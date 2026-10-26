# 批量把线性/径向渐变的 colors 数组里的 EcoTheme.primary* 换成深色专用 hero* 色位。
# 只处理 "colors: [" 括号内部，绝不碰 fontColor 等文字引用（primaryDeep 是文字强调色，改暗会看不见）。
import re
import pathlib
import sys

ROOT = pathlib.Path(r"D:\11\carbon-master\app\entry\src\main\ets\pages")
COLORS = re.compile(r"colors:\s*\[")

def replace_in_colors_arrays(text):
    out = []
    pos = 0
    count = 0
    while True:
        m = COLORS.search(text, pos)
        if not m:
            out.append(text[pos:])
            break
        start = m.end() - 1  # index of '['
        depth = 0
        j = start
        while j < len(text):
            c = text[j]
            if c == '[':
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        seg = text[start:j + 1]
        new_seg = seg
        # 先长后短，避免 primary( 抢匹配 primaryLight(/primaryDeep(
        new_seg = new_seg.replace('EcoTheme.primaryDeep(', 'EcoTheme.heroTo(')
        new_seg = new_seg.replace('EcoTheme.primaryLight(', 'EcoTheme.heroFrom(')
        new_seg = new_seg.replace('EcoTheme.primary(', 'EcoTheme.heroMid(')
        if new_seg != seg:
            count += 1
        out.append(text[pos:start])
        out.append(new_seg)
        pos = j + 1
    return ''.join(out), count

total_files = 0
total_arrays = 0
for f in sorted(ROOT.rglob("*.ets")):
    src = f.read_text(encoding="utf-8")
    new, cnt = replace_in_colors_arrays(src)
    if new != src:
        f.write_text(new, encoding="utf-8")
        total_files += 1
        total_arrays += cnt
        print(f"  {f.relative_to(ROOT)}  ({cnt} arrays)")
print(f"DONE: {total_files} files, {total_arrays} colors arrays updated")
