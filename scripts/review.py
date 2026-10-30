#!/usr/bin/env python3
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def stop(process):
    process.poll()
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("initial", "fix"):
        sys.exit("Usage: review.py initial|fix STANDARDS_PROMPT SPEC_PROMPT")
    prompts = [Path(path).read_text() for path in sys.argv[2:]]
    root = Path(os.environ["FACTORY_REVIEW_DIR"])
    root.mkdir(parents=True, exist_ok=True)
    with (root / "lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit("Review incomplete: another round is running.")
        rounds = sorted(root.glob("round-*"))
        if len(rounds) >= 2 or (sys.argv[1] == "initial") != (len(rounds) == 0):
            sys.exit("Review incomplete: initial review plus one fix round only.")
        if rounds:
            previous = json.loads((rounds[-1] / "status.json").read_text())
            if previous["status"] != "completed":
                sys.exit("Review incomplete: a failed or interrupted round cannot retry.")
        directory = root / f"round-{len(rounds) + 1}"
        directory.mkdir()
        status = {"status": "incomplete", "kind": sys.argv[1]}
        status_path = directory / "status.json"
        status_path.write_text(json.dumps(status) + "\n")
        processes = []
        outputs = []
        started = time.monotonic()
        warning = float(os.environ.get("FACTORY_REVIEW_WARN_SECONDS", "300"))
        limit = float(os.environ.get("FACTORY_REVIEW_LIMIT_SECONDS", "600"))
        warned = False
        try:
            for axis, prompt in zip(("standards", "spec"), prompts):
                output = (directory / f"{axis}.json").open("w")
                outputs.append(output)
                error = (directory / f"{axis}.stderr").open("w")
                outputs.append(error)
                with (directory / f"{axis}.prompt.md").open("w+") as source:
                    source.write(prompt)
                    source.seek(0)
                    processes.append(subprocess.Popen(
                        ["claude", "-p", "--model", "claude-opus-5-5", "--effort", "high",
                         "--permission-mode", "plan", "--no-session-persistence",
                         "--output-format", "json"],
                        stdin=source, stdout=output, stderr=error, start_new_session=True,
                    ))
            while True:
                elapsed = time.monotonic() - started
                if elapsed >= limit:
                    status["reason"] = "Review time limit reached; block and retain findings."
                    break
                if all(process.poll() is not None for process in processes):
                    break
                if elapsed >= warning and not warned:
                    print("::warning::Review has reached its warning time.", flush=True)
                    warned = True
                time.sleep(0.1)
            if "reason" not in status:
                for output in outputs:
                    output.flush()
                results = [json.loads((directory / f"{axis}.json").read_text())
                           for axis in ("standards", "spec")]
                if all(process.returncode == 0 for process in processes) and all(
                    result.get("type") == "result" and result.get("subtype") == "success"
                    and not result.get("is_error") and result.get("result", "").strip()
                    for result in results
                ):
                    status["status"] = "completed"
                else:
                    status["reason"] = "A reviewer failed or returned an incomplete report."
        except (OSError, ValueError, KeyboardInterrupt) as error:
            status["reason"] = str(error)
        finally:
            for process in processes:
                stop(process)
            for output in outputs:
                output.close()
            status["elapsed_seconds"] = round(time.monotonic() - started, 3)
            status_path.write_text(json.dumps(status) + "\n")
        print(json.dumps({**status, "reports": str(directory)}), flush=True)
        return 0 if status["status"] == "completed" else 1


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    sys.exit(main())
