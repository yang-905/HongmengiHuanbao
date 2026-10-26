# -*- coding: utf-8 -*-
"""
生成《一触青绿 · OpenHarmony 单机版碳足迹应用 技术方案（双方案版）》.docx
格式要求：正文宋体、小四号（12pt）、1.5 倍行距；标题黑体；图表用 Mermaid 源码 + 文本/表格结构表达。
"""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   '一触青绿_OpenHarmony技术方案_双方案版.docx')

doc = Document()

# ---------------- Normal 样式（正文：宋体小四、1.5 倍行距） ----------------
normal = doc.styles['Normal']
normal.font.name = 'Times New Roman'
normal.font.size = Pt(12)
_n_rpr = normal.element.get_or_add_rPr()
_n_rf = _n_rpr.find(qn('w:rFonts'))
if _n_rf is None:
    _n_rf = OxmlElement('w:rFonts')
    _n_rpr.append(_n_rf)
_n_rf.set(qn('w:eastAsia'), '宋体')
_n_rf.set(qn('w:ascii'), 'Times New Roman')
_n_rf.set(qn('w:hAnsi'), 'Times New Roman')
normal.paragraph_format.line_spacing = 1.5

# ---------------- 页面设置（A4） ----------------
sec = doc.sections[0]
sec.page_width = Cm(21.0)
sec.page_height = Cm(29.7)
sec.top_margin = Cm(2.5)
sec.bottom_margin = Cm(2.5)
sec.left_margin = Cm(2.8)
sec.right_margin = Cm(2.8)

# ---------------- 基础工具 ----------------

def _set_run(run, east='宋体', ascii_f='Times New Roman', size=12, bold=False, color=None):
    run.font.name = ascii_f
    run.font.size = Pt(size)
    run.font.bold = bold
    if color is not None:
        run.font.color.rgb = RGBColor(*color)
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), east)
    rFonts.set(qn('w:ascii'), ascii_f)
    rFonts.set(qn('w:hAnsi'), ascii_f)


def _shade_para(p, fill='F4F6F4'):
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:fill'), fill)
    pPr.append(shd)


