# -*- coding: utf-8 -*-
"""生成《一触青绿》作品设计详细版 Word 文档（.docx）
格式要求：正文宋体小四（12pt）、1.5 倍行距；标题黑体分级。
"""
import os
import re
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(ROOT, "docs", "assets")
OUT = os.path.join(ROOT, "docs", "一触青绿_作品设计详细文档.docx")

BLACK = RGBColor(0x00, 0x00, 0x00)
TEAL = RGBColor(0x0F, 0x6E, 0x56)


def set_ea(style_or_run_rpr, east_asia):
    rfonts = style_or_run_rpr.get_or_add_rFonts()
    rfonts.set(qn("w:eastAsia"), east_asia)


def style_font(style, ascii_font, ea, size, bold=False):
    style.font.name = ascii_font
    style.font.size = Pt(size)
    style.font.bold = bold
    style.font.color.rgb = BLACK
    set_ea(style.element.get_or_add_rPr(), ea)


def setup(doc):
    st = doc.styles["Normal"]
    style_font(st, "Times New Roman", "宋体", 12)
    pf = st.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)

    for name, size in [("Heading 1", 16), ("Heading 2", 14), ("Heading 3", 12)]:
        h = doc.styles[name]
        style_font(h, "黑体", "黑体", size, bold=True)
        h.paragraph_format.line_spacing = 1.5
        h.paragraph_format.space_before = Pt(14 if name == "Heading 1" else 10)
        h.paragraph_format.space_after = Pt(8 if name == "Heading 1" else 6)

    sec = doc.sections[0]
    sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)
    sec.top_margin = sec.bottom_margin = Cm(2.54)
    sec.left_margin = sec.right_margin = Cm(3.0)
    sec.different_first_page_header_footer = True

    # 页脚页码
    fp = sec.footer.paragraphs[0]
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = fp.add_run()
    for el, attr, val in [("w:fldChar", "w:fldCharType", "begin")]:
        e = OxmlElement(el)
        e.set(qn(attr), val)
        r._r.append(e)
    it = OxmlElement("w:instrText")
    it.set(qn("xml:space"), "preserve")
    it.text = " PAGE "
    r._r.append(it)
    e2 = OxmlElement("w:fldChar")
    e2.set(qn("w:fldCharType"), "end")
    r._r.append(e2)
    r.font.size = Pt(9)
    set_ea(r._r.get_or_add_rPr(), "宋体")

    # 打开时自动更新域（目录）
    s = doc.settings.element
    uf = OxmlElement("w:updateFields")
    uf.set(qn("w:val"), "true")
    s.append(uf)


TOKEN = re.compile(r"(\*\*.+?\*\*|`.+?`)")


def rich(p, text, size=None, ea="宋体", ascii_font="Times New Roman"):
    for seg in TOKEN.split(text):
        if not seg:
            continue
        if seg.startswith("**") and seg.endswith("**"):
            r = p.add_run(seg[2:-2])
            r.bold = True
        elif seg.startswith("`") and seg.endswith("`"):
            r = p.add_run(seg[1:-1])
            r.font.name = "Consolas"
            set_ea(r._r.get_or_add_rPr(), "宋体")
        else:
            r = p.add_run(seg)
            r.font.name = ascii_font
            set_ea(r._r.get_or_add_rPr(), ea)
        if size:
            r.font.size = Pt(size)
    return p


def para(doc, text, indent=True, align=None, size=None):
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing = 1.5
    if indent:
        p.paragraph_format.first_line_indent = Pt(24)
    if align:
        p.alignment = align
    rich(p, text, size=size)
    return p


def heading(doc, text, level):
    h = doc.add_heading(text, level=level)
    for r in h.runs:
        r.font.color.rgb = BLACK
    return h


def numlist(doc, items, start=1):
    for i, t in enumerate(items, start):
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.left_indent = Pt(26)
        p.paragraph_format.first_line_indent = Pt(-26)
        rich(p, "%d. %s" % (i, t))


def bullets(doc, items):
    for t in items:
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.left_indent = Pt(26)
        p.paragraph_format.first_line_indent = Pt(-26)
        rich(p, "· " + t)


