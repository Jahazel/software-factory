#!/usr/bin/env python3
"""Keep playbook steps and their evidence in a task-local JSON file."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile


STATES = ("pending", "completed", "reused", "substituted", "not-applicable", "blocked")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_steps(path):
    steps = re.findall(r"^\d+\. .+(?:\n[ \t]+.+)*", path.read_text(), re.M)
    if not steps:
        raise ValueError("The playbook has no numbered steps.")
    return steps


def validate(record):
    playbook = Path(record["playbook"])
    if digest(playbook) != record["playbook_sha256"]:
        raise ValueError("The playbook changed. Reconcile the recorded steps before continuing.")
    if [step["text"] for step in record["steps"]] != read_steps(playbook):
        raise ValueError("Keep every playbook step verbatim and in order.")
    for step in record["steps"]:
        state = step["state"]
        if state not in STATES:
            raise ValueError("Unknown step state: " + state)
        if state != "pending" and not step.get("reason", "").strip():
            raise ValueError("Explain each step disposition.")
        if state in ("completed", "reused", "substituted") and not step.get("evidence"):
            raise ValueError("Completed, reused, and substituted steps need evidence files.")
        if state == "substituted" and not all(step.get(k, "").strip() for k in ("coverage", "limits")):
            raise ValueError("A substitution needs acceptance-criteria coverage and limits.")
        for item in step.get("evidence", []):
            if digest(Path(item["path"])) != item["sha256"]:
                raise ValueError("Evidence changed: " + item["path"])


def apply_updates(record, updates):
    if not isinstance(updates, list) or not updates:
        raise ValueError("Supply a nonempty JSON array of step updates.")
    seen = set()
    fields = {"step", "state", "reason", "evidence", "coverage", "limits"}
    for update in updates:
        if not isinstance(update, dict) or set(update) - fields:
            raise ValueError("Each update must be an object with supported step fields.")
        number = update.get("step")
        if type(number) is not int or not 1 <= number <= len(record["steps"]):
            raise ValueError("Step number is outside the playbook.")
        if number in seen:
            raise ValueError("Duplicate step number: " + str(number))
        seen.add(number)
        if update.get("state") not in STATES:
            raise ValueError("Unknown state for step " + str(number))
        for field in ("reason", "coverage", "limits"):
            if not isinstance(update.get(field, ""), str):
                raise ValueError(field + " must be a string for step " + str(number))
        evidence = update.get("evidence", [])
        if not isinstance(evidence, list) or any(not isinstance(p, str) for p in evidence):
            raise ValueError("Evidence must be an array of file paths for step " + str(number))
        record["steps"][number - 1] = {
            "text": record["steps"][number - 1]["text"], "state": update["state"],
            "reason": update.get("reason", ""), "coverage": update.get("coverage", ""),
            "limits": update.get("limits", ""),
            "evidence": [{"path": str(Path(p).resolve(strict=True)), "sha256": digest(Path(p))}
                         for p in evidence],
        }
    validate(record)


def save_record(path, record):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as target:
            temporary = Path(target.name)
            target.write(json.dumps(record, indent=2) + "\n")
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init")
    init.add_argument("--playbook", type=Path, required=True)
    init.add_argument("--output", type=Path, required=True)
    update = commands.add_parser("set")
    update.add_argument("record", type=Path)
    update.add_argument("--step", type=int, required=True)
    update.add_argument("--state", choices=STATES, required=True)
    update.add_argument("--reason", default="")
    update.add_argument("--evidence", type=Path, action="append", default=[])
    update.add_argument("--coverage", default="")
    update.add_argument("--limits", default="")
    batch = commands.add_parser("batch", help="Validate and save several step updates together.")
    batch.add_argument("record", type=Path)
    batch.add_argument("--updates", type=Path, required=True, help="JSON array of step updates.")
    check = commands.add_parser("check")
    check.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "init":
            source = args.playbook.resolve(strict=True)
            record = {"playbook": str(source), "playbook_sha256": digest(source),
                      "steps": [{"text": text, "state": "pending"} for text in read_steps(source)]}
            with args.output.open("x") as target:
                target.write(json.dumps(record, indent=2) + "\n")
            print("Created step record: " + str(args.output))
            return 0
        record = json.loads(args.record.read_text())
        if args.command in ("set", "batch"):
            if args.command == "batch":
                updates = json.loads(args.updates.read_text())
            else:
                updates = [{"step": args.step, "state": args.state, "reason": args.reason,
                            "coverage": args.coverage, "limits": args.limits,
                            "evidence": [str(p) for p in args.evidence]}]
            apply_updates(record, updates)
            save_record(args.record, record)
            print(f"Updated {len(updates)} step(s): {args.record}")
            return 0
        else:
            validate(record)
        for index, step in enumerate(record["steps"], 1):
            print(f"{index}. {step['state']}: {step['text']}")
        if args.command == "check":
            if any(s["state"] in ("pending", "blocked") for s in record["steps"]):
                print("INCOMPLETE: pending or blocked steps remain.")
                return 1
            print("ACCOUNTED: inspect reuse, substitutions, applicability, and evidence before reporting completion.")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("INCOMPLETE: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
