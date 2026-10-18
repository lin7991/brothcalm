#!/usr/bin/env python3
"""Report H2 overlap and title/angle collisions for a generated pair."""
from __future__ import annotations
import html,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
COMMON={'safety','sources','参考资料','免责声明','faq','quick answer','practical takeaways','how to try it','when to see a doctor','is this guide for you','the decision','compare nearby choices','troubleshooting and personalization','safety boundaries','the modern food lens what we know and what we do not'}
def norm(x): return re.sub(r'[^a-z0-9\u3400-\u9fff ]','',html.unescape(x).lower()).strip()
def heads(p):
 s=p.read_text(errors='ignore'); return {norm(x) for x in re.findall(r'<h2[^>]*>(.*?)</h2>',s,re.S|re.I)}-COMMON
def pages(): return [p for p in ROOT.rglob('index.html') if '.cron' not in p.parts and '.git' not in p.parts]
def main():
 if len(sys.argv)<2: print('usage: check-content-overlap.py GENERATED.html [threshold]'); return 2
 new=Path(sys.argv[1]); threshold=float(sys.argv[2]) if len(sys.argv)>2 else .30; nh=heads(new)
 rows=[]
 for p in pages():
  ph=heads(p)
  if not ph or not nh: continue
  score=len(nh&ph)/max(1,min(len(nh),len(ph)))
  if score>=threshold: rows.append((score,str(p),sorted(nh&ph)))
 rows.sort(reverse=True)
 for score,p,shared in rows[:10]: print(f'{score:.0%}\t{p}\t{", ".join(shared)}')
 print(f'overlap_candidates={len(rows)} threshold={threshold:.0%}')
 return 1 if rows else 0
if __name__=='__main__': raise SystemExit(main())
