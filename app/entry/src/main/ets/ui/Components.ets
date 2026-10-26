/**
 * 通用 UI 组件库（淡绿奶油风）
 * ------------------------------------------------------------------
 * 所有页面统一复用这里的组件，保证视觉语言一致：
 * - CfCard      液态玻璃圆角卡 + 轻投影
 * - CfPill      状态药丸（成功/警告/危险/信息/中性）
 * - CfCatBadge  四大类标签
 * - CfSection   区块标题（带左侧色条）
 * - CfEmpty     空态
 * - CfStatTile  数据小卡
 * - CfProgress  进度条
 * - CfTopBar    页面顶部标题栏（悬浮玻璃条，含返回）
 * - CfButton    主/次按钮
 * - cfChart     迷你折线/柱状图（纯 Canvas 绘制，零依赖）
 */
import { Accent, Brand, EcoTheme, FontSize, Glass, Neutral, Radius, Shadow, Space } from './Theme';
import { GlassLight, GlassTier } from './GlassLight';
import { AppleMotion } from './AppleMotion';
import { CfIcon } from './Icon';

/* ==================== 卡片 ==================== */

/**
 * 玻璃性能档位
 * ------------------------------------------------------------------
 * 每一层 backgroundBlurStyle / backdropBlur 都会让系统为该组件创建一张
 * 离屏渲染层，并在**内容滚动或动画时逐帧重新合成**。实测：
 * 全项目 43 处 CfCard 若都开着模糊，在 Previewer（软件渲染）里
 * 滚动与 Tab 切换会明显掉帧。
 *
 * 因此把「模糊」收敛到少数几处真正需要通透感的悬浮元素上：
 *   LIVE  —— 实时模糊，用于底部胶囊 / 圆钮（用户明确要液态玻璃）
 *   SOLID —— 半透明实色，视觉上与玻璃几乎无差别，但**零离屏开销**
 *
 * 卡片一律用 SOLID：卡片是内容容器，本就不该透出后面的文字，
 * 半透明白底反而更易读。
 */
export class GlassLevel {
  /** 半透明实色（默认，性能友好） */
  static readonly SOLID: boolean = false;
  /** 实时模糊（仅用于悬浮胶囊 / 圆钮） */
  static readonly LIVE: boolean = true;
}

@Component
export struct CfCard {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  // 注意：不可用 padding / height / width / bg 等命名，会与 CustomComponent 内置属性冲突
  /**
   * 主题/画质变更信号（恒读钩子）。
   * 玻璃模糊半径经 GlassLight.blurScaled 按档位缩放，
   * 而 GlassLight.quality 是 static 字段（ArkTS 静态字段不响应），
   * 不订阅 themeTick 就不会重建，切档位时模糊不变。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  pad: number = Space.LG;
  /**
   * 自定义卡片底色。留空（默认）= 跟随主题，取当前档位的 Glass.CARD_BG。
   *
   * ⚠️ 这里**不能**写成 `bgColor: string = Glass.CARD_BG`：
   * 成员字段的初始值只在**组件构造时求值一次**，而 Glass.CARD_BG 是
   * static 字段，ThemePalette.applyDark() 换血后不会回灌到已存在的实例。
   * 于是深色模式下卡片仍是浅色 rgba(255,255,255,0.86)，
   * 叠在深底上实测就是 (225,224,222) —— 正是「我的」页看到的那块灰白。
   * 所以默认必须留空 + 每次 build 走 bgValue() 方法现取。
   */
  bgColor: string = '';
  /** 卡片实际底色：显式指定优先，否则每次 build 现取 static 值（响应深色换血） */
  private bgValue(): string {
    return this.bgColor.length > 0 ? this.bgColor : this.tc(Glass.CARD_BG);
  }
  corner: number = Radius.MD;
  /**
   * 环境底色（玻璃亮度自适应用）。留空 = 按白色处理。
   * 二三级页面的卡片多数在浅色底上，留空即可；
   * 若卡片可能落在深色/彩色 Hero 上，由调用方显式传入页面底色。
   */
  ambient: string = '';
  /**
   * 是否启用实时液态玻璃。
   * 默认 **false**：卡片用半透明实色即可，视觉几乎无差别但没有离屏渲染开销。
   * 只有确实需要「透出后方内容」的场景（悬浮条、叠层）才传 true。
   */
  glass: boolean = GlassLevel.SOLID;
  /**
   * 卡片点击回调（可选）。
   * ------------------------------------------------------------------
   * 不传 = 纯展示卡片（没有任何点击反馈，避免错误示能）；
   * 传了 = 卡片可点，自动获得苹果按压手感（按下 100ms 缩到 96%、
   * 松手弹簧回弹，AppleMotion 口径，与 CfButton / CfListRow 一致）。
   *
   * 为什么要内建而不是让调用方自己包 onClick：全库 43 处卡片，
   * 逐个外包一层「onClick + scale + onTouch」既啰嗦又必然漏 ——
   * 漏掉的那批就是「能点但没反馈」的假按钮。收进组件内部，
   * 传 onTap 即有反馈，不传即静默，口径天然统一。
   */
  onTap?: () => void;
  /** 按下态：AppleMotion 按压反馈驱动（见 build 内 scale/animation） */
  @State private pressed: boolean = false
  // 允许以尾随 lambda 形式传入内容（trailing lambda 语法要求且只能有一个 @BuilderParam）
  @BuilderParam contentSlot: () => void = this.emptySlot;

  @Builder
  emptySlot() {}

  /**
   * 卡片底面：统一 135° 单层合成渐变（全局左上 45° 光照）。
   *
   * ⚠️ 全局光照口径（本轮全库整改的核心）：
   *   二三级页面的卡片此前是**平涂底色**（`.backgroundColor(Glass.CARD_BG)`），
   *   压根没接光照模型 —— 所以只有一级页面（走 GlassPanel/GlassLightLayers）
   *   有左上 45° 入射感，点进二级页面卡片就「光的方向变了/没了」。
   *   用户诉求「液态玻璃做全局修改，都要左上角 45° 射入，包括二级三级菜单内的卡片」。
   *
   * 现在全部改走 `GlassLight.surface()`：底色 + 左上白光 + 右下内阴影
   * 压进同一条 135° 渐变，零子层、零离屏合成，47 处卡片一次性统一。
   */
  private surfaceValue(): LinearGradient {
    return this.tw(GlassLight.surface(this.tc(this.bgValue()), GlassTier.CARD, this.ambient, 1));
  }

