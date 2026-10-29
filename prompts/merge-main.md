1. Run `git fetch origin main`, then `git merge origin/main`.
2. A conflict that the project rules allow you to resolve: resolve it as they say. Any other conflict: run `git merge --abort` and block. Name the conflicting files and the PR that changed them.
3. When the merge changes dependency or migration files, install from the merged lockfile and apply schema updates with the project's documented commands. Reuse the running services from project setup. Do not rerun a setup command that recreates those services.
4. Run the project's checks again. When one fails because of the merged changes and the fix is not clear, block.
