/**
 * 统一玻璃光照模型（全库唯一定义处）
 * ------------------------------------------------------------------
 * 设计目标：让所有液态玻璃组件共享同一套「真实」的光照，
 * 而不是各页各画一层高光贴图。
 *
 * 物理模型（全部为近似，不做光线追踪）：
 *   ① 全局唯一主光源：左上 45°。所有玻璃的高光、内阴影、
 *      边缘亮边方向一致 —— 受光面在顶+左，背光面在底+右，
 *      外投影向右下（offsetX/offsetY 均 > 0）。
 *   ② 环境光自适应：玻璃后方的底色亮度（Rec.709 加权）决定
 *      白色面纱与光照的强度。亮背景收敛（不过曝），
 *      暗背景增强（不发灰）。
 *   ③ 菲涅尔边缘反射：边缘处更亮。用两层线性渐变近似 ——
 *      顶边与左边各一条「亮→透明」的衰减带，集中在 13% 边缘。
 *   ④ 高光形状与柔和度：对角光染是一条 135° 的多段渐变
 *      （亮 38% → 中性 62% → 内阴影 100%），模拟曲面反射；
 *      不是均匀发光。
 *   ⑤ 折射/厚度近似：边缘透镜效应由「亮边 + 背光边深色描边」
 *      共同营造；背景扭曲交给 backdropBlur 的真实模糊，
 *      本模型不再叠加深层模糊（性能红线，见 Glass 注释）。
 *   ⑥ 内阴影 + 外投影配合：外投影 offsetX/offsetY > 0（右下），
 *      与层①尾部的黑色内阴影同向，建立厚度感与接触感。
 *   ⑦ 动态交互：滚动时 GlassLight.nudge(dy) 累加坡视差，
 *      AppStorage('glassParallax') 驱动玻璃面高光平移
 *      （纯合成层操作，不触发布局重排）。
 *   ⑧ 可读性：亮背景下加一道暗色接触纱（scrim），
 *      防止玻璃「漂」在背景上、文字对比度不足。
 *   ⑨ 性能：GlassQuality 三档降级；card 档永不挂模糊
 *      （一屏十几张卡各一层离屏渲染会明显掉帧）。
 *
 * 用法：页面不直接算光照，只传 tier（材质档）+ ambient（环境底色），
 * 全部取值由本类计算。禁止在页面里硬编码光照参数。
 *
 * 通透度口径（2026-10 整改 · 对齐苹果 Liquid Glass）
 * ------------------------------------------------------------------
 * 靶值参照（苹果官方口径，两模式）：
 *   染色层浅色 8–14% / 深色 20–28%；1px 内描边浅色白 22% / 深色白 8%；
 *   背景模糊 30–40；饱和度提升 140–160%；高光方向角 135°。
 *   本项目受两条约束不能照抄：
 *     ① ArkUI `backdropBlur` 只有 radius + grayscale，**无饱和度滤镜**，
 *        且 card 档为性能红线永不挂模糊 → 染色层必须比苹果更实，
 *        否则深色文字压不住。0.72 是本项目浅色可读性底线。
 *     ② 折射/色散需要 WebGL/Metal，ArkUI 声明式无法表达，改为用
 *        「边缘亮带 + 背光内阴影」近似。
 *
 * 直觉陷阱：早前参数按「档位越大越浓」排列（pill 最重），
 * 但**同样的 alpha 铺在小面积上，视觉浓度远高于大卡片**——
 * 于是最小最常见的药丸反而最蒙，玻璃通透感最差。
 * 现统一改为「按面积反向取值」：pill < card < panel。
 *
 *   参数（浅色）        pill    card    panel
 *   tintAlpha 染色层   0.42    0.72    0.50
 *   washAlpha 面纱     0.10    0.11    0.13
 *   edgeAlpha 菲涅尔   0.26    0.30    0.34
 *   innerAlpha 内阴影  0.05    0.05    0.07
 *   edgeBorder 描边    0.40    0.46    0.52
 *   接触纱 scrim       亮底 0.10 / 中亮底 0.05，**且只在右下角压深**
 *
 *   参数（深色）        pill    card    panel
 *   tintAlphaDark      0.52    0.90    0.60
 *   washAlphaDark      0.10    0.05    0.07
 *   edgeAlphaDark      0.68    0.58    0.62
 *   innerAlphaDark     0.16    0.13    0.15
 *   edgeBorderDark     0.62    0.55    0.50
 *
 *   环境自适应：浅色 adapt 亮底 ×0.92（原 0.82，压过头变脏玻璃）；
 *               深色 darkAdapt 暗底 ×1.18（暗底提亮防消失）。
 *
 * 入射感（用户反馈「感觉光的位置变了」）：
 * ------------------------------------------------------------------
 *  washColors 的高光必须**集中在左上角一小段**（0 → 0.12 峰值 →
 *  0.38 收尾 → 0.55 全归零），而不是一路铺到 62%。
 *  后者是「整片玻璃在对角方向被均匀染色」，没有入射感；
 *  前者中段完全透明，玻璃中央留给背景透射 —— 这才是通透感的真正来源。
 *
 * 通透度三原则（本轮落地）：
 *   ① 染色层是主因：card 从 0.86 降到 0.72（0.86 ≈ 不透明白板）。
 *   ② 接触纱不能平铺：全幅暗纱会把白玻璃蒙灰，改为135° 定向
 *      （左上透明 → 右下压深），与主光源同向。
 *   ③ 厚度归厚度：玻璃的「厚」由 1px 背光描边 + 内阴影建立，
 *      **不是靠把面纱调亮**。面纱越亮越闷，通透度与厚度此消彼长。
 *
 * 深色模式 = 独立参数表（**不是浅色参数的反转**）：
 * ------------------------------------------------------------------
 *   基底   **白色微染** rgba(255,255,255,0.07~0.14)，不是深色染色。
 *          暗背景上玻璃必须靠「比背景亮」浮起来 —— 实算叠在页面底
 *          #111917 上得 (34,42,39)，比底亮 17 级，卡片立得住；
 *   ⚠️ 本轮推翻原「深色染色」方案（DARK_TINT = (23,36,34)）：
 *          该色与深色 Glass.CARD_BG (28,37,35) 几乎同色 → 玻璃 = 页面底，
 *          玻璃直接「消失」；暗底上唯一剩下的层次线索是内阴影，
 *          于是只能把内阴影拉到 0.153（浅色才0.02）→ 右下角一大块
 *          脏暗角，且 textScrim（顶0.16→底0.30）与之叠加，暗角翻倍。
 *          这是深色模式「很脏、暗角明显」的结构性根因，不是缺几个色值。
 *   不透明度 极低（card 0.09 / pill 0.13 / panel 0.11）：暗底提亮靠
 *          **绝对量**而非浓度，取高会变成乳白塑料板；
 *   边缘   菲涅尔权重 0.52~0.60，**上限压到 0.62**：底已是冷白微染，
 *          边缘再叠到 0.85 会烧出一圈死白亮线。厚度主要靠边缘光承担；
 *   光染   面纱减到 0.04~0.05，只负责把提亮集中到左上角（入射感），
 *          不做整体照明（tint 已贡献主要提亮）；
 *   内阴影 **0.04~0.05**（原 0.13~0.16，降 3 倍）：与浅色同量级，
 *          只做背光侧收边。白染底之上它不再压出体积，只会压脏；
 *   描边   受光边冷白 0.50~0.62；背光边从 0.10~0.12 收到 0.06~0.07 ——
 *          白染玻璃的右下若压深色 (8,14,16) 会切出一道明显暗边；
 *   暗纱   textScrim 从 顶0.16/底0.30 降到 0.02/0.08。它铺满整块玻璃、
 *          与 135° 内阴影在下半部叠加，是暗角翻倍的直接来源；
 *          文字对比度改由「玻璃比底亮17 级」保证，无需暗纱托底；
 *   自适应 背景越暗，边缘越亮（darkAdapt ×1.18）；视差幅度减半防暗底闪烁；
 *   层数   按画质档位做预算（layerBudget），LITE 全零。
 *
 *   深色对比度实测（WCAG AA 达标，正文需 ≥4.5，弱文需 ≥3）：
 *     卡片白染底 (34,42,39)：正文 5.94:1 / 副文 4.30:1 / 弱文 2.97:1
 *     底部胶囊 (29,37,35)：选中字 6.94:1 / 未选字 3.39:1
 *     科普页选中 chip (50,59,57)：选中字 4.29:1
 */

import { EcoTheme, Glass, ThemePalette } from './Theme'

