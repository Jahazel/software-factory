import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("steps.py")


class StepCommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.playbook = self.root / "playbook.md"
        self.playbook.write_text("1. Run checks.\n2. Review results.\n")
        self.record = self.root / "steps.json"
        self.proof = self.root / "proof.txt"
        self.proof.write_text("Checks passed.\n")
        self.run_command("init", "--playbook", self.playbook, "--output", self.record)

    def run_command(self, *args, status=0):
        result = subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        return result

    def batch(self, updates, status=0):
        source = self.root / "updates.json"
        source.write_text(json.dumps(updates))
        return self.run_command("batch", self.record, "--updates", source, status=status)

    def test_batch_records_results_with_compact_output(self):
        result = self.batch([
            {"step": 1, "state": "completed", "reason": "Checks passed.",
             "evidence": [str(self.proof)]},
            {"step": 2, "state": "not-applicable", "reason": "Outside authorization."},
        ])
        saved = json.loads(self.record.read_text())
        self.assertEqual([s["state"] for s in saved["steps"]], ["completed", "not-applicable"])
        self.assertEqual(saved["steps"][0]["evidence"][0]["path"], str(self.proof.resolve()))
        self.assertEqual(len(result.stdout.splitlines()), 1)
        self.run_command("check", self.record)

    def test_invalid_batches_leave_record_unchanged(self):
        valid = {"step": 1, "state": "completed", "reason": "Passed.",
                 "evidence": [str(self.proof)]}
        second = {"step": 2, "state": "not-applicable", "reason": "Condition false."}
        cases = [[], {}, [valid, valid], [valid, {**second, "step": 3}],
                 [valid, {**second, "step": True}], [valid, {**second, "state": "passed"}],
                 [valid, {**second, "reason": ""}], [valid, {**second, "reason": None}],
                 [valid, {**second, "evidence": "proof.txt"}],
                 [valid, {**second, "evidence": [None]}],
                 [valid, {**second, "unexpected": "ignored?"}], [valid, "step 2"],
                 [valid, {**second, "state": "completed"}],
                 [valid, {**second, "evidence": [str(self.root / "absent")]}],
                 [valid, {**second, "state": "substituted", "evidence": [str(self.proof)]}]]
        before = self.record.read_bytes()
        for updates in cases:
            with self.subTest(updates=updates):
                self.batch(updates, status=1)
                self.assertEqual(self.record.read_bytes(), before)

    def test_malformed_json_leaves_record_unchanged(self):
        source = self.root / "updates.json"
        source.write_text("[{broken")
        before = self.record.read_bytes()
        self.run_command("batch", self.record, "--updates", source, status=1)
        self.assertEqual(self.record.read_bytes(), before)

    def test_pending_and_blocked_steps_fail_final_check(self):
        self.run_command("check", self.record, status=1)
        self.batch([{"step": 1, "state": "blocked", "reason": "Reviewer unavailable."}])
        result = self.run_command("check", self.record, status=1)
        self.assertIn("blocked", result.stdout)

    def test_reuse_and_substitution_preserve_details(self):
        self.batch([
            {"step": 1, "state": "reused", "reason": "Revision abc; unchanged check scope.",
             "evidence": [str(self.proof)]},
            {"step": 2, "state": "substituted", "reason": "CLI task.",
             "evidence": [str(self.proof)], "coverage": "Command output and saved state.",
             "limits": "Does not prove agent adoption."},
        ])
        self.run_command("check", self.record)
        saved = json.loads(self.record.read_text())["steps"][1]
        self.assertEqual(saved["coverage"], "Command output and saved state.")
        self.assertEqual(saved["limits"], "Does not prove agent adoption.")

    def test_set_still_works_and_changed_evidence_blocks_later_updates(self):
        result = self.run_command("set", self.record, "--step", 1, "--state", "completed",
                                 "--reason", "Passed.", "--evidence", self.proof)
        self.assertEqual(len(result.stdout.splitlines()), 1)
        before = self.record.read_bytes()
        self.proof.write_text("Changed after recording.")
        self.batch([{"step": 2, "state": "not-applicable", "reason": "Condition false."}], status=1)
        self.assertEqual(self.record.read_bytes(), before)
        self.run_command("check", self.record, status=1)

    def test_changed_playbook_blocks_batch(self):
        before = self.record.read_bytes()
        self.playbook.write_text("1. Different work.\n")
        self.batch([{"step": 1, "state": "not-applicable", "reason": "Condition false."}], status=1)
        self.assertEqual(self.record.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
