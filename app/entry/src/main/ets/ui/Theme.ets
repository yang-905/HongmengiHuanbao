/**
 * 设计令牌：淡绿奶油风
 * ------------------------------------------------------------------
 * 风格定位：年轻化、低饱和、通透奶油底 + 薄荷绿主色，
 *           弱化后台感，强化消费级 App 的亲和力。
 * 所有页面统一从此处取色与取圆角，禁止在页面里硬编码色值。
 *
 * 深色模式（重要架构说明）：
 * ------------------------------------------------------------------
 * 色值类（Brand / Neutral / Accent / EcoMood / Glass / Shadow）全部是
 * **可变 static 字段**，初值即浅色套值。ThemePalette.applyDark(dark)
 * 在启动时与设置页切换时整组换血，调用点零改动。
 * 为什么用可变 static 而不是两套常量类：
 *   1) 全库约 1000 处调用点，两套类要改每一处引用的类名；
 *   2) ArkTS 的 static 字段本身非响应式 —— 换血后必须由
 *      ThemeMode.bumpRender() 推进 AppStorage('themeTick')，
 *      各页面 @StorageProp('themeTick') 订阅后重建 build()，
 *      重新读取 static 字段，新配色才会上屏。
 * Radius / Space / FontSize / Chart / Biz 与颜色无关，保持 readonly。
 */

/**
 * 主题明暗控制中心（深色模式唯一换血处）
 * ------------------------------------------------------------------
 * applyDark(dark) 重写所有可变色值令牌；dark 为 false 时恢复浅色套值。
 * 生命周期：
 *   ThemeMode.init()（启动读盘）→ applyDark(持久化值)
 *   设置页开关            → applyDark(新值) + ThemeMode.bumpRender()
 */
export class ThemePalette {
  /** 当前是否深色模式（GlassLight 等光照计算据此分支） */
  static dark: boolean = false;

  /** 切换明暗：整组换血所有可变色值令牌 */
  static applyDark(dark: boolean): void {
    ThemePalette.dark = dark;
    if (dark) {
      ThemePalette.applyDarkValues();
    } else {
      ThemePalette.applyLightValues();
    }
  }

  /* ==================== 深色套值 ==================== */

  private static applyDarkValues(): void {
    /* 品牌：薄荷绿在深色底上略提亮，保持辨识度 */
    Brand.PRIMARY = '#4ECBA9';
    Brand.PRIMARY_DEEP = '#63D3B6';
    Brand.PRIMARY_LIGHT = '#7FD9C4';
    Brand.PRIMARY_PALE = 'rgba(63,191,159,0.16)';
    Brand.PRIMARY_MIST = 'rgba(63,191,159,0.18)';
    /* 启动页：浅色薄荷渐变 → 深色深墨渐变（文字用深色套值，必须配深底）
     * ⚠️ 同 *_SOLID：启动页是全屏渐变，饱和度决定第一印象，
     *   原 (13,21,18)→(21,46,39) 偏绿，现压到近中性墨色。 */
    Brand.SPLASH_FROM = '#0E1312';
    Brand.SPLASH_TO = '#1C2523';

    /* 中性色：奶油白 → 深炭（带一点冷绿调，与薄荷主色同族）
     * ⚠️ 本轮去饱和（用户反馈「全局深色要这种效果」）：
     *   取证（深色记录页截图）：卡片内实测 #1C3934，**饱和度 0.51**，
     *   页面底 #122822 饱和度 0.55 —— 这是饱和的森林绿，不是深色玻璃。
     *   根因在 *_SOLID：它们照抄了浅色档「淡薄荷」的色相身份，
     *   但把 alpha 提到 1.0 之后，浅色里几乎察觉不到的绿相
     *   在深色底上被放大成整屏的绿。
     *   玻璃的材质感来自「中性暗面 + 极轻冷调」，绿相应该来自
     *   品牌与碳情绪，**不该由中性底色提供**。现把中性色相拉回冷灰，
     *   绿意交给玻璃的白色微染与碳情绪四档。
     */
    Neutral.BG = '#141A18';
    Neutral.CARD = '#1E2523';
    Neutral.SURFACE = '#252D2A';
    // 主文字深色用纯白（用户指令「深色模式下都替换成白色，仅深色为白」；
    // 此前 #E9F0ED 近白，压深玻璃上偶发仍显发灰）
    Neutral.TEXT = '#FFFFFF';
    /*
     * ⚠️ TEXT_SUB / TEXT_MUTED 本轮提亮（取证：深色 ALERT 档副标题对比度 1.00:1）。
     *
     * 现象：深色模式下「我的」页列表副标题（家庭多设备在线与同步 /
     * 成员合并统计与减排排行…）几乎看不见。
     *
     * 实测（截图逐像素，分位取文字笔画 / 中位取卡片底）：
     *   副标题 Neutral.TEXT_MUTED  vs  卡片底 #3B2C29 = **1.00:1**（完全隐形）
     *   主标题 Neutral.TEXT(#E9F0ED) vs  同底        = 7.85:1（清晰）
     *
     * 根因：这两个次级色是按**冷灰绿底**（#182421，ALERT 档的 NONE_SOLID）
     * 调的，而截图所在页面是 **ALERT 档**：*_SOLID 换成暖棕红（#2A1C1A）、
     * 卡片再叠一层暖调 → 底色整体偏暖偏红。
     * 冷调灰字压在暖调底上，Rec.709 亮度几乎相等 → 对比度归零。
     * 即：**次级文字色假定「背景恒为中性」，没考虑碳情绪会把底色染成暖色**。
     *
     * 现把两个次级色整体提亮并微微加暖：
     *   TEXT_SUB   #9DB1AC → #B4C4BF（更亮，且带一点中性绿避免脏绿）
     *   TEXT_MUTED #74847E → #9AA8A3（提亮约 1.5 级）
     * 实算 ALERT 暖底上副标题升到 3.9:1（弱文需 ≥3），主副层级仍清晰可分。
     */
    // 本轮再提亮一档（用户反馈深色下次级文字依旧偏暗，圈选副标题）：
    //   TEXT_SUB   #B4C4BF → #C7D7D2
    //   TEXT_MUTED #9AA8A3 → #AEBEB8
    Neutral.TEXT_SUB = '#C7D7D2';
    Neutral.TEXT_MUTED = '#AEBEB8';
    Neutral.BORDER = '#3A4340';
    Neutral.INK = '#0B1211';

    /* 语义色：主色微提亮；浅底(_BG)改为同色系 18% 深色半透明，
     * 保证「彩色标签底 + 浅色文字」在深色页面里可读 */
    Accent.TRAVEL = '#5CC2CE';
    Accent.TRAVEL_BG = 'rgba(79,184,196,0.18)';
    Accent.ENERGY = '#E8B268';
    Accent.ENERGY_BG = 'rgba(224,164,88,0.18)';
    Accent.RECYCLE = '#7FCB95';
    Accent.RECYCLE_BG = 'rgba(111,192,138,0.18)';
    Accent.FOOD = '#F0998C';
    Accent.FOOD_BG = 'rgba(232,139,126,0.18)';
    Accent.SUCCESS = '#5CBD8B';
    Accent.SUCCESS_BG = 'rgba(76,175,125,0.18)';
    Accent.WARNING = '#E8B268';
    Accent.WARNING_BG = 'rgba(224,164,88,0.18)';
    Accent.DANGER = '#EC8B83';
    Accent.DANGER_BG = 'rgba(224,115,107,0.18)';
    Accent.INFO = '#74AEE0';
    Accent.INFO_BG = 'rgba(91,155,213,0.18)';

    /*
     * 碳情绪四档深色适配（核心：情绪化反馈的深色版）
     * ------------------------------------------------------------------
     * 浅色档的情绪语言 = 「越超阈，页面越暖越亮」；
     * 深色档反过来 = 「越超阈，页面越暖越沉」——
     * 底色换成深色调染（保持色相身份：薄荷/青绿/麦黄/珊瑚），
     * 强调色(ACCENT)整体提亮，保证深底上的文字对比度。
     * FROM/TO 保持浅色套值不变：它们是 Hero 大卡与按钮的实底渐变，
     * 深色页面上「一块活的彩色」正是情绪反馈的视觉锚点。
     *
     * ⚠️ *_SOLID 本轮去饱和（取证：卡片实测饱和度 0.51、绿得发闷）：
     *   四个 *_SOLID 是 @Entry 根底实色，会**填满整屏**——它们的
     *   饱和度直接决定全屏基调。原先照抄浅色淡薄荷的色相
     *   （#122822 饱和度 0.55），在深色底上被放大成森林绿。
     *   现统一压到 0.30~0.38：仍能看出「这一屏是哪个情绪」，
     *   但绿/暖色只作为**色相倾向**存在，不再是实打实的绿。
     *   玻璃的白染与 Hero 渐变负责提供真正的彩色。
     */
    // ⚠️ 正向碳情绪 v2 口径（用户重构指令）：减排越多界面越轻盈，
    // 档位语义反转 —— eco=荧光绿(目标达成) / good=黄绿 / warn=暖黄 / none=灰(静默)。
    // alert 表保留但 level() 不再返回（旧「排放超标=红色」方向废弃）。
    EcoMood.ECO_BG = 'rgba(20,44,28,0.62)';
    EcoMood.ECO_ACCENT = '#4ADE80';
    EcoMood.ECO_SOLID = '#142C1C';
    EcoMood.GOOD_BG = 'rgba(36,44,24,0.62)';
    EcoMood.GOOD_ACCENT = '#B5D98A';
    EcoMood.GOOD_SOLID = '#242C18';
    EcoMood.WARN_BG = 'rgba(46,40,24,0.62)';
    EcoMood.WARN_ACCENT = '#EAC78D';
    EcoMood.WARN_SOLID = '#2E2818';
    EcoMood.ALERT_BG = 'rgba(47,30,28,0.62)';
    EcoMood.ALERT_ACCENT = '#F2A49D';
    EcoMood.ALERT_SOLID = '#2A1C1A';
    EcoMood.NONE_BG = 'rgba(20,26,24,0.62)';
    EcoMood.NONE_SOLID = '#141A18';
    // NONE_ACCENT 浅色时引用 Neutral.TEXT_SUB，深色时须重新绑定
    EcoMood.NONE_ACCENT = Neutral.TEXT_SUB;

    /* 玻璃：白玻璃 → 深色半透明玻璃；边缘高光收敛（深色玻璃上
     * 0.75 的白边会变成一条刺眼的亮线，0.14 才是有厚度的暗玻璃） */
    /*
     * ⚠️ 深色玻璃底色口径在本轮推翻重做（用户要求「兼容液态玻璃深色模式」）。
     *
     * 原方案用**深色染色** rgba(28,37,35,0.86) 做玻璃底 —— 这是错的：
     *   · DARK_TINT (23,36,34) 与之几乎同色 → 玻璃面 = 页面底色，玻璃「消失」；
     *   · 暗底上唯一的层次线索是内阴影与描边，于是只能把内阴影拉到 0.153
     *     （浅色才0.02）→ 右下角一大块脏暗角，深色下比浅色更严重。
     *
     * 苹果深色 Liquid Glass 的正确做法是**白色微染**：暗背景上玻璃靠
     *「比背景亮一点」浮起来，而不是靠阴影压暗。
     * 实算（叠在页面底 #111917 = (17,25,23) 上）：
     *   rgba(255,255,255,0.07) → (34,42,39)，比底亮 17 级，卡片浮得起来；
     *   且Neutral.TEXT #E9F0ED 压在上面对比度仍 > 10:1，可读性无损。
     * 玻璃厚度改由「高权重边缘光 + 极轻内阴影」承担，不再靠大片暗部。
     */
    Glass.CARD_BG = 'rgba(255,255,255,0.07)';
    /*
     * ⚠️ 深色 0.62 → 0.26（真透明）：用户反馈「你只是让白条向下了，
     * 不是真透明」。0.62 的深色染色层本身就是一条不透明的实体带 ——
     * 无论底色是浅色白还是深色黑，只要染色层够实，玻璃就退化成
     * 一块半透明塑料板。
     * 苹果 Liquid Glass 在深色背景上也是这样：玻璃面几乎不可见，
     * 靠的是**边缘光 + 折射 + 背景透出来的内容**，而不是一层实色。
     * 0.26 只够托住文字对比度（TAB 文字 TEXT_MUTED 在深底上仍清晰），
     * 其余全交给 backdropBlur 透出真实内容。
     */
    Glass.BOTTOM_BAR_BG = 'rgba(255,255,255,0.05)';
    Glass.PILL_BG = 'rgba(255,255,255,0.11)';
    Glass.TOPBAR_BG = 'rgba(255,255,255,0.06)';
    Glass.PANEL_LIVE_BG = 'rgba(255,255,255,0.06)';
    Glass.SEGMENT_TRACK_BG = 'rgba(255,255,255,0.07)';
    Glass.DISC_BG = 'rgba(255,255,255,0.09)';
    /* 徽标实底：深色下比渐变两端略亮，圆盘才浮得出来（环用亮薄荷定义边缘） */
    Glass.DISC_SOLID_BG = '#22322E';
    Glass.EDGE = 'rgba(236,244,246,0.14)';
    Glass.HIGHLIGHT = 'rgba(236,244,246,0.18)';

    /* 投影：深色底上黑投影几乎不可见，加深一档建立层次 */
    Shadow.cardColor = '#0F000000';
    Shadow.cardOffsetY = 0;
    Shadow.brandColor = 'rgba(63,191,159,0.22)';
    Shadow.raisedColor = '#2B000000';
    Shadow.raisedOffsetY = 8;
  }

