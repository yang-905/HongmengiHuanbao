"""娣辫壊妯″紡閫傞厤瀹¤锛氭姄鍑烘墍鏈夌‖缂栫爜棰滆壊瀛楅潰閲忓苟鎸変笂涓嬫枃鍒嗙被銆?
鍒嗙被瑙勫垯锛堝敖閲忚创杩戞湰椤圭洰宸茬‘绔嬬殑鍙ｅ緞锛夛細
  A 鐧藉瓧/鐧界嚎鍙犲湪鍝佺墝瀹炲簳涓?  -> 娣辫壊涓嬩篃搴斾繚鎸佺櫧锛堟湁鎰忎负涔嬶紝閫氬父鏃犻渶鏀癸級
  B 鑳屾櫙/搴曡壊绫诲啓姝伙紙backgroundColor/linearGradient/fill锛?> 娣辫壊涓嬩細鍙戠櫧/鍙戣剰锛岄噸鐐规煡
  C 鏂囧瓧鑹插啓姝伙紙fontColor锛変笖涓嶆槸鐧借壊 -> 娣辫壊涓嬪彲鑳界湅涓嶆竻锛岄噸鐐规煡
  D 闃村奖/鎻忚竟/鍗婇€忔槑鐧?        -> 涓€鑸畨鍏紝浣嗘繁鑹蹭笅鍙兘鍙戠伆
杈撳嚭锛氭寜绫诲埆 + 鏂囦欢鍒嗙粍锛岄檮 file:line 涓庡師濮嬭锛屼究浜庨€愭潯纭銆?"""
import os
import re
import json

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
                # 鎵捐繖涓€琛岄鑹插墠闈㈢殑灞炴€у悕锛堝悓涓€琛屽唴锛?                head = line[:m.start()]
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
                is_white = r is not None and r >= 245 and g >= 245 and b >= 245
                if prop in ('backgroundColor', 'fill', 'stroke', 'track',
                            'linearGradient', 'radialGradient', 'shadow',
                            'border', 'borderColor'):
                    if is_white:
                        cat = 'B-white-bg'
                    else:
                        cat = 'B-bg'
                elif prop in ('fontColor', 'color'):
                    cat = 'A-white-fg' if is_white else 'C-fg'
                else:
                    cat = 'D-other'
                records.append({'file': rel, 'line': i, 'prop': prop, 'lit': lit,
                                'cat': cat, 'text': s[:160]})

from collections import Counter, defaultdict
print('total literals:', len(records))
print(Counter(r['cat'] for r in records))
print()

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'audit.json'), 'w', encoding='utf-8') as f:
    json.dump(records, f, ensure_ascii=False, indent=1)

# 閲嶇偣绫诲埆锛欱-bg锛堝啓姝荤殑鑳屾櫙搴曪級涓?C-fg锛堥潪鐧芥枃瀛楄壊锛?for cat in ('B-bg', 'B-white-bg', 'C-fg'):
    print('=' * 20, cat, '=' * 20)
    by = defaultdict(list)
    for r in records:
        if r['cat'] == cat:
            by[r['file']].append(r)
    for fn in sorted(by):
        print('\n##', fn)
        for r in by[fn]:
            print('  L%-4d %-16s %-32s %s' % (r['line'], r['prop'], r['lit'], r['text'][:110]))

