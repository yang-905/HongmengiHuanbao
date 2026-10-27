/**
 * 玻璃弹窗与券视觉（兑换确认 / 券详情 / 券卡三段式）
 *   ① GlassDialog      —— 弹窗公共工具（遮罩色 / 面板有效底色 / 时间格式）
 *   ② CouponTicketView —— 券卡视觉（列表页卡片与详情弹窗大图共用同一实现）
 *   ③ ExchangeConfirmDialog —— 积分商城兑换确认弹窗（覆盖层弹窗）
 *   ④ CouponDetailDialog    —— 券详情弹窗（覆盖层弹窗，含核销二维码）
 *
 * 弹窗范式：普通 @Component + 宿主 Stack 覆盖层，禁用 @CustomDialog。
 * 深色 / 碳情绪口径：static 色值经 tc()/tw() 取值建立 themeTick 依赖，
 * 玻璃面走 GlassLight.surface + borderColors + shadowOf 三件套。
 */

import { LocalBenefit, LocalCoupon } from '../data/MockStore'
import { LocalStore } from '../data/LocalStore'
import { AppClock } from '../utils/AppClock'
import { toast } from './Toast'
import { Accent, EcoTheme, FontSize, Glass, Neutral, Radius, Shadow, Space, ThemePalette } from './Theme'
import { CfButton, CfCloseIcon, CfPill } from './Components'
import { GlassLight, GlassTier } from './GlassLight'
import { AppleMotion } from './AppleMotion'
import { CfIcon } from './Icon';

export class GlassDialog {
  /** 券卡固定高度（三段式：左主区 / 中缝 / 右券面） */
  static readonly TICKET_H: number = 112
  /** 中缝宽度（vp） */
  static readonly SEAM_W: number = 10
  /**
   * 缺口圆直径（vp）。
   * ⚠️ 必须**大于**中缝宽度：缺口圆的可见部分是「咬进左右两区」的那一圈，
   *    只有 NOTCH_D > SEAM_W 才能形成票券半圆缺口；等于中缝宽时圆被
   *    中缝完全吞掉，只剩一道竖缝（那不是券，是裂口）。
   */
  static readonly NOTCH_D: number = 16
  /** 中缝虚线段数 */
  static readonly DASH_N: number = 12

  /**
   * CouponTicketView.notchColor 的默认值（浅色页面根实色近似）：
   * 宿主总会显式覆盖（列表页传 EcoTheme.bgSolid、详情弹窗传
   * panelNotch() 合成色），此默认仅兜底防漏传。
   */
  static readonly NOTCH_DEFAULT: string = '#FBF8F3'

  /** 弹窗遮罩色：浅色墨绿 / 深色近黑（跟随 ThemePalette.dark） */
  static maskColor(): string {
    return ThemePalette.dark ? 'rgba(0,0,0,0.56)' : 'rgba(20,26,24,0.45)'
  }

  /** 弹窗面板有效底色（券缺口圆填色）：遮罩 + 页面底 + 玻璃平涂的合成 */
  static panelNotch(ambientSolid: string): string {
    const mask: number[] = GlassLight.rgbaOf(GlassDialog.maskColor())
    const masked: number[] = GlassLight.rgbaOf(
      GlassLight.over(GlassLight.rgbaOf(ambientSolid), mask, 1))
    return GlassLight.over(masked, GlassLight.rgbaOf(Glass.PANEL_LIVE_BG), 1)
  }

  /** 补零（月/日/时/分） */
  static pad2(n: number): string {
    return n < 10 ? '0' + n : '' + n
  }

  /** 时间戳 → MM-DD HH:mm（券面与信息行空间有限，不展示年份） */
  static fmtTime(ts: number): string {
    const d: Date = new Date(ts)
    return GlassDialog.pad2(d.getMonth() + 1) + '-' + GlassDialog.pad2(d.getDate()) +
      ' ' + GlassDialog.pad2(d.getHours()) + ':' + GlassDialog.pad2(d.getMinutes())
  }

