import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { TrendPoint } from '../../data/MockStore'
import { Accent, Biz, Chart, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * 粒度切换项：ArkTS 严格模式下数组字面量需显式声明元素类型
 */
interface GranTab {
  key: string;
  name: string;
  desc: string;
}

/**

 * 图表类型切换项：bar=柱状 / line=折线 / pie=饼图（环形）
 * 与 GranTab 分开定义：这里带 emoji 图标，且没有说明文案
 */
interface ChartTab {
  key: string;
  name: string;
  icon: string;
}

/**

 * P10 减排趋势
 */
@Component
export struct TrendChartPage {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   * ⚠️ @Watch('onThemeTick') 不能省：Canvas 是命令式绘制，
   *    换肤只重渲染组件树、不会重放绘制指令，折线/饼图会停留在
   *    旧主题配色上（与 SettingsPage.ets 同一写法）。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') @Watch('onThemeTick') themeTick: number = 0
  @State private points: TrendPoint[] = []
  @State private gran: string = 'day'
  /**
   * 统计口径快照。
 */
  @State private maxV: number = 1
  @State private avgV: number = 0
  @State private totalV: number = 0
  @State private ptsV: number = 0
  @State private maxLb: string = '-'
  /**
   * 粒度切换锁。
   * 只在「本次加载尚未返回」期间为 true，用于挡掉连点；
   * 每次 load() 结束时必须复位，否则锁会永久卡住，
   * pickTab 里的守卫会让周/月两个粒度完全点不动。
   */
  @State private loading: boolean = true
  /** 柱体生长动画开关：false 时柱子压扁且透明，置 true 后逐根长出 */
  @State private grown: boolean = false
  /**
   * 药丸宽度必须与文字槽位严格同宽，否则滑过去会错位。
   * 这样换机型/换字号都不会错位（与 Index.ets barW 同思路）。
   */
  @State private trackW: number = 0

  /**

   * 当前图表类型：bar=柱状 / line=折线 / pie=饼图（环形）。
   * 三者共用同一份 points 数据，只是渲染方式不同，
   * 因此切换时不需要重新拉数据，只需换渲染分支 + 重绘画布。
   */
  @State private chartType: string = 'bar'

  /**

   * 写死宽度在换机型/换字号时会错位。
   */
  @State private typeTrackW: number = 0

  /*
   * 画布上下文（折线图 / 饼图）。
   *   柱状图是「等高槽位 + 归一化高度」的矩形，Row/Column 就能表达；
   *   折线的斜线与饼图的圆弧没有对应声明式组件（Polyline 只能画stroke、
   *   PathShape 不支持圆弧命令），Canvas 是唯一选择。
   * 坐标系说明：绘制坐标用 ctx.width / ctx.height 的**比例**表示，
   * 不调用 vp2px —— 该项目历史上多次因预览器热更新时 vp2px 返回脏值
   * 出现图层错位/重影（见 Components.ets CloseBtn.Arms 注释）。
   * 比例坐标对「坐标单位是 px 还是 vp」两种解释都成立：
   * 无论 ctx.width 返回的是物理像素还是 vp，分数映射都恰好铺满组件。
   */
  private lineSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private lineCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.lineSettings)
  private pieSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private pieCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.pieSettings)

  /**

   * 画布就绪标记。
   * 三个图表分支同一时刻只有一个挂载（if/else 互斥），
   * 因此两种画布共用一个就绪标记即可；
   * onReady 之前 ctx.width/height 为 0，绘制指令必须被挡下。
   */
  private canvasReady: boolean = false

  private scroller: Scroller = new Scroller()

  /** 柱区高度（不含刻度文字与轴标签） */
  private chartH: number = 176

  /** 环形图直径（vp）：饼图分支的画布与图例行共同占位 */
  private PIE_SIZE: number = 148

  private tabs: GranTab[] = [
    { key: 'day', name: '日', desc: '近 7 天每日减排' },
    { key: 'week', name: '周', desc: '近 8 周每周减排' },
    { key: 'month', name: '月', desc: '近 6 个月减排' },
    { key: 'year', name: '年', desc: '近 6 年每年减排' }
  ]

  /** 图表类型切换项（柱状 / 折线 / 饼图），复用液态玻璃分段控件语言 */
  private chartTypes: ChartTab[] = [
    { key: 'bar', name: '柱状', icon: 'chart' },
    { key: 'line', name: '折线', icon: 'up' },
    { key: 'pie', name: '饼图', icon: 'pie' }
  ]

  aboutToAppear(): void {
    this.load('day')
  }

  /** 记录轨道实测宽度；百分比形式的 Length 直接忽略 */
  private onTrackArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.trackW) > 0.5) {
      this.trackW = w
    }
  }

  private async load(key: string): Promise<void> {
    // gran 的写入放进动画闭包：药丸平移与文字缩放随之过渡，
    // 视觉上是「滑过去」而不是「瞬间切换」
    this.getUIContext().animateTo({ duration: 320, curve: Curve.Friction }, (): void => {
      this.gran = key
    })
    try {
      this.points = await DataSource.trend(key)
    } catch (err) {
      // DataSource 内部已兜底为本地数据，此处仅防极端异常
      this.points = []
    }
    this.syncStats()
    // 折线/饼图是命令式绘制，points 换了必须显式重画
    // （柱状图是声明式 ForEach，改数据即自动重建，无需此步）
    this.redraw()
    // loading 必须在本次加载结束时复位。
    // 它在 aboutToAppear 里被置为 true，若不复位，pickTab 的
    // `if (this.gran === key || this.loading) return` 会永远命中，
    // 导致「周 / 月」两个粒度怎么点都没反应。
    this.loading = false
    // ArkTS 的动画走 UIContext.animateTo（全局 animateTo 自 API 18 起废弃）：
    // 先让柱子复位（高度归零），下一帧再在动画闭包里置 true，柱子从基线长出
    this.grown = false
    setTimeout((): void => {
      this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseOut }, (): void => {
        this.grown = true
      })
    }, 60)
  }
