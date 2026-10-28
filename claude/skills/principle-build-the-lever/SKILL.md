---
name: principle-build-the-lever
description: "Apply when the same edit, check, or analysis repeats in more than about five places, or when a reviewer must rerun a check to trust the result: migrations, bulk renames, data comparisons. Build the tool that does it or proves it (codemod, script, generator, or a skill your subagents follow). The tool is the artifact a reviewer can rerun."
user-invocable: false
---
# Build the Lever

When the work repeats, or a check must be rerun to be trusted, build the tool that does it instead of doing it by hand.

A codemod, generator, or script does the work the same way every time and reruns for free. The tool is one artifact a reviewer can read and rerun to check the work. Hand-done changes can only be re-verified by redoing them. A deterministic script turns "trust me" into "run this".

Build the lever when the same change repeats in more than about five places, or when a rerunnable tool is what makes the result checkable. Make the edits by hand when they are few and a reviewer can check them by reading the diff.

- Do the first unit by hand to learn the recipe, then build the tool. Prove it by rerunning it on that unit and diffing against your hand-done version. Make the lever safe to rerun.
- For a comparison tool, seed one known-bad change for each output it claims to compare, and confirm the tool reports each mismatch. For example, change a total, then separately swap item assignments while keeping the totals. If required input is missing, the tool must refuse or report the result as inconclusive, never as a match. Keep these controls with the experiment and rerun them before you trust its results.
- Codemod or script for edits, generator for repetitive files, a dump-to-sqlite query for analysis, a rerunnable check for verification.
- A deterministic lever beats fan-out. If the tool can process every unit in one pass, run it yourself. Don't fan out delegates to hand-apply what a script can do.
- When you fan work out to subagents, write the lever as a skill they all read: the recipe, the verification contract, and the do-not-touch fences in one artifact. Keep it outside the delegates' write scope so they can't quietly edit the contract.
- Applying this principle produces a file. If you cited it and there is no codemod, script, generator, or delegate skill in the diff, you didn't apply it.
- Commit the lever when the work outlives the session.

A one-off earns a lever only when the lever is what makes the work checkable. Per the [Laziness Protocol](../principle-laziness-protocol/SKILL.md), build the smallest script that does or proves the job, never a framework.

Distinct from [Encode Lessons in Structure](../principle-encode-lessons-in-structure/SKILL.md), which makes a recurring instruction a durable guardrail. This is throughput and reviewability on the work in front of you. For scripting the verification itself, see [Prove It Works](../principle-prove-it-works/SKILL.md).