  /* ==================== 浅色套值（与各类字段初值一致） ==================== */

  private static applyLightValues(): void {
    Brand.PRIMARY = '#3FBF9F';
    Brand.PRIMARY_DEEP = '#2A9E82';
    Brand.PRIMARY_LIGHT = '#7FD9C4';
    Brand.PRIMARY_PALE = '#E4F6F0';
    Brand.PRIMARY_MIST = 'rgba(63,191,159,0.14)';
    Brand.SPLASH_FROM = '#E4F6F0';
    Brand.SPLASH_TO = '#7FD9C4';

    Neutral.BG = '#FBF8F3';
    Neutral.CARD = '#FFFFFF';
    Neutral.SURFACE = '#F6F3EE';
    Neutral.TEXT = '#2E3A36';
    Neutral.TEXT_SUB = '#6B7A75';
    Neutral.TEXT_MUTED = '#A3AEA9';
    Neutral.BORDER = '#EDE8E1';
    Neutral.INK = '#24322E';

    Accent.TRAVEL = '#4FB8C4';
    Accent.TRAVEL_BG = '#E4F4F6';
    Accent.ENERGY = '#E0A458';
    Accent.ENERGY_BG = '#FBF0DF';
    Accent.RECYCLE = '#6FC08A';
    Accent.RECYCLE_BG = '#E6F5EB';
    Accent.FOOD = '#E88B7E';
    Accent.FOOD_BG = '#FCEAE7';
    Accent.SUCCESS = '#4CAF7D';
    Accent.SUCCESS_BG = '#E3F4EA';
    Accent.WARNING = '#E0A458';
    Accent.WARNING_BG = '#FBF0DF';
    Accent.DANGER = '#E0736B';
    Accent.DANGER_BG = '#FBE8E6';
    Accent.INFO = '#5B9BD5';
    Accent.INFO_BG = '#E6F0F9';

    EcoMood.ECO_BG = 'rgba(242,251,247,0.62)';
    EcoMood.ECO_ACCENT = '#2A9E82';
    EcoMood.ECO_SOLID = '#F2FBF7';
    EcoMood.GOOD_BG = 'rgba(244,250,243,0.62)';
    EcoMood.GOOD_ACCENT = '#3E9A78';
    EcoMood.GOOD_SOLID = '#F4FAF3';
    EcoMood.WARN_BG = 'rgba(253,248,239,0.62)';
    EcoMood.WARN_ACCENT = '#C4863A';
    EcoMood.WARN_SOLID = '#FDF8EF';
    EcoMood.ALERT_BG = 'rgba(253,243,241,0.62)';
    EcoMood.ALERT_ACCENT = '#C4554C';
    EcoMood.ALERT_SOLID = '#FDF3F1';
    EcoMood.NONE_BG = 'rgba(251,248,243,0.62)';
    EcoMood.NONE_SOLID = '#FBF8F3';
    EcoMood.NONE_ACCENT = Neutral.TEXT_SUB;

    Glass.CARD_BG = 'rgba(255,255,255,0.72)';
    Glass.BOTTOM_BAR_BG = 'rgba(255,255,255,0.12)';
    Glass.PILL_BG = 'rgba(255,255,255,0.42)';
    Glass.TOPBAR_BG = 'rgba(255,255,255,0.50)';
    Glass.PANEL_LIVE_BG = 'rgba(255,255,255,0.50)';
    Glass.SEGMENT_TRACK_BG = 'rgba(255,255,255,0.38)';
    Glass.DISC_BG = 'rgba(255,255,255,0.52)';
    Glass.DISC_SOLID_BG = '#FFFFFF';
    Glass.EDGE = 'rgba(255,255,255,0.52)';
    Glass.HIGHLIGHT = 'rgba(255,255,255,0.60)';

    Shadow.cardColor = '#03000003';
    Shadow.cardOffsetY = 0;
    Shadow.brandColor = '#3FBF9F47';
    Shadow.raisedColor = '#0C000014';
    Shadow.raisedOffsetY = 6;
  }
}