  /** 玻璃分支底面：底色取更透的 PANEL_LIVE_BG，光照模型与实底分支完全一致 */
  private glassSurfaceValue(): LinearGradient {
    return this.tw(GlassLight.surface(this.tc(Glass.PANEL_LIVE_BG), GlassTier.CARD, this.ambient, 1));
  }

  build() {
    if (this.glass) {
      // 玻璃分支：实时模糊组件后方像素（内容从卡下穿过被虚化），
      // 底色取更透的 PANEL_LIVE_BG，光照同样走 135° 统一模型
      Column() {
        this.contentSlot()
      }
      .width('100%')
      .padding(this.pad)
      .linearGradient(this.glassSurfaceValue())
      .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
      // themeTick 恒读钩子：档位切换后重建（值恒为 1）
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .borderRadius(this.corner)
      /*
       * 四边异色描边，**四边等宽 1vp**。
       * ⚠️ 不要再把顶部加宽到 1.5vp（见GlassLight.shadowOf 同轮记录）：
       *   取证（记录页截图逐像素，x=350..550纵扫）：
       *     y=431  (243,249,244)  亮
       *     y=432  (231,234,227)  **暗，比上下低 12~15，横贯整卡、严格 1px**
       *     y=433  (245,252,247)  最亮 ← 1.5vp 亮边本身
       *     y=434  (241,251,250)  卡片正常值
       *   即：**非整数宽度描边 + borderRadius 裁剪会在描边内侧留下一条
       *   未填充的暗缝**，正好压在亮边下方，视觉上就是一条横贯卡片的
       *   黑色暗线 —— 这就是用户反复说的「暗角、很脏」。
       * ArkUI 的描边按外扩绘制，圆角处覆盖不到内侧就会露底。
       * 结论：**描边宽度只用整数**，厚度感改由 alpha 亮度差承担。
       * ⚠️ 也不能写两次 `.border()` —— 后者会整体覆盖前者。
       */
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 1 },
        color: this.tw(GlassLight.borderColors(GlassTier.CARD, this.ambient, 1))
      })
      .shadow(this.tw(GlassLight.shadowOf(GlassTier.CARD)))
      // 内容被系统字体放大时不允许顶出卡片边界
      .clip(true)
    } else {
      // 非玻璃分支：半透明实色零离屏开销，观感与旧版一致，
      // 但底面换成 135° 合成渐变 —— 这是全局光照统一的关键
      Column() {
        this.contentSlot()
      }
      .width('100%')
      .padding(this.pad)
      .linearGradient(this.surfaceValue())
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .borderRadius(this.corner)
      // 与玻璃分支同口径：四边等宽 1vp（非整数宽度会在圆角内侧留暗缝，
      // 详见玻璃分支 border 处的取证注释）
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 1 },
        color: this.tw(GlassLight.borderColors(GlassTier.CARD, this.ambient, 1))
      })
      .shadow(this.tw(GlassLight.shadowOf(GlassTier.CARD)))
      // 内容被系统字体放大时不允许顶出卡片边界
      .clip(true)
      /*
       * 苹果按压手感（AppleMotion 口径，与 CfButton / CfListRow 一致）：
       *   按下 —— 100ms 内缩到 96%，与触摸事件同帧（晚一帧就「粘手」）；
       *   松手 —— 弹簧回弹（350ms / 0.75 阻尼），100% 附近一次极轻
       *           过冲，这就是 iOS 控件「活」的来源。
       * 未传 onTap 的展示卡不缩 —— 不可点的元素没有按压反馈，
       * 否则是错误示能。scale 是纯绘制属性，不影响布局与命中。
       */
      .scale({
        x: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1,
        y: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1
      })
      .animation(this.pressed
        ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
        : { duration: 0 })
      .onTouch((e: TouchEvent): void => {
        if (this.onTap === undefined) return;
        if (e.type === TouchType.Down) {
          this.pressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      // 保险丝：页面重新可见时强制复位（同 CfListRow，防冻结缩小）
      .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
        if (isExpanding && this.pressed) {
          this.pressed = false;
        }
      })
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    }
  }
}

@Component
export struct CfPill {
  // ⚠️ @Prop：普通成员不跟随父级更新（同 CfStatTile 教训），
  // 记录页分组头「N 条」曾因无装饰器而在筛选切换后停留旧条数。
  @Prop text: string = '';
  @Prop tone: string = 'muted'; // success | warning | danger | info | muted

  /**
   * 主题重建钩子（深色换血的驱动源）。
   * ------------------------------------------------------------------
   * ⚠️ 必须在每个读 static 色值的组件里都订阅 themeTick：
   *   Theme.ets 的色值是 **static 字段，本身不响应** ——
   *   ThemePalette.applyDark() 换血后，已经建完的组件不会重读新值。
   *   只有订阅了 AppStorage('themeTick') 的组件才会被标记重建。
   *
   * 本组件早前漏订阅，导致深色模式下药丸仍是浅色底 + 浅色字
   * （用户反馈「深色模式下我的和看板与记录科普显示不一致」）。
   * CfCard / CfTopBar / CfGlassDisc 早已订阅，唯独这几个没有。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private bg(): string {
    if (this.tone === 'success') return this.tc(Accent.SUCCESS_BG);
    if (this.tone === 'warning') return this.tc(Accent.WARNING_BG);
    if (this.tone === 'danger') return this.tc(Accent.DANGER_BG);
    if (this.tone === 'info') return this.tc(Accent.INFO_BG);
    return this.tc(Neutral.SURFACE);
  }

  private fg(): string {
    if (this.tone === 'success') return this.tc(Accent.SUCCESS);
    if (this.tone === 'warning') return this.tc(Accent.WARNING);
    if (this.tone === 'danger') return this.tc(Accent.DANGER);
    if (this.tone === 'info') return this.tc(Accent.INFO);
    return this.tc(Neutral.TEXT_SUB);
  }

  build() {
    Row({ space: 5 }) {
      Circle({ width: 5, height: 5 }).fill(this.tc(this.fg()))
      Text(this.text)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(this.fg()))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 9, right: 9, top: 3, bottom: 3 })
    .backgroundColor(this.tc(this.bg()))
    .borderRadius(Radius.PILL)
    .clip(true)
    // themeTick 恒读钩子：深色换血后驱动本组件重建（值恒为 1，无视觉影响）
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 分类标签 ==================== */

@Component
export struct CfCatBadge {
  text: string = '';
  // 留空 = 跟随主题（每次 build 现取 static 值，响应深色换血）。
  // 不能直接 `bg: string = Brand.PRIMARY_PALE` —— 成员字段初值只在
  // 组件构造时求值一次，ThemePalette.applyDark() 换血不会回灌。
  bg: string = '';
  fg: string = '';
  /** 主题重建钩子：static 色值不响应，深色换血必须靠它触发重建（见 CfPill 注释） */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private bgValue(): string {
    return this.bg.length > 0 ? this.bg : this.tc(Brand.PRIMARY_PALE);
  }

