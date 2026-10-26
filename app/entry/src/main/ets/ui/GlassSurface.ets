/**
 * 玻璃表面组件（统一光照模型的落地载体）
 * ------------------------------------------------------------------
 * 所有玻璃面必须走这两个组件，不允许页面自己叠渐变「画高光」——
 * 光照参数全部来自 GlassLight，保证全库方向一致。
 *
 * GlassPanel  内容面板（文章卡 / Hero / 测验入口 / 空态 / 弹窗）
 * GlassPill   小胶囊（分类 chip / 收藏钮 / 分段药丸）
 *
 * 每层玻璃的光照栈（自底向上）：
 *   ① 接触纱    —— 亮背景下的暗色 anchor，托住文字对比度（可读性）
 *   ② 对角光染  —— 135° 主光源：左上受光反射 + 右下内阴影（厚度）
 *   ③ 顶边菲涅尔 —— 顶部 13% 的亮→透明衰减（边缘反射）
 *   ④ 左边菲涅尔 —— 左侧 13% 的亮→透明衰减（边缘反射）
 *   ⑤ 内容      —— 永远在最上，光照不压文字（可读性优先）
 *   外加：1px 四边异色描边（上/左白 = 受光，下/右深 = 背光）
 *         + 右下的外投影（与内阴影同向，接触感）
 *         + 可选的 backdropBlur（仅小面积元素，card 档永不模糊）
 */
import { GlassLight, GlassPress, GlassTier, GlassQualityLevel } from './GlassLight';
import { Brand, Radius, ThemePalette } from './Theme';
import { AppleMotion } from './AppleMotion';

/**
 * 玻璃光照层栈（全局 Builder）。
 * ------------------------------------------------------------------
 * 供 GlassPanel / GlassPill 复用，也供 Index.ets 底部胶囊这类
 * 特殊布局直接嵌入（放在内容之下、容器底色之上）。
 *
 * 自底向上：接触纱 → 对角光染(含内阴影) → 顶边菲涅尔 → 左边菲涅尔
 *           →（深色）文字暗纱。
 * parallax 传入当前视差位移（vp）；不跟滚动的布局传 0。
 * gloss < 1 用于实底元素（选中药丸）上的克制高光。
 * textScrimOn 控制深色文字暗纱：实底元素（品牌渐变 Hero /
 * 选中药丸）传 false —— 暗纱会压脏品牌色。
 * LITE 档整栈不渲染（零叠加层降级）。
 */
@Builder
export function GlassLightLayers(tier: string, ambient: string, parallax: number, gloss: number,
  textScrimOn: boolean) {
  if (GlassLight.quality !== GlassQualityLevel.LITE) {
    // ① 接触纱：仅浅色模式的亮背景（暗底上加暗纱只会发灰）。
    //    ⚠️ 用 135° 定向渐变而非平铺色 —— 平铺暗纱会把整块玻璃蒙灰，
    //    是「不通透」的头号元凶；定向纱只在背光侧（右下）压深。
    if (GlassLight.scrimOn(ambient)) {
      Column() {}
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: GlassLight.LIGHT_ANGLE,
          colors: GlassLight.scrimColors(ambient)
        })
    }
    // ② 对角光染 + 内阴影（唯一随视差平移的光照层，纯合成层操作）
    Column() {}
      .width('100%')
      .height('100%')
      .linearGradient({ angle: GlassLight.LIGHT_ANGLE, colors: GlassLight.washColors(tier, ambient, gloss) })
      .translate({ x: parallax * 0.15, y: parallax * 0.5 })
    // ③ 顶边菲涅尔（180° = 顶→底）
    Column() {}
      .width('100%')
      .height('100%')
      .linearGradient({ angle: 180, colors: GlassLight.fresnelColors(tier, ambient, gloss) })
    // ④ 左边菲涅尔（90° = 左→右）。深色 BALANCED 按层数预算裁掉，
    //    省一层离屏合成；受光边由 1px 四边异色描边补位
    if (GlassLight.fresnelLeftOn()) {
      Column() {}
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 90, colors: GlassLight.fresnelColors(tier, ambient, gloss) })
    }
    // ⑤ 深色模式文字暗纱：压在光照之上、内容之下。
    //    定向渐变（顶浅底深）托住文字对比度，同时高光被 9%
    //    边缘带收在四周 —— 「高光避开文字」
    if (ThemePalette.dark && textScrimOn) {
      Column() {}
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: GlassLight.textScrim() })
    }
  }
}

