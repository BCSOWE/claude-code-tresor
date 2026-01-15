---
description: Smart git commit with conventional commit message
---

Create a git commit following best practices:

1. **Show current status:**
```bash
echo "=== Git Status ===" && \
git status --short && \
echo "" && \
echo "=== Files to be committed ===" && \
git diff --cached --name-only
```

2. **Review the changes:**
```bash
echo "" && \
echo "=== Changes Summary ===" && \
git diff --cached --stat
```

3. **Check related beads tasks:**
```bash
echo "" && \
echo "=== Open In-Progress Tasks ===" && \
bd list --status in-progress 2>/dev/null | head -5 || echo "No in-progress tasks"
```

4. **Analyze the changes and create a conventional commit message:**

Based on the git diff output:
- Determine the commit type: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `style`, `perf`
- Write a concise summary (imperative mood, no period)
- Add a detailed body if needed (explain "why" not "what")
- Include breaking changes if applicable
- Reference beads task ID if work relates to a tracked task

5. **Create the commit:**
```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

<optional body>

Relates-to: <beads-task-id> (if applicable)

Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

6. **Show result:**
```bash
echo "" && \
echo "=== Commit Created ===" && \
git log -1 --oneline && \
echo "" && \
git status
```

7. **Update beads task status (if applicable):**

If this commit completes a task:
```bash
bd close <task-id>
```

If work is in progress:
```bash
bd update <task-id> --status in-progress
```

**Conventional Commit Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `refactor:` - Code change that neither fixes a bug nor adds a feature
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks, dependencies
- `style:` - Code formatting, missing semicolons
- `perf:` - Performance improvement

**Examples:**
- `feat: Add payment schedule calendar view`
- `fix: Resolve forecast approval workflow bug`
- `docs: Update CHANGELOG with v0.5.0 release notes`
- `refactor: Simplify email template generation logic`

**With beads reference:**
- `feat: Add assessment comparison view`
  `Relates-to: assessment-wsc.C.5`
