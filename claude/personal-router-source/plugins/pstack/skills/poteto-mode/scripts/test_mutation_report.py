import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).with_name("mutation-report")

RESULTS = textwrap.dedent("""\
    KILLED    src/lib/clock.ts:4 / -> *
    SURVIVED  src/lib/clock.ts:22 - -> +
    Function   Namespace   Killed  Survived  Uncovered  Sites   Score
    -----------------------------------------------------------------
    tick       lib.clock        1         1          1      3  50.0%
    -----------------------------------------------------------------
    Total                       1         1          1      3  50.0%
""")

NOTHING_RAN = textwrap.dedent("""\
    Function   Namespace   Killed  Survived  Uncovered  Sites   Score
    Total                       0         0          9      9    n/a
""")


def git(cwd, *args):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def head(cwd):
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=cwd, check=True,
                          capture_output=True, text=True).stdout.strip()


class MutationReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.tools = root / "tools"
        self.calls = root / "calls.json"
        self.lock = root / "tools.lock"
        self.child_pid = root / "child.pid"
        self.write_tools()
        self.repo = root / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "T")
        self.write("README.md", "start\n")
        self.write("src/lib/old.ts", "export const old = 1;\n")
        self.commit("start")
        git(self.repo, "checkout", "-q", "-b", "issue-1")

    def write_tools(self, exit_code=3, output=RESULTS, start_child_then_stop_parent=False):
        mutator = self.tools / "mutator"
        mutator.mkdir(parents=True, exist_ok=True)
        (self.tools / "crapper").mkdir(exist_ok=True)
        fake = mutator / "mutator"
        fake.write_text(textwrap.dedent(f"""\
            #!{sys.executable}
            import json, os, signal, subprocess, sys, time
            from pathlib import Path
            Path({str(self.calls)!r}).write_text(json.dumps({{
                "args": sys.argv[1:], "cwd": os.getcwd(),
                "seen": [name for name in ("coverage", ".metrics") if Path(name).exists()],
                "blocked": sorted(s.name for s in signal.pthread_sigmask(signal.SIG_BLOCK, []))}}))
            Path(".metrics/mutate").mkdir(parents=True, exist_ok=True)
            Path(".metrics/mutate/new.edn").write_text("new")
            Path("target/mutation-workers").mkdir(parents=True, exist_ok=True)
            if {start_child_then_stop_parent!r}:
                child = subprocess.Popen(["sleep", "30"], start_new_session=True)
                Path({str(self.child_pid)!r}).write_text(str(child.pid))
                os.kill(os.getppid(), signal.SIGTERM)
                time.sleep(30)
            sys.stdout.write({output!r})
            sys.exit({exit_code})
            """))
        fake.chmod(0o755)
        for name in ("crapper", "mutator"):
            repo = self.tools / name
            if not (repo / ".git").exists():
                git(repo, "init", "-q")
                git(repo, "config", "user.email", "t@example.com")
                git(repo, "config", "user.name", "T")
            git(repo, "add", "-A")
            git(repo, "commit", "-q", "--allow-empty", "-m", "pin")
        self.lock.write_text("".join(f"{name} {head(self.tools / name)}\n"
                                     for name in ("crapper", "mutator")))

    def write(self, name, text):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self, message):
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", message)

    def command(self, *args, tools=None):
        return [sys.executable, str(SCRIPT), "--base", "main", "--tools", str(tools or self.tools),
                "--lock", str(self.lock), *args]

    def run_report(self, *args, status=0, cwd=None, tools=None):
        result = subprocess.run(self.command(*args, tools=tools), cwd=cwd or self.repo,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        return result

    def mutator_call(self):
        return json.loads(self.calls.read_text())

    def mutator_args(self):
        return self.mutator_call()["args"]

    def vitest_command(self):
        args = self.mutator_args()
        return args[args.index("--test-command") + 1]

    def test_reports_score_and_missed_changes_for_the_branch(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        out = self.run_report().stdout

        self.assertIn("src/lib/clock.ts", self.mutator_args())
        self.assertNotIn("src/lib/old.ts", self.mutator_args())
        self.assertIn("Changes tried: 2 · caught: 1 · missed: 1 · score 50.0%", out)
        self.assertIn("Not run by any test: 1", out)
        self.assertIn("src/lib/clock.ts:22 - -> +", out)

    def test_lists_only_the_files_mutator_changed(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.write("docs/notes.md", "notes\n")
        self.commit("add clock and notes")

        out = self.run_report().stdout

        self.assertIn("Files: src/lib/clock.ts\n", out)

    def test_passes_only_files_that_still_exist(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        (self.repo / "src/lib/old.ts").unlink()
        self.commit("replace old with clock")

        self.run_report()

        self.assertNotIn("src/lib/old.ts", self.mutator_args())

    def test_vitest_project_runs_only_the_tests_related_to_changed_files(self):
        self.write("package.json", json.dumps({"devDependencies": {"vitest": "^3"}}))
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        command = self.vitest_command()
        self.assertTrue(command.startswith("npx vitest related --run"), command)
        self.assertIn("--maxWorkers=1", command.split())
        self.assertIn("src/lib/clock.ts", command)
        self.assertNotIn("package.json", command)

    def test_quotes_file_names_the_shell_would_misread(self):
        self.write("package.json", json.dumps({"devDependencies": {"vitest": "^3"}}))
        self.write("src/app/(shop)/[id]/page.tsx", "export default 1;\n")
        self.commit("add page")

        self.run_report()

        words = shlex.split(self.vitest_command())
        self.assertEqual(words[-1], "src/app/(shop)/[id]/page.tsx")

    def test_hides_old_coverage_and_history_during_the_run_and_restores_them(self):
        self.write("coverage/lcov.info", "old coverage\n")
        self.write(".metrics/mutate/old.edn", "old history\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        self.assertEqual(self.mutator_call()["seen"], [])
        self.assertEqual((self.repo / "coverage/lcov.info").read_text(), "old coverage\n")
        self.assertEqual(sorted(p.name for p in (self.repo / ".metrics/mutate").iterdir()),
                         ["old.edn"])

    def test_leaves_out_changed_files_inside_the_tool_folders(self):
        self.write(".metrics/crap.edn", "{}\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock and metrics")

        out = self.run_report().stdout

        self.assertNotIn(".metrics/crap.edn", self.mutator_args())
        self.assertIn("1 changed file in tool folders was left out", out)

    def test_accepts_a_tools_path_relative_to_where_it_was_started(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report(cwd=self.repo / "src", tools=Path("..") / ".." / self.tools.name)

        self.assertIn("src/lib/clock.ts", self.mutator_args())

    def test_tools_start_with_no_signals_blocked(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        blocked = set(self.mutator_call()["blocked"])
        self.assertFalse(blocked & {"SIGTERM", "SIGHUP", "SIGINT"}, blocked)

    def test_names_left_out_files_when_no_source_file_changed(self):
        self.write_tools(exit_code=0, output="No source files to mutate.\n")
        self.write("README.md", "changed\n")
        self.write(".metrics/x.edn", "{}\n")
        self.commit("change docs and metrics")

        out = self.run_report().stdout

        self.assertIn("No changed source files", out)
        self.assertIn("1 changed file in tool folders was left out", out)

    def test_runs_from_the_repo_root_when_started_in_a_subfolder(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report(cwd=self.repo / "src")

        self.assertIn("src/lib/clock.ts", self.mutator_args())

    def test_cleans_up_and_stops_every_tool_process_when_the_run_is_stopped(self):
        self.write_tools(start_child_then_stop_parent=True)
        self.write("coverage/lcov.info", "old coverage\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        result = subprocess.run(self.command(), cwd=self.repo, capture_output=True,
                                text=True, timeout=20)

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.calls.exists())
        child = int(self.child_pid.read_text())
        alive = subprocess.run(["ps", "-o", "stat=", "-p", str(child)],
                               capture_output=True, text=True).stdout.strip()
        self.assertTrue(alive == "" or alive.startswith("Z"), alive)
        self.assertFalse((self.repo / ".metrics").exists())
        self.assertFalse((self.repo / "target").exists())
        self.assertEqual((self.repo / "coverage/lcov.info").read_text(), "old coverage\n")

    def test_never_reuses_an_old_coverage_report(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        self.assertNotIn("--use-existing-coverage", self.mutator_args())

    def test_says_when_only_tool_folder_files_changed(self):
        self.write("coverage/notes.ts", "export const x = 1;\n")
        self.commit("add a file in a tool folder")

        out = self.run_report().stdout

        self.assertIn("1 changed file in tool folders was left out", out)
        self.assertFalse(self.calls.exists())

    def test_branch_without_changed_files_reports_nothing_to_check(self):
        out = self.run_report().stdout

        self.assertIn("No changed files", out)
        self.assertFalse(self.calls.exists())

    def test_fails_when_no_change_was_tried(self):
        self.write_tools(exit_code=0, output=NOTHING_RAN)
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        result = self.run_report(status=1)

        self.assertIn("no change was tried", result.stderr)

    def test_fails_when_the_tests_fail_before_any_change(self):
        self.write_tools(exit_code=2, output="Baseline failed for src/lib/clock.ts: npx vitest\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        result = self.run_report(status=1)

        self.assertIn("tests failed before any change", result.stderr)

    def test_names_the_exit_code_when_mutator_stops_for_another_reason(self):
        self.write_tools(exit_code=2, output="crapper is not installed\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        result = self.run_report(status=1)

        self.assertIn("mutator exited 2", result.stderr)
        self.assertNotIn("tests failed", result.stderr)

    def test_fails_when_a_tool_is_not_at_its_locked_version(self):
        self.lock.write_text("crapper 0000000\nmutator 0000000\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        result = self.run_report(status=1)

        self.assertIn("not at its locked version", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_removes_the_tool_folders_it_created(self):
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        self.assertFalse((self.repo / ".metrics").exists())
        self.assertFalse((self.repo / "target").exists())

    def test_keeps_tool_folders_that_were_already_there(self):
        self.write("target/keep.txt", "mine\n")
        self.write("src/lib/clock.ts", "export const tick = 1;\n")
        self.commit("add clock")

        self.run_report()

        self.assertTrue((self.repo / "target/keep.txt").exists())


if __name__ == "__main__":
    unittest.main()
