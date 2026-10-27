import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalBadge, LocalOverview, LocalSmartTip, LocalTask, LocalFocusTask, TrendPoint } from '../../data/MockStore';
import { EcoMoodState } from '../../data/EcoMoodState'
import { Accent, Biz, CategoryMeta, EcoTheme, FontSize, Glass, IconTone, Neutral, Radius, Shadow, Space, ThemePalette, isDarkMode } from '../../ui/Theme';
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection } from '../../ui/Components';
import { GlassLight, GlassTier } from '../../ui/GlassLight';
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * P03 首页看板（Tab1）
 * 真实实现：减排总览 + 等级进度 + 今日重点 + 任务进度 + 趋势 + 快捷入口
 * 数据来源 DataSource（服务端优先，本地兜底）
 */
@Component
export struct DashboardPage {
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
  private td(): boolean {
    return this.themeTick >= 0 ? isDarkMode() : isDarkMode()
  }

  @StorageProp('themeTick') themeTick: number = 0
  @State private ov: LocalOverview = {
    totalKg: 0, todayKg: 0, monthKg: 0, totalPoints: 0, availablePoints: 0, exchangedPoints: 0,
    recordCount: 0, continuousDays: 0, treeCount: 0, badgeCount: 0, level: 1
  }
  @State private tasks: LocalTask[] = []
  @State private focus: LocalFocusTask | null = null
  @State private tips: LocalSmartTip[] = []
  @State private trend: TrendPoint[] = []
  @State private badges: LocalBadge[] = []
  @State private loading: boolean = true
  @State private online: boolean = true

  /**

   * 全局碳情绪档位（响应式）。
   * 订阅 AppStorage：任意页面写入新档位时本页自动重渲染，
   * 全应用背景色保持同步，不会出现「上一页绿、下一页黄」的跳变。
   */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /**

   * 记录变更信号（响应式）。
   * LocalStore 每次写入/删除记录都会 bump 这个自增序号，
   * 页面订阅它即可在「记录 → 切回看板」时立刻重算档位，
   * 无需依赖 onPageShow 的时序（Tab 切换不保证触发）。
   */
  @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0

  private scroller: Scroller = new Scroller()

  /**

   * 刷新中的并发锁 + 节流。
 */
  private inFlight: boolean = false;
  /** 飞行期间到达的刷新请求（数据真的变了才有），本次 load 结束后补拉一次 */
  private loadPending: boolean = false;
  /** 最近一次 load 完成时刻（Date.now 毫秒） */
  private lastLoadAt: number = 0;
  /** 节流窗口：太短挡不住连续记录，太长会让手动刷新「没反应」 */
  private static readonly THROTTLE_MS: number = 600;
/** 入场信号：首帧渲染后置 true，各分区按 delay 依次浮入（STEP_IN 同观感） */
  @State private entered: boolean = false
  /** 入场定时器 id，-1 表示未运行 */
  private entranceTimer: number = -1
  /** 数字滚动当前展示值：Hero 大数字 + 四项小数据（与 ov 指标一一对应） */
  @State private shownKg: number = 0
  @State private shownToday: number = 0
  @State private shownPoints: number = 0
  @State private shownDays: number = 0
  @State private shownRecords: number = 0
  /** 数字滚动定时器 id，-1 表示未运行 */
  private numTimer: number = -1
  /** 滚动起始时刻（ms）与起止值快照（easeOutCubic 补间） */
  private numStartAt: number = 0
  private numFrom: number[] = [0, 0, 0, 0, 0]
  private numTo: number[] = [0, 0, 0, 0, 0]
  /** 快捷格子按压态（按 route 记键，区分八个格子） */
  @State private pressedCell: string = ''

  aboutToAppear(): void {
    this.load()
    // 步进入场：先让首帧以「下移 + 透明」渲染，下一拍再整体浮入，
    // 各分区靠 .animation 的 delay 依次错峰（苹果式入场节奏）
    this.entranceTimer = setTimeout((): void => {
      this.entered = true
    }, 80)
  }

  /** 记录信号变化 → 重算档位（背景随即过渡到新颜色） */
  /**
   * ecoTick 变化的**真正**回调入口（@Watch 驱动）。
 */
  onEcoTick(): void {
    this.onStorageChange('ecoTick')
  }