/**
 * 当前是否深色模式（供组件 td() 主题钩子间接读取）。
 * ------------------------------------------------------------------
 * 为什么需要这个函数：组件的 td() 恒等钩子要读 `ThemePalette.dark`
 * 静态字段，但依赖注入脚本（tools/theme_dep_wrap.py）会把 struct 体内
 * 裸读的 `ThemePalette.dark` 也包上 this.td() —— 那会让 td() 自己调
 * 自己形成无限递归。经本函数中转后，td() 体内不再出现裸 token，
 * 脚本重跑也安全。本文件是色值库自身，被脚本排除在包装范围外。
 */
export function isDarkMode(): boolean {
  return ThemePalette.dark
}

/** 品牌主色（薄荷绿，低饱和不刺眼） */
export class Brand {
  /** 主色：用于强调、选中态、主按钮 */
  static PRIMARY: string = '#3FBF9F';
  /** 主色深：文字/图标强调 */
  static PRIMARY_DEEP: string = '#2A9E82';
  /** 主色浅：渐变尾色 */
  static PRIMARY_LIGHT: string = '#7FD9C4';
  /** 主色极浅：背景填充 */
  static PRIMARY_PALE: string = '#E4F6F0';
  /** 主色淡雾：卡片阴影染色 */
  static PRIMARY_MIST: string = 'rgba(63,191,159,0.14)';
  /** 启动页渐变起色（浅色=薄荷 Pale；深色换深墨绿，见 ThemePalette） */
  static SPLASH_FROM: string = '#E4F6F0';
  /** 启动页渐变尾色（浅色=薄荷 Light；深色换深青绿，见 ThemePalette） */
  static SPLASH_TO: string = '#7FD9C4';
}

/**
 * 输入控件令牌（TextInput / TextArea / Search）
 * ------------------------------------------------------------------
 * 独立成类的原因（用户反馈「数量输入框不明显，用户无法一眼看见这里输入数值」）：
 *   输入框是**唯一需要用户主动识别并点击**的控件，
 *   但它原先只写了 `.backgroundColor(Neutral.SURFACE)`，
 *   既没有描边、也没设 placeholderColor —— 而 ArkUI 的 placeholder
 *   默认取系统灰，在本项目的米色/深色底上都几乎隐形。
 *
 * 取证（截图逐像素 + WCAG 反解）：
 *   placeholder / 输入框底 = **1.09:1**（需 ≥4.5）
 *   "数量"标签 / 面板底   = **1.06:1**
 *   输入框底 / 面板底     = 2.90:1（框体轮廓勉强可见）
 * 即：用户既看不见提示文字，也很难看出这里有个可输入的框。
 *
 * 三条设计约束（缺一不可）：
 *   ① 框体描边要比普通卡片边框更明确 —— 卡片是「看」，输入框是「操作」，
 *      必须一眼区分；
 *   ② placeholder 用 TEXT_SUB 而非 TEXT_MUTED：既保持"这是提示不是内容"
 *      的层级语义，又满足可读性下限；
 *   ③ 深浅两套都必须达标 —— 上一版的问题正是只在深色下暴露。
 */
export class InputField {
  /** 输入框底色：比面板底更明确的一层「凹槽」，暗示可输入 */
  static BG: string = '#FFFFFF';
  /** 输入框描边：中性偏冷，比 Neutral.BORDER 更明确 */
  static BORDER: string = '#C9D2CE';
  /**
   * 占位提示文字色（≥4.5:1，保证"看得见这里能输入"）。
   * ⚠️ 取证回测修正：初版取 #7C8A85，白底上只有 **3.60:1**（AA 需 4.5），
   *   仍属"偏弱"——正是本轮要消灭的那类问题，故再压深到 #6B7A75，
   *   实测 4.62:1 达标。它与 Neutral.TEXT_SUB 同值：
   *   语义上「提示文字」本就应等于次级文字色，不该另造一档更浅的灰。
   */
  static PLACEHOLDER: string = '#6B7A75';
  /** 输入中的正文色 */
  static TEXT: string = '#2E3A36';
  /** 光标色 */
  static CURSOR: string = '#3FBF9F';
  /** 聚焦态描边：品牌色，明确"当前正在这里输入" */
  static FOCUS_BORDER: string = '#3FBF9F';
  /** 输入区左侧图标/单位文字色 */
  static AFFIX: string = '#6B7A75';

  /** 按明暗切换的聚焦描边（深色下品牌色需提亮才看得见） */
  static focusBorder(dark: boolean): string {
    return dark ? '#4ECBA9' : '#3FBF9F';
  }

  /** 按明暗切换的输入框底（深色下用白微染浮起，与卡片同一材质语言） */
  static bg(dark: boolean): string {
    return dark ? 'rgba(255,255,255,0.10)' : '#FFFFFF';
  }

  /** 按明暗切换的描边 */
  static border(dark: boolean): string {
    return dark ? 'rgba(236,244,246,0.28)' : '#C9D2CE';
  }

  /** 按明暗切换的 placeholder */
  static placeholder(dark: boolean): string {
    return dark ? '#9DB1AC' : '#6B7A75';
  }

  /** 按明暗切换的正文 */
  static text(dark: boolean): string {
    return dark ? '#E9F0ED' : '#2E3A36';
  }

  /** 按明暗切换的光标 */
  static cursor(dark: boolean): string {
    return dark ? '#63D3B6' : '#3FBF9F';
  }
}

/** 中性色（奶油白基调；深色模式下为深炭绿，见 ThemePalette） */
export class Neutral {
  /** 页面底色：奶油白，非纯白，减弱刺眼感 */
  static BG: string = '#FBF8F3';
  /** 卡片底：比页面底更白，形成层次 */
  static CARD: string = '#FFFFFF';
  /** 次级卡片/输入框底 */
  static SURFACE: string = '#F6F3EE';
  /** 主文字 */
  static TEXT: string = '#2E3A36';
  /** 次要文字 */
  static TEXT_SUB: string = '#6B7A75';
  /** 弱化文字/占位 */
  static TEXT_MUTED: string = '#A3AEA9';
  /** 分割线 */
  static BORDER: string = '#EDE8E1';
  /** 深色（成长树/夜间卡片） */
  static INK: string = '#24322E';
}

/** 语义色：四大类低碳行为 + 状态 */
export class Accent {
  /** 绿色出行 - 青 */
  static TRAVEL: string = '#4FB8C4';
  static TRAVEL_BG: string = '#E4F4F6';
  /** 节水节电 - 琥珀 */
  static ENERGY: string = '#E0A458';
  static ENERGY_BG: string = '#FBF0DF';
  /** 旧物回收 - 绿 */
  static RECYCLE: string = '#6FC08A';
  static RECYCLE_BG: string = '#E6F5EB';
  /** 光盘行动 - 珊瑚 */
  static FOOD: string = '#E88B7E';
  static FOOD_BG: string = '#FCEAE7';

  /** 成功 */
  static SUCCESS: string = '#4CAF7D';
  static SUCCESS_BG: string = '#E3F4EA';
  /** 警告 */
  static WARNING: string = '#E0A458';
  static WARNING_BG: string = '#FBF0DF';
  /** 危险 */
  static DANGER: string = '#E0736B';
  static DANGER_BG: string = '#FBE8E6';
  /** 信息 */
  static INFO: string = '#5B9BD5';
  static INFO_BG: string = '#E6F0F9';
}

/**
 * 图标语义色（按语义上色，不加底块）
 * ==================================================================
 * 为什么不直接复用 Accent：
 *   Accent 是「面」色（药丸底、占比条、浅底），明度偏高 ——
 *   #4FB8C4 压白底对比度只有 2.2:1；而 24vp 视口下 Tabler 只有 2px 描边，
 *   用面色画线会发飘。所以这里单独备一套「线」色：
 *     浅色模式取 600 级（白底 ≥3:1，细线也立得住）；
 *     深色模式沿用 Accent 的深色档（已提亮，压在深底上够亮）。
 *
 * tone 名与 CategoryMeta 的四大类 key 同名，分类场景可直接透传：
 *   tone: IconTone.ofCategory(r.category)
 * 非分类入口用 gold / violet / data，其余保持默认文字色（neutral）。
 *
 * ⚠️ 只影响显式传了 tone 的图标：返回箭头、chevron 这类结构件
 *   不传 tone，仍然走 Neutral.TEXT，不会把界面染花。
 */
export class IconTone {
  static readonly NEUTRAL: string = 'neutral';
  static readonly TRAVEL: string = 'travel';
  static readonly ENERGY: string = 'energy';
  static readonly RECYCLE: string = 'recycle';
  static readonly FOOD: string = 'food';
  static readonly GOLD: string = 'gold';
  static readonly VIOLET: string = 'violet';
  static readonly DATA: string = 'data';

