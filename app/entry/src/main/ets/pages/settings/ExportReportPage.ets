import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParamStr } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalOverview, LocalRecord } from '../../data/MockStore'
import { Accent, Biz, CategoryMeta, FontSize, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { AppClock } from '../../utils/AppClock'
import { CfCard, CfEmpty, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { CfIcon } from '../../ui/Icon';

/** 月度账单路由参数：ArkTS 严格模式禁止无类型对象字面量 */
class MonthBillParam {
  month: string = '';

  constructor(m: string) {
    this.month = m;
  }
}

/** 当前月份字符串 yyyy-MM（本地时间校准，见 AppClock：跟随系统时钟） */
function currentMonth(): string {
  const d: Date = AppClock.today()
  const m: number = d.getMonth() + 1
  return d.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m)
}

/** 本月起止日期文案 */
function monthRange(): string {
  const d: Date = AppClock.today()
  const m: number = d.getMonth() + 1
  return d.getFullYear() + ' 年 ' + m + ' 月'
}

/** 今日日期文案（yyyy 年 M 月 D 日） */
function todayStr(): string {
  const d: Date = AppClock.today()
  const m: number = d.getMonth() + 1
  const day: number = d.getDate()
  return d.getFullYear() + ' 年 ' + m + ' 月 ' + day + ' 日'
}

/**

 * P26 报表导出
 */
@Component
export struct ExportReportPage {
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
  @State private ov: LocalOverview | null = null
  @State private stats: LocalRecord[] = []
  /** 今日四大类聚合（近 1 天），日报图片导出用 */
  @State private todayStats: LocalRecord[] = []
  /** 截图模式：'month' 月报 / 'today' 日报——截图容器按此渲染 */
  @State private shotMode: string = 'month'
  @State private loading: boolean = true
  @State private exporting: boolean = false

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.ov = await DataSource.overview()
      // 近 30 天四大类聚合，用于月报占比预览
      this.stats = await DataSource.categoryStats(30)
      // 今日四大类聚合（近 1 天），用于日报图片导出
      this.todayStats = await DataSource.categoryStats(1)
    } catch (err) {
      // DataSource 内部已兜底
    }
  }
/** 四大类合计减排（kg） */
  private totalKg(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].reduceKg
    }
    return Math.round(sum * 100) / 100
  }

  /** 四大类合计次数 */
  private totalCount(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.stats.length; i++) {
      sum += this.stats[i].amount
    }
    return sum
  }

  /** 今日四大类合计减排（kg）——日报导出用 */
  private todayKg(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.todayStats.length; i++) {
      sum += this.todayStats[i].reduceKg
    }
    return Math.round(sum * 100) / 100
  }

  /** 当前截图模式的数据源：'today' 取今日聚合，'month' 取近 30 天聚合 */
  private activeStats(): LocalRecord[] {
    return this.shotMode === 'today' ? this.todayStats : this.stats
  }

  /** 当前截图模式合计减排（kg）：日报/月报占比条的统一分母 */
  private shotKg(): number {
    const arr: LocalRecord[] = this.activeStats()
    let sum: number = 0
    for (let i: number = 0; i < arr.length; i++) {
      sum += arr[i].reduceKg
    }
    return Math.round(sum * 100) / 100
  }

  /** 当前截图模式合计次数 */
  private shotCount(): number {
    const arr: LocalRecord[] = this.activeStats()
    let sum: number = 0
    for (let i: number = 0; i < arr.length; i++) {
      sum += arr[i].amount
    }
    return sum
  }

  /** 某类占比（0-100）：分母跟随截图模式（月报下与 totalKg 等价） */
  private pctOf(r: LocalRecord): number {
    const t: number = this.shotKg()
    if (t <= 0) return 0
    return Math.round((r.reduceKg / t) * 1000) / 10
  }

  /** 占比条宽度字符串：先算好再传，满足 ArkTS 百分比宽度要求 */
  private pctWidth(r: LocalRecord): string {
    return Math.max(2, this.pctOf(r)) + '%'
  }
