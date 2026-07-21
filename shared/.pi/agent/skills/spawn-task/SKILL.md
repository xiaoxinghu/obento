---
name: spawn-task
description: Dispatch a coding task into an isolated git worktree running a fresh pi agent in its own detached tmux session, while the current session stays as central control. Use to delegate/kick off a task in the background, run tasks in parallel on separate branches, or start work without touching the main session.
---

# Spawn task

Make the current session a **dispatcher**: given a one-sentence instruction,
create an isolated git worktree on a new branch, seed untracked dev files, and
launch a fresh `pi` in a detached `tmux` session rooted there with your
instruction as its opening prompt. The current session is untouched. Needs only
`pi` + `tmux` + `git`.

The skill argument is your instruction — used to derive the slug/branch and,
verbatim, as the spawned agent's first message. If it names a GitHub issue/PR,
the agent reads it via `gh` (e.g. `/skill:spawn-task review PR #42 and give feedback`).

## Spawn

```bash
set -euo pipefail
SLUG="issue-100"                          # kebab-case; use issue-N / review-pr-N when relevant
REPO_ROOT="$(git rev-parse --show-toplevel)"; REPO_NAME="$(basename "$REPO_ROOT")"
WT_DIR="$(dirname "$REPO_ROOT")/${REPO_NAME}.worktrees/${SLUG}"
SESSION="$(printf '%s-%s' "$REPO_NAME" "$SLUG" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-')"

tmux has-session -t "$SESSION" 2>/dev/null && { echo "session exists"; exit 1; }
[ -e "$WT_DIR" ] && { echo "worktree exists"; exit 1; }
git worktree add -b "$SLUG" "$WT_DIR"     # attach to an existing branch: drop -b

# Seed git-ignored dev files (a worktree only checks out tracked files, so these
# are missing and local runs break). List them in the repo's AGENTS.md; skip if none.
for rel in apps/frieren/.env apps/frieren/.dev.vars apps/frieren/.agent; do
  [ -f "$REPO_ROOT/$rel" ] && { mkdir -p "$WT_DIR/$(dirname "$rel")"; cp "$REPO_ROOT/$rel" "$WT_DIR/$rel"; }
done
echo "WT_DIR=$WT_DIR SESSION=$SESSION"
```

Write your instruction verbatim into `$WT_DIR/TASK.md` (use the `write` tool),
then launch:

```bash
tmux new-session -d -s "$SESSION" -c "$WT_DIR"
tmux send-keys -t "$SESSION" "pi --name $SESSION @TASK.md" Enter
```

`@TASK.md` becomes the spawned agent's auto-submitted opening prompt (quote-safe,
multi-line-safe). Launching via the shell (not as the tmux command) keeps your
login PATH so `pi` resolves and leaves a shell in the pane when pi exits. Report
`SESSION` and `WT_DIR` to the user.

## Observe / steer / clean up

```bash
tmux ls; git worktree list                                              # enumerate
tmux capture-pane -pt "$SESSION" | tail -n 40                           # peek (no attach)
tmux send-keys -t "$SESSION" -l "also add tests"; tmux send-keys -t "$SESSION" Enter   # steer
git -C "$WT_DIR" log --oneline -5                                       # progress (agent commits when done)
tmux attach -t "$SESSION"        # co-drive; Ctrl+b d to detach. Use switch-client if already inside tmux.

tmux kill-session -t "$SESSION"; git worktree remove "$WT_DIR"; git worktree prune   # teardown (add --force if dirty)
```

## Notes

- **Parallel**: repeat with different `SLUG`s; each gets its own branch/worktree/session.
- **No "done" signal**: poll `capture-pane` or `git -C "$WT_DIR" log`.
- **tmux session names** can't contain `.`/`:` — the `tr` step sanitizes them.
