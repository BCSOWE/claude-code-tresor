---
description: Show comprehensive git status with recent commits
---

Display detailed git repository information:

```bash
echo "=== Git Branch ===" && \
git branch --show-current

echo -e "\n=== Uncommitted Changes ===" && \
git status --short

echo -e "\n=== Recent Commits (last 5) ===" && \
git log --oneline --decorate -5

echo -e "\n=== Files Changed Since Last Commit ===" && \
git diff --stat

echo -e "\n=== Untracked Files ===" && \
git ls-files --others --exclude-standard
```

This provides a comprehensive view of:
- Current branch
- Modified/staged files
- Recent commit history
- Changed files statistics
- Untracked files
