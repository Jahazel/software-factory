#!/usr/bin/env python3
"""Exercise the review CLI with an isolated external reviewer executable."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

RUNNER = Path(__file__).resolve().parents[1] / "scripts/review.py"
FAKE = '''#!/usr/bin/env python3
import json, os, subprocess, sys, time
prompt = sys.stdin.read()
mode = os.environ.get("REVIEW_TEST_MODE", "success")
if mode == "hang":
    subprocess.Popen([sys.executable, "-c", "import time; from pathlib import Path; time.sleep(1.5); Path(" + repr(os.environ["REVIEW_TEST_SURVIVOR"]) + ").touch()"])
    print("partial finding", flush=True)
    time.sleep(30)
if mode == "failure":
    sys.exit(1)
if mode == "invalid":
    print("not a result")
    sys.exit(0)
ready = os.path.join(os.environ["FACTORY_REVIEW_DIR"], str(os.getpid()) + ".ready")
open(ready, "w").close()
import glob
deadline = time.monotonic() + 1
while len(glob.glob(os.path.join(os.environ["FACTORY_REVIEW_DIR"], "*.ready"))) < 2:
    if time.monotonic() >= deadline:
        sys.exit(1)
    time.sleep(0.02)
time.sleep(0.2)
print(json.dumps({"type": "result", "subtype": "success", "is_error": mode == "error", "result": prompt, "usage": {"input_tokens": 10}}))
'''


class ReviewCLI(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        binary = self.root / "claude"
        binary.write_text(FAKE)
        binary.chmod(0o700)
        self.prompt = self.root / "prompt.md"
        self.prompt.write_text("Review the issue requirements.")
        self.env = {**os.environ, "PATH": f"{self.root}:{os.environ['PATH']}",
                    "FACTORY_REVIEW_DIR": str(self.root / "reports"),
                    "FACTORY_REVIEW_WARN_SECONDS": "0.1",
                    "FACTORY_REVIEW_LIMIT_SECONDS": "2",
                    "REVIEW_TEST_SURVIVOR": str(self.root / "survivor")}

    def command(self, kind="initial"):
        return ["python3", str(RUNNER), kind, str(self.prompt), str(self.prompt)]

    def run_round(self, kind="initial"):
        return subprocess.run(self.command(kind), env=self.env, text=True,
                              capture_output=True, timeout=6)

    def status(self, number=1):
        return json.loads((self.root / f"reports/round-{number}/status.json").read_text())

    def test_parallel_reports_warning_and_round_cap(self):
        first = self.run_round()
        self.assertEqual(first.returncode, 0, first.stderr + first.stdout)
        self.assertIn("::warning::", first.stdout)
        self.assertEqual(self.status()["status"], "completed")
        for axis in ("standards", "spec"):
            report = json.loads((self.root / f"reports/round-1/{axis}.json").read_text())
            self.assertEqual(report["usage"]["input_tokens"], 10)
            self.assertEqual(report["result"], self.prompt.read_text())
        self.assertNotEqual(self.run_round().returncode, 0)
        self.assertEqual(self.run_round("fix").returncode, 0)
        self.assertNotEqual(self.run_round("fix").returncode, 0)
        self.assertEqual(len(list((self.root / "reports").glob("round-*"))), 2)

    def test_fix_cannot_be_first(self):
        self.assertNotEqual(self.run_round("fix").returncode, 0)
        self.assertFalse(list((self.root / "reports").glob("round-*")))

    def test_timeout_retains_findings_and_kills_descendants(self):
        self.env.update(REVIEW_TEST_MODE="hang", FACTORY_REVIEW_LIMIT_SECONDS="0.3")
        result = self.run_round()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.status()["status"], "incomplete")
        self.assertIn("time limit", self.status()["reason"])
        self.assertIn("partial finding", (self.root / "reports/round-1/spec.json").read_text())
        self.assertNotEqual(self.run_round("fix").returncode, 0)
        time.sleep(1.6)
        self.assertFalse((self.root / "survivor").exists())

    def test_reviewer_failure_and_invalid_results_cannot_pass(self):
        for mode in ("failure", "invalid", "error"):
            with self.subTest(mode=mode):
                self.env.update(REVIEW_TEST_MODE=mode, FACTORY_REVIEW_DIR=str(self.root / mode))
                self.assertNotEqual(self.run_round().returncode, 0)
                status = json.loads((self.root / mode / "round-1/status.json").read_text())
                self.assertEqual(status["status"], "incomplete")

    def test_signal_and_concurrent_round_fail_closed(self):
        self.env.update(REVIEW_TEST_MODE="hang", FACTORY_REVIEW_LIMIT_SECONDS="5")
        process = subprocess.Popen(self.command(), env=self.env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 2
            report = self.root / "reports/round-1/spec.json"
            while not report.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(report.exists())
            self.assertNotEqual(self.run_round("fix").returncode, 0)
            process.terminate()
            process.communicate(timeout=3)
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual(self.status()["status"], "incomplete")
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main(verbosity=2)
