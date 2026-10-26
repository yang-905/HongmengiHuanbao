import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalStore } from '../../data/LocalStore'
import { LocalCoupon } from '../../data/MockStore'
import { FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfSection, CfTopBar } from '../../ui/Components'
import { CouponDetailDialog, CouponTicketView } from '../../ui/GlassDialog'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**
 * P34 碳惠券包
 * ------------------------------------------------------------------
 * 「我的 → 证书夹」下的二级菜单：集中存放积分商城兑换的权益券。
 * 页面结构：概览大卡（可用/已使用/已过期 + 累计消耗）
 *          + 券卡列表（三段式票券视觉，见 ui/GlassDialog.CouponTicketView）
 *          + 空态引导去积分商城兑换
 *
 * 两条易错点（写错即静默失效）：
 *   ① 券变更必须订阅 couponTick：兑换/核销在 LocalStore 里 bump 该信号，
 *      本页据此重拉；只依赖 aboutToAppear 会导致「兑完回来列表不更新」。
 *   ② 券详情弹窗走**覆盖层范式**（普通 @Component + 宿主 Stack 挂载，
 *      不是 @CustomDialog —— 预览器原生崩溃，见 ui/GlassDialog 文件头）：
 *      宿主持 showDetail/detailIn/detailCoupon 三态，打开先挂载再延一帧
 *      起入场动画，关闭先播退场再卸载（openDetail/closeDetail）。
 */
@Component
export struct CouponListPage {
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
  @State private coupons: LocalCoupon[] = []
  @State private loading: boolean = true

  /**
   * 券详情弹窗（覆盖层范式，非 @CustomDialog —— 预览器原生崩溃，见
   * ui/GlassDialog 文件头）。宿主只出三样：挂载开关 showDetail、动画
   * 闸门 detailIn、当前券；打开/关闭时序见 openDetail/closeDetail。
   */
  @State private showDetail: boolean = false
  @State private detailIn: boolean = false
  @State private detailCoupon: LocalCoupon = {
    couponId: '', benefitCode: '', benefitName: '', benefitIcon: '🎁',
    points: 0, kind: 'coupon', issuedAt: 0, expireAt: 0,
    status: 'unused', usedAt: 0, qrContent: ''
  }
  /**
   * 入场/退场延时定时器（-1 = 无；关闭时先播退场再卸载）。
   * ⚠️ 必须拆成两个字段：原先 open/close 共用一个 detailTimer，
   * 且都先 clearDetailTimer() → 入场 16ms 与退场 200ms 互相清除：
   *   · 退场定时器被入场清掉 → 弹窗永久留在场上，遮罩继续吃点击（卡死）；
   *   · 入场定时器被退场清掉 → detailIn 永为 false，面板透明挂场、
   *     遮罩仍在 → 再点也是「卡住」。
   * 同 PointsMallPage.exchangeEnterTimer/exchangeExitTimer。
   */
  private detailEnterTimer: number = -1
  private detailExitTimer: number = -1

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  aboutToDisappear(): void {
    // 页面出栈时清掉未触发的入场/退场定时器（持 this 的延时会拖住已销毁页面）
    this.clearDetailTimers()
  }

  /** 清入场/退场定时器 */
  private clearDetailTimers(): void {
    if (this.detailEnterTimer >= 0) {
      clearTimeout(this.detailEnterTimer)
      this.detailEnterTimer = -1
    }
    if (this.detailExitTimer >= 0) {
      clearTimeout(this.detailExitTimer)
      this.detailExitTimer = -1
    }
  }

  /**
   * 打开券详情弹窗（覆盖层；使用成功后经 onUsed 回调重拉列表）。
   * ------------------------------------------------------------------
   * 时序分两帧：先挂载（showDetail=true），延后 16ms 再置 detailIn
   * 起入场动画 —— 同一帧内 0→1 会被框架合并，动画不播（同 Index
   * slotDeleteIn 手法）。qrContent 态活在弹窗组件内，卸载即重置，
   * 不会把上次的核销码带给下一张券。
   */
  private openDetail(c: LocalCoupon): void {
    // 已核销的券不再开详情弹窗（弹窗只剩 unused/expired 两种态）：
    // 核销凭证已独立成页（P35），直接进入回看
    if (c.status === 'used') {
      this.goRedeem(c.couponId)
      return
    }
    this.clearDetailTimers()
    this.detailCoupon = c
    // 先复位动画闸门：关→开 时若 detailIn 仍为 true，0→1 不会触发，
    // 面板会「直接出现」而没有入场动画（用户反馈：点开关闭没有动画）。
    this.detailIn = false
    this.showDetail = true
    this.detailEnterTimer = setTimeout((): void => {
      this.detailEnterTimer = -1
      this.detailIn = true
    }, 16)
  }