  onStorageChange(key: string): void {
    if (key === 'ecoTick') {
      EcoMoodState.refresh()
      // ⚠️ 自动刷新必须绕过节流：这是「数据真的变了」，
      // 与用户主动点刷新不同节流窗口，否则连续记两笔会丢一次。
      this.load(true)
    }
  }

  /**

   * 页面重新可见时刷新。
   * 关键场景：用户在「记录」Tab 记完一笔低碳行为再切回看板，
   * 当日碳排放会变化 → 情绪档位必须跟着重算，
   * 否则「记录了新行为但界面还是旧颜色」，动态反馈就断链了。
   */
  onPageShow(): void {
    this.load(true)
  }

  /** 数字滚动时长（ms）：easeOutCubic 先快后慢，苹果式计数节奏 */
  private static readonly NUM_ROLL_MS: number = 720;

  /**

   * 苹果式数字滚动：Hero 大数字 + 四项小数据从当前展示值续滚到新值。
   * 从**展示值**（而非上一帧目标值）起步：滚动中途刷新数据不跳变；
   * 整数位用 Math.round 抖动最小化，kg 保留两位小数由 toFixed 处理。
   */
  private startCountUp(target: LocalOverview): void {
    if (this.numTimer >= 0) {
      clearInterval(this.numTimer)
      this.numTimer = -1
    }
    this.numFrom = [this.shownKg, this.shownToday, this.shownPoints, this.shownDays, this.shownRecords]
    this.numTo = [target.totalKg, target.todayKg, target.availablePoints, target.continuousDays, target.recordCount]
    this.numStartAt = Date.now()
    this.numTimer = setInterval((): void => {
      const t: number = Math.min(1, (Date.now() - this.numStartAt) / DashboardPage.NUM_ROLL_MS)
      const e: number = 1 - Math.pow(1 - t, 3)
      this.shownKg = this.numFrom[0] + (this.numTo[0] - this.numFrom[0]) * e
      this.shownToday = this.numFrom[1] + (this.numTo[1] - this.numFrom[1]) * e
      const pts: number = Math.round(this.numFrom[2] + (this.numTo[2] - this.numFrom[2]) * e)
      const days: number = Math.round(this.numFrom[3] + (this.numTo[3] - this.numFrom[3]) * e)
      const recs: number = Math.round(this.numFrom[4] + (this.numTo[4] - this.numFrom[4]) * e)
      // 整数位未变不写 @State：滚动 720ms 里三个整数位大半时间不动，
      // 每帧白写会触发无效 diff，挤占列表/玻璃的渲染预算
      if (pts !== this.shownPoints) {
        this.shownPoints = pts
      }
      if (days !== this.shownDays) {
        this.shownDays = days
      }
      if (recs !== this.shownRecords) {
        this.shownRecords = recs
      }
      if (t >= 1) {
        clearInterval(this.numTimer)
        this.numTimer = -1
      }
    }, 16)
  }

  /**

   * 拉取首页全部数据。
   * @param force true = 数据源已变化（ecoTick / 页面回前台），跳过节流；
   *              false = 用户手动点击，遵守节流窗口。
   */
  private async load(force: boolean = false): Promise<void> {
    // 并发保护：同一时刻只允许一次 load 在飞。
    // ⚠️ 但**不能直接丢弃**在飞行期间到达的「数据已变」触发：
    // 连续记两笔 / 记完又 AI 录入时，第二次 tick 若被丢掉，
    // 首页会停在上一笔的口径（表现为「记了但数字没变，再刷一下才对」）。
    // 现改为打一个 pending 标记，本次 load 结束后补拉一次。
    if (this.inFlight) {
      this.loadPending = true
      return
    }
    if (!force) {
      const now: number = Date.now();
      if (now - this.lastLoadAt < DashboardPage.THROTTLE_MS) {
        return
      }
    }
    this.inFlight = true;
    this.loading = true;
    try {
      this.ov = await DataSource.overview()
      // 数字滚动：新总览到位即从当前展示值续滚（不阻塞后续数据拉取）
      this.startCountUp(this.ov)
      this.tasks = await DataSource.tasks()
      this.focus = await DataSource.focusTask()
      this.tips = await DataSource.smartTips()
      this.trend = await DataSource.trend('day')
      this.badges = await DataSource.badges()
      this.online = DataSource.online
      // 数据到位后重算全局档位：本地存储是唯一数据源
      EcoMoodState.refresh()
      this.lastLoadAt = Date.now();
    } catch (err) {
      // DataSource 内部已兜底，此处仅兜底极端异常
    } finally {
      // ⚠️ 锁必须在 finally 释放：否则一次异常会让本页再也刷不动。
      this.inFlight = false;
      this.loading = false;
      // 飞行期间被折叠掉的刷新请求，在这里补一次（force：确实是数据变了）
      if (this.loadPending) {
        this.loadPending = false;
        this.load(true);
      }
    }
  }

