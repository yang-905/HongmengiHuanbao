#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成两份正式文档（宋体 / 小四 / 1.5 倍行距）：
  1) 一触青绿_设计方案.docx      —— 按模板：概述 / 设计思路 / 资源需求 / 建设方案(4.1-4.6) / 功能实现逻辑 / 术语
  2) 一触青绿_业务逻辑讲解稿.docx —— 周五汇报教学材料（讲法 + 公式 + Q&A + 术语）
"""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIAG = os.path.join(ROOT, 'tools', 'diagrams')
GREEN = RGBColor(0x1F, 0x7A, 0x5F)
INK = RGBColor(0x22, 0x33, 0x3B)
GRAY = RGBColor(0x5A, 0x6A, 0x70)


# ---------------- 排版基础 ----------------
def set_font(run, east='宋体', ascii_f='Times New Roman', size=12, bold=False, color=None):
    run.font.name = ascii_f
    run.font.size = Pt(size)
    run.font.bold = bold
    if color is not None:
        run.font.color.rgb = color
    rpr = run._element.get_or_add_rPr()
    rf = rpr.find(qn('w:rFonts'))
    if rf is None:
        rf = OxmlElement('w:rFonts')
        rpr.append(rf)
    rf.set(qn('w:eastAsia'), east)
    rf.set(qn('w:ascii'), ascii_f)
    rf.set(qn('w:hAnsi'), ascii_f)


def base_doc():
    doc = Document()
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)
    sec.top_margin = sec.bottom_margin = Cm(2.54)
    sec.left_margin = sec.right_margin = Cm(3.0)
    st = doc.styles['Normal']
    st.font.name = 'Times New Roman'
    st.font.size = Pt(12)
    rpr = st.element.get_or_add_rPr()
    rf = rpr.find(qn('w:rFonts'))
    if rf is None:
        rf = OxmlElement('w:rFonts')
        rpr.append(rf)
    rf.set(qn('w:eastAsia'), '宋体')
    st.paragraph_format.line_spacing = 1.5
    st.paragraph_format.space_before = Pt(0)
    st.paragraph_format.space_after = Pt(0)
    return doc


def _indent_chars(par, chars=200):
    ppr = par._p.get_or_add_pPr()
    ind = ppr.find(qn('w:ind'))
    if ind is None:
        ind = OxmlElement('w:ind')
        ppr.append(ind)
    ind.set(qn('w:firstLineChars'), str(chars))


def p(doc, text, indent=True, align='justify', size=12, bold=False, east='宋体',
      color=None, after=4, before=0):
    par = doc.add_paragraph()
    run = par.add_run(text)
    set_font(run, east=east, size=size, bold=bold, color=color)
    pf = par.paragraph_format
    pf.line_spacing = 1.5
    pf.space_after = Pt(after)
    pf.space_before = Pt(before)
    if align == 'center':
        pf.alignment = WD_ALIGN_PARAGRAPH.CENTER
    elif align == 'left':
        pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    else:
        pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    if indent:
        _indent_chars(par)
    return par


def h1(doc, text):
    par = doc.add_paragraph()
    run = par.add_run(text)
    set_font(run, east='黑体', size=16, bold=True, color=INK)
    pf = par.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(16)
    pf.space_after = Pt(10)
    pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    return par


def h2(doc, text):
    par = doc.add_paragraph()
    run = par.add_run(text)
    set_font(run, east='黑体', size=14, bold=True, color=INK)
    pf = par.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(12)
    pf.space_after = Pt(6)
    pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    return par


def h3(doc, text):
    par = doc.add_paragraph()
    run = par.add_run(text)
    set_font(run, east='黑体', size=12, bold=True, color=GREEN)
    pf = par.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(8)
    pf.space_after = Pt(4)
    pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    return par


def bullet(doc, text, size=12):
    par = doc.add_paragraph()
    run = par.add_run('● ' + text)
    set_font(run, size=size)
    pf = par.paragraph_format
    pf.line_spacing = 1.5
    pf.space_after = Pt(3)
    pf.left_indent = Cm(0.74)
    return par


def img(doc, name, width=14.6):
    par = doc.add_paragraph()
    par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    par.paragraph_format.space_before = Pt(8)
    par.paragraph_format.space_after = Pt(8)
    run = par.add_run()
    run.add_picture(os.path.join(DIAG, name), width=Cm(width))


def table(doc, headers, rows, widths=None, size=10.5):
    t = doc.add_table(rows=1 + len(rows), cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = 1
    for j, htext in enumerate(headers):
        cell = t.rows[0].cells[j]
        cell.text = ''
        run = cell.paragraphs[0].add_run(htext)
        set_font(run, east='黑体', size=size, bold=True)
        cell.paragraphs[0].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cell.paragraphs[0].paragraph_format.line_spacing = 1.3
        shd = OxmlElement('w:shd')
        shd.set(qn('w:val'), 'clear')
        shd.set(qn('w:fill'), 'E3F4EE')
        cell._tc.get_or_add_tcPr().append(shd)
    for i, row in enumerate(rows):
        for j, val in enumerate(row):
            cell = t.rows[i + 1].cells[j]
            cell.text = ''
            run = cell.paragraphs[0].add_run(str(val))
            set_font(run, size=size)
            cell.paragraphs[0].paragraph_format.line_spacing = 1.3
    if widths:
        for j, w in enumerate(widths):
            for r in t.rows:
                r.cells[j].width = Cm(w)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return t


def cover(doc, title, subtitle, meta):
    for _ in range(5):
        doc.add_paragraph()
    par = doc.add_paragraph()
    par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = par.add_run(title)
    set_font(run, east='黑体', size=26, bold=True, color=INK)
    doc.add_paragraph()
    par = doc.add_paragraph()
    par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = par.add_run(subtitle)
    set_font(run, east='黑体', size=18, bold=True, color=GREEN)
    for _ in range(6):
        doc.add_paragraph()
    for line in meta:
        par = doc.add_paragraph()
        par.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = par.add_run(line)
        set_font(run, size=14)
    doc.add_page_break()


def toc(doc, items):
    h1(doc, '目  录')
    for lv, text in items:
        par = doc.add_paragraph()
        run = par.add_run(text)
        if lv == 1:
            set_font(run, east='黑体', size=12, bold=True)
            par.paragraph_format.space_before = Pt(6)
        else:
            set_font(run, size=12)
            par.paragraph_format.left_indent = Cm(0.74)
        par.paragraph_format.line_spacing = 1.5
    doc.add_page_break()


# ============================================================
#  文档一：设计方案（按用户模板）
# ============================================================
def build_design_doc():
    doc = base_doc()
    cover(doc, '一触青绿', '—— 基于 OpenHarmony 的碳普惠应用 · 设计方案',
          ['文档类别：系统设计方案', '版本：V2.0', '编制日期：2026 年 10 月 21 日',
           '工程：carbon-master（app / server / admin / db 四端）'])

    toc(doc, [
        (1, '1  概述'), (2, '1.1  项目背景'), (2, '1.2  系统建设的必要性'),
        (1, '2  项目设计思路'),
        (1, '3  资源需求（软硬件选型）'),
        (1, '4  建设方案'), (2, '4.1  系统架构'), (2, '4.2  整体功能架构'),
        (2, '4.3  软件架构'), (2, '4.4  业务流程'), (2, '4.5  接口对接'), (2, '4.6  硬件架构'),
        (1, '5  功能实现逻辑'),
        (1, '6  术语和缩略语'),
    ])

    # ---------- 1 概述 ----------
    h1(doc, '1  概述')
    h2(doc, '1.1  项目背景')
    p(doc, '在“2030 年碳达峰、2060 年碳中和”战略目标下，节能减排正从工业主战场向公众生活场景延伸。'
           '碳普惠机制通过将个人低碳行为量化、记账并给予激励，把宏观气候目标拆解为每一个普通用户可感知、'
           '可参与、可获益的日常动作，是衔接政策目标与公众行动的关键一环。')
    p(doc, '然而当前个人侧的低碳记录工具普遍存在三个短板：一是以网页或小程序为主，交互“网页感”重，'
           '缺少系统级应用的流畅与精致；二是数据口径不规范，减排量计算粗糙，难以支撑积分激励的公信力；'
           '三是设备孤岛，手机、手表、车机等多终端之间的行为数据无法互通合并。')
    p(doc, '与此同时，HarmonyOS（OpenHarmony）生态提供了声明式 UI（ArkTS / ArkUI）、分布式软总线'
           '与一次开发多端部署的能力，为打造一款体验与架构双优的碳普惠原生应用提供了理想土壤。'
           '本项目“一触青绿”即在此背景下立项：定位为面向个人用户的碳足迹记录与碳积分激励应用，'
           '采用四端工程形态——鸿蒙客户端（app）、若依后端服务（server）、运营管理端（admin）、'
           '数据库脚本（db），覆盖从行为记录到权益核销的完整业务闭环。')
    h2(doc, '1.2  系统建设的必要性')
    bullet(doc, '政策必要性：双碳目标落地需要公众侧广泛参与，碳普惠是国家与地方均认可的路径，'
                '需要合规、可量化的记录工具作为载体。')
    bullet(doc, '用户必要性：用户的绿色出行、节水节电、旧物回收等行为长期“无记录、无反馈、无激励”，'
                '需要一本“记账式”的低碳账本形成行为闭环。')
    bullet(doc, '技术必要性：验证 ArkTS 声明式开发、自定义渲染体系（液态玻璃材质与弹簧动效）、'
                'Stage 模型、Preferences 持久化与分布式软总线的工程化落地方式。')
    bullet(doc, '数据必要性：27 项行为因子与减排核算公式（kg = 因子值 × 数量）需要结构化落地，'
                '并保证端侧核算与服务端口径严格一致。')
    bullet(doc, '教学必要性：作为软件工程综合实践载体，完整覆盖需求分析、架构设计、编码实现、'
                '构建验证与汇报讲解的全流程。')

    # ---------- 2 设计思路 ----------
    h1(doc, '2  项目设计思路')
    h2(doc, '2.1  设计理念')
    p(doc, '“一触之间，青绿相随”。产品的核心理念是让低碳记录轻到只需“一触”，让正向反馈多到“青绿相随”，'
           '具体落实为四条设计主张：')
    bullet(doc, '一触即达：核心路径三步闭环（打开 → 记录 → 得积分），主框架采用 Tabs 四页签扁平导航，'
                '常用功能一屏可达，录入表单默认值贴近真实场景。')
    bullet(doc, '物理真实：自研 GlassLight 液态玻璃材质体系，以左上 45° 单一主光源、菲涅尔亮边与'
                'α 预合成模拟真实玻璃的光照层次；动效模拟弹簧回弹与惯性，按压有真实触感。')
    bullet(doc, '活的界面：碳情绪状态机（EcoMoodState）根据用户减排表现实时切换全应用配色，'
                '登录页、背景、图表随数据联动，让界面“感知”用户的低碳状态。')
    bullet(doc, '自洽明暗：深色模式不是简单反色，而是整套材质“换血”——深浅两套玻璃参数、'
                '三档画质降级与系统栏适配，保证两种主题下都成立。')
    h2(doc, '2.2  设计目标')
    bullet(doc, '功能完整：十大业务模块闭环（记录、核算、积分、商城、券包、证书、徽章、资讯、家庭、终端）。')
    bullet(doc, '体验流畅：交互动画统一使用 transform 类属性走合成层，时长与曲线全库收敛到一处定义，'
                '错峰入场避免首屏卡顿。')
    bullet(doc, '稳定可靠：预览器与真机双口径兜底，所有存储与网络失败均降级处理，不阻塞主流程。')
    bullet(doc, '数据自洽：减排、积分、证书、时钟统一口径；多账号数据命名空间级隔离。')
    h2(doc, '2.3  设计原则')
    bullet(doc, '单一数据源：LocalStore 为业务数据唯一权威（内存态 + best-effort 落盘），派生统计全部本地计算。')
    bullet(doc, '单向依赖分层：表现层 → 组件层 → 数据层 → 网络层 → 基础设施层，禁止反向与循环依赖。')
    bullet(doc, '失败降级：任何 IO 异常只降级不崩溃，演示数据种子可控（开发者账号“1”携带完整演示数据）。')

    # ---------- 3 资源需求 ----------
    h1(doc, '3  资源需求（软硬件选型）')
    h2(doc, '3.1  硬件选型')
    table(doc,
          ['用途', '选型', '说明'],
          [['开发机', 'Windows PC（16 GB 内存以上）', '安装 DevEco Studio，运行 hvigor 构建'],
           ['测试终端', 'HarmonyOS 手机 / 平板（API 24）', '真机验证；预览器用于快速 UI 走查'],
           ['服务端', 'Linux 云主机或本地服务器（4 核 8 GB 以上）', '部署 Nginx + 若依后端 + MySQL + Redis'],
           ['扩展终端', '手表 / 车机 / TV（可选）', '分布式软总线与超级终端能力验证']],
          widths=[3.0, 6.0, 5.4])
    h2(doc, '3.2  软件选型')
    table(doc,
          ['类别', '选型', '版本 / 说明'],
          [['端侧 IDE', 'DevEco Studio', '配套 API 24 SDK'],
           ['端侧框架', 'ArkTS / ArkUI（Stage 模型）', 'API 24（compileSdk / compatibleSdk 24）'],
           ['端侧构建', 'hvigor（assembleHap）', '随 DevEco Studio 提供'],
           ['后端框架', 'RuoYi-Vue（若依）', '3.8.7，carbon 业务模块'],
           ['后端运行时', 'JDK', '11'],
           ['数据库', 'MySQL', '8.0（utf8mb4）'],
           ['缓存', 'Redis', '6.x / 7.x'],
           ['管理端', 'Vue 3 + Element Plus（admin/）', '随若依框架'],
           ['端侧持久化', 'Preferences 首选项', '系统能力，无需三方依赖']],
          widths=[3.2, 6.2, 5.0])
    h2(doc, '3.3  选型依据')
    bullet(doc, '选择 HarmonyOS / ArkTS：生态要求叠加声明式 UI 开发效率与分布式能力，'
                '一套代码覆盖手机、平板乃至多终端。')
    bullet(doc, '自研 GlassLight 与 AppleMotion 而非三方库：预览器对部分原生弹窗存在兼容问题，'
                '自研体系体积可控、行为可预期，且能按项目视觉语言定制。')
    bullet(doc, '选择若依（RuoYi-Vue）：权限体系、代码生成与生态成熟度高，可快速搭建运营后台；'
                'carbon 业务表与因子种子独立成库，便于迁移。')
    bullet(doc, '端侧默认单机口径：演示场景零依赖、加载快；网络层完整保留，修改服务地址即可联调，'
                '兼顾“可演示”与“可扩展”。')

    # ---------- 4 建设方案 ----------
    h1(doc, '4  建设方案')
    h2(doc, '4.1  系统架构')
    p(doc, '系统采用四端一体架构：用户设备层承载鸿蒙应用（HAP），应用内部分为页面层、UI 组件层、'
           '业务数据层与网络层；云服务端由 Nginx 网关、若依后端（Spring Boot，:8089）、'
           'MySQL 8 与 Redis 组成，管理端（admin/）面向运营人员，数据库脚本（db/）负责建库与种子灌注。'
           '端侧与云端通过 HTTPS + App-Token 通信，断网时本地队列缓存、联网后批量补传。')
    img(doc, 'fig1_system.png')
    h2(doc, '4.2  整体功能架构')
    p(doc, '应用功能划分为十大模块：碳足迹记录、数据看板、积分与任务、积分商城、碳惠券包、证书与徽章、'
           '科普资讯、家庭与设置、AI 视觉识别、超级终端。全部模块复用同一套底层支撑：账号系统、'
           '本地数据仓库、主题 / 液态玻璃 / 动效体系与系统时钟。')
    img(doc, 'fig2_features.png')
    table(doc,
          ['模块', '核心功能', '主要页面 / 组件'],
          [['碳足迹记录', '27 项因子录入、AI 拍照识别', 'BehaviorAddSheet、AiRecognizePage、RecordListPage'],
           ['数据看板', '仪表盘、趋势图、分类分析', 'DashboardPage、TrendChartPage、CategoryAnalysisPage'],
           ['积分与任务', '任务中心、积分明细、月账单', 'PointsHomePage、TaskCenterPage、MonthBillPage'],
           ['积分商城', '权益兑换与确认', 'PointsMallPage、GlassDialog 确认弹窗'],
           ['碳惠券包', '我的券、核销二维码、凭证回看', 'CouponListPage、CouponRedeemPage'],
           ['证书与徽章', '植树证书、徽章墙', 'CertificateListPage、BadgeWallPage'],
           ['科普资讯', '文章列表 / 详情、问答、收藏', 'ArticleListPage、ArticleDetailPage、QuizSheet'],
           ['家庭与设置', '家庭账户、主题、备份、导出', 'FamilyPage、SettingsPage、BackupManagePage'],
           ['AI 视觉识别', '票据识别、智能填报', 'AiVisionRecognizer、AiRecognizePage'],
           ['超级终端', '跨设备同步（LWW）、智慧服务', 'SuperTerminalPage、SmartTipsPage']],
          widths=[2.8, 5.2, 5.8], size=9.5)
    h2(doc, '4.3  软件架构')
    p(doc, '端侧软件自上而下分为五层：应用表现层（启动 / 引导 / 登录闸门 / Tabs 主框架 / 30 余个'
           'NavDestination 二级页面）；UI 组件层（Theme 主题与业务常量、GlassLight 液态玻璃、'
           'AppleMotion 动效语言及通用组件）；业务数据层（AccountStore、LocalStore、MockStore、'
           'EcoMoodState、SyncStore）；网络层（HttpClient、ApiService、DataSource，含离线同步队列）；'
           '基础设施层（AppClock 系统时钟、AppConfig、AppRouter + PageMap 全局路由、Preferences 持久化）。'
           '层间单向依赖，平台能力（ArkUI / ArkTS、软总线）以侧栏形式纵贯支撑。')
    img(doc, 'fig3_software.png')
    h2(doc, '4.4  业务流程')
    p(doc, '核心业务流程为：启动 → 新手引导 → 登录 / 注册（新用户注册成功后由注册闸门强制完善资料，'
           '资料真实上屏后才解锁主框架）→ 主框架四页签 → 记录低碳行为（因子库手动录入或 AI 拍照识别）'
           '→ 减排核算（kg = 因子值 × 数量）→ 积分折算（pts = kg × 10，减排大于 0 保底 1 分）'
           '→ 本地存储（命名空间 @账号）。积分有三个出口：积分商城兑换权益生成碳惠券（7 天有效，'
           '使用即生成 ASCII 单行核销二维码）；植树认养（200 积分 = 1 棵树，发放证书）；'
           '数据看板（累计 / 今日 / 本月统计驱动等级、徽章、趋势图与月账单）。'
           '账号切换时整树重建并切换数据命名空间，实现多账号隔离。')
    img(doc, 'fig4_flow.png')
    h2(doc, '4.5  接口对接')
    p(doc, '端侧与服务端通过若依统一返回体（AjaxResult）交互，鉴权采用 App-Token：端侧以设备标识'
           '匿名登录换取令牌，后续请求均携带令牌，userId 由服务端按令牌注入，端侧不可伪造归属。'
           '记录上送使用端侧生成的 clientRecordId 作为幂等键，服务端按“用户 + 该 ID”去重，'
           '断网重传不产生重复记录；跨设备合并按 clientRecordId + updateTime 采用后写覆盖（LWW）策略。')
    img(doc, 'fig5_api.png')
    table(doc,
          ['接口', '方法', '说明'],
          [['/appLogin', 'POST', '匿名设备登录，换取 App-Token'],
           ['/behavior/factorList', 'GET', '拉取 27 项行为因子库'],
           ['/record/add', 'POST', '单条记录上送（clientRecordId 幂等）'],
           ['/record/syncBatch', 'POST', '离线队列批量补传'],
           ['/record/list', 'GET', '分页拉取云端记录'],
           ['/coupon/list', 'GET', '云端券列表（联调态）'],
           ['/certificate/list', 'GET', '云端证书列表（联调态）']],
          widths=[4.6, 2.0, 7.2], size=10)
    p(doc, '需要说明的是：端侧当前为单机演示口径，业务数据仅落本地 Preferences，上述网络层完整保留，'
           '将 AppConfig 中的服务地址指向后端即可进入四端联调形态。')
    h2(doc, '4.6  硬件架构')
    p(doc, '硬件侧分三区：用户终端（手机 / 平板为应用主载体，手表 / 车机 / TV 为扩展终端，'
           '经软总线近场互联构成超级终端）；网络区（WiFi / 4G / 5G / 以太网）；云服务端'
           '（Linux 服务器承载 Nginx、RuoYi-Admin、MySQL 8 与 Redis）。系统支持两种部署形态：'
           '演示形态为单机端侧，零依赖开箱即用；完整形态为四端联调，支持云端同步与运营后台。')
    img(doc, 'fig6_hardware.png')

    # ---------- 5 功能实现逻辑 ----------
    h1(doc, '5  功能实现逻辑')
    h2(doc, '5.1  减排核算与积分折算')
    p(doc, '减排量与积分全部在端侧按因子核算，与服务端口径严格一致（业务常量集中于 Theme.ets 的 '
           'Biz 类）：')
    bullet(doc, '减排量：kg = round(因子值 × 数量, 3)，保留 3 位小数（LocalStore.addRecord）。')
    bullet(doc, '积分：pts = round(kg × 10)，减排大于 0 时保底 1 分（Biz.pointsOf，1 kgCO2e = 10 积分）。')
    bullet(doc, '等级：按累计减排量分 5 档（10 / 100 / 500 / 1000 kg），对应碳芽、新芽、绿芽、'
                '低碳达人、森林卫士。')
    bullet(doc, '可用积分 = 累计获得 − 实际兑换消耗，下限钳 0；植树棵数只从真实兑换消耗推导'
                '（200 积分 = 1 棵树 = 1 张证书），杜绝“折算棵数”与证书两张皮。')
    h2(doc, '5.2  账号系统与注册闸门')
    p(doc, 'AccountStore 负责注册、登录、会话与个人资料：账号表与口令混淆哈希（盐 + xorshift）'
           '仅存本机；注册成功后自动登录并置位资料完善意图。针对“资料页比主框架上屏慢、'
           '手快能点到主页面子页面”的竞态，主框架实现注册闸门：注册成功即零帧锁死主框架交互，'
           '资料页经 NavDestination.onShown 确认真实上屏后才解锁，并设 4 秒兜底定时器防止信号丢失。')
    h2(doc, '5.3  多账号数据隔离')
    p(doc, '业务存储键按账号追加后缀形成命名空间（如 local_records@alice），登录 / 切换账号时'
           'LocalStore.switchUser 切换命名空间，登录闸门保证未登录不渲染业务页面，'
           '不存在跨账号数据可见的窗口期；预览器无 Preferences 时以会话内快照兜底，'
           '真机落盘与快照恢复双保险。')
    h2(doc, '5.4  碳惠券包与核销')
    p(doc, '兑换走“校验余额 → 生成券入队 → best-effort 落盘”的事务口径：券号格式 '
           'CP-<时间戳>-<随机 4 位>，有效期以领取时间起算 7 个自然日；过期状态由时间推导不落盘，'
           '边界取“到达即失效”。使用券时当场生成核销二维码：内容为英文感谢语 + 精简凭证字段的'
           '单行纯 ASCII 文本（约 146 字节，含券号、6 位核销码、时间与有效期），该格式经四轮实测校准，'
           '兼顾码图密度与微信可扫性；已使用的券重复进入返回同一内容，支持凭证回看。')
    h2(doc, '5.5  证书与徽章口径')
    p(doc, '植树证书仅由认养植树权益（benefitCode = b7）兑换消耗推导，兑换其他权益不产生证书；'
           '徽章采用结构化判定（类别计数 + 阈值），如“绿色出行累计 50 次”，判定逻辑集中在种子与'
           '徽章定义表，新增徽章只需追加一行定义。')
    h2(doc, '5.6  碳情绪与主题换血')
    p(doc, '记录增删即触发 EcoMoodState 重算档位并广播，全应用配色（登录页、背景、图表）'
           '随低碳表现联动；账号切换时显式重置档位，避免停留在旧账号情绪。深色主题通过'
           'ThemePalette.applyDark 与渲染刻度广播完成“换血”，静态色值组件订阅刻度重建，'
           '玻璃材质按深浅两套参数与三档画质降级适配。')
    h2(doc, '5.7  系统时钟校准')
    p(doc, '所有面向用户的时间口径（记录日期、今日 / 本月分桶、券有效期、核销时间）统一经由 '
           'AppClock 输出，支持本地校准；而记录 ID 与跨设备合并时间戳仍使用真实 Date.now()，'
           '保证毫秒级唯一性与单调性，两类入口语义分离，防止时间口径调整导致同会话撞号。')
    h2(doc, '5.8  动效与流畅性')
    p(doc, '动效语言收敛于 AppleMotion：五档时长（100 / 200 / 350 / 500 / 380 ms）与统一曲线、'
           '三档弹簧预设、按压 96% 缩放反馈、错峰入场（每项 30 ms、封顶 260 ms）。动画只使用'
           'translate / scale / opacity 等合成层属性，避免触碰布局属性；弹窗与页面入场采用'
           '显式 animateTo 驱动，规避声明式动画作用域污染子组件的问题。')

    # ---------- 6 术语 ----------
    h1(doc, '6  术语和缩略语')
    table(doc,
          ['术语 / 缩略语', '说明'],
          [['CO2e', '二氧化碳当量，温室气体统一计量单位'],
           ['碳普惠', '对个人低碳行为量化并给予激励的机制'],
           ['碳足迹', '个人活动产生的温室气体排放总量'],
           ['减排因子', '单位低碳行为对应的减排量系数（kg / 单位）'],
           ['ArkTS', 'HarmonyOS 应用开发语言（TypeScript 超集）'],
           ['ArkUI', 'HarmonyOS 声明式 UI 框架'],
           ['NavDestination', 'Navigation 路由体系中的二级页面容器'],
           ['Stage 模型', 'HarmonyOS 应用进程内 Ability 生命周期模型'],
           ['HAP', 'HarmonyOS Ability Package，应用安装包格式'],
           ['Preferences', 'HarmonyOS 轻量级键值持久化能力'],
           ['App-Token', '端侧匿名登录后由服务端签发的访问令牌'],
           ['LWW', 'Last-Write-Wins，按更新时间戳后写覆盖的合并策略'],
           ['TTL', '生存周期，本应用指碳惠券有效期（7 天）'],
           ['UUID', '通用唯一识别码，clientRecordId 由端侧生成'],
           ['RuoYi', '若依后台管理框架（Vue 版 3.8.7）'],
           ['hvigor', 'HarmonyOS 应用构建工具'],
           ['API 24', '本工程 compileSdk / compatibleSdk 版本号'],
           ['软总线', 'HarmonyOS 分布式设备互联总线'],
           ['stagger', '错峰入场，列表逐项延迟播放动画'],
           ['xorshift', '演示级口令混淆哈希所用移位混淆算法']],
          widths=[4.2, 9.6], size=10.5)

    out = os.path.join(ROOT, '一触青绿_设计方案.docx')
    doc.save(out)
    print('saved', out)
    return out


# ============================================================
#  文档二：业务逻辑讲解稿（周五汇报教学）
# ============================================================
def build_talk_doc():
    doc = base_doc()
    cover(doc, '一触青绿 · 业务逻辑讲解稿',
          '—— 代码熟悉 / 系统测试 / 汇报讲解 专用',
          ['用途：周五 8:30 办公室汇报准备', '适用对象：零基础起步', '日期：2026 年 10 月 21 日'])

    h1(doc, '〇、这份稿子怎么用')
    bullet(doc, '第一步：先背“30 秒电梯陈述”，能做到脱口而出。')
    bullet(doc, '第二步：读第三章，把四个公式和一条主线讲给自己听，讲不顺就重复。')
    bullet(doc, '第三步：打开第五章列出的五个文件，每个看 10 分钟，对照“代码地图”找位置。')
    bullet(doc, '第四步：拿第七章的 12 个问题自问自答，答不上来的回第三章查。')
    bullet(doc, '汇报当天带：本稿 + 设计方案文档（图都在里面，可照图讲）。')

    h1(doc, '一、30 秒电梯陈述（必背）')
    p(doc, '“一触青绿是一款基于 HarmonyOS 的碳普惠应用，解决的是个人低碳行为无记录、无反馈、'
           '无激励的问题。用户把绿色出行、节水节电、旧物回收这类行为记一笔，系统按国家口径的'
           '排放因子算出减排量，再折算成积分；积分可以在商城兑换权益、可以认养植树，'
           '兑换生成的碳惠券支持二维码核销，形成完整闭环。技术上采用四端工程：鸿蒙客户端、'
           '若依后端、管理端和数据库脚本，端侧做了液态玻璃材质和统一的动效语言。')

    h1(doc, '二、这个应用到底是干什么的（大白话）')
    p(doc, '把它想象成三样东西的合体：')
    bullet(doc, '一本账本：专门记“低碳行为”。你骑了 10 公里自行车、带了餐盒、回收了 2 公斤废纸，'
                '都记上去，每笔都算出少了多少碳排放（单位 kgCO2e）。')
    bullet(doc, '一家积分银行：每笔减排自动换积分，1 公斤二氧化碳当量 = 10 积分，积分只增不减，'
                '花掉的记“兑换消耗”，余额永远对得上。')
    bullet(doc, '一个优惠券包：积分能在商城换权益（公交券、植树认养等），换到的券 7 天内有效，'
                '用的时候弹出核销二维码，商家一扫即用，凭证还能回看。')
    p(doc, '所以整套业务的主线就一句话：记一笔 → 算减排 → 得积分 → 花积分 → 核销券。'
           '周五讲的时候，把这句写在黑板/幻灯片最上面，所有内容都挂在它下面。')

    h1(doc, '三、核心业务逻辑：一条主线 + 四个公式')
    h2(doc, '3.1  一条主线')
    p(doc, '启动 → 引导 → 登录 / 注册（新用户强制完善资料）→ 主框架四页签（首页 / 积分 / 券包 / 我的）'
           '→ 记录行为 → 核算 → 积分 → 存储 → 三个出口（商城 / 种树 / 看板）。'
           '建议对照设计方案文档的图 4 讲，一图足够。')
    h2(doc, '3.2  四个公式（必须记住，张口就来）')
    table(doc,
          ['公式', '内容', '代码位置'],
          [['公式 1（减排量）', 'kg = 因子值 × 数量，保留 3 位小数', 'LocalStore.ets addRecord()'],
           ['公式 2（积分）', 'pts = kg × 10，减排大于 0 保底 1 分', 'Theme.ets Biz.pointsOf()'],
           ['公式 3（余额）', '可用积分 = 累计获得 − 兑换消耗（下限钳 0）', 'LocalStore.ets stats()'],
           ['公式 4（种树）', '200 积分 = 1 棵树 = 1 张证书', 'Theme.ets Biz.POINTS_PER_TREE']],
          widths=[3.4, 6.4, 4.0], size=10)
    h2(doc, '3.3  一个可以现场算的例子')
    p(doc, '“我今天骑车 10 公里。因子库里骑行的因子是 0.19 kg/公里，所以减排量 = 0.19 × 10 = 1.9 kg；'
           '积分 = 1.9 × 10 = 19 分；再记一次自带水杯，因子 0.1，1 次就是 0.1 kg，积分保底 1 分。'
           '今天合计 20 分。攒到 200 分我就能认养一棵树，拿一张证书。”'
           '（把用户 App 里的真实数字报出来，效果更好。）')
    h2(doc, '3.4  等级与徽章（讲的时候显完整）')
    p(doc, '累计减排量决定等级：10 / 100 / 500 / 1000 kg 五档，对应碳芽、新芽、绿芽、低碳达人、'
           '森林卫士；徽章是结构化判定，比如“绿色出行累计 50 次”，判定条件就是一行定义，'
           '新增徽章不用改逻辑。')

    h1(doc, '四、代码地图：56 个文件从哪读起')
    h2(doc, '4.1  五个必读文件（按顺序读，共约 50 分钟）')
    table(doc,
          ['顺序', '文件', '读什么', '对应业务'],
          [['1', 'pages/Index.ets', 'Tabs 主框架 + 登录闸门 + 注册意图消费', '应用骨架'],
           ['2', 'data/LocalStore.ets', 'addRecord / stats / exchange / useCoupon', '业务核心：记录与券'],
           ['3', 'ui/Theme.ets 的 Biz 类', '四个公式与等级定义', '业务规则'],
           ['4', 'data/AccountStore.ets', '注册 / 登录 / 会话 / 多账号隔离', '账号体系'],
           ['5', 'data/MockStore.ets', '27 项因子库与演示种子', '数据来源']],
          widths=[1.2, 4.6, 5.6, 3.0], size=9.5)
    h2(doc, '4.2  目录速查')
    table(doc,
          ['目录', '放什么', '典型文件'],
          [['pages/', '全部页面（30+ 个 NavDestination）', 'DashboardPage、PointsMallPage、CouponRedeemPage'],
           ['data/', '账号、本地仓库、种子、情绪、主题模式', 'AccountStore、LocalStore、MockStore、EcoMoodState'],
           ['ui/', '主题、液态玻璃、动效、通用组件', 'Theme、GlassLight、AppleMotion、Components'],
           ['net/', '网络层（联调保留）', 'HttpClient、ApiService、DataSource'],
           ['utils/', '时钟与同步', 'AppClock、SyncStore'],
           ['common/', '配置与路由', 'AppConfig、AppRouter、PageMap'],
           ['model/', '网络数据模型', 'CarbonModels']],
          widths=[2.2, 6.0, 5.6], size=9.5)

    h1(doc, '五、三个能加分的“技术亮点”')
    h2(doc, '5.1  注册闸门（竞态修复，最能体现代码功底）')
    p(doc, '问题：注册成功后，“完善资料”页有时比主框架上屏慢，用户手快能直接点到主页面里的子页面。'
           '解法：注册成功立刻把主框架交互锁死（零帧延迟，不等任何动画帧）；资料页不是“弹出来”'
           '就算数，而是等系统级 onShown 回调确认“真的出现在屏幕上”才解锁；再加 4 秒兜底定时器。'
           '讲解词：“这不是玄学 bug，是会话广播与页面挂载的竞态，我用一个闸门把首帧锁死，'
           '用真实上屏信号解锁，双保险。”')
    h2(doc, '5.2  液态玻璃 GlassLight（视觉体系）')
    p(doc, '自研 1200 余行的玻璃材质：左上 45° 单一主光源、边缘菲涅尔亮边、α 预合成防止玻璃发脏，'
           '滚动时带视差。深色模式不是反色，是整套材质参数“换血”，并按设备性能三档降画质。')
    h2(doc, '5.3  AppleMotion 动效语言（流畅性）')
    p(doc, '全库动效收敛到一处定义：五档时长（100 / 200 / 350 / 500 / 380 ms）、三档弹簧、'
           '按压 96% 缩放回弹、列表错峰入场。动画只碰 translate / scale / opacity 这类合成层属性，'
           '不碰布局属性，所以不掉帧。')

    h1(doc, '六、照图讲架构（每张图 30 秒台词）')
    table(doc,
          ['图', '30 秒台词'],
          [['图 1 系统架构', '四端一体：左边用户设备，中间鸿蒙应用分四层，右边若依后端加 MySQL、'
                            'Redis；端侧现在单机口径，网络层留着，改个地址就能联调。'],
           ['图 2 功能架构', '十大模块，主线是记录到核销；底下四个支撑体系被所有模块复用。'],
           ['图 3 软件架构', '端侧五层：表现、组件、数据、网络、基础设施，单向依赖，右边是平台能力。'],
           ['图 4 业务流程', '用户旅程：新用户被闸门挡着完善资料；然后记行为、核算、得积分；'
                            '积分三个出口——商城、种树、看板。'],
           ['图 5 接口对接', '三类接口：匿名登录拿令牌、拉因子库、上送记录；幂等靠 clientRecordId，'
                            '离线批量补传。'],
           ['图 6 硬件架构', '三区：终端、网络、云服务器；两种部署形态——演示单机版与完整联调版。']],
          widths=[3.2, 10.6], size=10)

    h1(doc, '七、最可能被问到的 12 个问题')
    qa = [
        ('Q1 和市面上碳账户小程序有什么区别？',
         '三点：① 系统级原生体验，不是 H5 网页感；② 数据口径专业，27 项因子、减排量精确到 '
         '0.001 kg，端侧核算与服务端口径一致；③ 分布式能力，超级终端跨设备合并，小程序生态做不到。'
         '而且是四端工程，不只是前端 Demo。'),
        ('Q2 减排量怎么算的，准吗？',
         'kg = 因子值 × 数量。因子库里比如步行 0.19 kg/公里、公交 0.10 kg/公里，与后端种子同源。'
         '准不准取决于因子权威性，我们保留了 factorSource 字段，生产环境挂官方发布因子即可。'),
        ('Q3 积分谁发行的，能提现吗？',
         '系统按减排量自动发行，1 kgCO2e = 10 积分，只增不减；只能应用内兑换权益，不设提现，'
         '是激励闭环不是金融资产。'),
        ('Q4 券核销是谁来扫谁？',
         '用户点“使用”，端侧当场生成核销二维码（单行 ASCII，含券号 + 6 位核销码 + 时间），'
         '商户或系统扫码后回传核销结果。当前演示闭环：微信可扫、凭证可回看；服务端化后由后端校验。'),
        ('Q5 数据存在哪，换手机怎么办？',
         '演示口径存本机 Preferences（内存权威态 + best-effort 落盘）。换手机两条路：应用内备份导出，'
         '或四端联调后云端同步（离线队列 + 幂等 + LWW 合并）。'),
        ('Q6 多账号怎么隔离？',
         '存储键加账号后缀形成命名空间（local_records@alice），切换账号时整体切换；'
         '登录闸门保证未登录不渲染业务页，没有数据串台的窗口期。'),
        ('Q7 为什么不用云服务器？',
         '演示优先级：零依赖、加载快、预览器能跑全流程。但四端仓库齐全、网络层完整保留，'
         '是“可演示的单机版”，不是“只能单机”。'),
        ('Q8 深色模式怎么做的？',
         '不是反色是换血：主题刻度广播，静态色值组件订阅重建；玻璃材质深浅两套参数、'
         '三档画质降级；切换用统一 380 ms 曲线。'),
        ('Q9 动画会掉帧吗？',
         '三个手段：只用合成层属性；错峰入场；阴影改预合成。时长曲线全库收敛到 AppleMotion 一处。'),
        ('Q10 27 个因子哪来的？',
         '内置因子库，与后端 carbon.sql 种子一致，分出行 6、节电节水 6、回收 8、餐食 7 四类；'
         '演示种子只取低因子，避免首屏减排量失真。'),
        ('Q11 注册为什么强制完善资料？',
         '产品上昵称和性别是必填；工程上这是注册闸门要解决的竞态——资料页可能比主框架慢，'
         '所以先锁死主框架，等资料页真实上屏再解锁。'),
        ('Q12 这个项目你负责哪部分？',
         '（按实际分工改）我主要负责端侧架构与业务逻辑：账号系统、本地仓库、碳惠券包与注册闸门，'
         '以及液态玻璃和动效体系；后端与管理端由队友负责。'),
    ]
    for q, a in qa:
        h3(doc, q)
        p(doc, '答：' + a)

    h1(doc, '八、术语口头解释表（被问到就脱口而出）')
    table(doc,
          ['术语', '口头解释'],
          [['碳普惠', '把个人的低碳行为量化成积分，再换激励的机制'],
           ['CO2e', '二氧化碳当量，各种温室气体折成二氧化碳的统一计量'],
           ['减排因子', '做一次这种行为少排多少碳，比如骑行每公里 0.19 kg'],
           ['ArkTS / ArkUI', '鸿蒙的开发语言和界面框架，声明式，改数据界面自动更新'],
           ['NavDestination', '鸿蒙路由体系里的二级页面容器'],
           ['HAP', '鸿蒙应用的安装包'],
           ['Preferences', '鸿蒙的轻量键值存储，我们存账号和业务数据用它'],
           ['App-Token', '匿名登录后服务端发的“访客证”，之后每次请求都带它'],
           ['LWW', '后写覆盖，多设备同步时以更新时间戳新的为准'],
           ['TTL', '有效期，我们的券是领取后 7 天'],
           ['幂等', '同一笔重复提交多次，结果只算一次'],
           ['软总线', '鸿蒙设备之间互联的“数据高速公路”，超级终端靠它']],
          widths=[3.4, 10.4], size=10)

    h1(doc, '九、汇报流程建议')
    h2(doc, '9.1  五分钟版')
    bullet(doc, '0:00–0:30  电梯陈述（第一章）')
    bullet(doc, '0:30–2:30  业务主线 + 四个公式 + 现场算一笔（第三章，配图 4）')
    bullet(doc, '2:30–3:30  架构概览（图 1、图 3，各 30 秒）')
    bullet(doc, '3:30–4:30  一个技术亮点：注册闸门或核销二维码实测（第五章）')
    bullet(doc, '4:30–5:00  收尾：一句话总结 + 致谢')
    h2(doc, '9.2  十分钟版')
    p(doc, '在五分钟版基础上增加：功能模块走一遍（图 2，约 1.5 分钟）、接口与幂等（图 5，约 1 分钟）、'
           '测试与兼容性口径（构建通过、预览器与真机双口径，约 1 分钟），其余时间留给提问。')
    h2(doc, '9.3  讲之前最后一次自检')
    bullet(doc, '四个公式能默写吗？')
    bullet(doc, '“记一笔到核销”能不打绊子地讲完吗？')
    bullet(doc, '图 1 到图 6 每张能讲 30 秒吗？')
    bullet(doc, '12 个问题里挑 5 个自问自答过吗？')
    bullet(doc, '自己负责的部分（代码位置）能当场打开找到吗？')

    out = os.path.join(ROOT, '一触青绿_业务逻辑讲解稿.docx')
    doc.save(out)
    print('saved', out)
    return out


if __name__ == '__main__':
    build_design_doc()
    build_talk_doc()
    print('ALL DOCS DONE')
