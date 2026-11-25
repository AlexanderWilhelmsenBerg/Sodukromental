"""Refresh the bundled metadata from the public Sudoku listing. Requires lxml."""
import concurrent.futures
import datetime
import email.utils
import json
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.request
from lxml import html

BASE = 'https://logic-masters.de/Raetselportal/Suche/spezial.php'
OUT = Path(__file__).resolve().parents[1] / 'assets/library/catalog.json'
CACHE = Path(sys.argv[1]) if len(sys.argv) == 2 else Path('/tmp/sodukromental-listing-pages')
CACHE.mkdir(exist_ok=True)
MONTHS = {name: i for i, name in enumerate(('','January','February','March','April','May','June','July','August','September','October','November','December')) if name}

def parse(body, timestamp):
    doc = html.fromstring(body)
    tables = doc.xpath('//table[contains(@class,"rp_raetselliste")]')
    if not tables:
        raise ValueError('Listing table missing')
    records = []
    for row in tables[0].xpath('.//tr[td]'):
        links = row.xpath('td[2]/a | td[2]/span/a')
        if len(links) < 2:
            raise ValueError('Unrecognized listing row')
        link, author = links[:2]
        item = {'id': link.get('href').split('id=')[-1],
                'title': link.text_content().strip(), 'author': author.text_content().strip()}
        level = ''.join(row.xpath('td[4]/img/@src'))
        match = re.search(r'/(u?)level(\d)\.png', level)
        if match:
            item.update(difficulty=int(match[2]),estimated=bool(match[1]))
        rating = re.search(r'(\d+)\s*%', row.xpath('td[4]')[0].text_content())
        if rating:
            item['rating'] = int(rating[1])
        date = (author.tail or '').strip()
        dt = re.search(r'on (\d+)\. ([A-Za-z]+) (\d{4})', date)
        if dt and dt[2] in MONTHS:
            item['published'] = datetime.date(int(dt[3]), MONTHS[dt[2]], int(dt[1])).isoformat()
        elif timestamp and ('today' in date or 'yesterday' in date):
            day = email.utils.parsedate_to_datetime(timestamp).date()
            item['published'] = (day - datetime.timedelta(days=int('yesterday' in date))).isoformat()
        records.append(item)
    return records

def page(number):
    target = CACHE / f'{number}.json'
    if target.exists():
        return json.loads(target.read_text())
    req = urllib.request.Request(f'{BASE}?listname=sudokus&chlang=en&start={number*20}',
                                 headers={'User-Agent': 'Sodukromental/0.1 (public Sudoku listing metadata)'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                # The portal declares UTF-8 in its HTML.
                rows = parse(response.read(), response.headers.get('Date'))
            target.write_text(json.dumps(rows, ensure_ascii=False))
            return rows
        except (OSError, ValueError) as err:
            if attempt == 4: raise
            retry = err.headers.get('Retry-After','') if isinstance(err, urllib.error.HTTPError) else ''
            time.sleep(max(int(retry) if retry.isdigit() else 0, 2**(attempt+1)))

def publish(entries):
    part = OUT.with_suffix('.part')
    part.write_text(json.dumps(list(entries.values()), ensure_ascii=False, separators=(',', ':'))+'\n')
    part.replace(OUT)

def main():
    index = 0
    entries = {}
    # Two outstanding metadata pages at most. Saved pages allow a restart after interruption.
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        while True:
            pending = [pool.submit(page, offset) for offset in range(index, index+2)]
            for task in pending:
                rows = task.result()
                for item in rows:
                    entries.setdefault(item['id'],item)
                if len(rows) < 20:
                    publish(entries)
                    print(f'Final page {index+1}, {len(rows)} rows. Indexed {len(entries)} distinct portal IDs.',flush=True)
                    return
                index += 1
            if index % 20 == 0 or index == 2:
                publish(entries)
                print(f'{index} pages, {len(entries)} distinct IDs', flush=True)
            time.sleep(.15)
if __name__ == '__main__': main()