  /** 距失效还剩几天（向上取整；已过期返回 0） */
  static daysLeft(expireAt: number): number {
    // 时间口径（本地时间校准，见 AppClock）：与 exchange() 的 now 同源，
    // 都取系统时钟 —— 倒计天数与「是否过期」口径一致
    const ms: number = expireAt - AppClock.now()
    if (ms <= 0) return 0
    return Math.ceil(ms / (24 * 60 * 60 * 1000))
  }

  /** 权益类型标签（植树认养与普通权益券在券面上一眼可辨） */
  static kindLabel(kind: string): string {
    return kind === 'tree' ? '植树认养' : '权益券'
  }
}

/**
 * 券卡三段式：左主区（图标/名称/有效期）｜中缝（半圆缺口 + 虚线）｜右券面（积分数）
 * 外层 Row .clip(true) 把缺口圆溢出半圆裁掉，只留咬进卡片的内侧半圆；
 * 缺口圆直径 16 > 中缝宽 10，视觉上是页面从票券边缘「啃」进了两个半圆。
 */
@Component
export struct CouponTicketView {
  coupon: LocalCoupon = {
    couponId: '', benefitCode: '', benefitName: '', benefitIcon: '🎁',
    points: 0, kind: 'coupon', issuedAt: 0, expireAt: 0,
    status: 'unused', usedAt: 0, qrContent: ''
  };
  /**
   * 'unused' | 'used' | 'expired'，调用方按 LocalStore.couponStatus 传入。
   * 必须 @Prop：宿主核销后就地更新数据时，普通成员不会跟随父级同步。
   */
  @Prop status: string = 'unused';
  /** 缺口圆填充色 = 卡片后方有效底色（列表页传 bgSolid，弹窗传 panelNotch） */
  notchColor: string = GlassDialog.NOTCH_DEFAULT;
  /** 点击回调（列表页打开详情用；详情弹窗内不传） */
  onTap?: () => void;

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

  @StorageProp('themeTick') themeTick: number = 0

  /** 全局碳情绪档位（响应式）：右券面底色与数字色跟随档位 */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 可用态 = 未使用；已使用 / 已过期降级为灰版（无投影、整体压暗） */
  private active(): boolean {
    return this.status === 'unused'
  }

  /** 状态药丸文案：未使用按剩余天数真实倒计（领取当天即 7 天） */
  private statusText(): string {
    if (this.status === 'used') return '已使用'
    if (this.status === 'expired') return '已过期'
    return GlassDialog.daysLeft(this.coupon.expireAt) + ' 天后失效'
  }

  /** 状态药丸色调 */
  private statusTone(): string {
    if (this.status === 'used') return 'muted'
    if (this.status === 'expired') return 'danger'
    return 'warning'
  }

  /** 虚线段下标（固定段数，build 稳定） */
  private dashIndexes(): number[] {
    const out: number[] = []
    for (let i: number = 0; i < GlassDialog.DASH_N; i++) out.push(i)
    return out
  }

