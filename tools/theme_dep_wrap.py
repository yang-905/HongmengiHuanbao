#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
深色模式「背景不刷新」修复：按表达式粒度补 themeTick 依赖
=================================================================
根因（2026-10-20 用户反馈「打开深色模式后字体颜色自动刷新，但背景颜色不变」）：
  ThemePalette.applyDark() 换的是 **static 字段**，ArkTS 静态字段不响应；
  换肤广播 AppStorage('themeTick') 后，ArkUI 只重求值**自身读取了 themeTick
  的属性表达式**——组件订阅了 themeTick、甚至 build 里有恒读钩子，都救不了
  不读 themeTick 的绑定（SettingsPage 第 314 行 opacity 钩子救不了第 325 行
  backgroundColor，实证）。
  于是：走 tc() 的 CfSwitchRow 内部白字已上屏，页面自身裸读 static 的
  背景/渐变/文字全部停滞在浅色套值。

修法（与全库既有 tc() 范式一致，见 Components.ets）：
  · 字符串色值  Class.TOKEN            → this.tc(Class.TOKEN)
  · 非串返回值  Class.fn(...)          → this.tw(Class.fn(...))   （泛型恒等）
  · 布尔分流    ThemePalette.dark      → this.td()
  三者都读取 this.themeTick → 属性表达式建立 themeTick 依赖 → 换肤广播后
  重求值 → 重新读取 static 新色值。
  td() 体内经 Theme.ets 的 isDarkMode() 间接取静态字段，避免本脚本重跑时
  把 helper 自身的裸读再包一层（自递归）。

