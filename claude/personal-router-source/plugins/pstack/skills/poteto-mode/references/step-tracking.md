# Step tracking

Use `python3 <router>/scripts/steps.py init --playbook <playbook.md> --output <task>/steps.json` when selecting a playbook. Keep task-specific work in the checklist after the copied steps. Create a separate record for a nested playbook. Give each record one writer.

Group known results at a work boundary with `steps.py batch <record> --updates <updates.json>`. Record blockers when discovered. Each array entry has its own `step`, `state`, and `reason`. Add `evidence` as an array of proof file paths, and `coverage` and `limits` for substitutions. Paths resolve from the command's working directory.

```json
[
  {"step": 1, "state": "completed", "reason": "Checks passed.", "evidence": ["/task/checks.log"]},
  {"step": 2, "state": "not-applicable", "reason": "The task changes no browser path."}
]
```

The tool validates the whole batch before saving once. Invalid batches leave the record unchanged. Single updates still use `steps.py set <record> --step <number> --state <state> --reason <reason>`, with `--evidence <file>` for each proof file. Successful updates print a short confirmation. Full step details remain in the record and `check` output. Native task lists can point to the record rather than repeat its evidence notes.

The tool keeps the step text and file hashes. Use task-local, safe evidence files. Name only final files that will not change as evidence, such as a test result or a review resolution. Put notes and other facts in the reason.

| State | Required meaning |
| --- | --- |
| pending | Work has not reached a result. |
| completed | This run performed the step. Evidence shows its result. |
| reused | Earlier work satisfies the step. Record its revision, current scope, and the checks that establish reuse. |
| substituted | A different method covers the relevant acceptance criteria. Supply `--coverage` and `--limits`. |
| not-applicable | The step's condition is false or the action is outside authorization. Give the exact condition and reason. |
| blocked | A required result is unavailable. Name the missing result and keep the step incomplete. |

Run `steps.py check <record>` before handoff and PR creation. Resolve pending work. Report blocked work. Report reused, substituted, and not-applicable steps by name. A successful check means every step has a recorded disposition. Inspect the evidence to determine whether it proves the claim. The tool cannot judge truth, relevance, or authorization.

Keep a required unavailable check blocked. Use not-applicable only when its condition is false. For example, reused implementation does not establish a new test-first cycle. Database-login checks can replace browser checks for a SQL-only task when the task accepts that boundary. Record that they do not prove web sign-in.