  private fgValue(): string {
    return this.fg.length > 0 ? this.fg : this.tc(Brand.PRIMARY_DEEP);
  }

  build() {
    Text(this.text)
      .fontSize(FontSize.SMALL)
      .maxFontScale(FontSize.SCALE_TEXT)
      .fontColor(this.tc(this.fgValue()))
      .fontWeight(FontWeight.Medium)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 9, right: 9, top: 3, bottom: 3 })
      .backgroundColor(this.tc(this.bgValue()))
      .borderRadius(Radius.SM)
      // themeTick 恒读钩子：深色换血后驱动本组件重建
      .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 区块标题 ==================== */

@Component
export struct CfSection {
  /*
   * ⚠️ 必须是 @Prop（与 CfListRow 同款教训）：普通成员不跟随父级更新，
   * 父组件重建（如深色换肤）后子组件拿不到新值、也不会重渲染。
   * @Prop 同步即触发重渲染，标题色值（tc 取 static）随之强制重取。
   */
  @Prop title: string = '';
  @Prop more: string = '';
  /** 主题重建钩子：色条与「更多」文案取 static 值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  onMoreTap?: () => void;

  /**
   * 全局碳情绪档位（响应式）。
   * 组件层订阅全局档位，二三级页面的色条 / 「更多」文案会随一级页面
   * 的排放状态一起换色 —— 否则一级已变红、二级还是绿，像换了个应用。
   */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  build() {
    Row() {
      // 用 Row 画左侧色条，避免 @Builder 内 Rectangle 的解析歧义
      Row()
        .width(3)
        .height(14)
        .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
        .borderRadius(2)
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
      Text(this.title)
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .margin({ left: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (this.more.length > 0) {
        Text(this.more)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .maxLines(1)
          .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
          .onClick((): void => {
            if (this.onMoreTap !== undefined) this.onMoreTap!();
          })
      }
    }
    .width('100%')
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/**
 * 空态插画表：code → 卡通 emoji。
 * 只收「情绪位」的常用语义；表里没有的 code、或显式 line 的空态，
 * 都回落到线稿图标，不会开天窗。
 */
const EMPTY_ART: Record<string, string> = {
  'sprout': '🌱',
  'badge': '🏅',
  'book': '📚',
  'bulb': '💡',
  'calendar': '📅',
  'coin': '💎',
  'device': '📱',
  'folder': '📁',
  'home': '🏡',
  'inbox': '📭',
  'lock': '🔒',
  'mall': '🛍️',
  'note': '📄',
  'pie': '🥧',
  'receipt': '🧾',
  'star': '⭐',
  'target': '🎯',
  'ticket': '🎟️',
  'up': '📈'
}

/* ==================== 空态 ==================== */

@Component
export struct CfEmpty {
  // ⚠️ @Prop：普通成员不跟随父级更新（同 CfStatTile 教训）
  /** 空态主图标 code（IconMap 的 ui 表） */
  @Prop icon: string = 'sprout';
  @Prop text: string = '暂无数据';
  @Prop sub: string = '';
  /**
   * 指引型空态：改用线稿图标。
   * 默认空态是「情绪位」，用卡通插画接住用户；但有些空态的重点不是安慰，
   * 而是「告诉下一步做什么」（拍照识别、去兑换证书）——这类用线稿更克制，
   * 不会把注意力从行动指引上引开。
   */
  @Prop line: boolean = false;
  /** 主题重建钩子：空态文字取 static 色值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /**
   * 空态插画位：卡通 emoji。
   * 与全站线稿图标的分工（见 ui/Icon.ets 头注释）：
   *   · 线稿负责「结构与操作」，需要跟主题同色；
   *   · 空态是「情绪位」——整页没有内容时，需要一个有温度的东西接住用户。
   * 表里没有的 code 返回 ''，回落到线稿图标，新增空态不会开天窗。
   */
  private art(): string {
    const v: string | undefined = EMPTY_ART[this.icon]
    return v !== undefined ? v : ''
  }

  build() {
    Column({ space: 8 }) {
      if (!this.line && this.art().length > 0) {
        Text(this.art())
          .fontSize(40)
          .maxFontScale(FontSize.SCALE_NUM)
      } else {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 40,
          color: this.tc(Neutral.TEXT_MUTED)
        })
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ top: 40, bottom: 40 })
    .alignItems(HorizontalAlign.Center)
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 数据小卡 ==================== */

@Component
export struct CfStatTile {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  /*
   * ⚠️ 全部字段必须是 @Prop（2026-10-24 记录页合计不刷新的根因）：
   * ArkUI 单向数据流只对 @Prop/@Link/@ObjectLink 生效，**普通成员**
   * 只在子组件创建时从父组件拷一次初值，之后父组件重新渲染传进来的
   * 新值既不同步也不触发重建（同 CfListRow 的教训）——记录页切筛选后
   * sumKg/sumPoints 变了，三宫格却停在旧数字，就是栽在这里。
   */
  @Prop label: string = '';
  @Prop value: string = '';
  /** 指标名前的小图标 code（IconMap 的 ui 表），原先是 emoji */
  @Prop icon: string = '';
  @Prop accent: string = '';
  @Prop tint: string = '';
  /** 主题重建钩子：tint/accent 都是 static 色值，深色换血必须靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private accentValue(): string {
    return this.accent.length > 0 ? this.accent : this.tc(Brand.PRIMARY);
  }

  private tintValue(): string {
    return this.tint.length > 0 ? this.tint : this.tc(Brand.PRIMARY_PALE);
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 14,
          color: this.tc(this.accentValue())
        })
        Text(this.label)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(this.value)
        .fontSize(FontSize.HEADING)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(this.accentValue()))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    /*
     * ⚠️ 宽度策略（这里踩过一个坑，务必保留注释）：
     *
     * ArkUI 的 `layoutWeight` 是**按父容器主轴方向**生效的，没有「只对某一轴加权」：
     *   · 父是 Row   → 主轴水平 → 均分宽度
     *   · 父是 Column → 主轴垂直 → **子节点被纵向拉伸**
     *
     * 本组件的通用用法是 `Row > Column().layoutWeight(1) > CfStatTile`
     * （MinePage / BackupManagePage / LevelTreePage 等 10+ 处都这么写）。
     * 若把 layoutWeight 加在本组件上，当父容器是那层 Column 时，
     * 它会被**纵向撑满** —— 四宫格直接变成两条垂到底的色带、内容全挤没
     *（用户反馈「我的页面出现 UIbug」，截图即此现象）。
     *
     * 因此本组件**自身不带 layoutWeight**，只用 width('100%')：
     * 高度由内容决定（安全），宽度填满父容器 —— 而父层 Column 已经
     * 用 layoutWeight(1) 把宽度分好了。
     * 需要三宫格均分宽度时，调用方用 `Column().layoutWeight(1)` 包裹即可
     * （全库统一范式，见 RecordListPage.Summary）。
     */
    .width('100%')
    .padding(Space.MD)
    .backgroundColor(this.tc(this.tintValue()))
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .clip(true)
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 进度条 ==================== */

@Component
export struct CfProgress {
  // ⚠️ @Prop：普通成员不跟随父级更新（同 CfStatTile 教训），
  // 进度条百分比变化必须能同步进来。
  @Prop percent: number = 0;
  /**
   * 进度条颜色。
   * 留空则**自动跟随全局碳档位**（二三级页面的进度条不再一律是品牌绿）。
   * 需要固定色的场景（如头卡内白条）仍可显式传值覆盖。
   */
  color: string = '';
  barHeight: number = 7;
  /** 主题重建钩子：轨道色取 static 值（Neutral.SURFACE），深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  /** 轨道色；留空则每次 build 现取 Neutral.SURFACE（响应深色换血） */
  track: string = '';

  /** 全局碳情绪档位（响应式） */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 实际生效的轨道色 */
  private trackValue(): string {
    return this.track.length > 0 ? this.track : this.tc(Neutral.SURFACE);
  }

  /** 实际生效的颜色：未指定时取档位主色 */
  private barColor(): string {
    return this.color.length > 0 ? this.color : this.tc(EcoTheme.primary(this.ecoLevel))
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(this.barHeight)
        .backgroundColor(this.tc(this.trackValue()))
        .borderRadius(Radius.PILL)
      Row()
        .width(Math.max(2, Math.min(100, this.percent)) + '%')
        .height(this.barHeight)
        .backgroundColor(this.tc(this.barColor()))
        .borderRadius(Radius.PILL)
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    }
    .width('100%')
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 关闭按钮 ==================== */

/**
 * 关闭按钮（矢量叉号）
 * ------------------------------------------------------------------
 * 叉号演进史（每一代都被用户截图锤过「重影」，最终收敛到 Line 方案）：
 *  ① Text('✕') / Text('×') —— 字体回退 + 合成加粗 → 灰色毛边/错位重影；
 *  ② SymbolGlyph('sys.symbol.xmark') —— 预览器热更新不清旧图层，符号残影叠加；
 *  ③ Path + getUIContext().vp2px() —— 热更新下 vp2px 返回脏值，
 *    旧帧残影与新生 Path 错位叠出「一大一小两个 X」（2026-10-19 截图实锤）；
 *  ④ 最终：两条 Line 几何线段，坐标取 btnSize 的 vp 比例、不调 vp2px，
 *    渲染管线里不存在「第二笔画」。
 *
 * ⚠️ 组件由 CfCloseBtn 改名为 CfCloseIcon（2026-10-19）：
 *   预览器热更新按「组件类型 + 节点身份」复用旧渲染层，③ 的残帧一直
 *   挂在同名组件的旧节点上反复出现。整体改名 = 全新组件类型 = 全新节点，
 *   旧缓存图层无处附着，热更新后也必然从零绘制。
 */
@Component
export struct CfCloseIcon {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  /** 点击回调 */
  onTap?: () => void;
  /** 叉号颜色，默认次级文字色；留空则每次 build 现取（响应深色换血） */
  color: string = '';
  /** 圆形底色，默认卡片浅灰；留空则每次 build 现取（响应深色换血） */
  bg: string = '';
  /**
   * 主题重建钩子（深色换血的驱动源）。
   * ⚠️ 上面「留空则每次 build 现取（响应深色换血）」这句注释，
   *   前提是**组件真的会重新 build** —— 而 static 色值不响应，
   *   不订阅 themeTick 就只在构造时求值一次。现补上订阅，注释才成立。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private colorValue(): string {
    return this.color.length > 0 ? this.color : this.tc(Neutral.TEXT_SUB);
  }

  private bgValue(): string {
    return this.bg.length > 0 ? this.bg : this.tc(Neutral.SURFACE);
  }
  /**
   * 触控热区直径（vp）。
   * ⚠️ 属性名不能叫 size：CustomComponent 基类已有同名的
   * size() 通用属性（链式调用方法），声明 number 会与之类型冲突，
   * 编译报 "Property 'size' is not assignable to the same property
   * in base type 'CustomComponent'"。改名 btnSize 规避。
   */
  btnSize: number = 32;
  /** 是否带圆形底色；false 时只画叉号（如答题对错标记） */
  showBg: boolean = true;
  /**
   * 液态玻璃圆形底（配合 showBg=true）。
   * 用于半模态面板标题栏的关闭钮：与面板玻璃材质统一，
   * 底色透出面板模糊内容。默认 false 保持既有实色底。
   */
  glass: boolean = false;

  /**
   * 叉号笔画：用两条 Line 几何线段（主对角线 + 副对角线）绘制。
   *
   * ⚠️ 重影教训（用户多次红圈反馈同一症状）：
   *   ① Text('✕')/('×') —— 字体回退 + 合成加粗 → 灰色毛边/错位重影；
   *   ② SymbolGlyph —— 预览器热更新不清旧图层，符号残影与新帧叠加；
   *   ③ Path + getUIContext().vp2px —— 预览器热更新下 vp2px 常返回脏值，
   *      旧图层残影与新生 Path 错位叠出重影（整条「缝」）。
   * 共同点：要么走文本/符号引擎（引擎层管不住笔画），要么依赖 vp2px
   * （预览器热更新脏值）。
   *
   * 现改为两条 Line，**坐标用 btnSize 的 vp 比例、不调用 vp2px**：
   * 线段在组件本地坐标系内绘制，缩放无关、热更新无残影可能，
   * 渲染管线里不存在「第二笔画」的物理可能。这是彻底去重影的终解。
   */
  @Builder
  Arms() {
    Stack() {
      Line()
        .width(this.btnSize)
        .height(this.btnSize)
        // ⚠️ 本 SDK 的 Line.startPoint/endPoint 形参是 Array<number>（[x, y]），
        //    不是 {x, y} Point 对象（否则报 "not assignable to parameter of type 'any[]'"）。
        .startPoint([this.btnSize * 0.30, this.btnSize * 0.30])
        .endPoint([this.btnSize * 0.70, this.btnSize * 0.70])
        .strokeWidth(2)
        .stroke(this.tc(this.colorValue()))
        .strokeOpacity(1)
        .antiAlias(true)
      Line()
        .width(this.btnSize)
        .height(this.btnSize)
        .startPoint([this.btnSize * 0.70, this.btnSize * 0.30])
        .endPoint([this.btnSize * 0.30, this.btnSize * 0.70])
        .strokeWidth(2)
        .stroke(this.tc(this.colorValue()))
        .strokeOpacity(1)
        .antiAlias(true)
    }
    .width(this.btnSize)
    .height(this.btnSize)
  }

  build() {
    if (this.glass && this.showBg) {
      // 玻璃分支：半透明底 + 实时背景模糊（与 CfGlassDisc 同款材质）
      Stack() {
        this.Arms()
      }
      .width(this.btnSize)
      .height(this.btnSize)
      // Stack 用 alignContent 统一居中（Stack 没有 justifyContent）
      .alignContent(Alignment.Center)
      .borderRadius(this.btnSize / 2)
      // 同 CfGlassDisc：135° 统一光照，投影落右下
      .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.DISC_BG), GlassTier.PILL, '', 1)))
      .backdropBlur(GlassLight.blurScaled(Glass.DISC_BLUR))
      .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
      // themeTick 恒读钩子：深色换血后驱动本组件重建
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    } else {
      Stack() {
        this.Arms()
      }
      .width(this.btnSize)
      .height(this.btnSize)
      // Stack 用 alignContent 统一居中（Stack 没有 justifyContent）
      .alignContent(Alignment.Center)
      .borderRadius(this.btnSize / 2)
      .backgroundColor(this.showBg ? this.tc(this.bgValue()) : 'rgba(0,0,0,0)')
      // themeTick 恒读钩子：深色换血后驱动本组件重建
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    }
  }
}

/* ==================== 顶部标题栏 ==================== */

/**
 * 二级页返回箭头（矢量两条 Line，不用字符 '‹'）
 * ------------------------------------------------------------------
 * 用户反馈：「在深色模式二级菜单左上角，推出符号自动变成黑色，不然看不见」。
 *
 * 根因不是配色写错，而是**字符 '‹' (U+2039) 走字体回退**：
 * 它不在中文字体字库里，ArkUI 用系统 fallback 字体补字形，
 * 而 fallback 字形在部分设备/深色模式下**不继承 fontColor**，
 * 直接以系统默认黑绘制 —— 于是浅色下看着正常（黑字浅底），
 * 切深色后仍是黑字压在深色玻璃上，彻底看不见。
 * （与 CfCloseIcon 记录的「文字/符号引擎管不住笔画」是同一类问题。）
 *
 * 终解同 CfCloseIcon：**用两条 Line 画 chevron**，颜色由 stroke 显式给出，
 * 渲染管线里不存在「第二个字形」可以偷偷用别的颜色。
 * 坐标取 size 的 vp 比例、不调 vp2px，缩放无关、热更新无残影。
 */
@Component
export struct CfBackIcon {
  /**
   * 主题重建钩子（深色换血的驱动源）。
   * static 色值不响应，必须订阅 themeTick 才会重新 build 取新色。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /** 图标边长（vp） */
  iconSize: number = 30;
  /** 箭头颜色；留空则每次 build 现取（响应深色换血） */
  color: string = '';
  /** 点击回调 */
  onTap?: () => void;
  /**
   * 指向右侧（列表行末端的 '›' 箭头）。
   * 同为矢量绘制 —— 字符 '›' 同样走字体回退，深色下可能不继承 fontColor。
   */
  pointRight: boolean = false;

  /** 实际描边色 */
  private strokeColor(): string {
    return this.color.length > 0 ? this.color : this.tc(Neutral.TEXT);
  }

  build() {
    Stack() {
      // 上半笔
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint(this.pointRight
          ? [this.iconSize * 0.40, this.iconSize * 0.24]
          : [this.iconSize * 0.60, this.iconSize * 0.24])
        .endPoint(this.pointRight
          ? [this.iconSize * 0.62, this.iconSize * 0.50]
          : [this.iconSize * 0.38, this.iconSize * 0.50])
        .strokeWidth(2.2)
        .stroke(this.tc(this.strokeColor()))
        .strokeOpacity(1)
        .antiAlias(true)
      // 下半笔
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint(this.pointRight
          ? [this.iconSize * 0.62, this.iconSize * 0.50]
          : [this.iconSize * 0.38, this.iconSize * 0.50])
        .endPoint(this.pointRight
          ? [this.iconSize * 0.40, this.iconSize * 0.76]
          : [this.iconSize * 0.60, this.iconSize * 0.76])
        .strokeWidth(2.2)
        .stroke(this.tc(this.strokeColor()))
        .strokeOpacity(1)
        .antiAlias(true)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}

@Component
export struct CfTopBar {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  title: string = '';
  showBack: boolean = true;
  onBack?: () => void;
  /**
   * 主题/画质变更信号（恒读钩子）。
   * 玻璃模糊半径经 GlassLight.blurScaled 按档位缩放，
   * 而 GlassLight.quality 是 static 字段（ArkTS 静态字段不响应），
   * 不订阅 themeTick 就不会重建，切档位时模糊不变。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  build() {
    Row() {
      if (this.showBack) {
        // 返回符用矢量箭头（CfBackIcon），不用字符 '‹'：
        // '‹' 走字体回退时可能不继承 fontColor → 深色下渲染成黑、看不见
        // （用户截图反馈「深色模式二级菜单左上角返回符号自动变成黑色」）。
        CfBackIcon({
          iconSize: 30,
          color: this.tc(Neutral.TEXT),
          onTap: (): void => {
            if (this.onBack !== undefined) this.onBack!();
          }
        })
      } else {
        Blank().width(4)
      }
      Text(this.title)
        .fontSize(FontSize.HEADING)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .margin({ left: 4 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: Space.PAGE, right: Space.PAGE })
    // 液态玻璃标题栏：半透明底 + 实时背景模糊，页面内容滚到栏下会被真实虚化；
    // （旧实现用 backgroundBlurStyle 系统材质，只糊系统壁纸不糊滚动内容，
    // 像一层贴纸；backdropBlur 才是「活」的玻璃）
    // ⚠️ 全局光照口径：底面走 135° 合成渐变（底色 + 左上白光 + 右下内阴影），
    // 与全库卡片/药丸同一条对角轴 —— 标题栏是二级页面最显眼的玻璃面，
    // 此前平涂底色会让「光从哪来」在一屏内出现两种答案。
    .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.TOPBAR_BG), GlassTier.PILL, '', 1)))
    .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT))
    // themeTick 恒读钩子：档位切换后重建（值恒为 1）
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
  }
}

/* ==================== 按钮 ==================== */

@Component
export struct CfButton {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  text: string = '';
  /** 按钮文字前的小图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  primary: boolean = true;
  /** block=true 时撑满父容器；用于独占一行的场景 */
  block: boolean = false;
  /** flex=true 时占满 Row 剩余空间；用于「次要按钮 + 主按钮」并排 */
  flex: boolean = false;
  /** 主题重建钩子：按钮底/字色取 static 值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  onTap?: () => void;

  /** 按下态：按钮按下轻缩 96%、松手回弹（苹果按压手感） */
  @State private pressed: boolean = false

  /**
   * 全局碳情绪档位（响应式）。
   * 按钮主色跟随档位：超阈值时主按钮由薄荷绿转珊瑚红，
   * 二三级页面的「下一步 / 提交 / 分享」等操作色与一级页面警示态一致。
   */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 主按钮投影：染色跟随档位，不一律用品牌绿 */
  private themeShadow(): ShadowOptions {
    return {
      radius: 18,
      color: this.tc(EcoTheme.shadowColor(this.ecoLevel)),
      offsetX: 0,
      offsetY: 6
    }
  }

  /**
   * 按钮内容 + 外观
   * ------------------------------------------------------------------
   * flex / block 两种撑满方式语义不同，拆成独立分支而不是用条件表达式：
   *   · flex  → layoutWeight(1)，按 Row **剩余空间**分配（并排按钮用）
   *   · block → width('100%')，撑满父容器（独占一行用）
   * 不能写成 layoutWeight(this.flex ? 1 : undefined)：
   * 1) ArkUI 的 '100%' 参照的是父容器宽度而非剩余空间，早期实现用
   *    width('100%') 做 flex，导致「关闭」(96 最小宽) + 主按钮(父宽) + space
   *    远超父 Row，主按钮被整体挤出屏幕右边缘（分享按钮只剩左半截）。
   * 2) layoutWeight 传 0 时 ArkUI 仍可能让子项参与分配（见 Index.ets 注释），
   *    所以 flex=false 时干脆不调用 layoutWeight，走独立分支。
   */
  @Builder
  ButtonBody(full: boolean) {
    Row({ space: 6 }) {
      if (this.icon.length > 0) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 16,
          color: this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel))
        })
          .flexShrink(0)
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .maxLines(1)
        // 按钮文字不换行：否则并排时「关闭」会被挤成两行
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minWidth: 0 })
    }
    .justifyContent(FlexAlign.Center)
    .height(44)
    // 主按钮底色跟随碳档位：超阈值时按钮变珊瑚红，与一级页面警示色一致
    .backgroundColor(this.primary ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Glass.CARD_BG))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(Radius.PILL)
    .shadow(this.primary ? this.themeShadow() : Shadow.none())
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .clip(true)
    /*
     * 苹果按压手感（AppleMotion 口径，见 PRESS_SCALE / PRESS_MS / spring）：
     *   按下 —— 100ms 内缩到 96%，**必须即时**：视觉反馈与触摸事件同帧，
     *           晚一帧用户就觉得「这个按钮是假的」；
     *   松手 —— 弹簧回弹（350ms / 0.75 阻尼），在 100% 附近一次极轻过冲，
     *           这就是 iOS 按钮「活」的来源。原 140ms EaseInOut 双向同参，
     *           是「机械到位」，没有回弹。
     * scale 是纯绘制属性，不影响布局与命中。
     */
    .scale({ x: this.pressed ? AppleMotion.PRESS_SCALE : 1, y: this.pressed ? AppleMotion.PRESS_SCALE : 1 })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    // 保险丝：页面重新可见时强制复位（同 CfListRow，防冻结缩小）
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
    // block 独占一行：撑满父容器。非撑满则保留 96 最小宽 + 22 内边距，
    // 保证文字不被兄弟按钮挤没。
    .width(full ? '100%' : 'auto')
    .padding({ left: full ? 0 : 22, right: full ? 0 : 22 })
    .constraintSize({ minWidth: full ? 0 : 96 })
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }

  build() {
    if (this.flex) {
      // flex 分支交给 CfButtonFlexBody：只有它内部才调用 layoutWeight(1)，
      // 避免非 flex 路径出现 layoutWeight(0)（ArkUI 下不可靠）。
      CfButtonFlexBody({
        text: this.text,
        icon: this.icon,
        primary: this.primary,
        onTap: this.onTap
      })
    } else {
      this.ButtonBody(this.block)
    }
  }
}