  aboutToDisappear(): void {
    // ⚠️ 定时器必须清理：Tab 切走时若不清理，定时器会一直跑到
    // 页面销毁，持有已销毁的 @State 引用 → 内存泄漏 + 无意义重绘。
    if (this.entranceTimer >= 0) {
      clearTimeout(this.entranceTimer)
      this.entranceTimer = -1
    }
    if (this.numTimer >= 0) {
      clearInterval(this.numTimer)
      this.numTimer = -1
    }
  }
/** 主视觉渐变起色 */
  /**
   * 主视觉渐变起始色。
   * 深色模式切到 heroFrom（深绿玻璃调）：EcoMood.*_FROM/TO 是浅色套值、
   * 深色下不换血，直接用会让整张主视觉卡在深炭页面上亮成一块「贴纸」
   * （用户截图反馈「刷新颜色和主页面不一致」）。浅色模式原样返回。
   */
  private moodFrom(): string {
    return this.td() ? this.tc(EcoTheme.heroFrom(this.ecoLevel)) : this.tc(EcoTheme.from(this.ecoLevel))
  }

  /** 主视觉渐变尾色（同上，深色切 heroTo） */
  private moodTo(): string {
    return this.td() ? this.tc(EcoTheme.heroTo(this.ecoLevel)) : this.tc(EcoTheme.to(this.ecoLevel))
  }