/**
 * 玻璃材质档位（厚度/透明度档）。
 * 命名刻意区别于 Components.ets 的 GlassLevel（那个是「是否模糊」的开关），
 * 避免同一 hap 全局作用域内类名冲突（arkts-no-decl-merging）。
 */
export class GlassTier {
  /** 小胶囊（chip / 收藏钮 / 分段药丸）：最小面积，最亮的面纱 */
  static readonly PILL: string = 'pill';
  /** 内容卡片：接近不透明白，可读性优先 */
  static readonly CARD: string = 'card';
  /** 大面积面板（空态 / 弹窗 / 宫格）：比卡片透一档 */
  static readonly PANEL: string = 'panel';
}

/**
 * 画质档位（降级策略）
 * ------------------------------------------------------------------
 * CINEMATIC  全量光照 + 模糊（默认）
 * BALANCED   3 层光照 + 七成模糊（砍掉左侧菲涅尔层）
 * LITE       只留底色 + 投影 + 描边：零叠加层、零模糊。
 *            低端机或用户省电模式下由设置页写入 GlassLight.quality。
 */
export class GlassQualityLevel {
  static readonly CINEMATIC: string = 'cinematic';
  static readonly BALANCED: string = 'balanced';
  static readonly LITE: string = 'lite';
}

/** 玻璃面板按压反馈档：与页面既有物理反馈语言一致 */
export class GlassPress {
  /** 卡片：轻缩 98% */
  static readonly CARD: number = 0.98;
  /** 胶囊：轻缩 95% */
  static readonly PILL: number = 0.95;
  /** 不缩（纯点击） */
  static readonly NONE: number = 1;
}

export class GlassLight {
  /**
   * 主光源方向：左上 45°。
   * linearGradient 语义：angle 135° = 渐变从左上角扫向右下角，
   * colors[0] 落在左上（受光面），colors[last] 落在右下（背光面）。
   * 全库唯一光源定义，任何玻璃派生角度都从这里推：
   *   顶边受光 → 180°（顶→底）；左边受光 → 90°（左→右）。
   */
  static readonly LIGHT_ANGLE: number = 135;

  /** 视差状态在 AppStorage 里的键名 */
  static readonly PARALLAX_KEY: string = 'glassParallax';

  /**
   * 深色模式高光色温：冷白（236,244,246）。
   * 不用纯白 255：纯白高光叠在冷调暗玻璃上会「发青发脏」，
   * 冷白与薄荷品牌同族，低饱和、少色散。
   */
  static readonly DARK_LIT: string = '236,244,246';

  /**
   * 深色模式背光面色：深青黑（8,14,16）。
   * 比纯黑多一点冷调，与高光冷白形成「同族明暗」而不是「黑白硬碰」。
   */
  static readonly DARK_SHADE: string = '8,14,16';

  /**
   * 深色模式玻璃基底色。
   *
   * ⚠️ 本轮推翻原「深色染色」方案，改为**白色微染**：
   *   暗背景上玻璃必须靠「比背景亮」浮起来，而不是靠深色叠暗浮起来。
   *   原值 (23,36,34) 是深色，与深色 Glass.CARD_BG (28,37,35) 几乎同色 ——
   *   玻璃面 = 页面底色，玻璃直接「消失」；而暗底上唯一剩下的层次线索
   *   就是内阴影，于是只能把内阴影拉到 0.153（浅色才0.02），
   *   结果就是右下角一大块脏暗角（用户反馈的暗角，深色下比浅色更重）。
   *   现与 Theme.Glass 深色套值同口径：白色微染，alpha 由 tintAlpha 给。
   */
  static readonly DARK_TINT: string = '236,244,246';

  /** 深色模式文字区暗纱色（8,12,14）：压在光照之上、内容之下 */
  static readonly DARK_SCRIM: string = '8,12,14';

  /** 当前画质档位（可被设置页覆写，默认 CINEMATIC —— 全量光照 + 实时模糊） */
  static quality: string = GlassQualityLevel.CINEMATIC;

  /* ==================== 环境亮度 ==================== */

