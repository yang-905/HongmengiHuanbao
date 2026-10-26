import { AppRouter } from '../../common/router/AppRouter'
import { LocalCoupon } from '../../data/MockStore'
import { LocalStore } from '../../data/LocalStore'
import { AppClock } from '../../utils/AppClock'
import { EcoMoodState } from '../../data/EcoMoodState'
import {
  Accent,
  EcoMood,
  EcoTheme,
  FontSize,
  Neutral,
  Radius,
  Space
} from '../../ui/Theme'
import { CfButton, CfCard, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/*
 * P35 核销成功凭证页（P34 碳惠券包 → 核销后进入）
 * ------------------------------------------------------------------
 * 用户诉求：二维码不再挤在详情弹窗里，独立成页做成「感谢仪式」——
 *   · 大号核销成功徽章 + 「感谢您的低碳生活」主文案
 *   · 核销时间大字展示（= usedAt，AppClock 系统时钟口径，与核销码同源）
 *   · 二维码白底板：内容是中文感谢语 + 精简凭证字段（见
 *     LocalStore.buildQr），微信/相机扫一扫直接展示文本，任何手机都
 *     能读（URL 方案不可取：会跳到不存在的域名；容量红线见 buildQr）
 * 已核销的券从列表回看也进本页（usedAt / qrContent 均持久化，幂等）。
 *
 * 入场动画对齐券详情弹窗口径：徽章弹簧弹入（springMotion）、
 * 内容步进浮入（220ms EaseOut）—— TransitionEffect 常量与 GlassDialog
 * 同款（独立声明：跨文件共享需再抽 ui 层，两处复制成本更低）。
 */

/** 步进入场：淡入 + 自下方 10vp 浮起（与 GlassDialog.STEP_IN 同口径） */
/** 通用步进入场：淡入 + 自下方 10vp 浮起（AppleMotion 口径，与 GlassDialog 同源） */
const STEP_IN: TransitionEffect = AppleMotion.stepIn()

/** 徽章弹簧入场：从 50% 弹入，一次到位（AppleMotion 口径） */
const BADGE_SPRING_IN: TransitionEffect = AppleMotion.badgeIn()

@Component
export struct CouponRedeemPage {
  /*
   * 深色模式依赖注入（与 CouponListPage 同款三件套）：
   * 色值经 tc 取值即建立 themeTick 依赖，换肤广播后强制重取 static 新色。
   */
  @StorageProp('themeTick') themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /** 全局碳情绪档位（响应式）：页面底色随当日减排档位过渡 */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 记录变更信号：只重算碳档位，保证切回来背景立刻变色 */
  @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0

  onEcoTick(): void {
    EcoMoodState.refresh()
  }

  /** 当前展示的券（aboutToAppear 按 AppStorage 参数从本地库捞出） */
  @State private coupon: LocalCoupon = {
    couponId: '', benefitCode: '', benefitName: '', benefitIcon: '🎁',
    points: 0, kind: 'coupon', issuedAt: 0, expireAt: 0,
    status: 'unused', usedAt: 0, qrContent: ''
  }

  /** 券是否就位（false = 参数丢失/券不存在 → 兜底空态） */
  @State private ready: boolean = false

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      // 路由参数：goWithParam 只支持 number，券号是 string —— 走 AppStorage
      // string 键（跳转处 setOrCreate，这里读取后清理，见 PageMap 头注释同思路）
      const id: string | undefined = AppStorage.get<string>('redeemCouponId')
      AppStorage.setOrCreate<string>('redeemCouponId', '')
      if (id === undefined || id.length === 0) {
        this.ready = false
        return
      }
      const c: LocalCoupon | null = LocalStore.couponById(id)
      if (c === null) {
        this.ready = false
        return
      }
      // 历史数据兜底：更早期构建核销的券可能没有 qrContent（或还是旧
      // 中文长文本格式、码图过密扫不出），进凭证页统一补生成新格式
      // （幂等，新格式内容原样返回），保证历史核销券回看也能扫
      if (c.status === 'used') {
        await LocalStore.ensureQrContent(id)
      }
      this.coupon = c
      this.ready = true
    } catch (err) {
      this.ready = false
    }
  }

  /* ---------- 展示格式 ---------- */

  /** 核销时间（大字）：usedAt 毫秒戳 → 'yyyy-MM-dd HH:mm:ss'，系统时钟口径 */
  private redeemTimeStr(): string {
    if (this.coupon.usedAt > 0) {
      const d: Date = new Date(this.coupon.usedAt)
      return AppClock.fmtDate(d) + ' ' + AppClock.fmtTime(d)
    }
    // 理论不触发（本页只在核销后进入）：兜底显示当前时间
    return AppClock.dateTimeStr()
  }

  /** 有效期至 */
  private expireStr(): string {
    return AppClock.fmtDate(new Date(this.coupon.expireAt))
  }

  /**
   * 页面入场动画状态（苹果口径，见下方最外层容器的 onAppear）。
   * 每次 push 进入本页都会重放到 0→1，观感是「内容错峰上浮」。
   */
  @State private pageIn: boolean = false
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisAppear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Stack() {
        Column() {
          CfTopBar({
            title: '核销凭证',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll() {
            Column({ space: Space.LG }) {
              if (this.ready) {
                this.RedeemBody()
              } else {
                // 兜底：参数丢失 / 券不存在（正常路径到不了这里）
                Text('券不存在或已删除')
                  .fontSize(FontSize.BODY)
                  .maxFontScale(FontSize.SCALE_TEXT)
                  .fontColor(this.tc(Neutral.TEXT_SUB))
                  .margin({ top: 80 })
              }
            }
            .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
            .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.XL, bottom: 30 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .layoutWeight(1)
          .width('100%')
          .height('100%')
          .backgroundColor(this.tc(EcoTheme.bg(this.ecoLevel)))
          // 液态玻璃：半透明底 + 实时高斯模糊（⚠️ 底色必须半透明，
          // 纯色会把下层模糊完全盖住 —— 与券包页同口径）
          .backdropBlur(EcoMood.blurOf(this.ecoLevel))
          .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
          .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
        }
        .width('100%')
        .height('100%')
        // 页面底色必须铺满含顶栏的整列：顶栏区域无人上色时，
        // NavDestination 默认白底透出来 = 深色模式顶部「白额头」，
        // 白色顶栏文字压白底直接隐形（同设置页修复口径）
        .backgroundColor(this.tc(EcoTheme.bg(this.ecoLevel)))
      }
      // 页面入场动画（苹果口径：整页淡入 + 下方 12vp 浮起，见 AppleMotion）
      // ⚠️ 必须延一帧再置 true：同帧内 false→true 会被 ArkUI 合并，
      //    opacity/translate 补间不播（同 Index slotDeleteIn / DashboardPage entered 手法）。
      // ⚠️ 属性必须写在容器闭合「之后」：写在闭合前会变成最后一个子节点的属性。
      .onAppear((): void => {
        this.pageInTimer = setTimeout((): void => {
          this.pageInTimer = -1
          /*
           * ⚠️ 用 animateTo 而不是给本容器挂 .animation()：
           *   .animation() 会按作用域**继承给所有子组件**（含条件渲染的
           *   弹窗/覆盖层），父子动画叠加时 ArkUI 行为不稳定 —— 表现为
           *   弹窗入场动画被压制或丢失。animateTo 只动画化闭包内这次状态
           *   变更所影响的属性（本容器的 opacity/translate），作用域显式、
           *   零继承歧义。
           */
          this.getUIContext().animateTo({
            duration: AppleMotion.BASE_MS,
            curve: AppleMotion.IN
          }, (): void => {
            this.pageIn = true
          })
        }, 16)
      })
      .onDisAppear((): void => {
        if (this.pageInTimer !== -1) {
          clearTimeout(this.pageInTimer)
          this.pageInTimer = -1
        }
      })
      .opacity(this.pageIn ? 1 : 0)
      .translate({ y: this.pageIn ? 0 : 12 })

    }
    .hideTitleBar(true)
  }

  /* ---------- 核销成功感谢主体 ---------- */

  @Builder
  RedeemBody() {
    // ✓ 大徽章：品牌绿圆盘 + 白勾 + 外发光，弹簧弹入（springMotion）
    Column() {
      CfIcon({ kind: 'ui', code: 'check', iconSize: 34, color: '#FFFFFF' })
    }
    .width(76)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.tc(Accent.SUCCESS))
    .borderRadius(38)
    // 外发光：呼吸感的光晕（正向设计：核销成功是最亮的时刻）
    .shadow({
      radius: 26,
      color: this.tc(EcoTheme.primary(this.ecoLevel)),
      offsetX: 0,
      offsetY: 6
    })
    .transition(TransitionEffect.asymmetric(BADGE_SPRING_IN, STEP_IN))

    // 感谢文案组
    Column({ space: 8 }) {
      Text('核销成功')
        .fontSize(34)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
      Text('感谢您的低碳生活')
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
      Text('感谢您对本应用的支持，每一次绿色选择\n都在让城市多一抹绿')
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .textAlign(TextAlign.Center)
        .lineHeight(19)
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .transition(TransitionEffect.asymmetric(STEP_IN, STEP_IN))

    // 票根卡：核销信息（核销时间是主角，大字展示）
    // ⚠️ transition 必须挂在内置容器上（自定义组件不能直接挂），
    // 故包一层 Column 承载出入场动画
    Column() {
      CfCard({ pad: Space.LG }) {
      Column({ space: Space.MD }) {
        Row({ space: Space.MD }) {
          CfIcon({ kind: 'benefit', code: this.coupon.benefitCode, iconSize: 24 })
          Column({ space: 2 }) {
            Text(this.coupon.benefitName)
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.coupon.points + ' 积分 · 券号 ' + this.coupon.couponId)
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        // 分隔虚线（票根撕裂线意象）
        Row()
          .width('100%')
          .height(1)
          .border({ width: { bottom: 1 }, style: BorderStyle.Dashed, color: this.tc(Neutral.BORDER) })

        Column({ space: 6 }) {
          Text('核销时间')
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          // 主角：设备系统时间的当时时刻（与核销码内文本同源同刻）
          Text(this.redeemTimeStr())
            .fontSize(FontSize.TITLE)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          Text('有效期至 ' + this.expireStr())
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')
      }
      }
    }
    .width('100%')
    .transition(TransitionEffect.asymmetric(STEP_IN, STEP_IN))

    // 二维码凭证板：纯白底（深色模式也保持白底黑码，扫码对比度优先）
    Column() {
      CfCard({ pad: Space.LG }) {
      Column({ space: Space.MD }) {
        Column() {
          // 220vp：内容为单行英文感谢语版（~146 字节，v4 格式见 LocalStore.buildQr
          // —— 单行中文版微信结果页仍报「不支持演示该效果」，此场景只能用 ASCII），
          // 靠加大码图补偿模块尺寸，可扫性优先（页面可滚动，高度无约束）
          QRCode(this.coupon.qrContent.length > 0 ? this.coupon.qrContent : ' ')
            .width(220)
            .height(220)
            .color('#1A1F1C')
        }
        .padding(Space.SM)
        .backgroundColor('#FFFFFF')
        .borderRadius(Radius.SM)

        Text('核销凭证')
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Text('微信 / 相机扫一扫，即可查看核销信息')
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .transition(TransitionEffect.asymmetric(STEP_IN, STEP_IN))

    // 完成
    CfButton({
      text: '完成',
      block: true,
      onTap: (): void => {
        AppRouter.pathStack.pop()
      }
    })
    .transition(TransitionEffect.asymmetric(STEP_IN, STEP_IN))
  }
}