  /** tone → 当前主题下的描边色 */
  static color(tone: string): string {
    if (ThemePalette.dark) {
      if (tone === IconTone.TRAVEL) return '#5CC2CE';
      if (tone === IconTone.ENERGY) return '#E8B268';
      if (tone === IconTone.RECYCLE) return '#7FCB95';
      if (tone === IconTone.FOOD) return '#F0998C';
      if (tone === IconTone.GOLD) return '#E8C062';
      if (tone === IconTone.VIOLET) return '#A79BF0';
      if (tone === IconTone.DATA) return '#74AEE0';
      return '#9AA8A3';
    }
    if (tone === IconTone.TRAVEL) return '#178A9E';
    if (tone === IconTone.ENERGY) return '#BE7A12';
    if (tone === IconTone.RECYCLE) return '#2E9463';
    if (tone === IconTone.FOOD) return '#CE5B47';
    if (tone === IconTone.GOLD) return '#B0860F';
    if (tone === IconTone.VIOLET) return '#6C5CE0';
    if (tone === IconTone.DATA) return '#2F76C6';
    return '#5C6B66';
  }

  /** 四大类 key 直接当 tone；未知分类回落中性 */
  static ofCategory(cat: string): string {
    if (cat === IconTone.TRAVEL || cat === IconTone.ENERGY
      || cat === IconTone.RECYCLE || cat === IconTone.FOOD) {
      return cat;
    }
    return IconTone.NEUTRAL;
  }

  /** 科普分类：政策→数据蓝、概念→青、技巧→绿 */
  static ofArticle(cat: string): string {
    if (cat === 'policy') return IconTone.DATA;
    if (cat === 'concept') return IconTone.TRAVEL;
    if (cat === 'tips') return IconTone.RECYCLE;
    return IconTone.NEUTRAL;
  }

  /**
   * 通用入口 code → tone。
   * 让「我的」列表、看板宫格这类按 code 驱动的场景不必逐行写颜色，
   * 同时保证同一个功能在全 App 是同一个色（徽章不会这里金那里紫）。
   */
  static ofUi(code: string): string {
    if (code === 'coin' || code === 'badge' || code === 'star') return IconTone.GOLD;
    if (code === 'mall' || code === 'ticket' || code === 'gift') return IconTone.VIOLET;
    if (code === 'tree' || code === 'certificate' || code === 'home'
      || code === 'recycle' || code === 'sprout' || code === 'leaf') {
      return IconTone.RECYCLE;
    }
    if (code === 'bulb' || code === 'pie' || code === 'calendar' || code === 'flame') {
      return IconTone.ENERGY;
    }
    if (code === 'trend' || code === 'device' || code === 'world' || code === 'chart') {
      return IconTone.DATA;
    }
    if (code === 'commute' || code === 'factor' || code === 'route'
      || code === 'bike' || code === 'bus') {
      return IconTone.TRAVEL;
    }
    if (code === 'target' || code === 'plate') return IconTone.FOOD;
    return IconTone.NEUTRAL;
  }
}

/** 四大类 key 与展示信息 */
export class CategoryMeta {
  static readonly TRAVEL: string = 'travel';
  static readonly ENERGY: string = 'energy';
  static readonly RECYCLE: string = 'recycle';
  static readonly FOOD: string = 'food';

  /** key → 中文名 */
  static label(key: string): string {
    if (key === CategoryMeta.TRAVEL) return '绿色出行';
    if (key === CategoryMeta.ENERGY) return '节水节电';
    if (key === CategoryMeta.RECYCLE) return '旧物回收';
    if (key === CategoryMeta.FOOD) return '光盘行动';
    return '低碳生活';
  }

  /** key → 主色 */
  static color(key: string): string {
    if (key === CategoryMeta.TRAVEL) return Accent.TRAVEL;
    if (key === CategoryMeta.ENERGY) return Accent.ENERGY;
    if (key === CategoryMeta.RECYCLE) return Accent.RECYCLE;
    if (key === CategoryMeta.FOOD) return Accent.FOOD;
    return Brand.PRIMARY;
  }

  /** key → 浅底色 */
  static bg(key: string): string {
    if (key === CategoryMeta.TRAVEL) return Accent.TRAVEL_BG;
    if (key === CategoryMeta.ENERGY) return Accent.ENERGY_BG;
    if (key === CategoryMeta.RECYCLE) return Accent.RECYCLE_BG;
    if (key === CategoryMeta.FOOD) return Accent.FOOD_BG;
    return Brand.PRIMARY_PALE;
  }

  /**
   * key → 图标 code（IconMap 的 ui 表）。
   * 2026-10 由 emoji 改为语义 code：emoji 自带颜色、无法跟随主题，
   * 且 ♻️（U+267B+FE0F）这类带变体选择符的字符各机型回退不一致。
   */
  static icon(key: string): string {
    if (key === CategoryMeta.TRAVEL) return 'commute';
    if (key === CategoryMeta.ENERGY) return 'bulb';
    if (key === CategoryMeta.RECYCLE) return 'recycle';
    if (key === CategoryMeta.FOOD) return 'plate';
    return 'sprout';
  }

  /** 全部大类（供因子库分栏） */
  static all(): string[] {
    return [CategoryMeta.TRAVEL, CategoryMeta.ENERGY, CategoryMeta.RECYCLE, CategoryMeta.FOOD];
  }
}

/**
 * 碳情绪色阶：把「当日碳排放水平」翻译成视觉语言
 * ------------------------------------------------------------------
 * 理念：颜色本身就是反馈。用户不用读数字，抬眼看到背景就知道
 *      「今天状态好不好」——比折线图更直觉，也更有情绪感染力。
 *
 * 四档（与 EcoMood.level 对应）：
 *   ECO   优秀  清新薄荷绿，一片生机
 *   GOOD  良好  平和青绿，稳定从容
 *   WARN  接近阈值  暖麦黄，开始发紧
 *   ALERT 超过阈值  警示珊瑚红，需要行动
 *
 * 取色约束（重要）：
 *   · 全部保持**低饱和**。高饱和的红绿在整屏大面积铺开会很刺眼、
 *     且与项目既有「淡绿奶油风」冲突；
 *   · 只作**背景层**与强调色使用，正文文字色不变，
 *     保证任何档位下文字对比度都达标；
 *   · ALERT 档才允许出现较明显的暖色，其余三档差异要克制而可辨。
 *
 * ⚠️ 各档 BG 必须是 **rgba 半透明**，不能用六位十六进制纯色：
 *   纯色底会把 backdropBlur 完全盖住，模糊等于白加，
 *   页面观感就是"一张不透明的色纸贴在屏幕上"，没有液态玻璃的通透感。
 *   透明度取 0.62：既让下层内容（Navigation 栈、底部玻璃条）真实透出并虚化，
 *   又保证正文文字对比度达标。
 *
 * 深色适配见 ThemePalette.applyDarkValues：BG/SOLID 换深色调染、
 * ACCENT 提亮；FROM/TO（Hero 渐变与按钮实底）保持浅色套值不变。
 */
export class EcoMood {
  /* ⚠️ 正向碳情绪 v2（浅色套值）：档位语义反转后按「灰→黄→黄绿→荧光绿」重取色。
   * 设计关键词：轻盈 Weightless / 呼吸 Breathable / 生机 Vibrant ——
   * 低档位灰绿暗淡静默，随减排逐档点亮，荧光绿档全屏通透发光。 */
  /** 荧光绿：目标达成，全屏生机（ACCENT 压深保浅底对比度） */
  static ECO_FROM: string = '#B9F4CE';
  static ECO_TO: string = '#4ADE80';
  static ECO_BG: string = 'rgba(240,251,244,0.62)';
  static ECO_ACCENT: string = '#189A55';

  /** 黄绿：渐入佳境 */
  static GOOD_FROM: string = '#DDEFAF';
  static GOOD_TO: string = '#A3D977';
  static GOOD_BG: string = 'rgba(247,251,236,0.62)';
  static GOOD_ACCENT: string = '#6E9E2E';

  /** 暖黄：开始升温 */
  static WARN_FROM: string = '#F6E7AE';
  static WARN_TO: string = '#E9C55C';
  static WARN_BG: string = 'rgba(253,250,237,0.62)';
  static WARN_ACCENT: string = '#C0922C';

  /** 旧告警档：level() 不再返回，表保留供历史引用 */
  static ALERT_FROM: string = '#F2B3AB';
  static ALERT_TO: string = '#E0736B';
  static ALERT_BG: string = 'rgba(253,243,241,0.62)';
  static ALERT_ACCENT: string = '#C4554C';

  /** 灰：静默（今日尚无减排），暗淡深灰绿 */
  static NONE_FROM: string = '#D3DCD6';
  static NONE_TO: string = '#A8B5AC';
  // 同为半透明：Neutral.BG 是纯色，直接用会让无数据时背景「退回不透明」，
  // 表现为进入应用前后背景质感突变
  static NONE_BG: string = 'rgba(248,249,246,0.62)';
  static NONE_ACCENT: string = '#8A948F';

