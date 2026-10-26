"""Dark-mode readiness audit for the ArkTS project.

Scans every .ets for hardcoded color literals and classifies them by the
property they are applied to, so genuine dark-mode gaps can be told apart
from intentional white-on-brand text.
"""
import os
import re
import json
from collections import Counter, defaultdict

ROOT = r'D:\11\carbon-master\app\entry\src\main\ets'

COLOR_RE = re.compile(r"'(#[0-9A-Fa-f]{3,8}|rgba?\([^)]*\))'")
PROP_RE = re.compile(r'\.(\w+)\(')

records = []
for dirpath, _dirs, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.ets'):
            continue
        path = os.path.join(dirpath, fn)
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding='utf-8') as f:
            lines = f.read().splitlines()
        for i, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith('//') or s.startswith('*') or s.startswith('/*'):
                continue
            for m in COLOR_RE.finditer(line):
                lit = m.group(1)
                head = line[:m.start()]
                props = PROP_RE.findall(head)
                prop = props[-1] if props else ''
                low = lit.lower()
                r = g = b = None
                if low.startswith('#'):
                    h = low[1:]
                    if len(h) == 8:
                        h = h[2:]
                    if len(h) == 3:
                        r, g, b = (int(c * 2, 16) for c in h)
                    elif len(h) == 6:
                        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
                else:
                    nums = [float(x) for x in re.findall(r'[0-9]+(?:\.[0-9]+)?', low)]
                    if len(nums) >= 3:
                        r, g, b = nums[0], nums[1], nums[2]
                is_white = (r is not None and r >= 245 and g >= 245 and b >= 245)
                if prop in ('backgroundColor', 'fill', 'stroke', 'track',
                            'linearGradient', 'radialGradient', 'shadow',
                            'border', 'borderColor', 'colorValue'):
                    cat = 'B-white-bg' if is_white else 'B-bg'
                elif prop in ('fontColor', 'color'):
                    cat = 'A-white-fg' if is_white else 'C-fg'
                else:
                    cat = 'D-other'
                records.append({'file': rel, 'line': i, 'prop': prop, 'lit': lit,
                                'cat': cat, 'text': s[:180]})

print('total literals:', len(records))
print(Counter(r['cat'] for r in records))
print()

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'audit.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(records, f, ensure_ascii=False, indent=1)

for cat in ('B-white-bg', 'B-bg', 'C-fg'):
    print('=' * 18, cat, '=' * 18)
    by = defaultdict(list)
    for r in records:
        if r['cat'] == cat:
            by[r['file']].append(r)
    for fn in sorted(by):
        print('\n##', fn)
        for r in by[fn]:
            print('  L%-4d %-17s %-30s %s' % (r['line'], r['prop'], r['lit'], r['text'][:110]))
