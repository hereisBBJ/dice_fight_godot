#!/usr/bin/env python3
"""Record a selected generated row into an animation run."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()

    run_dir = Path(args.run_dir).resolve()
    manifest_path = run_dir / "imagegen-jobs.json"
    manifest = load_json(manifest_path)
    source = Path(args.source).resolve()
    if not source.exists():
        raise SystemExit("source does not exist: %s" % source)

    jobs = manifest.get("jobs", [])
    job = next((item for item in jobs if item.get("id") == args.job_id), None)
    if job is None:
        raise SystemExit("unknown job id: %s" % args.job_id)

    decoded_path = Path(job["decoded_path"])
    decoded_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, decoded_path)
    job["status"] = "completed"
    job["source_path"] = str(source)
    job["recorded_at"] = datetime.now(timezone.utc).isoformat()
    write_json(manifest_path, manifest)
    print("Recorded %s -> %s" % (source, decoded_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