/**
 * 把 points 聚合结果一次性落到 @State 标量。
   * 必须在每次 points 赋值后立即调用，保证图表与统计区读同一份快照。
   */
  private syncStats(): void {
    let mx: number = 0
    let sum: number = 0
    let lp: number = 0
    let lb: string = '-'
    for (let i = 0; i < this.points.length; i++) {
      const kg: number = this.points[i].kg
      if (kg > mx) {
        mx = kg
        lb = this.points[i].label
      }
      sum += kg
      lp += this.points[i].points
    }
    const n: number = this.points.length
    this.maxV = mx <= 0 ? 1 : mx
    this.totalV = Math.round(sum * 100) / 100
    this.avgV = n === 0 ? 0 : Math.round((sum / n) * 100) / 100
    this.ptsV = lp
    this.maxLb = lb
  }

  /** 最大值（用于柱子高度归一化，避免除零） */
  private maxKg(): number {
    return this.maxV
  }

  /** 峰值所在周期文案 */
  private maxLabel(): string {
    return this.maxLb
  }

  /** 区间总计减排 */
  private totalKg(): number {
    return this.totalV
  }

  /** 区间总计积分 */
  private totalPoints(): number {
    return this.ptsV
  }

  /** 平均值 */
  private avgKg(): number {
    return this.avgV
  }

  /** 最新一期与上一期对比文案（含方向） */
  private deltaText(): string {
    const n: number = this.points.length
    if (n < 2) return '数据不足，暂无对比'
    const cur: number = this.points[n - 1].kg
    const pre: number = this.points[n - 2].kg
    if (pre <= 0) return cur > 0 ? '较上一期新增减排' : '与上一期持平'
    const rate: number = Math.round(((cur - pre) / pre) * 1000) / 10
    if (rate >= 0) {
      return '较上一期 +' + rate + '%，继续保持'
    }
    return '较上一期 ' + rate + '%，再接再厉'
  }

  /** 环比方向对应的语义色 */
  private deltaColor(): string {
    const n: number = this.points.length
    if (n < 2) return this.tc(Neutral.TEXT_SUB)
    return this.points[n - 1].kg >= this.points[n - 2].kg ? this.tc(Accent.SUCCESS) : this.tc(Accent.WARNING)
  }

  /** 当前粒度的说明文案 */
  private granDesc(): string {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].key === this.gran) return this.tabs[i].desc
    }
    return ''
  }

  /** 刻度文案：按量级自动选择小数位 */
  private axisKg(v: number): string {
    if (v <= 0) return '0'
    if (v >= 100) return v.toFixed(0)
    if (v >= 10) return v.toFixed(1)
    return v.toFixed(2)
  }

  /** 柱顶数值文案 */
  private barValue(v: number): string {
    if (v >= 100) return v.toFixed(0)
    if (v >= 10) return v.toFixed(1)
    return v.toFixed(2)
  }
