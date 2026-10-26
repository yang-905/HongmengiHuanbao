import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalRecord } from '../../data/MockStore'
import { Biz, CategoryMeta, FontSize, Glass, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 统计周期选项 */
interface RangeTab {
  key: string;
  name: string;
  days: number;
}

/**
 * P11 分类占比
 * ------------------------------------------------------------------
 * 真实实现：周期切换 + 100% 堆叠占比条（四大类分段着色）
 *          + 每类的环形指标徽标 / 减排 kg / 占比% / 记录数
 * 说明：ArkUI 不支持 conic-gradient，这里用「Row 叠加 + 百分比宽度」
 *      拼出分段占比条，再配合每类的圆形占比徽标与横向进度条呈现，
 *      视觉等价于环形图且零依赖。
 */
@Component
export struct CategoryAnalysisPage {
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
  @State private stats: LocalRecord[] = []
  @State private days: number = 30
  /**
   * 周期切换锁。
   * 只在「本次加载尚未返回」期间为 true，用于挡掉连点；
   * 每次 load() 结束时必须复位，否则锁会永久卡住，
   * pickRange 里的守卫会让「近 7 天 / 近 90 天」完全点不动。
   */
  @State private loading: boolean = true
  /**
   * 切换轨道实测宽度（vp）。
   * 药丸宽度必须与文字槽位严格同宽，否则滑过去会错位。
   * 依赖屏幕尺寸与页面 padding，用 onAreaChange 实测而非写死。
   */
  @State private rangeTrackW: number = 0

  private scroller: Scroller = new Scroller()

  private ranges: RangeTab[] = [
    { key: '7', name: '近 7 天', days: 7 },
    { key: '30', name: '近 30 天', days: 30 },
    { key: '90', name: '近 90 天', days: 90 }
  ]

  aboutToAppear(): void {
    this.load(30)
  }

  private async load(d: number): Promise<void> {
    // days 的写入放进动画闭包：药丸平移与文字缩放随之过渡
    this.getUIContext().animateTo({ duration: 320, curve: Curve.Friction }, (): void => {
      this.days = d
    })
    try {
      this.stats = await DataSource.categoryStats(d)
    } catch (err) {
      this.stats = []
    }
    // loading 必须复位：它在 aboutToAppear 里被置为 true，若不复位，
    // pickRange 的 `if (this.days === d || this.loading) return` 永远命中，
    // 「近 7 天 / 近 90 天」两个周期就完全点不动。
    this.loading = false
  }

  /* ---------- 统计口径 ---------- */

  /** 四大类减排合计 */
  private totalKg(): number {
    let s: number = 0
    for (let i = 0; i < this.stats.length; i++) s += this.stats[i].reduceKg
    return Math.round(s * 100) / 100
  }

  /** 四大类记录合计 */
  private totalCount(): number {
    let s: number = 0
    for (let i = 0; i < this.stats.length; i++) s += this.stats[i].amount
    return s
  }

  /** 某类占比（百分数，保留一位小数） */
  private pctOf(r: LocalRecord): number {
    const t: number = this.totalKg()
    if (t <= 0) return 0
    return Math.round((r.reduceKg / t) * 1000) / 10
  }

  /** 占比最大的分类名 */
  private topName(): string {
    let kg: number = -1
    let name: string = '-'
    for (let i = 0; i < this.stats.length; i++) {
      if (this.stats[i].reduceKg > kg) {
        kg = this.stats[i].reduceKg
        name = CategoryMeta.label(this.stats[i].category)
      }
    }
    return name
  }

  /** 该分类平均单次减排 */
  private avgOf(r: LocalRecord): number {
    if (r.amount <= 0) return 0
    return Math.round((r.reduceKg / r.amount) * 1000) / 1000
  }

  /** 堆叠条分段宽度：不足 3% 时保底 3%，避免完全看不见 */
  private segWidth(r: LocalRecord): string {
    const p: number = this.pctOf(r)
    return Math.max(3, p) + '%'
  }

  /** 数值格式化：整数不带小数，否则保留两位 */
  private fmtNum(n: number): string {
    const v: number = Math.round(n * 100) / 100
    if (Math.abs(v - Math.round(v)) < 0.001) {
      return '' + Math.round(v)
    }
    return v.toFixed(2)
  }

  /**
 * 周期切换。
 * days 的赋值放进 animateTo 闭包，药丸的 translate / 文字的 scale
 * 会在同一帧内做属性动画，读起来是「药丸滑过去 + 文字轻轻放大」，
 * 而非瞬间跳变（与 TrendChartPage.load 同思路）。
 */
  private pickRange(r: RangeTab): void {
    if (this.days === r.days || this.loading) return
    this.load(r.days)
  }

  private tapCategory(r: LocalRecord): void {
    toast(CategoryMeta.label(r.category) + '：' + Biz.formatKg(r.reduceKg))
  }

  private openTrend(): void {
    AppRouter.pathStack.pushPathByName(RouteName.TREND_CHART, null)
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

  /** 记录信号变化 → 重算全局碳档位 + 按当前周期重拉数据 */
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
      this.reload()
    }
  }

  /**
   * 按当前统计周期重新拉取占比数据。
   * load() 需要周期参数，不能直接当无参重载调用，故单独包一层。
   */
  private reload(): void {
    this.load(this.days)
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
            title: '分类占比',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.RangeBar()
              if (this.stats.length === 0 || this.totalKg() <= 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'pie', text: '暂无分类数据', sub: '记录低碳行为后可查看四大类占比' })
                }
              } else {
                this.RatioCard()
                this.StatRow()
                this.CategoryList()
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

  /* ---------- 周期切换（液态玻璃滑动分段控件） ---------- */

  /**
   * 周期分段控件：滑动药丸 + 液态玻璃
   * ------------------------------------------------------------------
   * 参照 `TrendChartPage.TabBar()` 的同一套做法：
   *   · 选中态是一块**独立图层**用 translate 平移过去，读起来是「滑」不是「闪」；
   *   · 药丸宽度与文字槽位严格同宽（onAreaChange 实测轨道宽），否则滑过去错位；
   *   · 药丸挂 backdropBlur + 档位高光描边 = 液态玻璃，
   *     且同区域只挂一层模糊（见 Theme.ets Glass.LIVE_BLUR 性能说明）。
   *
   * 药丸是 HitTestMode.None，点击由文字层承接。
   */
  @Builder
  RangeBar() {
    Stack({ alignContent: Alignment.Start }) {
      // 轨道：极淡玻璃底，只做承载
      Row()
        .width('100%')
        .height(36)
        .borderRadius(Radius.PILL)
        .linearGradient(this.tw(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1)))
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

      // 选中药丸：随 days 平移，玻璃质感对齐右下角加号按钮
      Row()
        .width(this.rangePillW())
        .height(36)
        .linearGradient({
          angle: 90,
          colors: [
            [this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0],
            [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]
          ]
        })
        .borderRadius(Radius.PILL)
        .border({ width: 1, color: 'rgba(255,255,255,0.55)' })
        // 紧致投影：不能用 Shadow.brand()，大偏移投影会溢出轨道右缘形成光晕
        .shadow({
          radius: 4,
          color: this.tc(EcoTheme.shadowColor(this.ecoLevel)),
          offsetX: 0,
          offsetY: 1
        })
        .translate({ x: this.rangePillX() })
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
        // 弹簧感曲线：起步快、收尾带轻微回弹，模仿 iOS segmented control
        .animation({ duration: 320, curve: Curve.Friction })
        .hitTestBehavior(HitTestMode.None)

      // 文字层：槽位均分，选中项轻微放大
      Row() {
        ForEach(this.ranges, (r: RangeTab) => {
          Text(r.name)
            .fontSize(FontSize.BODY)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontWeight(this.days === r.days ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.days === r.days ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .layoutWeight(1)
            .height(36)
            .scale({
              x: this.days === r.days ? 1.06 : 1,
              y: this.days === r.days ? 1.06 : 1
            })
            .animation({ duration: this.days === r.days ? 260 : 200, curve: Curve.EaseOut })
            .onClick((): void => this.pickRange(r))
        }, (r: RangeTab): string => r.key)
      }
      .width('100%')
      .height(36)
    }
    .width('100%')
    .onAreaChange((old: Area, area: Area): void => {
      this.onRangeTrackArea(area.width as number | string)
    })
    .padding(3)
    .borderRadius(Radius.PILL)
    // 裁剪加在 Stack（轨道与药丸的共同父级）上：
    // 药丸是轨道的兄弟节点，clip 加在轨道自身裁不到它的投影
    .clip(true)
    .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(this.tw(Shadow.card()))
  }

  /** 记录轨道实测宽度（药丸必须与文字槽位同宽，否则滑动会错位） */
  private onRangeTrackArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.rangeTrackW) > 0.5) {
      this.rangeTrackW = w
    }
  }

  /** 单项宽度 = (轨道实测宽 − 左右各 3vp 内边距) / 周期数
   *  ⚠️ rangeTrackW 是 onAreaChange 测得的 **Stack 总宽**（外层 Stack 带
   *  .padding(3)），必须扣掉 6vp 才是轨道内可用宽度。漏扣的旧公式让药丸
   *  每格宽出 2vp、位移每级偏 2vp，滑到最右档（「近 90 天」）时咬破轨道
   *  右缘，被外层 clip(true) 裁成直边 —— 表现为最右档圆角消失、边缘错位。
   *  与 TrendChartPage.cellW() 同口径（那边修过同一个坑）。 */
  private rangeCellW(): number {
    const track: number = this.rangeTrackW > 0 ? this.rangeTrackW : 300
    return (track - 6) / this.ranges.length
  }

  /** 药丸位移 = 选中项序号 × 单项宽度 */
  private rangePillX(): number {
    return this.rangeCellW() * this.rangeIndex()
  }

  /** 药丸宽度 = 单项宽度 */
  private rangePillW(): number {
    return this.rangeCellW()
  }

  /** 当前选中周期下标；找不到时兜底 0 */
  private rangeIndex(): number {
    for (let i = 0; i < this.ranges.length; i++) {
      if (this.ranges[i].days === this.days) return i
    }
    return 0
  }

  /* ---------- 占比总览：100% 堆叠条 + 环形指标 ---------- */
  @Builder
  RatioCard() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text('四大类减排占比')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 3 }) {
            Text(this.fmtNum(this.totalKg()))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('kg CO₂e')
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          Text('共 ' + this.totalCount() + ' 次记录 · 贡献最高：' + this.topName())
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        CfIcon({ kind: 'ui', code: 'pie', iconSize: 34 })
      }
      .width('100%')

      // 分段占比条：每个大类按占比宽度着色，等价于环形图的扇区
      Row() {
        ForEach(this.stats, (r: LocalRecord) => {
          Row()
            .width(this.segWidth(r))
            .height(14)
            .backgroundColor(this.tc(CategoryMeta.color(r.category)))
        }, (r: LocalRecord): string => r.category)
      }
      .width('100%')
      .borderRadius(Radius.PILL)
      .clip(true)

      // 图例：色点 + 名称 + 占比
      Column({ space: Space.SM }) {
        ForEach(this.stats, (r: LocalRecord) => {
          Row({ space: Space.SM }) {
            Circle({ width: 8, height: 8 }).fill(this.tc(CategoryMeta.color(r.category)))
            Text(CategoryMeta.label(r.category))
              .fontSize(FontSize.SMALL)
              .fontColor('#FFFFFF')
            Blank()
            Text(this.pctOf(r) + '%')
              .fontSize(FontSize.SMALL)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width('100%')
        }, (r: LocalRecord): string => 'lg_' + r.category)
      }
      .width('100%')
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

  /* ---------- 统计三宫格 ---------- */
  @Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '减排合计',
          value: Biz.formatKg(this.totalKg()),
          icon: 'world',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '记录条数',
          value: '' + this.totalCount(),
          icon: 'note',
          accent: this.tc(CategoryMeta.color(CategoryMeta.ENERGY)),
          tint: this.tc(CategoryMeta.bg(CategoryMeta.ENERGY))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '折算积分',
          value: '+' + Biz.pointsOf(this.totalKg()),
          icon: 'coin',
          accent: this.tc(CategoryMeta.color(CategoryMeta.RECYCLE)),
          tint: this.tc(CategoryMeta.bg(CategoryMeta.RECYCLE))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  /* ---------- 分类明细 ---------- */
  @Builder
  CategoryList() {
    Column({ space: Space.MD }) {
      CfSection({ title: '分类明细', more: '看趋势 ›', onMoreTap: (): void => this.openTrend() })
      Column({ space: Space.MD }) {
        ForEach(this.stats, (r: LocalRecord) => {
          // 尾随 lambda 后不能再链式调用属性，故用 Column 包一层承载 onClick
          Column() {
            CfCard({ pad: Space.LG }) {
              Column({ space: Space.MD }) {
                Row({ space: Space.MD }) {
                  // 圆形占比徽标：大类 emoji + 占比数字
                  Column({ space: 1 }) {
                    CfIcon({ kind: 'ui', code: CategoryMeta.icon(r.category), iconSize: 17, tone: IconTone.ofCategory(r.category) })
                    Text(this.pctOf(r) + '%')
                      .fontSize(9)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.tc(CategoryMeta.color(r.category)))
                  }
                  .width(48)
                  .height(48)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.tc(CategoryMeta.bg(r.category)))
                  .borderRadius(24)

                  Column({ space: 5 }) {
                    Row() {
                      Text(CategoryMeta.label(r.category))
                        .fontSize(FontSize.BODY)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.tc(Neutral.TEXT))
                      Blank()
                      Text(Biz.formatKg(r.reduceKg))
                        .fontSize(FontSize.TITLE)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.tc(CategoryMeta.color(r.category)))
                    }
                    .width('100%')
                    CfProgress({
                      percent: this.pctOf(r),
                      color: this.tc(CategoryMeta.color(r.category)),
                      barHeight: 7
                    })
                    .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')

                Row() {
                  Text('记录 ' + r.amount + ' 次 · 单次均值 ' + this.fmtNum(this.avgOf(r)) + ' kg')
                    .fontSize(FontSize.CAPTION)
                    .fontColor(this.tc(Neutral.TEXT_MUTED))
                  Blank()
                  CfPill({ text: '+' + r.points + ' 分', tone: 'success' })
                }
                .width('100%')
                .padding({ top: Space.SM })
                .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
              }
              .width('100%')
            }
          }
          .width('100%')
          .onClick((): void => this.tapCategory(r))
        }, (r: LocalRecord): string => 'row_' + r.category)
      }
    }
    .width('100%')
  }
}