  build() {
    Row({ space: 0 }) {
      Column({ space: 5 }) {
        Row({ space: Space.SM }) {
          Stack({ alignContent: Alignment.Center }) {
            CfIcon({ kind: 'benefit', code: this.coupon.benefitCode, iconSize: 22 })
          }
          .width(38)
          .height(38)
          .backgroundColor(this.active()
            ? this.tc(EcoTheme.primaryPale(this.ecoLevel))
            : this.tc(Neutral.SURFACE))
          .borderRadius(Radius.SM)
          Column({ space: 2 }) {
            Text(this.coupon.benefitName)
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.active() ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(GlassDialog.kindLabel(this.coupon.kind) + ' · ' + this.coupon.points + ' 积分')
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .constraintSize({ minWidth: 0 })
          CfPill({ text: this.statusText(), tone: this.statusTone() })
        }
        .width('100%')
        Text('有效期至 ' + GlassDialog.fmtTime(this.coupon.expireAt))
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      .justifyContent(FlexAlign.Center)
      .height('100%')
      .padding({ left: Space.MD, right: Space.XS })
      .backgroundColor(this.active() ? this.tc(Glass.CARD_BG) : this.tc(Neutral.SURFACE))

      Column() {
        Circle()
          .width(GlassDialog.NOTCH_D)
          .height(GlassDialog.NOTCH_D)
          .fill(this.notchColor)
          .margin({ top: -GlassDialog.NOTCH_D / 2 })
        Column({ space: 3 }) {
          ForEach(this.dashIndexes(), (i: number) => {
            Column()
              .width(2)
              .backgroundColor(this.tc(Neutral.BORDER))
              .layoutWeight(1)
          }, (i: number): string => 'dash_' + i)
        }
        .layoutWeight(1)
        Circle()
          .width(GlassDialog.NOTCH_D)
          .height(GlassDialog.NOTCH_D)
          .fill(this.notchColor)
          .margin({ bottom: -GlassDialog.NOTCH_D / 2 })
      }
      .width(GlassDialog.SEAM_W)
      .height('100%')

      Column({ space: 2 }) {
        Text('' + this.coupon.points)
          .fontSize(FontSize.DISPLAY)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.active()
            ? this.tc(EcoTheme.primaryDeep(this.ecoLevel))
            : this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
        Text('积分')
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.active()
            ? this.tc(EcoTheme.primaryDeep(this.ecoLevel))
            : this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .width(92)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.active()
        ? this.tc(EcoTheme.primaryPale(this.ecoLevel))
        : this.tc(Neutral.SURFACE))
    }
    .width('100%')
    .height(GlassDialog.TICKET_H)
    .borderRadius(Radius.MD)
    /* 外层 clip：缺口圆溢出半圆被裁（只留咬进卡片的内侧半圆），
     * 左右两区的直角统一收成外框圆角（两区不各自设圆角，见类注释） */
    .clip(true)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(this.active() ? this.tw(Shadow.card()) : Shadow.none())
    .opacity(this.active() ? 1 : 0.75)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap()
    })
  }
}

/**
 * 积分商城兑换确认覆盖层弹窗，居中。
 * 宿主传 benefit / available / visible 与两个回调；确认回调里执行
 * LocalStore.exchange，取消与确认都由宿主卸载。
 */
@Component
export struct ExchangeConfirmDialog {
  /**
   * 待兑换权益。
   * ⚠️ 必须是 @Prop：弹窗在宿主里是「挂载 → 退场 200ms → 卸载」的覆盖层，
   *   若退场期间用户又点了另一张权益卡，宿主只改数据不重挂载组件，
   *   普通成员变量不会被父级同步（ArkUI 单向数据流只对 @Prop/@Link 生效），
   *   面板就会停留在上一张券的内容上（用户截图反馈「点开关闭没反应」）。
   */
  @Prop benefit: LocalBenefit = {
    benefitId: 0, benefitCode: '', benefitName: '', points: 0,
    description: '', icon: '🎁'
  };
  /** 当前可用积分（打开弹窗时传入，用于「兑换后剩余」预览） */
  @Prop available: number = 0;
  /**
   * 可见性：驱动入场退场动画（宿主挂载后延一帧置 true，关闭时先置 false）。
   * ⚠️ 必须 @Prop（普通成员不会跟随父级更新，退场/再入场动画都失效）。
   */
  @Prop visible: boolean = false;
  /** 取消 / 点遮罩（宿主卸载弹窗） */
  onCancel: () => void = (): void => {}
  /** 确认兑换（宿主执行兑换并卸载弹窗） */
  onConfirm: () => void = (): void => {}

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 兑换后剩余（兜底不为负：入口已按可兑换过滤，防御性取 max） */
  private remain(): number {
    return Math.max(0, this.available - this.benefit.points)
  }