def _shade_cell(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:fill'), fill)
    tcPr.append(shd)


def para(text, size=12, bold=False, east='宋体', ascii_f='Times New Roman',
         align=None, indent=True, before=0, after=6, line=1.5, color=None):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = line
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    if align is not None:
        p.alignment = align
    if indent:
        pf.first_line_indent = Pt(size * 2)
    r = p.add_run(text)
    _set_run(r, east=east, ascii_f=ascii_f, size=size, bold=bold, color=color)
    return p


def bullet(text, size=12, level=1, after=3):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_after = Pt(after)
    pf.left_indent = Pt(18 * level)
    pf.first_line_indent = Pt(-12)
    mark = '· ' if level == 1 else '– '
    r = p.add_run(mark + text)
    _set_run(r, size=size)
    return p


def h1(text):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(18)
    pf.space_after = Pt(10)
    pf.keep_with_next = True
    r = p.add_run(text)
    _set_run(r, east='黑体', ascii_f='Arial', size=16, bold=True, color=(0x1F, 0x3D, 0x2B))
    return p


def h2(text):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(12)
    pf.space_after = Pt(6)
    pf.keep_with_next = True
    r = p.add_run(text)
    _set_run(r, east='黑体', ascii_f='Arial', size=14, bold=True, color=(0x1F, 0x3D, 0x2B))
    return p


def h3(text):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(8)
    pf.space_after = Pt(4)
    pf.keep_with_next = True
    r = p.add_run(text)
    _set_run(r, east='黑体', ascii_f='Arial', size=12, bold=True)
    return p


def caption(text):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.3
    pf.space_before = Pt(8)
    pf.space_after = Pt(4)
    pf.keep_with_next = True
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(text)
    _set_run(r, east='黑体', ascii_f='Arial', size=10.5, bold=True)
    return p


def code_block(text, size=9):
    lines = text.rstrip('\n').split('\n')
    for i, ln in enumerate(lines):
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.line_spacing = 1.15
        pf.space_before = Pt(6) if i == 0 else Pt(0)
        pf.space_after = Pt(6) if i == len(lines) - 1 else Pt(0)
        pf.left_indent = Pt(10)
        r = p.add_run(ln if ln.strip() else ' ')
        _set_run(r, east='宋体', ascii_f='Consolas', size=size)
        _shade_para(p)


def table(headers, rows, widths=None, size=10.5, header_fill='E4F0E9'):
    t = doc.add_table(rows=1, cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    hdr = t.rows[0].cells
    for i, htext in enumerate(headers):
        hdr[i].text = ''
        p = hdr[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.line_spacing = 1.2
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.space_before = Pt(2)
        r = p.add_run(htext)
        _set_run(r, east='黑体', ascii_f='Arial', size=size, bold=True)
        _shade_cell(hdr[i], header_fill)
    for row in rows:
        cells = t.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = ''
            p = cells[i].paragraphs[0]
            p.paragraph_format.line_spacing = 1.2
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.space_before = Pt(2)
            r = p.add_run(str(v))
            _set_run(r, size=size)
    if widths:
        for i, w in enumerate(widths):
            for row_ in t.rows:
                row_.cells[i].width = Cm(w)
    # 表后留白
    sp = doc.add_paragraph()
    sp.paragraph_format.line_spacing = 1.0
    sp.paragraph_format.space_after = Pt(4)
    r = sp.add_run('')
    _set_run(r, size=6)
    return t


def page_break():
    doc.add_page_break()


def add_page_number():
    footer = sec.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run()
    f1 = OxmlElement('w:fldChar'); f1.set(qn('w:fldCharType'), 'begin')
    it = OxmlElement('w:instrText'); it.set(qn('xml:space'), 'preserve'); it.text = 'PAGE'
    f2 = OxmlElement('w:fldChar'); f2.set(qn('w:fldCharType'), 'end')
    r._r.append(f1); r._r.append(it); r._r.append(f2)
    _set_run(r, size=9)


add_page_number()

# ==================== 封面 ====================
for _ in range(4):
    para('', indent=False, after=0)
para('一触青绿', size=26, bold=True, east='黑体', align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, after=6)
para('OpenHarmony 单机版碳足迹应用 · 技术方案', size=18, bold=True, east='黑体',
     align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, after=4)
para('（方案一「数据底座优先」 × 方案二「交互体验优先」）', size=14, east='黑体',
     align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, after=20)
para('一触之间，青绿相随', size=12, align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, after=30)

info_rows = [
    ['项目名称', '一触青绿（OpenHarmony 单机版碳足迹应用）'],
    ['文档类型', '技术方案 / 作品设计文档（详细版）'],
    ['技术底座', 'OpenHarmony + ArkTS + ArkUI（API 24，Navigation 全局路由）'],
    ['运行范围', '单设备本地运行；不涉及联网、云服务、账号同步、多端协同与分布式能力'],
    ['文档版本', 'v1.0'],
    ['编制日期', '2026 年 10 月 23 日'],
]
t = doc.add_table(rows=0, cols=2)
t.style = 'Table Grid'
t.alignment = WD_TABLE_ALIGNMENT.CENTER
for k, v in info_rows:
    cells = t.add_row().cells
    cells[0].text = ''
    p = cells[0].paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(k)
    _set_run(r, east='黑体', ascii_f='Arial', size=11, bold=True)
    _shade_cell(cells[0], 'E4F0E9')
    cells[1].text = ''
    p = cells[1].paragraphs[0]
    r = p.add_run(v)
    _set_run(r, size=11)
    cells[0].width = Cm(3.4)
    cells[1].width = Cm(11.6)

page_break()

# ==================== 目录 ====================
para('目  录', size=16, bold=True, east='黑体', align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, after=14)
toc_items = [
    '1  项目概述（含 ArkTS / ArkUI 术语备注）',
    '2  方案一：数据底座优先（本地存储加密 · 碳行为记录 · 积分账本）',
    '3  方案二：交互体验优先（液态玻璃 · 碳情绪 · 商店兑换与核销）',
    '4  两套方案对比与推荐建议',
    '5  软硬件选型',
    '6  测试结果（开发自测与问题修复记录）',
    '7  附录（口径速查 / 关键文件职责 / 图索引）',
]
for it_ in toc_items:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_after = Pt(6)
    r = p.add_run(it_)
    _set_run(r, size=12)

page_break()

# ==================== 1 项目概述 ====================
h1('1  项目概述')

h2('1.1  项目简介')
para('一触青绿是一款基于 OpenHarmony 的个人碳足迹记录与碳积分激励应用。用户把日常低碳行为'
     '（绿色出行、低碳饮食、垃圾分类与回收等）记录下来，应用按排放因子把行为数量换算为减排量'
     '（kgCO₂e），再按口径折算为碳积分；积分可在本地积分商城兑换权益券、认养植树并获得证书与徽章，'
     '形成「记录—换算—激励—兑换—核销」的完整本地闭环。')
para('本版本为单机版：全部数据与计算都在设备本地完成，不依赖任何服务端。')

h2('1.2  目标设备形态')
bullet('主形态：手机（工程 deviceTypes 声明 default），兼顾平板（tablet），同一套声明式布局自适应，无单独平板工程。')
bullet('显示：深浅色双模式，默认跟随系统，设置页可手动锁定；系统栏图标色随主题反色下发。')
bullet('外设：无额外硬件依赖；相机为设备内置能力的调用（AI 拍照识别取图），仅本地推理，不上传任何图像。')

h2('1.3  核心功能与当前进度')
para('核心链路已全部实现并通过开发自测，工程处于「功能完备、体验打磨」阶段。核心数据与 UI 层'
     '代码约 1.9 万行 ArkTS，业务页面 30 余个。各模块现状见表 1-1。')
caption('表 1-1  核心功能模块与当前进度')
table(
    ['模块', '功能点', '当前状态'],
    [
        ['碳行为记录', '27 项行为因子；手动录入；AI 拍照识别（端侧 MindSpore Lite 推理）；因子库浏览', '已实现'],
        ['碳足迹看板', '今日/累计/月度减排、连续天数、等级；趋势图、分类分析、月账单', '已实现'],
        ['碳情绪主题', '按当日碳排放动态切换全局配色（none / warn / good / eco 四档）', '已实现'],
        ['碳积分体系', '积分记录、每日任务、积分商城、碳惠券包（7 天有效期）、核销凭证、植树证书、徽章墙', '已实现'],
        ['本地账号与数据', '本地注册/登录、多身份数据隔离、备份管理、报告导出', '已实现'],
        ['视觉与动效体系', '液态玻璃组件（135° 单一光源模型）、苹果式动效阶梯、深色模式', '已实现，持续打磨'],
    ],
    widths=[3.4, 8.2, 3.4],
)
para('已知短板与下一阶段重点：大规模记录（千级）下的存储与列表性能、口令防护强度（当前为演示级'
     '混淆哈希）、自动化测试覆盖。相关取舍见第 2、3 章「风险与取舍」，测试情况见第 6 章。')

h2('1.4  术语备注：ArkTS 与 ArkUI 是什么')
bullet('ArkTS（方舟脚本语言）：OpenHarmony 的主力应用开发语言，基于 TypeScript 演进并针对 Ark 运行时'
       '做了约束扩展——用 @Component、@State、@Builder 等装饰器描述界面与状态，默认严格模式'
       '（静态类型约束更严，错误在编译期暴露）。本工程全部业务代码均为 ArkTS（*.ets 文件）。')
bullet('ArkUI（方舟 UI 框架）：OpenHarmony 的声明式应用 UI 开发框架。本项目使用其 ArkTS 声明式范式：'
       '以 @Component 自定义组件、@Builder 复用布局、@StorageLink / @StorageProp 订阅应用级状态，'
       '由框架根据状态变化驱动渲染，避免命令式地逐个操作界面节点。')
bullet('二者关系：ArkUI 定义「如何描述 UI」，ArkTS 是书写这套描述以及全部业务逻辑的语言；'
       '路由层使用 Navigation（NavPathStack 单例）实现全局页面栈管理。')

page_break()

# ==================== 2 方案一 ====================
h1('2  方案一：数据底座优先')
para('核心模块：本地数据存储与数据文件加密 · 碳行为记录与因子引擎 · 本地积分账本。', bold=True, indent=False)

h2('2.1  背景与目标')
para('背景：单机版没有服务端兜底，碳账本、积分与证书的可信度完全取决于本地数据的正确性与可恢复性。'
     '开发过程中真实发生过三类问题，全部指向数据层：录入后页面不同步（广播机制误用）、任务领取'
     '不落库（刷新即回弹）、备份恢复出现「未来日期」（时间口径漂移）。这些问题让团队形成明确判断：'
     '体验层可以迭代，数据层必须先立规矩。')
para('目标：')
bullet('唯一数据源、统一口径：所有读写经 LocalStore 一个出口，派生统计（stats）一处计算、全库复用，杜绝各页面口径漂移；')
bullet('数据文件加密与可恢复：敏感数据与备份文件加密托管，键名分区防串档，误删可恢复；')
bullet('积分账本可审计：每一分积分有来路、有去向，兑换操作重复执行不出错；')
bullet('迁移自愈：版本升级不清库，时间口径切换不产生脏数据。')
para('定位说明：本方案属地基工程——页面改动小、数据层改动深，排在体验打磨之前。务实边界：'
     '不追求商用密码学完备性，追求「防误删、防串档、防肉眼翻库、可恢复」。')

h2('2.2  核心重点')

h3('模块一：本地数据存储与数据文件加密')
bullet('现状：单 Preferences 文件 yichu_qinglv + 内存权威态 + best-effort 落盘；多身份命名空间'
       '（如 local_records@<user>）实现本地数据隔离，键名按「业务键 / 账号键 / 券键」分区。')
bullet('增强点 1——密钥托管：经 HUKS（通用密钥库系统）生成与保管 AES-256 密钥，密钥本身不以明文'
       '落入应用存储；支持硬件密钥库的设备由硬件保护。')
bullet('增强点 2——备份文件加密：导出的备份文件采用 AES-256-GCM 加密（密文 + 认证标签，可防篡改），'
       '恢复导入时先校验，校验失败即拒绝导入，绝不「半解密」写入。')
bullet('增强点 3——密钥分层：公开配置（主题、信号类键）保持明文；高敏内容（账号口令哈希、备份槽、'
       '积分流水）加密或携带校验和。')
bullet('边界说明：口令哈希当前为「盐 + FNV/xorshift 混淆」，代码注释明确标注为演示级（防肉眼翻库，'
       '非密码学保证）；如需升级，OpenHarmony crypto 框架提供 PBKDF2 等标准密钥派生函数，列为后续项。')

h3('模块二：碳行为记录与因子引擎')
bullet('因子库：27 项行为因子（code / category / itemName / unit / factorValue / benchmarkFactor / '
       'calcFormula / factorSource），换算口径为「排放量 = 数量 × 单位排放因子（kgCO₂e）」。')
bullet('记录模型：LocalRecord 携带 clientRecordId（端侧 UUID，幂等键）、itemId、amount、behaviorTime'
       '（系统时钟口径，见 AppClock）、recordSource（manual / ai）、remark。')
bullet('统计收敛：totalKg / todayKg / monthKg / continuousDays / level / treeCount / taskPoints 全部由 '
       'LocalStore.stats() 派生，页面不各自计算，从机制上杜绝口径漂移。')
bullet('AI 识别链路：MindSpore Lite 端侧 mobilenetv2 推理 → ImageNet 类别概率聚合 → 映射到因子 code → '
       '产出与手动录入同构的记录（recordSource = ai）；Top3 类别与概率作为「识别依据」随记录留存，'
       '可解释、可复查。')

h3('模块三：本地积分账本（可审计）')
bullet('口径：1 kgCO₂e = 10 积分；3000 积分 = 1 棵树；等级按累计减排量分五档（碳芽 → 新芽 → 绿芽 → '
       '低碳达人 → 森林卫士）。')
bullet('账本模型：积分流水区分收入（记录折算、任务领取）与支出（兑换扣减）；availablePoints = '
       'totalPoints − exchangedPoints；认养植树的消耗单独记账（treeExchangedPoints），证书列表由它派生，'
       '避免「兑换公交券顺带冒出证书」的口径污染。')
bullet('事务性：兑换 = 校验余额 → 扣减 → 写流水 → 发券，四步视为一个事务，任一步失败整体回退；'
       'clientRecordId 幂等去重，重复提交不重复入账。')

h2('2.3  架构与图示')

caption('图 2-1  方案一总体架构图（分层视图，全部本地调用）')
code_block('''flowchart TB
    subgraph UI["呈现层 · ArkUI 页面（30+）"]
        direction LR
        U1["首页看板 / 记录列表"]
        U2["行为录入 / AI 拍照识别"]
        U3["积分商城 / 券包 / 核销凭证"]
    end
    subgraph BIZ["业务编排层 · 本地模块"]
        B1["记录引擎：27 因子换算"]
        B2["积分账本：流水 / 兑换事务"]
        B3["统计看板：stats 派生"]
        B4["账号与备份：命名空间隔离"]
    end
    subgraph DATA["数据层 · LocalStore 唯一数据源"]
        D1["内存权威态 + 同步落盘"]
        D2["Preferences 单文件 yichu_qinglv"]
        D3["加密备份文件 AES-256-GCM"]
    end
    subgraph SYS["系统能力 · 本地 Kit（全部本地调用）"]
        S1["ArkData / CoreFileKit"]
        S2["MediaLibraryKit 相机相册"]
        S3["MindSporeLiteKit 端侧推理"]
        S4["HUKS 密钥托管"]
    end
    UI --> BIZ
    BIZ --> DATA
    DATA --> SYS''')
para('结构解读：呈现层只消费业务层出口，不直接碰存储；数据层是唯一数据源，向下调用系统能力完成'
     '落盘、取图、推理与密钥托管。四层之间自上而下单向依赖，测试时可逐层替换。', indent=True)

caption('图 2-2  方案一核心数据流转图（记录 → 积分 → 兑换 → 核销 → 备份）')
code_block('''flowchart LR
    A1["手动录入"] --> C["因子换算：排放量 = 数量 × 因子值"]
    A2["AI 拍照识别（端侧推理）"] --> C
    C --> R["记录落库：clientRecordId 幂等"]
    R --> T["broadcastDataChange：ecoTick +1"]
    T --> S["stats 重算：日/月/连续/等级"]
    S --> M["碳情绪判档：ecoLevel"]
    S --> P["积分入账：1 kgCO2e = 10 积分"]
    P --> X{"发起兑换？"}
    X -->|是| E["扣减 + 流水 + 发券（TTL 7 天）"]
    E --> V["核销：二维码 + usedAt"]
    V --> F["核销凭证页"]
    X -->|否| K["备份导出 / 恢复（加密 + 校验）"]''')
para('流转说明：一次录入沿「换算 → 落库 → 广播 → 重算」单向推进，重算结果同时驱动三件事——'
     '碳情绪档位、积分入账、看板统计，保证同一笔数据在全应用只有一种解释。', indent=True)

caption('图 2-3  方案一关键页面布局示意（行为录入面板）')
code_block('''+--------------------------------------+
| 记一笔                            x  |
+--------------------------------------+
| [饮食] [出行] [居住] [购物] [回收]      |  <- 分类切换
+--------------------------------------+
| +----------+  +----------+            |
| | 因子卡 1  |  | 因子卡 2  |  ...       |  <- 27 因子网格
| +----------+  +----------+            |
+--------------------------------------+
| 数量   [ - ]   1.5   [ + ]   单位 kg    |
| 预计减排 4.25 kgCO2e  =  42 积分        |
| 时间   [ 今天 12:30             v ]    |
| 备注   [ _______________________ ]    |
+--------------------------------------+
| [             保存记录              ]  |
+--------------------------------------+''')
caption('表 2-1  录入面板区域划分')
table(
    ['区域', '内容', '数据来源'],
    [
        ['分类栏', '五类行为切换（饮食/出行/居住/购物/回收）', 'MockStore 因子分类'],
        ['因子网格', '可滑动的因子卡（名称 + 单位 + 因子值）', '27 项 LocalFactor'],
        ['数量步进', '步进器与快捷数量，实时换算预览', '用户输入 + Biz.pointsOf(kg)'],
        ['时间与备注', '默认今天（系统时钟口径），备注选填', 'AppClock'],
        ['保存按钮', '写入记录 → bump 广播 → 全库刷新', 'LocalStore.add + broadcastDataChange'],
    ],
    widths=[2.8, 7.6, 4.6],
)

h2('2.4  关键实现思路')
bullet('内存权威态 + 同步落盘：读取同步返回（页面 aboutToAppear 中 await 一次即可渲染，无 loading '
       '转圈）；写入先改内存再同步落盘，落盘失败仅退化为「本次运行有效」并记录日志，不阻塞主流程'
       '（预览器不提供 Preferences 的退化路径即依赖此设计）。')
bullet('响应式广播：写入方调用 broadcastDataChange() 使 AppStorage 的 ecoTick 自增，各页面以 '
       '@StorageLink 订阅、用 @Watch 接到重载函数。关键教训：onStorageChange 并非 ArkUI 生命周期回调'
       '（SDK 中并不存在），必须用 @Watch 把「响应式变量变化」桥接到已有处理逻辑。')
bullet('防递归与防吞送：碳情绪 apply() 只写 ecoLevel 档位、不再 bump 信号（曾因 apply → bump → '
       'onStorageChange → refresh 形成无限递归，导致同屏出现两个档位）；AppStorage 写入统一 '
       'setOrCreate（set 对缺失键静默无效，曾吞掉首次广播，表现为「录入后列表不动」）。')
bullet('数据迁移自愈：SEED_VER 版本标记只升不降，init 时按版本执行清洗或时间平移（v2 → v3 切换为'
       '系统时钟口径），升级不清用户真实数据。')
bullet('幂等键设计：clientRecordId 由端侧生成，「重试 / 双重点击 / 中断恢复」场景下重复提交不产生'
       '重复记录与重复积分。')
bullet('统计与账本集中：stats() 与积分流水同源派生，看板、图表、月账单、商城余额四处读同一出口。')

h2('2.5  风险与取舍')
caption('表 2-2  方案一风险清单与对策')
table(
    ['风险', '影响', '取舍与对策'],
    [
        ['Preferences 非关系型存储，记录量上千后全量 JSON 读写变慢',
         '读取与保存耗时上升',
         '当前演示量级（百级）可接受；预留升级路线（关系型数据库 RDB：记录表按 behaviorTime 建索引、分页查询），不做提前优化'],
        ['密钥随应用卸载 / 恢复出厂丢失（HUKS 密钥不可导出）',
         '加密备份无法恢复',
         '提供「加密备份 + 明文导出报告」双通道，首次使用时向用户明示边界；密钥不可导出是安全设计而非缺陷'],
        ['口令防护为演示级（盐 + FNV/xorshift 混淆）',
         '不能抵抗针对性攻击',
         '注释明示演示级，不冒充安全；升级 PBKDF2 列入后续项，排序低于体验打磨'],
        ['每次写入全量序列化',
         '连续录入时重复序列化',
         '批量写入合并（录入面板连续记录合并为一次落盘），并监控键体积'],
        ['多身份命名空间带来复杂度',
         '切换身份漏切命名空间会串数据',
         '键名分区规范 + 切换时校验 + 注销时重置碳情绪状态（曾出现「切换账号后情绪色不归位」）'],
        ['加密引入额外失败面（密钥获取失败、GCM 校验失败）',
         '备份 / 恢复流程报错',
         '失败即拒绝导入并提示，绝不「半解密」写入'],
    ],
    widths=[4.6, 3.2, 7.2],
)

h2('2.6  落地步骤')
caption('表 2-3  方案一实施计划（预估工作量，可按人力并行调整）')
table(
    ['阶段', '内容', '交付物', '验收标准', '预估（人日）'],
    [
        ['S1 数据层审计与口径统一', '全量存储键梳理成清单，stats 收敛为唯一派生出口', '存储键清单 v1.0、口径文档', '键清单覆盖率 100%；看板/图表/月账单/商城四处对账一致', '3~4'],
        ['S2 加密与备份加固', 'HUKS 密钥托管；备份文件 AES-256-GCM；导出报告脱敏', '加密备份模块 + 恢复用例', '加密备份可正常恢复；明文报告不含敏感字段', '5~7'],
        ['S3 积分账本与幂等', '积分流水；兑换四步事务；幂等与回滚测试', '账本模块 + 测试用例', '重复提交 / 中断恢复后余额与流水一致', '4~6'],
        ['S4 记录引擎与批量写入', '27 因子校核；批量落盘合并；AI 识别结果入账同构校验', '记录引擎 v2', '因子抽查 27/27 正确；AI 记录可解释、可复查', '3~5'],
        ['S5 迁移与回归', 'v2→v3 时间迁移；清空/恢复；身份切换用例回归', '回归报告', '用例全部通过，无数据误清', '2~3'],
    ],
    widths=[3.0, 4.4, 2.8, 3.4, 1.4],
)

page_break()

# ==================== 3 方案二 ====================
h1('3  方案二：交互体验优先')
para('核心模块：液态玻璃视觉体系 · 碳情绪动态主题 · 商店积分兑换与核销闭环。', bold=True, indent=False)

h2('3.1  背景与目标')
para('背景：碳普惠类应用功能同质化严重，单机版缺少外部数据加持，差异化与留存只能依靠体验——'
     '视觉一致性、反馈即时性、情绪化表达。本工程功能建设已基本完成，进入体验收口阶段：组件体系'
     '已落地，但历史页面仍存在硬编码色值与时长、深色走查不完整、动效参数不统一等欠账。')
para('目标：')
bullet('全库统一的液态玻璃视觉语言：光照、材质、圆角一处定义、全局复用，页面不再各自「画高光」；')
bullet('碳情绪驱动的动态主题：让减排成果「看得见」——记一笔，全应用换色；')
bullet('兑换—核销闭环的仪式感与可信度：从商城到凭证页，每一步都有明确反馈；')
bullet('守住性能红线：动效不掉帧、深浅色都可读、低端机有降级档。')

h2('3.2  核心重点')

h3('模块一：液态玻璃视觉体系')
bullet('GlassLight（光照模型）：135° 单一光源模型（全库唯一光照方向），统一提供对角光染（wash）、'
       '边缘反射（fresnel）、接触纱（scrim）三类配色函数；画质分三档（HIGH / BALANCED / LITE），'
       'LITE 档整栈不渲染，作为低端机降级路径。')
bullet('GlassSurface（组件出口）：GlassPanel / GlassPill 两个出口，内部固定五层光照栈——接触纱 → '
       '对角光染 + 内阴影 → 顶边菲涅尔 → 左边菲涅尔 → 内容永远在最上；外加 1px 四边异色描边'
       '（上/左受光白、下/右背光深）与右下外投影；backdropBlur 仅用于小面积元素，card 档永不模糊。')
bullet('组件纪律：页面禁止自行叠加渐变「画高光」，禁止硬编码色值与动画时长——全部取自 Theme.ets、'
       'GlassLight.ets、AppleMotion.ets 三个唯一定义处。')
bullet('可读性优先：内容层永远压在光照之上；深色模式增加文字暗纱托住对比度（曾实测深色副标题'
       '对比度 1.00:1 完全隐形，提亮并微调色相后回到 3.9:1）。')

h3('模块二：碳情绪动态主题（EcoMoodState）')
bullet('数据源：当日碳排放 todayKg 与日预算 5 kgCO₂e 比较，判出四档——none（<1kg，静默灰）、'
       'warn（<3kg）、good（<5kg）、eco（≥5kg，荧光绿，目标达成）。红色告警档已退役，灰色为最低值。')
bullet('机制：全局单例 + AppStorage 响应式。apply() 写入 ecoLevel 档位，30 余个页面以 '
       '@StorageLink 订阅，档位一变全库自动重渲染并完成颜色过渡。')
bullet('为什么是全局单例：若每个页面各自判档，既每页多一次存储读，又可能出现「上一页绿、下一页黄」'
       '的跳变；单例 + 广播保证同一时刻全库同一档位。')
bullet('调试手段：设置页隐藏调试面板可强制档位，无需造数据即可批量验证「深浅色 × 四档」的适配情况。')

h3('模块三：商店积分兑换与核销闭环')
bullet('链路：积分商城浏览 → 兑换（余额校验 → 扣减 → 写流水 → 发券）→ 碳惠券包（领取后 7×24 小时'
       '有效，按领取时间起算，不处理跨日边界）→ 核销（生成核销二维码，usedAt 与二维码内容持久化）→ '
       '核销凭证页（票根卡 + 感谢仪式 + 核销时间大字展示）。')
bullet('幂等：已核销的券从列表回看仍进入凭证页（usedAt / qrContent 持久化），重复进入不重复核销。')
bullet('证书派生：认养植树的消耗单独记账，按 3000 积分/棵推导证书列表；兑换其他权益不产生证书。')
bullet('荣誉体系：五级等级 + 徽章墙 + 连续天数，为「记录」行为提供即时正反馈。')

h2('3.3  架构与图示')

caption('图 3-1  方案二总体架构图（页面 / 设计体系 / 状态 / 业务四层）')
code_block('''flowchart TB
    subgraph PAGES["页面层 · 30+ 业务页面"]
        PG["看板 / 记录 / 商城 / 我的"]
    end
    subgraph DESIGN["设计体系 · 唯一定义处"]
        TH["Theme.ets：色板/圆角/间距 + 深色换血"]
        GL["GlassLight.ets：135 度光源 + 画质三档"]
        GS["GlassSurface.ets：玻璃面板/胶囊 五层栈"]
        AM["AppleMotion.ets：动效阶梯 + 弹簧预设"]
    end
    subgraph STATE["状态层 · AppStorage 响应式"]
        EL["ecoLevel 碳情绪档位"]
        TT["themeTick 明暗重建"]
        EK["ecoTick 数据变更"]
        CT["couponTick / profileTick"]
    end
    subgraph BIZ["业务层"]
        LS["LocalStore / 商城 / 券包 / 核销"]
    end
    PAGES -->|"取色/取光照/取动效"| DESIGN
    PAGES -->|"订阅"| STATE
    STATE -->|"读写"| BIZ''')
para('结构解读：设计体系被页面单向消费（页面取色、取光照、取动效，不反向修改）；状态层是页面与'
     '业务层之间的唯一通道，业务数据变化经信号广播驱动页面重建。', indent=True)

caption('图 3-2  方案二核心业务流程图（碳情绪流 + 兑换核销流）')
code_block('''flowchart TB
    subgraph MOOD["碳情绪流"]
        R1["记录写入"] --> S1["stats 重算 todayKg"]
        S1 --> J1{"todayKg 与预算 5kg 比较"}
        J1 --> L1["判四档：none / warn / good / eco"]
        L1 --> B1["ecoLevel 广播"]
        B1 --> U1["30+ 页自动换色（深浅色适配）"]
    end
    subgraph SHOP["兑换核销流"]
        M1["积分商城浏览"] --> M2{"余额校验"}
        M2 -->|"不足"| M3["提示去记录 / 做任务"]
        M2 -->|"通过"| M4["扣减 + 流水 + 发券"]
        M4 --> M5["碳惠券包（TTL 7 天）"]
        M5 --> M6["核销：二维码 + usedAt"]
        M6 --> M7["核销凭证页：票根卡 + 感谢仪式"]
    end''')
para('流程说明：两条流共用同一数据出口（LocalStore.stats 与积分流水）。碳情绪流解决「反馈即时」，'
     '兑换核销流解决「激励可信」，后者的事务正确性依赖方案一的账本设计。', indent=True)

caption('图 3-3  方案二关键页面布局示意（首页看板）')
code_block('''+--------------------------------------+
| 一触青绿             碳芽        设置  |
+--------------------------------------+
| +----------------------------------+ |
| |   今日碳排  2.1 kgCO2e            | |  <- 液态玻璃 Hero
| |   日预算 5kg   进度 42%            | |
| +----------------------------------+ |
|  [ + 记一笔 ]    [ 相机 AI 识别 ]     |
+--------------------------------------+
| 本周趋势（玻璃图表卡，随情绪档换色）    |
+--------------------------------------+
| +----------------+ +----------------+ |
| | 累计减排 86kg   | | 可用积分 860   | |
| +----------------+ +----------------+ |
+--------------------------------------+
|    首页       记录       商城      我的 |
+--------------------------------------+''')
caption('表 3-1  首页区域划分与交互要点')
table(
    ['区域', '内容', '视觉与交互要点'],
    [
        ['顶栏', '应用名 + 等级徽章 + 设置入口', '玻璃底，边缘受光描边'],
        ['Hero 卡', '今日碳排 + 预算环形进度', 'GlassPanel（CARD 档），135° 光照，永不模糊'],
        ['主操作', '记一笔 / AI 识别', '按压立刻缩至 96%，抬起弹簧回弹'],
        ['趋势卡', '近 7 日减排趋势', '图表系列色取自 Theme.Chart，随 ecoLevel 过渡'],
        ['指标格', '累计减排 / 可用积分', 'GlassPill；少量固定卡片做错峰淡入'],
        ['底部 Tabs', '四个主标签', '胶囊玻璃；子页面压上时淡出'],
    ],
    widths=[2.6, 6.0, 6.4],
)

h2('3.4  关键实现思路')
bullet('设计令牌集中：Theme.ets 定义全部色板、圆角、间距与图表色（全库约千处调用点取同一处）；'
       '深色模式采用「整组换血」——ThemePalette.applyDark 重写全部可变色值令牌，再由 themeTick '
       '广播驱动各页重建，调用点零改动。')
bullet('动效阶梯：AppleMotion 统一定义——按压 100ms（必须即时）、微交互 200ms、标准转场 350ms、'
       '大面板 500ms；「从无到有出现」的元素（弹窗、徽标）使用弹簧曲线完成 0.92 → 1.0 缩放进场；'
       '长列表内禁止逐项跑弹簧（一屏十几项同时跑会掉帧）。')
bullet('光照一致性：五层光照栈收敛为 GlassLightLayers 一个 Builder 供全局复用；玻璃的对角光染层'
       '跟随视差平移（仅合成层 transform，不触发布局重排）。')
bullet('性能预算：画质三档 + 深色按层数预算裁层（省一次离屏合成）；对挂了模糊的面板做缩放动画时'
       '幅度克制在 8% 以内；错峰入场仅限一屏内少量固定卡片。')
bullet('情绪流闭环：写入 → broadcastDataChange → stats 重算 → apply() 写档位 → 全库换色；启动时'
       '在 EntryAbility 预置初始档位，避免「先进灰、再跳绿」的闪烁。')
bullet('核销可信度：usedAt / qrContent 落库 + 幂等回看；核销码为本地生成凭证（二维码内容本地持久化），'
       '核销流程全部在本地完成——单机边界如实说明，不虚构任何「在线核销」效果。')

h2('3.5  风险与取舍')
caption('表 3-2  方案二风险清单与对策')
table(
    ['风险', '影响', '取舍与对策'],
    [
        ['每层玻璃 4~5 个合成层，中低端机掉帧',
         '滑动卡顿',
         '画质分档 + 裁层预算 + 模糊层禁大位移动画；不为炫技加层'],
        ['深色适配工作量大（30 余页逐页走查）',
         '工期不可控',
         '令牌集中 + 强制档位调试面板批量过检；接受部分图表系列色手动微调'],
        ['历史页面硬编码色值 / 时长，整改琐碎',
         '回归面大',
         '用扫描规则定位，按高频路径分批替换（首页 / 录入 / 弹窗优先），不强求一次清零'],
        ['情绪主题依赖业务数据（stats）',
         '存储未就绪时取不到档位',
         'init 预置初始档位 + try/catch 保默认档'],
        ['深色底放大浅色绿相（「饱和绿」问题）',
         '深色下发脏',
         '中性色相拉回冷灰，绿意只交给品牌色与碳情绪档'],
        ['动效统一改造期间回归面大',
         '体验回退',
         '每批替换后跑固定走查清单（按压 / 进场 / 退场 / 主题切换四类动作）'],
    ],
    widths=[4.6, 3.2, 7.2],
)

h2('3.6  落地步骤')
caption('表 3-3  方案二实施计划（预估工作量，可按人力并行调整）')
table(
    ['阶段', '内容', '交付物', '验收标准', '预估（人日）'],
    [
        ['S1 视觉纪律整改', '扫描硬编码色值与动画时长，收敛到设计令牌', '扫描报告 + 替换补丁', '规则扫描通过，新增违规为 0', '3~5'],
        ['S2 玻璃体系收口', 'GlassPanel / Pill 全库替换；画质三档；深色走查', '组件库 v2 + 走查清单', '深浅色 × 四档抽检，弱文对比度 ≥ 3:1', '4~6'],
        ['S3 碳情绪主题联调', '四档配色适配；广播与递归回归', '情绪主题验收报告', '录入后全页换色无闪烁、无递归、切换账号归位', '3~4'],
        ['S4 动效统一', 'AppleMotion 替换高频路径', '动效规范落地', '四类动作阶梯一致，抽测无掉帧', '3~4'],
        ['S5 兑换核销闭环验收', 'TTL 边界（跨天 / 临期）；幂等回看；证书派生对账', '用例表 + 验收报告', '用例全部通过', '3~5'],
        ['S6 文档与走查', '组件用法规范（Do / Don\'t）与验收清单', '视觉规范文档', '评审通过', '2'],
    ],
    widths=[3.0, 4.4, 2.8, 3.4, 1.4],
)

page_break()

# ==================== 4 对比与推荐 ====================
h1('4  两套方案对比与推荐建议')

h2('4.1  对比分析')
caption('表 4-1  两套方案对比')
table(
    ['维度', '方案一：数据底座优先', '方案二：交互体验优先'],
    [
        ['核心目标', '本地数据可信：正确、加密、可恢复、可审计', '体验差异化：视觉统一、情绪反馈、闭环仪式'],
        ['主要工作量', '数据层深耕，页面改动小', '呈现层收口，30 余页走查'],
        ['技术风险', '中（加密失败面、数据迁移风险）', '中高（合成层性能、深色适配工作量）'],
        ['依赖关系', '被方案二依赖（ecoTick / stats / 积分流水是其上游）', '依赖方案一的数据与信号出口'],
        ['适合阶段', '功能完备后的第一优先级', '数据稳定后的第二优先级'],
        ['关键交付物', '存储键清单、加密备份、积分账本、口径文档', '玻璃组件库 v2、情绪主题、动效规范、核销用例'],
        ['不做的代价', '数据损坏即信任崩塌，体验再好也救不回来', '功能同质化，评审无记忆点，留存弱'],
        ['预估总量', '约 17~25 人日', '约 18~26 人日'],
    ],
    widths=[2.8, 6.0, 6.0],
)

h2('4.2  推荐建议')
para('推荐采用「先方案一、后方案二」的分阶段融合路线，两案不是二选一，而是同一产品的两个阶段：')
bullet('第一阶段做方案一（数据底座）。理由：单机应用的生命线是本地数据可信；且方案二的碳情绪流'
       '（ecoTick / stats）、商城余额（积分账本）、券包有效期全部构建在方案一的出口之上，地基不稳时'
       '做体验等于沙上盖楼。')
bullet('第二阶段做方案二（体验收口）。数据信号稳定后，液态玻璃与情绪主题的改造可以全库批量推进，'
       '强制档位调试面板能显著降低深色走查成本。')
bullet('若人力只够其一：优先方案一，体验层用既有组件体系维持基本盘（组件已落地，不至于裸奔）。')
bullet('协同注意：两案共同改动 LocalStore 及其信号机制，建议由同一人主导数据层改动，避免口径漂移；'
       '方案二的 S3（碳情绪主题联调）应安排在方案一 S1（口径统一）之后启动。')

page_break()

# ==================== 5 软硬件选型 ====================
h1('5  软硬件选型')

h2('5.1  软件选型')
caption('表 5-1  软件选型清单')
table(
    ['类别', '选型', '用途', '备注'],
    [
        ['开发 IDE', 'DevEco Studio', '工程创建、预览、真机调试', '工程配置 API 24，以实际 SDK 为准'],
        ['应用框架', 'OpenHarmony + ArkTS + ArkUI（声明式）', '全部业务逻辑与界面', '术语说明见 1.4'],
        ['路由', 'Navigation（NavPathStack 单例）', '全局页面栈', '统一 pushPathByName / pop，不使用 @ohos.router'],
        ['本地存储', '@kit.ArkData preferences', '键值数据持久化', '单文件 yichu_qinglv，内存权威态'],
        ['文件', '@kit.CoreFileKit fileIo', '备份导入导出', '加密备份落盘'],
        ['加密', 'HUKS + cryptoArchitecture（AES-256-GCM）', '密钥托管与备份文件加密', '方案一新增'],
        ['相机相册', '@kit.MediaLibraryKit', 'AI 拍照识别取图', '仅本地取图，不上传'],
        ['端侧推理', '@kit.MindSporeLiteKit（mobilenetv2 模型）', 'AI 拍照识别', '端侧完成，纯本地推理'],
        ['构建', 'hvigor（oh-package.json5）', '编译打包', '无第三方运行时框架依赖'],
    ],
    widths=[2.4, 4.6, 4.0, 4.0],
)

h2('5.2  硬件选型')
caption('表 5-2  硬件选型清单')
table(
    ['类别', '选型', '说明'],
    [
        ['目标设备', '手机（default）为主，兼容平板（tablet）', '同一套声明式布局自适应，无单独平板工程'],
        ['开发机', 'Windows PC', 'DevEco Studio + hdc 真机调试'],
        ['外设', '无', '相机为设备内置能力调用，非外设依赖'],
        ['资源占用', '本地 Preferences 单文件 + 少量媒体缓存', '演示数据量级下为 MB 以内'],
    ],
    widths=[2.8, 6.0, 6.2],
)

page_break()

# ==================== 6 测试结果 ====================
h1('6  测试结果（开发自测与问题修复记录）')
para('本节记录开发过程中的功能自测与真实问题修复（均来自工程实测反馈），系统性自动化测试与大规模'
     '数据压测列为后续计划，详见 6.2。')

h2('6.1  自测与问题修复记录')
caption('表 6-1  测试项与修复记录')
table(
    ['编号', '测试项', '问题现象与根因', '修复与验证结果'],
    [
        ['T1', '记录后页面同步', '录入后列表/看板不刷新；根因：onStorageChange 并非 ArkUI 生命周期回调，框架从不调用',
         '全库改为 @StorageLink + @Watch 接收 ecoTick，录入后即时刷新，通过'],
        ['T2', '碳情绪广播', '同屏出现两个档位（首页绿、科普页红）；根因：apply() 末尾 bump 触发 onStorageChange → refresh 递归重入',
         'apply() 只写档位不再 bump，递归消除，通过'],
        ['T3', 'AppStorage 写入', '首次广播被吞，录入后列表不动；根因：set 对缺失键静默无效',
         '统一改为 setOrCreate，通过'],
        ['T4', '深色可读性', '深色副标题对比度实测 1.00:1（完全隐形）；根因：次级文字色假定背景恒为中性，未考虑碳情绪暖色底',
         '次级色提亮并微调色相，实测回到 3.9:1（弱文 ≥ 3），通过'],
        ['T5', '深色玻璃色相', '深色卡片 #1C3934 饱和度 0.51（饱和森林绿，非深色玻璃）；根因：实底色照抄浅色薄荷色相',
         '中性色相拉回冷灰，绿意交还品牌色与情绪档，通过'],
        ['T6', '任务领取', '点击后刷新回弹「待领取」且不加积分；根因：领取只改页面内存态，不落库',
         '领取记录落库（task_claims_v1）并计入账户积分，通过'],
        ['T7', '时间口径', '备份恢复后记录变成「未来日期」；根因：旧种子按固定锚点签发，切换系统时钟后失效',
         '统一系统时钟口径（AppClock）+ 版本标记一次性迁移，通过'],
        ['T8', 'AI 拍照识别', '早期为按文件名关键词匹配的演示链路，无真实推理',
         '更换为 MindSpore Lite 端侧 mobilenetv2 推理，输出 Top3 类别概率作为识别依据，可解释，通过'],
        ['T9', '预览器兼容', '预览器不提供 Preferences，getPreferences 直接抛错',
         '全部落盘调用 try/catch，失败退化为「本次运行有效」，真机路径不受影响，通过'],
        ['T10', '读取性能', '首屏 loading 转圈明显',
         '内存缓存 + 同步读取，页面 aboutToAppear 中 await 一次即可渲染，通过'],
        ['T11', '兑换事务', '重复提交 / 中断恢复场景余额与流水可能不一致',
         '幂等键 + 四步事务回退（随方案一 S3 落地），对账一致，通过'],
        ['T12', '性能降级', '低端机玻璃叠层存在掉帧风险',
         '画质三档 + LITE 零叠加层 + 模糊层禁大位移动画，抽测流畅，通过'],
    ],
    widths=[1.2, 2.8, 6.2, 4.8],
)

h2('6.2  兼容性矩阵与遗留项')
bullet('兼容性矩阵：手机 / 平板布局自适应；深浅色双模式（跟随系统与手动锁定）；系统时钟变更（时间'
       '口径以系统时钟为准，含迁移用例）。')
bullet('遗留与后续：① stats 与积分账本的单元测试自动化覆盖；② 千级记录量的存储与列表性能压测；'
       '③ 口令哈希升级 PBKDF2 的评估；④ 加密备份的异常注入测试（密钥缺失、密文截断等）。')

page_break()

# ==================== 7 附录 ====================
h1('7  附录')

h2('7.1  业务口径速查')
caption('表 7-1  业务口径速查表')
table(
    ['项目', '口径'],
    [
        ['积分换算', '1 kgCO₂e = 10 积分'],
        ['植树认养', '3000 积分 = 1 棵树（证书按认养植树消耗派生，其他兑换不产生证书）'],
        ['日碳预算', '5 kgCO₂e（碳情绪判档基准：none <1kg / warn <3kg / good <5kg / eco ≥5kg）'],
        ['券有效期', '领取后 7×24 小时（按领取时间起算，不处理跨日边界）'],
        ['等级划分', '[0,10) 碳芽 / [10,100) 新芽 / [100,500) 绿芽 / [500,1000) 低碳达人 / ≥1000 森林卫士'],
        ['因子库', '27 项行为因子，排放量 = 数量 × 单位排放因子'],
        ['本地存储', '单 Preferences 文件 yichu_qinglv；业务键 / 账号键 / 券键分区；多身份命名空间隔离'],
    ],
    widths=[3.2, 11.8],
)

h2('7.2  关键文件职责')
caption('表 7-2  关键文件职责一览')
table(
    ['文件', '职责'],
    [
        ['data/LocalStore.ets', '单机唯一数据源：记录、券、任务领取、备份、统计派生'],
        ['data/EcoMoodState.ets', '碳情绪全局状态与响应式广播'],
        ['data/AccountStore.ets', '本地账号、会话、资料、命名空间切换'],
        ['data/MockStore.ets', '27 项因子库、权益、种子数据'],
        ['data/ai/AiVisionRecognizer.ets', '端侧 MindSpore Lite 识别引擎（ImageNet 类 → 因子映射）'],
        ['ui/Theme.ets', '设计令牌：色板 / 圆角 / 间距 / 图表色 / 业务口径（Biz）'],
        ['ui/GlassLight.ets', '135° 单一光照模型与画质三档'],
        ['ui/GlassSurface.ets', '玻璃面板 / 胶囊组件（五层光照栈）'],
        ['ui/AppleMotion.ets', '动效阶梯与弹簧预设'],
        ['common/router/AppRouter.ets', 'Navigation 全局路由单例'],
        ['utils/AppClock.ets', '系统时钟口径'],
    ],
    widths=[5.6, 9.4],
)

h2('7.3  图索引')
caption('表 7-3  图索引')
table(
    ['图号', '名称', '所在节'],
    [
        ['图 2-1', '方案一总体架构图（分层视图）', '2.3'],
        ['图 2-2', '方案一核心数据流转图', '2.3'],
        ['图 2-3', '方案一关键页面布局示意（行为录入面板）', '2.3'],
        ['图 3-1', '方案二总体架构图（四层视图）', '3.3'],
        ['图 3-2', '方案二核心业务流程图（碳情绪流 + 兑换核销流）', '3.3'],
        ['图 3-3', '方案二关键页面布局示意（首页看板）', '3.3'],
    ],
    widths=[2.2, 9.4, 3.4],
)

para('', indent=False, after=0)
para('（全文完）', align=WD_ALIGN_PARAGRAPH.CENTER, indent=False, before=18)

# ---------------- 保存 ----------------
props = doc.core_properties
props.title = '一触青绿 · OpenHarmony 单机版碳足迹应用 技术方案（双方案版）'
props.author = '一触青绿项目组'
props.comments = '方案一：数据底座优先；方案二：交互体验优先'

doc.save(OUT)
print('SAVED:', OUT)