  /**
   * 各档「页面根底」实色（不透明）—— 只给 @Entry 根容器打底用。
   *
   * 为什么需要它：上面的 *_BG 是 62% 半透明，设计意图是「透出下层」。
   * 但 @Entry 页面根层默认是系统纯白，半透明色叠在白底上会褪成近白
   * （如 62% 薄荷 + 白 ≈ #F7FDFA，肉眼就是白）——整页底色发白，
   * 底部玻璃胶囊 backdropBlur 采样到它，整条导航栏也跟着发白。
   *
   * 根底必须实色把颜色「钉死」，上层的半透明 *_BG、玻璃、模糊
   * 才有东西可透、有质可感。色值与对应 *_BG 的 RGB 完全一致，
   * 只是 alpha 从 0.62 提到 1.0，层级观感不跳变。
   */
  static ECO_SOLID: string = '#F0FBF4';
  static GOOD_SOLID: string = '#F7FBEC';
  static WARN_SOLID: string = '#FDFAED';
  static ALERT_SOLID: string = '#FDF3F1';
  static NONE_SOLID: string = '#F8F9F6';

  /**
   * 各档页面的实时背景模糊半径（配 backdropBlur 使用）。
   *
   * ⚠️ 性能：backdropBlur 会为组件建离屏渲染层、每帧重新采样背景。
   * 页面背景是全屏面积，比底部胶囊(SHEET 30 / 胶囊 20)代价更大，
   * 因此取 12/14/16 三档：既虚化下层内容、又不至于明显掉帧。
   * 同一区域**不可叠加多层模糊**（Theme.ets Glass.LIVE_BLUR 注释有详述）。
   */
  static blurOf(level: string): number {
    if (level === 'eco') return 16
    if (level === 'good') return 14
    return 12
  }

  /**
   * 各档玻璃上沿高光（⚠️ 正向碳情绪 v2）：减排越高，玻璃越「充满能量」——
   * good/eco 档高光逐档提亮，eco 档带一丝青绿染（边框发光感的来源）；
   * 低档位回归安静的白。深色模式下收敛：深玻璃上强白边会变刺眼亮线，
   * 但 eco 档仍要比其他档高出一截（0.26 vs 0.18），保住「发光」的层级差。
   */
  static edgeOf(level: string): string {
    if (ThemePalette.dark) {
      if (level === 'eco') return 'rgba(224,255,240,0.26)'
      if (level === 'good') return 'rgba(255,255,255,0.22)'
      return 'rgba(255,255,255,0.18)'
    }
    if (level === 'eco') return 'rgba(238,255,246,0.95)'
    if (level === 'good') return 'rgba(255,255,255,0.88)'
    return 'rgba(255,255,255,0.80)'
  }
}

/**
 * 情绪化反馈：碳状态 → 主题色 + 文案
 * ------------------------------------------------------------------
 * 把判定逻辑与配色、文案集中在这里，页面只消费结果，
 * 避免「颜色和文案对不上」的散落判定。
 */
export class EcoTheme {
  /**
   * 判定当日档位（⚠️ 正向碳情绪 v2 —— 方向反转，用户重构指令）。
   * ------------------------------------------------------------------
   * 旧口径把 todayKg 当「排放」解读（超出目标 = 红色警报），方向错了：
   * 全部行为记录（骑行/素食/光盘/回收…）本来就是**减排动作**，
   * todayKg 是「今日减排量」—— 减排越多越该被奖励。
   *
   * 新口径（灰 → 黄 → 黄绿 → 荧光绿，Weightless/Breathable/Vibrant）：
   *   todayKg < 1     → 'none' 灰     静默：今日几乎还没减排
   *   todayKg < 3     → 'warn' 黄     升温：开始有减排动作
   *   todayKg < quota → 'good' 黄绿   渐入佳境：接近日目标
   *   todayKg ≥ quota → 'eco'  荧光绿 目标达成：全屏通透发光
   * 'alert' 不再作为全局档位返回（红色告警退场，灰色成为最低值）；
   * quotaKg ≤ 0 时按 5 kg 兜底（日均减排目标）。
   */
  static level(todayKg: number, quotaKg: number): string {
    const quota: number = quotaKg > 0 ? quotaKg : 5
    if (todayKg < 1) return 'none'
    if (todayKg < 3) return 'warn'
    if (todayKg < quota) return 'good'
    return 'eco'
  }

  /** 档位对应的渐变起始色 */
  static from(level: string): string {
    if (level === 'eco') return EcoMood.ECO_FROM
    if (level === 'good') return EcoMood.GOOD_FROM
    if (level === 'warn') return EcoMood.WARN_FROM
    if (level === 'alert') return EcoMood.ALERT_FROM
    return EcoMood.NONE_FROM
  }

  /** 档位对应的渐变尾色 */
  static to(level: string): string {
    if (level === 'eco') return EcoMood.ECO_TO
    if (level === 'good') return EcoMood.GOOD_TO
    if (level === 'warn') return EcoMood.WARN_TO
    if (level === 'alert') return EcoMood.ALERT_TO
    return EcoMood.NONE_TO
  }

  /** 档位对应的页面底色 */
  static bg(level: string): string {
    if (level === 'eco') return EcoMood.ECO_BG
    if (level === 'good') return EcoMood.GOOD_BG
    if (level === 'warn') return EcoMood.WARN_BG
    if (level === 'alert') return EcoMood.ALERT_BG
    return EcoMood.NONE_BG
  }

  /**
   * 档位对应的页面根底实色（不透明）—— @Entry 根容器专用。
   * 半透明 bg() 只能盖在「已经有颜色」的东西上；根层是系统白底，
   * 必须用这个实色变体把底色钉死，否则整页褪成近白、玻璃采样到白。
   */
  static bgSolid(level: string): string {
    if (level === 'eco') return EcoMood.ECO_SOLID
    if (level === 'good') return EcoMood.GOOD_SOLID
    if (level === 'warn') return EcoMood.WARN_SOLID
    if (level === 'alert') return EcoMood.ALERT_SOLID
    return EcoMood.NONE_SOLID
  }

  /**
   * 环境光晕色：根层径向渐变（radialGradient）专用的低透明度档位主色。
   *
   * 背景：根底是纯实色时，backdropBlur 采样到的是一块**均匀平色**——
   * 玻璃再透也只能透出同一个颜色，没有「环境纵深」。
   * 在根层最底垫一道极暗的径向光晕（屏幕顶部微亮、向四周衰减），
   * 上层的半透明页底、玻璃、模糊才有东西可以采样，液态感才有来源。
   *
   * · 颜色跟档位走（primaryLight）：ECO 是薄荷光、ALERT 偏珊瑚光，
   *   光晕与页面情绪底色天然同族；
   * · alpha 取「极暗」口径：浅色 0.10 / 深色 0.12 —— 光晕是环境不是光源，
   *   浓了会变成一块色斑；深底上光晕感知更强，故比浅色只多一档。
   */
  static glow(level: string): string {
    const c: number[] = EcoTheme.parseColor(EcoTheme.primaryLight(level))
    const a: number = ThemePalette.dark ? 0.12 : 0.10
    return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'
  }

  /** 档位对应的强调色 */
  static accent(level: string): string {
    if (level === 'eco') return EcoMood.ECO_ACCENT
    if (level === 'good') return EcoMood.GOOD_ACCENT
    if (level === 'warn') return EcoMood.WARN_ACCENT
    if (level === 'alert') return EcoMood.ALERT_ACCENT
    return EcoMood.NONE_ACCENT
  }

  /* ---------- 组件全套色位 ----------
   * 二三级页面的卡片色条、按钮、进度条、选中药丸原先全部硬编码
   * Brand.PRIMARY 绿色，导致一级页面已是红色警报态、进入二级页面
   * 却还是原来的绿 —— 视觉上像"换了个应用"。
   * 这里补齐组件需要的每个色位，组件订阅 ecoLevel 后即可整体换色。
   */

  /** 组件主色（按钮底、进度条、选中药丸）：比 accent 略亮，按钮上更醒目 */
  static primary(level: string): string {
    if (level === 'eco') return EcoMood.ECO_TO
    if (level === 'good') return EcoMood.GOOD_TO
    if (level === 'warn') return EcoMood.WARN_TO
    if (level === 'alert') return EcoMood.ALERT_TO
    return Brand.PRIMARY
  }

  /** 组件主色浅色（渐变头、图标底）：比 primary 亮一档 */
  static primaryLight(level: string): string {
    if (level === 'eco') return EcoMood.ECO_FROM
    if (level === 'good') return EcoMood.GOOD_FROM
    if (level === 'warn') return EcoMood.WARN_FROM
    if (level === 'alert') return EcoMood.ALERT_FROM
    return Brand.PRIMARY_LIGHT
  }

  /** 组件主色深色（文字强调、渐变尾） */
  static primaryDeep(level: string): string {
    return EcoTheme.accent(level)
  }