  /** 页面底色 */
  private moodBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
  }

  /** 当前档位强调色 */
  private moodAccent(): string {
    return this.tc(EcoTheme.accent(this.ecoLevel))
  }

  /** 今日减排达成率（0~100，达成日目标时封顶，用于环形进度） */
  private quotaPct(): number {
    return Math.min(100, Math.round((this.ov.todayKg / EcoMoodState.QUOTA) * 100))
  }

  /** 是否有需要展示的行动建议 */
  private hasAdvice(): boolean {
    return EcoTheme.advice(this.ecoLevel).length > 0
  }

  /** 等级进度百分比 */
  private levelPct(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    const span: number = r[1] - r[0];
    if (span <= 0) return 100
    return Math.max(2, Math.min(100, ((this.ov.totalKg - r[0]) / span) * 100))
  }

  private nextLevelKg(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    return Math.max(0, Math.round((r[1] - this.ov.totalKg) * 100) / 100)
  }

  /** 任务完成度 */
  private taskPct(t: LocalTask): number {
    if (t.targetValue <= 0) return 0
    return Math.min(100, Math.round((t.progress / t.targetValue) * 100))
  }

  private taskTone(t: LocalTask): string {
    if (t.status === 'claimed') return 'success'
    if (t.status === 'done') return 'warning'
    return 'info'
  }

  private taskStatusText(t: LocalTask): string {
    if (t.status === 'claimed') return '已领取'
    if (t.status === 'done') return '待领取'
    return t.progress + '/' + t.targetValue
  }

  /** 趋势折线高度归一化 */
  private trendMax(): number {
    let m: number = 0
    for (let i = 0; i < this.trend.length; i++) {
      if (this.trend[i].kg > m) m = this.trend[i].kg
    }
    return m <= 0 ? 1 : m
  }

  /**

   * 近 7 天迷你柱高度：按最大值归一化，最高 78vp、最矮 6vp（始终可见）。
 */
  private miniBarH(kg: number): number {
    const h: number = (kg / this.trendMax()) * 78
    return Math.max(6, Math.min(78, h))
  }

  /** 九宫格入口 */
  private go(route: string): void {
    AppRouter.pathStack.pushPathByName(route, null)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Space.LG }) {
        this.Header()
        this.EcoMoodCard()
        /*
         * 苹果式步进入场：各分区包一层全宽 Column，挂 opacity + translateY，
         * entered 置 true 后按 delay 依次浮入（30ms 步进错峰）。
         * ⚠️ 内层各 Builder 自身的 .animation（620ms 主题过渡）在更内层节点上，
         * 与外层入场动画互不覆盖 —— 两个属性链在不同节点，不会相互顶掉。
         */
        Column() {
          this.HeroCard()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(0) })
        Column() {
          this.QuickGrid()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(2) })
        Column() {
          this.FocusCard()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(3) })
        Column() {
          this.WeekTrend()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(4) })
        Column() {
          this.TaskSection()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(5) })
        Column() {
          this.TipSection()
        }
        .width('100%')
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 18 })
        .animation({ duration: AppleMotion.BASE_MS, curve: AppleMotion.IN, delay: AppleMotion.stagger(6) })
      }
      .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
      .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 96 })
    }
    .scrollBar(BarState.Off)
    // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
    // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    /*
     * ⚠️ themeTick 恒读钩子必须挂在**本 Scroll 根容器**上（不能只在内部 Column）。
     * 与 MinePage 同一个根因：`backgroundColor(EcoTheme.bgSolid(...))` 挂在
     * Scroll 上，而 themeTick 只在 Scroll 内部的 Column（第 291 行）被读取。
     * 换血推 themeTick 时 Scroll 自身不重建 → 背景色停留在建页时的浅色值，
     * 于是「看板」在深色模式下仍是浅色，而记录/科普是深色。
     * 记录/科普正常是因为它们的条目额外订阅了 themeTick，条目重建
     * 把父级一起带上；本页条目没有这层订阅。值恒为 1，无视觉影响。
     */
    .opacity(this.themeTick >= 0 ? 1 : 0)
    // 页面底色跟随碳档位：优秀时是清透薄荷，越接近/超过阈值越暖。
    // 这是「环境关联感」的第一层：用户进页面抬眼就知道今天状态。
    // animation 让换色有 620ms 过渡，不是硬切。
    //
    // ⚠️ 本轮改回**半透明 bg()（62%）**：根层实色锚已由 Index 根 Stack 的
    // bgSolid 提供（Navigation/Tabs 已显式透明），半透明底落上去不会再遇白；
    // 同时根层的径向环境光晕（EcoTheme.glow）才能透过这 38% 透上来 ——
    // 玻璃条与卡片的模糊才有「环境纵深」可采样（此前不透明实色把根层全盖死）。
    .backgroundColor(this.tc(EcoTheme.bg(this.ecoLevel)))
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }
@Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Row({ space: 4 }) {
          CfIcon({
            kind: 'ui',
            code: EcoTheme.icon(this.ecoLevel),
            iconSize: 12,
            color: this.tc(Neutral.TEXT_MUTED)
          })
          Text('一触青绿')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        // 问候语跟着碳状态走：达标说「今天也很低碳」，
        // 超阈值则转为提醒语气 —— 文案与背景色传达同一个信号
        Text(this.greeting())
          .fontSize(FontSize.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })

      if (!this.online) {
        CfPill({ text: '演示模式', tone: 'warning' })
      }
    }
    .width('100%')
  }

  /** 情绪化问候语 */
  private greeting(): string {
    if (this.ecoLevel === 'eco') return '今天状态很棒，继续保持'
    if (this.ecoLevel === 'good') return '今天也很低碳'
    if (this.ecoLevel === 'warn') return '今天排碳有点多了'
    if (this.ecoLevel === 'alert') return '已超出今日目标'
    return '今天也要低碳一点'
  }

  /**

   * 生态状态卡 —— 情绪化反馈的核心载体
 */
  @Builder
  EcoMoodCard() {
    Row({ space: Space.LG }) {
      Column({ space: 5 }) {
        Row({ space: 6 }) {
          CfIcon({
            kind: 'ui',
            code: EcoTheme.icon(this.ecoLevel),
            iconSize: 18,
            color: this.tc(EcoTheme.moodAccent(this.ecoLevel))
          })
          Text(EcoTheme.title(this.ecoLevel))
            .fontSize(FontSize.TITLE)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Text(EcoTheme.desc(this.ecoLevel, this.ov.todayKg, EcoMoodState.QUOTA))
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // 升温/渐入佳境时给正向引导，达成目标后不占空间
        if (this.hasAdvice()) {
          Row({ space: 5 }) {
            CfIcon({ kind: 'ui', code: 'bulb', iconSize: 11 })
            Text(EcoTheme.advice(this.ecoLevel))
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.moodAccent())
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .constraintSize({ minWidth: 0 })
          }
          .width('100%')
          .padding({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })

      // 右侧：今日减排目标环
      this.QuotaRing()
    }
    .width('100%')
    .padding(Space.LG)
    .linearGradient({
      angle: 135,
      colors: [[this.moodFrom(), 0.30], [this.moodTo(), 0.14]]
    })
    .borderRadius(Radius.XL)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, this.moodBg(), 1)) })
    .shadow(this.tw(Shadow.card()))
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }

  /** 今日减排目标环：Progress(type=Ring) 环形进度 + 中心数值 */
  @Builder
  QuotaRing() {
    Stack() {
      // Ring 进度：原生支持百分比，颜色取当前情绪强调色
      Progress({
        value: this.quotaPct(),
        total: 100,
        type: ProgressType.Ring
      })
        .width(72)
        .height(72)
        .color(this.moodAccent())
        .style({ strokeWidth: 7 })
        // 达成日目标时环变满格，档位色随减排量从灰一路升到荧光绿
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
      Column({ space: 0 }) {
        Text('' + Math.round(this.ov.todayKg * 10) / 10)
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.moodAccent())
          // 数字光晕已移除：预览器把 Text 阴影渲染成文字包围盒矩形，
          .maxLines(1)
        Text('kg')
          .fontSize(9)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(72)
    .height(72)
    .flexShrink(0)
  }
@Builder
  HeroCard() {
    Column({ space: Space.MD }) {
      Row() {
        Column({ space: 2 }) {
          Text('累计减排')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 3 }) {
            // 数字滚动展示值：数据到位后从旧值 easeOutCubic 续滚到新值
            Text(this.shownKg.toFixed(2))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              // 数字光晕已移除：预览器把 Text 阴影渲染成文字包围盒矩形，
            Text('kg')
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          // 等价折算（≠ 已认种）：减排量按每 3000 分 ≈ 1 棵树换算，仅作展示
          Text('减排量 ≈ 种下 ' + Biz.treesOf(this.ov.totalPoints) + ' 棵树')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()

        // 等级徽章
        Column({ space: 2 }) {
          // 植物等级是「情绪位」：用卡通原画表达成长，不跟主题染色
          Text(Biz.levelArt(this.ov.level))
            .fontSize(28)
            .maxFontScale(FontSize.SCALE_NUM)
          Text('Lv.' + this.ov.level)
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .padding({ top: 10, bottom: 10, left: 14, right: 14 })
        .backgroundColor('rgba(255,255,255,0.18)')
        .borderRadius(Radius.LG)
      }
      .width('100%')

      // 等级进度
      Column({ space: 5 }) {
        CfProgress({
          percent: this.levelPct(),
          color: '#FFFFFF',
          barHeight: 6,
          track: 'rgba(255,255,255,0.28)'
        })
        Row() {
          Text(Biz.levelName(this.ov.level))
            .fontSize(FontSize.CAPTION)
            .fontColor('#FFFFFF')
          Blank()
          Text(this.ov.level >= 5 ? '已达最高等级' : ('再减 ' + this.nextLevelKg() + ' kg 升级'))
            .fontSize(FontSize.CAPTION)
            .fontColor('rgba(255,255,255,0.9)')
        }
        .width('100%')
      }
      .width('100%')

      // 四项数据（同样走数字滚动展示值）
      Row() {
        Column({ space: 2 }) {
          Text(this.shownToday.toFixed(2))
            .fontSize(FontSize.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('今日 kg').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text('' + this.shownPoints)
            .fontSize(FontSize.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('可用积分').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text('' + this.shownDays)
            .fontSize(FontSize.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('连续天数').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text('' + this.shownRecords)
            .fontSize(FontSize.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('记录条数').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: Space.MD })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.22)' })
    }
    .width('100%')
    .padding(Space.XL)
    // 主视觉渐变跟随碳档位：整张卡是当天的「环境底色」。
    // 底部卡片的绿色只是点缀，页面级的配色变化才让用户感到关联。
    .linearGradient({
      angle: 135,
      colors: [[this.moodFrom(), 0], [this.moodTo(), 1]]
    })
    .borderRadius(Radius.XL)
    .shadow(this.tw(Shadow.brand()))
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }
@Builder
  QuickGrid() {
    // 用 Row + layoutWeight 显式分列替代 Grid：columnsTemplate 的列宽约束
    // 传不到子 Text，格子会被压成内容宽度，文字被系统字体放大后逐字竖排。
    //
    // 液态玻璃面板：8 个入口合并为**一块**磨砂玻璃（苹果分组列表观感）。
    // 旧版每格一张独立白卡，视觉碎、且 8 层背景叠在滚动内容上发糊；
    // 现在面板挂一层实时模糊，格子透明化只保留点击热区与间距。
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        this.QuickSlot('trend', '趋势', RouteName.TREND_CHART, IconTone.DATA)
        this.QuickSlot('pie', '占比', RouteName.CATEGORY_ANALYSIS, IconTone.ENERGY)
        this.QuickSlot('tree', '成长树', RouteName.LEVEL_TREE, IconTone.RECYCLE)
        this.QuickSlot('target', '任务', RouteName.TASK_CENTER, IconTone.FOOD)
      }
      .width('100%')

      Row({ space: Space.MD }) {
        this.QuickSlot('badge', '徽章', RouteName.BADGE_WALL, IconTone.GOLD)
        this.QuickSlot('mall', '商城', RouteName.POINTS_MALL, IconTone.VIOLET)
        this.QuickSlot('factor', '因子库', RouteName.FACTOR_LIB, IconTone.TRAVEL)
        this.QuickSlot('certificate', '证书', RouteName.CERTIFICATE_LIST, IconTone.RECYCLE)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.MD)
    .linearGradient(GlassLight.panelSurface(this.moodBg()))
    .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
    .borderRadius(Radius.XL)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, this.moodBg(), 1)) })
    .shadow(this.tw(Shadow.card()))
  }

  /** 快捷入口槽位：定宽由 layoutWeight 均分，格内内容自己撑满 */
  @Builder
  QuickSlot(code: string, label: string, route: string, tone: string) {
    Column() {
      this.QuickCell(code, label, route, tone)
    }
    .layoutWeight(1)
    .height(72)
  }

  @Builder
  QuickCell(code: string, label: string, route: string, tone: string) {
    Column({ space: 5 }) {
      CfIcon({ kind: 'ui', code: code, iconSize: 24, tone: tone })
      Text(label)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    // 格子透明化：玻璃质感由外层 QuickGrid 面板统一提供，
    // 每格再铺底色会把面板的模糊效果割成一格一格
    // 苹果按压手感（AppleMotion 口径）：按下 100ms 即时轻缩 94%（小格子
    // 比卡片缩得更明显），松手瞬时归位（禁长回弹动画，否则 push 转场挂起
    // 回弹 → 格子冻结在中间值；「看板随机变大变小」即此根因）；
    // pressedCell 按 route 记键，八个格子互不串扰
    .scale({
      x: this.pressedCell === route ? 0.94 : 1,
      y: this.pressedCell === route ? 0.94 : 1
    })
    .animation(this.pressedCell === route
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressedCell = route
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedCell = ''
      }
    })
    // 保险丝：看板重新可见时若 pressedCell 因异常未复位，强制归位
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressedCell === route) {
        this.pressedCell = ''
      }
    })
    .onClick((): void => this.go(route))
  }