  /**
   * 摘要小格（扣除 / 剩余）：玻璃面 + 居中双行。
   * ⚠️ 宽度必须用 layoutWeight(1) 而非 width('100%')：
   *   两格同处一个 Row，各占 100% 会把第二格顶出面板（用户截图：右侧
   *   「兑换后剩余」被裁成一条缝）。layoutWeight 让两格各占一半。
   */
  @Builder
  SummaryCell(label: string, value: string, color: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
      Text(value)
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding({ top: Space.SM, bottom: Space.SM })
    .alignItems(HorizontalAlign.Center)
    .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.CARD, '', 1)))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .borderRadius(Radius.SM)
  }

  build() {
    Stack() {
      /* 遮罩：全屏，点击关闭（等价原 CustomDialog 的 autoCancel: true） */
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(GlassDialog.maskColor())
        .opacity(this.visible ? 1 : 0)
        .animation({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.IN })
        .onClick((): void => {
          this.onCancel()
        })
      /* 居中定位层：hitTestBehavior(Transparent) 自身不吃触摸事件，
       * 面板以外的点击穿透给遮罩层；面板相对整屏居中 */
      Column()
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent) {
        Column({ space: Space.LG }) {
          /* 权益图标 + 标题 + 权益名 */
          Row({ space: Space.MD }) {
            Stack() {
              CfIcon({ kind: 'benefit', code: this.benefit.benefitCode, iconSize: 26 })
            }
            .width(46)
            .height(46)
            .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
            .borderRadius(Radius.SM)
            Column({ space: 3 }) {
              Text('确认兑换')
                .fontSize(FontSize.HEADING)
                .maxFontScale(FontSize.SCALE_TEXT)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(Neutral.TEXT))
                .maxLines(1)
              Text(this.benefit.benefitName)
                .fontSize(FontSize.SMALL)
                .maxFontScale(FontSize.SCALE_TEXT)
                .fontColor(this.tc(Neutral.TEXT_SUB))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .constraintSize({ minWidth: 0 })
          }
          .width('100%')

          /* 摘要双格：扣除积分 / 兑换后剩余
           * ⚠️ 「扣除积分」只显示正数（500），不带负号 ——
           *   标签「扣除积分」本身已表达扣减语义，再加负号是重复表达，
           *   用户截图明确要求「不是扣除-500，应该是500」。 */
          Row({ space: Space.MD }) {
            this.SummaryCell('扣除积分', '' + this.benefit.points, this.tc(Accent.WARNING))
            this.SummaryCell('兑换后剩余', '' + this.remain(),
              this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          }
          .width('100%')

          /* 存入提示 */
          Row({ space: Space.SM }) {
            CfIcon({ kind: 'ui', code: 'clock', iconSize: 13, color: this.tc(Neutral.TEXT_SUB) })
            Text('兑换后存入「碳惠券包」，7 天内有效')
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .lineHeight(17)
              .maxLines(2)
              .layoutWeight(1)
              .constraintSize({ minWidth: 0 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          /* 操作：取消 / 确定兑换（宿主负责卸载，本组件不持控制器） */
          Row({ space: Space.MD }) {
            CfButton({
              text: '取消',
              primary: false,
              flex: true,
              onTap: (): void => {
                this.onCancel()
              }
            })
            CfButton({
              text: '确定兑换',
              icon: 'check',
              flex: true,
              onTap: (): void => {
                this.onConfirm()
              }
            })
          }
          .width('100%')
        }
        .width(300)
        .padding(Space.XL)
        /* 液态玻璃面板：预合成渐变 + 实时模糊 + 四边异色描边 + 投影（全库三件套） */
        .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, '', 1)))
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
        .borderRadius(Radius.XL)
        .shadow(this.tw(GlassLight.shadowOf(GlassTier.PANEL)))
        .opacity(this.visible ? 1 : 0)
        .scale({ x: this.visible ? 1 : AppleMotion.ENTER_SCALE, y: this.visible ? 1 : AppleMotion.ENTER_SCALE })
        .animation({ curve: AppleMotion.springLike() })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 通用步进入场：淡入 + 自下方 10vp 浮起 */
const STEP_IN: TransitionEffect = AppleMotion.stepIn()

/** 通用步进退场：淡出 + 轻微缩小（退场要快，不抢入场戏） */
const STEP_OUT: TransitionEffect = AppleMotion.stepOut()

/** 「已核销」徽标入场：从 50% 弹簧弹入（一次性，比步进更醒目） */
const BADGE_SPRING_IN: TransitionEffect = AppleMotion.badgeIn()

/**
 * 券详情覆盖层弹窗，居中。券大图 + 明细 + 按状态三态操作区：
 *  unused —— 两步确认核销；used —— 核销凭证入口；expired —— 置灰。
 */
@Component
export struct CouponDetailDialog {
  /**
   * 当前券。
   * ⚠️ 必须是 @Prop（与 ExchangeConfirmDialog 同理）：弹窗在宿主里
   *   「挂载 → 退场 200ms → 卸载」，退场窗口内用户再点另一张券时
   *   宿主只换数据不重挂载，普通成员变量不会被父级同步，
   *   面板会停在上一张券的内容上。
   */
  @Prop coupon: LocalCoupon = {
    couponId: '', benefitCode: '', benefitName: '', benefitIcon: '🎁',
    points: 0, kind: 'coupon', issuedAt: 0, expireAt: 0,
    status: 'unused', usedAt: 0, qrContent: ''
  };
  /**
   * 可见性：驱动入场退场动画（宿主挂载后延一帧置 true，关闭时先置 false）。
   * ⚠️ 必须是 @Prop：普通成员不跟随父级更新 → 退场动画不播、看起来「闪没」。
   */
  @Prop visible: boolean = false;
  /** 取消 / 点遮罩（宿主卸载弹窗） */
  onCancel: () => void = (): void => {}
  /**
   * 核销成功回调：携带券号 —— 宿主（券包页）据此关闭弹窗并跳转
   * 核销凭证页（P35 CouponRedeemPage，二维码已独立成页）。
   * 打开已核销券时「查看核销凭证」按钮复用同一出口。
   */
  onUsed: (couponId: string) => void = (couponId: string): void => {}
  /** 本次会话新生成的核销码（空 = 尚未在本弹窗内使用；驱动二维码态切换） */
  @State qrContent: string = ''
  /**
   * 「确定使用吗？」二次确认态：
   *   false = unused 分支一态（提示 + 「确定使用此券」主动作）；
   *   true  = 二态（确认问题 + 取消 / 确定使用，取消可回退一态）。
   * 核销不可撤销，必须有一次显式确认（旧版一步触发，找不到确认入口）。
   */
  @State private confirmUse: boolean = false
  /** 核销事务飞行中标记：防双击重复提交（useCoupon 幂等但 UI 不该连点） */
  @State private confirmUsing: boolean = false

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /**
   * 实时状态：本弹窗内使用过 → 'used'（@State 驱动，无需等持久化回读）；
   * 否则按持久化对象推导（'expired' 由 expireAt 现算，不落盘）。
   */
  private liveStatus(): string {
    if (this.qrContent.length > 0) return 'used'
    return LocalStore.couponStatus(this.coupon)
  }

  /** 缺口色 = 弹窗面板有效底色（遮罩 + 页面底 + 玻璃平涂的合成） */
  private notchColor(): string {
    return GlassDialog.panelNotch(this.tc(EcoTheme.bgSolid(this.ecoLevel)))
  }

  /** 明细行 */
  @Builder
  InfoLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
      Blank().width(Space.MD)
      Text(value)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    }
    .width('100%')
  }

  /**
   * 确定使用：走 LocalStore.useCoupon 事务（幂等 —— 已使用的券重复点击
   * 返回旧核销码而不是再扣一次）。成功后 bump couponTick 让列表页刷新。
   * ⚠️ 整体 try/catch：按钮 onTap 火忘调用，throw 即未捕获 rejection
   * （预览器弹红条），异常降级为 toast。
   */
  private async doUse(): Promise<void> {
    // 防双击：核销事务飞行中忽略后续点击（成功后分支已切走，双击场景
    // 只发生在事务耗时窗口内）
    if (this.confirmUsing) return
    this.confirmUsing = true
    try {
      const qr: string | null = await LocalStore.useCoupon(this.coupon.couponId)
      if (qr === null || qr.length === 0) {
        toast('该券已失效，无法使用')
        return
      }
      // animateTo 包状态变更：unused → used 的面板高度跳变随布局动画
      // 平滑过渡（随后宿主关弹窗并跳转核销凭证页 P35）
      this.getUIContext().animateTo({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.IN }, (): void => {
        this.qrContent = qr
      })
      LocalStore.bumpCouponTick()
      // 带券号回调：宿主关弹窗并跳转核销凭证页（二维码不再原地展示）
      this.onUsed(this.coupon.couponId)
    } catch (err) {
      toast('核销未完成，请重试')
    } finally {
      this.confirmUsing = false
    }
  }

  build() {
    Stack() {
      /* 遮罩：全屏，点击关闭（等价原 CustomDialog 的 autoCancel: true） */
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(GlassDialog.maskColor())
        .opacity(this.visible ? 1 : 0)
        .animation({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.IN })
        .onClick((): void => {
          this.onCancel()
        })
      /* 居中定位层：hitTestBehavior(Transparent) 自身不吃触摸事件，
       * 面板以外的点击穿透给遮罩层；面板相对整屏居中 */
      Column()
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent) {
        Column({ space: Space.LG }) {
          /* 标题行 */
          Row() {
            Text('券详情')
              .fontSize(FontSize.HEADING)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .layoutWeight(1)
            CfCloseIcon({
              btnSize: 32,
              glass: true,
              onTap: (): void => {
                this.onCancel()
              }
            })
          }
          .width('100%')

          /* 券大图（与列表页同一份券视觉） */
          CouponTicketView({
            coupon: this.coupon,
            status: this.liveStatus(),
            notchColor: this.notchColor()
          })

          /* 操作区（按状态三分支） */
          if (this.liveStatus() === 'unused') {
            /* 分支根容器：挂步进 transition —— unused→used 切换时整段
             * 淡缩退场（不包的话旧内容瞬间消失，有一帧跳感） */
            Column({ space: Space.LG }) {
            Column({ space: Space.SM }) {
              this.InfoLine('券号', this.coupon.couponId)
              this.InfoLine('面值', this.coupon.points + ' 积分')
              this.InfoLine('类型', GlassDialog.kindLabel(this.coupon.kind))
              this.InfoLine('领取时间', GlassDialog.fmtTime(this.coupon.issuedAt))
              this.InfoLine('有效期至',
                GlassDialog.fmtTime(this.coupon.expireAt) + '（共 7 天）')
            }
            .width('100%')
            .padding(Space.MD)
            .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.CARD, '', 1)))
            .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
            .borderRadius(Radius.SM)
            /* 底部操作区：一态主动作 → 二态显式确认（核销不可撤销）。
             * 两态切换动画：分支各包一层 Column 挂 asymmetric transition
             * （新态浮入 / 旧态淡缩），onTap 用 animateTo 包状态变更 ——
             * 面板高度变化随布局动画平滑过渡，不再瞬间跳变。 */
            Column({ space: Space.MD }) {
              if (!this.confirmUse) {
                Column({ space: Space.MD }) {
                  Text('使用后即时生成核销二维码，请向工作人员出示')
                    .fontSize(FontSize.SMALL)
                    .maxFontScale(FontSize.SCALE_TEXT)
                    .fontColor(this.tc(Neutral.TEXT_SUB))
                    .maxLines(2)
                    .lineHeight(17)
                    .width('100%')
                  CfButton({
                    text: '确定使用此券',
                    icon: 'ticket',
                    block: true,
                    onTap: (): void => {
                      this.getUIContext().animateTo({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.IN }, (): void => {
                        this.confirmUse = true
                      })
                    }
                  })
                }
                .width('100%')
                .transition(TransitionEffect.asymmetric(STEP_IN, STEP_OUT))
              } else {
                Column({ space: Space.MD }) {
                  Text('确定使用吗？')
                    .fontSize(FontSize.TITLE)
                    .maxFontScale(FontSize.SCALE_TEXT)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.tc(Neutral.TEXT))
                    .maxLines(1)
                    .width('100%')
                  Text('核销后不可恢复，请确认已准备向工作人员出示')
                    .fontSize(FontSize.SMALL)
                    .maxFontScale(FontSize.SCALE_TEXT)
                    .fontColor(this.tc(Neutral.TEXT_SUB))
                    .maxLines(2)
                    .lineHeight(17)
                    .width('100%')
                  Row({ space: Space.MD }) {
                    CfButton({
                      text: '取消',
                      primary: false,
                      flex: true,
                      onTap: (): void => {
                        this.getUIContext().animateTo({ duration: AppleMotion.MICRO_MS, curve: AppleMotion.IN }, (): void => {
                          this.confirmUse = false
                        })
                      }
                    })
                    CfButton({
                      text: '确定使用',
                      icon: 'ticket',
                      flex: true,
                      onTap: (): void => {
                        this.doUse()
                      }
                    })
                  }
                  .width('100%')
                }
                .width('100%')
                .transition(TransitionEffect.asymmetric(STEP_IN, STEP_OUT))
              }
            }
            .width('100%')
            }
            .width('100%')
            .transition(TransitionEffect.asymmetric(STEP_IN, STEP_OUT))
          } else if (this.liveStatus() === 'used') {
            /* 已核销态：二维码不再弹窗内展示（已独立成核销凭证页 P35），
             * 这里只给「已核销」徽标 + 跳转入口；弹簧徽标保留 ——
             * 打开已核销券回看时同样有弹入仪式感。 */
            Column({ space: Space.LG }) {
              /* 「已核销」徽标：从 50% 弹簧弹入（BADGE_SPRING_IN），一次到位 */
              Row({ space: 6 }) {
                Stack({ alignContent: Alignment.Center }) {
                  CfIcon({ kind: 'ui', code: 'check', iconSize: 11, color: '#FFFFFF' })
                }
                .width(18)
                .height(18)
                .backgroundColor(this.tc(Accent.SUCCESS))
                .borderRadius(9)
                Text('已核销')
                  .fontSize(FontSize.CAPTION)
                  .maxFontScale(FontSize.SCALE_NUM)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.tc(Accent.SUCCESS))
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
              .transition(TransitionEffect.asymmetric(BADGE_SPRING_IN, STEP_OUT))
              Text('券号 ' + this.coupon.couponId + ' · 已核销')
                .fontSize(FontSize.CAPTION)
                .maxFontScale(FontSize.SCALE_NUM)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text('核销凭证已生成，扫码即可向工作人员出示')
                .fontSize(FontSize.SMALL)
                .maxFontScale(FontSize.SCALE_TEXT)
                .fontColor(this.tc(Neutral.TEXT_SUB))
                .maxLines(2)
                .lineHeight(17)
                .width('100%')
              CfButton({
                text: '查看核销凭证',
                icon: 'device',
                block: true,
                onTap: (): void => {
                  // 二维码已独立成核销凭证页（P35）：宿主关弹窗并跳转
                  this.onUsed(this.coupon.couponId)
                }
              })
            }
            .width('100%')
            .transition(TransitionEffect.asymmetric(STEP_IN, STEP_OUT))
          } else {
            /* expired 分支同样挂步进 transition：打开过期券时内容随
             * 弹窗浮入，三分支切换风格统一 */
            Column({ space: Space.LG }) {
            Column({ space: Space.SM }) {
              this.InfoLine('券号', this.coupon.couponId)
              this.InfoLine('面值', this.coupon.points + ' 积分')
              this.InfoLine('领取时间', GlassDialog.fmtTime(this.coupon.issuedAt))
              this.InfoLine('有效期至', GlassDialog.fmtTime(this.coupon.expireAt))
            }
            .width('100%')
            .padding(Space.MD)
            .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.CARD, '', 1)))
            .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
            .borderRadius(Radius.SM)
            Column({ space: Space.MD }) {
              Text('该券已超过 7 天有效期，无法使用')
                .fontSize(FontSize.SMALL)
                .maxFontScale(FontSize.SCALE_TEXT)
                .fontColor(this.tc(Neutral.TEXT_SUB))
                .maxLines(2)
                .lineHeight(17)
                .width('100%')
              CfButton({
                text: '知道了',
                primary: false,
                block: true,
                onTap: (): void => {
                  this.onCancel()
                }
              })
            }
            .width('100%')
            }
            .width('100%')
            .transition(TransitionEffect.asymmetric(STEP_IN, STEP_OUT))
          }
        }
        .width(320)
        .padding(Space.XL)
        /* 液态玻璃面板：与兑换确认弹窗同材质 */
        .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, '', 1)))
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
        .borderRadius(Radius.XL)
        .shadow(this.tw(GlassLight.shadowOf(GlassTier.PANEL)))
        .opacity(this.visible ? 1 : 0)
        .scale({ x: this.visible ? 1 : AppleMotion.ENTER_SCALE, y: this.visible ? 1 : AppleMotion.ENTER_SCALE })
        .animation({ curve: AppleMotion.springLike() })
      }
    }
    .width('100%')
    .height('100%')
  }
}
