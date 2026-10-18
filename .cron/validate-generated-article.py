#!/usr/bin/env python3
"""Validate one generated EN/ZH pair before queue advancement."""
from __future__ import annotations
import json, re, sys
from pathlib import Path
from html import unescape

PLACEHOLDERS = re.compile(r"<!--(?:TITLE|META_DESC|CANONICAL_PATH|EN_PATH|OG_TITLE|OG_DESC|H1|TYPE_LABEL|READ_TIME|CONTENT|FAQ_SCHEMA)-->")
DANGEROUS_CLAIMS = re.compile(r"\b(cure|cures|treats?|prevents?|guarantees?|detox(?:es|ify|ification)?|miracle|proven remedy|immune boost)\b", re.I)
RISK_TERMS = re.compile(r"\b(pregnan|breastfeed|diabet|kidney|liver|blood thinner|anticoagul|medication|drug interaction|surgery|seizure|children|infant|hypertension)\b", re.I)

def visible(html: str) -> str:
    body = re.search(r"<div class=\"article-body\">(.*?)</div>\s*</article>", html, re.S | re.I)
    text = body.group(1) if body else html
    text = re.sub(r"<script.*?</script>|<style.*?</style>|<[^>]+>", " ", text, flags=re.S | re.I)
    return re.sub(r"\s+", " ", unescape(text)).strip()

def schemas(html: str):
    out=[]
    for raw in re.findall(r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', html, re.S|re.I):
        try: out.append(json.loads(raw))
        except Exception: pass
    return out

def check(path: Path, lang: str, recipe: bool):
    html = path.read_text(encoding="utf-8", errors="replace")
    text = visible(html)
    errors=[]
    if PLACEHOLDERS.search(html): errors.append("unreplaced template placeholder")
    if DANGEROUS_CLAIMS.search(text): errors.append("medical or hype claim")
    if "Disclaimer" not in html and "免责声明" not in html: errors.append("missing disclaimer")
    source_heading = re.search(r"<(h2|h3)[^>]*>[^<]*(Sources|Further reading|参考资料|资料来源)[^<]*</", html, re.I)
    if not source_heading:
        errors.append("missing sources section")
    else:
        tail = html[source_heading.start():]
        after_heading = tail[source_heading.end()-source_heading.start():]
        next_heading = re.search(r"<h[23][^>]*>", after_heading, re.I)
        source_block = tail if not next_heading else tail[:source_heading.end()-source_heading.start()+next_heading.start()]
        links = re.findall(r"https?://[^\"'<>\s]+", source_block)
        if len(set(links)) < 2: errors.append("sources section has fewer than two links")
    if lang == "en":
        words = re.findall(r"\b[A-Za-z][A-Za-z'’-]*\b", text)
        if not 900 <= len(words) <= 2200: errors.append(f"English word count {len(words)} outside 900-2200")
    else:
        cjk = re.findall(r"[\u3400-\u9fff]", text)
        if not 1200 <= len(cjk) <= 2600: errors.append(f"Chinese character count {len(cjk)} outside 1200-2600")
    if RISK_TERMS.search(text) and not re.search(r"consult|professional|医生|专业人员|医师", text, re.I):
        errors.append("risk topic lacks professional-care boundary")
    if recipe:
        found=False
        for data in schemas(html):
            types=data.get("@type",[]) if isinstance(data,dict) else []
            if not isinstance(types,list): types=[types]
            if "Recipe" not in types: continue
            found=True
            for key in ("name","keywords","nutrition","recipeYield","recipeIngredient","recipeInstructions"):
                if not data.get(key): errors.append(f"Recipe missing {key}")
            if not data.get("prepTime") and not data.get("cookTime"):
                errors.append("Recipe missing prepTime or cookTime")
            if isinstance(data.get("recipeIngredient"),list) and len(data["recipeIngredient"]) < 2: errors.append("Recipe has fewer than two ingredients")
            if isinstance(data.get("recipeInstructions"),list) and len(data["recipeInstructions"]) < 2: errors.append("Recipe has fewer than two instructions")
        if not found: errors.append("recipe article has no Recipe JSON-LD")
    return errors

def main():
    if len(sys.argv) != 3:
        print("usage: validate-generated-article.py EN.html ZH.html", file=sys.stderr); return 2
    en, zh = map(Path, sys.argv[1:])
    # Recipe status is inferred from either page's visible/schema content.
    recipe = '"Recipe"' in en.read_text(errors='replace') or '"Recipe"' in zh.read_text(errors='replace')
    errors = [(str(en), e) for e in check(en, "en", recipe)] + [(str(zh), e) for e in check(zh, "zh", recipe)]
    if errors:
        for path, error in errors: print(f"❌ {path}: {error}")
        return 1
    print("✅ generated pair passed content, safety, source, and schema validation")
    return 0

if __name__ == "__main__": raise SystemExit(main())
