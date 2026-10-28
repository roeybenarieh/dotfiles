---
name: git-commit
description: Use when the user explicitly asks to commit changes. Writes a conventional commit message from the staged diff. Never commit without an explicit request.
---

# git-commit

Only run when the user explicitly asked to commit.

1. `git status --short` and `git diff --staged`. If nothing is staged, stage only the files relevant to the request (never `git add -A` blindly; skip secrets and unrelated work).
2. `git log -n 10 --oneline` to match the repo's message style.
3. Write the message: `type(scope): imperative summary` (<= 72 chars), types `feat|fix|docs|refactor|test|chore|build|ci|perf`. Add a body only to explain *why*.
4. `git commit` with the message. Never use `--no-verify` or `--amend` unless asked. If a hook fails, fix the cause and create a new commit.
5. Do not push unless asked.
