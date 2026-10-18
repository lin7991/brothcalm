#!/usr/bin/env python3
"""Validate a generated EN/ZH pair before queue advancement.
Exit 0=publishable, 1=invalid, 2=valid but requires manual review.
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path
from html import unescape
from urllib.parse import urlparse

PLACEHOLDERS = re.compile(r"<!--(?:TITLE|META_DESC|CANONICAL_PATH|EN_PATH|OG_TITLE|OG_DESC|H1|TYPE_LABEL|READ_TIME|CONTENT|FAQ_SCHEMA)-->")
RISK_TERMS = re.compile(r"\b(pregnan|breastfeed|diabet|kidney|liver|blood thinner|anticoagul|drug interaction|medication|surgery|seizure|children|infant|hypertension|concentrated extract|supplement)\b|孕|哺乳|儿童|糖尿病|肾病|肝病|抗凝|药物相互作用|手术|癫痫|浓缩草药", re.I)
DIRECT_CLAIM = re.compile(r"\b(?:this|the)\s+(?:herb|tea|recipe|food|method)\s+(?:cures?|treats?|heals?|prevents?|reverses?)\b|\b(?:cures?|treats?|heals?|prevents?|reverses?)\s+(?:anxiety|insomnia|diabetes|cancer|disease|pain|infection)\b|\b(stop|discontinue)\s+(?:taking|your)\s+medication|you do not need (?:to see|a) doctor", re.I)
QUALITY_CLAIM = re.compile(r"\b(?:miracle|guaranteed results?|proven remedy|immune boost|detox(?:es|ify|ification)?)\b", re.I)

def visible(h: str) -> str:
    m = re.search(r'<div class="article-body">(.*?)</div>\s*</article>', h, re.S|re.I)
    x = m.group(1) if m else h
    x = re.sub(r'<script.*?</script>|<style.*?</style>|<[^>]+>', ' ', x, flags=re.S|re.I)
    return re.sub(r'\s+', ' ', unescape(x)).strip()

def schemas(h: str):
    out=[]
    for raw in re.findall(r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', h, re.S|re.I):
        try: out.append(json.loads(raw))
        except Exception: pass
    return out

def kind(path: Path) -> str:
    s = str(path).lower()
    if '/recipes-' in s or '/recipes/' in s: return 'recipe'
    if '/teas-' in s or '/teas/' in s: return 'tea'
    if '/food-therapy-' in s or '/food-therapy/' in s: return 'symptom'
    if '/theory-' in s or '/theory/' in s: return 'theory'
    return 'ingredient'

def ranges(k, lang):
    vals = {'ingredient':(700,2000,900,1600),'tea':(800,2200,1000,1800),'recipe':(600,1800,700,1400),'symptom':(1000,3000,1400,2500),'theory':(900,2600,1200,2200)}[k]
    return vals[:2] if lang == 'en' else ({'ingredient':(900,2800),'tea':(1000,3000),'recipe':(800,2500),'symptom':(1400,4000),'theory':(1100,3400)}[k])

def source_block(h):
    m = re.search(r'<h[23][^>]*>[^<]*(?:Sources|Further reading|参考资料|资料来源|来源)[^<]*</h[23]>', h, re.I)
    if not m: return ''
    rest=h[m.end():]; nxt=re.search(r'<h[23][^>]*>',rest,re.I)
    return rest if not nxt else rest[:nxt.start()]

def check(path, lang, recipe, review):
    h=path.read_text(encoding='utf-8',errors='replace'); t=visible(h); e=[]
    if PLACEHOLDERS.search(h): e.append('unreplaced template placeholder')
    if 'Disclaimer' not in h and '免责声明' not in h: e.append('missing disclaimer')
    title=re.search(r'<title>(.*?)</title>',h,re.S|re.I); og=re.search(r'<meta property="og:title" content="([^"]*)"',h,re.I)
    if not title or not og or unescape(re.sub('<[^>]+>','',title.group(1))).strip()!=unescape(og.group(1)).strip(): e.append('title and og:title are not identical')
    dm=re.search(r'<meta name="description" content="([^"]*)"',h,re.I)
    if not dm or len(unescape(dm.group(1)))>155: e.append('missing or overlong meta description')
    if '| BrothCalm' not in (unescape(title.group(1)) if title else ''): e.append('title missing BrothCalm brand')
    sb=source_block(h); links=re.findall(r'https?://[^"\'<>\s]+',sb)
    hosts={urlparse(u).netloc.lower().split(':')[0].removeprefix('www.') for u in links}
    trusted=any(h.endswith(('.gov','.edu')) or any(x in h for x in ('who.int','nih.gov','pubmed.ncbi.nlm.nih.gov','nhs.uk','mayoclinic.org','cdc.gov','cochranelibrary.com')) for h in hosts)
    is_symptom='/food-therapy/' in h or '/food-therapy-' in h
    min_sources=3 if is_symptom else 2
    if not sb or len(set(links))<min_sources: e.append(f'sources section has fewer than {min_sources} links')
    if is_symptom and not trusted: e.append('symptom guide lacks a government, medical, university, or systematic-review source')
    for u in set(links):
        if urlparse(u).scheme!='https' or not urlparse(u).netloc: e.append('invalid source URL')
    cm=re.search(r'<link rel="canonical" href="[^"]+(/[^"]*)',h,re.I)
    k=kind(Path(cm.group(1)) if cm else path)
    lo,hi=ranges(k,lang)
    n=len(re.findall(r"\b[A-Za-z][A-Za-z'’-]*\b",t)) if lang=='en' else len(re.findall(r'[\u3400-\u9fff]',t))
    if not lo<=n<=hi: e.append(f'{lang} length {n} outside {lo}-{hi} for {k}')
    if DIRECT_CLAIM.search(t): e.append('direct medical promise or medication instruction')
    if QUALITY_CLAIM.search(t): e.append('unsupported hype claim')
    if k=='symptom':
        if not re.search(r'practical takeaways|how to try|when to see|when to seek|专业照护|就医|何时',h,re.I): e.append('symptom guide lacks takeaways or care boundary')
    if review and not re.search(r'consult|professional|qualified|医生|医师|专业人员',t,re.I): e.append('high-risk topic lacks professional-care boundary')
    if recipe:
        found=[]
        for d in schemas(h):
            typ=d.get('@type',[]) if isinstance(d,dict) else []
            if isinstance(typ,str): typ=[typ]
            if 'Recipe' in typ: found.append(d)
        if not found: e.append('recipe article has no Recipe JSON-LD')
        for d in found:
            for key in ('name','keywords','nutrition','recipeYield','recipeIngredient','recipeInstructions'):
                if not d.get(key): e.append(f'Recipe missing {key}')
            if not d.get('prepTime') and not d.get('cookTime'): e.append('Recipe missing prepTime or cookTime')
            if not isinstance(d.get('recipeIngredient'),list) or len(d['recipeIngredient'])<2: e.append('Recipe has fewer than two ingredients')
            if not isinstance(d.get('recipeInstructions'),list) or len(d['recipeInstructions'])<2: e.append('Recipe has fewer than two instructions')
    return e

def main():
    if len(sys.argv)!=3: print('usage: validator EN.html ZH.html',file=sys.stderr); return 2
    en,zh=map(Path,sys.argv[1:]); allh=en.read_text(errors='replace')+'\n'+zh.read_text(errors='replace')
    recipe='"Recipe"' in allh; review=bool(RISK_TERMS.search(visible(allh)))
    errs=[(str(en),x) for x in check(en,'en',recipe,review)]+[(str(zh),x) for x in check(zh,'zh',recipe,review)]
    if errs:
        for p,x in errs: print(f'❌ {p}: {x}')
        return 1
    if review:
        print('⚠️ pair passed validation but requires manual review due to high-risk topic')
        return 2
    print('✅ generated pair passed content, safety, source, SEO, and schema validation'); return 0
if __name__=='__main__': raise SystemExit(main())