/**
 * 玻璃内容面板。
 * 用法（尾随 lambda 传内容，与 CfCard 一致）：
 *   GlassPanel({ tier: GlassTier.CARD, corner: Radius.MD, pad: Space.MD }) {
 *     Row() { ... }
 *   }
 */
@Component
export struct GlassPanel {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  /** 材质档位：pill / card / panel（默认 card） */
  tier: string = GlassTier.CARD;
  /**
   * 环境底色：玻璃后方的颜色（页面根底色）。
   * 传空串按白色处理 —— 用于亮度自适应（受光强度 / 接触纱）。
   */
  ambient: string = '';
  /** 圆角 */
  corner: number = Radius.MD;
  /** 内容内边距（光照层铺满整卡，padding 只作用于内容） */
  pad: number = 0;
  /**
   * 是否启用实时模糊。默认 false：
   * card 档一律不开（一屏十几张卡各一层离屏渲染会掉帧），
   * 只有 panel 档大面积悬浮面板才传 true。
   */
  glass: boolean = false;
  /**
   * 自定义底色渐变（Hero 品牌大卡用）。
   * 不传则用 GlassLight 计算的半透明玻璃底色。
   */
  bgGradient: LinearGradient | undefined = undefined;
  /** 投影覆写（Hero 品牌大卡用品牌色投影）；不传则用档位默认投影 */
  shadowOverride: ShadowOptions | undefined = undefined;
  /** 点击回调；不传则不挂点击与按压反馈 */
  onTap: (() => void) | undefined = undefined;
  /** 按下轻缩幅度：卡片 0.98 / 胶囊 0.95 / 不缩 1 */
  pressScale: number = GlassPress.CARD;
  /** 是否随滚动视差平移高光（小元素与横向列表建议关） */
  parallaxOn: boolean = true;

  /** 内容插槽（尾随 lambda 传入） */
  @BuilderParam contentSlot: () => void = this.emptySlot;

  /** 按下态：白面纱 + 轻缩，松手回弹 */
  @State private pressed: boolean = false;
  /** 滚动视差（AppStorage 驱动，纯合成层平移） */
  @StorageProp('glassParallax') private parallax: number = 0;
  /**
   * 主题/画质变更信号（恒读钩子）。
   * ⚠️ 必须订阅：GlassLight.quality 与 ThemePalette.dark 都是 static 字段，
   * ArkTS 静态字段不响应。设置页切「玻璃画质」只推 themeTick，
   * 本组件不订阅就不会重建，光照层栈里的
   * `if (quality !== LITE)` 永远不重新求值 —— 表现为切了档位没反应。
   * build() 里以 `.opacity(this.themeTick >= 0 ? 1 : 0)` 恒读一次。
   */
  @StorageProp('themeTick') private themeTick: number = 0;

  @Builder
  emptySlot() {}

  /**
   * 实际铺在组件上的渐变（零子层方案的唯一底面）。
   * ------------------------------------------------------------------
   * · 普通玻璃：走 `GlassLight.surface()` 把底色 + 左上白光 + 右下内阴影
   *   合成进**一条** 135° 渐变 —— 这是「光从左上 45° 射入」的承载方式。
   * · 品牌渐变 Hero（bgGradient 传了）：保留自定义渐变作为底，
   *   不叠 wash/菲涅尔 —— 品牌实底上再压白光会把色相洗淡
   *   （原实现在 Stack 里也传了 textScrim=false，但 wash 仍会叠）。
   *   厚度改由四边异色描边 + 品牌投影承担。
   * · 画质 LITE：零光照，只留底色。
   */
  private surfaceValue(): LinearGradient {
    if (this.bgGradient !== undefined) {
      return this.bgGradient;
    }
    if (GlassLight.quality === GlassQualityLevel.LITE) {
      return this.tw(GlassLight.flat(GlassLight.tintColor(this.tier, this.ambient)));
    }
    return this.tw(GlassLight.surface(
      GlassLight.tintColor(this.tier, this.ambient), this.tier, this.ambient, 1));
  }

