---
name: code-review
description: Review a factory change against its issue and applicable repository standards, using two bounded independent reviewers.
---

# Factory code review

Use the originating issue and its parent as the spec. Use the supplied fixed point,
or `git merge-base HEAD origin/main`. Confirm it resolves and that the committed
diff is nonempty. Keep the small, low-risk review exemption in the router.

## Scope and prompts

Write two prompt files for independent reviewers. Each must include the diff
command, commit list, issue requirements, relevant repository instruction paths,
and these scope rules:

- Check whether the change meets the issue and introduces defects. Trace affected
  callers when needed to prove a regression caused by the change.
- Report actionable findings with file and line, evidence, impact, and the issue
  requirement or changed behavior it violates.
- Exclude pre-existing defects, unrelated cleanup, optional improvements, and style
  preferences. Mention an unrelated discovery only under Open items; it cannot
  block this issue or trigger a fix or another review round.
- Stay read-only. Use tools to inspect and reproduce claims. Return a report under
  400 words. Run no nested reviewers or review skill.

The Standards prompt checks applicable documented standards in changed code where
a violation affects this issue's correctness or required conventions. The Spec
prompt checks missing requirements, incorrect behavior, and scope creep.

## Run the round

Run both axes through the supervisor, in the foreground:

```bash
python3 "$FACTORY_REVIEW_RUNNER" initial /absolute/standards.md /absolute/spec.md
```

The command starts fresh Claude Opus 5.5 processes at high effort. Both axes share
one round timer. It warns at five minutes and stops both process groups at ten
minutes. It retains prompts, JSON reports (including usage), errors, and elapsed
time under `$FACTORY_REVIEW_DIR`. Read reports only after the command exits.
Use actual process handles through this command to wait for completion.

A nonzero exit means incomplete review. Follow the worker's draft PR path. Preserve
available findings. Incomplete review is never a pass and has no automatic retry.
A zero exit means the reports completed; it does not mean their findings passed.

## Findings and two fix rounds

Present Standards and Spec separately. Fix only defects introduced by the change
or missing issue requirements. A serious finding breaks behavior, loses data,
affects security/privacy/money/authentication, or misses a spec requirement.
Keep unrelated discoveries in Open items without fixing them.

When a serious finding needs fixes, make and verify them, commit, then write two
new prompts containing the previous findings and the diff since the reviewed
commit. Focus on those fixes and their direct effects. Run:

```bash
python3 "$FACTORY_REVIEW_RUNNER" fix /absolute/standards-fix.md /absolute/spec-fix.md
```

Run at most two fix rounds. When the second fix round still reports serious
findings, fix them only when the fix is small and local, and run no fourth round.
Then follow the worker's draft PR path: list the remaining findings and evidence,
and name every commit no completed round reviewed. Keep cheap local non-serious
fixes only when verification proves them. These factory bounds replace the
router's unlimited fix-round rule.
