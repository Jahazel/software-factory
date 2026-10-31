# Bounded reviews

A worker runs one initial review and up to two fix reviews with retained reports.

## Sub-features

- Concurrent Standards and Spec reports.
- Warning, timeout, process cleanup and incomplete outcomes.
- Round ordering, cap and rejection of concurrent invocations.

## How to get to it (user POV)

The factory code-review skill invokes `python3 "$FACTORY_REVIEW_RUNNER" initial|fix`
with two prompt files. The workflow sets the runner and report paths.

## Driving it with Bash

Preconditions: Python 3 and Bash are available.
Run `bash tests/review.sh`. Require all five integration scenarios to pass.
The timeout case verifies preserved findings and the absence of a delayed child
process side effect. Successful reports retain usage and both prompt results.

## Gotchas

The external model is a fake executable. This proves process supervision, not live
review quality or installed skill selection. A real worker run must verify those.
