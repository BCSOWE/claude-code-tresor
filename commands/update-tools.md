# Update Tools Command

Comprehensive update checker and installer for Claude Code ecosystem tools.

## Overview

This command checks for updates and optionally applies them across multiple tools:

| Tool | Source | Update Method |
|------|--------|---------------|
| Claude Code | Anthropic | `claude update` |
| Tresor | GitHub Fork | Git fetch/merge/rebase |
| Beads (bd) | steveyegge/beads | GitHub release binary |
| PixelTable | PyPI | pip upgrade in venv |
| MCP Servers | npm | npx @latest (auto-updates) |

---

## IMPORTANT GUARDRAILS

### Before Running Updates

1. **Check current work state** - Don't update mid-task
2. **Commit uncommitted changes** - Updates may restart Claude
3. **Note current versions** - For rollback if needed
4. **Review changelogs** - Major versions may have breaking changes

### Rollback Procedures

| Tool | Rollback Method |
|------|-----------------|
| Claude Code | `claude update --version X.Y.Z` |
| Tresor | `git checkout <previous-commit>` |
| Beads | Download previous release from GitHub |
| PixelTable | `pip install pixeltable==X.Y.Z` |

---

## Step 1: Check Current Versions

Run these commands to see current state:

```bash
# Claude Code
claude --version

# Beads
bd --version

# PixelTable (in claude_memory venv)
$CLAUDE_PROJECT_DIR/claude_memory/venv/bin/pip show pixeltable | grep Version

# Tresor
cd ~/.claude/tresor && git log --oneline -1 && git remote -v
```

---

## Step 2: Check for Updates

### 2.1 Claude Code

```bash
claude update --check
```

If update available, review release notes at: https://github.com/anthropics/claude-code/releases

### 2.2 Beads (bd)

```bash
# Current version
bd --version

# Latest release
curl -s https://api.github.com/repos/steveyegge/beads/releases/latest | jq -r '.tag_name'

# Release notes
curl -s https://api.github.com/repos/steveyegge/beads/releases/latest | jq -r '.body' | head -50
```

### 2.3 PixelTable

```bash
# Current version
$CLAUDE_PROJECT_DIR/claude_memory/venv/bin/pip show pixeltable | grep Version

# Latest available
pip index versions pixeltable 2>/dev/null | head -1

# Changelog: https://github.com/pixeltable/pixeltable/releases
```

### 2.4 Tresor (Your Fork)

```bash
cd ~/.claude/tresor

# Fetch upstream changes
git fetch upstream

# Check if behind
git log HEAD..upstream/main --oneline

# If commits shown, upstream has updates
```

### 2.5 MCP Servers

MCP servers using `npx -y @package@latest` auto-update on each invocation.
No manual update needed, but you can clear npm cache if issues occur:

```bash
npm cache clean --force
```

---

## Step 3: Apply Updates

### 3.1 Update Claude Code

```bash
claude update
```

**GUARDRAIL**: This will restart Claude Code. Save your work first.

### 3.2 Update Beads

```bash
# Download latest for Linux x64
cd /tmp
curl -sL https://github.com/steveyegge/beads/releases/latest/download/beads_$(curl -s https://api.github.com/repos/steveyegge/beads/releases/latest | jq -r '.tag_name' | sed 's/v//')_linux_amd64.tar.gz | tar xz

# Backup old version
cp ~/.local/bin/bd ~/.local/bin/bd.backup

# Install new version
mv bd ~/.local/bin/bd
chmod +x ~/.local/bin/bd

# Verify
bd --version
```

**ROLLBACK**: `mv ~/.local/bin/bd.backup ~/.local/bin/bd`

### 3.3 Update PixelTable

```bash
# Activate venv and upgrade
$CLAUDE_PROJECT_DIR/claude_memory/venv/bin/pip install --upgrade pixeltable

# Verify
$CLAUDE_PROJECT_DIR/claude_memory/venv/bin/pip show pixeltable | grep Version
```

**GUARDRAIL**: Check for database migrations needed after major version updates.

**ROLLBACK**: `$CLAUDE_PROJECT_DIR/claude_memory/venv/bin/pip install pixeltable==0.5.9`

### 3.4 Update Tresor (Merge Upstream)