def shade_cell(cell, hexfill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:fill"), hexfill)
    tcPr.append(shd)


def table(doc, header, rows, widths=None, size=10.5):
    t = doc.add_table(rows=1, cols=len(header))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for j, htxt in enumerate(header):
        c = t.rows[0].cells[j]
        c.text = ""
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.line_spacing = 1.15
        r = p.add_run(htxt)
        r.bold = True
        r.font.size = Pt(size)
        r.font.name = "Times New Roman"
        set_ea(r._r.get_or_add_rPr(), "宋体")
        shade_cell(c, "E1F5EE")
    for row in rows:
        cells = t.add_row().cells
        for j, val in enumerate(row):
            c = cells[j]
            c.text = ""
            p = c.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            rich(p, str(val), size=size)
    if widths:
        for j, w in enumerate(widths):
            for row in t.rows:
                row.cells[j].width = Cm(w)
    doc.add_paragraph().paragraph_format.line_spacing = 1.0
    return t


def code(doc, text):
    for line in text.strip("\n").split("\n"):
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.line_spacing = 1.15
        pf.left_indent = Pt(12)
        pf.space_after = Pt(0)
        pPr = p._p.get_or_add_pPr()
        shd = OxmlElement("w:shd")
        shd.set(qn("w:val"), "clear")
        shd.set(qn("w:fill"), "F5F5F5")
        pPr.append(shd)
        r = p.add_run(line if line else " ")
        r.font.name = "Consolas"
        r.font.size = Pt(9)
        set_ea(r._r.get_or_add_rPr(), "宋体")
    doc.add_paragraph().paragraph_format.line_spacing = 1.0


def figure(doc, fname, caption):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.line_spacing = 1.0
    p.paragraph_format.space_before = Pt(6)
    p.add_run().add_picture(os.path.join(ASSETS, fname), width=Cm(14.0))
    cp = doc.add_paragraph()
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.paragraph_format.line_spacing = 1.15
    cp.paragraph_format.space_after = Pt(10)
    r = cp.add_run(caption)
    r.font.size = Pt(10.5)
    r.font.name = "Times New Roman"
    set_ea(r._r.get_or_add_rPr(), "宋体")


def pagebreak(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)


def add_toc(doc):
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing = 1.5
    r = p.add_run()
    b = OxmlElement("w:fldChar")
    b.set(qn("w:fldCharType"), "begin")
    it = OxmlElement("w:instrText")
    it.set(qn("xml:space"), "preserve")
    it.text = ' TOC \\o "1-3" \\h \\z \\u '
    sep = OxmlElement("w:fldChar")
    sep.set(qn("w:fldCharType"), "separate")
    t = OxmlElement("w:t")
    t.text = "（目录将在 Word 打开时自动生成；若未显示，请全选后按 F9 或右键选择“更新域”）"
    e = OxmlElement("w:fldChar")
    e.set(qn("w:fldCharType"), "end")
    for el in (b, it, sep, t, e):
        r._r.append(el)


# ============================ 文档构建 ============================

doc = Document()
setup(doc)
cp = doc.core_properties
cp.title = "一触青绿——基于 OpenHarmony 的个人碳足迹记录与碳积分激励应用"
cp.author = "一触青绿项目组"

# ---------- 封面 ----------
for _ in range(4):
    doc.add_paragraph()
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("一触青绿")
r.font.size = Pt(30)
r.font.name = "黑体"
set_ea(r._r.get_or_add_rPr(), "黑体")
r.bold = True

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(12)
r = p.add_run("基于 OpenHarmony 的个人碳足迹记录与碳积分激励应用")
r.font.size = Pt(16)
set_ea(r._r.get_or_add_rPr(), "黑体")

doc.add_paragraph()
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("作 品 设 计 文 档")
r.font.size = Pt(18)
r.font.name = "黑体"
set_ea(r._r.get_or_add_rPr(), "黑体")
for _ in range(3):
    doc.add_paragraph()

table(doc,
      ["项目", "内容"],
      [["作品名称", "一触青绿"],
       ["作品形态", "OpenHarmony 单设备本地应用（手机）"],
       ["技术栈", "ArkTS + ArkUI（API 24）· MindSpore Lite 端侧推理"],
       ["文档版本", "V1.0（详细版）"],
       ["完成日期", "2026 年 10 月"]],
      widths=[4.2, 10.4], size=12)
doc.add_paragraph()
para(doc, "摘要：本作品面向“双碳”战略下个人低碳行为记录与激励的普遍需求，基于 OpenHarmony "
          "开源鸿蒙生态，采用 ArkTS + ArkUI 声明式开发，实现单设备本地运行的碳足迹记录、端侧 AI "
          "辅助识别、碳积分激励与数据可视化闭环。作品坚持“数据不出设备、零服务端依赖”的设计约束，"
          "在保障隐私与离线可用的同时，通过液态玻璃视觉体系与碳情绪反馈提升记录过程的体验与黏性。")
pagebreak(doc)

# ---------- 目录 ----------
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("目  录")
r.font.size = Pt(16)
r.font.name = "黑体"
set_ea(r._r.get_or_add_rPr(), "黑体")
add_toc(doc)
pagebreak(doc)

# ---------- 1 作品概述 ----------
heading(doc, "1  作品概述", 1)
heading(doc, "1.1  背景与意义", 2)
para(doc, "在“双碳”目标推进与公众环保意识提升的背景下，个人层面的低碳行为记录与激励成为碳普惠体系的"
          "重要组成部分。当前市面上的碳账户类应用普遍依赖账号体系与云端服务：用户需要注册登录、数据上传"
          "服务器，既带来隐私顾虑，也在弱网或无网环境下不可用。")
para(doc, "本作品探索一条相反的路径：以开源鸿蒙（OpenHarmony）为技术底座，做一款**单设备、纯本地、零服务端"
          "依赖**的个人碳账本。所有行为记录、积分流水与权益凭证均存储于本机，离线可用、秒开即用、数据不出"
          "设备，为个人碳普惠提供一种轻量、隐私友好的实现形态。")
heading(doc, "1.2  作品定位与目标", 2)
numlist(doc, [
    "**产品定位**：面向个人用户的碳足迹记录与碳积分激励工具，运行于 OpenHarmony 手机，单进程本地闭环。",
    "**录入效率目标**：一笔低碳行为从打开应用到完成记录不超过 3 次核心点击；AI 拍照识别进一步降低录入成本。",
    "**激励闭环目标**：记录产生减排量与积分，积分可兑换本地权益（植树认养、碳惠券），配合任务、徽章、证书形成持续激励。",
    "**体验目标**：以“青绿”为主题的液态玻璃视觉体系，浅色/深色双模式，兼顾美感与低端机性能。",
])
heading(doc, "1.3  创新点", 2)
numlist(doc, [
    "**端侧 AI 识别入账**：基于 MindSpore Lite 与 mobilenetv2 模型的端侧推理，将照片识别为低碳行为并直接入账，"
    "识别过程完全在设备本地完成，无需联网；ImageNet 类别按碳因子聚合，输出 Top3 识别依据与置信度。",
    "**液态玻璃视觉体系**：建立 135° 单一光源模型与材质三档参数（浅色/深色两套），玻璃拟态组件"
    "（GlassSurface / GlassLight / GlassDialog）全应用复用，深色模式全局“换血”而非逐页适配。",
    "**本地优先的数据架构**：LocalStore 单一数据源按数据性质分层落盘——无上限增长的行为记录进 RDB"
    "（relationalStore/SQLite）按需查询与分页，少量键值留 Preferences；写入成功即广播，失败如实上报，"
    "规避全量加载带来的内存与启动开销。",
    "**碳情绪反馈（EcoMood）**：将当日减排量映射为情绪档位并可视化，把抽象的减排数据转化为可感知的情绪反馈，"
    "增强记录行为的正向激励。",
])
heading(doc, "1.4  运行边界与形态", 2)
table(doc,
      ["项", "说明"],
      [["设备形态", "手机（Phone）单设备，屏幕自适应；面向 OpenHarmony 标准系统"],
       ["系统与 API", "OpenHarmony，compileSdk / compatibleSdk / targetSdk 均为 API 24，runtimeOS 为 OpenHarmony"],
       ["运行模式", "单进程本地运行；不请求网络、不依赖服务端、无账号同步、无多端协同"],
       ["数据边界", "业务数据存放于本机 RDB 关系数据库（relationalStore / SQLite），轻量配置与登录态存放于 Preferences；备份与恢复均在设备内完成"]],
      widths=[3.6, 11.0])

# ---------- 2 作品设计思路 ----------
heading(doc, "2  作品设计思路", 1)
heading(doc, "2.1  设计理念", 2)
para(doc, "作品主题为“一触之间，青绿相随”，设计理念围绕三个关键词展开：")
numlist(doc, [
    "**一触**：录入路径极短。首页常驻“＋ 记一笔”主按钮，录入以底部弹窗完成，选因子、调数量、确认三步结束；"
    "AI 识别再把“选因子”这一步也省略。",
    "**青绿**：以青绿色系为主视觉，玻璃拟态材质呼应“清透、自然”的气质；背景插画与碳情绪条随数据变化。",
    "**相随**：记录之后有即时反馈——减排量、积分、等级、连续打卡、情绪档位在首页一眼可见，形成“记录—反馈—"
    "再记录”的正向循环。",
])
heading(doc, "2.2  设计原则", 2)
table(doc,
      ["原则", "含义", "在本作品中的落地"],
      [["单一数据源", "全应用只有一处权威数据", "页面只经 DataSource 访问 LocalStore，不各自持有数据副本"],
       ["口径统一", "减排、积分、植树折算全用一个出口", "stats() 派生统计唯一出口；1 kgCO₂e = 10 积分；3000 积分兑 1 棵树"],
       ["降级优先", "任何能力缺失都有明确退路", "模型缺失/无推理能力/解码失败 → 引导手动录入；落盘失败 → 内存态优先"],
       ["零网络依赖", "不依赖任何服务端", "无网络请求、无轮询、无后台常驻，冷启动快且功耗低"],
       ["务实取舍", "不为“技术先进”增加复杂度", "存储按数据性质分层：无上限增长的行为记录进 RDB 按需查询与分页，少量键值留 Preferences，不做过度设计"]],
      widths=[2.6, 5.0, 7.0])
heading(doc, "2.3  信息架构与功能地图", 2)
para(doc, "作品按“记录—核算—激励—回顾”的用户旅程组织功能，共 6 大模块、约 60 个页面与组件文件，"
          "Navigation 全局路由统一管理转场。功能模块划分如图 1 所示。")
figure(doc, "fig4_modules.png", "图 1  功能模块图")
para(doc, "主要页面及职责见表 1。")
table(doc,
      ["页面 / 组件", "职责", "关键实现"],
      [["首页 Dashboard", "核心指标、碳情绪、趋势、任务、主入口", "stats() 派生统计 + 自绘图表"],
       ["行为录入弹窗 BehaviorAddSheet", "选因子、调数量、备注、确认", "底部弹窗 + 步进器 + 因子库"],
       ["AI 识别页 AiRecognizePage", "选图、识别、确认入账", "PhotoViewPicker + MindSpore Lite"],
       ["记录列表 RecordListPage", "记录浏览、筛选、删除", "RDB 分页 + LazyForEach 懒加载"],
       ["图表分析", "趋势、分类占比、月账单", "本地数据分桶聚合 + Canvas 自绘"],
       ["积分中心 / 商城 / 券包", "积分余额、兑换、核销凭证", "本地事务化兑换 + 券状态机"],
       ["任务 / 徽章 / 证书", "激励反馈与成就体系", "task_claim 表落库 + 证书折算"],
       ["文章与问答", "低碳内容与知识问答", "点赞收藏 RDB 持久化"],
       ["设置 / 我的", "备份恢复、导出、深色模式、清空数据", "RDB 备份槽 + 版本兼容"]],
      widths=[4.4, 5.6, 4.6], size=10)
heading(doc, "2.4  视觉设计", 2)
numlist(doc, [
    "**液态玻璃光照模型**：统一 135° 单一光源方向，高光与阴影角度全局一致；材质分三档（标准 / 轻 / 简），"
    "分别对应不同的模糊半径、高光强度与不透明度，浅色与深色各一套参数（参数详见《液态玻璃与深色模式方案》）。",
    "**组件化落地**：玻璃拟态收敛为 GlassSurface（承载面）、GlassLight（高光条）、GlassDialog（玻璃对话框）"
    "三件套，页面只传档位不传数值，保证跨页一致性。",
    "**深色模式**：跟随系统的同时支持手动切换，切换时全局换血；建立深浅色对比度走查清单并纳入验收。",
    "**画质三档降级**：按设备档位下调模糊与高光强度，保障低端机滚动帧率。",
    "**碳情绪可视化**：EcoMood 将当日减排量映射为情绪档位，首页情绪条随数据实时变化。",
])
heading(doc, "2.5  交互设计", 2)
bullets(doc, [
    "录入交互：底部弹窗 + 数量步进器，关键操作一步可达；确认后 Toast 明示减排量与积分增量。",
    "反馈交互：变更信号广播驱动各页面同步刷新，避免用户手动下拉等待。",
    "列表交互：长列表统一 LazyForExpand + 懒加载适配器，滚动期只构建可见项。",
    "空态与引导：首启以确定性种子数据填充各页（30 天演示记录、27 项因子），提供引导页与空态提示。",
    "确认与撤销：清空数据、兑换等高感知操作走玻璃对话框二次确认。",
])

# ---------- 3 功能实现逻辑 ----------
heading(doc, "3  功能实现逻辑", 1)
heading(doc, "3.1  功能模块划分", 2)
para(doc, "应用按数据流划分为 6 个核心模块：碳足迹记录、碳核算引擎、AI 辅助识别、积分激励、权益凭证、"
          "统计与本地管理。模块间通过 LocalStore 单一数据源解耦，页面不直接访问持久层。")
heading(doc, "3.2  因子库与碳核算逻辑", 2)
para(doc, "因子库内置 27 项行为因子，覆盖交通出行、饮食、居家用电等类别，字段包括类别、名称、单位、"
          "因子值（kg/单位）、基准值、计算公式与来源说明。核算规则如下：")
numlist(doc, [
    "**减排量**：reduceKg = 因子值 × 行为数量，如“骑行 5 公里 × 0.19 kg/公里 = 0.95 kgCO₂e”。",
    "**积分**：points = round(reduceKg × 10)，即 1 kgCO₂e 折算 10 积分，不足 1 分按 1 分保底。",
    "**植树折算**：累计消耗积分每满 3000 分折算 1 棵树（向下取整），与积分商城“公益植树认养”标价一致。",
    "**等级与连续天数**：由 stats() 依据累计减排量与记录连续性计算，作为成就体系的输入。",
    "**演示数据**：首启种子数据用 FNV-1a 哈希伪随机生成，同一 seed 结果稳定，30 天演示记录围绕“今天”生成，"
    "日期不漂移；真实用户注册账号零起步，种子版本标记只升不降，避免误清用户数据。",
])
heading(doc, "3.3  行为记录录入逻辑", 2)
para(doc, "手动录入与 AI 识别共用同一套核算与入账链路，区别仅在于“因子与数量”由谁产生。以手动录入为例，"
          "完整数据流如图 2 所示。")
figure(doc, "fig2_record_flow.png", "图 2  记录一笔低碳行为的数据流")
numlist(doc, [
    "用户在录入弹窗选择因子并调整数量，点击确认。",
    "LocalStore.addRecord 端侧核算减排量与积分（口径唯一出口），组装记录行。",
    "写入 RDB：单行 INSERT 进 carbon_record 表（账号维度 user_key 隔离）；成功后广播 "
    "ecoTick 变更信号，订阅页面立即重新拉取，界面零延迟刷新。",
    "失败即上报：INSERT 失败（磁盘满/库损坏）直接抛错，录入弹窗提示“保存失败，请重试”，"
    "不出现“界面显示成功、重启后数据丢失”的假象。",
    "stats() 按需聚合：累计/今日/本月减排、积分余额、连续天数、等级、植树棵数由 SQL 条件聚合"
    "一次查出（SUM/COUNT 下推），渲染期不再全量遍历记录。",
])
heading(doc, "3.4  AI 拍照识别实现逻辑", 2)
para(doc, "AI 识别是作品降低录入门槛的核心能力，完整链路如图 3 所示。")
figure(doc, "fig3_ai_flow.png", "图 3  AI 拍照识别入账链路")
numlist(doc, [
    "**选图**：通过 PhotoViewPicker 选择图片，免去申请整个相册读取权限。",
    "**预处理**：uri 解码后限长边 640 控制内存，等比放大覆盖 224 后居中裁剪，RGBA 逐通道归一化"
    "（mean=[0.485,0.456,0.406]，std=[0.229,0.224,0.225]），与 ImageNet 训练预处理保持一致。",
    "**推理**：MindSpore Lite 加载 mobilenetv2.ms（ImageNet 1000 类，输入 [1,3,224,224] NCHW float32），"
    "loadModelFromBuffer → getInputs → setData → predict。",
    "**类别聚合**：softmax 后，将映射到同一碳因子 code 的多个 ImageNet 类别概率相加（如多种自行车细分类聚合为"
    "“骑行”），取 Top3 作为“识别依据”展示。",
    "**确认入账**：展示候选因子、置信度与依据，用户确认数量后按 3.2 节同一口径入账；置信度不足时引导手动选择，"
    "不夸大识别能力。",
    "**降级策略**：模型文件缺失、设备无 MindSporeLite 系统能力、解码失败任一发生，即降级为手动录入，"
    "并在界面常驻展示真实原因，不假装可用。",
])
heading(doc, "3.5  积分与激励逻辑", 2)
numlist(doc, [
    "**任务**：每日任务按记录流判定完成度，领取动作写入 taskClaims 落库，刷新后状态不丢失。",
    "**商城兑换**：校验积分余额 → 生成权益记录 → 扣减积分流水，本地事务化完成，避免多键写入不一致。",
    "**碳惠券**：兑换生成的券具备状态流转（待使用 / 已使用 / 已过期），核销后留痕。",
    "**徽章与证书**：依据累计减排、连续打卡、兑换记录解锁；植树证书按 floor(累计消耗积分 / 3000) 折算棵数。",
    "**积分商城商品**：内置公益植树认养（3000 分）等权益，与核算口径同源。",
])
heading(doc, "3.6  统计与图表逻辑", 2)
bullets(doc, [
    "派生统计：stats() 统一输出累计/今日/本月减排、积分余额、连续天数、等级、植树棵数。",
    "趋势图：记录按日期字符串分桶聚合，近 7 日/30 日柱状或折线呈现，ArkUI Canvas 自绘。",
    "分类占比：按因子类别汇总减排量，饼图/环图呈现，口径与因子库类别一致。",
    "月账单：按月汇总记录条数、减排量与积分收支，支持导出分享。",
])
heading(doc, "3.7  数据持久化与备份恢复逻辑", 2)
numlist(doc, [
    "**分层落盘**：行为记录/券/任务领取/文章互动/备份快照落 RDB（SQLite），登录态、种子标记、备份计数等"
    "轻量键值留 Preferences；RDB 索引带 user_key 前缀，账号隔离即索引前缀。",
    "**按需读取**：记录查询全部走 SQL——聚合统计 SUM/COUNT 条件聚合一次出结果，列表 LIMIT/OFFSET "
    "分页读取，单条按 recordId / clientRecordId 定位；init() 不再解析整份数据 JSON。",
    "**账号命名空间**：RDB 行级 user_key 列隔离（空串 = 未登录兼容命名空间），本地多账户数据互不串扰；"
    "旧版 Preferences「键名 @账号」口径由一次性迁移器转换。",
    "**备份槽**：备份写入 RDB backup_slot 表（“记录 + 券”组合结构），恢复时按数组/对象形状判别新旧格式，"
    "老备份不丢；恢复为跨表单事务，记录与券要么整体恢复、要么整体回退。",
    "**恢复与清空**：设置页提供备份恢复、导出报告、恢复演示数据、清空全部数据，高危操作二次确认。",
])

# ---------- 4 技术架构 ----------
heading(doc, "4  技术架构", 1)
heading(doc, "4.1  总体架构", 2)
para(doc, "作品采用五层架构：表现层（ArkUI 声明式页面）→ 交互与组件层（设计体系）→ 数据层（LocalStore 单一"
          "数据源）→ 持久层（RDB 关系数据库 + Preferences 轻量键值）与系统能力。数据单向依赖，页面不直接"
          "触达持久层。总体架构如图 4 所示。")
figure(doc, "fig1_architecture.png", "图 4  作品总体架构图")
table(doc,
      ["层", "组成", "职责", "关键约束"],
      [["表现层", "首页/录入/记录/图表/积分/文章/设置等页面", "渲染与交互", "只读数据层，不直接访问持久层"],
       ["组件层", "玻璃组件/懒加载列表/主题/路由", "设计规范落地与复用", "组件不含业务状态"],
       ["数据层", "LocalStore + CarbonRdb", "唯一数据源、派生统计、变更广播", "读写时序统一，异常可兜底"],
       ["持久层", "RDB（carbon_record / carbon_coupon / task_claim / article_interact / backup_slot）+ Preferences 轻量键值", "本机关系库按需读写，事务保证一致性", "按 user_key 账号隔离，聚合下推、列表分页"],
       ["系统能力", "系统时钟/相册选图/端侧推理", "时间口径、图片输入、AI 推理", "时间口径统一走 AppClock"]],
      widths=[2.0, 4.6, 4.4, 4.6], size=10)
heading(doc, "4.2  关键技术", 2)
numlist(doc, [
    "**ArkTS + ArkUI 声明式开发**：全量页面采用声明式布局，状态驱动渲染，配合 @Builder 复用视图片段。",
    "**Navigation 全局路由**：统一页面转场与导航栈管理，约 60 个页面与组件文件按域划分目录。",
    "**RDB 关系数据库（relationalStore）**：行为记录等业务数据落 SQLite，支持索引、分页与事务；"
    "聚合统计 SUM/COUNT 下推，列表 LIMIT/OFFSET 分页，兑换与恢复走单事务；Preferences 只保留登录态、"
    "种子标记、备份计数等少量键值，规避全量加载的内存与启动开销。",
    "**LocalStore 数据层**：对外 API 收敛为单一数据源，小数据集（券/任务领取/文章互动）内存镜像写穿，"
    "记录全集按需查询，派生统计唯一出口。",
    "**MindSpore Lite 端侧推理**：OpenHarmony 侧可用的端侧推理框架，承载 mobilenetv2 图像分类。",
    "**Canvas 自绘图表**：趋势与分类图表不依赖第三方图表库，按画质三档降级保障帧率。",
])
heading(doc, "4.3  性能与功耗设计", 2)
bullets(doc, [
    "按需读取零全量加载：init() 不再解析整份数据 JSON，记录查询走 SQL 按需取，首屏可交互时间与数据总量脱钩。",
    "分页列表：记录列表 LazyForEach + LIMIT/OFFSET 分页，首屏只读一页，记录涨到几千条首屏依旧轻快。",
    "懒加载：长列表 LazyForEach + 适配器，滚动期只构建可见项。",
    "画质三档降级：模糊与高光按设备档位下调，低端机保帧率。",
    "无轮询、无后台常驻、无网络请求：单机形态下功耗表现良好，切后台不做任何空转。",
    "AI 推理输入先限长边 640 再裁剪 224，控制单次推理内存峰值。",
])
heading(doc, "4.4  存储分层与演进", 2)
para(doc, "存储按数据性质分层，不为统一而统一：")
bullets(doc, [
    "**RDB（relationalStore / SQLite）**：行为记录（无上限增长）、兑换券、任务领取、文章互动、备份快照。"
    "索引全部带 user_key 前缀（账号隔离即索引前缀），聚合统计与合计口径 SQL 下推，列表分页读取，"
    "兑换/恢复/清空/迁移走单事务。",
    "**Preferences**：登录态与账号表（AccountStore）、种子版本标记、备份份数与时间、RDB 迁移标记 —— "
    "都是小键值，读取一次常驻内存。",
    "**一次性迁移**：旧版本 Preferences 大 JSON 由迁移器清洗后写入 RDB（幂等、带完成标记、失败保留旧键"
    "下次重试），迁移成功后删除旧键回收体积；备份内容随之进 backup_slot 表。",
    "**预览器兜底**：RDB 不可用（预览器无应用上下文）时自动退化为内存态，按 user_key 分桶，页面照常演示。",
])

# ---------- 5 软硬件选型 ----------
heading(doc, "5  软硬件选型", 1)
heading(doc, "5.1  硬件选型", 2)
table(doc,
      ["类别", "选型", "用途与理由"],
      [["开发主机", "Windows x86_64 PC，16GB 内存及以上", "运行 DevEco Studio 与模拟器；ArkTS 编译与模拟器调试对内存有一定要求"],
       ["目标设备", "搭载 OpenHarmony 标准系统、API 24 的手机或开发板", "作品运行载体；选择标准系统设备以支持完整的 ArkData、MindSpore Lite 等能力"],
       ["本机存储", "设备内置存储（RDB 数据库文件 + Preferences 键值 + 本机 rawfile）", "存放业务数据与 13.3MB 端侧模型文件；无外部存储依赖"]],
      widths=[2.6, 5.2, 7.8])
heading(doc, "5.2  软件选型", 2)
table(doc,
      ["层面", "选型", "选型理由"],
      [["操作系统", "OpenHarmony（API 24）", "开源鸿蒙生态，分布式能力预留但本作不使用；API 24 提供完整的 ArkTS/ArkData/MindSpore Lite 支持"],
       ["开发 IDE", "DevEco Studio", "OpenHarmony 官方 IDE，内置 API 24 SDK、模拟器与 hvigor 构建"],
       ["开发语言", "ArkTS", "鸿蒙生态首选语言，类型安全，与 ArkUI 状态驱动渲染深度配合"],
       ["UI 框架", "ArkUI 声明式开发", "状态驱动、组件复用、适配深浅色与多屏幕"],
       ["构建工具", "hvigor + ohpm + Git", "工程标配构建与依赖管理；Git 版本控制"],
       ["本地存储", "relationalStore RDB（@kit.ArkData，业务数据）+ Preferences（轻量键值）", "记录无上限增长，RDB 索引/分页/事务支撑按需读取与一致性；Preferences 只放登录态与少量标记，规避全量加载"],
       ["端侧推理", "MindSpore Lite Kit（@kit.MindSporeLiteKit）", "OpenHarmony 侧唯一可用的端侧推理框架；官方 quick_start 模型 mobilenetv2.ms 开箱即用"],
       ["图片能力", "PhotoViewPicker + ImageKit（@kit.MediaLibraryKit）", "免相册全量权限选图；解码限长边控制内存"],
       ["图表", "ArkUI Canvas 自绘", "无第三方依赖，可随画质档位降级"],
       ["时间口径", "自封装 AppClock", "统一“今天”判定，种子演示数据日期不漂移"]],
      widths=[2.4, 5.4, 7.8], size=10)
heading(doc, "5.3  关键选型对比与决策", 2)
para(doc, "**存储方案对比**（本作选择 RDB 关系库承载业务数据，Preferences 仅保留轻量键值）：")
table(doc,
      ["维度", "relationalStore RDB（选用）", "Preferences 全量 JSON", "JSON 文件"],
      [["实现复杂度", "中，需表设计/索引/聚合调优", "低，读写简单", "低"],
       ["读取性能", "按需查询 + 索引 + 分页，与总量脱钩", "整文件解析进内存，随数据量线性劣化", "每次全量解析"],
       ["数据规模", "数千至数万条可支撑", "千条级以内体验良好", "随规模线性劣化"],
       ["一致性", "事务保证（兑换/恢复/清空单事务）", "best-effort，启动自愈", "无事务"],
       ["内存占用", "拿多少读多少", "全量常驻 + 解析临时对象", "全量常驻"]],
      widths=[2.6, 4.6, 4.4, 3.0], size=10)
para(doc, "**识别方案对比**（本作选择端侧模型推理，演示词库作为退路）：")
table(doc,
      ["维度", "MindSpore Lite 端侧模型（选用）", "关键词演示词库（退路）"],
      [["识别能力", "真实推理，覆盖 ImageNet 1000 类中可映射的低碳场景", "文件名关键词匹配，仅演示用途"],
       ["离线与隐私", "完全本地推理，数据不出设备", "本地匹配"],
       ["依赖", "设备需支持 MindSporeLite 系统能力 + 13.3MB 模型文件", "无额外依赖"],
       ["降级关系", "能力缺失时自动降级为词库演示并提示真实原因", "始终可用的保底链路"]],
      widths=[2.8, 6.8, 5.0], size=10)

# ---------- 6 测试结果 ----------
heading(doc, "6  测试结果", 1)
heading(doc, "6.1  测试环境", 2)
table(doc,
      ["项", "配置"],
      [["开发环境", "DevEco Studio，OpenHarmony SDK API 24，hvigor 构建"],
       ["运行环境", "OpenHarmony 模拟器（API 24）；真机/开发板复测项见表 6 标注"],
       ["工程配置", "compileSdk / compatibleSdk / targetSdk = 24，runtimeOS = OpenHarmony，签名类型 OpenHarmony"],
       ["包体", "HAP 约 16.4 MB（2026-10-19 构建产物，含 13.3 MB 端侧模型 mobilenetv2.ms）"]],
      widths=[3.2, 11.4])
heading(doc, "6.2  构建与兼容性验证", 2)
table(doc,
      ["验证项", "方法", "结果"],
      [["工程构建", "hvigor 全量构建", "BUILD SUCCESSFUL，无阻塞性错误"],
       ["SDK 兼容", "核对 build-profile.json5", "compile/compatible/targetSdk 均为 24，runtimeOS 为 OpenHarmony"],
       ["包体与签名", "检查 HAP 产物", "签名类型 OpenHarmony，HAP 约 16.4 MB，模型文件完整（13,988,384 字节）"],
       ["代码规范", "strictMode 大小写敏感与 OHM URL 归一化检查", "通过"]],
      widths=[3.2, 5.4, 6.0], size=10)
heading(doc, "6.3  功能测试", 2)
table(doc,
      ["编号", "模块", "测试用例", "结果"],
      [["F01", "因子库", "首启加载 27 项因子，字段完整", "通过"],
       ["F02", "碳核算", "骑行 5 km × 0.19 kg/km = 0.95 kg，积分 95 分", "通过"],
       ["F03", "积分口径", "3000 积分兑换 1 棵树，商城标价与折算一致", "通过（回归）"],
       ["F04", "任务激励", "任务领取后落库，刷新页面状态保持", "通过"],
       ["F05", "商城兑换", "余额不足拦截；兑换后余额与权益记录一致", "通过"],
       ["F06", "AI 识别（降级）", "模拟器无 MindSporeLite 系统能力时提示真实原因并引导手动录入", "通过（符合预期）"],
       ["F07", "AI 识别（真机）", "支持系统能力的真机上完成识别入账", "待真机复测"],
       ["F08", "备份恢复", "备份后清空再恢复，记录与券往返一致", "通过"],
       ["F09", "深色模式", "全局深浅色切换，对比度走查清单逐项过检", "通过"],
       ["F10", "演示数据", "首启 30 天演示数据；清空/恢复演示不影响真实记录", "通过"]],
      widths=[1.4, 2.8, 8.0, 2.4], size=10)
heading(doc, "6.4  UI 与兼容性测试", 2)
bullets(doc, [
    "深浅色模式：全页面走查，文本与背景对比度达标，系统栏颜色随主题适配。",
    "页面转场：Navigation 路由转场一致，无跳转丢失栈。",
    "空态与引导：空列表、无记录、无网络无关场景均有明确空态提示。",
    "长列表：记录列表 LazyForEach 滚动流畅，无明显掉帧（以主观走查 + 帧率观察判定）。",
])
heading(doc, "6.5  性能测试", 2)
para(doc, "性能指标与目标值如下，运行时实测数据按附录 C 记录表在目标设备上填写（真机数据以实测为准）。")
table(doc,
      ["指标", "目标值", "测试方法", "结论"],
      [["冷启动时长", "< 1.5 s", "启动到首屏可交互计时", "待真机实测"],
       ["首屏可交互时间", "< 1 s", "RDB 按需查询，不解析全量数据", "架构上满足，待实测确认"],
       ["长列表滚动", "无明显掉帧", "记录列表快速滚动观察帧率", "走查通过"],
       ["init() 建库与首查", "< 300 ms", "冷启动打开 RDB + 首页首查计时", "待实测"],
       ["AI 单次推理耗时", "真机上秒级完成", "选图到出结果计时", "待真机复测"],
       ["HAP 包体积", "< 20 MB", "构建产物统计", "实测约 16.4 MB，达标"]],
      widths=[3.4, 3.4, 5.0, 3.0], size=10)
heading(doc, "6.6  稳定性与异常测试", 2)
table(doc,
      ["场景", "注入方式", "预期与结果"],
      [["写入失败", "模拟 RDB 插入异常", "录入提示保存失败，不出现“假成功”；重启后数据一致，符合预期"],
       ["备份恢复往返", "备份 → 清空 → 恢复", "记录与券数据一致（单事务恢复），新旧备份格式均可判别恢复，符合预期"],
       ["模型缺失", "移除 rawfile 模型", "提示真实原因并降级为手动录入，不假装可用，符合预期"],
       ["演示数据边界", "注册账号后检查首启数据", "零起步，种子版本标记不误清真实记录，符合预期"],
       ["旧版本数据迁移", "Preferences 存量数据首启", "一次性迁移进 RDB 后删除旧键，条数与合计口径一致，符合预期"],
       ["规模压力", "构造数千条记录量", "分页读取与 SQL 聚合保持可用，首屏不随总量劣化，符合预期"]],
      widths=[3.0, 4.2, 7.4], size=10)
heading(doc, "6.7  已知问题与改进计划", 2)
numlist(doc, [
    "AI 识别真机推理待复测：不同设备对 MindSpore Lite 系统能力支持度不同，需在目标真机完成一轮验证。",
    "性能数据待实测：冷启动、首查、推理耗时等运行时指标需在目标设备上按附录 C 记录表填写。",
    "推理线程模型：当前推理在页面线程执行，后续下沉 Worker 线程并支持切后台取消，进一步保障交互流畅。",
    "可识别场景扩展：ImageNet 通用类别可映射的低碳场景有限，后续按需扩充因子映射表。",
])

# ---------- 7 总结与展望 ----------
heading(doc, "7  总结与展望", 1)
para(doc, "本作品以 OpenHarmony + ArkTS/ArkUI 为技术底座，完成了“记录—核算—激励—回顾”的碳普惠闭环："
          "27 项因子的本地核算引擎、端侧 AI 拍照识别、液态玻璃视觉体系、本地优先的数据架构与备份恢复机制，"
          "全部能力在单设备本地闭环，零服务端依赖。测试表明核心功能链路、口径一致性与异常降级均符合设计预期。")
para(doc, "后续演进方向：其一，按规模警戒线将存储升级至关系型数据库并完成事务化兑换；其二，将 AI 推理下沉"
          "Worker 线程并扩展可识别的低碳场景；其三，持续扩充因子库与激励玩法，探索与系统级碳普惠能力的衔接。")

pagebreak(doc)
# ---------- 附录 ----------
heading(doc, "附录 A  核心代码片段", 1)
para(doc, "A.1  积分核算口径（Biz.pointsOf，1 kgCO₂e = 10 积分）：")
code(doc, """static pointsOf(kg: number): number {
  if (kg <= 0) return 0;
  const p: number = Math.round(kg * Biz.POINTS_PER_KG);   // POINTS_PER_KG = 10
  return p < 1 ? 1 : p;
}""")
para(doc, "A.2  植树折算（3000 积分兑 1 棵树，向下取整）：")
code(doc, """// 抵扣的树数量（向下取整）
static treesOf(exchangedPoints: number): number {
  return Math.floor(exchangedPoints / Biz.POINTS_PER_TREE);  // POINTS_PER_TREE = 3000
}""")
para(doc, "A.3  记录入账时序（核算 → 写入 RDB → 广播；失败即上报）：")
code(doc, """addRecord(item: FactorItem, amount: number, remark?: string): LocalRecord {
  const reduceKg = round2(item.factorValue * amount);      // 端侧核算
  const points = Biz.pointsOf(reduceKg);                   // 口径唯一出口
  const record: LocalRecord = { /* ...组装记录... */ };
  await CarbonRdb.insertRecord(userKey, record);           // ① 单行 INSERT 落 RDB
  EcoMoodState.bump();                                     // ② 成功后广播（失败已抛错）
  return record;
}""")
para(doc, "A.4  AI 预处理要点（与 ImageNet 训练预处理一致）：")
code(doc, """// uri → PixelMap：解码限长边 640 → 放大覆盖 224 → 居中裁剪 224
// 像素 → Float32Array：RGBA 逐通道归一化
//   (x/255 - mean) / std，mean=[0.485,0.456,0.406] std=[0.229,0.224,0.225]
// MindSpore Lite：loadModelFromBuffer → getInputs → setData → predict → softmax 聚合""")

heading(doc, "附录 B  配图 Mermaid 源码", 1)
para(doc, "B.1  总体架构图（图 4）：")
code(doc, """flowchart TB
    subgraph L1["表现层 · ArkUI 声明式页面"]
        A1["首页 Dashboard / 行为录入 / 记录与权益 / 图表与文章"]
    end
    subgraph L2["交互与组件层 · 设计体系"]
        B1["液态玻璃 GlassSurface/GlassLight/GlassDialog"]
        B2["懒加载列表 LazyList / 主题深色 ThemeMode / 全局路由 Navigation"]
    end
    subgraph L3["数据层 · 单一数据源 LocalStore + CarbonRdb"]
        C1["按需查询 records（SQL 聚合/分页）"]
        C2["派生统计 stats 唯一出口"]
        C3["变更信号 ecoTick/couponTick/articleTick"]
        C4["账号隔离 user_key 列"]
    end
    subgraph L4["持久层与系统能力"]
        D1["RDB carbon.db：carbon_record/carbon_coupon/task_claim/article_interact/backup_slot"]
        D2["Preferences 轻量键值：登录态/种子标记/备份计数"]
        E1["系统时钟 AppClock / 相册选图 PhotoViewPicker"]
    end
    L1 --> L2 --> L3 --> L4""")
para(doc, "B.2  记录数据流图（图 2）：")
code(doc, """sequenceDiagram
    participant U as 用户
    participant P as 录入弹窗 BehaviorAddSheet
    participant S as LocalStore
    participant D as CarbonRdb（RDB/SQLite）
    participant V as 各业务页面
    U->>P: 选择因子、输入数量、确认
    P->>S: addRecord(...)
    S->>S: 端侧核算 reduceKg 与 points（口径唯一）
    S->>D: insertRecord 单行 INSERT（user_key 账号隔离）
    D-->>S: 写入成功
    S->>V: ecoTick 自增广播
    V->>S: 收到信号，重新拉取
    S->>D: stats 聚合查询（SUM/COUNT 下推）
    D-->>V: 派生统计返回""")
para(doc, "B.3  AI 识别链路图（图 3）：")
code(doc, """flowchart TB
    A["① 选图 PhotoViewPicker（免相册全量权限）"] --> B["② 预处理：限长边640 → 居中裁剪224 → 归一化"]
    B --> C["③ MindSpore Lite 推理 mobilenetv2.ms"]
    C --> D["④ softmax 聚合 → ImageNet 类别映射碳因子 → Top3 依据"]
    D --> E["⑤ 用户确认数量（低置信度引导手动录入）"]
    E --> F["⑥ 按统一口径入账，信号广播刷新页面"]
    C -.->|"模型缺失/无系统能力/解码失败"| G["降级为手动录入并提示真实原因"]""")

heading(doc, "附录 C  性能测试记录表", 1)
para(doc, "说明：运行时性能数据需在目标设备上实测填写，下表为记录模板。")
table(doc,
      ["指标", "目标值", "实测值", "测试环境", "测试人", "日期"],
      [["冷启动时长", "< 1.5 s", "", "", "", ""],
       ["首屏可交互时间", "< 1 s", "", "", "", ""],
       ["长列表滚动帧率", "无明显掉帧", "", "", "", ""],
       ["init() 建库与首查", "< 300 ms", "", "", "", ""],
       ["分页加载一页（50 条）", "< 50 ms", "", "", "", ""],
       ["AI 单次推理耗时", "秒级", "", "", "", ""],
       ["连续记录 100 次写入", "无卡顿、无丢数据", "", "", "", ""]],
      widths=[3.6, 2.6, 2.0, 2.6, 1.8, 1.8], size=10)

doc.save(OUT)
print("saved:", OUT)