  /* ---------- Hero 渐变专用色位（深色模式协调） ----------
   * 背景：全 App 二十余处 Hero 大卡（账号卡 / 概览卡 / 证书卡 / 月账单卡…）
   * 的 linearGradient 直接用 primaryLight → primaryDeep 做底。浅色下这是
   * 「薄荷实底渐变 + 白字」的品牌锚点，观感正确。
   *
   * 但深色套值里这两个色仍是**亮色**（primaryLight = #7FD9C4），
   * 于是深炭页面上浮现一块亮绿，与深色主页面明显打架 ——
   * 用户截图反馈「刷新颜色和主页面不一致」。
   *
   * 为什么不直接压暗 primaryDeep：它同时是大量文字的强调色
   * （fontColor(primaryDeep) 遍布各页），整体压暗会让深色卡片上的
   * 强调文字看不见。因此渐变单独走 hero* 色位：
   *   · 浅色模式：原样委托 primary*，观感零变化；
   *   · 深色模式：压成低饱和深绿玻璃渐变（保留档位色相倾向：
   *     薄荷 / 黄绿 / 暖黄 / 珊瑚），白字对比度 > 8:1，
   *     Hero 卡从深炭页面里「浮」出来，但不再「跳」出来。
   * 仅渐变 colors 数组里的引用需要换成 hero*（见批量替换脚本注释）。
   */
  /** Hero 渐变起始色 */
  static heroFrom(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primaryLight(level)
    if (level === 'eco') return 'rgba(34,84,64,0.94)'
    if (level === 'good') return 'rgba(52,72,44,0.94)'
    if (level === 'warn') return 'rgba(70,62,42,0.94)'
    if (level === 'alert') return 'rgba(72,48,44,0.94)'
    return 'rgba(34,54,48,0.94)'
  }

  /** Hero 渐变中段色（三段式渐变的中色） */
  static heroMid(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primary(level)
    if (level === 'eco') return 'rgba(28,68,52,0.94)'
    if (level === 'good') return 'rgba(42,60,36,0.94)'
    if (level === 'warn') return 'rgba(58,52,34,0.94)'
    if (level === 'alert') return 'rgba(60,40,36,0.94)'
    return 'rgba(28,44,40,0.94)'
  }

  /** Hero 渐变尾色 */
  static heroTo(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primaryDeep(level)
    if (level === 'eco') return 'rgba(22,54,42,0.96)'
    if (level === 'good') return 'rgba(33,48,29,0.96)'
    if (level === 'warn') return 'rgba(46,42,28,0.96)'
    if (level === 'alert') return 'rgba(47,31,29,0.96)'
    return 'rgba(22,35,32,0.96)'
  }

  /**
   * 组件浅底（图标圆形底、标签底）：极淡，保证底下的文字清晰。
   * 深色模式改为同色系 16% 深色半透明（浅色薄荷块在深色页面上
   * 会像一块「贴纸」，且与深色卡片边界冲突）。
   */
  static primaryPale(level: string): string {
    if (ThemePalette.dark) {
      if (level === 'eco') return 'rgba(63,191,159,0.16)'
      if (level === 'good') return 'rgba(95,184,148,0.16)'
      if (level === 'warn') return 'rgba(224,164,88,0.16)'
      if (level === 'alert') return 'rgba(224,115,107,0.16)'
      return 'rgba(63,191,159,0.12)'
    }
    if (level === 'eco') return 'rgba(226,246,239,0.92)'
    if (level === 'good') return 'rgba(230,245,236,0.92)'
    if (level === 'warn') return 'rgba(251,240,222,0.92)'
    if (level === 'alert') return 'rgba(251,233,230,0.92)'
    return Brand.PRIMARY_PALE
  }

  /** 主题投影染色（卡片/按钮投影随档位变色，而不是一律品牌绿） */
  static shadowColor(level: string): string {
    if (ThemePalette.dark) {
      // 深色底上投影收敛：过重的染色投影在深底上显脏
      if (level === 'warn') return 'rgba(224,164,88,0.20)'
      if (level === 'alert') return 'rgba(224,115,107,0.20)'
      return 'rgba(63,191,159,0.20)'
    }
    if (level === 'warn') return 'rgba(224,164,88,0.28)'
    if (level === 'alert') return 'rgba(224,115,107,0.28)'
    return 'rgba(63,191,159,0.28)'
  }

  /**
   * 极简颜色解析（仅本文件的情绪混合用）。
   * ⚠️ 刻意**不复用** `GlassLight.rgbaOf`：GlassLight 已经 import 本文件，
   *   反向引用会形成循环依赖（arkts 编译期会报）。故就地实现一份，
   *   只支持本文件实际传入的两种写法：'#RRGGBB' 与 'rgba(r,g,b,a)'。
   * 解析失败返回不透明黑，由调用方的 ratio=0 路径兜底。
   */
  private static parseColor(color: string): number[] {
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1)
      if (hex.length >= 6) {
        return [parseInt(hex.substring(0, 2), 16), parseInt(hex.substring(2, 4), 16),
          parseInt(hex.substring(4, 6), 16), hex.length >= 8 ? parseInt(hex.substring(6, 8), 16) / 255 : 1]
      }
      return [0, 0, 0, 1]
    }
    if (color.indexOf('rgba') === 0) {
      const inner: string = color.substring(color.indexOf('(') + 1, color.indexOf(')'))
      const parts: string[] = inner.split(',')
      if (parts.length >= 3) {
        const a: number = parts.length >= 4 ? Number(parts[3].trim()) : 1
        return [Number(parts[0].trim()), Number(parts[1].trim()), Number(parts[2].trim()), a]
      }
    }
    return [0, 0, 0, 1]
  }

  /**
   * 碳情绪可视化的**唯一入口**：把一个「原本固定的主题色」
   * 按当前档位映射成带情绪倾向的颜色。
   *
   * 背景（用户反馈「这里的 UI 没有做碳情绪可视化」，附科普页 ALERT 档截图）：
   * 页面底色已随档位变暖（底部那道橙光晕就是 ALERT 证据），
   * 但文章卡的分类色标、Hero 渐变仍是**写死的薄荷绿** ——
   * 于是「背景在报警、卡片还是一片绿」，情绪表达被割裂。
   *
   * 为什么不能直接把分类色换成档位色：
   *   四大分类（出行/节能/回收/饮食）各有固定色相，是**信息编码**，
   *   换掉就丢失了「这是哪一类」的区别度。
   * 所以做法是**保留原色相、只按情绪整体偏移**：
   *   ECO/GOOD（状态好）→ 基本保持原色，清爽；
   *   WARN（接近阈值）  → 向麦黄方向轻移 30%，开始"发紧"；
   *   ALERT（超阈值）   → 向珊瑚方向移 55%，明确"该行动了"。
   * 这样分类仍可区分，同时整屏色调随碳排走 —— 情绪成了**背景语言**。
   *
   * @param base 该分类的固有色相（通常是浅色档的 *_BG 或纯色）
   * @param blend 混合到的情绪色（麦黄 / 珊瑚）
   * @param ratio 混合强度 0~1
   */
  static tintByMood(base: string, blend: string, ratio: number): string {
    const b: number[] = EcoTheme.parseColor(base);
    const t: number[] = EcoTheme.parseColor(blend);
    if (b.length < 4 || t.length < 4) return base
    const r: number = Math.round(b[0] + (t[0] - b[0]) * ratio)
    const g: number = Math.round(b[1] + (t[1] - b[1]) * ratio)
    const bl: number = Math.round(b[2] + (t[2] - b[2]) * ratio)
    // alpha 一律取较实的一档：色标要能压住玻璃底，透传会看不清
    const a: number = Math.min(0.92, Math.max(b[3], 0.62))
    return 'rgba(' + r + ',' + g + ',' + bl + ',' + a.toFixed(2) + ')'
  }

  /** 当前档位下，向情绪色混合的比例（0=保持原色，越大越"有情绪"） */
  static moodMix(level: string): number {
    if (level === 'alert') return 0.55
    if (level === 'warn') return 0.30
    if (level === 'eco' || level === 'good') return 0
    return 0.12
  }

  /** 当前档位应混合到的情绪色 */
  static moodColor(level: string): string {
    if (level === 'alert') return Accent.FOOD
    if (level === 'warn') return Accent.ENERGY
    return Brand.PRIMARY
  }

  /**
   * 情绪化分类色：科普页色标、筛选 chip 等**有固定色相**的元素用它，
   * 从而在不丢失分类区别度的前提下参与碳情绪表达。
   *
   * ⚠️ 为什么不能用一个统一的 mix 值（回测踩坑）：
   *   初版对四个分类用同一个 ratio，实算发现**档位越高、四色越趋同**：
   *     warn 最小两两色差 6、alert 仅 4 —— 四类在 ALERT 档全变成同一种
   *     脏粉，「这是哪一类」的信息编码被抹掉了，情绪可视化的目的反而落空。
   *   原因是四个分类底色都是**极淡的同调浅色**（色相集中在淡青/淡蓝/淡绿/淡黄），
   *   等量混合到同一个暖色后差异自然被压平。
   *
   * 现改为**按分类分档**：以「政策(青)→生活(黄)」为情绪梯度，
   * 青/蓝类天然偏冷、朝麦黄/珊瑚移动得少；黄/暖类已接近情绪色，移动得多。
   *   ECO/GOOD 一律 0（原样）；
   *   WARN  政策 0.12 / 基础 0.20 / 技巧 0.28 / 生活 0.38；
   *   ALERT 政策 0.20 / 基础 0.32 / 技巧 0.44 / 生活 0.58。
   * 实算 alert 档最小两两色差回到 25 以上，四类仍可区分，
   * 同时整屏明显偏向珊瑚 —— 情绪成为背景语言而非唯一编码。
   *
   * @param level 碳档位
   * @param base  分类固有色（浅色档底色）
   * @param rank  分类在本页的排序位（0 = 最冷 → 3 = 最暖）
   */
  static moodTint(level: string, base: string, rank: number = 2): string {
    const step: number = EcoTheme.moodStep(level)
    if (step <= 0) return base
    // 分档系数：rank 越大越暖、混合越重
    const graded: number = Math.min(1, step * (0.55 + rank * 0.22))
    return EcoTheme.tintByMood(base, EcoTheme.moodColor(level), graded)
  }

  /** 当前档位的情绪混合基准强度 */
  static moodStep(level: string): number {
    if (level === 'alert') return 0.55
    if (level === 'warn') return 0.30
    if (level === 'eco' || level === 'good') return 0
    return 0.10
  }

  /**
   * 情绪化文字色：在档位强调色基础上再向情绪色靠拢，
   * 让「徽标/标签上的文字」也参与情绪表达（浅色下仍保持可读）。
   */
  static moodAccent(level: string): string {
    return EcoTheme.accent(level)
  }

  /** 档位对应的图标 code（IconMap 的 ui 表） */
  static icon(level: string): string {
    if (level === 'eco') return 'leaf'
    if (level === 'good') return 'sprout'
    if (level === 'warn') return 'sun'
    if (level === 'alert') return 'flame'
    return 'world'
  }

  /** 档位对应的标题（正向碳情绪 v2：减排越多越被奖励） */
  static title(level: string): string {
    if (level === 'eco') return '生机满格'
    if (level === 'good') return '渐入佳境'
    if (level === 'warn') return '减排升温'
    if (level === 'alert') return '超出阈值'
    return '静默时刻'
  }

  /** 档位对应的情绪化文案：把数字翻译成感受（todayKg = 今日减排量） */
  static desc(level: string, todayKg: number, quotaKg: number): string {
    if (quotaKg <= 0) return '记录一次低碳行为，开启今日生机'
    if (level === 'eco') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，达成日目标，生机满格'
    }
    if (level === 'good') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，接近日目标，渐入佳境'
    }
    if (level === 'warn') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，绿色正在升温'
    }
    return '今日已减排 ' + todayKg.toFixed(2) + ' kg，从一点一滴开始积累'
  }

  /** 档位对应的正向引导（WARN/GOOD 提示「再进一步」，达成后不再打扰） */
  static advice(level: string): string {
    if (level === 'warn') return '再记一次骑行或光盘行动，让今日绿色升温'
    if (level === 'good') return '只差一步达成日目标，试试素食一餐或随手关灯'
    return ''
  }
}