/**
 * 粒度切换。
   * gran 的赋值放进 animateTo 闭包，药丸的 translate / 文字的 scale
   * 会在同一帧内做属性动画，读起来是「药丸滑过去 + 文字轻轻放大」，
   * 而非瞬间跳变（与 Index.ets switchTab 同思路）。
   */
  private pickTab(key: string): void {
    if (this.gran === key || this.loading) return
    this.load(key)
  }

  private tapBar(p: TrendPoint): void {
    toast(p.label + ' 减排 ' + Biz.formatKg(p.kg) + '，获得 ' + p.points + ' 积分')
  }

  private openCategory(): void {
    AppRouter.pathStack.pushPathByName(RouteName.CATEGORY_ANALYSIS, null)
  }

  /**

   * 图表类型切换。
   * 与 pickTab 不同：数据不变，只换渲染分支，因此不重拉 DataSource。
   * 切过去后重放入场动画，让折线/饼图也有「长出来」的仪式感。
   */
  private pickType(key: string): void {
    if (this.chartType === key) return
    this.chartType = key
    this.replayGrow()
    // 新分支的 Canvas 是随 chartType 变化**重新挂载**的，
    // onReady 里会补画；这里再延一帧兜底，
    // 防止 onReady 与数据竞态导致首帧空白。
    setTimeout((): void => this.redraw(), 80)
  }

  /**

   * 重放入场动画。
   * 与 load() 里的 grown 节奏保持一致：先归零，下一帧再置 true。
   */
  private replayGrow(): void {
    this.grown = false
    setTimeout((): void => {
      this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseOut }, (): void => {
        this.grown = true
      })
    }, 60)
  }

  /**

   * 按当前图表类型重绘画布。
   * 柱状图是声明式渲染，无需重绘（直接 return）。
   * 所有可能影响画布内容的变化都要调它：数据、主题、尺寸。
   */
  private redraw(): void {
    if (this.chartType === 'line') {
      this.drawLine()
    } else if (this.chartType === 'pie') {
      this.drawPie()
    }
  }

  /** 记录图表类型轨道实测宽度；百分比形式的 Length 直接忽略 */
  private onTypeTrackArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.typeTrackW) > 0.5) {
      this.typeTrackW = w
      // 画布尺寸依赖布局结果，轨道落定后补一次绘制
      this.redraw()
    }
  }

  /** 图表类型单项宽度（与 TabBar.cellW 同口径：扣掉左右各 3vp 内边距） */
  private typeCellW(): number {
    const track: number = this.typeTrackW > 0 ? this.typeTrackW : 300
    return (track - 6) / this.chartTypes.length
  }

  /** 当前图表类型下标；找不到时兜底 0 */
  private typeIndex(): number {
    for (let i = 0; i < this.chartTypes.length; i++) {
      if (this.chartTypes[i].key === this.chartType) return i
    }
    return 0
  }

  /**

   * 饼图色板：按周期序号循环取色。
 */
  private pieColor(i: number): string {
    const palette: string[] = [
      this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
      this.tc(Accent.TRAVEL),
      this.tc(Accent.ENERGY),
      this.tc(Accent.INFO),
      this.tc(Accent.RECYCLE),
      this.tc(Accent.FOOD),
      this.tc(EcoTheme.primary(this.ecoLevel)),
      this.tc(Accent.SUCCESS)
    ]
    return palette[i % palette.length]
  }

  /** 饼图图例占比文案：小于 10% 保留一位小数，避免小块显示成 0% */
  private piePct(kg: number): string {
    const total: number = this.totalV
    if (total <= 0) return '0%'
    const pct: number = kg / total * 100
    if (pct > 0 && pct < 10) return pct.toFixed(1) + '%'
    return Math.round(pct) + '%'
  }

  /** 卡片底部操作提示（随图表类型换文案） */
  private chartHint(): string {
    if (this.chartType === 'pie') return '点击色块可查看该周期的减排明细'
    if (this.chartType === 'line') return '点击数据点可查看该周期的减排明细'
    return '点击柱体可查看该周期的减排明细'
  }
