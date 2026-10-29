1. Run `git fetch origin main`, then `git merge origin/main`.
2. A conflict that the project rules allow you to resolve: resolve it as they say. Any other conflict: run `git merge --abort` and block. Name the conflicting files and the PR that changed them.
3. Run the project's checks again. When one fails because of the merged changes and the fix is not clear, block.
