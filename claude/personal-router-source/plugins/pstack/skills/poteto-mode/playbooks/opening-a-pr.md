# Opening a PR

1. Inspect the final changes and target branch. Confirm scope. Stop all helpers that can still edit the working copy, including their helpers. Confirm they stopped through the runtime's supported controls. Then check the working copy's status and inspect the final changes. Use a separate checkout when unrelated edits or parallel agents need isolation; otherwise reuse the isolated current checkout.
2. Prepare small, ordered commits. Prefer several narrow PRs over one large PR, as pstack does. Use stacks for dependent PRs: the root targets trunk and each child targets its preceding branch.
3. Do not run or repeat checks. The calling playbook owns cleanup, verification, and review. Write in Evidence what the caller checked and reviewed. Write in Merge Danger what was not checked: any blocked or inconclusive check, and any step skipped under the small-change or medium-change rule. Never state that a check passed when it did not run.
4. Use `type(scope): subject` for the title. Write the body with `pr`.
5. Open ready for review. Use the runtime's built-in PR tool when it is available and supports the operation. Otherwise use the supported repository command-line tool. Register every PR with the current thread when the runtime requires it. Confirm actual status and target before reporting them.
6. Report each PR's URL. Continue until all PRs within the approved task are open. This does not authorize extra PRs. Ongoing monitoring and merging require separate requests.
7. List open items that the PRs do not cover in the reply. Follow-up work on these PRs, such as failed checks, review comments, or a local run, starts in a new session. That session uses [Babysit](babysit.md) for failed checks, review comments, and merge conflicts. When the owner asks for follow-up work in this session, give the PR URLs and ask for a new session. Answer status questions directly. Then stop.

## Skill references

- [pr](/Users/jahazelsanchez/.claude/skills/pr/SKILL.md).