作用范围：仅 **@Component struct 体内部** 的读取（模块级 @Builder / 数据层无 this，不碰）；
          跳过注释、字符串字面量、已包装（tc(/tw(/td(）及其外层调用；
          Theme.ets / GlassLight.ets / ThemeMode.ets 是色值库本身，不包装。

应用分两阶段（避免位置平移出错）：
  阶段 0  必要时并入 isDarkMode import，然后**重新解析**（位置全部以新文本为准）
  阶段 1  只做表达式包装（按 start 降序应用，位置互不影响）
  阶段 2  重新解析，统计各 struct 需要的 helper，**只做插入**（按位置降序应用）

用法：
  python tools/theme_dep_wrap.py           # 审计（只读，打印报告）
  python tools/theme_dep_wrap.py --apply   # 执行包装 + 按需补 helper/字段
  python tools/theme_dep_wrap.py --apply --only pages/Index.ets
"""
import os
import re
import sys
import pathlib

ETS_ROOT = pathlib.Path(r"D:\11\carbon-master\app\entry\src\main\ets")

# 色值库 / 主题管理自身，不包装
EXCLUDE_FILES = {
    ETS_ROOT / "ui" / "Theme.ets",
    ETS_ROOT / "ui" / "GlassLight.ets",
    ETS_ROOT / "data" / "ThemeMode.ets",
}
# 无 build 作用域的层：审计时列出其中的色值读取供人工确认，不自动包装
REPORT_ONLY_DIRS = {ETS_ROOT / "data", ETS_ROOT / "net", ETS_ROOT / "common"}

# ---- 字符串色值字段（wrap → this.tc）----
TC_FIELDS = {
    "Neutral": {"BG", "CARD", "SURFACE", "TEXT", "TEXT_SUB", "TEXT_MUTED", "BORDER", "INK"},
    "Brand": {"PRIMARY", "PRIMARY_DEEP", "PRIMARY_LIGHT", "PRIMARY_PALE", "PRIMARY_MIST",
              "SPLASH_FROM", "SPLASH_TO"},
    "Accent": {"TRAVEL", "TRAVEL_BG", "ENERGY", "ENERGY_BG", "RECYCLE", "RECYCLE_BG",
               "FOOD", "FOOD_BG", "SUCCESS", "SUCCESS_BG", "WARNING", "WARNING_BG",
               "DANGER", "DANGER_BG", "INFO", "INFO_BG"},
    "EcoMood": {"ECO_FROM", "ECO_TO", "ECO_BG", "ECO_ACCENT",
                "GOOD_FROM", "GOOD_TO", "GOOD_BG", "GOOD_ACCENT",
                "WARN_FROM", "WARN_TO", "WARN_BG", "WARN_ACCENT",
                "ALERT_FROM", "ALERT_TO", "ALERT_BG", "ALERT_ACCENT",
                "NONE_FROM", "NONE_TO", "NONE_BG", "NONE_ACCENT",
                "ECO_SOLID", "GOOD_SOLID", "WARN_SOLID", "ALERT_SOLID", "NONE_SOLID"},
    "Glass": {"CARD_BG", "BOTTOM_BAR_BG", "PILL_BG", "TOPBAR_BG", "PANEL_LIVE_BG",
              "SEGMENT_TRACK_BG", "DISC_BG", "DISC_SOLID_BG", "EDGE", "HIGHLIGHT"},
    "Shadow": {"cardColor", "brandColor", "raisedColor"},
    "InputField": {"BG", "BORDER", "PLACEHOLDER", "TEXT", "CURSOR", "FOCUS_BORDER", "AFFIX"},
}

# ---- 返回字符串色值的函数（wrap → this.tc；括号调用整体吞掉）----
TC_METHODS = {
    "EcoMood": {"edgeOf"},                                   # blurOf 只随档位、不随明暗，不包装
    "InputField": {"focusBorder", "bg", "border", "placeholder", "text", "cursor"},
    "CategoryMeta": {"color", "bg"},
    "EcoTheme": {"from", "to", "bg", "bgSolid", "accent", "primary", "primaryLight",
                 "primaryDeep", "heroFrom", "heroMid", "heroTo", "primaryPale",
                 "shadowColor", "glow", "numberGlow", "moodAccent", "moodTint",
                 "tintByMood", "moodColor"},
}

# ---- 返回非字符串（数组/对象/布尔）的 theme 相关函数（wrap → this.tw）----
TW_METHODS = {
    "Shadow": {"card", "brand", "raised"},                   # none() 是常量黑，不包装
    "Glass": {"edge"},
    "GlassLight": {"tintColor", "surface", "flat", "pillSurface", "washColors",
                   "scrimColors", "fresnelColors", "borderColors", "textScrim",
                   "shadowTintOf", "shadowOf"},
}

# ---- 布尔分流（replace → this.td()）----
TD_READS = {"ThemePalette": {"dark"}}

TOKEN_RE = re.compile(
    r"\b(Neutral|Brand|Accent|EcoMood|Glass|Shadow|InputField|CategoryMeta|EcoTheme"
    r"|GlassLight|ThemePalette)\.([A-Za-z_][A-Za-z0-9_]*)")

STRUCT_RE = re.compile(r"^(?:export\s+)?struct\s+(\w+)\s*\{", re.M)

HELPER_COMMENT = ("\n  /*\n   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：\n"
                  "   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取\n"
                  "   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。\n   */\n")


# ---------------------------------------------------------------- 词法工具

def scan_strings_and_comments(text):
    """返回 (clean_text, string_ranges)。注释字符替换为空格（保留换行以维持行号）。"""
    out = list(text)
    str_ranges = []
    i, n = 0, len(text)
    state = "normal"
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state == "normal":
            if c == "/" and nxt == "/":
                state = "line_comment"
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if c == "/" and nxt == "*":
                state = "block_comment"
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if c in "'\"":
                state = "sq" if c == "'" else "dq"
                str_ranges.append([i, None])
                i += 1
                continue
            if c == "`":
                state = "tpl"
                str_ranges.append([i, None])
                i += 1
                continue
            i += 1
            continue
        if state == "line_comment":
            if c == "\n":
                state = "normal"
            else:
                out[i] = " "
            i += 1
            continue
        if state == "block_comment":
            if c == "*" and nxt == "/":
                out[i] = out[i + 1] = " "
                state = "normal"
                i += 2
                continue
            if c != "\n":
                out[i] = " "
            i += 1
            continue
        if state in ("sq", "dq"):
            if c == "\\":
                out[i] = " "
                if i + 1 < n:
                    out[i + 1] = " "
                i += 2
                continue
            if (c == "'" and state == "sq") or (c == '"' and state == "dq"):
                str_ranges[-1][1] = i
                state = "normal"
            i += 1
            continue
        if state == "tpl":
            if c == "\\":
                out[i] = " "
                if i + 1 < n:
                    out[i + 1] = " "
                i += 2
                continue
            if c == "`":
                str_ranges[-1][1] = i
                state = "normal"
            i += 1
            continue
    return "".join(out), str_ranges


def in_ranges(pos, ranges):
    for s, e in ranges:
        if s <= pos and (e is None or pos < e):
            return True
    return False


def match_paren(text, open_idx):
    """open_idx 指向 '('，返回配对 ')' 的下标；找不到返回 None。跳过字符串。"""
    depth = 0
    i, n = open_idx, len(text)
    state = "normal"
    while i < n:
        c = text[i]
        if state == "normal":
            if c in "'\"`":
                state = c
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return i
        elif c == "\\":
            i += 1
        elif c == state:
            state = "normal"
        i += 1
    return None


def word_before(text, idx):
    """idx 前一个标识符单词（跳过空白）。"""
    j = idx
    while j >= 0 and text[j] in " \t\r\n":
        j -= 1
    k = j
    while k >= 0 and (text[k].isalnum() or text[k] == "_"):
        k -= 1
    return text[k + 1:j + 1]


# ------------------------------------------------------------ 括号匹配 / 幂等

def build_paren_map(clean, str_ranges):
    """返回 (pmap, encl, parent)：
      pmap   {open_idx: close_idx}
      encl   长度=len(clean) 的数组，encl[i] = 位置 i 直接所在的最内层 '(' 下标（-1 无）
      parent {open_idx: 上一层 '(' 下标}
    跳过字符串内部。"""
    in_str = bytearray(len(clean))
    for s, e in str_ranges:
        end = len(clean) if e is None else e
        for k in range(s, end):
            in_str[k] = 1
    n = len(clean)
    pmap = {}
    parent = {}
    encl = [-1] * n
    stack = []
    for i in range(n):
        if in_str[i]:
            continue
        c = clean[i]
        if c == "(":
            parent[i] = stack[-1] if stack else -1
            stack.append(i)
            encl[i] = parent[i]
        elif c == ")":
            if stack:
                o = stack.pop()
                pmap[o] = i
            encl[i] = stack[-1] if stack else -1
        else:
            encl[i] = stack[-1] if stack else -1
    return pmap, encl, parent


def enclosing_wrapped(clean, pmap, encl, parent, pos):
    """pos 处的 token 是否已位于某个 tc(/tw(/td( 调用内部。

    沿括号链**逐层向外**判定：任一层是 tc/tw/td 即视为已包装。
    （只查最近一层会漏判 this.tc(InputField.bg(ThemePalette.dark)) 的内层，
      导致重跑时二次包装。）
    """
    o = encl[pos]
    guard = 0
    while o is not None and o >= 0 and guard < 64:
        guard += 1
        if word_before(clean, o - 1) in ("tc", "tw", "td"):
            return True
        o = parent.get(o, -1)
    return False


def already_wrapped(clean, pos):
    """pos 紧前方是否已是 this.tc( / this.tw( / this.td( 。"""
    return word_before(clean, pos - 1) in ("tc", "tw", "td")


# ---------------------------------------------------------------- 结构解析

def find_struct_ranges(clean):
    """[(name, start, end, is_component)]，end 为 struct 花括号配对后的下标（不含）。"""
    ranges = []
    for m in STRUCT_RE.finditer(clean):
        name = m.group(1)
        open_idx = clean.index("{", m.end() - 1)
        depth = 0
        i = open_idx
        state = "normal"
        n = len(clean)
        while i < n:
            c = clean[i]
            if state == "normal":
                if c in "'\"`":
                    state = c
                elif c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        break
            elif c == "\\":
                i += 1
            elif c == state:
                state = "normal"
            i += 1
        head = clean[max(0, m.start() - 800):m.start()]
        # 装饰器必须在「上一个结构结束」之后才有效，否则会误判到上一个 struct
        cut = max(head.rfind("}"), head.rfind(";"))
        head = head[cut + 1:]
        is_component = ("@Component" in head) or ("@Entry" in head)
        ranges.append((name, m.start(), i + 1, is_component))
    return ranges


def collect_ops(clean, str_ranges, pmap, encl, parent, struct_ranges):
    """收集包装操作 [(start, end, replacement, kind, struct_name)]，kind ∈ tc/tw/td。"""
    ops = []
    for m in TOKEN_RE.finditer(clean):
        cls, member = m.group(1), m.group(2)
        s, e = m.start(), m.end()
        if in_ranges(s, str_ranges):
            continue
        if already_wrapped(clean, s) or enclosing_wrapped(clean, pmap, encl, parent, s):
            continue
        # 仅 @Component struct 内部才包装（模块级 @Builder / 普通类无 this）
        owner = None
        for name, st, en, is_comp in struct_ranges:
            if st <= s < en:
                if is_comp:
                    owner = name
                break
        if owner is None:
            continue
        kind = None
        end = e
        if cls in TD_READS and member in TD_READS[cls]:
            kind = "td"
        elif cls in TC_FIELDS and member in TC_FIELDS[cls]:
            j = e
            while j < len(clean) and clean[j] in " \t\r\n":
                j += 1
            if j < len(clean) and clean[j] == "(":
                continue
            kind = "tc"
        elif cls in TC_METHODS and member in TC_METHODS[cls]:
            j = e
            while j < len(clean) and clean[j] in " \t\r\n":
                j += 1
            if j >= len(clean) or clean[j] != "(":
                continue
            close = match_paren(clean, j)
            if close is None:
                continue
            end = close + 1
            kind = "tc"
        elif cls in TW_METHODS and member in TW_METHODS[cls]:
            j = e
            while j < len(clean) and clean[j] in " \t\r\n":
                j += 1
            if j >= len(clean) or clean[j] != "(":
                continue
            close = match_paren(clean, j)
            if close is None:
                continue
            end = close + 1
            kind = "tw"
        if kind is None:
            continue
        if kind == "td":
            ops.append((s, e, "this.td()", "td", owner))
        else:
            seg = clean[s:end]
            ops.append((s, end, "this.%s(%s)" % (kind, seg), kind, owner))
    # 去掉被外层吞掉的嵌套（外层 tc/tw 调用内部不再单独处理）
    ops.sort(key=lambda o: (o[0], -(o[1] - o[0])))
    kept = []
    last_end = -1
    for o in ops:
        if o[0] < last_end:
            continue
        kept.append(o)
        last_end = o[1]
    return kept


def analyze(text):
    """一次性解析出后续所有阶段需要的信息。"""
    clean, str_ranges = scan_strings_and_comments(text)
    pmap, encl, parent = build_paren_map(clean, str_ranges)
    struct_ranges = find_struct_ranges(clean)
    ops = collect_ops(clean, str_ranges, pmap, encl, parent, struct_ranges)
    return {"clean": clean, "str": str_ranges, "pmap": pmap, "encl": encl,
            "parent": parent, "structs": struct_ranges, "ops": ops}


# ---------------------------------------------------------------- helper 注入

def rel_theme_import(path):
    rel = os.path.relpath(str(ETS_ROOT / "ui" / "Theme.ets"), str(path.parent))
    return rel.replace("\\", "/")


def build_helper_block(needs, nl):
    lines = [HELPER_COMMENT]
    if "field" in needs:
        lines.append("  @StorageProp('themeTick') private themeTick: number = 0\n")
    if "tc" in needs:
        lines.append("  private tc(c: string): string {\n"
                     "    return this.themeTick >= 0 ? c : c\n"
                     "  }\n")
    if "tw" in needs:
        lines.append("  private tw<T>(v: T): T {\n"
                     "    return this.themeTick >= 0 ? v : v\n"
                     "  }\n")
    if "td" in needs:
        lines.append("  private td(): boolean {\n"
                     "    return this.themeTick >= 0 ? isDarkMode() : isDarkMode()\n"
                     "  }\n")
    return "".join(lines).replace("\n", nl)


def ensure_import(text, names, path, nl):
    """确保 import 了 names（集合）里的符号；优先并入已有的 Theme import。"""
    missing = [n for n in names if not re.search(r"import\s*\{[^}]*\b%s\b" % n, text)]
    if not missing:
        return text
    m = re.search(r"import\s*\{([^}]*)\}\s*from\s*'([^']*Theme)'\s*;", text)
    if m:
        exist = [x.strip() for x in m.group(1).split(",") if x.strip()]
        merged = sorted(set(exist) | set(missing))
        return text[:m.start()] + "import { %s } from '%s';" % (", ".join(merged), m.group(2)) + text[m.end():]
    imports = list(re.finditer(r"^import\s.*;\s*$", text, re.M))
    line = "import { %s } from '%s';" % (", ".join(sorted(missing)), rel_theme_import(path))
    if imports:
        last = imports[-1]
        return text[:last.end()] + nl + line + text[last.end():]
    return line + nl + text


def struct_open_brace(text, st):
    """struct 关键字位置 → struct 体 '{' 的下标。"""
    return text.index("{", st)


def plan_helpers(text, info, fname):
    """返回 (insertions, problems)。insertions = [(pos, block)]，pos 为 struct '{' 之后。

    body 取自 clean（注释已剥离，长度与原文本一致），避免注释里的
    'this.tc(' 之类造成误判；插入位置用原文本。
    """
    problems = []
    insertions = []
    for name, st, en, is_comp in info["structs"]:
        if not is_comp:
            continue
        body = info["clean"][st:en]
        uses = {k: ("this.%s(" % k) in body for k in ("tc", "tw", "td")}
        if not any(uses.values()):
            continue

        def has_method(nm, _body=body):
            # 排除 'this.tc(' 这类调用点：前导字符不能是 '.' 或标识符字符
            pat = r"(?<![\w.$])(?:private\s+|public\s+|protected\s+)?%s\s*[<(]" % nm
            return re.search(pat, _body) is not None

        has_field = re.search(r"@StorageProp\(\s*'themeTick'\s*\)", body) is not None
        has_member = re.search(r"^\s*(?:private\s+|public\s+)?themeTick\s*:", body, re.M) is not None

        needs = set()
        for k in ("tc", "tw", "td"):
            if uses[k] and not has_method(k):
                needs.add(k)
        any_method = any(has_method(k) for k in ("tc", "tw", "td"))
        if (needs or any_method) and not has_field and not has_member:
            needs.add("field")
        elif any_method and not has_field and has_member:
            problems.append("%s: struct %s 有 themeTick 成员但非 @StorageProp，请人工确认"
                            % (fname, name))
        if needs:
            nl = "\r\n" if "\r\n" in body else "\n"
            insertions.append((struct_open_brace(text, st) + 1, build_helper_block(needs, nl)))
    return insertions, problems


# ---------------------------------------------------------------- 主流程

def process_file(path, apply_mode):
    with open(path, "r", encoding="utf-8", newline="") as fh:
        raw = fh.read()
    nl = "\r\n" if "\r\n" in raw else "\n"

    info = analyze(raw)
    ops = info["ops"]

    if any(path.parent == d or d in path.parents for d in REPORT_ONLY_DIRS):
        if ops:
            print("  [仅报告] %-52s %d 处色值读取（数据层，无 this，未包装）"
                  % (path.relative_to(ETS_ROOT), len(ops)))
        return 0
    if not ops:
        return 0

    tc_n = sum(1 for o in ops if o[3] == "tc")
    tw_n = sum(1 for o in ops if o[3] == "tw")
    td_n = sum(1 for o in ops if o[3] == "td")
    print("  %-58s tc:%-3d tw:%-3d td:%-3d" % (path.relative_to(ETS_ROOT), tc_n, tw_n, td_n))

    if not apply_mode:
        return len(ops)

    text = raw
    # ---- 阶段 0：必要 import（改文本后必须整体重解析）----
    if any(o[3] == "td" for o in ops):
        text = ensure_import(text, {"isDarkMode"}, path, nl)

    # ---- 阶段 1：只做表达式包装（按 start 降序，位置互不影响）----
    info = analyze(text)
    ops = info["ops"]
    for s, e, rep, kind, owner in sorted(ops, key=lambda o: -o[0]):
        text = text[:s] + rep + text[e:]

    # ---- 阶段 2：重新解析，只做 helper 插入（按位置降序）----
    info = analyze(text)
    insertions, problems = plan_helpers(text, info, path.name)
    for pos, ins in sorted(insertions, key=lambda x: -x[0]):
        text = text[:pos] + ins + text[pos:]

    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    for p in problems:
        print("    !! %s" % p)
    return len(ops)


def main():
    apply_mode = "--apply" in sys.argv
    only = None
    for i, a in enumerate(sys.argv):
        if a == "--only" and i + 1 < len(sys.argv):
            only = sys.argv[i + 1]
    print("=" * 78)
    print("深色模式依赖审计%s" % ("（执行包装）" if apply_mode else "（只读）"))
    print("=" * 78)
    total_ops, total_files = 0, 0
    for f in sorted(ETS_ROOT.rglob("*.ets")):
        if f in EXCLUDE_FILES:
            continue
        if only is not None and only not in str(f).replace("\\", "/"):
            continue
        n = process_file(f, apply_mode)
        total_ops += n
        if n:
            total_files += 1
    print("-" * 78)
    print("合计：%d 处表达式待补/已补 themeTick 依赖，涉及 %d 个文件" % (total_ops, total_files))
    if not apply_mode:
        print("加 --apply 执行包装。")


if __name__ == "__main__":
    main()