/** 导出：演示反馈，不真实写文件 */
  private exportReport(): void {
    if (this.exporting) return
    if (this.totalKg() <= 0) {
      toast('本月还没有可导出的数据')
      return
    }
    this.exporting = true
    setTimeout((): void => {
      this.exporting = false
      toast('月报已生成（演示环境不写入文件）')
    }, 700)
  }
@State private exportingImg: boolean = false

  /**

   * 导出今日数据 / 月报为 PNG 图片并保存到应用沙箱。
 */
  private exportImage(mode: string): void {
    if (this.exportingImg) return
    const isToday: boolean = mode === 'today'
    if ((isToday ? this.todayKg() : this.totalKg()) <= 0) {
      toast(isToday ? '今天还没有可导出的数据' : '本月还没有可导出的数据')
      return
    }
    this.exportingImg = true
    this.shotMode = mode
    // 等截图容器按新模式完成一帧重渲染，再执行截图
    setTimeout((): void => {
      this.doExport(isToday)
    }, 80)
  }

  /** 截图 → 打包 PNG → 写沙箱（由 exportImage 延帧调用） */
  private async doExport(isToday: boolean): Promise<void> {
    try {
      // ① 组件截图：截取带 id 的报告内容区（标题卡 + 三宫格 + 占比卡）
      // ⚠️ 走 UIContext.componentSnapshot（全局 componentSnapshot.get 已废弃）
      const px: image.PixelMap = await this.getUIContext().getComponentSnapshot().get('reportSnapshot')
      // ② 打包 PNG
      const packer: image.ImagePacker = image.createImagePacker()
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 }
      const buf: ArrayBuffer = await packer.packToData(px, packOpts)
      // ③ 写入沙箱文件目录
      const ctx = this.getUIContext().getHostContext()
      if (ctx === undefined) {
        toast('导出失败：无法获取应用上下文')
        return
      }
      const dir: string = ctx.filesDir + '/export'
      try {
        fs.accessSync(dir)
      } catch (e) {
        fs.mkdirSync(dir, true)
      }
      const d: Date = AppClock.today()
      const tag: string = isToday
        ? '低碳日报_' + (d.getMonth() + 1) + '月' + d.getDate() + '日'
        : '低碳月报_' + currentMonth()
      const name: string = tag + '_' + d.getTime() + '.png'
      const path: string = dir + '/' + name
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, buf)
      fs.closeSync(file.fd)
      toast((isToday ? '今日数据图片已保存：' : '月报图片已保存：') + name)
    } catch (err) {
      toast('导出失败：预览器不支持截图，请在真机或模拟器上使用')
    } finally {
      this.exportingImg = false
      this.shotMode = 'month'
    }
  }

  private openMonthBill(): void {
    goWithParamStr(RouteName.MONTH_BILL, 'detailMonth', currentMonth())
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
        CfTopBar({
          title: '报表导出',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        if (this.ov === null || this.stats.length === 0) {
          Column() {
            CfEmpty({ icon: 'note', text: '暂无可导出的月报', sub: '先去记录几条低碳行为吧' })
          }
          .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              /*
               * 截图容器：exportImage() 通过 componentSnapshot.get('reportSnapshot')
               * 把「标题卡 + 三宫格 + 占比卡」整体渲染为一张 PNG。
               * ⚠️ 必须给出实底色（与页面同色）：组件树透明背景截出来是
               *    透明 PNG，压在深色查看器上不可读。
               */
              Column({ space: Space.LG }) {
                this.MonthHead()
                this.StatRow()
                this.CategoryBlock()
              }
              .width('100%')
              .backgroundColor(this.ecoBg())
              .id('reportSnapshot')
              this.ActionBlock()
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
    .hideTitleBar(true)
  }
@Builder
  MonthHead() {
    Row() {
      Column({ space: 3 }) {
        Text(this.shotMode === 'today' ? '低碳日报 · ' + todayStr() : '低碳月报 · ' + monthRange())
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text(this.shotMode === 'today' ? '统计口径：今日行为记录' : '统计口径：近 30 天行为记录')
          .fontSize(FontSize.CAPTION)
          .fontColor('rgba(255,255,255,0.88)')
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Stack({ alignContent: Alignment.Center }) {
        CfIcon({ kind: 'ui', code: 'note', iconSize: 30, color: '#FFFFFF' })
      }
      .width(52)
      .height(52)
      .backgroundColor('rgba(255,255,255,0.22)')
      .borderRadius(Radius.PILL)
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
          label: this.shotMode === 'today' ? '今日减排' : '本月减排',
          value: Biz.formatKg(this.shotMode === 'today' ? this.todayKg() : this.ov!.monthKg),
          icon: 'world',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: this.shotMode === 'today' ? '今日积分' : '获得积分',
          value: '' + Biz.pointsOf(this.shotMode === 'today' ? this.todayKg() : this.ov!.monthKg),
          icon: 'coin',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: this.shotMode === 'today' ? '今日条数' : '记录条数',
          value: '' + (this.shotMode === 'today' ? this.shotCount() : this.ov!.recordCount),
          icon: 'note',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  CategoryBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '四大类占比', more: '完整账单 ›', onMoreTap: (): void => this.openMonthBill() })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          // 键掺截图模式 + 动态数值：日报/月报切换时强制整组行重建，
          // 避免同分类键不变导致的复用残留（占比条冻结旧值）
          ForEach(this.activeStats(), (r: LocalRecord) => {
            this.CategoryRow(r)
          }, (r: LocalRecord): string => this.shotMode + '-' + r.category + '-' + r.reduceKg)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  CategoryRow(r: LocalRecord) {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: CategoryMeta.icon(r.category), iconSize: 20, tone: IconTone.ofCategory(r.category) })

      Column({ space: 6 }) {
        Row() {
          Text(CategoryMeta.label(r.category))
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Neutral.TEXT))
          Text(this.pctOf(r) + '%')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(CategoryMeta.color(r.category)))
          Blank()
          Text(Biz.formatKg(r.reduceKg))
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
        }
        .width('100%')

        // 占比条：宽度百分比先拼成字符串再传入
        CfProgress({
          percent: this.pctOf(r),
          color: this.tc(CategoryMeta.color(r.category)),
          barHeight: 7,
          track: this.tc(Neutral.SURFACE)
        })
        .width('100%')

        Text(Math.round(r.amount) + ' 次 · 约 ' + Biz.pointsOf(r.reduceKg) + ' 积分')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  ActionBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '导出报告' })

      // 报告预览卡：模拟导出内容摘要
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.SM }) {
          this.PreviewLine('报告周期', monthRange())
          this.PreviewLine('统计条数', this.totalCount() + ' 条行为记录')
          this.PreviewLine('合计减排', Biz.formatKg(this.totalKg()))
          this.PreviewLine('折算积分', Biz.pointsOf(this.totalKg()) + ' 积分')
          this.PreviewLine('折算树木', Biz.treesOf(Biz.pointsOf(this.totalKg())) + ' 棵')
        }
        .width('100%')
      }

      // 主按钮：今日数据日报图片（真实落盘）
      Row() {
        Text(this.exportingImg ? '正在生成图片…' : '保存今日数据为图片（PNG）')
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
          .enabled(!this.exportingImg)
          .onClick((): void => {
            this.exportImage('today')
          })
      }
      .width('100%')

      Row() {
        Text(this.exportingImg ? '正在生成图片…' : '保存月报为图片（PNG）')
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
          .enabled(!this.exportingImg)
          .onClick((): void => {
            this.exportImage('month')
          })
      }
      .width('100%')

      Row() {
        Text('导出月报（CSV）')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(44)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.PILL)
          .onClick((): void => this.exportReport())
      }
      .width('100%')

      Row() {
        Text('查看完整月度绿色账单')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(44)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.PILL)
          .onClick((): void => this.openMonthBill())
      }
      .width('100%')

      Text('图片真实保存到应用文件目录 export/ 下，截图瞬间页面会短暂切换为日报/月报视图')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }

  @Builder
  PreviewLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
      Blank()
      Text(value)
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
    }
    .width('100%')
  }
}
