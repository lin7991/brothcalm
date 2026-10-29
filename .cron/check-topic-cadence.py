#!/usr/bin/env python3
"""Guard against publishing more than 3 articles in one cluster per 30 days.

Only queue entries with explicit related_cluster are evaluated. Legacy entries
without that metadata are reported as unclassified rather than guessed.
"""
from __future__ import annotations
import json, re, subprocess, sys
from datetime import date, timedelta
from pathlib import Path

WS = Path(__file__).resolve().parent.parent
QUEUE = WS / ".content-queue.json"

def git_published_paths():
    since = (date.today() - timedelta(days=30)).isoformat()
    out = subprocess.run(
        ["git", "-C", str(WS), "log", f"--since={since}", "--format=%s"],
        text=True, capture_output=True, check=False).stdout
    return [m.group(1).strip().rstrip("/") for line in out.splitlines()
            if (m := re.match(r"Publish:\s+(.+)$", line))]

def main():
    q = json.loads(QUEUE.read_text())
    by_path = {a.get("path", "").strip("/"): a for a in q.get("articles", [])}
    counts = {}
    unclassified = 0
    for path in git_published_paths():
        item = by_path.get(path)
        if not item or not item.get("related_cluster"):
            unclassified += 1
            continue
        cluster = str(item["related_cluster"]).strip().lower()
        counts[cluster] = counts.get(cluster, 0) + 1
    violations = {k: v for k, v in counts.items() if v >= 3}
    if violations:
        print("Topic cadence blocked; clusters already have 3 articles in 30 days:", violations)
        return 1
    print(f"Topic cadence OK: {len(counts)} classified clusters, {unclassified} legacy/unclassified publishes")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