/**
 * 全局碳情绪档位（响应式）。
 */
  @StorageProp('ecoLevel') @Watch('onEcoLevelTick') ecoLevel: string = 'none'

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

  /** 记录信号变化 → 重算全局碳档位 + 按当前粒度重拉数据 */
  /**
   * ecoTick 变化的**真正**回调入口（@Watch 驱动）。
 */
  onEcoTick(): void {
    this.onStorageChange('ecoTick')
  }

  onStorageChange(key: string): void {
    if (key === 'ecoTick') {
      EcoMoodState.refresh()
      this.reload()
    }
  }

  /**

   * 深色模式切换 → 重绘画布。
   * 声明式部分（药丸/文字/图例）靠 themeTick 依赖自动换色，
   * 画布必须在这里显式重绘（颜色在 draw* 内部才求值）。
   */
  onThemeTick(): void {
    this.redraw()
  }

  /**

   * 碳情绪档位切换 → 重绘画布。
   * EcoTheme.*(ecoLevel) 的取值随档位变化，同样需要显式重绘。
   */
  onEcoLevelTick(): void {
    this.redraw()
  }

  /**

   * 按当前粒度重新拉取趋势数据。
   * load() 需要粒度参数，不能直接当无参重载调用，故单独包一层。
   */
  private reload(): void {
    this.load(this.gran)
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
      Column() {
        Column() {
          CfTopBar({
            title: '减排趋势',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.TabBar()
              // 无数据时连图表都没有，类型切换留着只会「可点但无反馈」
              if (this.points.length > 0) {
                this.TypeBar()
              }
              if (this.points.length === 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'up', text: '暂无趋势数据', sub: '记录低碳行为后这里会自动生成趋势' })
                }
              } else {
                this.ChartCard()
                this.StatRow()
                this.SummaryCard()
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
/**
 * 分段切换：滑动药丸 + 液态玻璃
 */
  @Builder
  TabBar() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Start }) {
        // 轨道：极淡玻璃底，只做承载
        Row()
          .width('100%')
          .height(36)
          .borderRadius(Radius.PILL)
          .linearGradient(this.tw(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1)))
          .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

        // 选中药丸：随 gran 平移，玻璃质感参考右下角 OrbButton
        Row()
          .width(this.pillW())
          .height(36)
          .linearGradient({
            angle: 90,
            colors: [[this.tc(EcoTheme.heroMid(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
          })
          .borderRadius(Radius.PILL)
          /*
           * 投影：不能用 Shadow.brand()（0 6px 18px 品牌绿）。
           * 药丸紧贴轨道边缘时，这个带偏移+大半径的投影会溢出轨道，
           * 在页面背景上留下一圈绿白光晕 —— 这就是截图里的瑕疵。
           * 改用无偏移、小半径的紧致投影：只做「浮起一点」的层次，
           * 范围完全落在药丸自身附近，不会溢出。
           * 注意：药丸**不挂 backdropBlur、也不加白色描边**——
           * * 渐变底是不透明实色，blur 会被整个盖住：既白建一层离屏渲染，
           *   边缘还会渗出一圈半透明晕（「边缘不对」的观感来源之一）；
           * * 白色描边是半透明玻璃的语言，压在绿底上只会显脏。
           * 「液态玻璃」的通透感由未选中的半透明轨道（0.42）承担即可，
           * 选中态就该是一块干净的实色。
           */
          .shadow({ radius: 4, color: this.tc(EcoTheme.shadowColor(this.ecoLevel)), offsetX: 0, offsetY: 1 })
          .translate({ x: this.pillX() })
          // 弹簧感曲线：起步快、收尾带轻微回弹，模仿苹果 segmented control
          .animation({ duration: 320, curve: Curve.Friction })
          .hitTestBehavior(HitTestMode.None)

        Row() {
          ForEach(this.tabs, (t: GranTab) => {
            this.GranChip(t.key, t.name)
          }, (t: GranTab): string => t.key)
        }
        .width('100%')
        .height(36)
      }
      .width('100%')
      .onAreaChange((old: Area, area: Area): void => {
        this.onTrackArea(area.width as number | string)
      })
      .padding(3)
      .borderRadius(Radius.PILL)
      // 裁剪加在 Stack（轨道与药丸的共同父级）上。
      // 药丸是轨道的**兄弟节点**，clip 加在轨道自身裁不到它；
      // 药丸投影若不裁，最右一档（选中「月」）会在轨道外缘留下绿白光晕。
      .clip(true)
      .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
      .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
      .shadow(this.tw(Shadow.card()))

      Text(this.granDesc())
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
        .width('100%')
    }
    .width('100%')
  }

  /** 药丸位移 = 选中项序号 × 单项宽度（含 3vp 内边距的补偿） */
  private pillX(): number {
    return this.cellW() * this.granIndex()
  }

  /** 药丸宽度 = 单项宽度，与轨道内边距对齐 */
  private pillW(): number {
    return this.cellW()
  }

  /** 单项宽度：药丸必须与文字槽位严格同宽，否则滑过去会错位。
   *  ⚠️ trackW 是 onAreaChange 测得的 **Stack 总宽**（含左右各 3vp 内边距），
   *  必须扣掉 6vp 才是轨道内可用宽度。早期版本漏扣：药丸每格宽出 2vp，
   *  滑到最右档（选中「月」）时溢出轨道，被外层 clip(true) 裁成**直边**——
   *  表现为最右档圆角消失、边缘错位。 */
  private cellW(): number {
    const track: number = this.trackW > 0 ? this.trackW : 300
    return (track - 6) / this.tabs.length
  }

  /** 当前选中项下标；找不到时兜底 0 */
  private granIndex(): number {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].key === this.gran) return i
    }
    return 0
  }

  @Builder
  GranChip(key: string, name: string) {
    Text(name)
      .fontSize(FontSize.BODY)
      // 药丸高度写死 36，字号被系统放大就会溢出，这里钳住
      .maxFontScale(FontSize.SCALE_NUM)
      .fontWeight(this.gran === key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.gran === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .layoutWeight(1)
      .height(36)
      // 选中项轻微放大：苹果 segmented control 的标志性手感。
      // 药丸是 HitTestMode.None 的独立图层，所以点击必须由文字层承接。
      .scale({ x: this.gran === key ? 1.06 : 1, y: this.gran === key ? 1.06 : 1 })
      .animation({ duration: this.gran === key ? 260 : 200, curve: Curve.EaseOut })
      .onClick((): void => this.pickTab(key))
  }
/**
 * 图表类型分段控件：与 TabBar 同一套液态玻璃语言（滑动药丸 + 玻璃轨道），
 */
  @Builder
  TypeBar() {
    Stack({ alignContent: Alignment.Start }) {
      // 轨道：极淡玻璃底，只做承载
      Row()
        .width('100%')
        .height(32)
        .borderRadius(Radius.PILL)
        .linearGradient(this.tw(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1)))
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

      // 选中药丸：随 chartType 平移（与 TabBar 同款紧致投影，不溢出轨道）
      Row()
        .width(this.typeCellW())
        .height(32)
        .linearGradient({
          angle: 90,
          colors: [[this.tc(EcoTheme.heroMid(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
        })
        .borderRadius(Radius.PILL)
        .shadow({ radius: 4, color: this.tc(EcoTheme.shadowColor(this.ecoLevel)), offsetX: 0, offsetY: 1 })
        .translate({ x: this.typeCellW() * this.typeIndex() })
        .animation({ duration: 320, curve: Curve.Friction })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        ForEach(this.chartTypes, (t: ChartTab) => {
          this.TypeChip(t.key, t.icon, t.name)
        }, (t: ChartTab): string => 'ct_' + t.key)
      }
      .width('100%')
      .height(32)
    }
    .width('100%')
    .onAreaChange((old: Area, area: Area): void => {
      this.onTypeTrackArea(area.width as number | string)
    })
    .padding(3)
    .borderRadius(Radius.PILL)
    .clip(true)
    .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(this.tw(Shadow.card()))
  }

  @Builder
  TypeChip(key: string, icon: string, name: string) {
    Row({ space: 4 }) {
      CfIcon({
        kind: 'ui',
        code: icon,
        iconSize: 12,
        color: this.chartType === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB)
      })
      Text(name)
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(this.chartType === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.chartType === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .onClick((): void => this.pickType(key))
  }
@Builder
  ChartCard() {
    Column({ space: Space.MD }) {
      Row() {
        Text('减排量（kg CO₂e）')
          .fontSize(FontSize.TITLE)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        // 饼图没有纵轴，右上的轴提示换成占比说明
        Text(this.chartType === 'pie' ? '环形占比' : '右轴：积分')
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .width('100%')

      /*
       * 三种图表共用同一份 points，按 chartType 分发渲染分支。
       * 分支互斥（if/else），因此同一时刻只有一个 Canvas 挂载，
       * onReady 时机天然对齐「切到该类型的第一帧」。
       */
      if (this.chartType === 'bar') {
        this.BarBody()
      } else if (this.chartType === 'line') {
        this.LineBody()
      } else {
        this.PieBody()
      }

      Text(this.chartHint())
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(Space.LG)
    .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(this.tw(Shadow.card()))
    .clip(true)
    // 卡片入场：轻微上浮 + 淡入（由 animateTo 驱动）
  }

  /**

   * 柱状图主体（原 ChartCard 内联的坐标轴三件套）。
 */
  @Builder
  BarBody() {
    Column({ space: 0 }) {
      // 绘图区（含左右纵轴刻度列）
      Row({ space: 0 }) {
        this.AxisLabels(true)
        Blank().width(Chart.AXIS_GAP)
        this.PlotArea()
        Blank().width(Chart.AXIS_GAP)
        this.AxisLabels(false)
      }
      .width('100%')

      // 基线：与绘图区同宽，横向 1px 实线，明确「柱子站在这条线上」
      Row({ space: 0 }) {
        Blank().width(Chart.AXIS_W)
        Blank().width(Chart.AXIS_GAP)
        Row()
          .layoutWeight(1)
          .height(1)
          .backgroundColor(this.tc(Neutral.BORDER))
        Blank().width(Chart.AXIS_GAP)
        Blank().width(Chart.AXIS_RIGHT_W)
      }
      .width('100%')

      // X 轴标签行：左右留白与上方轴列严格等宽，保证标签与柱体一一对齐
      Row({ space: 0 }) {
        Blank().width(Chart.AXIS_W)
        Blank().width(Chart.AXIS_GAP)
        this.XLabels()
        Blank().width(Chart.AXIS_GAP)
        Blank().width(Chart.AXIS_RIGHT_W)
      }
      .width('100%')
    }
    .width('100%')
  }

  /**

   * 折线图主体：左右纵轴 + Canvas 折线 + 基线 + X 轴标签。
 */
  @Builder
  LineBody() {
    Column({ space: 0 }) {
      Row({ space: 0 }) {
        this.AxisLabels(true)
        Blank().width(Chart.AXIS_GAP)
        Stack({ alignContent: Alignment.Bottom }) {
          Canvas(this.lineCtx)
            .width('100%')
            .height(this.chartH)
            .onReady((): void => {
              this.canvasReady = true
              this.drawLine()
            })
            // 入场与柱状图同节奏：不透明度和缩放随 grown 过渡
            .opacity(this.grown ? 1 : 0)
            .animation({ duration: 380, curve: Curve.EaseOut })

          // 命中层：每个周期一个透明槽位，点击弹出该周期明细
          Row() {
            ForEach(this.points, (p: TrendPoint, i: number) => {
              Column()
                .layoutWeight(1)
                .height(this.chartH)
                .backgroundColor(Color.Transparent)
                .onClick((): void => this.tapBar(p))
            }, (p: TrendPoint, i: number): string => 'hl_' + p.label + '_' + i.toString())
          }
          .width('100%')
          .height(this.chartH)
        }
        .layoutWeight(1)
        .height(this.chartH)
        Blank().width(Chart.AXIS_GAP)
        this.AxisLabels(false)
      }
      .width('100%')

      // 基线（与柱状图同一条参照线，折线贴在同一基线上）
      Row({ space: 0 }) {
        Blank().width(Chart.AXIS_W)
        Blank().width(Chart.AXIS_GAP)
        Row()
          .layoutWeight(1)
          .height(1)
          .backgroundColor(this.tc(Neutral.BORDER))
        Blank().width(Chart.AXIS_GAP)
        Blank().width(Chart.AXIS_RIGHT_W)
      }
      .width('100%')

      // X 轴标签行：与折线数据点一一对齐
      Row({ space: 0 }) {
        Blank().width(Chart.AXIS_W)
        Blank().width(Chart.AXIS_GAP)
        this.XLabels()
        Blank().width(Chart.AXIS_GAP)
        Blank().width(Chart.AXIS_RIGHT_W)
      }
      .width('100%')
    }
    .width('100%')
  }

  /**

   * 饼图（环形）主体：Canvas 环形图 + 右侧图例。
 */
  @Builder
  PieBody() {
    Row({ space: Space.MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Canvas(this.pieCtx)
          .width(this.PIE_SIZE)
          .height(this.PIE_SIZE)
          .onReady((): void => {
            this.canvasReady = true
            this.drawPie()
          })
          // 入场：淡入 + 轻微放大，与柱状图的「生长」同节奏
          .opacity(this.grown ? 1 : 0)
          .scale({ x: this.grown ? 1 : 0.86, y: this.grown ? 1 : 0.86 })
          .animation({ duration: 420, curve: Curve.EaseOut })

        // 环心汇总：总计 + 口径说明，随主题自动换色
        Column({ space: 2 }) {
          Text(Biz.formatKg(this.totalKg()))
            .fontSize(FontSize.TITLE)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('累计减排')
            .fontSize(Chart.AXIS_FONT)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
        }
      }
      .width(this.PIE_SIZE)
      .height(this.PIE_SIZE)

      // 图例：色点 + 周期名 + 减排量 + 占比，点击查看该周期明细
      Column({ space: 6 }) {
        ForEach(this.points, (p: TrendPoint, i: number) => {
          Row({ space: 6 }) {
            Circle()
              .width(8)
              .height(8)
              .fill(this.pieColor(i))
            Text(p.label)
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.barValue(p.kg))
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
            Text(this.piePct(p.kg))
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
              .width('16%')
          }
          .width('100%')
          .onClick((): void => this.tapBar(p))
        }, (p: TrendPoint, i: number): string => 'pl_' + p.label + '_' + i.toString())
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**

   * 绘图区：网格线 + 柱体
 */
  @Builder
  PlotArea() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 横向网格线：与纵轴 4 档刻度一一对应（顶部、1/3、2/3、基线）
      Column() {
        Row().width('100%').height(1).backgroundColor(this.tc(Neutral.BORDER))
        Blank()
        Row().width('100%').height(1).backgroundColor(this.tc(Neutral.BORDER))
        Blank()
        Row().width('100%').height(1).backgroundColor(this.tc(Neutral.BORDER))
        Blank()
        Row().width('100%').height(1).backgroundColor(this.tc(Neutral.BORDER))
      }
      .width('100%')
      .height(this.chartH)

      // 柱体层：等宽槽位，柱体底部对齐 Stack 底边（即 X 轴）
      Row() {
        ForEach(this.points, (p: TrendPoint, i: number) => {
          Stack({ alignContent: Alignment.Bottom }) {
            // 柱体：贴住 Stack 底边，底边恒等于 X 轴
            Column()
              .width(Chart.BAR_W)
              .height(this.barH(p.kg))
              .linearGradient({
                angle: 90,
                colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
              })
              .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 2, bottomRight: 2 })
              // 入场：grown 为 false 时高度为 0，animateTo 置 true 后从基线长出
              // （用高度而非 scale：scale 会绕组件中心缩放，柱子会从中间鼓出来）

            // 柱顶数值：放在 Stack 里做纯视觉叠加，向上偏移一个柱高，
            // 不参与 Column 布局，因此不会把柱体顶离基线
            Text(this.barValue(p.kg))
              .fontSize(Chart.VALUE_FONT)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(i === this.points.length - 1 ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Clip })
              .textAlign(TextAlign.Center)
              .width(Chart.BAR_W)
              .height(Chart.VALUE_H)
              .offset({ x: 0, y: -this.barH(p.kg) })
              .opacity(this.grown ? 1 : 0)
          }
          .layoutWeight(1)
          .height(this.chartH)
          .onClick((): void => this.tapBar(p))
        }, (p: TrendPoint, i: number): string => p.label + '_' + i.toString())
      }
      .width('100%')
      .height(this.chartH)
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .height(this.chartH)
  }

  /**

   * 柱体高度：按最大值归一化。
   * 预留 Chart.VALUE_H 给柱顶数值，保证最小值也有可见高度且不越过绘图区顶部。
   */
  private barH(kg: number): number {
    // grown 为 false 时柱高归零，配合 animateTo 实现「从基线生长」
    if (!this.grown) {
      return 0;
    }
    const usable: number = this.chartH - Chart.VALUE_H;
    const h: number = (kg / this.maxKg()) * usable;
    return Math.max(4, Math.min(usable, h));
  }
/**
 * 折线图：网格线 + 面积填充 + 折线 + 数据点 + 数值标签。
 */
  private drawLine(): void {
    const ctx: CanvasRenderingContext2D = this.lineCtx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    // onReady 之前 width/height 为 0，指令必须被挡下
    if (!this.canvasReady || w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);

    // 网格线：与纵轴四档刻度严格同位（顶 / 1-3 / 2-3 / 基线）
    ctx.strokeStyle = this.tc(Neutral.BORDER);
    ctx.lineWidth = Math.max(1, w * 0.0022);
    for (let g: number = 0; g < 4; g++) {
      const gy: number = h * g / 3;
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(w, gy);
      ctx.stroke();
    }

    const n: number = this.points.length;
    if (n === 0) {
      return;
    }

    // 归一化：与 barH 同口径 —— 柱顶位置 = chartH - (kg/mx)*(chartH-VALUE_H)，
    // 即「1 - (kg/mx)*usableF」处；kg=0 时落在基线（h），kg=mx 时在 VALUE_H 处。
    const usableF: number = 1 - Chart.VALUE_H / this.chartH;
    const mx: number = this.maxKg() > 0 ? this.maxKg() : 1;
    const slot: number = w / n;
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i: number = 0; i < n; i++) {
      xs.push(slot * (i + 0.5));
      ys.push((1 - this.points[i].kg / mx * usableF) * h);
    }

    // 面积填充：折线 + 基线闭合的多边形，用档位浅色（primaryPale 已是半透明色）
    const pale: string = this.tc(EcoTheme.primaryPale(this.ecoLevel));
    ctx.beginPath();
    ctx.moveTo(xs[0], h);
    for (let i: number = 0; i < n; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.lineTo(xs[n - 1], h);
    ctx.closePath();
    ctx.fillStyle = pale;
    ctx.fill();

    // 折线：档位深色，圆角接头
    const deep: string = this.tc(EcoTheme.primaryDeep(this.ecoLevel));
    ctx.beginPath();
    ctx.moveTo(xs[0], ys[0]);
    for (let i: number = 1; i < n; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.strokeStyle = deep;
    ctx.lineWidth = Math.max(2, w * 0.005);
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.stroke();

    // 数据点（光晕 + 实心）与数值标签
    const rDot: number = Math.max(3, w * 0.011);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'alphabetic';
    ctx.font = (h * 0.062) + 'px sans-serif';
    for (let i: number = 0; i < n; i++) {
      const last: boolean = i === n - 1;
      ctx.beginPath();
      ctx.arc(xs[i], ys[i], rDot * 2.1, 0, Math.PI * 2);
      ctx.fillStyle = pale;
      ctx.fill();
      ctx.beginPath();
      ctx.arc(xs[i], ys[i], rDot, 0, Math.PI * 2);
      ctx.fillStyle = deep;
      ctx.fill();
      // 最新一期用档位深色强调，其余走弱化文字色（与柱顶数值同一套语义）
      ctx.fillStyle = last ? deep : this.tc(Neutral.TEXT_MUTED);
      ctx.fillText(this.barValue(this.points[i].kg), xs[i], ys[i] - rDot - h * 0.022);
    }
  }
/**
 * 环形图：按当前区间各周期占比画环带，空洞由 declarative 汇总文字填充。
 */
  private drawPie(): void {
    const ctx: CanvasRenderingContext2D = this.pieCtx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    if (!this.canvasReady || w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);

    const n: number = this.points.length;
    if (n === 0) {
      return;
    }
    const cx: number = w / 2;
    const cy: number = h / 2;
    const rOut: number = Math.min(w, h) * 0.46;
    const rIn: number = rOut * 0.60;

    let total: number = 0;
    for (let i: number = 0; i < n; i++) {
      total += this.points[i].kg;
    }
    if (total <= 0) {
      // 空数据：一圈浅色轨道环（从 12 点方向起整圈）
      this.ringSegment(ctx, cx, cy, rOut, rIn, -Math.PI / 2, Math.PI * 1.5, this.tc(Neutral.BORDER));
      return;
    }

    const gap: number = 0.018;
    let start: number = -Math.PI / 2; // 12 点方向起笔
    for (let i: number = 0; i < n; i++) {
      const kg: number = this.points[i].kg;
      if (kg <= 0) {
        continue;
      }
      const full: number = kg / total * Math.PI * 2;
      let sweep: number = full;
      if (sweep > gap * 2) {
        sweep -= gap;
      }
      if (sweep <= 0) {
        continue;
      }
      this.ringSegment(ctx, cx, cy, rOut, rIn, start, start + sweep, this.pieColor(i));
      start += full;
    }
  }

  /**

   * 画一段环带（环形图扇形）。
   * 外弧从 a0 正向扫到 a1，内弧从 a1 反向扫回 a0，闭合后一次填充。
   */
  private ringSegment(ctx: CanvasRenderingContext2D, cx: number, cy: number,
                      rOut: number, rIn: number, a0: number, a1: number, color: string): void {
    ctx.beginPath();
    ctx.arc(cx, cy, rOut, a0, a1, false);
    ctx.arc(cx, cy, rIn, a1, a0, true);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
  }

  /** X 轴标签行（与 PlotArea 同宽同列数，逐槽居中） */
  @Builder
  XLabels() {
    Row() {
      ForEach(this.points, (p: TrendPoint, i: number) => {
        Text(p.label)
          .fontSize(Chart.AXIS_FONT)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(i === this.points.length - 1 ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
          .fontWeight(i === this.points.length - 1 ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
          // 与柱体槽位一一对应，禁止收缩
          .flexShrink(0)
      }, (p: TrendPoint, i: number): string => 'x_' + p.label + '_' + i.toString())
    }
    .height(Chart.XAXIS_H)
    .layoutWeight(1)
  }

  /**

   * 纵轴刻度列。
   * left=true 显示 kg；left=false 显示积分（1 kg = 10 积分）。
   * 两列都是「最大 / 1/3 / 2/3 / 0」四档，与绘图区网格线严格等高对齐。
   */
  @Builder
  AxisLabels(left: boolean) {
    Column() {
      Text(left ? this.axisKg(this.maxKg()) : '' + Biz.pointsOf(this.maxKg()))
        .fontSize(Chart.AXIS_FONT)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
      Text(left ? this.axisKg(this.maxKg() * 2 / 3) : '' + Biz.pointsOf(this.maxKg() * 2 / 3))
        .fontSize(Chart.AXIS_FONT)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
      Text(left ? this.axisKg(this.maxKg() / 3) : '' + Biz.pointsOf(this.maxKg() / 3))
        .fontSize(Chart.AXIS_FONT)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
      Text('0')
        .fontSize(Chart.AXIS_FONT)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
    }
    .width(left ? Chart.AXIS_W : Chart.AXIS_RIGHT_W)
    .height(this.chartH)
    // 轴列宽度必须锁死：一旦被压缩，X 轴标签的留白就会与轴列错位
    .flexShrink(0)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(left ? HorizontalAlign.Start : HorizontalAlign.End)
  }
@Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '峰值',
          value: this.axisKg(this.maxKg()) + ' kg',
          icon: 'up',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '平均',
          value: this.axisKg(this.avgKg()) + ' kg',
          icon: 'chart',
          accent: this.tc(Accent.INFO),
          tint: this.tc(Accent.INFO_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '总计',
          value: this.axisKg(this.totalKg()) + ' kg',
          icon: 'world',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  SummaryCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '区间汇总', more: '看分类占比 ›', onMoreTap: (): void => this.openCategory() })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          this.SummaryLine('峰值周期', this.maxLabel() + '（' + Biz.formatKg(this.maxKg()) + '）')
          this.SummaryLine('累计减排', Biz.formatKg(this.totalKg()))
          this.SummaryLine('累计积分', '+' + this.totalPoints() + ' 分')
          this.SummaryLine('折算树木', '≈ 种下 ' + Biz.treesOf(this.totalPoints()) + ' 棵树')
          Row() {
            Text(this.deltaText())
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.deltaColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: Space.SM })
          .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  SummaryLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
      Blank()
      Text(value)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }
}
