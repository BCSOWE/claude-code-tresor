# Session Start Protocol (v2)

Initialize a productive Claude Code session with parallel context loading.

## Phase 1: Parallel Context Gathering

Execute ALL of these simultaneously (in a single tool call batch):

### 1. Beads Ready List
```bash
bd ready 2>/dev/null || echo "Beads not configured"
```

### 2. Memory Context
```
get_recent_context(days=3, project="assessment")
```

### 3. Git State
```bash
git status --short && git log --oneline -3
```

### 4. Service Health
```bash
echo "Backend:" && (curl -sf http://localhost:4007/health > /dev/null && echo "[OK]" || echo "[DOWN]") && \
echo "Frontend:" && (curl -sf http://localhost:3007 > /dev/null && echo "[OK]" || echo "[DOWN]") && \
echo "PostgreSQL:" && (pg_isready -h localhost -p 5432 > /dev/null 2>&1 && echo "[OK]" || echo "[DOWN]")
```

**IMPORTANT**: Run all 4 checks in PARALLEL (single message with multiple tool calls), not sequentially.

## Phase 2: Synthesize Results

After parallel results return, synthesize into the output format below.

## Output Format

```
SESSION START - [DATE]
═══════════════════════════════════════════════════════════════

SERVICES
  Backend (4007):    [OK/DOWN]
  Frontend (3007):   [OK/DOWN]
  PostgreSQL:        [OK/DOWN]

GIT STATE
  Branch: [branch-name]
  Status: [clean | X uncommitted files - list them]
  Recent: [last 3 commit summaries]

AVAILABLE WORK (bd ready)
  [P0] issue-id: Title
  [P1] issue-id: Title
  [P2] issue-id: Title
  (or: "No unblocked issues - run `bd list --status=open` to see all")

RECENT CONTEXT (last 3 days)
  [Date]: Brief session summary
  [Date]: Brief session summary
  (or: "No recent sessions - fresh context")

═══════════════════════════════════════════════════════════════
RECOMMENDED FOCUS
  [Specific recommendation based on:
   - P0 issues take priority
   - Uncommitted work should be addressed first
   - Recent context informs continuity]
═══════════════════════════════════════════════════════════════
```

## Decision Logic for Recommendations

```
IF uncommitted changes exist:
   → "Address uncommitted changes first: [list files]"

ELSE IF P0 issues exist:
   → "Start with [P0 issue]: [title]"

ELSE IF P1 issues exist:
   → "Continue with [P1 issue]: [title]"

ELSE IF recent context shows in-progress work:
   → "Resume: [work from recent session]"

ELSE:
   → "No urgent work. Check `bd list --status=open` or start new work."
```

## Error Handling

| Situation | Response |
|-----------|----------|
| Beads not configured | Skip beads section, note "Beads not configured" |
| Memory returns empty | Note "Fresh context - no recent sessions" |
| Service is down | Show [DOWN] and suggest: "Run /restart to fix" |
| Git has conflicts | Warn: "Merge conflicts detected - resolve before continuing" |

## Timing

- **Target**: 2-3 seconds total (parallel execution)
- **Old approach**: 8-12 seconds (sequential)
- **Improvement**: 4x faster

## Notes

- This replaces the sequential v1 protocol
- Parallel execution is KEY - don't run steps one-by-one
- Memory context is limited to 3 days for speed (use `/memory` for deeper search)
- Service check catches environment issues before you start working
- Uncommitted changes get priority to avoid losing work

## Quick Reference

| Need More Context? | Command |
|--------------------|---------|
| Deeper memory search | `/memory "topic"` or `search_memory("query")` |
| All open issues | `bd list --status=open` |
| Full service status | `/check-status` |
| Recent commits | `git log --oneline -10` |