```bash
cd ~/.claude/tresor

# 1. Fetch upstream
git fetch upstream

# 2. Switch to main and merge upstream
git checkout main
git merge upstream/main

# 3. Rebase custom branch on updated main
git checkout custom
git rebase main

# 4. Force push custom branch (your fork only)
git push -f origin custom

# 5. Push main to your fork
git checkout main
git push origin main
```

**GUARDRAIL**: Rebase may have conflicts if upstream changed files you customized.

**CONFLICT RESOLUTION**:
```bash
# If rebase conflicts:
git status  # See conflicting files
# Edit files to resolve conflicts
git add <resolved-files>
git rebase --continue

# Or abort and keep old version:
git rebase --abort
```

---

## Quick Update Script

Copy this script to check all updates at once:

```bash
#!/bin/bash
# update-check.sh - Check for updates across all tools

echo "============================================"
echo "     Claude Code Ecosystem Update Check    "
echo "============================================"
echo ""

# Claude Code
echo "=== Claude Code ==="
claude --version 2>/dev/null || echo "Not found"
echo ""

# Beads
echo "=== Beads (bd) ==="
CURRENT_BD=$(bd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
LATEST_BD=$(curl -s https://api.github.com/repos/steveyegge/beads/releases/latest | jq -r '.tag_name' | sed 's/v//')
echo "Current: $CURRENT_BD"
echo "Latest:  $LATEST_BD"
if [ "$CURRENT_BD" != "$LATEST_BD" ]; then
  echo ">>> UPDATE AVAILABLE <<<"
fi
echo ""

# PixelTable
echo "=== PixelTable ==="
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  VENV="$CLAUDE_PROJECT_DIR/claude_memory/venv/bin"
else
  VENV="$HOME/dev_projects/assessment/claude_memory/venv/bin"
fi
CURRENT_PT=$($VENV/pip show pixeltable 2>/dev/null | grep Version | cut -d' ' -f2)
LATEST_PT=$(pip index versions pixeltable 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "Current: $CURRENT_PT"
echo "Latest:  $LATEST_PT"
if [ "$CURRENT_PT" != "$LATEST_PT" ]; then
  echo ">>> UPDATE AVAILABLE <<<"
fi
echo ""

# Tresor
echo "=== Tresor ==="
cd ~/.claude/tresor 2>/dev/null && {
  git fetch upstream --quiet
  BEHIND=$(git rev-list HEAD..upstream/main --count)
  echo "Custom branch commits behind upstream: $BEHIND"
  if [ "$BEHIND" -gt 0 ]; then
    echo ">>> UPDATE AVAILABLE <<<"
    echo "New commits:"
    git log HEAD..upstream/main --oneline | head -5
  fi
  cd - > /dev/null
} || echo "Tresor not found at ~/.claude/tresor"
echo ""

echo "============================================"
echo "Run /update-tools for update instructions"
echo "============================================"
```

---

## Automation Ideas

### Cron Job for Notifications

Add to crontab to check weekly:

```bash
# Check for updates every Monday at 9am
0 9 * * 1 ~/.claude/scripts/update-check.sh > ~/.claude/update-status.txt 2>&1
```

### Pre-Session Hook

Add to `~/.claude/settings.json` SessionStart hook to warn about updates:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/update-check.sh 2>/dev/null | grep -q 'UPDATE AVAILABLE' && echo '⚠️  Tool updates available - run /update-tools'"
          }
        ]
      }
    ]
  }
}
```

---

## Troubleshooting

### Beads Update Fails

```bash
# Check architecture
uname -m  # Should be x86_64 for linux_amd64

# Manual download
wget https://github.com/steveyegge/beads/releases/download/vX.Y.Z/beads_X.Y.Z_linux_amd64.tar.gz
```

### PixelTable Database Issues

```bash
# Check PixelTable database status
$VENV/python -c "import pixeltable as pxt; print(pxt.list_tables())"

# If issues, may need to run migrations (check release notes)
```

### Tresor Merge Conflicts

If custom branch has conflicts with upstream:

1. Identify conflicting files
2. Decide: keep your changes or adopt upstream
3. For files you customized, usually keep yours
4. For new upstream files, adopt them

```bash
# See what upstream changed
git diff main upstream/main --name-only

# See what you changed
git diff main custom --name-only

# Overlap = potential conflicts
```

---

## Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-15 | Claude | Initial creation |