  /**
   * 解析颜色字符串并返回 Rec.709 感知亮度（0~1）。
   * 支持 '#RRGGBB' 与 'rgba(r,g,b,a)' 两种本项目常用写法；
   * 解析失败按白色（1.0）处理 —— 玻璃后方默认是浅色页面底。
   */
  static luma(color: string): number {
    let r: number = 255;
    let g: number = 255;
    let b: number = 255;
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1);
      if (hex.length === 6) {
        r = parseInt(hex.substring(0, 2), 16);
        g = parseInt(hex.substring(2, 4), 16);
        b = parseInt(hex.substring(4, 6), 16);
      }
    } else if (color.indexOf('rgba') === 0) {
      const inner: string = color.substring(color.indexOf('(') + 1, color.indexOf(')'));
      const parts: string[] = inner.split(',');
      if (parts.length >= 3) {
        r = Number(parts[0].trim());
        g = Number(parts[1].trim());
        b = Number(parts[2].trim());
      }
    }
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return 1;
    }
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  }

  /**
   * 浅色模式环境自适应系数：玻璃整体受光强度随背景亮度缩放。
   *   亮背景（l > 0.78）× 0.92 —— 白色面纱轻微收敛，防止过曝发糊；
   *   暗背景（l < 0.40）× 1.22 —— 面纱与亮边增强，防止玻璃发灰；
   *   中间带 × 1.0。
   *
   * ⚠️ 亮背景系数由 0.82 提到 0.92：早前压得太狠，等于「在亮底上
   * 再把玻璃调暗一档」，与通透的目标正好相反 —— 亮背景本身已是
   * 最亮的基底，玻璃只需轻收面纱即可，压过头就成了灰蒙蒙的脏玻璃。
   * 过曝风险改由 washAlpha 的绝对值（已降到 0.10~0.15）控制，
   * 不再依赖这个全局系数。
   */
  static adapt(ambient: string): number {
    const l: number = GlassLight.luma(ambient);
    if (l > 0.78) return 0.92;
    if (l < 0.40) return 1.22;
    return 1;
  }

  /* ==================== 深色模式参数表 ==================== */

  /**
   * 深色模式环境自适应：背景越暗，边缘越亮。
   *   l < 0.12 近黑底 ×1.18 —— 暗底上边缘是玻璃「存在」的主要线索；
   *   l < 0.25 深底   ×1.08；
   *   其余（深玻璃压在彩色 hero 渐变上）×1.0 收敛，防止抢戏。
   * 与浅色 adapt() 完全独立：浅色是「亮底收敛防过曝」，
   * 深色是「暗底提亮防消失」。
   */
  static darkAdapt(ambient: string): number {
    const l: number = GlassLight.luma(ambient);
    /*
     * ⚠️ 本轮收敛（1.18/1.08 → 1.10/1.05）。
     * 这个系数是**乘性放大器**，会同时放大描边、光染、内阴影 ——
     * 之前把 edgeBorderAlphaDark 单独砍到 0.18 后，darkAdapt 仍乘 1.18
     * 把它顶回 0.21，白描边的观感没真正解决。
     * 深色玻璃的边缘已经由「底染 + 光染」两级表达，
     * 自适应只需极轻地补偿暗底，不再需要 1.18 这种强放大。
     */
    if (l < 0.12) return 1.10;
    if (l < 0.25) return 1.05;
    return 1;
  }

  /**
   * 玻璃层数预算（限制叠加层，真机降级策略的静态部分）。
   *   CINEMATIC：接触纱? + 光染 + 菲涅尔×2 = 4（全量光照）
   *   BALANCED ：光染 + 菲涅尔×1（顶边）= 3（砍掉左边菲涅尔层）
   *   LITE     ：0（只剩底色 + 描边 + 弱投影）
   * 动态降级见质量档位（设置页「玻璃画质」）。
   *
   * ⚠️ BALANCED 的降级必须在**浅色下也生效**：早前只在深色分支裁层，
   * 结果浅色下 CINEMATIC 与 BALANCED 的层数/模糊完全相同，
   * 用户切档位看不到任何差别，该开关形同虚设。
   */
  static layerBudget(): number {
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (GlassLight.quality === GlassQualityLevel.BALANCED) return 3;
    return 4;
  }

  /** 左边菲涅尔是否出这一层（深色 BALANCED 降级去掉，省一层离屏合成） */
  static fresnelLeftOn(): boolean {
    return GlassLight.layerBudget() >= 4;
  }

  /* ==================== 底色 / 接触纱 ==================== */

  /**
   * 玻璃底色 alpha（受背景亮度影响）。
   * 浅色：card 档只做窄幅自适应（可读性契约强，43 处卡片观感不能跳）；
   *       pill / panel 全幅自适应（它们本就是「透」的档位）。
   * 深色：不透明度整体**略高于浅色**（card 0.86→0.90、pill 0.46→0.52、
   *       panel 0.55→0.60）——暗底上太透会露出下层文字与色块；
   *       再按背景暗度微调 ±0.02（近黑底更实，压在彩色 hero 上收敛）。
   */
  static tintAlpha(tier: string, ambient: string): number {
    if (ThemePalette.dark) {
      /*
       * ⚠️ 本轮重构：深色改为白色微染，alpha 口径随之整体下调。
       * 原 card 0.90 是配合「深色染色底」设计的；换成白染后若仍取 0.90，
       * 玻璃会变成一大块乳白塑料板（比深色染色更糟）。
       * 现按面积反向取值（与浅色同口径）：pill 0.13 / card 0.09 / panel 0.11。
       * 暗底提亮靠的是**绝对量**而非浓度，所以这个值本来就该很小。
       */
      let a: number = 0.09;
      if (tier === GlassTier.PILL) {
        a = 0.13;
      } else if (tier === GlassTier.PANEL) {
        a = 0.11;
      }
      // 近黑底略提亮（玻璃需要更明确的存在感），彩色 hero 上略收敛
      const l: number = GlassLight.luma(ambient);
      if (l < 0.12) {
        a += 0.02;
      } else if (l > 0.25) {
        a -= 0.02;
      }
      return Math.min(0.20, Math.max(0.05, a));
    }
    const f: number = GlassLight.adapt(ambient);
    let a: number = 0.72;
    if (tier === GlassTier.PILL) {
      a = 0.42 * f;
    } else if (tier === GlassTier.PANEL) {
      a = 0.50 * f;
    } else {
      // card：只在 ±0.02 内微调，保持「白玻璃卡」的既定观感
      a = 0.72 + (f - 1) * 0.1;
    }
    return Math.min(0.92, Math.max(0.26, a));
  }

  /**
   * 玻璃底色颜色（受明暗模式影响）。
   * 浅色模式 = 白色面纱（既有「白玻璃」观感）；
   * 深色模式 = 深色面纱 rgba(24,32,30,a) —— 与 Glass.CARD_BG 深色值同族，
   * 白 tint 在深色页面上会变成一块发灰的塑料片。
   * alpha 仍由 tintAlpha() 计算（亮度自适应不变）。
   */
  static tintColor(tier: string, ambient: string): string {
    const a: number = GlassLight.tintAlpha(tier, ambient);
    if (ThemePalette.dark) {
      return 'rgba(' + GlassLight.DARK_TINT + ',' + a.toFixed(2) + ')';
    }
    return 'rgba(255,255,255,' + a.toFixed(2) + ')';
  }

  /**
   * 可读性接触纱（scrim）：亮背景下压在玻璃最底层的暗纱。
   *
   * ⚠️ 通透度头号元凶（已改）：原先是**全幅**均匀暗纱
   * （rgba(12,18,16,0.14) 铺满整块玻璃），等于给白玻璃蒙了一层灰纱——
   * 无论怎么调低白纱与高光，整体观感仍然发灰，这就是「不通透」的由来。
   * 苹果浅色 Liquid Glass 的暗部只出现在**背光侧（右下）**，
   * 受光侧（左上）保持干净，靠高光而不是靠暗纱建立层次。
   *
   * 现改为与 wash 同一方向的定向暗纱：左上 0 → 右下峰值。
   * 强度也整体收敛（0.14/0.07 → 0.10/0.05）。
   */
  static scrim(ambient: string): string {
    const l: number = GlassLight.luma(ambient);
    if (l > 0.78) return 'rgba(12,18,16,0.10)';
    if (l > 0.62) return 'rgba(12,18,16,0.05)';
    return 'rgba(0,0,0,0)';
  }

  /**
   * 接触纱的定向渐变（135°，与主光源同向）。
   * 停靠点严格递增：左上透明 → 右下压深。
   */
  static scrimColors(ambient: string): [string, number][] {
    const c: string = GlassLight.scrim(ambient);
    if (c === 'rgba(0,0,0,0)') {
      return [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0)', 1]];
    }
    return [
      ['rgba(12,18,16,0)', 0],
      [c, 1]
    ];
  }

  /** 接触纱是否需要出这一层（暗背景/已透明时不出） */
  static scrimOn(ambient: string): boolean {
    return GlassLight.scrim(ambient) !== 'rgba(0,0,0,0)';
  }

  /* ==================== 三层光照 alpha ==================== */

  /**
   * 对角光染强度（层①起点白）：模拟曲面受光反射
   *
   * ⚠️ 数值口径（通透度整改）：
   * 早前 pill 档取 0.22、panel 0.16，是全库最重的两档 —— 但「小元素
   * 铺高 alpha」的视觉浓度远高于大卡片，同样的数值落在药丸上就显得
   * 蒙了一层白纱，玻璃通透感反而最差（与直觉相反）。
   * 现统一收敛为「小面积用低浓度、大面积才敢用高浓度」：
   *   pill（最小）0.10 < card 0.12 < panel（最大）0.15
   */
  static washAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.11;
    if (tier === GlassTier.PILL) {
      base = 0.10;
    } else if (tier === GlassTier.PANEL) {
      base = 0.13;
    }
    return base * f;
  }

  /**
   * 菲涅尔亮边强度（层②③起点白）：边缘处更亮
   *
   * ⚠️ 同样按面积反向取值：药丸面积小，亮边宽度占比高，
   * 早前 0.55 的强度在小圆上会糊成一圈白边（截图里最明显的失真）。
   * 现 pill 0.30 < card 0.36 < panel 0.42。
   */
  static edgeAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.30;
    if (tier === GlassTier.PILL) {
      base = 0.26;
    } else if (tier === GlassTier.PANEL) {
      base = 0.34;
    }
    return base * f;
  }

  /**
   * 内阴影强度（层①尾部黑）：背光面（右下）的厚度感
   *
   * ⚠️ 仿苹果 Liquid Glass 再收敛（用户反馈「每一个液态玻璃下都有个暗角，
   * 太明显了」）：苹果的玻璃**底部没有暗角** —— 厚度感全部来自
   * 顶部/四周的边缘光 + 极轻投影，背光侧只贴一条 1px 深描边。
   * 取证（科普页预览器截图）：胶囊底部从 (244,253,250) 渐暗到
   * (223,232,229)，看起来像「玻璃下面垫了一层底色」，正是
   * 内阴影 + 背光描边 + 外投影三暗叠加的结果 —— 用户说的
   * 「导航栏下面有一层底色不是透明」就是它。
   *
   * 此前 card/pill 0.05、panel 0.07；现在减半：0.02 / 0.02 / 0.03。
   * 深色模式不动（innerAlphaDark 独立参数，用户要求深色保持）。
   */
  static innerAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.02;
    if (tier === GlassTier.PILL) {
      base = 0.02;
    } else if (tier === GlassTier.PANEL) {
      base = 0.03;
    }
    return base * f;
  }

  /**
   * 1px 描边：受光边（顶/左）白色亮度
   *
   * ⚠️ 早前 pill 档 0.80 是全库最高，叠在小药丸上就是一圈「死白描边」，
   * 观感像发光边框而非玻璃边缘（通透度整改的重点之一）。
   * 现按面积收敛：pill 0.46 / card 0.56 / panel 0.62。
   * 玻璃的边缘亮线应由**渐隐**的菲涅尔承担，
   * 1px 描边只做「厚度收边」，不该是全篇最亮的一笔。
   */
  static edgeBorderAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.46;
    if (tier === GlassTier.PILL) {
      base = 0.40;
    } else if (tier === GlassTier.PANEL) {
      base = 0.52;
    }
    return Math.min(0.92, base * f);
  }

  /** 1px 描边：背光边（底/右）深色alpha —— 与受光边共同构成厚度 */
  static shadeBorderAlpha(tier: string, ambient: string): number {
    /*
     * 仿苹果再收敛：0.05/0.06/0.07 → 0.02/0.025/0.03。
     * 苹果玻璃的背光边几乎不可见，只有受光边（顶/左）负责勾勒；
     * 之前的 0.06~0.07 深描边叠上内阴影，右下形成可见暗角。
     */
    let base: number = 0.02;
    if (tier === GlassTier.PILL) {
      base = 0.025;
    } else if (tier === GlassTier.PANEL) {
      base = 0.03;
    }
    // 暗背景下背光边几乎不可见，收敛一点避免脏
    if (GlassLight.luma(ambient) < 0.40) base *= 0.6;
    return base;
  }

  /* ---------- 深色模式三层光照 alpha（独立参数，非浅色反转） ---------- */

  /**
   * 深色：对角光染强度。浅色 card 0.12 → 深色 0.05（减半以上）。
   * 暗玻璃上是「受光的边」而不是「发光的面」——面纱一强，
   * 暗玻璃就变成灰玻璃，品牌冷底的材质感全部消失。
   */
  static washAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    /*
     * ⚠️ 本轮小幅上调（原 card 0.05 / pill 0.04 / panel 0.05）。
     *
     * 背景：菲涅尔渐变层（GlassLightLayers）已弃用，描边 alpha 又下调了 60%，
     * 玻璃的「受光感」现在几乎全靠这一条 135° 渐变承担。若不同步补一点，
     * 深色玻璃会塌成「一块均匀的灰片 + 一圈淡边」，彻底失去液态感。
     *
     * 0.05→0.07 是很轻的一档：实算在页面底 (10,41,35) 上，左上角
     * 约亮 10 级，与实测的卡片左上周���（#203F39, L=56）同量级，
     * 不改变「卡片比底亮 16 级」的层级契约。
     */
    let base: number = 0.07;
    if (tier === GlassTier.PILL) {
      base = 0.06;
    } else if (tier === GlassTier.PANEL) {
      base = 0.07;
    }
    return base * f;
  }

  /**
   * 深色：菲涅尔亮边强度。浅色 card 0.40 → 深色 0.58（权重提高）。
   * 暗背景上「边缘」是玻璃存在的主要视觉线索，必须比浅色更亮；
   * 但峰值钳在 0.85，且带宽收窄（见 fresnelColorsDark）—— 更集中、更克制。
   */
  static edgeAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    /*
     * 深色玻璃的厚度现在**主要由边缘光承担**（底改白染后内阴影已收到 0.04，
     * 不再能压出体积感），所以边缘光维持在较高权重。
     * 但 glass 底的 DARK_TINT 本身已是冷白微染，边缘若再叠到 0.85 会
     * 烧出一圈死白亮线 —— 现压在 0.62 上限，靠「带宽收窄」而非「提亮」
     * 来表达玻璃存在（与浅色同思路：亮线要渐隐，不要均匀发光）。
     */
    let base: number = 0.52;
    if (tier === GlassTier.PILL) {
      base = 0.60;
    } else if (tier === GlassTier.PANEL) {
      base = 0.56;
    }
    return Math.min(0.62, base * f);
  }

  /**
   * 深色：内阴影强度。浅色 card 0.07 → 深色 0.13（接近翻倍）。
   * 厚度主要靠它：外投影弱化后，内阴影 + 四边异色描边的方向偏移
   * （上/左受光、下/右背光）共同把「厚度」钉在玻璃内部。
   */
  static innerAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    /*
     * ⚠️ 本轮大幅收敛（用户反馈「液态玻璃还是有暗角，很脏」在深色下更明显）。
     *
     * 原 card 0.13 × darkAdapt(1.18) = **0.153**，是浅色 card (0.02) 的7.6倍。
     * 但深色玻璃的底色本身就是深色，DARK_SHADE (8,14,16) 叠上去：
     *   玻璃右下 (25,33,32)vs 页面底 (18,40,34) —— 几乎无差别，
     *   也就是说这0.153 的内阴影**没建立任何厚度**，只是把右下角压脏。
     * 根因是「深色染色底」方案让内阴影失去了存在空间；
     * 改成白色微染后，玻璃面比背景亮，厚度改由**边缘光**承担，
     * 内阴影只需极轻一档做「背光侧收边」即可。
     *
     * 现 card 0.04 / pill 0.05 / panel 0.045，与浅色同量级。
     */
    let base: number = 0.04;
    if (tier === GlassTier.PILL) {
      base = 0.05;
    } else if (tier === GlassTier.PANEL) {
      base = 0.045;
    }
    return base * f;
  }

  /**
   * 深色：1px 描边受光边（顶/左）亮度，冷白。
   *
   * ⚠️ 本轮按截图像素取证大幅下调（原 card 0.55 / pill 0.62 / panel 0.50）。
   *
   * 取证（深色模式记录页截图 817×920 逐像素扫描）：
   *   页面底 (10,41,35)      L=34.0
   *   卡片内 (28,57,52)      L=50.5   ← 玻璃比底亮 16 级，层级正确
   *   统计卡顶边 y=208       L=160.0  ← 比卡片本身亮 3 倍
   *   胶囊顶边   y=797       L=181.6  ← 比胶囊内部亮 4 倍
   *   被裁卡左边 x=559       L=155.5
   *
   * 反解插值 alpha：L = 50.5 + (243-50.5)·a = 160 → **a ≈ 0.57**，
   * 正是 0.55 × darkAdapt 的结果。也就是说：卡片四周被一根 57% 冷白
   * 描边包住，在深底上「发亮发灰」，观感是**描边**而不是**玻璃**。
   *
   * 为什么以前没这么刺眼：菲涅尔渐变层（fresnelColors，9% 带宽的渐隐亮带）
   * 原本与 1px 描边共存，两者叠加才构成自然的边缘。但那套 Stack 叠层已在
   * 本项目弃用（Index.ets 不再挂 GlassLightLayers），现在**描边是唯一的
   * 边缘线索**，它的观感好坏直接等于玻璃的观感好坏 —— 于是过亮被暴露出来。
   *
   * 现降到 card 0.18 / pill 0.22 / panel 0.16：
   *   · 仍明显高于玻璃面（底染 0.09），保证卡片轮廓可辨 ——
   *     深色下卡片只比页面底亮 15 级，若把描边也抹掉，卡片会糊成一片
   *     看不出边界的污渍，所以边缘光必须保留；
   *   · 实算：0.18×darkAdapt(1.08)=0.194 → L ≈ 49+194×0.194 ≈ 87，
   *     从原来的 156 降到 87，是「玻璃边缘被光扫过」而不是「描了个白框」；
   *   · 与其它玻璃面（胶囊 48、圆钮）落在同一亮度层级，全屏不再有刺眼断线。
   */
  static edgeBorderAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    let base: number = 0.18;
    if (tier === GlassTier.PILL) {
      base = 0.22;
    } else if (tier === GlassTier.PANEL) {
      base = 0.16;
    }
    return Math.min(0.26, base * f);
  }

  /**
   * 深色：1px 描边背光边（底/右）深度。
   * 深色玻璃上「深色描边」意义有限（底色已深），保持克制即可，
   * 厚度由内阴影承担。
   */
  static shadeBorderAlphaDark(tier: string, ambient: string): number {
    /*
     * ⚠️ 本轮收敛（原 0.10/0.12/0.11）。
     * 深色玻璃底已改为白色微染 —— 背光边若仍压深色 (8,14,16)，
     * 会在白染玻璃的右下角切出一道明显的暗切边，正是「暗角」。
     * 背光边改为**中性半透明黑**且极轻：只做 1px 收边，不参与厚度塑造。
     */
    let base: number = 0.06;
    if (tier === GlassTier.PILL) {
      base = 0.07;
    } else if (tier === GlassTier.PANEL) {
      base = 0.065;
    }
    return base;
  }

  /* ==================== 外投影 ==================== */

  /**
   * 外投影：与内阴影同向（右下），建立接触感。
   * 主光源在左上，影子必然落向右下 —— offsetX / offsetY 均 > 0。
   *
   * 深色模式**弱化黑色外投影**：黑投影在深底上本就不可见，
   * 强行加深只会让玻璃边缘「发脏」；厚度改由内阴影与
   * 四边异色描边承担（见 innerAlphaDark / edgeBorderAlphaDark）。
   */
  static shadowOf(tier: string): ShadowOptions {
    if (ThemePalette.dark) {
      if (tier === GlassTier.PILL) {
        return { radius: 6, color: '#06000000', offsetX: 0, offsetY: 1 };
      }
      if (tier === GlassTier.PANEL) {
        return { radius: 14, color: '#0A000010', offsetX: 1, offsetY: 3 };
      }
      return { radius: 10, color: '#08000000', offsetX: 0, offsetY: 2 };
    }
    /*
     * 浅色外投影 —— 本轮取证后大幅收敛（用户反馈「液态玻璃还是有暗角，很脏」）。
     *
     * 取证（记录页预览器截图逐像素，x=400 纵切 / y=432 横切）：
     *   页面底色      (241,250,247)
     *   白玻璃应呈现  (251,254,253)   ← rgba(255,255,255,0.72) 叠底色的算术结果
     *   **卡片实测    (231,234,227)** ← 反而比底色暗 10~20
     *
     * 差值来源就是本函数返回的外投影：卡片内部横切从 x=275 到 x=490
     * **完全均匀**（无渐变），说明内阴影与高光层都没生效/已被抵消，
     * 而均匀压暗只可能来自**四边均匀渗出的投影**。
     * ArkUI 的 shadow 不做「只在下方」裁剪，blur 半径内的阴影会从
     * 卡片四周一起冒出来 —— 于是卡片被一圈脏边包住，
     * 这正是苹果液态玻璃明确禁止的「暗角」。
     *
     * 苹果浅色玻璃的投影几乎不可见（靠边缘光 + 背景对比建立层次）。
     * 现把浅色三档投影砍到 alpha ≤ 0.02、偏移归零：
     *   PILL  radius 10 / #06000004 / (0,0)
     *   CARD  radius 12 / #06000005 / (0,0)
     *   PANEL radius 14 / #06000006 / (0,0)
     * 厚度仍由「1vp 四边异色描边 + 极轻的右下内阴影」承担。
     * （顶部亮边**不能**加宽到 1.5vp：非整数描边 + borderRadius 会在内侧
     *   留下一条未填充暗缝，见 Components.ets 的取证记录。）
     * 深色分支不动（黑投影在深底上本就不可见，用户要求深色保持）。
     *
     * ⚠️ 再收一档（2026-10-19 夜，用户第二次说「阴影和暗角很脏」）：
     * 上一轮把 alpha 砍到 2.3% 后，卡片**四周**仍有一圈肉眼可辨的灰晕
     * —— 原因已定位：卡片矩形本身不再是深色，而是比页面底亮 10 级的
     * 白玻璃，任何 alpha > 1% 的黑投影都会把这一圈压回去，看起来像脏边。
     * 这一轮把浅色投影压到 **0.8%~1.2%**、半径同时收到 8/10/12：
     * 玻璃与页面的层次改由「白玻璃 vs 页面底 +10 级 + 1px 受光描边」建立，
     * 投影只留一丝「不是完全贴死」的空气感。
     */
    if (tier === GlassTier.PILL) {
      return { radius: 8, color: '#02000002', offsetX: 0, offsetY: 0 };
    }
    if (tier === GlassTier.PANEL) {
      return { radius: 12, color: '#03000004', offsetX: 0, offsetY: 0 };
    }
    return { radius: 10, color: '#03000003', offsetX: 0, offsetY: 0 };
  }

  /* ==================== 模糊（性能红线） ==================== */

  /**
   * 按画质档位缩放一个基准模糊半径。
   * ------------------------------------------------------------------
   * 全库所有 backdropBlur 都应经过本函数，而不是直接写
   * `Glass.LIVE_BLUR` —— 后者绕过了档位，是「切了画质没反应」的
   * 主要来源之一（页面上一片模糊该缩的不缩）。
   *
   * 各站点仍传自己的基准值（DISC_BLUR / LIVE_BLUR_SOFT / LIVE_BLUR），
   * 本函数只做档位系数，因此默认档（CINEMATIC，系数 1）下
   * 观感与原先完全一致，切档才产生可见差异：
   *   CINEMATIC ×1（满值） / BALANCED ×0.7 / LITE ×0（零模糊）
   */
  static blurScaled(base: number): number {
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (GlassLight.quality === GlassQualityLevel.BALANCED) return Math.round(base * 0.7);
    return base;
  }

  /**
   * 实时模糊半径。
   * ⚠️ card 档一律 0：一屏十几张卡片各挂一层 backdropBlur 会明显掉帧
   * （Theme.ets Glass.CARD_BG 注释有实测记录），卡片透出的底色
   * 来自页面根本身的模糊。LITE 档全部归零。
   *
   * 半径按档位递减（CINEMATIC 满值 → BALANCED 七成 → LITE 零），
   * 与 layerBudget 一起保证三档在观感上确实可辨，而不只是名字不同。
   */
  static blurOf(tier: string, glass: boolean): number {
    if (!glass) return 0;
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (tier === GlassTier.PILL) return GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT);
    if (tier === GlassTier.PANEL) return GlassLight.blurScaled(Glass.LIVE_BLUR);
    return 0;
  }

  /**
   * 品牌色投影：把 '#RRGGBB' 转成同色 30% alpha 的 rgba，
   * 供选中态药丸使用 —— 投影跟着品牌色走（eco 档位变色时
   * 选中药丸的投影同步变，而不是一律写死绿色）。
   */
  static shadowTintOf(color: string): string {
    if (color.charAt(0) === '#' && color.length === 7) {
      const r: number = parseInt(color.substring(1, 3), 16);
      const g: number = parseInt(color.substring(3, 5), 16);
      const b: number = parseInt(color.substring(5, 7), 16);
      if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b)) {
        return 'rgba(' + r + ',' + g + ',' + b + ',0.30)';
      }
    }
    return 'rgba(63,191,159,0.30)';
  }

  /* ==================== 颜色解析 / α 合成 ==================== */

  /**
   * 解析颜色字符串 → [r, g, b, a]（a 为 0~1）。
   * 支持 '#RRGGBB'、'#AARRGGBB'（ArkUI 的 ShadowOptions 用两位 alpha 前缀）、
   * 'rgb(r,g,b)' 与 'rgba(r,g,b,a)'。
   * 解析失败回退到不透明白色 —— 与 luma() 的容错口径一致。
   */
  static rgbaOf(color: string): number[] {
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1);
      const ok: boolean = hex.length === 6 || hex.length === 8;
      if (ok) {
        let r: number = 255;
        let g: number = 255;
        let b: number = 255;
        let a: number = 1;
        if (hex.length === 8) {
          a = parseInt(hex.substring(0, 2), 16) / 255;
          r = parseInt(hex.substring(2, 4), 16);
          g = parseInt(hex.substring(4, 6), 16);
          b = parseInt(hex.substring(6, 8), 16);
        } else {
          r = parseInt(hex.substring(0, 2), 16);
          g = parseInt(hex.substring(2, 4), 16);
          b = parseInt(hex.substring(4, 6), 16);
        }
        if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b) && !Number.isNaN(a)) {
          return [r, g, b, a];
        }
      }
    } else if (color.indexOf('rgb') === 0) {
      const open: number = color.indexOf('(');
      const close: number = color.indexOf(')');
      if (open >= 0 && close > open) {
        const parts: string[] = color.substring(open + 1, close).split(',');
        if (parts.length >= 3) {
          const r: number = Number(parts[0].trim());
          const g: number = Number(parts[1].trim());
          const b: number = Number(parts[2].trim());
          let a: number = 1;
          if (parts.length >= 4) {
            a = Number(parts[3].trim());
          }
          if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b) && !Number.isNaN(a)) {
            return [r, g, b, a];
          }
        }
      }
    }
    return [255, 255, 255, 1];
  }

  /**
   * α 合成：把 top（自带透明度，可再乘 alphaScale）叠在 base 之上，
   * 返回合成结果的 rgba 字符串。
   * ------------------------------------------------------------------
   * ⚠️ 这是「玻璃光照不吃脏」的关键工具，理由见 surface() 的整改记录：
   * ArkUI 的 linearGradient **不做预乘插值**，两个 rgba 停靠点之间是
   * 逐通道（含 alpha）线性插值。于是「半透明深墨 → 不透明白底」直连时，
   * 中段会插出一大片 alpha 0.2~0.4、RGB 110~160 的**半透明灰** ——
   * 落在浅色页面上就是右下角那块脏暗角。
   *
   * 正确做法：先把光照层按 α 合成到玻璃底色上，得到「已合成」的停靠点。
   * 这样每个停靠点都自带完整底色，任意两点之间插值都只在
   * 「同一块玻璃的亮部/暗部」之间过渡，不会再凭空生出灰色。
   */
  static over(base: number[], top: number[], alphaScale: number): string {
    const ba: number = Math.max(0, Math.min(1, base[3]));
    const ta: number = Math.max(0, Math.min(1, top[3] * alphaScale));
    const outA: number = ta + ba * (1 - ta);
    if (outA <= 0.001) {
      return 'rgba(0,0,0,0)';
    }
    const k: number = ba * (1 - ta);
    const r: number = (top[0] * ta + base[0] * k) / outA;
    const g: number = (top[1] * ta + base[1] * k) / outA;
    const b: number = (top[2] * ta + base[2] * k) / outA;
    return 'rgba(' + Math.round(r) + ',' + Math.round(g) + ',' + Math.round(b) +
      ',' + outA.toFixed(3) + ')';
  }

  /* ==================== 渐变构造（组件与特殊布局共用） ==================== */

  /**
   * 通用「单层合成」135° 渐变（卡片 / 顶栏 / 圆钮等**有确定宽度**的玻璃面）。
   * ------------------------------------------------------------------
   * 背景：完整光照栈（GlassLightLayers）每层都是 100%×100%，
   * 在 fit-content / 高度自适应的父容器里，百分比会按祖先约束最大值解析，
   * 把元素撑成巨块（药丸曾实测撑成约 210×586vp，`position()` 在 Stack 里
   * 也无效，因为 Stack 仍按绝对定位子节点算尺寸）。
   *
   * 所以对**不需要顶/左菲涅尔独立层**的玻璃面，一律走「零子层」方案：
   * 把底色 + 135° 对角光染 + 右下内阴影压进**一条 135° 渐变**，
   * 直接铺在元素自身。没有 100%、没有子层，尺寸必然正确。
   *
   * 为什么这条就够：真正建立「光从左上 45° 射入」观感的是
   *   ① 左上角的白光（washColors 起点）→ 受光面
   *   ② 右下角的深色内阴影（washColors 终点）→ 背光面与厚度
   *   ③ 1px 四边异色描边（borderColors：上/左亮、下/右深）
   * 三者同在一条对角轴上，物理上就是同一个方向的光。
   * 顶/左菲涅尔只是这条轴的边缘加强，卡片尺寸上肉眼几乎不可辨，
   * 省掉换来的是全库 40+ 处卡片零离屏合成开销 —— 净收益。
   *
   * ⚠️⚠️ 本轮根治「阴影/暗角很脏」（用户第 N 次反馈，红圈标在卡片右下角）：
   * ------------------------------------------------------------------
   * 之前这里把 washColors 的停靠点**原样**塞进渐变（首尾各加一个 base），
   * 有三个结构性错误，全部由「ArkUI 渐变逐通道插值 rgba」放大：
   *
   *   ① **卡片中段全透明**：wash 在 0.55~0.90 之间的停靠点 alpha = 0，
   *      而底色 base 只出现在 t=0 与 t=1 两个端点上。于是卡片
   *      t≈0.5 处 alpha 归零 → 卡片根本没有白色底，直接透出页面底色。
   *      实测取证（截图逐像素）：卡片内部 (239,248,245) ≈ 页面底
   *      (241,250,247)，只差 2 级 —— 卡片「看起来不存在」，
   *      只剩 1px 描边和右下那块脏雾，这正是「很脏」的观感来源。
   *   ② **右下角插值出半透明灰带**：0.90 是深墨 rgba(10,16,14,0.018)、
   *      1.00 是白底 rgba(255,255,255,0.72)，两停靠点直连 →
   *      中段插出 rgba(约132,135,134,0.37)。叠在浅色页面上 = 比底色
   *      暗 39 级的一块灰，且 0.90 处从「完全透明」突然变成 1.8% 深墨，
   *      边界硬得像一道斜切线 —— 就是用户圈出来的那块「阴影/暗角」。
   *      实算复现：t=0.94 处 -39 级，与截图实测 (199,208,205) 完全吻合。
   *   ③ **选中药丸被洗白**：同理，品牌实底只有两端点，中段透明 →
   *      选中 chip「白底白字」（历史上被误判为「重复停靠点导致渐变失效」）。
   *
   * 根治手法：**先把光照层 α 合成到底色上**（GlassLight.over），
   * 再作为停靠点。这样
   *   · 每个停靠点自带完整底色 → 中段不再透明，卡片是真正的白玻璃卡；
   *   · 任意两点都在「同一块玻璃的亮部/暗部」之间过渡 → 不再生出灰带；
   *   · 停靠点位置直接用 wash 的 0/0.12/0.38/0.55/0.90/1（严格递增，
   *     不需要再收进 [0.02,0.90] 来躲重复位置）。
   * 修复后同一套参数实算：卡片通体比页面底亮 10 级，到右下角单调
   * 收到 +5 级，全程无一处比底色暗 —— 暗角彻底消失。
   *
   * @param base 底色（传该元素的主题底色，如 Glass.CARD_BG）
   * @param tier 材质档位（card / panel / pill）
   * @param ambient 环境底色（亮度自适应；传空串按白色处理）
   * @param gloss 高光强度，实底元素传 <1 收敛高光
   */
  static surface(base: string, tier: string, ambient: string, gloss: number): LinearGradient {
    const baseRgba: number[] = GlassLight.rgbaOf(base);
    const wash: [string, number][] = GlassLight.washColors(tier, ambient, gloss);
    /*
     * 预合成：每个光照停靠点先 over 到底色上，再进渐变。
     * 位置直接沿用 washColors 的归一化位置（0 → 1，严格递增），
     * 首尾正好是 t=0 / t=1，不需要额外补 base 停靠点。
     * 仍做一次防御：跳过非递增位置，避免 ArkUI 静默丢整条渐变。
     */
    const colors: [string, number][] = [];
    let last: number = -1;
    for (let i = 0; i < wash.length; i++) {
      let pos: number = wash[i][1];
      if (pos < 0) {
        pos = 0;
      }
      if (pos > 1) {
        pos = 1;
      }
      if (pos <= last) {
        continue;
      }
      colors.push([GlassLight.over(baseRgba, GlassLight.rgbaOf(wash[i][0]), 1),
        Number(pos.toFixed(3))]);
      last = pos;
    }
    if (colors.length === 0) {
      colors.push([base, 0]);
      colors.push([base, 1]);
    }
    return { angle: GlassLight.LIGHT_ANGLE, colors: colors };
  }

  /**
   * fit-content 药丸专用的「单层合成」渐变（= surface 的药丸档别名）。
   *
   * @param base 药丸底色（选中态传品牌实底色）
   */
  static pillSurface(base: string, tier: string, ambient: string, gloss: number): LinearGradient {
    return GlassLight.surface(base, tier, ambient, gloss);
  }

  /**
   * 大面积玻璃面板的「单层合成」渐变入口。
   * ------------------------------------------------------------------
   * 供**没有包装组件**、直接写在页面上的玻璃面使用（bindSheet 面板、
   * 首页悬浮分组卡、启动页/引导页说明条、调试面板等）。
   *
   * 口径与 CfCard / GlassPanel 完全一致：底色 Glass.PANEL_LIVE_BG
   * + 左上白光 + 右下极轻内阴影，全部预合成进同一条 135° 渐变。
   *
   * ⚠️ 禁止再写 `.backgroundColor(Glass.PANEL_LIVE_BG)` 这种**平涂**：
   *   · 平涂没有方向性 → 全库「光从左上 45° 射入」的一致性被破坏；
   *   · 深色模式下 PANEL_LIVE_BG 只是 6% 白，平涂等于一块没有边缘光的
   *     灰片，与周围玻璃面不是同一材质。
   * @param ambient 面板后方的页面底色（亮度自适应；空串按亮底处理）
   */
  static panelSurface(ambient: string): LinearGradient {
    return GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, ambient, 1);
  }

  /** 把任意颜色包成「等色双停渐变」—— 需要条件切换底色时的统一手法 */
  static flat(color: string): LinearGradient {
    return { angle: 180, colors: [[color, 0], [color, 1]] };
  }

  /**
   * 「＋」圆钮（OrbButton）的球面渐变 —— 预合成单层。
   * ------------------------------------------------------------------
   * 圆钮是球面不是平面：中心透光、0.38 处一小块高光斑、右下向边缘弯折压暗。
   * 原来这五档停靠点是**直接写的 rgba**，于是重演了 surface() 的同一个坑：
   *   0.38 白底 0.78 → 0.72 深墨 0.10 → 1.00 深墨 0.22
   * 逐通道插值在三者之间造出大片半透明灰，圆钮右下角就是一块脏暗斑。
   *
   * 现改为「先给球体一个统一玻璃底（中心最透，符合透镜透光），
   * 再把高光/背光 α 合成上去」：α 从 0.34 单调升到 0.80（受光斑）再回落，
   * RGB 全程连续，不会再出现灰色突变。终端深墨也从 0.22 收到 0.09，
   * 边缘只是「略微收暗」，不是一块黑斑。
   */
  static orbSurface(): LinearGradient {
    if (ThemePalette.dark) {
      /*
       * ⚠️ 深色球面本轮大幅压暗（原 lit 0.10/0.20/0.28 → 0.05/0.09/0.13）。
       *
       * 取证（深色记录页截图，圆钮区域 512..566 × 796..834）：
       *   页面底 L=34 / 底部胶囊本体 L=45，而圆钮中位 **L=160**、
       *   峰值 201 —— 是环境亮度的 3.5~4.7 倍，截图里就是一颗「死白球」。
       *
       * 根因：底染与高光都用 DARK_LIT(236,244,246) 且 alpha 偏高，
       * 球面「中心最透」的设定在深色下不成立 —— 暗背景上玻璃本来
       * 就该靠低 alpha 微染浮起，圆钮却按浅色的思路叠了三层高光。
       *
       * 现统一降到与卡片玻璃同量级（0.05~0.13），让圆钮与胶囊、
       * 卡片处在**同一个亮度层级**上；球感改由 1px 受光边承担。
       */
      const baseD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_TINT + ',0.09)');
      const litD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_LIT + ',1)');
      const shadeD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_SHADE + ',1)');
      const colorsD: [string, number][] = [
        [GlassLight.over(baseD, litD, 0.05), 0],
        [GlassLight.over(baseD, litD, 0.09), 0.22],
        [GlassLight.over(baseD, litD, 0.13), 0.38],
        [GlassLight.over(baseD, shadeD, 0.03), 0.72],
        [GlassLight.over(baseD, shadeD, 0.05), 1]
      ];
      return { angle: GlassLight.LIGHT_ANGLE, colors: colorsD };
    }
    const baseL: number[] = GlassLight.rgbaOf('rgba(255,255,255,0.34)');
    const litL: number[] = [255, 255, 255, 1];
    const shadeL: number[] = [10, 16, 14, 1];
    const colorsL: [string, number][] = [
      // 0.00 中心透光（最低不透明度）：模糊后的内容能透上来
      [GlassLight.over(baseL, litL, 0.30), 0],
      // 0.22 高光斑起始
      [GlassLight.over(baseL, litL, 0.55), 0.22],
      // 0.38 高光斑峰值
      [GlassLight.over(baseL, litL, 0.70), 0.38],
      // 0.72 进入边缘弯折区
      [GlassLight.over(baseL, shadeL, 0.05), 0.72],
      // 1.00 背光侧边缘：只轻微收暗（原 0.22 是一块脏暗斑）
      [GlassLight.over(baseL, shadeL, 0.09), 1]
    ];
    return { angle: GlassLight.LIGHT_ANGLE, colors: colorsL };
  }

  /**
   * 「＋」圆钮（OrbButton）的**品牌档位色**球面渐变 —— 预合成单层。
   * ------------------------------------------------------------------
   * 用户反馈「加号按钮有点灰，不够突出；液态玻璃的 FAB 应该通透且带发光」。
   * 原 orbSurface() 是白色玻璃球 —— 与胶囊同灰阶，缺少视觉锚点，
   * 这正是「灰、不突出」的来源。
   *
   * 本方法保留球面的五档停靠结构（中心透光 → 高光斑 → 边缘弯折 → 背光边），
   * 只把「白色微染底」换成**档位主色半透明底**：
   *   · primaryLight(level) → primary(level)：135° 从浅绿扫向主绿
   *     （跟碳档位走 —— WARN 是琥珀球、ALERT 是珊瑚球，FAB 也参与情绪表达）；
   *   · α 0.78~0.95：仍是玻璃，中心能透出模糊的背景，不是实心色饼；
   *   · 左上受光 / 右下背光仍由 over() 预合成，全程无灰色插值带。
   * 搭配 Index.OrbButton 的白色「＋」图标与绿色辉光投影构成 FAB 焦点。
   */
  static orbAccentSurface(level: string): LinearGradient {
    const fromC: number[] = GlassLight.rgbaOf(EcoTheme.primaryLight(level));
    const toC: number[] = GlassLight.rgbaOf(EcoTheme.primary(level));
    const lit: number[] = [255, 255, 255, 1];
    const shade: number[] = [10, 16, 14, 1];
    const colors: [string, number][] = [
      // 0.00 中心透光：浅绿底 α 最低，球面正对光源最亮处
      [GlassLight.over([fromC[0], fromC[1], fromC[2], 0.78], lit, 0.30), 0],
      // 0.22 高光斑起始
      [GlassLight.over([fromC[0], fromC[1], fromC[2], 0.84], lit, 0.50), 0.22],
      // 0.38 高光斑峰值：主绿底 + 白色受光
      [GlassLight.over([toC[0], toC[1], toC[2], 0.90], lit, 0.38), 0.38],
      // 0.72 进入边缘弯折区：向主绿收深
      [GlassLight.over([toC[0], toC[1], toC[2], 0.93], shade, 0.05), 0.72],
      // 1.00 背光边缘：轻微收暗，保持球面厚度（不是黑斑）
      [GlassLight.over([toC[0], toC[1], toC[2], 0.95], shade, 0.10), 1]
    ];
    return { angle: GlassLight.LIGHT_ANGLE, colors: colors };
  }

  /**
   * 对角光染 + 内阴影的多段渐变（层②）。
   * 135° 主光源：左上受光（白）→ 中性带 → 右下内阴影（深）。
   * gloss < 1 用于实底元素（选中药丸）上的克制高光。
   * 深色模式走 washColorsDark：冷白、强度减半。
   */
  static washColors(tier: string, ambient: string, gloss: number): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'w|' + tier + '|' + ambient + '|' + gloss + '|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.washColorsImpl(tier, ambient, gloss));
  }

  private static washColorsImpl(tier: string, ambient: string, gloss: number): [string, number][] {
    if (ThemePalette.dark) {
      const wa: number = GlassLight.washAlphaDark(tier, ambient) * gloss;
      const ia: number = GlassLight.innerAlphaDark(tier, ambient) * gloss;
      /*
       * ⚠️ 深色渐变停靠点本轮重排（原 0 / 0.14 / 0.34 / 0.52 / 0.86 / 1）。
       *
       * 取证发现的问题：原停靠点里 0.52 处有一档**完全透明**，
       * 而 surface() 会把每个停靠点 over 到底色上 —— 于是卡片沿对角线
       * 呈现「亮 → 暗 → 突降 → 微暗」的三段式，中段 0.52 是个断点。
       * 加上内阴影从 0.86 才开始，深色下这条断点被放大成一道**斜向亮带**，
       * 正是截图里卡片左上亮、右下突然沉下去的原因。
       *
       * 现改为：受光区更宽更缓地铺到 0.62 才归零（不再留断点），
       * 内阴影只在最后 0.88→1 一小段收边，全程单调下沉、无比底突降。
       * 这样玻璃的明暗是**一条连续的斜向受光**，而不是三段拼接。
       */
      return [
        ['rgba(' + GlassLight.DARK_LIT + ',' + wa.toFixed(3) + ')', 0],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.72).toFixed(3) + ')', 0.16],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.40).toFixed(3) + ')', 0.34],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.16).toFixed(3) + ')', 0.50],
        ['rgba(' + GlassLight.DARK_LIT + ',0)', 0.62],
        ['rgba(' + GlassLight.DARK_SHADE + ',' + (ia * 0.35).toFixed(3) + ')', 0.88],
        ['rgba(' + GlassLight.DARK_SHADE + ',' + ia.toFixed(3) + ')', 1]
      ];
    }
    const wa: number = GlassLight.washAlpha(tier, ambient) * gloss;
    const ia: number = GlassLight.innerAlpha(tier, ambient) * gloss;
    /*
     * ⚠️ 入射感（用户反馈「感觉光的位置变了」）：
     * 原停靠点 0 / 0.38 / 0.62 —— 高光一直铺到 62% 处才归零，
     * 视觉上是**整片玻璃在对角方向被均匀染色**，不像「光从左上 45° 射入」。
     * 现在把高光压进左上角一小段（0 → 0.12峰值 → 0.38 收尾 → 0.55 全归零），
     * 中段 alpha 归零 —— 玻璃中央留给背景透射，这才是通透感的来源。
     *
     * ⚠️ 但这里的 alpha=0 只能当作「光照层」用，**绝不能直接当渐变停靠点**
     *    塞给 `.linearGradient()`：那段 alpha=0 会把元素自身的底色挖空
     *    （卡片中段全透明），并且末端「深墨 → 白底」直连会插出半透明灰带
     *    （右下角脏暗角的真凶）。必须先用 surface() 把本数组 over 到底色上。
     *    本数组目前只剩两处合法消费者：
     *      · surface()        —— 预合成后进渐变（全库 40+ 玻璃面）
     *      · GlassLightLayers —— 作为 Stack 叠加层铺在**真实 backgroundColor**
     *                            之上（alpha=0 段透出的是底色层，不是页面）
     */
    return [
      ['rgba(255,255,255,' + wa.toFixed(3) + ')', 0],
      ['rgba(255,255,255,' + (wa * 0.62).toFixed(3) + ')', 0.12],
      ['rgba(255,255,255,' + (wa * 0.16).toFixed(3) + ')', 0.38],
      ['rgba(255,255,255,0)', 0.55],
      // ⚠️ 仿苹果：右下暗部从 0.84 提前收窄到 0.90 才起步，且起步档
      // 从 ia*0.55 降到 ia*0.30 —— 暗部只贴最边缘一小段，
      // 不再形成「玻璃下面垫了一层底色」的暗带
      ['rgba(10,16,14,' + (ia * 0.30).toFixed(3) + ')', 0.90],
      ['rgba(10,16,14,' + ia.toFixed(3) + ')', 1]
    ];
  }

  /**
   * 菲涅尔亮边渐变（层③④）：亮 → 透明，集中在边缘。
   * 浅色带宽 13%（0/0.05/0.13）；深色带宽收窄到 9% 且衰减更陡
   * （0/0.03/0.09）——「更集中」：高光被压在边缘带内，
   * 玻璃中心留给文字（配合 textScrim 实现「高光避开文字」）。
   */
  static fresnelColors(tier: string, ambient: string, gloss: number): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'f|' + tier + '|' + ambient + '|' + gloss + '|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.fresnelColorsImpl(tier, ambient, gloss));
  }

  private static fresnelColorsImpl(tier: string, ambient: string, gloss: number): [string, number][] {
    if (ThemePalette.dark) {
      const ea: number = GlassLight.edgeAlphaDark(tier, ambient) * gloss;
      return [
        ['rgba(' + GlassLight.DARK_LIT + ',' + ea.toFixed(3) + ')', 0],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (ea * 0.45).toFixed(3) + ')', 0.03],
        ['rgba(' + GlassLight.DARK_LIT + ',0)', 0.09]
      ];
    }
    const ea: number = GlassLight.edgeAlpha(tier, ambient) * gloss;
    return [
      ['rgba(255,255,255,' + ea.toFixed(3) + ')', 0],
      ['rgba(255,255,255,' + (ea * 0.35).toFixed(3) + ')', 0.05],
      ['rgba(255,255,255,0)', 0.13]
    ];
  }

  /**
   * 四边异色描边：受光边（顶/左）亮，背光边（底/右）深。
   * 这是「菲涅尔边缘反射」的 1px 版本 —— 视角边缘更亮，
   * 而不是一条固定白色描边。
   * 深色模式：受光边用冷白（DARK_LIT）、亮度按 darkAdapt 提亮；
   * 背光边用深青黑（DARK_SHADE），厚度感由这一对方向偏移建立。
   */
  static borderColors(tier: string, ambient: string, gloss: number): EdgeColors {
    if (ThemePalette.dark) {
      const lit: string = 'rgba(' + GlassLight.DARK_LIT + ',' +
        (GlassLight.edgeBorderAlphaDark(tier, ambient) * gloss).toFixed(2) + ')';
      const shade: string = 'rgba(' + GlassLight.DARK_SHADE + ',' +
        (GlassLight.shadeBorderAlphaDark(tier, ambient) * gloss).toFixed(2) + ')';
      return { top: lit, right: shade, bottom: shade, left: lit };
    }
    const lit: string = 'rgba(255,255,255,' + (GlassLight.edgeBorderAlpha(tier, ambient) * gloss).toFixed(2) + ')';
    const shade: string = 'rgba(10,16,14,' + (GlassLight.shadeBorderAlpha(tier, ambient) * gloss).toFixed(2) + ')';
    return { top: lit, right: shade, bottom: shade, left: lit };
  }

  /**
   * 深色模式文字区暗纱（text scrim，仅深色）。
   * ------------------------------------------------------------------
   * 压在全部光照层之上、内容之下：定向渐变（顶 0.16 → 底 0.30），
   * 顶部留亮给受光边、底部压深托住副标题/说明文字。
   * 与 9% 边缘带菲涅尔配合 = 「高光在四周，文字区安静」。
   * 实底元素（选中药丸 / 品牌渐变 Hero）不压这层。
   */
  static textScrim(): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'ts|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.textScrimImpl());
  }

  private static textScrimImpl(): [string, number][] {
    /*
     * ⚠️ 本轮大幅下调（原 顶0.16 → 底0.30）。
     *
     * 深色玻璃底改成白色微染后，这层暗纱从「托住文字」变成了「纯粹的压暗」：
     * 它压在光照之上、铺满整块玻璃（180° 从顶到底），与135° 内阴影
     * 在下半部**叠加** —— 实测右下角因此比周围暗 30+ 级，
     * 这就是深色模式下「玻璃很脏、暗角明显」的直接来源。
     *
     * 文字对比度现在由两处保证，都不需要暗纱：
     *   ① 玻璃面比背景亮 17 级（白染），浅色文字天然可读；
     *   ② 内阴影收到 0.04，不再压暗文字区。
     * 所以暗纱只保留极轻一档做「底部微沉」，防止大段文字浮在玻璃上发飘。
     */
    return [
      ['rgba(' + GlassLight.DARK_SCRIM + ',0.02)', 0],
      ['rgba(' + GlassLight.DARK_SCRIM + ',0.08)', 1]
    ];
  }

  /* ==================== 滚动视差 ==================== */

  /** 当前视差位移（vp），浅色 ±10 / 深色 ±5（见 parallaxLimit） */
  private static parallaxValue: number = 0;
  /** 尚未写入的累加量 */
  private static parallaxPending: number = 0;
  /** 80ms 心跳定时器，-1 表示未运行 */
  private static parallaxTimer: number = -1;

  /**
   * 视差累加系数：深色模式**减半**（0.22 → 0.11）。
   * 暗底上高光与背景的对比更强，同样幅度的高光平移会更「跳」，
   * 减半是防闪烁的直接手段（配合限幅减半）。
   */
  static parallaxFactor(): number {
    return ThemePalette.dark ? 0.11 : 0.22;
  }

  /** 视差限幅：深色模式 ±5（浅色 ±10） */
  static parallaxLimit(): number {
    return ThemePalette.dark ? 5 : 10;
  }

  /**
   * 滚动视差：由列表 onScroll(dy) 调用。
   * 累加 dy × parallaxFactor（限幅 ±parallaxLimit）后按 80ms 心跳写入
   * AppStorage，同时每心跳衰减 0.78 倍；归位后自清定时器。
   * 节流理由：AppStorage 每次写入都会让所有订阅的玻璃面重渲染，
   * 每帧直写会让长列表里几十张卡同时重渲。
   */
  static nudge(dy: number): void {
    GlassLight.parallaxPending = GlassLight.parallaxPending + dy * GlassLight.parallaxFactor();
    GlassLight.ensureTick();
  }

  /** 复位视差（页面隐藏/销毁时调用，避免下次进入带着残余偏移） */
  static resetParallax(): void {
    GlassLight.parallaxPending = 0;
    GlassLight.parallaxValue = 0;
    if (GlassLight.parallaxTimer !== -1) {
      clearInterval(GlassLight.parallaxTimer);
      GlassLight.parallaxTimer = -1;
    }
    AppStorage.setOrCreate(GlassLight.PARALLAX_KEY, 0);
  }

  private static ensureTick(): void {
    if (GlassLight.parallaxTimer !== -1) return;
    GlassLight.parallaxTimer = setInterval((): void => {
      let v: number = GlassLight.parallaxValue + GlassLight.parallaxPending;
      GlassLight.parallaxPending = 0;
      v = v * 0.78;
      if (Math.abs(v) < 0.1) {
        v = 0;
      }
      GlassLight.parallaxValue = Math.max(-GlassLight.parallaxLimit(),
        Math.min(GlassLight.parallaxLimit(), v));
      AppStorage.setOrCreate(GlassLight.PARALLAX_KEY, GlassLight.parallaxValue);
      if (GlassLight.parallaxValue === 0) {
        clearInterval(GlassLight.parallaxTimer);
        GlassLight.parallaxTimer = -1;
      }
    }, 80);
  }

  /* ==================== 光照结果缓存（流畅性优化） ====================
   * 视差心跳（80ms）与任意玻璃组件重建都会重调 washColors 等取色方法，
   * 每次都要解析 ambient 色串 + 构造多段渐变数组 —— 而 diff 后值根本没变。
   * 这里按「参数 + 明暗 + 画质」缓存**同一数组引用**：ArkUS diff 对对象
   * 参数做引用比较，引用相同则跳过 linearGradient 属性更新，
   * 高频心跳期只剩 translate 的纯合成层操作。缓存对象只读，勿改。
   */
  private static gradMemo: Map<string, Object> = new Map();

  /** 缓存键的明暗/画质签名：换血或切画质自动换键，天然失效旧缓存 */
  private static sig(): string {
    return (ThemePalette.dark ? 'd1' : 'd0') + '|' + GlassLight.quality;
  }

  private static memoPut<T>(key: string, make: () => T): T {
    const hit: Object | undefined = GlassLight.gradMemo.get(key);
    if (hit !== undefined) {
      return hit as T;
    }
    const made: T = make();
    GlassLight.gradMemo.set(key, made as Object);
    return made;
  }
}