/**
 * 按钮内容 + 外观（flex 分支专用）
 * ------------------------------------------------------------------
 * 与 ButtonBody 拆开是因为 layoutWeight 只能在 flex 分支里调用：
 * ArkUI 下 layoutWeight(0) 仍可能让子项参与剩余空间分配（见 Index.ets 注释），
 * 所以非 flex 路径干脆不碰 layoutWeight。
 */
@Component
struct CfButtonFlexBody {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  text: string = '';
  /** 按钮文字前的小图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  primary: boolean = true;
  onTap?: () => void;
  /** 按下态：与 CfButton 主分支同一按压口径（轻缩 96%） */
  @State private pressed: boolean = false

  /** 全局碳情绪档位（响应式），与 CfButton 保持同一取色口径 */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'
  /** 主题重建钩子：底/边框色取 static 值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  build() {
    Row({ space: 6 }) {
      if (this.icon.length > 0) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 16,
          color: this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel))
        })
          .flexShrink(0)
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minWidth: 0 })
    }
    .justifyContent(FlexAlign.Center)
    .height(44)
    .backgroundColor(this.primary ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Glass.CARD_BG))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(Radius.PILL)
    .shadow(this.primary ? {
      radius: 18,
      color: this.tc(EcoTheme.shadowColor(this.ecoLevel)),
      offsetX: 0,
      offsetY: 6
    } : Shadow.none())
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .clip(true)
    // 苹果按压手感：与 CfButton 主分支同一 AppleMotion 口径
    // （按下 100ms 缩到 96% 即时响应，松手瞬时归位 —— 严禁长回弹动画，
    //  否则 push 转场挂起回弹 → scale 冻结在中间值，见 CfListRow 处说明）
    .scale({ x: this.pressed ? AppleMotion.PRESS_SCALE : 1, y: this.pressed ? AppleMotion.PRESS_SCALE : 1 })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    // 保险丝：页面重新可见时强制复位（同 CfListRow，防冻结缩小）
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
    // flex 语义 = 占满 Row 剩余空间，唯一正确写法是 layoutWeight
    .layoutWeight(1)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}

/* ==================== 列表行 ==================== */

@Component
export struct CfListRow {
  /**
   * ⚠️ 这几个字段必须是 @Prop 而不是普通成员：
   *   ArkUI 单向数据流只对 @Prop/@Link/@ObjectLink 生效，普通成员
   *   **不会跟随父级更新**。而本组件在 MinePage 等处被放在 ForEach 里，
   *   key 是稳定的标题/文案 → 父级数据变了，行组件会被**复用**，
   *   普通成员里的旧值会一直留着（用户截图：兑换成功后「碳惠券包 N 张」
   *   角标不刷新）。改成 @Prop 后父级赋值即同步到行内。
   */
  /**
   * 左侧图标 code（语义键，见 IconMap 的 ui 表）。
   *
   * 2026-10 由 emoji 字符串迁移为 Tabler 矢量图标：
   *   · emoji 各机型字体回退不一致（♻️ U+267B+FE0F 与 ♻ U+267B 是两个码位，
   *     历史数据里两种写法都出现过，按字符查表必挂）；
   *   · emoji 自带颜色，无法跟随主题高亮/深色模式。
   */
  @Prop icon: string = '';
  /** 图标语义色（Theme.IconTone）；留空 = 默认文字色 */
  @Prop tone: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop right: string = '';
  // 留空 = 跟随主题（每次 build 现取），避免深色模式不换肤
  @Prop rightColor: string = '';
  /** 主题重建钩子：title/sub/right 颜色均取 static 值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  @Prop showArrow: boolean = true;
  onTap?: () => void;
  /** 按下态：可点击行按下轻缩、松手回弹（苹果按压手感，与 GlassPanel 同一语言） */
  @State private pressed: boolean = false

