#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""包装后完整性校验：
  1) 每个 struct 内使用了 this.tc/tw/td 的，必须有对应方法定义
  2) 使用了 themeTick 的，必须有 @StorageProp('themeTick') 字段
  3) 括号配对平衡（跳过字符串/注释）
  4) 无重复 helper 定义
  5) 无残留碎片（如 "'', 1) })" 这类断裂文本）
"""
import re
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import theme_dep_wrap as W

ETS_ROOT = W.ETS_ROOT

def main():
    bad = 0
    total_struct = 0
    for f in sorted(ETS_ROOT.rglob("*.ets")):
        with open(f, "r", encoding="utf-8", newline="") as fh:
            raw = fh.read()
        info = W.analyze(raw)
        clean = info["clean"]
        # 括号平衡
        if clean.count("(") != clean.count(")"):
            print("!! %s: 括号不平衡 ( = %d, ) = %d" % (f.name, clean.count("("), clean.count(")")))
            bad += 1
        if clean.count("{") != clean.count("}"):
            print("!! %s: 花括号不平衡" % f.name)
            bad += 1
        # 碎片检测：出现「已闭合的字符串字面量后紧跟多余右括号」且其外层无对应左括号
        # （真正断裂会表现为 this.tw(...('', 1) }) 这种残缺尾巴）
        for m in re.finditer(r"[;{]\s*\)", clean):
            print("!! %s: 多余右括号: %r" % (f.name, clean[max(0, m.start()-70):m.end()]))
            bad += 1
        # 跨行未闭合：this.tc(/tw(/td( 之后直到文件末尾仍未闭合
        for m in re.finditer(r"this\.(?:tc|tw|td)\(", clean):
            seg = clean[m.end():]
            if seg.count("(") > seg.count(")"):
                print("!! %s: 未闭合包装于 offset %d" % (f.name, m.start()))
                bad += 1
        # helper 定义
        for name, st, en, is_comp in info["structs"]:
            if not is_comp:
                continue
            body = clean[st:en]
            total_struct += 1
            def count_def(nm):
                return len(re.findall(r"(?<![\w.$])(?:private\s+|public\s+|protected\s+)?%s\s*[<(]" % nm, body))
            for nm in ("tc", "tw", "td"):
                used = ("this.%s(" % nm) in body
                ndef = count_def(nm)
                if used and ndef == 0:
                    print("!! %s/%s: 使用了 this.%s( 但无定义" % (f.name, name, nm))
                    bad += 1
                if ndef > 1:
                    print("!! %s/%s: %s 定义重复 %d 次" % (f.name, name, nm, ndef))
                    bad += 1
            if ("themeTick" in body) and ("@StorageProp('themeTick')" not in body):
                if not re.search(r"^\s*(?:private\s+|public\s+)?themeTick\s*:", body, re.M):
                    print("!! %s/%s: 用了 themeTick 但无字段声明" % (f.name, name))
                    bad += 1
    print("=" * 60)
    print("校验 %d 个 @Component struct，问题 %d 处" % (total_struct, bad))
    return bad

if __name__ == "__main__":
    sys.exit(0 if main() == 0 else 1)
