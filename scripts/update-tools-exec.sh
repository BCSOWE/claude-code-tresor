#!/bin/bash
#
# update-tools-exec.sh - Robust update manager for Claude Code ecosystem
#
# Usage:
#   update-tools-exec.sh [OPTIONS]
#
# Options:
#   --check          Check for updates only (default)
#   --update         Apply updates interactively
#   --yes, -y        Auto-confirm all updates (use with --update)
#   --dry-run        Show what would be done without doing it
#   --force          Update even if versions match
#   --skip TOOL      Skip specific tool (beads, pixeltable, tresor, claude)
#   --only TOOL      Only update specific tool
#   --help, -h       Show this help
#
# Exit codes:
#   0 - Success (all up to date or updates applied)
#   1 - Updates available (check mode)
#   2 - Update failed
#   3 - Lock acquisition failed
#   4 - Missing dependencies
#

set -uo pipefail  # Don't use -e, we handle errors manually

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
readonly SCRIPT_NAME="update-tools"
readonly SCRIPT_VERSION="1.0.0"
readonly LOCK_FILE="$HOME/.claude/.update-tools.lock"
readonly LOG_DIR="$HOME/.claude/logs"
readonly LOG_FILE="$LOG_DIR/update-tools.log"
readonly BACKUP_DIR="$HOME/.claude/backups"
readonly LOCK_TIMEOUT=3600  # 1 hour = stale lock

# Tool locations
readonly BEADS_BIN="$HOME/.local/bin/bd"
readonly BEADS_BACKUP="$HOME/.local/bin/bd.backup"
readonly BEADS_REPO="steveyegge/beads"

# PixelTable venv locations (in order of preference)
PIXELTABLE_VENV=""
readonly PIXELTABLE_VENV_PATHS=(
    "${CLAUDE_PROJECT_DIR:-}/claude_memory/venv"
    "$HOME/dev_projects/assessment/claude_memory/venv"
)

readonly TRESOR_DIR="$HOME/.claude/tresor"

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

#------------------------------------------------------------------------------
# State
#------------------------------------------------------------------------------
MODE="check"
AUTO_YES=false
DRY_RUN=false
FORCE=false
SKIP_TOOLS=()
ONLY_TOOL=""
UPDATES_AVAILABLE=0
UPDATES_APPLIED=0
UPDATES_FAILED=0
declare -A TOOL_STATUS  # Track status per tool

#------------------------------------------------------------------------------
# Logging
#------------------------------------------------------------------------------
setup_logging() {
    mkdir -p "$LOG_DIR"
    echo "=== Update Tools Run: $(date -Iseconds) ===" >> "$LOG_FILE"
}

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

log_info()    { log "INFO" "$@"; echo -e "${BLUE}ℹ${NC}  $*"; }
log_success() { log "SUCCESS" "$@"; echo -e "${GREEN}✓${NC}  $*"; }
log_warn()    { log "WARN" "$@"; echo -e "${YELLOW}⚠${NC}  $*"; }
log_error()   { log "ERROR" "$@"; echo -e "${RED}✖${NC}  $*" >&2; }
log_debug()   { log "DEBUG" "$@"; }  # Silent to console

#------------------------------------------------------------------------------
# Lock Management
#------------------------------------------------------------------------------
acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")"

    # Check for stale lock
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
        if [[ $lock_age -gt $LOCK_TIMEOUT ]]; then
            log_warn "Removing stale lock file (age: ${lock_age}s)"
            rm -f "$LOCK_FILE"
        else
            local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
            log_error "Another instance is running (PID: $lock_pid, age: ${lock_age}s)"
            log_error "If this is incorrect, remove: $LOCK_FILE"
            return 1
        fi
    fi

    echo $$ > "$LOCK_FILE"
    log_debug "Lock acquired (PID: $$)"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
    log_debug "Lock released"
}

#------------------------------------------------------------------------------
# Cleanup Handler
#------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    log_debug "Cleanup triggered (exit code: $exit_code)"
    release_lock

    # Summary if we did updates
    if [[ "$MODE" == "update" ]]; then
        echo ""
        echo -e "${BOLD}═══════════════════════════════════════════${NC}"
        echo -e "${BOLD}                 Summary                    ${NC}"
        echo -e "${BOLD}═══════════════════════════════════════════${NC}"
        echo -e "  Applied: ${GREEN}$UPDATES_APPLIED${NC}"
        echo -e "  Failed:  ${RED}$UPDATES_FAILED${NC}"
        echo -e "  Log:     $LOG_FILE"
        echo ""
    fi

    exit $exit_code
}