  /** 关闭券详情弹窗：先置 false 播 200ms 退场，再卸载 */
  private closeDetail(): void {
    if (this.detailEnterTimer >= 0) {
      clearTimeout(this.detailEnterTimer)
      this.detailEnterTimer = -1
    }
    this.detailIn = false
    this.detailExitTimer = setTimeout((): void => {
      this.detailExitTimer = -1
      this.showDetail = false
    }, 200)
  }

  private async load(): Promise<void> {
    try {
      this.coupons = await DataSource.coupons()
    } catch (err) {
      this.coupons = []
    }
  }

  /* ---------- 口径 ---------- */

  /** 可用券数（未使用且未过期） */
  private unusedCount(): number {
    return this.countOf('unused')
  }

  /** 已使用券数 */
  private usedCount(): number {
    return this.countOf('used')
  }

  /** 已过期券数（expired 由时间现算，不落盘） */
  private expiredCount(): number {
    return this.countOf('expired')
  }

  private countOf(status: string): number {
    let n: number = 0
    for (let i: number = 0; i < this.coupons.length; i++) {
      if (LocalStore.couponStatus(this.coupons[i]) === status) n++
    }
    return n
  }

  /** 累计消耗积分（兑换时扣掉的口径，与可用积分此消彼长） */
  private totalSpent(): number {
    let n: number = 0
    for (let i: number = 0; i < this.coupons.length; i++) {
      n += this.coupons[i].points
    }
    return n
  }

  /* ---------- 交互 ---------- */

  private openMall(): void {
    AppRouter.pathStack.pushPathByName(RouteName.POINTS_MALL, null)
  }

  /**
   * 进入核销凭证页（P35）。
   * 券号是 string，goWithParam 只支持 number —— 走 AppStorage string 键
   * 传参（⚠️ setOrCreate：对不存在的键 set 是静默 no-op），
   * 凭证页 aboutToAppear 读取后清理。
   */
  private goRedeem(couponId: string): void {
    AppStorage.setOrCreate<string>('redeemCouponId', couponId)
    AppRouter.pathStack.pushPathByName(RouteName.COUPON_REDEEM, null)
  }

  /* ---------- 动态碳主题 ---------- */

