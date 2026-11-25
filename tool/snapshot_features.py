"""Verify Sudoku catalog video links against the official CtC catalog and portal.
Run after snapshot_catalog.py. An optional argument limits title/author candidates.
Requires lxml. Unmatched candidates retain their original catalog state.
"""
import datetime
import hashlib
import json
from pathlib import Path
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
import urllib.error
from lxml import html

ROOT = Path(__file__).resolve().parents[1] / 'assets/library'
CACHE = Path('/tmp/sodukromental-ctc')
CACHE.mkdir(exist_ok=True)
SITE = 'https://www.crackingthecryptic.com'
PORTAL = 'https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id='

def document(url):
    path = CACHE / hashlib.sha256(url.encode()).hexdigest()
    if not path.exists():
        time.sleep(.15)
        with urllib.request.urlopen(url,timeout=20) as response:
            body = response.read()
        path.write_bytes(body)
    return html.fromstring(path.read_bytes())

def normalize(value):
    return ''.join(c for c in unicodedata.normalize('NFKC',value).casefold() if c.isalnum())

def game(url):
    parsed = urllib.parse.urlparse(url)
    if parsed.netloc.lower() in {'sudokupad.app','www.sudokupad.app','app.crackingthecryptic.com'}:
        return parsed.path.strip('/') or dict(urllib.parse.parse_qsl(parsed.query)).get('puzzleid')
    return None

def main():
    out = ROOT/'features.json'
    matches = json.loads(out.read_text()) if out.exists() else {}
    entries = json.loads((ROOT/'catalog.json').read_text())
    by_name = {(normalize(row['title']),normalize(row['author'])):row['id'] for row in entries}
    rule_paths = {}
    for row in entries:
        source = CACHE / hashlib.sha256((PORTAL+row['id']).encode()).hexdigest()
        if source.exists(): rule_paths[row['id']] = str(source)
    candidates=[]
    for item in document(SITE+'/sudokus').xpath('//li[a[contains(@href,"/sudokuwatch?id=")]]'):
        first=item.xpath('a[contains(@href,"/sudoku?id=")]')[0]
        name=re.fullmatch(r'(.+)\s+\((.+)\)', first.text_content().strip())
        if not name: continue
        pid=by_name.get((normalize(name[1]),normalize(name[2])))
        if pid and pid not in matches:
            candidates.append((pid,first.get('href'),item.xpath('a[contains(@href,"sudokuwatch")]/@href')[0],first.get('title')))
    limit=int(sys.argv[1]) if len(sys.argv)>1 else len(candidates)
    print('Title/author candidates:',len(candidates),'limit',limit,flush=True)
    for pid,puzzle,watch,date in candidates[:limit]:
        try:
            portal=document(PORTAL+pid)
            rule_paths[pid]=str(CACHE/hashlib.sha256((PORTAL+pid).encode()).hexdigest())
            links={g for url in portal.xpath('//*[contains(concat(" ",normalize-space(@class)," ")," rp_html ")]//a/@href') if (g:=game(url))}
            games={g for url in document(SITE+puzzle).xpath('//iframe/@src') if (g:=game(url))}
            if not links.intersection(games):continue
            ids=[m[1] for src in document(SITE+watch).xpath('//iframe/@src') if (m:=re.fullmatch(r'https://(?:www\.)?youtube(?:-nocookie)?\.com/embed/([a-zA-Z0-9_-]{11})(?:\?.*)?',src))]
            if len(ids)!=1:continue
            matches[pid]=[dict(id=ids[0],date=date,source=SITE+watch,review=datetime.date.today().isoformat())]
            temp=out.with_suffix('.new')
            temp.write_text(json.dumps(matches,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
            temp.replace(out)
            print(pid,ids[0],len(matches),flush=True)
        except urllib.error.HTTPError as error:
            print('Source returned', error.code, 'for', pid, flush=True)
            if error.code in (429, 503):
                print('Paused. Retry after the source is available:', error.headers.get('Retry-After',''), flush=True)
                break
        except (OSError, ValueError) as error:
            print('Unavailable',pid,type(error).__name__,flush=True)
    (CACHE/'details-index.json').write_text(json.dumps(rule_paths))
if __name__=='__main__':main()
