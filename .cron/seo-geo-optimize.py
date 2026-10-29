#!/usr/bin/env python3
"""Deterministic SEO/GEO pass for BrothCalm published HTML pages."""
from __future__ import annotations
import html as htmlmod
import json
import re
import subprocess
from datetime import date
from pathlib import Path

WS = Path(__file__).resolve().parent.parent
SITE = "https://brothcalm.com"
SKIP = {".git", ".cron", "node_modules"}

def pages(pending_only=False):
    if pending_only:
        yield from (WS / ".cron" / "pending").glob("*.html")
        return
    for p in WS.rglob("index.html"):
        if any(part in SKIP for part in p.parts):
            continue
        yield p
    # Run the same metadata pass on staged pages before they are published.
    yield from (WS / ".cron" / "pending").glob("*.html")

def text(fragment: str) -> str:
    return re.sub(r"\s+", " ", htmlmod.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()

def git_date(p: Path, newest: bool) -> str:
    # Metadata already present in generated pages is preserved by setdefault.
    # New pages use the build date; per-page git history lookups make a 400+
    # page static-site pass unnecessarily slow and do not improve indexing.
    return date.today().isoformat()

def canonical_path(s: str) -> str:
    m = re.search(r'<link rel="canonical" href="https://brothcalm\.com(/[^"]*)"', s)
    return (m.group(1).rstrip("/") if m else "")

def image_for(path: str) -> str:
    slug = path.strip("/").split("/")[-1] if path.strip("/") else "goji-berries"
    is_zh = path.startswith("/zh/")
    candidates = ([f"images/zh-{slug}.jpg", f"images/{slug}.jpg"] if is_zh else [f"images/{slug}.jpg", f"images/zh-{slug}.jpg"])
    for c in candidates:
        if (WS / c).exists():
            return f"{SITE}/{c}"
    return f"{SITE}/images/default-og.jpg"

def replace_once(s: str, pattern: str, repl: str) -> str:
    return re.sub(pattern, repl, s, count=1, flags=re.S)

def metadata(s: str, path: str, p: Path) -> str:
    lang = "zh-CN" if path.startswith("/zh") else "en"
    h1m = re.search(r"<h1[^>]*>(.*?)</h1>", s, re.S)
    h1 = text(h1m.group(1)) if h1m else "BrothCalm Chinese Food Therapy"
    tm = re.search(r"<title>(.*?)</title>", s, re.S)
    title = text(tm.group(1)) if tm else h1
    title = re.sub(r"\s*[—|:]\s*BrothCalm\s*$", "", title, flags=re.I).strip()
    if len(title) > 54:
        title = title[:51].rsplit(" ", 1)[0].rstrip("—:,- ") + "…"
    title = f"{title} | BrothCalm"
    if len(htmlmod.unescape(title)) > 65:
        title = title[:62].rstrip("—:,- ") + "…"
    dm = re.search(r'<meta name="description" content="([^"]*)"', s)
    desc = htmlmod.unescape(dm.group(1)).strip() if dm else ""
    if len(desc) < 70:
        if lang.startswith("zh"):
            desc = f"了解{h1}的中医食疗传统、实用做法与安全注意事项。BrothCalm 提供清晰、可操作的食疗指南。"
        else:
            desc = f"Explore {h1}: traditional Chinese food therapy context, practical preparation, and safety notes from BrothCalm."
    desc = re.sub(r"\s+", " ", desc).strip()
    if len(desc) > 155:
        desc = desc[:152].rsplit(" ", 1)[0].rstrip("—,;: ") + "…"
    s = replace_once(s, r"<title>.*?</title>", f"<title>{htmlmod.escape(title)}</title>")
    if dm:
        s = replace_once(s, r'<meta name="description" content="[^"]*"', f'<meta name="description" content="{htmlmod.escape(desc, quote=True)}"')
    else:
        s = s.replace("</title>", f'</title>\n  <meta name="description" content="{htmlmod.escape(desc, quote=True)}" />', 1)
    s = replace_once(s, r'<meta property="og:title" content="[^"]*"', f'<meta property="og:title" content="{htmlmod.escape(title, quote=True)}"')
    s = replace_once(s, r'<meta property="og:description" content="[^"]*"', f'<meta property="og:description" content="{htmlmod.escape(desc, quote=True)}"')
    og = image_for(path)
    if 'property="og:image"' in s:
        s = replace_once(s, r'<meta property="og:image" content="[^"]*"', f'<meta property="og:image" content="{og}"')
    else:
        marker = '  <meta name="twitter:card"'
        insert = f'  <meta property="og:image" content="{og}" />\n  <meta property="og:image:width" content="1200" />\n  <meta property="og:image:height" content="630" />\n'
        if marker in s:
            s = s.replace(marker, insert + marker, 1)
        else:
            s = s.replace('  <link rel="canonical"', insert + '  <link rel="canonical"', 1)
    if 'name="author"' not in s:
        s = s.replace('  <meta name="description"', '  <meta name="author" content="BrothCalm Editorial Team" />\n  <meta name="description"', 1)
    if 'property="og:locale"' not in s:
        loc = "zh_CN" if lang.startswith("zh") else "en_US"
        s = s.replace('  <meta property="og:title"', f'  <meta property="og:locale" content="{loc}" />\n  <meta property="og:title"', 1)
    # Remove accidental duplicate stylesheet imports.
    css = '  <link rel="stylesheet" href="/styles/brothcalm.css" />'
    first = s.find(css)
    if first >= 0:
        tail = s[first + len(css):].replace(css, "")
        s = s[:first + len(css)] + tail
    return s

def schemas(s: str, p: Path) -> str:
    published, modified = git_date(p, False), git_date(p, True)
    blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', s, re.S)
    for raw in blocks:
        try: data = json.loads(raw)
        except json.JSONDecodeError: continue
        types = data.get("@type", []) if isinstance(data, dict) else []
        if isinstance(types, str): types = [types]
        if not isinstance(data, dict) or not any(t in types for t in ("Article", "Recipe", "HowTo")):
            continue
        data.setdefault("author", {"@type": "Organization", "name": "BrothCalm Editorial Team", "url": f"{SITE}/about/"})
        data.setdefault("publisher", {"@type": "Organization", "name": "BrothCalm", "url": f"{SITE}/about/"})
        data.setdefault("datePublished", published)
        data.setdefault("dateModified", modified)
        if "Recipe" in types:
            # Google requires Recipe.name and recommends keywords/nutrition.
            # Derive name from the visible H1; do not invent calorie values.
            if not data.get("name"):
                h1m = re.search("<h1[^>]*>(.*?)</h1>", s, re.S)
                recipe_name = text(h1m.group(1)) if h1m else text(data.get("headline", "BrothCalm recipe"))
                data["name"] = recipe_name.replace(" | BrothCalm", "").strip()
            data.setdefault("keywords", "Chinese food therapy, TCM recipe, home cooking")
            data.setdefault("nutrition", {
                "@type": "NutritionInformation",
                "description": "Nutrition varies with ingredients, preparation, and serving size."
            })
        new = '<script type="application/ld+json">\n' + json.dumps(data, ensure_ascii=False, indent=2) + '\n  </script>'
        s = s.replace(f'<script type="application/ld+json">{raw}</script>', new, 1)
    return s

def quick_answer(s: str, path: str) -> str:
    if "article-body" not in s or "quick-answer" in s: return s
    m = re.search(r'<div class="article-body">.*?<p[^>]*>(.*?)</p>', s, re.S)
    if not m: return s
    summary = m.group(1).strip()
    label = "快速了解" if path.startswith("/zh") else "Quick answer"
    block = f'\n  <aside class="quick-answer" aria-label="{label}"><strong>{label}</strong><p>{summary}</p></aside>\n'
    return s.replace('<div class="article-body">', block + '\n  <div class="article-body">', 1)

def main():
    count = 0
    pending_only = "--pending-only" in __import__("sys").argv[1:]
    for p in pages(pending_only):
        s = p.read_text(errors="ignore")
        path = canonical_path(s)
        if path is None: continue
        n = quick_answer(schemas(metadata(s, path, p), p), path)
        if n != s:
            p.write_text(n)
            count += 1
    print(f"optimized {count} pages")

if __name__ == "__main__": main()
