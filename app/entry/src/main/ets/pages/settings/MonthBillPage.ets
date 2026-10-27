import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalRecord, TrendPoint } from '../../data/MockStore'
import { Accent, Biz, CategoryMeta, FontSize, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { AppClock } from '../../utils/AppClock'
import { CfCard, CfEmpty, CfPill, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 月度账单路由参数：ArkTS 严格模式禁止无类型对象字面量，故声明 interface */
interface MonthBillParam {
  month: string
}

/** 每日明细行 */
interface DayBillRow {
  date: string;
  label: string;
  kg: number;
  points: number;
  count: number;
}

/**

 * P28 月度绿色账单
 */
@Component
export struct MonthBillPage {
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
  @State private month: string = ''
  @State private stats: LocalRecord[] = []
  @State private daily: TrendPoint[] = []
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    // 路由参数由 PageMap 经 AppStorage 传入（可选，缺省显示当月）
    const m: string | undefined = AppStorage.get<string>('detailMonth')
    if (m !== undefined && m !== null && m.length > 0) {
      this.month = m
      AppStorage.delete('detailMonth')
    }
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.stats = await DataSource.categoryStats(30)
      this.daily = await DataSource.trend('day')
    } catch (err) {
      // DataSource 内部已兜底
    }
  }
/** 本月减排合计（四大类聚合口径） */
  private monthKg(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].reduceKg
    }
    return Math.round(sum * 100) / 100
  }

  /** 本月积分 */
  private monthPoints(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].points
    }
    return sum
  }

  /** 本月记录数（次） */
  private monthCount(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].amount
    }
    return Math.round(sum)
  }

  /** 占比基准：四大类合计 */
  private totalKg(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].reduceKg
    }
    return Math.round(sum * 1000) / 1000
  }

  /** 某类占比（0-100，保留一位小数） */
  private pctOf(r: LocalRecord): number {
    const t: number = this.totalKg()
    if (t <= 0) return 0
    return Math.round((r.reduceKg / t) * 1000) / 10
  }

  /** 占比条宽度字符串：先算好再传，满足 ArkTS 百分比宽度要求 */
  private pctWidth(r: LocalRecord): string {
    return Math.max(2, this.pctOf(r)) + '%'
  }
/** 上月合计减排：用近 7 天日均值 × 上月天数近似，保持口径可解释 */
  private lastMonthKg(): number {
    if (this.daily.length === 0) return 0
    let sum: number = 0
    for (let i: number = 0; i < this.daily.length; i++) {
      sum += this.daily[i].kg
    }
    const avg: number = sum / this.daily.length
    return Math.round(avg * 30 * 100) / 100
  }

  /** 环比差额：本月 - 上月 */
  private diffKg(): number {
    return Math.round((this.monthKg() - this.lastMonthKg()) * 100) / 100
  }

  /** 环比文案：涨为正、跌为负 */
  private diffText(): string {
    const d: number = this.diffKg()
    if (d > 0) return '+' + d.toFixed(2)
    return d.toFixed(2)
  }

  /** 涨跌色：减排增加为绿（正向），减少为红（负向） */
  private diffColor(): string {
    return this.diffKg() >= 0 ? this.tc(Accent.SUCCESS) : this.tc(Accent.DANGER)
  }

  /** 涨跌语义：正向还是负向 */
  private isUp(): boolean {
    return this.diffKg() >= 0
  }
/** 每日明细行（近 7 天，倒序：今天在最上） */
  private dayRows(): DayBillRow[] {
    const out: DayBillRow[] = []
    for (let i: number = this.daily.length - 1; i >= 0; i--) {
      const p: TrendPoint = this.daily[i]
      const row: DayBillRow = {
        date: p.label,
        label: p.label,
        kg: p.kg,
        points: p.points,
        count: p.kg > 0 ? Math.max(1, Math.round(p.points / 10)) : 0
      }
      out.push(row)
    }
    return out
  }

  /** 明细中的最大减排量，用于归一化条宽 */
  private dayMaxKg(): number {
    let m: number = 0
    for (let i: number = 0; i < this.daily.length; i++) {
      if (this.daily[i].kg > m) m = this.daily[i].kg
    }
    return m <= 0 ? 1 : m
  }

  /** 某日条宽百分比 */
  private dayWidth(r: DayBillRow): string {
    return Math.max(3, Math.round((r.kg / this.dayMaxKg()) * 100)) + '%'
  }