  /**
   * 全局碳情绪档位（响应式）。
   * 订阅 AppStorage：任意页面写入新档位时自动重渲染，全应用背景同步。
   */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 当前档位对应的页面底色 */
  private ecoBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
  }

  /**
   * 券变更信号（响应式）。
   * 兑换成功 / 核销成功 / 切账号都会在 LocalStore.bumpCouponTick 里 +1，
   * 本页据此重拉 —— 「兑完券回来列表立刻多一张」靠的就是它。
   */
  @StorageLink('couponTick') @Watch('onCouponTick') couponTick: number = 0

  /** couponTick 变化的回调入口（@Watch 驱动，ArkUI 无 onStorageChange 生命周期） */
  onCouponTick(): void {
    this.load()
  }

  /**
   * 记录变更信号（响应式）：只重算碳档位、**不重拉券**。
   * 券是兑换产生的落盘资产，与行为记录无关；ecoTick 到这里只为
   * 保证「记完一笔切回来背景立刻变色」（档位由 EcoMoodState 重算）。
   */
  @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0

  onEcoTick(): void {
    EcoMoodState.refresh()
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
            title: '碳惠券包',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.SummaryCard()
              if (this.coupons.length === 0) {
                CfCard({}) {
                  CfEmpty({
                    icon: 'ticket',
                    text: '暂无兑换券',
                    sub: '在积分商城兑换权益后，券会存入这里，7 天内有效'
                  })
                }
                this.EmptyAction()
              } else {
                this.CouponSection()
                this.TipCard()
              }
            }
            .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
            .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 30 })
          }
          .scrollBar(BarState.Off)
          // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
          // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
          .edgeEffect(EdgeEffect.None)
          .width('100%')
          .layoutWeight(1)
          .width('100%')
          .height('100%')
          .backgroundColor(this.ecoBg())
          // 动态碳主题：背景随当日碳排放档位过渡（全局 AppStorage 驱动）
          // 液态玻璃：半透明底 + 实时高斯模糊，让下层内容（导航栈 / 底部玻璃条）
          // 真实透出并虚化。⚠️ 底色必须是半透明，纯色会把模糊完全盖住。
          .backdropBlur(EcoMood.blurOf(this.ecoLevel))
          // 上沿一道高光，模拟玻璃受光面（顶边更亮，视觉上「有厚度」）
          .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
          .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
        }
        .width('100%')
        .height('100%')
        // 页面底色必须铺满含顶栏的整列：顶栏区域无人上色时，
        // NavDestination 默认白底透出来 = 深色模式顶部「白额头」，
        // 白色顶栏文字压白底直接隐形（同设置页修复口径）
        .backgroundColor(this.ecoBg())
        // 券详情弹窗：覆盖层（全屏遮罩 + 居中玻璃面板），挂在页面最上层，
        // 盖住顶栏与列表（等价原 CustomDialog 的全窗口覆盖）
        if (this.showDetail) {
          CouponDetailDialog({
            coupon: this.detailCoupon,
            visible: this.detailIn,
            onCancel: (): void => {
              this.closeDetail()
            },
            onUsed: (couponId: string): void => {
              // 核销成功 → 关弹窗 + 重拉角标 + 跳核销凭证页（感谢仪式）。
              // ⚠️ 必须先关弹窗：凭证页压栈后盖住整页，弹窗若不卸载，
              // 返回时仍会盖在券包列表上。
              this.closeDetail()
              this.load()
              this.goRedeem(couponId)
            }
          })
        }
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

  /* ---------- 概览大卡 ---------- */
  /**
   * 概览卡：左「可用 N 张」大数字 + 右侧「已使用 / 已过期」两组指标。
   * 排版口径同证书夹概览卡：大数字必须给宽度约束（flexShrink(0)），
   * 否则按内容撑开把右侧指标挤出卡片右缘。
   */
  @Builder
  SummaryCard() {
    Row({ space: Space.LG }) {
      Column({ space: 3 }) {
        Text('可用券')
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.85)')
          .maxLines(1)
        Row({ space: 4 }) {
          Text('' + this.unusedCount())
            .fontSize(FontSize.HERO)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1)
          Text('张')
            .fontSize(FontSize.BODY)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor('rgba(255,255,255,0.9)')
            .margin({ top: 10 })
            .maxLines(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minWidth: 0 })
      .flexShrink(0)

      // 右侧两组指标：竖排 + 均分，4 位数值也不溢出
      Row({ space: Space.SM }) {
        this.MetricCell('check', '已使用', this.usedCount() + ' 张')
        this.MetricCell('clock', '已过期', this.expiredCount() + ' 张')
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
    }
    .width('100%')
    .padding(Space.XL)
    .linearGradient({
      angle: 135,
      colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
    })
    .borderRadius(Radius.XL)
    .shadow(this.tw(Shadow.brand()))
  }

  /** 概览卡右侧的单个指标格（竖排标签/数值，layoutWeight 均分） */
  @Builder
  MetricCell(icon: string, label: string, value: string) {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        CfIcon({ kind: 'ui', code: icon, iconSize: 12, color: 'rgba(255,255,255,0.85)' })
        Text(label)
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.85)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(value)
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .constraintSize({ minWidth: 0 })
  }

  /* ---------- 券列表 ---------- */
  @Builder
  CouponSection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '我的券', more: '去商城 ›', onMoreTap: (): void => this.openMall() })
      Column({ space: Space.MD }) {
        ForEach(this.coupons, (c: LocalCoupon) => {
          // 缺口圆填页面根实色：半透明页底叠在 Index 根实色上的等效色，
          // 缺口才与卡片后方页面融为一体（深色两值联动）
          CouponTicketView({
            coupon: c,
            status: LocalStore.couponStatus(c),
            notchColor: this.tc(EcoTheme.bgSolid(this.ecoLevel)),
            onTap: (): void => this.openDetail(c)
          })
          // ⚠️ 键必须掺动态状态：纯 couponId 是稳定键，核销后键不变，
          // ArkUI 复用旧子树 —— 统计卡已刷新、票面却停留「N 天后失效」
          // 不变灰（2026-10-21 用户反馈，同 MinePage 角标冻结实锤）。
          // 掺 status/expired 后键随状态变化 → 旧子树销毁重建，票面即变。
        }, (c: LocalCoupon): string => c.couponId + '-' + LocalStore.couponStatus(c))
      }
      .width('100%')
    }
    .width('100%')
  }

  /* ---------- 空态操作 ---------- */
  @Builder
  EmptyAction() {
    Row() {
      Text('去积分商城兑换')
        .fontSize(FontSize.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .width('100%')
        .textAlign(TextAlign.Center)
        .height(44)
        .linearGradient({
          angle: 90,
          colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
        })
        .borderRadius(Radius.PILL)
    }
    .width('100%')
    .onClick((): void => this.openMall())
  }

  /* ---------- 底部提示 ---------- */
  @Builder
  TipCard() {
    Row({ space: Space.MD }) {
      CfIcon({
        kind: 'ui',
        code: 'clock',
        iconSize: 20,
        color: this.tc(Neutral.TEXT_MUTED)
      })
      Column({ space: 3 }) {
        Text('权益券自领取起 7 天内有效')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text('过期后自动失效；累计已消耗 ' + this.totalSpent() + ' 积分')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(17)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.MD)
  }
}