  build() {
    /*
     * ⚠️ **零子层方案**（2026-10 整改）：这里原来是一个 `Stack`，里面铺
     * `GlassLightLayers`（每个光照层都是 `width('100%').height('100%')`）。
     *
     * 坑：在 fit-content / 高度自适应的容器里，百分比会按**祖先约束最大值**
     * 解析，于是光照层把 Stack 撑到父容器的全部可用高度 —— 表现为
     * 「卡片巨大、占满整屏，内容被挤到中间」（科普页置顶 hero 实测）。
     * 与 GlassPill 之前撑成 210×586vp 是同一个坑，两处都必须零子层。
     *
     * 现在光照压进组件自身的 135° 渐变（`surfaceValue()`），
     * 内容是唯一子节点，尺寸必然正确 —— 与 CfCard 同一口径。
     */
    Column() {
      this.contentSlot()
    }
    .width('100%')
    .padding(this.pad)
    .linearGradient(this.surfaceValue())
    .borderRadius(this.corner)
    /*
     * 四边异色描边，**四边等宽 1vp**。
     * ⚠️ 描边宽度只能用整数：非整数（如 top: 1.5）+ borderRadius 裁剪
     *    会在描边内侧留下一条未填充的暗缝，横贯整个组件顶边 ——
     *    取证实测该暗线比上下低 12~15，视觉上就是「一条黑线/ 暗角」。
     *    厚度感改由 alpha 亮度差（上/左亮、下/右深）承担。
     */
    .border({
      width: { top: 1, left: 1, right: 1, bottom: 1 },
      color: this.tw(GlassLight.borderColors(this.tier, this.ambient, 1))
    })
    .backdropBlur(GlassLight.blurOf(this.tier, this.glass))
    // themeTick 恒读钩子：画质/深色档位切换后驱动本组件重建（值恒为 1）
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .shadow(this.shadowOverride !== undefined ? this.shadowOverride : this.tw(GlassLight.shadowOf(this.tier)))
    .clip(true)
    // 按下：白面纱 + 轻缩，松手瞬时归位（AppleMotion 口径；禁长回弹动画，
    // 否则 push 转场挂起回弹 → scale 冻结在中间值，见 Components.ets CfListRow 处说明）
    .scale({
      x: this.pressed ? this.pressScale : 1,
      y: this.pressed ? this.pressScale : 1
    })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onClick((): void => {
      if (this.onTap !== undefined) {
        this.onTap()
      }
    })
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
  }
}

/**
 * 玻璃小胶囊（分类 chip / 收藏钮）。
 * 选中态 = 品牌实底 + 品牌投影，光照层减半（实底上 gloss 要克制）；
 * 未选中 = 半透明玻璃 + 轻模糊 + 全量光照。
 */
@Component
export struct GlassPill {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  /** 内容（行内文字/图标，颜色由调用方按选中态决定） */
  @BuilderParam contentSlot: () => void = this.emptySlot;
  /**
   * 选中态。
   * ⚠️ 必须是 @Prop：普通成员只在组件**首次构造**时赋值一次，父组件
   * 重建不会同步 —— 实测后果（用户截图）：绿色高亮永远停在初始选中的
   * chip 上，点击其他 chip 后底色不动、只有插槽内文字变色，白字压在
   * 未变绿的底上直接隐形（「选中的那个看不清」）。@Prop 才会随父组件
   * 重建把新值同步进来，底色/投影/缩放才能跟随点击切换。
   */
  @Prop active: boolean = false;
  /**
   * 选中态实底色（传 EcoTheme.primary(level) 跟随碳档位）。
   *
   * ⚠️ 留空而非写死 '#3FBF9F'：留空 + 私有方法现取 Brand.PRIMARY，
   * 每次构建重新求值 —— 深色换血后自动用新色值。
   * 与 CfCard.bgColor / CfSegTrack.track 同一处理。
   * 同步机制同 active：@Prop 保证父组件传入的新值能进得来。
   */
  @Prop activeBg: string = '';
  /** 环境底色（亮度自适应用；父组件可能传随碳档位变化的 ecoBg()，须 @Prop） */
  @Prop ambient: string = '';
  /** 圆角，默认全圆胶囊 */
  corner: number = Radius.PILL;
  /** 选中回弹系数（页面 chipPop：1.08 → 150ms 归位；@Prop 才能收到回弹值） */
  @Prop popScale: number = 1;
  /** 按下轻缩幅度 */
  pressScale: number = GlassPress.PILL;
  /**
   * 是否撑满父容器宽度（默认 false = fit-content）。
   * ------------------------------------------------------------------
   * 为「分类栏按格均分」场景准备：科普页 4 个分类用 Flex 折行时，
   * fit-content 会让总宽超出容器 → Flex 把第一行**压窄**，
   * chip 被裁掉一半（实测白色 chip 左边缘外溢 5px、「减排技巧」孤行）。
   *
   * 设为 true 后药丸跟随父容器宽度，配合调用方的均分格宽使用；
   * 默认保持 fit-content，因为 chip / 收藏钮等场景都排在横向 Row 里，
   * 百分比宽会撑满整行。
   */
  fillWidth: boolean = false;
  /** 点击回调 */
  onTap: (() => void) | undefined = undefined;