trap cleanup EXIT
trap 'log_warn "Interrupted by user"; exit 130' INT TERM

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------
detect_arch() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64)   arch="arm64" ;;
        *)       log_error "Unsupported architecture: $arch"; return 1 ;;
    esac

    case "$os" in
        linux)  os="linux" ;;
        darwin) os="darwin" ;;
        *)      log_error "Unsupported OS: $os"; return 1 ;;
    esac

    echo "${os}_${arch}"
}

retry_curl() {
    local url="$1"
    local output="${2:--}"  # Default to stdout
    local max_retries=3
    local retry_delay=2

    for ((i=1; i<=max_retries; i++)); do
        if curl -sfL --connect-timeout 10 --max-time 60 "$url" -o "$output" 2>/dev/null; then
            return 0
        fi

        if [[ $i -lt $max_retries ]]; then
            log_warn "Download failed (attempt $i/$max_retries), retrying in ${retry_delay}s..."
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))
        fi
    done

    log_error "Download failed after $max_retries attempts: $url"
    return 1
}

confirm_action() {
    local prompt="$1"

    if [[ "$AUTO_YES" == true ]]; then
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would prompt: $prompt"
        return 0
    fi

    echo -en "$prompt [y/N] "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

should_skip() {
    local tool="$1"

    # Check --only flag
    if [[ -n "$ONLY_TOOL" && "$ONLY_TOOL" != "$tool" ]]; then
        return 0
    fi

    # Check --skip flag
    for skip in "${SKIP_TOOLS[@]}"; do
        if [[ "$skip" == "$tool" ]]; then
            return 0
        fi
    done

    return 1
}

find_pixeltable_venv() {
    for path in "${PIXELTABLE_VENV_PATHS[@]}"; do
        if [[ -f "$path/bin/pip" ]]; then
            PIXELTABLE_VENV="$path"
            return 0
        fi
    done
    return 1
}

#------------------------------------------------------------------------------
# Version Check Functions
#------------------------------------------------------------------------------
check_beads() {
    local tool="beads"

    if should_skip "$tool"; then
        TOOL_STATUS[$tool]="skipped"
        return 0
    fi

    echo -e "\n${YELLOW}=== Beads (bd) ===${NC}"

    if [[ ! -x "$BEADS_BIN" ]]; then
        log_warn "Beads not installed at $BEADS_BIN"
        TOOL_STATUS[$tool]="not_installed"
        return 0
    fi

    local current=$("$BEADS_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_debug "Beads current version: $current"

    local latest_json
    if ! latest_json=$(retry_curl "https://api.github.com/repos/$BEADS_REPO/releases/latest"); then
        log_warn "Could not check latest version (API error)"
        TOOL_STATUS[$tool]="check_failed"
        return 0
    fi

    local latest=$(echo "$latest_json" | jq -r '.tag_name // "unknown"' | sed 's/^v//')

    echo -e "  Current: ${BOLD}$current${NC}"
    echo -e "  Latest:  ${BOLD}$latest${NC}"

    if [[ "$current" == "$latest" && "$FORCE" != true ]]; then
        log_success "Beads is up to date"
        TOOL_STATUS[$tool]="up_to_date"
    else
        if [[ "$FORCE" == true && "$current" == "$latest" ]]; then
            log_info "Force update requested"
        fi
        echo -e "  ${RED}>>> UPDATE AVAILABLE <<<${NC}"
        TOOL_STATUS[$tool]="update_available:$current:$latest"
        ((UPDATES_AVAILABLE++))
    fi
}

check_pixeltable() {
    local tool="pixeltable"

    if should_skip "$tool"; then
        TOOL_STATUS[$tool]="skipped"
        return 0
    fi

    echo -e "\n${YELLOW}=== PixelTable ===${NC}"

    if ! find_pixeltable_venv; then
        log_warn "PixelTable venv not found"
        TOOL_STATUS[$tool]="not_installed"
        return 0
    fi

    echo -e "  Venv: $PIXELTABLE_VENV"

    local current=$("$PIXELTABLE_VENV/bin/pip" show pixeltable 2>/dev/null | grep "^Version:" | cut -d' ' -f2 || echo "unknown")
    log_debug "PixelTable current version: $current"

    local latest
    latest=$(pip index versions pixeltable 2>/dev/null | head -1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\)' | tr -d '()' || true)
    [[ -z "$latest" ]] && latest="check_failed"

    if [[ "$latest" == "check_failed" || -z "$latest" ]]; then
        log_warn "Could not check latest version (PyPI error)"
        TOOL_STATUS[$tool]="check_failed"
        return 0
    fi

    echo -e "  Current: ${BOLD}$current${NC}"
    echo -e "  Latest:  ${BOLD}$latest${NC}"

    if [[ "$current" == "$latest" && "$FORCE" != true ]]; then
        log_success "PixelTable is up to date"
        TOOL_STATUS[$tool]="up_to_date"
    else
        echo -e "  ${RED}>>> UPDATE AVAILABLE <<<${NC}"
        TOOL_STATUS[$tool]="update_available:$current:$latest"
        ((UPDATES_AVAILABLE++))
    fi
}

check_tresor() {
    local tool="tresor"

    if should_skip "$tool"; then
        TOOL_STATUS[$tool]="skipped"
        return 0
    fi

    echo -e "\n${YELLOW}=== Tresor ===${NC}"

    if [[ ! -d "$TRESOR_DIR/.git" ]]; then
        log_warn "Tresor not found at $TRESOR_DIR"
        TOOL_STATUS[$tool]="not_installed"
        return 0
    fi

    cd "$TRESOR_DIR"

    if ! git remote | grep -q upstream; then
        log_warn "Upstream remote not configured"
        TOOL_STATUS[$tool]="no_upstream"
        cd - > /dev/null
        return 0
    fi

    git fetch upstream --quiet 2>/dev/null || {
        log_warn "Could not fetch upstream"
        TOOL_STATUS[$tool]="fetch_failed"
        cd - > /dev/null
        return 0
    }

    local current_branch=$(git branch --show-current)
    local current_commit=$(git rev-parse --short HEAD)
    local behind=$(git rev-list HEAD..upstream/main --count 2>/dev/null || echo "0")

    echo -e "  Directory: $TRESOR_DIR"
    echo -e "  Branch: ${BOLD}$current_branch${NC} ($current_commit)"
    echo -e "  Behind upstream: ${BOLD}$behind${NC} commits"

    if [[ "$behind" -eq 0 && "$FORCE" != true ]]; then
        log_success "Tresor is up to date"
        TOOL_STATUS[$tool]="up_to_date"
    else
        echo -e "  ${RED}>>> UPDATE AVAILABLE <<<${NC}"
        echo -e "  Recent upstream commits:"
        git log HEAD..upstream/main --oneline 2>/dev/null | head -3 | sed 's/^/    /'
        TOOL_STATUS[$tool]="update_available:$behind"
        ((UPDATES_AVAILABLE++))
    fi

    cd - > /dev/null
}

check_claude() {
    local tool="claude"

    if should_skip "$tool"; then
        TOOL_STATUS[$tool]="skipped"
        return 0
    fi

    echo -e "\n${YELLOW}=== Claude Code ===${NC}"

    if ! command -v claude &>/dev/null; then
        log_warn "Claude Code not found"
        TOOL_STATUS[$tool]="not_installed"
        return 0
    fi

    local current=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    echo -e "  Installed: ${BOLD}$current${NC}"

    # Claude update --check would tell us, but it's interactive
    # Just note that user can run `claude update` manually
    log_info "Run 'claude update' to check for updates"
    TOOL_STATUS[$tool]="manual_check"
}

#------------------------------------------------------------------------------
# Update Functions
#------------------------------------------------------------------------------
update_beads() {
    local status="${TOOL_STATUS[beads]:-}"

    if [[ ! "$status" =~ ^update_available ]]; then
        return 0
    fi

    local parts=(${status//:/ })
    local current="${parts[1]}"
    local latest="${parts[2]}"

    echo -e "\n${CYAN}Updating Beads: $current → $latest${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would update Beads from $current to $latest"
        return 0
    fi

    if ! confirm_action "Update Beads from $current to $latest?"; then
        log_info "Skipped Beads update"
        return 0
    fi

    # Step 1: Kill daemon
    log_info "Stopping Beads daemons..."
    "$BEADS_BIN" daemons killall 2>/dev/null || true

    # Step 2: Backup
    log_info "Backing up current version..."
    mkdir -p "$BACKUP_DIR"
    cp "$BEADS_BIN" "$BACKUP_DIR/bd-$current-$(date +%Y%m%d%H%M%S)" || {
        log_error "Failed to create backup"
        ((UPDATES_FAILED++))
        return 1
    }
    cp "$BEADS_BIN" "$BEADS_BACKUP"

    # Step 3: Download
    local arch=$(detect_arch) || {
        log_error "Could not detect architecture"
        ((UPDATES_FAILED++))
        return 1
    }

    local download_url="https://github.com/$BEADS_REPO/releases/download/v$latest/beads_${latest}_${arch}.tar.gz"
    log_info "Downloading from $download_url..."

    local tmp_dir=$(mktemp -d)
    if ! retry_curl "$download_url" "$tmp_dir/beads.tar.gz"; then
        log_error "Download failed"
        ((UPDATES_FAILED++))
        rm -rf "$tmp_dir"
        return 1
    fi

    # Step 4: Extract and install
    log_info "Installing..."
    cd "$tmp_dir"
    if ! tar xzf beads.tar.gz; then
        log_error "Extraction failed"
        ((UPDATES_FAILED++))
        rm -rf "$tmp_dir"
        cd - > /dev/null
        return 1
    fi

    mv bd "$BEADS_BIN"
    chmod +x "$BEADS_BIN"
    cd - > /dev/null
    rm -rf "$tmp_dir"

    # Step 5: Verify
    local new_version=$("$BEADS_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    if [[ "$new_version" != "$latest" ]]; then
        log_error "Verification failed (expected $latest, got $new_version)"
        log_warn "Rolling back..."
        mv "$BEADS_BACKUP" "$BEADS_BIN"
        ((UPDATES_FAILED++))
        return 1
    fi

    # Step 6: Run migration
    log_info "Running database migration..."
    "$BEADS_BIN" migrate 2>/dev/null || true

    log_success "Beads updated to $latest"
    ((UPDATES_APPLIED++))
    rm -f "$BEADS_BACKUP"
    return 0
}

update_pixeltable() {
    local status="${TOOL_STATUS[pixeltable]:-}"

    if [[ ! "$status" =~ ^update_available ]]; then
        return 0
    fi

    local parts=(${status//:/ })
    local current="${parts[1]}"
    local latest="${parts[2]}"

    echo -e "\n${CYAN}Updating PixelTable: $current → $latest${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would update PixelTable from $current to $latest"
        return 0
    fi

    if ! confirm_action "Update PixelTable from $current to $latest?"; then
        log_info "Skipped PixelTable update"
        return 0
    fi

    log_info "Installing PixelTable $latest..."
    if ! "$PIXELTABLE_VENV/bin/pip" install --upgrade "pixeltable==$latest" 2>&1 | tail -5; then
        log_error "pip install failed"
        ((UPDATES_FAILED++))
        return 1
    fi

    # Verify
    log_info "Verifying installation..."
    if ! "$PIXELTABLE_VENV/bin/python" -c "import pixeltable; print(f'PixelTable {pixeltable.__version__} OK')" 2>/dev/null; then
        log_error "Verification failed - PixelTable import error"
        log_warn "Rolling back to $current..."
        "$PIXELTABLE_VENV/bin/pip" install "pixeltable==$current" 2>/dev/null
        ((UPDATES_FAILED++))
        return 1
    fi

    log_success "PixelTable updated to $latest"
    ((UPDATES_APPLIED++))
    return 0
}

update_tresor() {
    local status="${TOOL_STATUS[tresor]:-}"

    if [[ ! "$status" =~ ^update_available ]]; then
        return 0
    fi

    local behind="${status#update_available:}"

    echo -e "\n${CYAN}Updating Tresor: $behind commits behind${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would merge $behind commits from upstream"
        return 0
    fi

    if ! confirm_action "Merge $behind commits from upstream?"; then
        log_info "Skipped Tresor update"
        return 0
    fi

    cd "$TRESOR_DIR"

    local current_branch=$(git branch --show-current)
    local has_changes=false

    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_changes=true
        log_info "Stashing uncommitted changes..."
        git stash push -m "update-tools auto-stash $(date +%Y%m%d%H%M%S)" || {
            log_error "Failed to stash changes"
            ((UPDATES_FAILED++))
            cd - > /dev/null
            return 1
        }
    fi

    # Update main branch
    log_info "Updating main branch..."
    git checkout main 2>/dev/null || git checkout -b main origin/main 2>/dev/null || {
        log_error "Failed to checkout main"
        [[ "$has_changes" == true ]] && git stash pop 2>/dev/null
        ((UPDATES_FAILED++))
        cd - > /dev/null
        return 1
    }

    if ! git merge upstream/main --no-edit; then
        log_error "Merge conflict on main branch"
        git merge --abort 2>/dev/null
        git checkout "$current_branch" 2>/dev/null
        [[ "$has_changes" == true ]] && git stash pop 2>/dev/null
        ((UPDATES_FAILED++))
        cd - > /dev/null
        return 1
    fi

    # Rebase custom branch if we were on it
    if [[ "$current_branch" == "custom" ]]; then
        log_info "Rebasing custom branch on updated main..."
        git checkout custom

        if ! git rebase main; then
            log_error "Rebase conflict on custom branch"
            log_warn "Aborting rebase - manual resolution needed"
            git rebase --abort 2>/dev/null
            [[ "$has_changes" == true ]] && git stash pop 2>/dev/null
            ((UPDATES_FAILED++))
            cd - > /dev/null
            return 1
        fi

        log_info "Pushing updated custom branch..."
        git push -f origin custom 2>/dev/null || log_warn "Could not push to origin"
    fi

    # Push main
    git checkout main
    git push origin main 2>/dev/null || log_warn "Could not push main to origin"

    # Return to original branch
    git checkout "$current_branch" 2>/dev/null

    # Restore stashed changes
    if [[ "$has_changes" == true ]]; then
        log_info "Restoring stashed changes..."
        git stash pop 2>/dev/null || log_warn "Could not restore stashed changes"
    fi

    cd - > /dev/null

    log_success "Tresor updated ($behind commits merged)"
    ((UPDATES_APPLIED++))
    return 0
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
print_usage() {
    cat << EOF
${BOLD}update-tools${NC} v$SCRIPT_VERSION - Claude Code ecosystem update manager

${BOLD}USAGE${NC}
    update-tools-exec.sh [OPTIONS]

${BOLD}OPTIONS${NC}
    --check          Check for updates only (default)
    --update         Apply updates interactively
    --yes, -y        Auto-confirm all updates
    --dry-run        Show what would be done
    --force          Update even if versions match
    --skip TOOL      Skip tool (beads, pixeltable, tresor, claude)
    --only TOOL      Only check/update specific tool
    --help, -h       Show this help

${BOLD}EXAMPLES${NC}
    # Check all tools for updates
    update-tools-exec.sh

    # Update all tools with confirmation
    update-tools-exec.sh --update

    # Update only beads without prompts
    update-tools-exec.sh --update --yes --only beads

    # See what would be updated
    update-tools-exec.sh --update --dry-run

${BOLD}TOOLS MANAGED${NC}
    beads       - Issue tracker (steveyegge/beads)
    pixeltable  - Memory database (PyPI)
    tresor      - Claude Code toolkit (Git fork)
    claude      - Claude Code CLI (manual)

EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                MODE="check"
                shift
                ;;
            --update)
                MODE="update"
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --skip)
                SKIP_TOOLS+=("$2")
                shift 2
                ;;
            --only)
                ONLY_TOOL="$2"
                shift 2
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Setup
    setup_logging
    log_debug "Mode: $MODE, AutoYes: $AUTO_YES, DryRun: $DRY_RUN, Force: $FORCE"

    # Acquire lock
    if ! acquire_lock; then
        exit 3
    fi

    # Header
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${BOLD}     Claude Code Ecosystem Update Tool     ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN MODE]${NC}"
    fi

    # Check all tools
    check_beads
    check_pixeltable
    check_tresor
    check_claude

    # Apply updates if requested
    if [[ "$MODE" == "update" && $UPDATES_AVAILABLE -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}═══════════════════════════════════════════${NC}"
        echo -e "${BOLD}              Applying Updates             ${NC}"
        echo -e "${BOLD}═══════════════════════════════════════════${NC}"

        update_beads
        update_pixeltable
        update_tresor
        # Claude update is manual - just inform user
        if [[ "${TOOL_STATUS[claude]:-}" == "manual_check" ]]; then
            echo -e "\n${CYAN}Claude Code:${NC} Run 'claude update' manually"
        fi
    fi

    # Final status
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"

    if [[ "$MODE" == "check" ]]; then
        if [[ $UPDATES_AVAILABLE -gt 0 ]]; then
            echo -e "${YELLOW}$UPDATES_AVAILABLE update(s) available${NC}"
            echo -e "Run with ${BOLD}--update${NC} to apply"
            exit 1
        else
            echo -e "${GREEN}All tools are up to date${NC}"
            exit 0
        fi
    else
        if [[ $UPDATES_FAILED -gt 0 ]]; then
            exit 2
        fi
        exit 0
    fi
}

main "$@"