  private rightColorValue(): string {
    return this.rightColor.length > 0 ? this.rightColor : this.tc(Neutral.TEXT_SUB);
  }

  build() {
    Row({ space: Space.MD }) {
      if (this.icon.length > 0) {
        Stack() {
          CfIcon({ kind: 'ui', code: this.icon, iconSize: 20, tone: this.tone })
        }
        .width(38)
        .height(38)
        .backgroundColor(this.tc(Brand.PRIMARY_PALE))
        .borderRadius(Radius.SM)
      }
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.right.length > 0) {
        Text(this.right)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(this.rightColorValue()))
          .maxLines(1)
      }
      if (this.showArrow) {
        // '›' 同样走字体回退（深色下可能不继承 fontColor）→ 改用矢量箭头
        CfBackIcon({
          iconSize: 18,
          color: this.tc(Neutral.TEXT_MUTED),
          pointRight: true
        })
      }
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    //（此前只声明未引用，ArkUI 最小化更新下永不重建，
    // 深色模式标题停留浅色套值 #2E3A36，压深底上直接隐形）
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
    /*
     * 苹果按压手感（AppleMotion 口径，与 CfButton 完全一致）：
     *   按下 100ms 缩到 96%（即时），松手**瞬时归位**（duration 0）。
     * ⚠️ 松手回弹严禁 spring()/长时动画（2026-10-24 用户视频实测 bug）：
     *   点击行 → onClick 立刻 push 子页面 → 本页隐藏，350ms 弹簧回弹
     *   被页面转场挂起丢弃 → 返回时 scale 冻结在半路（如 0.97），
     *   每进出一次累积一次 →「我的低碳资产 5 张卡越点越小」；
     *   首页看板「随机变大变小」同根因（弹簧过冲冻在 >1 处即变大）。
     *   瞬时归位没有任何可被挂起的动画，冻结从机制上不可能发生。
     * 可点击行（onTap 已挂）才缩；纯展示行不缩 —— 不可点的元素
     * 不该有按压反馈，那是错误示能（affordance）。
     * ⚠️ scale 是纯绘制属性，不影响布局与滚动命中。
     */
    .scale({
      x: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1,
      y: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1
    })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (this.onTap === undefined) return;
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    // 保险丝：返回本页重新可见时若 pressed 因异常未复位（Up/Cancel 被
    // 页面转场吞掉），强制归位 —— 杜绝「行冻在 96% 不回来」
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
  }
}

