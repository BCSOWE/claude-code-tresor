#!/bin/bash
#
# update-check.sh - Check for updates across Claude Code ecosystem tools
#
# Usage: ~/.claude/scripts/update-check.sh
#
# This script checks versions of:
#   - Claude Code (Anthropic CLI)
#   - Beads (bd) - Issue tracker from steveyegge/beads
#   - PixelTable - Memory system database
#   - Tresor - Claude Code toolkit from your fork
#
# Exit codes:
#   0 - All tools up to date
#   1 - Updates available
#   2 - Error checking updates
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

UPDATES_AVAILABLE=0

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}     Claude Code Ecosystem Update Check    ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
echo -e "${YELLOW}=== Claude Code ===${NC}"
if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1)
    echo "Installed: $CLAUDE_VERSION"
    # Check for updates (non-blocking)
    UPDATE_CHECK=$(claude update --check 2>/dev/null || echo "")
    if echo "$UPDATE_CHECK" | grep -qi "available\|update"; then
        echo -e "${RED}>>> UPDATE AVAILABLE <<<${NC}"
        UPDATES_AVAILABLE=1
    else
        echo -e "${GREEN}Up to date${NC}"
    fi
else
    echo "Not found"
fi
echo ""

# -----------------------------------------------------------------------------
# Beads (bd)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}=== Beads (bd) ===${NC}"
if command -v bd &> /dev/null; then
    CURRENT_BD=$(bd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    LATEST_BD=$(curl -sf https://api.github.com/repos/steveyegge/beads/releases/latest | jq -r '.tag_name // "unknown"' | sed 's/v//' || echo "check-failed")

    echo "Current: $CURRENT_BD"
    echo "Latest:  $LATEST_BD"

    if [ "$CURRENT_BD" != "$LATEST_BD" ] && [ "$LATEST_BD" != "check-failed" ] && [ "$LATEST_BD" != "unknown" ]; then
        echo -e "${RED}>>> UPDATE AVAILABLE <<<${NC}"
        echo "Release: https://github.com/steveyegge/beads/releases/tag/v$LATEST_BD"
        UPDATES_AVAILABLE=1
    elif [ "$LATEST_BD" = "check-failed" ]; then
        echo -e "${YELLOW}Could not check latest version${NC}"
    else
        echo -e "${GREEN}Up to date${NC}"
    fi
else
    echo "Not found at expected path (~/.local/bin/bd)"
fi
echo ""

# -----------------------------------------------------------------------------
# PixelTable
# -----------------------------------------------------------------------------
echo -e "${YELLOW}=== PixelTable ===${NC}"

# Find the venv - check CLAUDE_PROJECT_DIR first, then common locations
VENV_PATHS=(
    "${CLAUDE_PROJECT_DIR}/claude_memory/venv/bin"
    "$HOME/dev_projects/assessment/claude_memory/venv/bin"
)

VENV=""
for path in "${VENV_PATHS[@]}"; do
    if [ -f "$path/pip" ]; then
        VENV="$path"
        break
    fi
done

if [ -n "$VENV" ]; then
    CURRENT_PT=$($VENV/pip show pixeltable 2>/dev/null | grep "^Version:" | cut -d' ' -f2 || echo "unknown")
    LATEST_PT=$(pip index versions pixeltable 2>/dev/null | head -1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\)' | tr -d '()' || echo "check-failed")

    echo "Venv: $VENV"
    echo "Current: $CURRENT_PT"
    echo "Latest:  $LATEST_PT"

    if [ "$CURRENT_PT" != "$LATEST_PT" ] && [ "$LATEST_PT" != "check-failed" ] && [ "$LATEST_PT" != "" ]; then
        echo -e "${RED}>>> UPDATE AVAILABLE <<<${NC}"
        echo "Changelog: https://github.com/pixeltable/pixeltable/releases"
        UPDATES_AVAILABLE=1
    elif [ "$LATEST_PT" = "check-failed" ] || [ "$LATEST_PT" = "" ]; then
        echo -e "${YELLOW}Could not check latest version${NC}"
    else
        echo -e "${GREEN}Up to date${NC}"
    fi
else
    echo "PixelTable venv not found"
    echo "Expected at: \$CLAUDE_PROJECT_DIR/claude_memory/venv"
fi
echo ""

# -----------------------------------------------------------------------------
# Tresor
# -----------------------------------------------------------------------------
echo -e "${YELLOW}=== Tresor ===${NC}"
TRESOR_DIR="$HOME/.claude/tresor"

if [ -d "$TRESOR_DIR/.git" ]; then
    cd "$TRESOR_DIR"

    # Check if upstream is configured
    if git remote | grep -q upstream; then
        git fetch upstream --quiet 2>/dev/null || true

        CURRENT_COMMIT=$(git rev-parse --short HEAD)
        CURRENT_BRANCH=$(git branch --show-current)
        BEHIND=$(git rev-list HEAD..upstream/main --count 2>/dev/null || echo "0")

        echo "Directory: $TRESOR_DIR"
        echo "Branch: $CURRENT_BRANCH ($CURRENT_COMMIT)"
        echo "Commits behind upstream/main: $BEHIND"

        if [ "$BEHIND" -gt 0 ]; then
            echo -e "${RED}>>> UPDATE AVAILABLE <<<${NC}"
            echo ""
            echo "Recent upstream commits:"
            git log HEAD..upstream/main --oneline 2>/dev/null | head -5
            UPDATES_AVAILABLE=1
        else
            echo -e "${GREEN}Up to date with upstream${NC}"
        fi
    else
        echo "Upstream remote not configured"
        echo "Run: git remote add upstream https://github.com/alirezarezvani/claude-code-tresor.git"
    fi

    cd - > /dev/null
else
    echo "Tresor not found at $TRESOR_DIR"
fi
echo ""

# -----------------------------------------------------------------------------
# MCP Servers Info
# -----------------------------------------------------------------------------
echo -e "${YELLOW}=== MCP Servers ===${NC}"
echo "MCP servers using npx @latest auto-update on each run."
echo "No manual update needed."
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}============================================${NC}"
if [ $UPDATES_AVAILABLE -eq 1 ]; then
    echo -e "${RED}Updates available!${NC} Run ${YELLOW}/update-tools${NC} for instructions."
    exit 1
else
    echo -e "${GREEN}All tools are up to date.${NC}"
    exit 0
fi
