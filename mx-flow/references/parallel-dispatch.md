# 5a-parallel — parallel batch execution (mx-flow)

> Read this only when Phase 5a's mode selection produced a parallel batch
> of ≥ 2 tasks. Everything here supplements — never overrides — mx-flow's
> Non-negotiables and gate table.

Each task in the batch runs in its **own isolated git worktree**.
Sub-agents work freely — full TDD cycle, commits via `/mx-commit`, full
test suite — with no shared state to race against. The parent reconciles
by cherry-picking each sub-branch back onto the feature branch in
`task_id` order.

## Pre-flight

```bash
git status --porcelain          # must be empty — abort otherwise
BATCH_BASE=$(git rev-parse HEAD)
```

Record `BATCH_BASE` in conversation context. It is the rollback anchor and
the merge base for every cherry-pick in this batch.

## Dispatch

Issue one `Agent` call **per task in a single message** so all sub-agents
run concurrently. For each task:

- **subagent_type**: omit (default catch-all) — sub-agents need
  Edit/Write/Bash.
- **model**: mid tier (`sonnet`) by default. A task scoped `complexity: L`
  that also touches concurrency or a public API → strongest tier
  (see `../../mx-doctrine/references/model-dispatch.md` §4; if that file
  is missing, stay on the default).
- **isolation**: `"worktree"` — the harness creates a temporary worktree
  branched from the parent's current HEAD (= `BATCH_BASE`) and surfaces
  the branch name + path on completion.
- **Brief contents:**
  - "You are running one task of a parallel TDD batch in mx-flow. You are
    isolated in your own git worktree — work freely; you cannot collide
    with sibling sub-agents."
  - Task ID and full task body copied from `plan.md` (What, Test, Files).
  - `predicted_files` and `predicted_touches` for this task — **advisory
    only**, not a constraint. Touch whatever the implementation actually
    needs.
  - One-line summaries of sibling tasks in the batch (awareness only —
    "if you find yourself doing a sibling's work, stop and return
    `status: failed` with reason").
  - Iron Law (Non-negotiable 2 in SKILL.md), vertical-slice TDD philosophy
    and comment policy (both in 5a-sequential) — copy the same wording
    those sections use, do not paraphrase.
  - **Sub-agent workflow (verbatim in the brief):**
    1. Read existing code relevant to your task.
    2. Iron Law: write a failing test before any production code.
    3. RED → GREEN → REFACTOR, one slice at a time.
    4. Honor the comment policy.
    5. Run the full project test suite — your worktree is isolated, this
       is safe.
    6. Run `/mx-commit` to commit your changes (one or more commits). Do
       not push.
    7. Return the YAML block below as the final content of your last
       message.
  - **Required return shape:**
    ```yaml
    status: success | failed
    task_id: task-<N>
    branch: <result of `git rev-parse --abbrev-ref HEAD`; the harness also surfaces this>
    worktree_path: <result of `git rev-parse --show-toplevel`>
    commits: [<commit hashes you created, oldest first>]
    files_changed: [<repo-relative paths>]
    test_summary: "<all tests passed | N failed — details>"
    failure_reason: "<populated when status: failed; empty otherwise>"
    ```

## Reconcile (parent runs serially after **all** sub-agents return)

1. **Status triage:**
   - `status: failed` → leave the sub-worktree intact for inspection,
     enqueue this task into the sequential queue. Do not cherry-pick
     anything for failed tasks.
   - `status: success` → proceed to cherry-pick.

2. **Cherry-pick successful tasks in `task_id` ascending order.** For each
   task:
   ```bash
   git cherry-pick <BATCH_BASE>..<sub-branch>
   ```
   - **Clean apply** → continue with next task.
   - **Conflict** → conflict triage (step 3).

3. **Conflict triage** — parent judges each conflict:
   - **Trivial conflict** — both sides added independent, non-overlapping
     content to the same region (e.g., two new imports in the same import
     block, two appended test cases at the end of a file, two new entries
     in a registry slice). Parent resolves by combining both sides
     preserving order, then:
     ```bash
     git add <resolved files>
     git cherry-pick --continue
     ```
   - **Non-trivial conflict** — both sides semantically modified the same
     region, or it is unclear how to combine. Parent aborts the in-flight
     cherry-pick:
     ```bash
     git cherry-pick --abort
     ```
     Enqueue this task into the sequential queue. Continue with the
     **next** task in cherry-pick order — already-applied tasks stay on
     the feature branch (incremental progress; no full rollback).

   Calibration:
   - "Two imports added to the same import group" → trivial.
   - "Two new test cases appended to the same test file" → trivial.
   - "Both sides renamed the same function" → non-trivial.
   - "Both sides changed the signature of the same function" → non-trivial.
   - "Side A renamed X, Side B added a call site for X" → non-trivial
     (semantic — cherry-pick won't catch the broken call).

4. **Integration test:** after all cherry-picks complete (clean or
   aborted), run the full project test suite on the feature branch
   (runner priority from Phase 4.4).
   - **Pass** → batch done; proceed to step 5.
   - **Fail** → batch-scoped rollback (Abort path below). An integration
     failure that wasn't seen in any sub-agent's isolated full-suite run
     means the tasks were not truly independent. Enqueue **all** in-flight
     batch tasks (including the cleanly cherry-picked ones) back into the
     sequential queue.

5. **Update `plan.md`:** mark each successfully cherry-picked +
   integration-passing task `[x]`. Single writer (parent) — no race.

6. **Cleanup** sub-worktrees and sub-branches for tasks that landed
   cleanly (worktrees with changes are not auto-cleaned by the harness):
   ```bash
   git worktree remove <worktree_path>
   git branch -D <branch>
   ```
   (`-D` is safe here: these are internal, just-cherry-picked sub-task
   branches. The never-force-delete-automatically rule protects the
   user-facing feature branch in Phase 8, not these.)
   **Keep** the sub-worktree and sub-branch intact when the task was
   bounced to sequential — the user (or a sequential-mode rerun) may want
   to inspect what the sub-agent produced before discarding.

7. **Announce:** `Parallel batch B<n>: <K> cherry-picked, <C> bounced to
   sequential, <wall-time>s.`

## Abort path (batch-scoped rollback — fires only on integration-test failure after merge)

```bash
# Safety: only reset if every commit between BATCH_BASE and HEAD was made by the parent's cherry-picks.
EXPECTED_PICKS=<count of successful cherry-picks the parent ran>
ACTUAL_AHEAD=$(git rev-list --count $BATCH_BASE..HEAD)
if [ "$ACTUAL_AHEAD" -ne "$EXPECTED_PICKS" ]; then
  STOP and ask the user. Do not run git reset.
fi

git reset --hard $BATCH_BASE
```

Then push all batch tasks (cherry-picked and not) back to the sequential
queue. Clean up sub-worktrees as in step 6 above.

Report:
```
Parallel batch B<n> aborted at integration test: <failure summary>. Re-running <K> tasks sequentially.
```

## When to skip 5a-parallel entirely

Drain everything via 5a-sequential when **any** of:
- The user has uncommitted work in the worktree before the batch starts.
- A prior batch in this flow was aborted at the integration-test step —
  fall back to sequential for the remainder; do not re-attempt parallel in
  the same flow.
