#!/usr/bin/env python3
"""Validate the SEO/GEO trend brief used by content creation.
The brief is runtime data and must contain sources, dates, and confidence labels.
"""
from __future__ import annotations
import json, sys
from urllib.parse import urlparse
from pathlib import Path

REQUIRED = {'updated_at', 'market', 'evergreen_clusters', 'seasonal_clusters', 'trend_signals'}

def main():
    p = Path(sys.argv[1] if len(sys.argv) > 1 else '.cron/.seo-keyword-research.json')
    try: data = json.loads(p.read_text())
    except Exception as e:
        print(f'Invalid SEO brief: {e}'); return 1
    missing = REQUIRED - data.keys()
    if missing: print('Missing fields:', ', '.join(sorted(missing))); return 1
    for group in ('evergreen_clusters','seasonal_clusters','trend_signals'):
        if not isinstance(data[group], list) or not data[group]:
            print(f'{group} must be a non-empty list'); return 1
        for item in data[group]:
            if not isinstance(item, dict) or not item.get('primary_keyword') or (group != 'trend_signals' and not item.get('search_intent')):
                print(f'{group} contains an item without required keyword/intent'); return 1
            if group == 'trend_signals':
                if not item.get('source_urls'):
                    print('trend signal without source_urls:', item.get('primary_keyword')); return 1
                if item.get('fit_for_brothcalm') not in {'high', 'medium', 'low'}:
                    print('trend signal without fit_for_brothcalm high|medium|low:', item.get('primary_keyword')); return 1
                if not item.get('why_now') or not item.get('risk_note'):
                    print('trend signal missing why_now or risk_note:', item.get('primary_keyword')); return 1
            for url in item.get('source_urls', []):
                parsed = urlparse(url)
                if parsed.scheme != 'https' or not parsed.netloc:
                    print('invalid source URL:', url); return 1
    print(f"SEO brief valid: {len(data['evergreen_clusters'])} evergreen, {len(data['seasonal_clusters'])} seasonal, {len(data['trend_signals'])} trend signals")
    return 0
if __name__ == '__main__': raise SystemExit(main())
