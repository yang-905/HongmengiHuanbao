import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalPointsLog } from '../../data/MockStore'
import { LazySource } from '../../ui/LazyList'
import { Accent, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 流水类型筛选项 */
interface TypeTab {
  key: string;
  name: string;
}

/** 流水条目空占位（@State 初值，进池复用前不会上屏） */
const EMPTY_LOG: LocalPointsLog = {
  logId: 0, changeType: '', points: 0, balanceAfter: 0, remark: '', createTime: ''
};
/** 类型文案 */
function typeText(t: string): string {
  if (t === 'earn') return '获得'
  if (t === 'task') return '任务'
  if (t === 'exchange') return '兑换'
  if (t === 'rollback') return '回滚'
  return '其他'
}

/** 类型药丸色调 */
function typeTone(t: string): string {
  if (t === 'earn') return 'success'
  if (t === 'task') return 'info'
  if (t === 'exchange') return 'warning'
  if (t === 'rollback') return 'danger'
  return 'muted'
}

/** 类型图标 */
/**
 * 历史流水的备注里带着旧版 emoji 因子图标（如「🚶 步行出行」）。
 * 图标已改由左侧 CfIcon 表达，这里剥掉行首的非文字字符，
 * 避免老数据在新界面上出现一枚彩色 emoji。
 */
function plainRemark(s: string): string {
  let i: number = 0
  while (i < s.length) {
    const cp: number = s.codePointAt(i) as number
    const isText: boolean = (cp >= 0x4E00 && cp <= 0x9FFF) ||
      (cp >= 0x30 && cp <= 0x7A) || (cp >= 0x3000 && cp <= 0x303F)
    if (isText) break
    i += cp > 0xFFFF ? 2 : 1
  }
  return s.substring(i)
}

/** 类型图标 code（IconMap 的 ui 表），原先是 emoji */
function typeIcon(t: string): string {
  if (t === 'earn') return 'sprout'
  if (t === 'task') return 'target'
  if (t === 'exchange') return 'gift'
  if (t === 'rollback') return 'refresh'
  return 'coin'
}

/**

 * 变动额文案：正数带 + 绿色，负数带 − 红色
 * 注意负号用 Unicode − 以便与 + 对齐
 */
function deltaText(l: LocalPointsLog): string {
  if (l.points > 0) return '+' + l.points
  if (l.points < 0) return '−' + (-l.points)
  return '0'
}

/** 时间文案：MM-DD HH:mm */
function timeText(l: LocalPointsLog): string {
  const s: string = l.createTime
  if (s.length < 16) return s
  return s.substring(5, 16)
}

/**

 * 单条流水条目（懒加载 + 回收复用）
 */
@Reusable
@Component
struct PointsLogItem {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值经 tc 取值即建立 themeTick 依赖，换肤广播后强制重取 static 新色。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /**

   * 条目数据（父组件 → 子组件单向同步）。
   * ⚠️ 必须是 @Prop 而不是 @State（同 RecordDayItem 2026-10-24 教训）：
   * @State 只在创建时拷一次初值，父侧 logsSource.reload 后进不来。
   */
  @Prop log: LocalPointsLog = EMPTY_LOG
  /** 点击回调（由页面传入） */
  onTap: (l: LocalPointsLog) => void = (l: LocalPointsLog): void => {}

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  aboutToReuse(params: ESObject): void {
    this.log = params.log as LocalPointsLog
    this.onTap = params.onTap as (l: LocalPointsLog) => void
  }

  /** 类型底色（依赖主题注入，留在组件内） */
  private typeTint(t: string): string {
    if (t === 'earn') return this.tc(Accent.SUCCESS_BG)
    if (t === 'task') return this.tc(Accent.INFO_BG)
    if (t === 'exchange') return this.tc(Accent.WARNING_BG)
    if (t === 'rollback') return this.tc(Accent.DANGER_BG)
    return this.tc(EcoTheme.primaryPale(this.ecoLevel))
  }

  /** 变动额颜色 */
  private deltaColor(l: LocalPointsLog): string {
    if (l.points > 0) return this.tc(Accent.SUCCESS)
    if (l.points < 0) return this.tc(Accent.DANGER)
    return this.tc(Neutral.TEXT_MUTED)
  }

  build() {
    // 原 LogRow 的 UI 原样搬入（视觉不变，取色口径 tc() 一致）
    Row({ space: Space.MD }) {
      // 类型图标
      Stack({ alignContent: Alignment.Center }) {
        CfIcon({ kind: 'ui', code: typeIcon(this.log.changeType), iconSize: 18 })
      }
      .width(38)
      .height(38)
      .backgroundColor(this.typeTint(this.log.changeType))
      .borderRadius(Radius.SM)

      Column({ space: 4 }) {
        Row() {
          Text(plainRemark(this.log.remark))
            .fontSize(FontSize.BODY)
            .fontColor(this.tc(Neutral.TEXT))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          CfPill({ text: typeText(this.log.changeType), tone: typeTone(this.log.changeType) })
        }
        .width('100%')
        Row() {
          Text(timeText(this.log))
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          Text('余额 ' + this.log.balanceAfter)
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .margin({ left: Space.MD })
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 变动额：右对齐
      Text(deltaText(this.log))
        .fontSize(FontSize.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.deltaColor(this.log))
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    .border({ width: { bottom: 1 }, color: this.tc(Neutral.BORDER) })
    .onClick((): void => this.onTap(this.log))
    // themeTick 恒读钩子：静态色值换血后驱动本条目重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/**

 * P14 积分明细（流水）
 */
@Component
export struct PointsRecordPage {
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

  @StorageProp('themeTick') @Watch('onThemeTick') themeTick: number = 0
  @State private logs: LocalPointsLog[] = []
  /** 流水懒加载数据源（替代原 ForEach(this.view()) 急切构建） */
  private logsSource: LazySource<LocalPointsLog> = new LazySource<LocalPointsLog>()
  /**
   * 当前筛选结果（@State 镜像）。
 */
  @State private filtered: LocalPointsLog[] = []
  @State private filter: string = 'all'
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  private tabs: TypeTab[] = [
    { key: 'all', name: '全部' },
    { key: 'earn', name: '获得' },
    { key: 'task', name: '任务' },
    { key: 'exchange', name: '兑换' },
    { key: 'rollback', name: '回滚' }
  ]

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.logs = await DataSource.pointsLogs()
    } catch (err) {
      this.logs = []
    }
    this.rebuild()
  }

  /** 按当前筛选重算流水视图：同步懒加载数据源与空态镜像 */
  private rebuild(): void {
    const out: LocalPointsLog[] = this.filter === 'all'
      ? this.logs
      : this.logs.filter((l: LocalPointsLog): boolean => l.changeType === this.filter)
    // 走数据源 reload：LazyForEach 只重建可见条目，不可见的延迟到滚到位
    this.logsSource.reload(out)
    this.filtered = out
  }
/** 当前余额（列表首条即最新） */
  private balance(): number {
    if (this.logs.length === 0) return 0
    return this.logs[0].balanceAfter
  }

  /** 累计获得（正数之和） */
  private earned(): number {
    let s: number = 0
    for (let i = 0; i < this.logs.length; i++) {
      if (this.logs[i].points > 0) s += this.logs[i].points
    }
    return s
  }

  /** 累计兑换（负数绝对值之和） */
  private spent(): number {
    let s: number = 0
    for (let i = 0; i < this.logs.length; i++) {
      if (this.logs[i].points < 0) s += -this.logs[i].points
    }
    return s
  }

  private pickTab(key: string): void {
    this.filter = key
    this.rebuild()
  }

  private tapLog(l: LocalPointsLog): void {
    toast(typeText(l.changeType) + ' ' + deltaText(l) + ' 分 · 余额 ' + l.balanceAfter)
  }

  private openTask(): void {
    AppRouter.pathStack.pushPathByName(RouteName.TASK_CENTER, null)
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

  /**

   * 深色换血 → 强制懒列表全量重建。
   * ⚠️ @Reusable 条目在复用池里收不到 themeTick 广播，复用回树也不重走
   *   build → 换血后池内条目停浅色套值（同 RecordListPage.onThemeTick）。
   *   rebuild() 内部 logsSource.reload(out) 强制 LazyForEach 按新键重建。
   */
  onThemeTick(): void {
    this.rebuild()
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
          title: '积分明细',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        /*
         * 懒加载列表：List + LazyForEach + @Reusable 条目（对齐 RecordListPage）。
         * 汇总卡与类型筛选作为前两个 ListItem 进滚动流；
         * 流水随记录增长到几百条时只有可见条目会被创建，
         * 滚出屏幕的进回收池复用，不再整页急切构建。
         */
        List({ scroller: this.scroller }) {
          ListItem() {
            this.SummaryCard()
          }
          .width('100%')
          .margin({ bottom: Space.LG })

          ListItem() {
            this.TabBar()
          }
          .width('100%')
          .margin({ bottom: Space.LG })

          // ⚠️ 空态判断读 @State filtered（由 rebuild() 维护），不能读
          // logsSource.totalCount() —— 非响应式对象不会触发 if 分支重新求值
          if (this.filtered.length === 0) {
            ListItem() {
              CfCard({}) {
                CfEmpty({ icon: 'receipt', text: '暂无积分流水', sub: '完成低碳任务或兑换权益后即可看到记录' })
              }
            }
            .width('100%')
          } else {
            ListItem() {
              CfSection({ title: '流水明细', more: '赚积分 ›', onMoreTap: (): void => this.openTask() })
            }
            .width('100%')
            .margin({ bottom: Space.SM })

            LazyForEach(this.logsSource, (l: LocalPointsLog) => {
              ListItem() {
                PointsLogItem({
                  log: l,
                  onTap: (x: LocalPointsLog): void => this.tapLog(x)
                })
              }
              .width('100%')
            }, (l: LocalPointsLog): string => l.logId.toString())
          }

          /*
           * 尾部占位 ListItem —— 滚动余量的正确放法（对齐 RecordListPage）：
           * padding 挂 List（滚动视口）会把视口压短，内容永远滚不进底部；
           * 底部余量交给尾随占位项，视口铺满剩余空间。
           */
          ListItem() {
            Column()
              .width('100%')
              .height(30)
          }
        }
        .width('100%')
        .layoutWeight(1)
        // ⚠️ 视口上只留左右内边距（原 Scroll 子 Column 的水平边距），
        // 不能挂 bottom（会把视口压短），底部余量由尾部占位 ListItem 承担。
        .padding({ left: Space.PAGE, right: Space.PAGE })
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .cachedCount(1)
        // List 自带不透明视口底，必须显式透明，否则盖住根层档色
        //（同款问题与修法详见 RecordListPage 的 backgroundColor 注释）
        .backgroundColor(Color.Transparent)
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
  SummaryCard() {
    Column({ space: Space.MD }) {
      Column({ space: 4 }) {
        Text('当前可用积分')
          .fontSize(FontSize.SMALL)
          .fontColor('rgba(255,255,255,0.85)')
        Row({ space: 4 }) {
          Text('' + this.balance())
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
        Text('流水只追加不修改，每条均带余额快照')
          .fontSize(FontSize.SMALL)
          .fontColor('rgba(255,255,255,0.85)')
      }
      .alignItems(HorizontalAlign.Start)
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
@Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '累计获得',
          value: '+' + this.earned(),
          icon: 'up',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '累计兑换',
          value: '−' + this.spent(),
          icon: 'gift',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '流水条数',
          value: '' + this.logs.length,
          icon: 'receipt',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  TabBar() {
    Column({ space: Space.MD }) {
      Scroll() {
        Row({ space: Space.SM }) {
          ForEach(this.tabs, (t: TypeTab) => {
            Text(t.name)
              .fontSize(FontSize.SMALL)
              .fontWeight(this.filter === t.key ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.filter === t.key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor(this.filter === t.key ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.CARD))
              .borderRadius(Radius.PILL)
              .shadow(this.filter === t.key ? this.tw(Shadow.brand()) : this.tw(Shadow.card()))
              .onClick((): void => this.pickTab(t.key))
          }, (t: TypeTab): string => t.key)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
      // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      this.StatRow()
    }
    .width('100%')
  }
}
