import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalStore } from '../../data/LocalStore'
import { LocalBenefit, LocalCoupon, LocalOverview } from '../../data/MockStore'
import { Accent, Biz, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { ExchangeConfirmDialog } from '../../ui/GlassDialog'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**
 * P16 积分商城
 * ------------------------------------------------------------------
 * 真实实现：可用积分头卡 + 8 项权益网格（图标/名称/所需积分/描述）
 *          积分不足置灰（灰底 + 灰字 + 「还差 N 分」），可兑换的点击弹确认框
 */
@Component
export struct PointsMallPage {
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
  /** 权益卡固定行高 */
  private static readonly CARD_H: number = 176
  /** 每行权益卡数：同时决定列宽与行拆分 */
  private static readonly COLS: number = 2
  @State private benefits: LocalBenefit[] = []
  @State private ov: LocalOverview = {
    totalKg: 0, todayKg: 0, monthKg: 0, totalPoints: 0, availablePoints: 0, exchangedPoints: 0,
    recordCount: 0, continuousDays: 0, treeCount: 0, badgeCount: 0, level: 1
  }
  @State private loading: boolean = true
  /**
   * 兑换确认弹窗（覆盖层范式，非 @CustomDialog —— 预览器原生崩溃，见
   * ui/GlassDialog 文件头）。宿主只出三样：挂载开关 showExchange、动画
   * 闸门 exchangeIn、待兑换权益；打开/关闭时序见 openExchange/closeExchange。
   */
  @State private showExchange: boolean = false
  @State private exchangeIn: boolean = false
  @State private exchangeBenefit: LocalBenefit = {
    benefitId: 0, benefitCode: '', benefitName: '', points: 0,
    description: '', icon: '🎁'
  }
  @State private exchangeAvailable: number = 0
  /**
   * 入场 / 退场定时器（必须分开，不能共用一个字段）。
   * ------------------------------------------------------------------
   * ⚠️ 曾经共用一个 exchangeTimer，用户反馈「点击取消后再开有概率卡死」。
   *   根因：openExchange 与 closeExchange 都先 clearExchangeTimer()，
   *   两个定时器互相清对方 —— 退场的 200ms 卸载定时器被入场清掉后，
   *   弹窗永远留在场上（遮罩还在吃点击，看起来就是「卡住」）；
   *   反之入场的 16ms 定时器被退场清掉，exchangeIn 永远为 false，
   *   面板挂在场上却是透明的，用户再点「去兑换」全被遮罩吞掉。
   *   分成两个字段后，两个方向的定时器互不干扰。
   */
  private exchangeEnterTimer: number = -1
  private exchangeExitTimer: number = -1
  /**
   * 顶部余额卡「可用积分」的滚动显示值（动画中间值）。
   * 兑换后 ov.availablePoints 变化 → 数字从旧值滚到新值（数字滚动动画）。
   */
  @State private shownPoints: number = 0
  /** 数字滚动定时器（-1 = 无） */
  private pointsTimer: number = -1

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  aboutToDisappear(): void {
    // 页面出栈时清掉未触发的入场/退场定时器（持 this 的延时会拖住已销毁页面）
    this.clearExchangeTimers()
    this.clearPointsTimer()
  }

  /** 清入场/退场定时器（两个方向各清各的，互不误伤） */
  private clearExchangeTimers(): void {
    if (this.exchangeEnterTimer >= 0) {
      clearTimeout(this.exchangeEnterTimer)
      this.exchangeEnterTimer = -1
    }
    if (this.exchangeExitTimer >= 0) {
      clearTimeout(this.exchangeExitTimer)
      this.exchangeExitTimer = -1
    }
  }

  /**
   * 打开兑换确认弹窗（覆盖层）。
   * ------------------------------------------------------------------
   * 时序分两帧：先挂载（showExchange=true），延后 16ms 再置 exchangeIn
   * 起入场动画 —— 同一帧内 0→1 会被框架合并，opacity/scale 动画不播
   * （同 Index slotDeleteIn 手法）。
   *
   * ⚠️ 退场中的重开：若上一次关闭的 200ms 退场定时器还挂着，必须先清掉
   *   （否则弹窗刚入场就被退场定时器卸载 → 用户看到「点了没反应」）。
   *   同时把 exchangeIn 先复位成 false，保证「关→开」这一轮入场动画
   *   也能重新播（否则 true→true 无变化，动画不触发）。
   */
  private openExchange(b: LocalBenefit): void {
    this.clearExchangeTimers()
    this.exchangeBenefit = b
    this.exchangeAvailable = this.ov.availablePoints
    this.exchangeIn = false
    this.showExchange = true
    this.exchangeEnterTimer = setTimeout((): void => {
      this.exchangeEnterTimer = -1
      this.exchangeIn = true
    }, 16)
  }

  /**
   * 关闭兑换确认弹窗：先置 false 播 200ms 退场，再卸载。
   * ⚠️ 不清入场定时器之外的东西；退场定时器独立于入场定时器，
   *   避免「关→开」时入场的 16ms 定时器被退场逻辑误清。
   */
  private closeExchange(): void {
    if (this.exchangeEnterTimer >= 0) {
      clearTimeout(this.exchangeEnterTimer)
      this.exchangeEnterTimer = -1
    }
    this.exchangeIn = false
    this.exchangeExitTimer = setTimeout((): void => {
      this.exchangeExitTimer = -1
      this.showExchange = false
    }, 200)
  }

  /**
   * 数字滚动动画：把「可用积分」从旧值滚到新值。
   * ------------------------------------------------------------------
   * 用户反馈「再兑换后这里的数据刷新也没动画」——数字直接跳变。
   * 现在用 24 帧 × 16ms ≈ 380ms 的缓动滚动，视觉上是平滑过渡。
   * 数值本身由 ov.availablePoints 提供，shownPoints 只是显示中间值。
   */
  private animatePoints(target: number): void {
    this.clearPointsTimer()
    const from: number = this.shownPoints
    if (from === target) {
      this.shownPoints = target
      return
    }
    const frames: number = 24
    let i: number = 0
    const step = (): void => {
      i++
      const t: number = i / frames
      // easeOutCubic：起步快、收尾稳
      const eased: number = 1 - Math.pow(1 - t, 3)
      this.shownPoints = Math.round(from + (target - from) * eased)
      if (i < frames) {
        this.pointsTimer = setTimeout(step, 16)
      } else {
        this.pointsTimer = -1
        this.shownPoints = target
      }
    }
    this.pointsTimer = setTimeout(step, 16)
  }

  /** 清数字滚动定时器 */
  private clearPointsTimer(): void {
    if (this.pointsTimer >= 0) {
      clearTimeout(this.pointsTimer)
      this.pointsTimer = -1
    }
  }

  private async load(): Promise<void> {
    try {
      this.benefits = await DataSource.benefits()
      const prev: number = this.ov.availablePoints
      this.ov = await DataSource.overview()
      // 可用积分变了 → 滚数字（首次加载直接置位，不做滚动）
      if (prev !== this.ov.availablePoints) {
        this.animatePoints(this.ov.availablePoints)
      } else if (this.shownPoints === 0) {
        this.shownPoints = this.ov.availablePoints
      }
    } catch (err) {
      this.benefits = []
    }
  }

  /* ---------- 口径 ---------- */

  /** 是否可兑换 */
  private affordable(b: LocalBenefit): boolean {
    return this.ov.availablePoints >= b.points
  }

  /** 还差多少积分 */
  private gapOf(b: LocalBenefit): number {
    return Math.max(0, b.points - this.ov.availablePoints)
  }

  /** 可兑换项数 */
  private affordableCount(): number {
    let n: number = 0
    for (let i = 0; i < this.benefits.length; i++) {
      if (this.affordable(this.benefits[i])) n++
    }
    return n
  }

  /** 最低门槛（用于「最低门槛」统计） */
  private minPoints(): number {
    let m: number = 0
    for (let i = 0; i < this.benefits.length; i++) {
      if (m === 0 || this.benefits[i].points < m) m = this.benefits[i].points
    }
    return m
  }

  /* ---------- 交互 ---------- */

  private tapBenefit(b: LocalBenefit): void {
    if (!this.affordable(b)) {
      toast('积分不足，还差 ' + this.gapOf(b) + ' 分，继续低碳记录吧')
      return
    }
    // 可兑换：弹液态玻璃确认窗（覆盖层弹窗，替代旧演示态 toast ——
    // 确认类交互必须可撤销、可看清后果，系统 toast 既不可撤销也没有按钮位）
    this.openExchange(b)
  }

  /**
   * 确认兑换（弹窗「确定兑换」的落地点）。
   * ------------------------------------------------------------------
   * 事务口径：LocalStore.exchange 内部已做余额校验 + 发券 + best-effort 落盘，
   * 返回 null 只可能是「弹窗停留期间积分被其他入口用掉」—— toast 兜底并重拉。
   * 成功后两个广播都要发：
   *   · bumpCouponTick —— 券包页列表、「我的」页入口角标据此刷新；
   *   · broadcastDataChange —— 可用积分余额是跨页共享状态，常驻 Tab 页
   *     （我的/首页）经 ecoTick 重拉，否则回来看到旧余额。
   *
   * ⚠️ 整体 try/catch：弹窗 onConfirm 是火忘调用（无 await），本方法一旦
   * throw 就是未捕获 rejection —— 预览器直接判预览错误弹红条、真机
   * 也可能静默失败。任何异常统一降级为「兑换未完成」toast。
   */
  private async doExchange(b: LocalBenefit): Promise<void> {
    try {
      const cp: LocalCoupon | null = await LocalStore.exchange(b)
      if (cp === null) {
        toast('积分不足，兑换未完成')
        this.load()
        return
      }
      LocalStore.bumpCouponTick()
      EcoMoodState.broadcastDataChange()
      toast('兑换成功！已存入『碳惠券包』，7 天内有效')
      this.load()
    } catch (err) {
      toast('兑换未完成，请重试')
    }
  }

  private openBadge(): void {
    AppRouter.pathStack.pushPathByName(RouteName.BADGE_WALL, null)
  }

  private openRecord(): void {
    AppRouter.pathStack.pushPathByName(RouteName.FACTOR_LIB, null)
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
   * 记录变更信号（响应式）。
   * LocalStore 每次写入/删除记录都会 bump 该序号，页面据此即时重算档位，
   * 保证「记完行为切回来背景立刻变色」。
   */
  @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0

  /** 记录信号变化 → 重算全局碳档位 */
  /**
   * ecoTick 变化的**真正**回调入口（@Watch 驱动）。
   * ------------------------------------------------------------------
   * ⚠️ 这里必须走 @Watch：ArkUI **没有** `onStorageChange` 这个生命周期
   *    （SDK d.ts 里不存在），框架永远不会调用它。只订阅 @StorageLink
   *    的结果是「组件重建了、但没有重新拉数据」——
   *    这正是「记完一笔还要手动刷新」的根因：全库 30+ 个页面都写了
   *    一个没人调用的方法。
   *
   * `@Watch` 才是官方支持的「响应式变量变化回调」：
   *   记录写入 → DataSource.addRecord → EcoMoodState.broadcastDataChange()
   *   → AppStorage('ecoTick') +1 → 本方法 → onStorageChange('ecoTick')
   *   → 重算碳档位 + load() 重拉数据。
   */
  onEcoTick(): void {
    this.onStorageChange('ecoTick')
  }

  onStorageChange(key: string): void {
    if (key === 'ecoTick') {
      EcoMoodState.refresh()
      this.load()
    }
  }

  /**
   * 页面入场动画状态（苹果口径，见下方最外层容器的 onAppear）。
   * 每次 push 进入本页都会重放到 0→1，观感是「内容错峰上浮」。
   */
  @State private pageIn: boolean = false
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisappear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Stack() {
        Column() {
          Column() {
            CfTopBar({
              title: '积分商城',
              onBack: (): void => {
                AppRouter.pathStack.pop()
              }
            })
            Scroll(this.scroller) {
              Column({ space: Space.LG }) {
                this.HeaderCard()
                if (this.benefits.length === 0) {
                  CfCard({}) {
                    CfEmpty({ icon: 'mall', text: '暂无兑换权益', sub: '权益上架后即可在这里兑换' })
                  }
                } else {
                  this.StatRow()
                  this.MallGrid()
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
          }
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
        // 兑换确认弹窗：覆盖层（全屏遮罩 + 居中玻璃面板），挂在页面最上层，
        // 盖住顶栏与列表（等价原 CustomDialog 的全窗口覆盖）
        if (this.showExchange) {
          ExchangeConfirmDialog({
            benefit: this.exchangeBenefit,
            available: this.exchangeAvailable,
            visible: this.exchangeIn,
            onCancel: (): void => {
              this.closeExchange()
            },
            onConfirm: (): void => {
              this.closeExchange()
              this.doExchange(this.exchangeBenefit)
            }
          })
        }
      }
      // 页面入场动画（苹果口径：整页淡入 + 下方 12vp 浮起，见 AppleMotion）
      // ⚠️ 必须延一帧再置 true：同帧内 false→true 会被 ArkUI 合并，
      //    opacity/translate 补间不播（同 Index slotDeleteIn / DashboardPage entered 手法）。
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
      .opacity(this.pageIn ? this.themeTick >= 0 ? 1 : 0 : 0)
      .translate({ y: this.pageIn ? 0 : 12 })

    }
    .hideTitleBar(true)
  }

  /* ---------- 顶部余额卡 ---------- */
  @Builder
  HeaderCard() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text('可用积分')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 4 }) {
            Text('' + this.shownPoints)
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('分')
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          Text('当前可兑换 ' + this.affordableCount() + ' 项权益')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        CfIcon({ kind: 'ui', code: 'mall', iconSize: 34 })
      }
      .width('100%')

      // 兑换进度：可用积分 / 最高门槛
      Column({ space: 6 }) {
        CfProgress({
          percent: (this.ov.availablePoints / this.maxPoints()) * 100,
          color: '#FFFFFF',
          barHeight: 7,
          track: 'rgba(255,255,255,0.28)'
        })
        .width('100%')
        Row() {
          Text('积分进度')
            .fontSize(FontSize.CAPTION)
            .fontColor('rgba(255,255,255,0.9)')
          Blank()
          Text('最高门槛 ' + this.maxPoints() + ' 分')
            .fontSize(FontSize.CAPTION)
            .fontColor('rgba(255,255,255,0.9)')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: Space.MD })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.22)' })
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

  /** 全部权益中的最高门槛（避免除零） */
  private maxPoints(): number {
    let m: number = 1
    for (let i = 0; i < this.benefits.length; i++) {
      if (this.benefits[i].points > m) m = this.benefits[i].points
    }
    return m
  }

  /* ---------- 统计三宫格 ---------- */
  @Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '可兑换',
          value: this.affordableCount() + ' 项',
          icon: 'check',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '最低门槛',
          value: this.minPoints() + ' 分',
          icon: 'unlock',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '权益总数',
          value: '' + this.benefits.length,
          icon: 'gift',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  /* ---------- 权益网格 ---------- */
  @Builder
  MallGrid() {
    Column({ space: Space.MD }) {
      CfSection({ title: '碳普惠权益', more: '看徽章 ›', onMoreTap: (): void => this.openBadge() })
      // 与徽章墙同理：不用 Grid——columnsTemplate 的列宽约束传不到子 Text，
      // 卡片会被压成极窄竖条、文字逐字竖排。改用 Row + layoutWeight 显式分列。
      Column({ space: Space.MD }) {
        ForEach(this.rowIndexes(), (r: number) => {
          Row({ space: Space.MD }) {
            ForEach(this.cellsOfRow(r), (b: LocalBenefit) => {
              Column() {
                this.BenefitCell(b)
              }
              .layoutWeight(1)
            }, (b: LocalBenefit): string => b.benefitCode)
            if (this.cellsOfRow(r).length < PointsMallPage.COLS) {
              ForEach(this.fillerIndexes(r), (f: number) => {
                Column().layoutWeight(1)
              }, (f: number): string => 'fill_' + r.toString() + '_' + f.toString())
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (r: number): string => 'row_' + r.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  /** 行号数组 */
  private rowIndexes(): number[] {
    const rows: number = Math.ceil(this.benefits.length / PointsMallPage.COLS);
    const out: number[] = [];
    for (let i: number = 0; i < rows; i++) out.push(i);
    return out;
  }

  /** 第 r 行的权益（最多 COLS 个） */
  private cellsOfRow(r: number): LocalBenefit[] {
    const out: LocalBenefit[] = [];
    const start: number = r * PointsMallPage.COLS;
    for (let i: number = 0; i < PointsMallPage.COLS; i++) {
      const idx: number = start + i;
      if (idx < this.benefits.length) out.push(this.benefits[idx]);
    }
    return out;
  }

  /** 末行补齐占位下标 */
  private fillerIndexes(r: number): number[] {
    const used: number = this.cellsOfRow(r).length;
    const out: number[] = [];
    for (let i: number = used; i < PointsMallPage.COLS; i++) out.push(i);
    return out;
  }

  /* ---------- 单项权益卡 ---------- */
  @Builder
  BenefitCell(b: LocalBenefit) {
    Column({ space: 7 }) {
      Row() {
        Stack() {
          CfIcon({ kind: 'benefit', code: b.benefitCode, iconSize: 26 })
        }
        .width(46)
        .height(46)
        .backgroundColor(this.affordable(b) ? this.tc(EcoTheme.primaryPale(this.ecoLevel)) : this.tc(Neutral.SURFACE))
        .borderRadius(Radius.MD)
        Blank()
        if (this.affordable(b)) {
          CfPill({ text: '可兑', tone: 'success' })
        } else {
          CfPill({ text: '未解锁', tone: 'muted' })
        }
      }
      .width('100%')

      Text(b.benefitName)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.affordable(b) ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(b.description)
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .lineHeight(15)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(b.points + ' 分')
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.affordable(b) ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
        Blank()
        Text(this.affordable(b) ? '去兑换' : ('差 ' + this.gapOf(b)))
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.affordable(b) ? this.tc(Accent.SUCCESS) : this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .width('100%')
      .padding({ top: Space.XS })
      .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height(PointsMallPage.CARD_H)
    .padding(Space.MD)
    .backgroundColor(this.affordable(b) ? this.tc(Glass.CARD_BG) : this.tc(Neutral.SURFACE))
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .opacity(this.affordable(b) ? 1 : 0.72)
    .shadow(this.affordable(b) ? this.tw(Shadow.card()) : Shadow.none())
    // 兜底：任何文字放大都被裁在卡片内部
    .clip(true)
    .onClick((): void => this.tapBenefit(b))
  }

  /* ---------- 兑换说明 ---------- */
  @Builder
  TipCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '兑换说明' })
      Row({ space: Space.MD }) {
        CfIcon({ kind: 'ui', code: 'tree', iconSize: 20 })
        Column({ space: 3 }) {
          Text(Biz.POINTS_PER_TREE + ' 积分可兑换 1 棵植树证书')
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Neutral.TEXT))
          Text('兑换成功后积分实时扣减，可在积分明细中查看流水')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .lineHeight(18)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(Space.LG)
      .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
      .borderRadius(Radius.MD)
      .onClick((): void => this.openRecord())
    }
    .width('100%')
  }
}
