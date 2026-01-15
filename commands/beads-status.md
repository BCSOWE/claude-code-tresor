---
description: Show beads epic progress and open tasks
---

Show current project status from beads issue tracker:

## 1. Epic Progress Overview

```bash
echo "=== Epic Progress ===" && \
bd epic status
```

## 2. Open P0 (Critical) Tasks

```bash
echo "" && \
echo "=== Open P0 Tasks (Critical Priority) ===" && \
bd list --status open --priority 0 2>/dev/null || echo "No P0 tasks found"
```

## 3. Open P1 (High Priority) Tasks

```bash
echo "" && \
echo "=== Open P1 Tasks (High Priority) ===" && \
bd list --status open --priority 1 2>/dev/null || echo "No P1 tasks found"
```

## 4. Recently Closed Tasks

```bash
echo "" && \
echo "=== Recently Closed (last 5) ===" && \
bd list --status closed 2>/dev/null | head -10 || echo "No closed tasks found"
```

## 5. In-Progress Tasks

```bash
echo "" && \
echo "=== In-Progress Tasks ===" && \
bd list --status in-progress 2>/dev/null || echo "No in-progress tasks"
```

## Quick Actions

After reviewing status, consider:
- Close completed tasks: `bd close <task-id>`
- Update priority: `bd update <task-id> --priority <0-4>`
- Add new task: `bd create --parent <epic-id> --title "Task name" --priority 1`
- Start work: `bd update <task-id> --status in-progress`
