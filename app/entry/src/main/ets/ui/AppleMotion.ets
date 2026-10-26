/**
 * 苹果动效语言（全库唯一定义处）
 * ------------------------------------------------------------------
 * 定位与 Theme.ets / GlassLight.ets 平行：Theme 管颜色、GlassLight 管
 * 玻璃光照，本类管**动效**。所有页面/组件从这里取时长与曲线，
 * 禁止在页面里硬编码 duration / curve。
 *
 * 为什么需要它（整改前的问题）：
 * ------------------------------------------------------------------
 * 全库动效参数是随手写的 —— `.animation({duration:620, curve:EaseInOut})`
 * 出现在 20 多处（主题过渡、入场、卡片），弹窗进场 200ms EaseOut，
 * 按压反馈干脆没有。后果：
 *   ① 同一个「出现」动作，A 页 350ms、B 页 620ms、C 页 200ms，
 *      用户感知的是「这个 App 的快慢不统一」，而不是「设计」；
 *   ② 缺 iOS 最标志的两个动作 —— **弹簧回弹**与**进场缩放**，
 *      弹窗/面板出现都是「啪一下淡入」，没有「从指尖长出来」的物理感。
 *
 * 苹果动效的四个支柱（本类逐一落地）：
 * ------------------------------------------------------------------
 * ① **时长阶梯**（iOS HIG 口径）：不是所有动画都用同一个时长。
 *    按压 100ms（必须即时，晚 16ms 都觉得「粘手」）→
 *    微交互 200ms（开关、chip）→
 *    标准转场 350ms（iOS 默认 push/pop）→
 *    大面板 500ms（sheet、覆盖层）→
 *    主题切换 380ms（跨越多元素的整体换色，慢一点才不刺眼）。
 *
 * ② **曲线语义**：
 *    · 进场用 EaseOut（快出慢收 —— iOS 的 curveEaseOut ≈
 *      cubic-bezier(0, 0, 0.58, 1)）：元素「冲进来再稳稳停住」；
 *    · 退场用 EaseIn（慢起快走）：元素「被抽走」，退场要比进场快，
 *      不抢入场戏；
 *    · **弹簧**（springMotion）：iOS 的核心质感来源。凡是
 *      「从无到有出现」的元素（弹窗、徽标、按压缩放回弹）都用
 *      弹簧，而不是 EaseOut —— EaseOut 是「机械到位」，
 *      弹簧是「物理到位」，差的就是那一下 Q 弹。
 *      参数口径（ArkUI curves.springMotion(response, dampingFraction)）：
 *        response  = 自然振动周期（ms），越大越慢；
 *        damping   = 阻尼比，1 = 临界阻尼（不回弹）、
 *                    0.75 = iOS 默认（轻微过冲）、
 *                    0.5 = 明显回弹。
 *
 * ③ **进场缩放（iOS Liquid Glass 的标志动作）**：
 *    弹窗/面板出现时从 92% 缩放到 100% —— 模拟「从指尖/屏幕深处
 *    弹出」的纵深。苹果的 alert / sheet / 分享面板全部是这个动作。
 *    配合弹簧曲线，缩放会在 100% 附近有一次极轻过冲再回落，
 *    这就是「活的」感觉。本项目 GlassDialog 早前已有 0.92 缩放进场，
 *    但用的是 200ms EaseOut（机械到位），本轮换成弹簧。
 *
 * ④ **按压反馈（iOS 的「即时响应」契约）**：
 *    手指按下**立刻**缩到 96%（100ms），抬起用弹簧回弹
 *    （350ms / 0.75）。关键在「立刻」：视觉反馈必须与触摸事件
 *    同帧，晚一帧就会觉得「这个按钮是假的」。
 *    本项目早前可点组件（CfCard / CfListRow）没有任何按压反馈，
 *    本轮补齐。
 *
 * 性能红线（继承 GlassLight 的口径）：
 * ------------------------------------------------------------------
 * · 弹簧曲线的 duration 由物理参数自适应，**不要同时写 duration**；
 * · 对挂 backdropBlur 的面板做 scale 动画要克制幅度（≤8%）——
 *   离屏模糊层每帧重采样，大位移会掉帧（Index.ets 胶囊注释有实测记录）；
 * · 长列表内不做逐项弹簧入场（一屏十几项同时跑弹簧会掉帧），
 *   只做整体淡入；stagger 仅限一屏内的少量固定卡片（看板 6 项）。
 */

