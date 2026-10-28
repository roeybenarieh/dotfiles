---
name: git-conflicts
description: Use when a merge, rebase, cherry-pick, or stash pop stops with conflicts. Resolves them file by file and continues the operation.
---

# git-conflicts

1. `git status` to identify the operation (merge/rebase/cherry-pick) and the conflicted files (`git diff --name-only --diff-filter=U`).
2. For each file, read both sides and the surrounding code; understand what each side intended (`git log --merge -p -- <file>`). Keep the intent of both; do not blindly pick `--ours`/`--theirs`.
3. Remove all `<<<<<<<`, `=======`, `>>>>>>>` markers, then run the project's formatter/build/tests for the touched files.
4. `git add <file>` each resolved file, then continue: `git merge --continue` / `git rebase --continue` / `git cherry-pick --continue`.
5. If the resolution is genuinely ambiguous, stop and ask the user. Never `--abort` or force-resolve without asking.
