#!/usr/bin/env python3
"""
BrothCalm — Article Queue Manager
=====================================
Usage:
  python3 .cron/publish-article.py remaining      # Show queue count
  python3 .cron/publish-article.py next            # Get next item
  python3 .cron/publish-article.py add < json      # Add items
  python3 .cron/publish-article.py publish <file>   # Publish article HTML
"""

import json, sys, os, shutil, re
from pathlib import Path

QUEUE_FILE = Path(__file__).parent.parent / ".content-queue.json"
SITE_ROOT = Path(__file__).parent.parent
TEMPLATE = SITE_ROOT / "article-template.html"

def load_queue():
    if QUEUE_FILE.exists():
        return json.loads(QUEUE_FILE.read_text())
    return {"articles": [], "index": 0}

def save_queue(q):
    QUEUE_FILE.write_text(json.dumps(q, indent=2))

def show_remaining():
    q = load_queue()
    remaining = len(q["articles"]) - q["index"]
    print(remaining)

def next_article():
    q = load_queue()
    if q["index"] >= len(q["articles"]):
        print("null")
        return
    item = q["articles"][q["index"]]
    print(json.dumps(item))

def add_articles():
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        data = [data]
    q = load_queue()
    q["articles"].extend(data)
    save_queue(q)
    print(f"Added {len(data)} articles. Queue: {len(q['articles']) - q['index']} remaining")

def publish_article(filepath):
    """Move published article from /tmp to site root, update queue index."""
    src = Path(filepath)
    if not src.exists():
        print(f"❌ Article file not found: {filepath}")
        return False

    # Read the article to determine target path
    html = src.read_text()

    # Extract canonical path (e.g., /ingredients/goji-berries)
    m = re.search(r'href="https://brothcalm\.com(/[^"]+)/"', html)
    if not m:
        m = re.search(r'CANONICAL_PATH-->([^<]+)', html)
    if not m:
        print("❌ Could not determine target path from article")
        return False

    target_path = m.group(1).rstrip("/")
    target_dir = SITE_ROOT / target_path.lstrip("/")
    target_file = target_dir / "index.html"

    # Create directory and write
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file.write_text(html)

    # Replace .gitkeep with actual article
    gitkeep = target_dir / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()

    # Update queue index
    q = load_queue()
    q["index"] += 1
    save_queue(q)

    print(f"✅ Published: {target_path}/")
    print(f"   → {target_file}")

    # Git operations
    git_add = f"cd {SITE_ROOT} && git add -A && git diff --cached --quiet || git commit -m 'Publish: {target_path}'"
    os.system(git_add)
    # Push separately unless BROTHCALM_STAGE_ONLY=1
    if not os.environ.get("BROTHCALM_STAGE_ONLY"):
        os.system(f"cd {SITE_ROOT} && git push")

    remaining = len(q["articles"]) - q["index"]
    print(f"   Queue remaining: {remaining}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: publish-article.py [remaining|next|add|publish]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "remaining":
        show_remaining()
    elif cmd == "next":
        next_article()
    elif cmd == "add":
        add_articles()
    elif cmd == "publish":
        if len(sys.argv) < 3:
            print("Usage: publish-article.py publish <filepath>")
            sys.exit(1)
        publish_article(sys.argv[2])
    elif cmd == "stage":
        # Just advance queue index without writing any file
        q = load_queue()
        q["index"] += 1
        save_queue(q)
        remaining = len(q["articles"]) - q["index"]
        print(f"✅ Queue advanced. Remaining: {remaining}")
    elif cmd == "pending":
        # List staged files
        import glob
        pending = Path(__file__).parent / "pending"
        files = list(pending.glob("*.html"))
        for f in files:
            print(f.name)
        print(f"Total: {len(files)}")
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