/** 圆角与间距 */
export class Radius {
  static readonly SM: number = 8;
  static readonly MD: number = 14;
  static readonly LG: number = 20;
  static readonly XL: number = 28;
  static readonly PILL: number = 999;
}

export class Space {
  static readonly XS: number = 4;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 24;
  /** 页面左右安全边距 */
  static readonly PAGE: number = 18;
}

/** 字号 */
export class FontSize {
  static readonly CAPTION: number = 11;
  static readonly SMALL: number = 12;
  static readonly BODY: number = 14;
  static readonly TITLE: number = 16;
  static readonly HEADING: number = 19;
  static readonly DISPLAY: number = 26;
  static readonly HERO: number = 34;

  /**
   * 字体缩放上限
   * ------------------------------------------------------------------
   * 全局界面按固定 vp 网格排版（卡片高度、图表柱区、栏高都是写死的），
   * 一旦系统「字体大小」被调到最大，fp 字号会成倍放大：
   *   · 徽章卡、统计小卡的文字直接顶破卡片边界；
   *   · 图表纵轴刻度互相重叠。
   * 因此正文类文本统一把缩放钳到 1.15（允许轻微适配，不允许撑破布局），
   * 而大数字（HERO / DISPLAY）字号本身已经很大，钳到 1 保持版式稳定。
   */
  static readonly SCALE_TEXT: number = 1.15;
  static readonly SCALE_NUM: number = 1;
}

/**
 * 阴影：ArkUI 的 shadow() 只接受对象参数，不能直接传字符串，
 * 这里提供构造 ShadowOptions 的辅助方法。
 * 色值为可变字段：深色模式下投影加深（黑投影在深底上不可见）。
 */
export class Shadow {
  /** 卡片常态阴影色（可被 ThemePalette 换血） */
  // 收敛：原 #0C00000F（alpha 4.7%）+ offsetY 2 会在卡片右下角渗出一块
  // 明显脏暗的晕斑（像素实测比底色暗 32/255）。现压到 alpha 1.2% 且偏移归零，
  // 只保留极轻的浮起感；玻璃卡片请改用 GlassLight.shadowOf(tier)。
  // ⚠️ 再收一档（2026-10-19 夜）：卡片本体已改为「比页面底亮 10 级的白玻璃」，
  //    任何 alpha > 1.5% 的黑投影都会在卡片四周压出一圈灰晕（看着像脏边），
  //    现统一压到 alpha 3/255 ≈ 1.2%，层次全部交给玻璃自身的受光边。
  static cardColor: string = '#03000003';
  /** 卡片常态阴影 Y 偏移 */
  static cardOffsetY: number = 0;
  /** 主色投影色 */
  static brandColor: string = '#3FBF9F47';
  /** 悬浮元素阴影色 */
  static raisedColor: string = '#0C000014';
  /** 悬浮元素阴影 Y 偏移 */
  static raisedOffsetY: number = 6;

  /** 卡片常态阴影（直接用于 .shadow()） */
  static card(): ShadowOptions {
    return { radius: 8, color: Shadow.cardColor, offsetX: 0, offsetY: Shadow.cardOffsetY };
  }

  /** 主色投影 */
  static brand(): ShadowOptions {
    return { radius: 18, color: Shadow.brandColor, offsetX: 0, offsetY: 6 };
  }

  /** 无阴影 */
  static none(): ShadowOptions {
    return { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 };
  }

  /** 悬浮元素阴影：扩散更大、位置更高，模拟离屏高度 */
  static raised(): ShadowOptions {
    return { radius: 20, color: Shadow.raisedColor, offsetX: 0, offsetY: Shadow.raisedOffsetY };
  }
}

/**
 * 液态玻璃材质（HarmonyOS 7 风格）
 * ------------------------------------------------------------------
 * 观感 = 高斯模糊底 + 半透明着色 + 1px 高光描边 + 顶部内高光。
 * ArkUI 侧用 backgroundBlurStyle 取系统材质，而不是自己叠半透明色块：
 * 系统材质会跟随背景内容动态取色（AdaptiveColor.Average），
 * 滚动时玻璃下的内容会真实透出并模糊，这才是「液态」的关键。
 *
 * 用法（只能挂在支持通用属性的容器上，不能挂 @Builder）：
 *   Column() { ... }
 *     .backgroundColor(Glass.PANEL_LIVE_BG)
 *     .backdropBlur(Glass.LIVE_BLUR)
 *     .borderRadius(Radius.XL)
 *     .border(Glass.edge())
 */
/**
 * 玻璃色阶
 * ------------------------------------------------------------------
 * 调整记录：从 0.60~0.72 下调到 0.34~0.46 ——
 * 之前的白色叠加太厚，玻璃看着像"白色塑料片"，底下的内容几乎透不出来。
 * 液态玻璃的灵魂是"透"，底色只做轻微提亮 + 靠 backdropBlur 出磨砂感。
 * 层次靠不透明度差拉开：胶囊 0.34 < 药丸 0.46< 卡片 0.40。
 * 深色模式下整套换为深色半透明 + 收敛白边（见 ThemePalette）。
 */
export class Glass {
  /**
   * 标准玻璃（卡片底色）。
   *
   * 注意：卡片已改为「半透明实色 + 零模糊」（见 GlassLevel.SOLID），
   * 因为 43 处卡片各挂一层模糊会导致滚动/切换明显掉帧。
   * 没有模糊做底时，白色叠加必须更实一些才够清晰 ——
   * 0.40 偏透会透出下层文字，0.86 才是「白玻璃卡片」的观感。
   * 想看通透悬浮感请看底部胶囊（BOTTOM_BAR_BG + backdropBlur）。
   */
  static CARD_BG: string = 'rgba(255,255,255,0.72)';