private shareBill(): void {
    toast('月度账单已生成（' + this.monthLabel() + ' 共减排 ' + this.monthKg() + ' kg）')
  }

  private openReport(): void {
    AppRouter.pathStack.pushPathByName(RouteName.EXPORT_REPORT, null)
  }

  /** 月份展示：参数为空时取当前月（本地时间校准，见 AppClock：跟随系统时钟） */
  private monthLabel(): string {
    if (this.month.length > 0) return this.month
    const d: Date = AppClock.today()
    const m: number = d.getMonth() + 1
    return d.getFullYear() + ' 年 ' + m + ' 月'
  }
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
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisAppear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Column() {
        this.BillContent()
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
    .hideTitleBar(true).opacity(this.themeTick >= 0 ? 1 : 0)
  }
@Builder
  BillContent() {
    Column() {
      CfTopBar({
        title: '月度绿色账单',
        onBack: (): void => {
          AppRouter.pathStack.pop()
        }
      })
      if (this.stats.length === 0 || this.monthKg() <= 0) {
        Column() {
          CfEmpty({
            icon: 'receipt',
            text: '本月还没有账单',
            sub: '记录几条低碳行为就能生成账单'
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.BillHead()
            this.StatRow()
            this.CategorySection()
            this.CompareCard()
            this.DailySection()
            this.FooterAction()
          }
          .width('100%')
          .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 30 })
        }
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
      }
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
@Builder
  BillHead() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.monthLabel() + ' 减排量')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 4 }) {
            Text(this.monthKg().toFixed(2))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('kg')
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          Text('减排量 ≈ 种下 ' + Biz.treesOf(this.monthPoints()) + ' 棵树')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        CfIcon({ kind: 'ui', code: 'receipt', iconSize: 34 })
      }
      .width('100%')

      // 环比条：涨绿跌红
      Row({ space: Space.SM }) {
        Text(this.isUp() ? '▲' : '▼')
          .fontSize(FontSize.SMALL)
          .fontColor('#FFFFFF')
        Text(this.diffText() + ' kg')
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('较上月' + (this.isUp() ? '增加' : '减少'))
          .fontSize(FontSize.CAPTION)
          .fontColor('rgba(255,255,255,0.9)')
      }
      .width('100%')
      .padding(Space.MD)
      .backgroundColor('rgba(255,255,255,0.20)')
      .borderRadius(Radius.MD)
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
@Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '本月积分',
          value: '' + this.monthPoints(),
          icon: 'coin',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '记录数',
          value: '' + this.monthCount(),
          icon: 'record',
          accent: this.tc(Accent.INFO),
          tint: this.tc(Accent.INFO_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '环比',
          value: this.diffText(),
          icon: this.isUp() ? 'up' : 'down',
          accent: this.diffColor(),
          tint: this.isUp() ? this.tc(Accent.SUCCESS_BG) : this.tc(Accent.DANGER_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  CategorySection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '四大类占比', more: '查看分析 ›', onMoreTap: (): void => this.openReport() })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          ForEach(this.stats, (r: LocalRecord) => {
            this.CategoryRow(r)
          }, (r: LocalRecord): string => r.category)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  CategoryRow(r: LocalRecord) {
    Column({ space: 6 }) {
      Row() {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: CategoryMeta.icon(r.category), iconSize: 14, tone: IconTone.ofCategory(r.category) })
          Text(CategoryMeta.label(r.category))
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Neutral.TEXT))
        }
        Blank()
        Text(this.pctOf(r) + '%')
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(CategoryMeta.color(r.category)))
      }
      .width('100%')

      // 占比条：轨道 + 分类色填充
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor(this.tc(Neutral.SURFACE))
          .borderRadius(Radius.PILL)
        Row()
          .width(this.pctWidth(r))
          .height(8)
          .backgroundColor(this.tc(CategoryMeta.color(r.category)))
          .borderRadius(Radius.PILL)
      }
      .width('100%')

      Text(Biz.formatKg(r.reduceKg) + ' · ' + Math.round(r.amount) + ' 次')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
    }
    .width('100%')
  }
