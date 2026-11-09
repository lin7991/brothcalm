#!/usr/bin/env python3
"""Report generated bilingual inventory and enforce production thresholds.

Inventory is counted in complete EN/ZH pairs. Pending-review pairs count too:
they are generated work that still needs a human decision and must not be
silently replaced by more production.
"""
from __future__ import annotations
import sys
from pathlib import Path

WS = Path(__file__).resolve().parent.parent
PENDING = WS / ".cron" / "pending"
REVIEW = WS / ".cron" / "pending-review"
SOFT_START = 10
HARD_CAP = 100

def pair_count(directory: Path) -> int:
    if not directory.exists():
        return 0
    return sum(
        1 for en in directory.glob("*.html")
        if not en.name.startswith("zh-")
        and (directory / f"zh-{en.name}").is_file()
    )

def orphan_count(directory: Path) -> int:
    if not directory.exists():
        return 0
    files = list(directory.glob("*.html"))
    return sum(
        1 for p in files
        if (p.name.startswith("zh-") and not (directory / p.name[3:]).is_file())
        or (not p.name.startswith("zh-") and not (directory / f"zh-{p.name}").is_file())
    )

def main() -> int:
    pending = pair_count(PENDING)
    review = pair_count(REVIEW)
    total = pending + review
    if "--count" in sys.argv[1:]:
        print(total)
        return 0
    print(f"inventory_pairs={total} pending_pairs={pending} review_pairs={review} "
          f"pending_orphans={orphan_count(PENDING)} review_orphans={orphan_count(REVIEW)}")
    if "--can-produce" in sys.argv[1:]:
        if total >= HARD_CAP:
            print(f"production=paused reason=hard_cap_{HARD_CAP}")
            return 1
        if total >= SOFT_START:
            print(f"production=paused reason=inventory_at_least_{SOFT_START}")
            return 1
        print(f"production=allowed reason=inventory_below_{SOFT_START}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