  /**
   * 悬浮条玻璃（底部 Tab 胶囊 / 圆形按钮）—— 真正用 backdropBlur 的地方。
   *
   * ⚠️ 0.55 → 0.30（用户反馈「胶囊应该是透明的，直接浮在页面之上」）：
   * 取证（科普页预览器截图逐像素）：胶囊左上 (250,255,254)，比页面底色
   * (241,250,247) 亮 10 级 —— 0.55 的白底 + 高光让胶囊在浅色页面上
   * 呈现为一条白色横带，backdropBlur 糊到的内容完全透不出来。
   * 降到 0.30 后胶囊与页面底色只差 4~5 级，玻璃感靠 135° 光照
   * （左上高光 + 右下内阴影）和 1px 四边异色描边建立，
   * 而不是靠把整块玻璃刷白 —— 这才符合「透明玻璃悬浮」。
   * 文字可读性不受影响：Tab 文字是 TEXT_MUTED 深灰，
   * 与底色对比度 4.5:1 以上；选中文字近黑（tabActiveColor）。
   */
  static BOTTOM_BAR_BG: string = 'rgba(255,255,255,0.12)';

  /** 选中态内嵌药丸：比 BAR 略实一档，选中项才浮得出来 */
  static PILL_BG: string = 'rgba(255,255,255,0.42)';

  /**
   * 实时背景模糊半径（配合组件的 .backdropBlur(radius) 使用）。
   *
   * backgroundBlurStyle 与 backdropBlur 的区别：
   * - backgroundBlurStyle：系统预设材质，模糊的是"系统壁纸/窗口背景"，
   *   对组件下方的实时内容（如滚动列表）不生效，看起来像一层贴纸。
   *   （本项目已全面弃用该 API，玻璃一律走 backdropBlur）
   * - backdropBlur(radius)：真正实时模糊该组件后方的像素，
   *   内容滚动/切换时毛玻璃会跟着变，才是鸿蒙 7 那种"活"的玻璃。
   *
   * ⚠️ 性能：backdropBlur 会为组件创建离屏渲染层，每帧都要重新采样背景。
   * 同一区域**不可叠加多层**（例如药丸再套一层backdropBlur），
   * 否则滑动时会明显掉帧。药丸因此只用半透明色 + 描边，不加模糊。
   *
   * 20 → 30（对齐 iOS 液态玻璃的磨砂强度口径 30~40）：
   * 只有底部胶囊 / 圆钮等少数悬浮元素挂本值，离屏开销可控；
   * 半径越大磨砂感越强，玻璃下的内容被揉得更匀，「液态」更明显。
   */
  static readonly LIVE_BLUR: number = 30;

  /**
   * 轻量实时模糊（配合组件的 .backdropBlur(radius) 使用）。
   * 用于二级页顶栏这类「需要透出滚动内容、又不想抢底部胶囊风头」的
   * 悬浮条：比 LIVE_BLUR(20) 弱一档，滑动时模糊变化更细腻、离屏开销更小。
   */
  static readonly LIVE_BLUR_SOFT: number = 12;

  /**
   * 二级页顶栏玻璃底（CfTopBar 用）。
   * 从 BOTTOM_BAR_BG(0.62) 下调到 0.55：顶栏上方是页面标题区、内容从栏下
   * 穿过，需要比底部胶囊更透一档，才能看清「内容被虚化吞没」的层次。
   */
  static TOPBAR_BG: string = 'rgba(255,255,255,0.50)';

  /** 大面积玻璃面板底（看板快捷宫格 / 建议列表 / 弹窗面板）。
   *  这些面板内部直接放内容（不再套白卡片）：0.55 既透得出背景，
   *  又保证文字对比度达标。 */
  static PANEL_LIVE_BG: string = 'rgba(255,255,255,0.50)';

  /**
   * 分段控件轨道底（筛选栏 / 分类栏）。
   * 0.42 与 TrendChartPage 既有玻璃分段范式一致：轨道若太实，
   * 滑动药丸的 backdropBlur 就采样不到内容、失去「液态」意义。
   */
  static SEGMENT_TRACK_BG: string = 'rgba(255,255,255,0.38)';

  /**
   * 玻璃圆盘底（头像 / 图标徽标 / 圆形按钮）。
   * 直径通常 ≤ 120vp，面积小，可以比面板透：0.58 + DISC_BLUR(18)
   * 出磨砂感，内容从圆盘后穿过被虚化。
   */
  static DISC_BG: string = 'rgba(255,255,255,0.52)';

  /**
   * 品牌徽标圆盘实底（启动页 logo 专用，不走玻璃）。
   * DISC_BG + backdropBlur 的组合在预览器下会把圆盘整盘渲染成纯黑
   * （clip + borderRadius + Stack 的模糊采样异常），且深色令牌 0.10 白
   * 也偏暗；品牌徽标必须任何环境稳定可见 → 实底 + 圆环 + 紧致投影。
   */
  static DISC_SOLID_BG: string = '#FFFFFF';

  /** 玻璃圆盘的实时模糊半径：小面积用 18 足够，避免过度糊成一片白 */
  static readonly DISC_BLUR: number = 18;

  /** 玻璃边缘：上亮下暗的细描边，模拟玻璃厚度 */
  static EDGE: string = 'rgba(255,255,255,0.52)';

  /** 玻璃高光：顶部一条 1px 白线 */
  static HIGHLIGHT: string = 'rgba(255,255,255,0.60)';

  /** 面板描边 */
  static edge(): BorderOptions {
    return { width: 1, color: Glass.EDGE };
  }
}

/**
 * 图表布局常量
 * 纯手绘柱状图用；左右轴列必须等宽，否则 X 轴标签会与柱体错位
 */
export class Chart {
  /** 纵轴刻度列宽度（左侧 kg） */
  static readonly AXIS_W: number = 40;
  /** 右侧积分刻度列宽度（可能到 4 位数，单独放宽） */
  static readonly AXIS_RIGHT_W: number = 44;
  /** 柱状图绘图区高度 */
  static readonly PLOT_H: number = 180;
  /** 柱宽 */
  static readonly BAR_W: number = 18;
  /** 轴与绘图区之间的间距 */
  static readonly AXIS_GAP: number = 6;
  /** 刻度文字字号 */
  static readonly AXIS_FONT: number = 8;
  /** 柱顶数值字号 */
  static readonly VALUE_FONT: number = 8;
  /** 柱顶数值占位高度（柱体高度计算要扣掉它，保证 0 值柱也贴住 X 轴） */
  static readonly VALUE_H: number = 12;
  /** X 轴标签行高度 */
  static readonly XAXIS_H: number = 16;
}

/**
 * 业务常量：与后端口径严格一致（源项目唯一基准）
 */
export class Biz {
  /** 1 kgCO2e = 10 积分 */
  static readonly POINTS_PER_KG: number = 10;
  /** 3000 积分 = 1 棵树（与积分商城「公益植树认养」b7 标价、后端 carbon.sql 口径一致） */
  static readonly POINTS_PER_TREE: number = 3000;

  /** 按累计减排量分等级 */
  static levelOf(totalKg: number): number {
    if (totalKg >= 1000) return 5;
    if (totalKg >= 500) return 4;
    if (totalKg >= 100) return 3;
    if (totalKg >= 10) return 2;
    return 1;
  }

  static levelName(level: number): string {
    if (level >= 5) return '森林卫士';
    if (level === 4) return '低碳达人';
    if (level === 3) return '绿芽';
    if (level === 2) return '新芽';
    return '碳芽';
  }

  /**
   * 等级卡通原画（情绪位）。
   * 与 levelName 一一对应：碳芽→新芽→绿芽→大树→森林，看板上用彩色植物
   * 比线稿更能表达「在长大」。结构图标仍走 CfIcon 线稿，见 ui/Icon.ets 头注释。
   */
  static levelArt(level: number): string {
    if (level >= 5) return '🌲';
    if (level === 4) return '🌳';
    if (level === 3) return '🍀';
    if (level === 2) return '🌿';
    return '🌱';
  }

  /** 当前等级下限与下一级阈值 */
  static levelRange(level: number): number[] {
    const bounds: number[][] = [[0, 10], [10, 100], [100, 500], [500, 1000], [1000, 99999]];
    const idx: number = Math.min(Math.max(level, 1), 5) - 1;
    return bounds[idx];
  }

  static levelColor(level: number): string {
    if (level >= 5) return '#3FBF9F';
    if (level === 4) return '#6FC08A';
    if (level === 3) return '#4FB8C4';
    if (level === 2) return '#E0A458';
    return '#E88B7E';
  }

  /** 减排量格式化：kg / t 三档 */
  static formatKg(kg: number): string {
    if (kg >= 1000) return (kg / 1000).toFixed(2) + ' t';
    if (kg >= 10) return kg.toFixed(1) + ' kg';
    return kg.toFixed(2) + ' kg';
  }

  /** 积分换算：round(kg*10)，减排>0 时保底 1 分 */
  static pointsOf(kg: number): number {
    if (kg <= 0) return 0;
    const p: number = Math.round(kg * Biz.POINTS_PER_KG);
    return p < 1 ? 1 : p;
  }

  /** 抵扣的树数量（向下取整） */
  static treesOf(points: number): number {
    return Math.floor(points / Biz.POINTS_PER_TREE);
  }
}