import { curves } from '@kit.ArkUI'

/** 弹簧参数预设（response / dampingFraction） */
export class SpringPreset {
  /** iOS 默认：轻微过冲。弹窗进场、按压缩放回弹、徽标入场 */
  static readonly DEFAULT_RESPONSE: number = 350
  static readonly DEFAULT_DAMPING: number = 0.75
  /** 轻快：小元素（chip、开关），周期短、回弹明显 */
  static readonly SNAPPY_RESPONSE: number = 260
  static readonly SNAPPY_DAMPING: number = 0.72
  /** 稳重：大面板（sheet），周期长、阻尼高，不晃 */
  static readonly HEAVY_RESPONSE: number = 420
  static readonly HEAVY_DAMPING: number = 0.85
}

export class AppleMotion {
  /* ==================== 时长阶梯 ==================== */

  /** 按压响应：手指按下立即缩放的时长。iOS 口径 ~100ms，必须即时 */
  static readonly PRESS_MS: number = 100
  /** 微交互：开关、chip 选中、数字滚动 */
  static readonly MICRO_MS: number = 200
  /** 标准转场：iOS 默认 push/pop 时长 */
  static readonly BASE_MS: number = 350
  /** 大面板：sheet / 覆盖层弹窗（比标准转场慢一档，强调「层次升起」） */
  static readonly SHEET_MS: number = 500
  /** 主题切换：整体换色，慢一档才不刺眼（原全库 620ms 统一收到此值） */
  static readonly THEME_MS: number = 380

  /* ==================== 曲线 ==================== */

  /** 进场标准曲线：快出慢收（≈ iOS curveEaseOut） */
  static readonly IN: Curve = Curve.EaseOut
  /** 退场标准曲线：慢起快走（≈ iOS curveEaseIn），退场要比进场快 */
  static readonly OUT: Curve = Curve.EaseIn
  /** 位移/尺寸过渡：两端缓（≈ iOS curveEaseInOut），用于药丸滑动等 */
  static readonly EASE: Curve = Curve.EaseInOut
  /** 摩擦曲线：用于内容滚动减速（ArkUI Friction ≈ iOS 滚动摩擦） */
  static readonly FRICTION: Curve = Curve.Friction

  /* ==================== 进场 / 退场几何 ==================== */

  /**
   * 弹窗/面板进场缩放起点（iOS Liquid Glass 标志动作）。
   * ⚠️ 上限 0.92：对挂 backdropBlur 的面板，缩放过大会让离屏模糊层
   *    每帧重采样大面积区域 → 掉帧。8% 的位移肉眼已足够表达纵深。
   */
  static readonly ENTER_SCALE: number = 0.92

  /** 按压缩放目标（iOS 即时反馈契约） */
  static readonly PRESS_SCALE: number = 0.96

  /** 退场缩放终点（比进场更小一档，强化「被抽走」的方向感） */
  static readonly EXIT_SCALE: number = 0.96

  /* ==================== 曲线工厂 ==================== */

  /**
   * 确定性「弹簧感」曲线：过冲贝塞尔（easeOutBack 族，y1>1 提供过冲）。
   * ------------------------------------------------------------------
   * ⚠️ 凡驱动**可见性**的动画（opacity 0→1 的弹窗面板/徽标入场）必须用
   *   本曲线，禁止 curves.springMotion：物理弹簧实测在预览器对
   *   opacity 0→1 的补间会卡死在初值 —— 表现就是「弹窗只剩遮罩变暗，
   *   面板永远不出现」（2026-10-21 用户实测：积分商城兑换确认弹窗 +
   *   券包核销详情弹窗同炸；同帧的遮罩用的是 EaseOut 就正常）。
   *   真机物理曲线可能正常，但预览器是主验证环境，可见性动画必须
   *   真机/预览器表现一致。本曲线是确定性三次贝塞尔，过冲段提供与
   *   springMotion 等价的 Q 弹感，两端环境行为相同。
   */
  static springLike(): curves.ICurve {
    return curves.cubicBezierCurve(0.34, 1.56, 0.64, 1)
  }

