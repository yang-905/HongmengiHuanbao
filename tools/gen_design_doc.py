# -*- coding: utf-8 -*-
"""
生成《一触青绿》正式设计方案文档（.docx）。
正文统一：宋体 / 小四号(12pt) / 1.5 倍行距 / 首行缩进 2 字符。
"""
from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn

PY = "C:/Users/坤坤/.workbuddy/binaries/python/envs/default/Scripts/python.exe"

# ---------------- 字体工具 ----------------
def set_run_font(run, name='宋体', size=None, bold=None, color=None):
    run.font.name = name
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = rPr.makeelement(qn('w:rFonts'), {})
        rPr.append(rFonts)
    rFonts.set(qn('w:ascii'), name)
    rFonts.set(qn('w:hAnsi'), name)
    rFonts.set(qn('w:eastAsia'), name)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold
    if color is not None:
        run.font.color.rgb = color

def style_normal(doc):
    # 默认正文样式：宋体 / 小四(12pt) / 1.5 倍行距 / 首行缩进 2 字符
    st = doc.styles['Normal']
    st.font.name = '宋体'
    st.font.size = Pt(12)
    st.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
    st.element.rPr.rFonts.set(qn('w:ascii'), '宋体')
    st.element.rPr.rFonts.set(qn('w:hAnsi'), '宋体')
    pf = st.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    pf.line_spacing = 1.5
    pf.first_line_indent = Pt(24)  # 2 字符 * 12pt
    pf.space_after = Pt(4)