@Builder
  CompareCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '与上月对比' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          this.CompareRow('本月', this.monthKg(), this.tc(EcoTheme.primary(this.ecoLevel)), true)
          this.CompareRow('上月（近 30 天折算）', this.lastMonthKg(), this.tc(Neutral.TEXT_MUTED), false)

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
            .margin({ top: Space.XS })

          Row() {
            Text('环比差额')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
            Blank()
            CfPill({
              text: (this.isUp() ? '进步 ' : '减少 ') + Math.abs(this.diffKg()).toFixed(2) + ' kg',
              tone: this.isUp() ? 'success' : 'danger'
            })
          }
          .width('100%')

          Text(this.isUp()
            ? '继续保持，你的低碳习惯正在稳定发挥'
            : '本月略有回落，去「智慧建议」看看可以补哪一类')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .lineHeight(17)
            .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 对比行：标签 + 归一化条 + 数值 */
  @Builder
  CompareRow(label: string, kg: number, color: string, isCurrent: boolean) {
    Column({ space: 5 }) {
      Row() {
        Text(label)
          .fontSize(FontSize.SMALL)
          .fontColor(isCurrent ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_SUB))
          .fontWeight(isCurrent ? FontWeight.Medium : FontWeight.Normal)
        Blank()
        Text(Biz.formatKg(kg))
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor(this.tc(Neutral.SURFACE))
          .borderRadius(Radius.PILL)
        Row()
          .width(Math.max(3, Math.round((kg / Math.max(this.monthKg(), this.lastMonthKg(), 0.01)) * 100)) + '%')
          .height(6)
          .backgroundColor(color)
          .borderRadius(Radius.PILL)
      }
      .width('100%')
    }
    .width('100%')
  }
@Builder
  DailySection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '每日明细', more: '查看趋势 ›', onMoreTap: (): void => this.openReport() })
      if (this.daily.length === 0) {
        CfCard({}) {
          CfEmpty({ icon: 'calendar', text: '暂无每日明细', sub: '连续记录几天就能看到曲线' })
        }
      } else {
        CfCard({ pad: Space.LG }) {
          Column() {
            // 表头
            Row() {
              Text('日期')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .width(60)
              Text('减排')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .layoutWeight(1)
              Text('积分')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .textAlign(TextAlign.End)
                .width(60)
            }
            .width('100%')
            .padding({ bottom: Space.SM })

            ForEach(this.dayRows(), (r: DayBillRow, i: number) => {
              this.DayRow(r)
              if (i < this.dayRows().length - 1) {
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor(this.tc(Neutral.BORDER))
              }
            }, (r: DayBillRow): string => r.date)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
  }

  @Builder
  DayRow(r: DayBillRow) {
    Row() {
      Text(r.label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT))
        .width(60)

      Column({ space: 4 }) {
        Text(r.kg > 0 ? r.kg.toFixed(2) + ' kg' : '—')
          .fontSize(FontSize.SMALL)
          .fontColor(r.kg > 0 ? this.tc(Neutral.TEXT_SUB) : this.tc(Neutral.TEXT_MUTED))
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(5)
            .backgroundColor(this.tc(Neutral.SURFACE))
            .borderRadius(Radius.PILL)
          Row()
            .width(this.dayWidth(r))
            .height(5)
            .backgroundColor(r.kg > 0 ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.BORDER))
            .borderRadius(Radius.PILL)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(r.kg > 0 ? ('+' + r.points) : '0')
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(r.kg > 0 ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
        .textAlign(TextAlign.End)
        .width(60)
    }
    .width('100%')
    .padding({ top: Space.SM, bottom: Space.SM })
  }
@Builder
  FooterAction() {
    Row() {
      Text('保存并分享本月账单')
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
        .onClick((): void => this.shareBill())
    }
    .width('100%')
  }
}
