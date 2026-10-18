#!/usr/bin/env python3
"""Build conservative FAQPage JSON-LD from real H2 + following paragraph text."""
from __future__ import annotations
import json,re,html
from pathlib import Path
WS=Path(__file__).resolve().parent.parent
SKIP={'.git','.cron','node_modules'}
def pages():
 for p in WS.rglob('index.html'):
  if not any(x in SKIP for x in p.parts): yield p
 for p in (WS/'.cron/pending').glob('*.html'): yield p
def clean(x): return re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',x))).strip()
def build(s,zh=False):
 if '<!--FAQ_SCHEMA-->' not in s:return s
 pairs=[]
 for m in re.finditer(r'<h2[^>]*>(.*?)</h2>(.*?)(?=<h2|</article>)',s,re.S|re.I):
  q=clean(m.group(1))
  pm=re.search(r'<p[^>]*>(.*?)</p>',m.group(2),re.S|re.I)
  a=clean(pm.group(1)) if pm else ''
  if q and a and '?' in q and len(a)>=40:pairs.append({'@type':'Question','name':q,'acceptedAnswer':{'@type':'Answer','text':a}})
  if len(pairs)>=5:break
 if not pairs:return s.replace('<!--FAQ_SCHEMA-->','')
 data={'@context':'https://schema.org','@type':'FAQPage','mainEntity':pairs}
 return s.replace('<!--FAQ_SCHEMA-->','<script type="application/ld+json">\n'+json.dumps(data,ensure_ascii=False,indent=2)+'\n</script>',1)
def main():
 n=0
 for p in pages():
  s=p.read_text(errors='ignore'); x=build(s,p.name.startswith('zh-'))
  if x!=s:p.write_text(x);n+=1
 print(f'FAQ schema generated for {n} pages')
if __name__=='__main__':main()
