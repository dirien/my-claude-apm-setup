---
description: How to read command output that rtk has compressed
---

- Command output may be condensed by [rtk](https://github.com/rtk-ai/rtk): a `PreToolUse`
  hook silently rewrites Bash commands (`git status` → `rtk git status`), so what you read
  keeps every signal but drops noise.
- Treat condensed output as the complete result. Run commands normally and batch related
  ones into a single call rather than re-running them to "see more".
- Truncated results state their own recovery path. Only when a result is unusable — empty
  where output was clearly expected, contradicting its exit code, or garbled — re-run it as
  `rtk proxy <cmd>` to get the raw output.
- Inside a Claude Code worktree (`.claude/worktrees/`) the hook leaves commands unrewritten,
  so output there is raw. Don't wrap commands in `rtk` yourself in a worktree session: the
  isolation check refuses git behind a launcher.
- `rtk gain` reports what the compression saved.
