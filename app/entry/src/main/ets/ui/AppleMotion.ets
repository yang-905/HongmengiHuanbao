import { curves } from '@kit.ArkUI'

export class SpringPreset {
  static readonly DEFAULT_RESPONSE: number = 350
  static readonly DEFAULT_DAMPING: number = 0.75
  static readonly SNAPPY_RESPONSE: number = 260
  static readonly SNAPPY_DAMPING: number = 0.72
  static readonly HEAVY_RESPONSE: number = 420
  static readonly HEAVY_DAMPING: number = 0.85
}

export class AppleMotion {
  /* 时长阶梯 */
  static readonly PRESS_MS: number = 100
  static readonly MICRO_MS: number = 200
  static readonly BASE_MS: number = 350
  static readonly SHEET_MS: number = 500
  static readonly THEME_MS: number = 380

  /* 曲线 */
  static readonly IN: Curve = Curve.EaseOut
  static readonly OUT: Curve = Curve.EaseIn
  static readonly EASE: Curve = Curve.EaseInOut
  static readonly FRICTION: Curve = Curve.Friction

  /* 进场 / 退场几何 */
  static readonly ENTER_SCALE: number = 0.92
  static readonly PRESS_SCALE: number = 0.96
  static readonly EXIT_SCALE: number = 0.96

  /* 曲线工厂 */

  /**
   * 过冲贝塞尔曲线（easeOutBack）。
   * 用于可见性动画（opacity 0→1）—— 预览器上 springMotion 对 opacity 补间会卡死，
   * 本曲线是确定性三次贝塞尔，真机/预览器表现一致。
   */
  static springLike(): curves.ICurve {
    return curves.cubicBezierCurve(0.34, 1.56, 0.64, 1)
  }

  /** 物理弹簧，仅用于常显元素的属性动画，不能给可见性动画用。 */
  static spring(): curves.ICurve {
    return curves.springMotion(SpringPreset.DEFAULT_RESPONSE, SpringPreset.DEFAULT_DAMPING)
  }

  static springSnappy(): curves.ICurve {
    return curves.springMotion(SpringPreset.SNAPPY_RESPONSE, SpringPreset.SNAPPY_DAMPING)
  }

  static springHeavy(): curves.ICurve {
    return curves.springMotion(SpringPreset.HEAVY_RESPONSE, SpringPreset.HEAVY_DAMPING)
  }

  /* 进场 / 退场 TransitionEffect */

  static enterRise(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 8 }))
      .combine(TransitionEffect.scale({ x: AppleMotion.ENTER_SCALE, y: AppleMotion.ENTER_SCALE }))
      .animation({ curve: AppleMotion.springLike() })
  }

  static exitFade(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: AppleMotion.EXIT_SCALE, y: AppleMotion.EXIT_SCALE }))
      .animation({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.OUT })
  }

  static stepIn(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 10 }))
      .animation({ duration: 220, curve: AppleMotion.IN })
  }

  static stepOut(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
      .animation({ duration: 160, curve: AppleMotion.OUT })
  }

  static badgeIn(): TransitionEffect {
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
      .animation({ curve: AppleMotion.springLike() })
  }

  /* 入场 stagger（看板 6 卡用） */
  static stagger(index: number): number {
    return Math.min(260, index * 30)
  }
}