/* ==================== 开关设置行 ==================== */

/**
 * 设置行 + 右侧开关（深色模式 / 重新渲染用）。
 * ------------------------------------------------------------------
 * 与 CfListRow 同一视觉语言（emoji 方块 + 标题/副标题 + 右侧控件），
 * 区别只在右侧由「文案 + 箭头」换成 Toggle 开关。
 * 选中色跟随品牌薄荷绿，未选轨道用系统默认。
 */
@Component
export struct CfSwitchRow {
  /*
   * ⚠️ 三个文案必须是 @Prop（与 CfListRow 同款教训）：
   * 普通成员只在组件首次构造时赋值一次，父组件重建不会同步 ——
   * 深色开关拨动后父组件已把 sub 换成「深炭绿界面…」，本组件却
   * 仍显示首次构造时的「奶油白界面…」旧文案（2026-10-21 用户截图实锤）。
   * @Prop 随父级同步，且同步本身触发本组件重渲染，
   * 标题/副标题色值（tc 取 static）一并强制重取。
   */
  /** 左侧图标 code（IconMap 的 ui 表），原先是 emoji */
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  /** 主题重建钩子：标题/副标题取 static 值，深色换血靠它触发重建 */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  /**
   * 开关当前状态。
   * ⚠️ 必须是 @Prop（2026-10-20 修复「深色开关拨上去自动弹回」）：
   * 普通成员只在组件**首次构造**时赋值一次，父组件重建不会同步。
   * 而本组件自带 @StorageProp('themeTick') —— 用户拨开关 → setDark →
   * bumpRender 推进 themeTick → 本组件必然重渲染 → Toggle({ isOn: this.on })
   * 用的是过期旧值，开关被重置回旧状态。深色模式因此永远「打开自动关闭」。
   * @Prop 才能在父组件 darkOn 变化时同步进来，Toggle 跟随真实状态。
   */
  @Prop on: boolean = false;
  /** 开关变化回调（回传新状态） */
  onChange?: (isOn: boolean) => void;