@Builder
  FocusCard() {
    if (this.focus !== null) {
      Column({ space: Space.MD }) {
        CfSection({ title: '今日重点', more: '全部建议 ›', onMoreTap: (): void => this.go(RouteName.SMART_TIPS) })
        Row({ space: Space.MD }) {
          CfIcon({ kind: 'task', code: this.focus!.taskCode, iconSize: 26 })
          Column({ space: 4 }) {
            Text(this.focus!.title)
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
            Text(this.focus!.desc)
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .lineHeight(18)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(Space.LG)
        .backgroundColor(this.tc(CategoryMeta.bg(this.focus!.category)))
        .borderRadius(Radius.MD)
      }
      .width('100%')
    }
  }
@Builder
  WeekTrend() {
    Column({ space: Space.MD }) {
      CfSection({ title: '近 7 天减排', more: '查看趋势 ›', onMoreTap: (): void => this.go(RouteName.TREND_CHART) })
      if (this.trend.length === 0) {
        CfEmpty({ text: '暂无趋势数据' })
      } else {
        // 柱体基线对齐（修「柱子底部不在同一 X 轴上」）：
        // 旧写法把「数值 + 柱 + 日期标签」都放进 Column，最高柱（84vp）整组约
        // 122vp，超过卡片内容区（130 - 32 padding = 98vp），该槽位的底部对齐
        // 失效、整体向下溢出，柱底脱离 X 轴、「18日」标签被挤出标签行。
        // 现在柱体与数值分层放进固定高度的 Stack：柱体恒贴 Stack 底边（= X 轴），
        // 数值用 offset 浮在柱顶、不占布局高度；日期标签统一在 Stack 下方一行。
        Row() {
          ForEach(this.trend, (p: TrendPoint, i: number) => {
            Column({ space: 4 }) {
              // 柱体区：固定 98vp 高，所有柱体恒贴底边
              Stack({ alignContent: Alignment.Bottom }) {
                Column()
                  .width(16)
                  .height(this.miniBarH(p.kg))
                  .linearGradient({
                    angle: 90,
                    colors: [
                      [this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0],
                      [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]
                    ]
                  })
                  .borderRadius(6)
                // 柱顶数值：offset 上浮一个柱高，纯视觉叠加，不参与布局
                Text(p.kg.toFixed(1))
                  .fontSize(9)
                  .maxFontScale(FontSize.SCALE_NUM)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
                  .textAlign(TextAlign.Center)
                  .width(34)
                  .height(13)
                  .offset({ x: 0, y: -this.miniBarH(p.kg) })
              }
              .width('100%')
              .height(98)

              // X 轴日期标签：柱区高度固定，因此永远在同一水平线上
              Text(p.label)
                .fontSize(10)
                .maxFontScale(FontSize.SCALE_NUM)
                .fontColor(i === this.trend.length - 1
                  ? this.tc(EcoTheme.primaryDeep(this.ecoLevel))
                  : this.tc(Neutral.TEXT_MUTED))
                .fontWeight(i === this.trend.length - 1 ? FontWeight.Bold : FontWeight.Normal)
                .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (p: TrendPoint) => p.label + '-' + p.kg.toFixed(2))
        }
        .width('100%')
        .height(150)
        .alignItems(VerticalAlign.Bottom)
        .padding(Space.LG)
        .backgroundColor(this.tc(Neutral.CARD))
        .borderRadius(Radius.MD)
        .shadow(this.tw(Shadow.card()))
      }
    }
    .width('100%')
  }
@Builder
  TaskSection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '每日任务', more: '任务中心 ›', onMoreTap: (): void => this.go(RouteName.TASK_CENTER) })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          ForEach(this.tasks.slice(0, 3), (t: LocalTask) => {
            Row({ space: Space.MD }) {
              CfIcon({ kind: 'task', code: t.taskCode, iconSize: 20 })
              Column({ space: 5 }) {
                Row() {
                  Text(t.taskName)
                    .fontSize(FontSize.BODY)
                    .fontColor(this.tc(Neutral.TEXT))
                    .fontWeight(FontWeight.Medium)
                  Blank()
                  Text('+' + t.rewardPoints + ' 分')
                    .fontSize(FontSize.CAPTION)
                    .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
                }
                .width('100%')
                CfProgress({
                  percent: this.taskPct(t),
                  color: t.status === 'claimed'
                    ? this.tc(Accent.SUCCESS)
                    : this.tc(EcoTheme.primary(this.ecoLevel)),
barHeight: 6
                })
                .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              CfPill({ text: this.taskStatusText(t), tone: this.taskTone(t) })
            }
            .width('100%')
          }, (t: LocalTask) => t.taskCode)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  TipSection() {
    if (this.tips.length > 0) {
      Column({ space: Space.MD }) {
        CfSection({ title: '给你的建议' })
        // 液态玻璃卡：多条建议合并进一块磨砂玻璃（苹果分组列表观感），
        // 行与行之间用极淡分割线区分，替代旧版的逐条独立白卡
        CfCard({ pad: Space.LG, glass: true }) {
          Column({ space: Space.SM }) {
            ForEach(this.tips, (t: LocalSmartTip, i: number) => {
              Row({ space: Space.MD }) {
                CfIcon({ kind: 'tip', code: t.id, iconSize: 20 })
                Column({ space: 3 }) {
                  Text(t.title)
                    .fontSize(FontSize.BODY)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.tc(Neutral.TEXT))
                  Text(t.content)
                    .fontSize(FontSize.SMALL)
                    .fontColor(this.tc(Neutral.TEXT_SUB))
                    .lineHeight(17)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(Space.MD)
              .border(i < this.tips.length - 1
                ? { width: { bottom: 1 }, color: this.tc(Neutral.BORDER) }
                : { width: { bottom: 0 }, color: 'rgba(0,0,0,0)' })
            }, (t: LocalSmartTip) => t.id)
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }
}