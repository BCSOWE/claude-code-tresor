---
description: End of session checklist and handoff
---

Run comprehensive end-of-session checklist:

## 1. Git Status Check

```bash
echo "=== Git Status ===" && \
git status --short && \
echo "" && \
echo "=== Uncommitted Changes ===" && \
git diff --stat && \
echo "" && \
echo "=== Untracked Files ===" && \
git ls-files --others --exclude-standard
```

## 2. Service Status Check

```bash
echo "" && \
echo "=== Service Status (Dev Ports; Prod uses 4006/3006) ===" && \
echo "" && \
echo "Backend (port 4007):" && \
(curl -s http://localhost:4007/api/health > /dev/null && echo "Running" || echo "Not running") && \
echo "" && \
echo "Frontend (port 3007):" && \
(curl -s http://localhost:3007 > /dev/null && echo "Running" || echo "Not running") && \
echo "" && \
echo "PostgreSQL (port 5432):" && \
(pg_isready -h localhost -p 5432 > /dev/null 2>&1 && echo "Running" || echo "Not running")
```

## 3. Beads Task Status

```bash
echo "" && \
echo "=== Beads Epic Progress ===" && \
bd epic status 2>/dev/null || echo "Beads not configured"
```

```bash
echo "" && \
echo "=== Open P0/P1 Tasks ===" && \
bd list --status open --priority 0 2>/dev/null | head -5 && \
bd list --status open --priority 1 2>/dev/null | head -5
```

**Beads Task Review:**
- [ ] Close any tasks completed this session: `bd close <task-id>`
- [ ] Update task status for work in progress: `bd update <task-id> --status in-progress`
- [ ] Create new tasks discovered during work: `bd create --parent <epic> --title "..." --priority 1`

## 4. Recent Work Summary

```bash
echo "" && \
echo "=== Recent Commits (last 3) ===" && \
git log --oneline --decorate -3
```

## 5. Knowledge Capture (IMPORTANT)

**Did we learn anything this session that belongs in CLAUDE.md?**

Ask yourself:
- [ ] New patterns or anti-patterns discovered? (e.g., "use X instead of Y")
- [ ] New pitfalls or gotchas encountered?
- [ ] Environment-specific behaviors found? (dev vs prod differences)
- [ ] Library/framework quirks documented?
- [ ] Architecture decisions made?

If YES to any → Update CLAUDE.md in the appropriate section.

**Persist to Memory** (for future sessions):
- [ ] Call `add_session_memory()` with summary, decisions, patterns learned
- [ ] Call `add_pattern()` for reusable code patterns
- [ ] Call `add_decision()` for architectural decisions

## 6. Documentation Status

Check if these files need updating:
- [ ] CHANGELOG.md - Add new features/fixes
- [ ] TECHNICAL_SPECS.md - Update if schema/API changed

## 7. Next Session Prep

Create handoff notes:
- What was accomplished this session?
- What beads tasks were completed/updated?
- What's the next priority (check P0/P1 tasks)?
- Any blockers or issues to address?
- Any files left in uncommitted state intentionally?

## 8. Cleanup Tasks

```bash
echo "" && \
echo "=== Log Files Size ===" && \
ls -lh /tmp/assessment-*.log 2>/dev/null || echo "No log files found"
```

Consider:
- Committing all completed work
- Pushing to remote repository
- Clearing old log files if needed
- Stopping services if done for the day

## Quick Checklist:

- [ ] All work committed and pushed
- [ ] Beads tasks updated (closed/in-progress)
- [ ] **Learnings captured** (CLAUDE.md + add_session_memory)
- [ ] Documentation updated if needed
- [ ] Services running properly
- [ ] No console errors in development
- [ ] Database migrations applied
- [ ] Next session priorities documented (reference beads P0/P1)