  build() {
    Row({ space: Space.MD }) {
      Stack() {
        CfIcon({ kind: 'ui', code: this.icon, iconSize: 20 })
      }
      .width(38)
      .height(38)
      .backgroundColor(this.tc(Brand.PRIMARY_PALE))
      .borderRadius(Radius.SM)
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.on })
        .selectedColor(this.tc(Brand.PRIMARY))
        .onChange((isOn: boolean): void => {
          if (this.onChange !== undefined) this.onChange!(isOn);
        })
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    // themeTick 恒读钩子：深色换血后驱动本组件重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/* ==================== 玻璃圆盘 ==================== */

/**
 * 玻璃圆盘（液态玻璃圆形元素）
 * ------------------------------------------------------------------
 * 苹果液态玻璃里圆形元素（头像、图标徽标、圆形按钮）的三要素：
 *   · 半透明底 + 实时背景模糊 —— 后方内容从圆盘里穿过被虚化；
 *   · 1px 细亮描边 —— 玻璃的厚度感；
 *   · 正圆大圆角 + 紧致投影 —— 浮在内容之上。
 *
 * 面积小（通常 ≤ 120vp），实时模糊的离屏开销可接受；
 * 调用方只传直径与内容（emoji / 图标 / 头像），玻璃细节全部收敛在此。
 */
@Component
export struct CfGlassDisc {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  /**
   * 主题/画质变更信号（恒读钩子）。
   * 玻璃模糊半径经 GlassLight.blurScaled 按档位缩放，
   * 而 GlassLight.quality 是 static 字段（ArkTS 静态字段不响应），
   * 不订阅 themeTick 就不会重建，切档位时模糊不变。
   */
  @StorageProp('themeTick') private themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /** 圆盘直径（vp） */
  diameter: number = 56;
  /** 内容：emoji / 图标 / 头像组件，以尾随 lambda 形式传入 */
  @BuilderParam contentSlot: () => void = this.emptySlot;
  /** 可选强调色圆环（等级色 / 主题色），传空则不画 */
  ringColor: string = '';
  /** 点击回调（可选） */
  onTap?: () => void;

  @Builder
  emptySlot() {}

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.contentSlot()
      // 强调色圆环：内缩 4vp 的细环，与玻璃描边形成「双环」层次
      //
      // ⚠️ 必须 fill(Color.Transparent)：ArkUI 形状组件（Circle）
      // 默认填充纯黑，不写 fill 会得到一个黑色实心圆盖住 emoji/头像。
      if (this.ringColor.length > 0) {
        Circle()
          .width(this.diameter - 8)
          .height(this.diameter - 8)
          .fill(Color.Transparent)
          .stroke(this.ringColor)
          .strokeWidth(2)
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.DISC_BG), GlassTier.PILL, '', 1)))
    .backdropBlur(GlassLight.blurScaled(Glass.DISC_BLUR))
    // themeTick 恒读钩子：档位切换后重建（值恒为 1）
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(this.diameter / 2)
    // 投影跟随主光源落右下，与卡片/顶栏同一方向
    .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
    .clip(true)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}