  /**
   * iOS 默认弹簧（轻微过冲）—— 弹窗进场、按压缩放回弹。
   * ⚠️ 不要给弹簧同时写 duration：弹簧时长由物理参数自适应，
   *    硬写 duration 会覆盖物理特性，退化成普通 EaseOut。
   * ⚠️ 返回类型是 ICurve 而非 Curve：ArkUI 的 curves.springMotion()
   *    返回 ICurve（物理曲线对象），与 Curve 枚举不能互赋值 ——
   *    声明成 Curve 会报 "Type 'ICurve' is not assignable to type 'Curve'"。
   * ⚠️ 只用于**常显元素**的属性动画（按压缩放回弹、Tab 选中放大 ——
   *    元素本来可见，曲线卡死也只是停在原位，不会消失）；
   *    可见性动画（0→1 入场）一律走 springLike()，原因见上。
   */
  static spring(): curves.ICurve {
    return curves.springMotion(SpringPreset.DEFAULT_RESPONSE, SpringPreset.DEFAULT_DAMPING)
  }

  /** 轻快弹簧（小元素：chip / 开关 / 徽标） */
  static springSnappy(): curves.ICurve {
    return curves.springMotion(SpringPreset.SNAPPY_RESPONSE, SpringPreset.SNAPPY_DAMPING)
  }

  /** 稳重弹簧（大面板：sheet / 覆盖层） */
  static springHeavy(): curves.ICurve {
    return curves.springMotion(SpringPreset.HEAVY_RESPONSE, SpringPreset.HEAVY_DAMPING)
  }

  /* ==================== 进场 / 退场 TransitionEffect ==================== */

  /**
   * 面板进场：淡入 + 自下方 8vp 浮起 + 92% 缩放到 100%（弹簧）。
   * 三段一起才是 iOS 的「从屏幕深处升起」—— 只有位移是「滑入」，
   * 只有缩放是「弹出」，只有淡入是「显影」，三者缺一都少一层纵深。
   */
  static enterRise(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 8 }))
      .combine(TransitionEffect.scale({ x: AppleMotion.ENTER_SCALE, y: AppleMotion.ENTER_SCALE }))
      .animation({ curve: AppleMotion.springLike() })
  }

  /**
   * 面板退场：淡出 + 轻微缩小（快，不抢入场戏）。
   * 退场刻意不做位移 —— 进场是「从下往上长」，退场只需「原地消失」，
   * 反向滑出会让用户以为页面被推走。
   */
  static exitFade(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: AppleMotion.EXIT_SCALE, y: AppleMotion.EXIT_SCALE }))
      .animation({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.OUT })
  }

  /**
   * 内容步进入场（列表新增项 / 状态切换后的新块）：淡入 + 下方 10vp 浮起。
   * 比面板进场轻一档（无缩放），用于内容区块而不是容器。
   */
  static stepIn(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 10 }))
      .animation({ duration: 220, curve: AppleMotion.IN })
  }

  /** 内容步进退场（与 stepIn 镜像） */
  static stepOut(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
      .animation({ duration: 160, curve: AppleMotion.OUT })
  }

  /**
   * 徽标 / 计数入场：从 50% 弹簧弹入（醒目，一次性）。
   * 用于「兑换成功」徽标、角标更新 —— 数字变化要能被余光注意到。
   */
  static badgeIn(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
      .animation({ curve: AppleMotion.springLike() })
  }

  /* ==================== 入场 stagger（看板 6 卡用） ==================== */

  /**
   * 列表入场的逐项延时阶梯（ms）。
   * ------------------------------------------------------------------
   * 一屏内的少量固定卡片（看板 6 项）用 stagger 制造「依次落座」的
   * 节奏感；索引越大延时越长，最后一项也不超过 260ms ——
   * 拖太长用户会等得不耐烦（HIG 建议 stagger 总时长 ≤300ms）。
   * ⚠️ 只用于**固定数量**的少量卡片：长列表逐项跑动画会掉帧，
   *    且滚动时新项会不停触发，反而乱。
   */
  static stagger(index: number): number {
    return Math.min(260, index * 30)
  }
}