  @State private pressed: boolean = false;
  /**
   * 主题/画质变更信号（恒读钩子），理由同 GlassPanel：
   * GlassLight.quality 是 static 字段，不订阅 themeTick 就不会重建，
   * 切档位时药丸的光照层栈不会重新求值。
   */
  @StorageProp('themeTick') private themeTick: number = 0;

  @Builder
  emptySlot() {}

  /** 选中态光照减半：实底上的高光必须克制，否则塑料感 */
  private gloss(): number {
    return this.active ? 0.5 : 1;
  }

  /** 选中态实底色：显式传入优先，否则现取 Brand.PRIMARY（响应深色换血） */
  private activeBgValue(): string {
    return this.activeBg.length > 0 ? this.activeBg : this.tc(Brand.PRIMARY);
  }

  private bgGradientValue(): LinearGradient {
    let tint: string = '';
    if (this.active) {
      tint = this.activeBgValue();
    } else {
      tint = this.tw(GlassLight.tintColor(GlassTier.PILL, this.ambient));
    }
    // 画质 LITE：零光照层，只留底色
    if (GlassLight.quality === GlassQualityLevel.LITE) {
      return this.tw(GlassLight.flat(tint));
    }
    // 单层合成渐变：底色 + 对角光染 + 内阴影压成一条 135° 渐变。
    // ⚠️ 不能用 Stack 叠 GlassLightLayers：药丸要 fit-content（芯片排在
    // 横向 Row 里，百分比宽会撑满整行），而光照层是 100%×100%，
    // 在自适应父容器里会按祖先约束最大值解析，把药丸撑成约 210×586vp
    // 的整屏巨块（真机实测：标题被顶到屏幕中部、右侧胶囊越界、
    // 分类栏与列表被挤没）。position() 在 Stack 里也无效。
    // 零子层方案从根上消除尺寸风险。
    return this.tw(GlassLight.pillSurface(tint, GlassTier.PILL, this.ambient, this.gloss()));
  }

  /** 选中态投影跟随品牌色；未选中用统一小投影 */
  private shadowValue(): ShadowOptions {
    if (this.active) {
      return { radius: 16, color: this.tw(GlassLight.shadowTintOf(this.activeBgValue())), offsetX: 2, offsetY: 6 };
    }
    return this.tw(GlassLight.shadowOf(GlassTier.PILL));
  }

  build() {
    // 药丸：零子层单组件。
    // 外层不设 width('100%') —— chip / 收藏钮都排在横向 Row 里，
    // 百分比宽会撑满整行；包裹内容（fit-content）才是药丸的正确尺寸。
    // 光照已由 bgGradientValue() 合成进自身渐变，故内部不再叠任何层。
    Column() {
      Column() {
        this.contentSlot()
      }
      .justifyContent(FlexAlign.Center)
    }
    .linearGradient(this.bgGradientValue())
    .borderRadius(this.corner)
    /*
     * fillWidth=true → '100%'（跟随父容器，配合调用方均分格宽）；
     * 否则传 'auto' 保持 fit-content。
     * ⚠️ 不能传 undefined：ArkTS 的 width 入参是 Length（含 undefined
     *   联合类型），但静态检查在本项目不接受该联合入参，故用 'auto'。
     */
    .width(this.fillWidth ? '100%' : 'auto')
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, this.ambient, this.gloss())) })
    // 选中态也保留模糊层：选中过程底色由半透渐变为品牌实底，
    // 模糊在场才是「玻璃慢慢凝固成品牌色」；药丸面积小，
    // 这一层离屏开销可接受（大卡片才受实底盖模糊的代价约束）
    .backdropBlur(GlassLight.blurOf(GlassTier.PILL, true))
    // themeTick 恒读钩子：画质/深色档位切换后驱动本组件重建（值恒为 1）
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .shadow(this.shadowValue())
    .clip(true)
    // 按下轻缩优先于选中回弹（同一时刻只有一种缩放意图）
    .scale({
      x: this.pressed ? this.pressScale : (this.active ? this.popScale : 1),
      y: this.pressed ? this.pressScale : (this.active ? this.popScale : 1)
    })
    .animation({ duration: 200, curve: Curve.EaseInOut })
    .onClick((): void => {
      if (this.onTap !== undefined) {
        this.onTap()
      }
    })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
  }
}