def add_title(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(10)
    r = p.add_run(text)
    set_run_font(r, name='黑体', size=22, bold=True)
    return p

def add_subtitle(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(text)
    set_run_font(r, name='宋体', size=12, bold=False, color=None)
    return p

def add_chapter(doc, num, title):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(8)
    p.paragraph_format.keep_with_next = True
    r = p.add_run('第%s章 %s' % (num, title))
    set_run_font(r, name='黑体', size=16, bold=True)
    return p

def add_section(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(text)
    set_run_font(r, name='黑体', size=14, bold=True)
    return p

def add_sub(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(text)
    set_run_font(r, name='宋体', size=12, bold=True)
    return p

def add_body(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(24)
    r = p.add_run(text)
    set_run_font(r, name='宋体', size=12)
    return p

def add_bullet(doc, text):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.left_indent = Pt(24)
    p.paragraph_format.line_spacing = 1.5
    r = p.add_run(text)
    set_run_font(r, name='宋体', size=12)
    return p

def add_kv(doc, k, v):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(k + '：')
    set_run_font(r, name='宋体', size=12, bold=True)
    r2 = p.add_run(v)
    set_run_font(r2, name='宋体', size=12)
    return p

# ---------------- 构建文档 ----------------
doc = Document()
style_normal(doc)

# 页边距
sec = doc.sections[0]
sec.top_margin = Cm(2.54)
sec.bottom_margin = Cm(2.54)
sec.left_margin = Cm(3.18)
sec.right_margin = Cm(3.18)

# ===== 封面 =====
add_title(doc, '一触青绿')
add_subtitle(doc, '—— 个人碳足迹记录与碳积分激励应用 设计方案')
add_subtitle(doc, '（基于 OpenHarmony / HarmonyOS ArkTS 的液态玻璃 + 苹果动效实践）')
doc.add_paragraph()
add_kv(doc, '应用名称', '一触青绿（One Touch Green）')
add_kv(doc, '项目定位', '个人碳足迹记录与碳积分激励应用（四端工程：app / server / admin / db）')
add_kv(doc, '目标平台', 'OpenHarmony / HarmonyOS（API 24，compatibleSdkVersion 24）')
add_kv(doc, '开发语言', 'ArkTS / ArkUI（Stage 模型）')
add_kv(doc, '文档版本', 'v1.0')
add_kv(doc, '编制说明', '正文统一采用宋体、小四号字体、1.5 倍行距')

doc.add_page_break()

# ===== 目录（手动） =====
add_chapter(doc, '目', '录')
toc = [
    '第一章 作品设计思路',
    '第二章 功能需求与实现逻辑',
    '第三章 技术架构',
    '第四章 关键技术实现',
    '第五章 软硬件选型',
    '第六章 数据与安全设计',
    '第七章 测试结果',
    '第八章 总结与展望',
]
for t in toc:
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(t)
    set_run_font(r, name='宋体', size=12)
doc.add_page_break()

# ===================== 第一章 =====================
add_chapter(doc, '一、', '作品设计思路')
add_section(doc, '1.1 设计背景与愿景')
add_body(doc, '“一触青绿”是一款面向个人用户的碳足迹记录与碳积分激励应用，核心理念是“一触之间，青绿相随”。在“双碳”战略背景下，个人低碳行为（绿色出行、节能、回收、低碳饮食）长期处于“看不见、难量化、缺反馈”的状态。本作品把抽象的减排量转化为可感、可积累、可兑换的碳积分与城市权益，用一套统一的液态玻璃视觉语言与苹果级动效，让“随手记录低碳行为”成为顺滑、愉悦的日常动作。')
add_body(doc, '应用覆盖“记录—核算—激励—兑换—洞察”的完整闭环：用户记录四类低碳行为，系统按因子库核算减排量（kgCO₂e），按“1kg=10 分”结算积分，积分可兑换实体树木电子证书、城市碳普惠权益（碳惠券包），并通过数据看板与图表呈现日/周/月/年趋势与分类占比，辅以双碳科普、家庭碳账户、AI 图片识别、智慧服务与超级终端多设备同步，形成可持续的低碳生活激励生态。')

add_section(doc, '1.2 设计理念')
add_body(doc, '一是“一触即达”的交互减负：以底部液态玻璃胶囊 + 独立圆形「＋」悬浮按钮（FAB）承载全局行为录入入口，任何页面一键唤起半模态记录面板，把记录成本压到最低。二是“物理真实”的视觉表达：自研 GlassLight 液态玻璃光照模型，以单一 135° 主光源、四边菲涅尔亮边、α 预合成防脏，建立与 iOS Liquid Glass 同构的质感。三是“活的设计”动效语言：以 AppleMotion 统一全库时长阶梯、弹簧回弹、进场缩放与按压反馈，让每个出现与消失都具备物理重量。四是“自洽的明暗”：深色模式采用“换血”机制（重算 static 色值令牌），并与系统栏图标反色联动，深浅始终一致。')

add_section(doc, '1.3 用户画像与使用场景')
add_body(doc, '核心用户为关注环保与自我管理的城市人群，典型场景包括：通勤途中一键记录骑行/公交（出行类）、居家记录节电/回收（能源/回收类）、用餐记录低碳饮食（食物类）；积分攒到阈值后兑换电子植树证书或碳惠券包权益；周末在“我的”页查看年度减排量与等级树；家庭成员通过超级终端近场同步合并家庭减排。应用同时面向管理端（运营人员配置因子库、权益、任务、徽章、推荐规则）与后端（RuoYi 多用户体系 + 碳业务模块）。')

add_section(doc, '1.4 信息架构与导航范式')
add_body(doc, '主框架采用“四 Tab 一级页 + 全局路由栈二级页”结构：看板（Dashboard）、记录（Record）、科普（Article）、我的（Mine）四个一级页由底部胶囊承载；所有深层页面走 Navigation + NavPathStack 全局路由栈，不堆在 Tab 内。底部导航参考鸿蒙 7 与大疆 DJI MIMO 的“胶囊 + 圆钮”布局：主 Tab 页左侧 4 格胶囊（选中白玻璃药丸平移滑动）+ 右侧独立圆形「＋」FAB；进入二级页时胶囊“被吸进＋钮”退场，仅留右侧圆钮，点击仍弹出记录面板。这种布局让“记录”这一最高频动作在任何层级都触手可及。')

add_section(doc, '1.5 视觉语言与碳情绪体系')
add_body(doc, '视觉以“生态绿”为主色，并引入“碳情绪（EcoMood）”档位：依据当日/累计减排量动态切换背景与配色（none / 浅 / 中 / 深四档），让“今天环保做得好不好”一眼可辨，底部导航的选中色与 FAB 也跟随档位。深色模式不另起一套设计，而是对同一套色令牌执行“换血”，保证深浅两套观感连续、不会出现色阶跳变。')

# ===================== 第二章 =====================
add_chapter(doc, '二、', '功能需求与实现逻辑')
add_section(doc, '2.1 功能清单（按模块）')
add_body(doc, '应用共 63 个 ArkTS 源文件，功能按模块划分如下：')
add_bullet(doc, '碳行为记录：27 种低碳行为因子库，分 travel / energy / recycle / food 四类；减排量 = 数量 × 因子（保留 3 位小数，单位 kgCO₂e）；含行为录入半模态面板、行为详情、因子库浏览、AI 图片识别录入。')
add_bullet(doc, '积分与任务体系：1kg=10 分结算；每日任务状态机；10 枚徽章自动判定；积分商城、积分流水、任务中心、徽章墙、电子证书（200 积分兑换 1 棵树，证书编号 CF-yyyyMMddHHmmss）。')
add_bullet(doc, '碳惠券包：城市碳普惠 8 种权益兑换，新增 carbon_benefit 表，核销码 PT-…；含券列表、兑换确认与二维码核销凭证。')
add_bullet(doc, '数据看板与图表：看板 6 卡（stagger 依次落座）、趋势图（日/周/月/年）、分类占比分析；服务端时间桶聚合 + 补空桶。')
add_bullet(doc, '双碳科普：10 篇图文，含阅读量、点赞、收藏与答题测验。')
add_bullet(doc, '家庭碳账户：真实成员聚合、成员排行、分类汇总。')
add_bullet(doc, 'AI 图片智能识别：54 条关键词库 + 识别引擎 + 识别日志，识别结果采纳入账。')
add_bullet(doc, '智慧服务：个性化推荐（今日重点任务 + 生活建议规则引擎）。')
add_bullet(doc, '超级终端：基于软总线的多设备近场组网、一键同步记录与设备状态（不经服务器）。')
add_bullet(doc, '设置与账户：深色模式、数据备份管理、导出报告、月度账单、等级树、关于、生态调试面板、登录注册闸门。')

add_section(doc, '2.2 核心业务流程')
add_body(doc, '注册/登录闸门：登录或注册成功后，AccountStore 写入 AppStorage 会话态，主框架整体挂载；注册流程额外打“待完善资料”意图标记，主框架第一帧即锁死交互，待资料页真实上屏后延时解锁，杜绝“手快误触主页”。')
add_body(doc, '碳行为记录：用户从任意页面唤起行为录入面板 → 选择行为类型、填写数量 → 提交后按因子库核算减排量 → 写入本地队列并上云 → 积分账户与碳情绪档位实时重算。')
add_body(doc, '积分结算与兑换：减排量换算积分进入账户流水；积分达阈值可兑换电子证书或碳惠券包权益；券包兑换生成 PT- 核销码，线下/线上核销时校验并置失效。')
add_body(doc, '图表分析：看板与趋势页从服务端拉取时间桶聚合数据（已补空桶），端侧按日/周/月/年切换维度，分类占比以环/条形呈现。')

add_section(doc, '2.3 关键功能实现逻辑')
add_sub(doc, '2.3.1 碳足迹核算')
add_body(doc, '统一分类 key（travel / energy / recycle / food），废弃旧工程 water / plate；日汇总表 carbon_daily_stat 列名同步为 travel_kg / energy_kg / recycle_kg / food_kg；减排量 = 数量 × 因子，结果保留 3 位小数，单位 kgCO₂e。')
add_sub(doc, '2.3.2 积分与徽章')
add_body(doc, '积分账户与流水独立建模；任务定义增强 task_code / icon / target_type（times 次数或 amount 数量）/ target_value；徽章判定结构化（badge_def 用 metric / category / threshold 三字段），达到阈值自动解锁；证书编号按 CF-yyyyMMddHHmmss 生成。')
add_sub(doc, '2.3.3 碳惠券包核销')
add_body(doc, '城市碳普惠权益存于 carbon_benefit 表，兑换时生成 PT- 前缀核销码并在详情页以二维码呈现；核销动作校验码有效性并置失效，形成“发放—核销”闭环。')
add_sub(doc, '2.3.4 AI 识别与智慧服务')
add_body(doc, 'AI 识别原为端侧能力，本工程把识别引擎、推荐规则、设备编组“规则与数据上移至服务端”，端侧仅保留相机/软总线等强设备相关能力，便于管理端配置与跨端一致。')

# ===================== 第三章 =====================
add_chapter(doc, '三、', '技术架构')
add_section(doc, '3.1 总体架构（四端）')
add_body(doc, '仓库采用 RuoYi 四端规范，四个目录各司其职：app/ 为鸿蒙端（OpenHarmony ArkTS，API 24，Navigation 全局路由）；server/ 为后端服务（RuoYi-Vue 3.8.7，JDK 11，端口 8089，com.ruoyi.carbon 业务模块）；admin/ 为管理端前端（若依 Vue，carbon 业务页面与 API 封装）；db/ 为数据库脚本（若依基础表 + carbon 业务库）。鸿蒙端与后端以 /carbon/app/** 免登录开放接口通信，业务数据以源项目为唯一基准。')

add_section(doc, '3.2 端侧分层架构')
add_body(doc, '鸿蒙端按职责分为六层：UI 层（pages/ 业务页 + ui/ 视觉基建）、状态层（data/ 账户、碳情绪、本地存储、主题）、网络层（net/ ApiService、DataSource、HttpClient）、模型层（model/ CarbonModels）、公共层（common/ 常量与路由）、工具层（utils/ AppClock、SyncStore）。这种分层使“视觉—状态—数据—网络”解耦，视觉基建（GlassLight、AppleMotion）可独立演进。')

add_section(doc, '3.3 模块划分与依赖')
add_body(doc, 'ui/ 下核心模块：Theme.ets（颜色令牌）、GlassLight.ets（液态玻璃光照模型，1200+ 行）、GlassSurface.ets / GlassDialog.ets（玻璃面与覆盖层弹窗）、AppleMotion.ets（动效唯一来源）、Components.ets（CfButton / CfCard / CfListRow 等通用件）、Toast.ets、LazyList.ets。data/ 下：AccountStore（账号与会话）、EcoMoodState（碳情绪档位）、LocalStore（命名空间隔离存储）、ThemeMode（深色换血）、MockStore（预览器兜底）。net/ 与 model/ 负责接口契约与数据对象。')

add_section(doc, '3.4 状态管理与数据流')
add_body(doc, '采用 ArkUI 响应式体系：跨组件共享态走 AppStorage + @StorageProp / @StorageLink；组件内态走 @State；父→子单向数据流用 @Prop / @Link / @ObjectLink。关键技巧包括：static 色值令牌靠 @StorageProp(\'themeTick\') 订阅重建；路由栈变化以 400ms 低频轮询（pathStack.size() 为跨语言调用，过频占主线程）；多账号隔离通过“会话翻转→整棵 Navigation 卸载重建→各页 aboutToAppear 重跑读新命名空间”实现。')

add_section(doc, '3.5 路由设计')
add_body(doc, '全局路由基于 Navigation + NavPathStack，所有二级页统一在 PageMap / AppRouter 注册；Tab 切换不走 index 属性（改属性跳页不动画），而走 TabsController.changeIndex() 触发自定义内容转场。switchTab 把“药丸平移、文字高亮、整页滑动”三件事压进同一个 animateTo（300ms EaseInOut），整页位移只改 translate（纯合成层、不重建页面），动画期间主线程空闲，保证流畅。')

add_section(doc, '3.6 主题与玻璃体系')
add_body(doc, 'ThemePalette.applyDark(dark) 切换明暗，ThemeMode.bumpRender() 推 AppStorage(\'themeTick\') 触发全树重建。GlassLight 提供 surface() / orbAccentSurface() 等单方法：单层 135° 合成渐变（底色 + 左上白光 + 右下内阴影）替代“平涂 + 光照层”双层打架；悬浮控件用 PILL 档（无文字暗纱、菲涅尔更轻），内容面板用 PANEL 档；支持三档画质降级（quality）与滚动视差（glassParallax），并区分 GlassLevel.LIVE / SOLID。')

add_section(doc, '3.7 动效体系')
add_body(doc, 'AppleMotion 是全库动效唯一来源，与 Theme / GlassLight 平行。它定义时长阶梯（按压 100ms / 微交互 200ms / 标准 350ms / 大面板 500ms / 主题 380ms）、曲线语义（进场 EaseOut、退场 EaseIn、过渡 EaseInOut、摩擦 Friction）、弹簧工厂（spring / springSnappy / springHeavy，返回 curves.ICurve）、进场缩放（ENTER_SCALE=0.92）、按压缩放（PRESS_SCALE=0.96）与 stagger（min(260, index*30)）。所有页面/组件从此取参，禁止硬编码时长与曲线。')

# ===================== 第四章 =====================
add_chapter(doc, '四、', '关键技术实现')
add_section(doc, '4.1 注册引导误触闸门（零帧锁死）')
add_body(doc, '问题：注册成功 → 主框架可见 → Navigation.onAppear 才 push 资料页，这段转场空窗期主页完全可点，手快会误触。方案为三段式：① 预置——注册意图标记在 register() 之前落，onSessionUser（@Watch，早于重建）读到即把闸门拉起，主框架第一帧即锁死；② 保持——Navigation.onAppear 里 push 前再置一次兜底；③ 解除——资料页真实上屏（ProfilePage 根节点 onAppear）后延 420ms 解锁，避开 push 滑入动画。闸门用“普通字段存真值 + @State tick 触发重渲染”实现零帧延迟，并设 4s 兜底防永久锁死。')

add_section(doc, '4.2 液态玻璃光照模型')
add_body(doc, 'GlassLight 以单一左上 45°（135° 对角轴）主光源建立厚度与方向感：受光边冷白、背光边深色，形成四边异色描边（菲涅尔亮边）。关键实现细节：① α 预合成防止停靠点之间插出灰色带；② 浮控件走 PILL 档避免 PANEL 的文字暗纱把小胶囊糊成脏灰；③ backdropBlur 每层创建离屏渲染，同一区域只保留一层（胶囊与 FAB 不相交），并对挂模糊的面板做 scale 时克制幅度（≤8%）防掉帧；④ 阴影每帧重绘，已在滑动药丸等处去除投影保性能。')

add_section(doc, '4.3 苹果动效语言落地')
add_body(doc, '统一时长曲线弹簧后，补上 iOS 标志动作：进场缩放（0.92→1，模拟从指尖弹出）与按压反馈（按下 100ms 缩 96%、抬起弹簧回弹）。踩坑点：① curves.springMotion 返回 ICurve 而非 Curve 枚举，不能互赋值；② 物理弹簧在预览器上对 opacity 0→1 可见性动画会卡死在初值（弹窗只剩遮罩），故可见性动画统一改用确定性过冲贝塞尔 springLike（cubicBezier(0.34,1.56,0.64,1)），真机/预览器表现一致；③ 常显元素（按压缩放回弹、Tab 选中放大）才用物理弹簧。')

add_section(doc, '4.4 深色模式换血机制')
add_body(doc, 'ThemeMode.applyDark(dark) + bumpRender() 推 themeTick，各页 @StorageProp(\'themeTick\') 订阅后重算 static 色值令牌，实现“换血”而非“叠色”。系统栏通过 attachWindow 透明化背景 + 按实际主题反色下发图标色（避免“深色界面 + 深色状态栏图标看不见”）。module.json5 声明 colorMode=auto 跟随系统；onConfigurationUpdate 在用户未手动锁定时实时跟随系统切换。预览器不跑 UIAbility 生命周期，由 Index 的 aboutToAppear 补播 themeTick 键，保证深色链路不断。')

add_section(doc, '4.5 系统时钟本地校准')
add_body(doc, 'AppClock.now() / today() / dateStr() 全部基于 Date.now() 本地取时，避免依赖服务端时区导致的日/周/月/年边界错位；回到前台（onForeground）重新判档，防止跨天后沿用昨天的碳情绪档位。')

add_section(doc, '4.6 覆盖层弹窗范式')
add_body(doc, '覆盖层弹窗采用“普通 @Component + 宿主 Stack 挂载”而非 @CustomDialog：实测 @CustomDialog 在预览器会触发原生崩溃（0xc0000005）。GlassDialog 在宿主 Stack 内以条件渲染承载遮罩 + 玻璃面板，进场用弹簧 + 0.92 缩放进场；并规避“三元 .animation(visible?{…}:{…})”同帧竞争（取消后再开丢失入场），改为静态 .animation({curve: AppleMotion.spring()})。')

add_section(doc, '4.7 超级终端分布式同步')
add_body(doc, '基于鸿蒙软总线（DISTRIBUTED_DATASYNC 权限）实现近场组网，一键同步记录与设备状态，全程不经过任何服务器。总开关 AppConfig.DISTRIBUTED_SYNC 控制是否申请权限与组网，关闭时退化为纯单机模式，行为与原生一致。')

# ===================== 第五章 =====================
add_chapter(doc, '五、', '软硬件选型')
add_section(doc, '5.1 开发环境')
add_bullet(doc, 'IDE：DevEco Studio（HarmonyOS SDK API 24）。')
add_bullet(doc, '构建：hvigor（assembleHap 产出 HAP），Gradle-like 声明式构建。')
add_bullet(doc, '语言与框架：ArkTS / ArkUI（Stage 模型、Navigation 路由）。')
add_bullet(doc, '后端：JDK 11、Maven、RuoYi-Vue 3.8.7（Spring Boot + MyBatis）。')
add_bullet(doc, '数据：MySQL 8、Redis（缓存/分布式会话）。')
add_bullet(doc, '管理端：若依 Vue 前端。')

add_section(doc, '5.2 运行环境与目标设备')
add_bullet(doc, '目标设备类型：default（手机）、tablet（平板）。')
add_bullet(doc, '兼容 SDK 版本：compatibleSdkVersion = 24，compileSdkVersion = 24。')
add_bullet(doc, '后端服务端口：8089；鸿蒙端联调模拟器基址 http://10.0.2.2:8089。')

add_section(doc, '5.3 关键技术栈与自建库')
add_bullet(doc, '官方：ArkUI 声明式组件、Navigation、NavPathStack、animateTo、TransitionEffect、curves.springMotion。')
add_bullet(doc, '后端：RuoYi 多用户权限体系、状态机、日汇总表。')
add_bullet(doc, '自研：GlassLight（液态玻璃光照模型）、AppleMotion（苹果动效语言）、Theme/ThemeMode（深浅换血）、EcoMoodState（碳情绪档位）。')

add_section(doc, '5.4 选型依据与权衡')
add_body(doc, '选择 OpenHarmony/HarmonyOS 是因为其原生分布式能力（软总线）天然契合“超级终端多设备同步”诉求，且 ArkUI 声明式 + 自定义光照/动效能支撑高质感视觉。后端沿用 RuoYi-Vue 是因为其成熟的多用户、鉴权、代码生成体系可快速搭建碳业务后台，且管理端开箱即用。视觉基建（GlassLight / AppleMotion）自研而非套组件库，是为了把“离屏模糊层控制、弹簧曲线、菲涅尔描边”等性能与质感细节完全可控，避免通用组件库在预览器/真机表现不一致。')

# ===================== 第六章 =====================
add_chapter(doc, '六、', '数据与安全设计')
add_section(doc, '6.1 数据模型')
add_body(doc, 'carbon 业务库在若依基础表之上扩展：carbon_daily_stat（travel_kg / energy_kg / recycle_kg / food_kg 日汇总）、carbon_benefit（城市碳普惠权益 + 核销码）、badge_def（metric / category / threshold 结构化徽章定义）、task_def（task_code / icon / target_type / target_value）、carbon_certificate（CF 编号电子证书）、因子库（四大类 27 种）、家庭账户与设备编组等。')

add_section(doc, '6.2 本地存储')
add_body(doc, '使用 Preferences 持久化，文件名 yichu_qinglv；本地存储键涵盖 App-Token、用户 ID、设备匿名标识、昵称、因子库缓存、离线待同步队列、最近同步时间等。LocalStore 按账号切命名空间，保证多账号数据隔离；预览器不可用 Preferences 时由 MockStore 兜底。')

add_section(doc, '6.3 多账号数据隔离')
add_body(doc, '登录/注销/切换账号触发会话翻转，整棵 Navigation 卸载重建，各页 aboutToAppear 重跑，读到新账号命名空间的 LocalStore——隔离机制即“组件树重建”。会话善后统一在 onSessionUser 处理：复位 Tab 簿记与位移、清底部导航/删除条/FAB 标记、清空路由栈记录、按新账号重算碳情绪，防止旧会话残留导致白屏或错位。')

add_section(doc, '6.4 鉴权与安全')
add_body(doc, '后端以 App-Token 请求头（TOKEN_HEADER=\'App-Token\'）鉴权；/carbon/app/** 为免登录开放接口，供 App 直接调用；请求超时 10s。敏感操作（如核销）需校验码有效性与归属；因子库、权益、任务、徽章、推荐规则均可在管理端配置，服务端化为唯一数据源。')

add_section(doc, '6.5 离线优先与同步')
add_body(doc, '行为记录先写入本地 pending_records 队列并打 last_sync_time，联网后批量上云；弱网/离线不影响记录体验。超级终端场景则走软总线近场同步，记录与设备状态在组网设备间直传，不经过中心服务器，兼顾隐私与实时性。')

# ===================== 第七章 =====================
add_chapter(doc, '七、', '测试结果')
add_section(doc, '7.1 构建验证')
add_body(doc, '每轮改造后均执行 hvigorw assembleHap --no-daemon 构建，结果 BUILD SUCCESSFUL；HAP 产物时间戳晚于源码，确认编译切实生效；全程零新增编译警告（仅 AiVisionRecognizer 存在历史 syscap 告警，非阻塞）。')

add_section(doc, '7.2 功能走查')
add_body(doc, '八大功能模块（碳记录、积分任务、碳惠券包、看板图表、科普、家庭账户、AI 识别、智慧服务、超级终端）均按业务流程走查：注册登录闸门、行为录入与核算、积分结算与证书、券包兑换与核销、趋势/占比切换、科普阅读收藏答题、家庭合并、AI 识别入账、智慧推荐、近场同步均验证可达预期。')

add_section(doc, '7.3 流畅性 / 性能优化结果')
add_bullet(doc, 'backdropBlur 离屏层控制：同一区域只保留一层模糊，胶囊与 FAB 互不交叠，避免滑动掉帧。')
add_bullet(doc, '位移走 translate 纯合成层：Tab 整页滑动只改 translate，不触发布局重排，页面不重建，动画期间主线程空闲。')
add_bullet(doc, '同帧 animateTo 统一驱动：药丸/高亮/整页滑动同一段动画同帧同曲线起止。')
add_bullet(doc, 'stagger 仅限看板 6 卡：长列表只做整体淡入，避免一屏十几项弹簧同时跑导致掉帧。')
add_bullet(doc, '去除每帧重绘的阴影：滑动药丸等高频移动件去掉 shadow，显著降低卡顿。')

add_section(doc, '7.4 兼容性验证')
add_body(doc, '覆盖 default（手机）与 tablet（平板）两种设备类型；在预览器与真机两条路径验证；深色/浅色两套主题、跟随系统切换均验证一致；覆盖层弹窗在预览器与真机均正常弹出（规避了 @CustomDialog 原生崩溃）。')

add_section(doc, '7.5 动效修复验证')
add_bullet(doc, '注册闸门：资料页盖住屏幕前主框架锁死，杜绝手快误触子页面。')
add_bullet(doc, '弹窗入场：修复“取消后再点丢失入场动画”的同帧三元 animation 竞态，改为静态 spring 动画。')
add_bullet(doc, '二级页面：26 个 NavDestination 二级页统一补上“淡入 + 上浮”入场动画。')
add_bullet(doc, '底部导航：胶囊退场/返场、FAB 显隐均改为补间动画（非 visibility 秒切），并与删除条同槽位接班。')

add_section(doc, '7.6 遗留问题与风险')
add_body(doc, 'AiVisionRecognizer 存在历史 syscap 告警（非阻塞，不影响构建与运行）；可见性动画在预览器需以 springLike 确定性贝塞尔替代物理弹簧（已规避）；路由栈变化依赖 400ms 低频轮询，极端快速进出场景下感知略有延迟。上述项均不影响主体功能，列入后续优化。')

# ===================== 第八章 =====================
add_chapter(doc, '八、', '总结与展望')
add_section(doc, '8.1 项目创新点')
add_bullet(doc, '自研 GlassLight 液态玻璃光照模型：单一 135° 主光源 + 菲涅尔亮边 + α 预合成，性能可控。')
add_bullet(doc, '统一苹果动效语言 AppleMotion：时长阶梯、弹簧回弹、进场缩放、按压反馈全库一致。')
add_bullet(doc, '深色“换血”机制：static 色令牌重建 + 系统栏反色联动，深浅自洽。')
add_bullet(doc, '注册引导零帧闸门：预置意图标记 + 真实上屏解锁，彻底消除首屏误触。')
add_bullet(doc, '完整四端工程：鸿蒙端 + RuoYi 后端 + 管理端 + 数据库，并把 AI/智慧/超级终端服务端化。')

add_section(doc, '8.2 不足之处')
add_body(doc, '预览器对物理弹簧的可见性动画存在卡死缺陷，需以确定性贝塞尔绕过；路由栈变化仍以轮询感知，实时性有上限；部分高频交互的离屏模糊仍有进一步 GPU 合成优化的空间；AI 识别 syscap 告警待澄清。')

add_section(doc, '8.3 后续规划')
add_body(doc, '一是真机全量回归与功耗/流畅度专项调优；二是把更多动画迁移到 GPU 合成层，进一步降低主线程占用；三是扩充低碳场景因子库与城市碳普惠真实权益对接；四是完善家庭与超级终端的多设备协同体验。总体而言，“一触青绿”已具备从原型走向可运营产品的完整骨架，后续将聚焦于体验打磨与生态对接。')

# 落款
doc.add_paragraph()
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
p.paragraph_format.first_line_indent = Pt(0)
r = p.add_run('—— 一触青绿 设计团队')
set_run_font(r, name='宋体', size=12)

OUT = r'D:\11\carbon-master\一触青绿_设计方案.docx'
doc.save(OUT)
print('SAVED ->', OUT)
