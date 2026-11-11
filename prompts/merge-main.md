1. Run `git rev-parse HEAD` and keep the hash: it is the head before the merge. Run `git fetch origin main`, then `git merge origin/main`.
2. Resolve each conflict whose path is not on the deny list. Keep what both sides meant: the change on this branch and the change on main. To learn what main meant, find the PR that changed the file: `git log origin/main -- <file>`, then `gh pr list --state merged --search <commit>`.
3. The deny list is the path prefixes the project rules or an owner comment name for it, such as `migrations/`. Resolve a conflict on the deny list only as the project rules or an owner comment say for that path. When they say nothing for it, block.
4. When the merge changes dependency or migration files, install from the merged lockfile and apply schema updates with the project's documented commands. Reuse the running services from project setup. Do not rerun a setup command that recreates those services.
5. Run the project's checks again. When one fails because of the merged changes and the fix is not clear, block.
6. When you resolved a conflict outside the deny list, review the merge as the next section says.
7. To block in these steps, first undo the merge: run `git merge --abort` while it is open, or `git reset --hard` to the head before the merge. Then name each conflicting file, if any, and the PR on main that changed it.
