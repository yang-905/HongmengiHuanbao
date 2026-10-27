import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParam } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalRecord } from '../../data/MockStore'
import { RecordSummary } from '../../data/rdb/CarbonRdb'
import { LazySource } from '../../ui/LazyList'
import { Accent, CategoryMeta, EcoMood, EcoTheme, FontSize, Glass, IconTone, Neutral, Radius, Shadow, Space, ThemePalette, isDarkMode } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { AccountStore } from '../../data/AccountStore'
import { AppClock } from '../../utils/AppClock'
import { CfCard, CfEmpty, CfGlassDisc, CfPill, CfStatTile } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * 详情页路由参数：ArkTS 严格模式下对象字面量必须对应显式类型，故声明 class
 */
class BehaviorDetailParam {
  id: number = 0;

  constructor(i: number) {
    this.id = i;
  }
}

/** 分类筛选项 */
interface FilterTab {
  key: string;
  name: string;
}

/** 按日分组后的结果集 */
interface DayGroup {
  date: string;
  label: string;
  kg: number;
  points: number;
  items: LocalRecord[];
}

/** 分组条目空占位（@State 初值，进池复用前不会上屏） */
const EMPTY_DAY_GROUP: DayGroup = {
  date: '', label: '', kg: 0, points: 0, items: []
};
/** 数字格式化：整数不带小数，否则保留两位 */
function fmtNum(n: number): string {
  const v: number = Math.round(n * 100) / 100
  if (Math.abs(v - Math.round(v)) < 0.001) {
    return '' + Math.round(v)
  }
  return v.toFixed(2)
}

/** 时分 */
function timeText(r: LocalRecord): string {
  if (r.behaviorTime.length >= 16) return r.behaviorTime.substring(11, 16)
  return ''
}

/** 来源药丸文案 */
function sourceText(r: LocalRecord): string {
  return r.recordSource === 'ai' ? 'AI识图' : '手动记录'
}

function sourceTone(r: LocalRecord): string {
  return r.recordSource === 'ai' ? 'info' : 'muted'
}

/**

 * 单日分组条目（懒加载 + 回收复用）
 */
@Reusable
@Component
struct RecordDayItem {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /**

   * 分组数据（父组件 → 子组件单向同步）。
 */
  @Prop group: DayGroup = EMPTY_DAY_GROUP
  /** 打开详情回调（由页面传入） */
  onOpen: (r: LocalRecord) => void = (r: LocalRecord): void => {}

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  aboutToReuse(params: ESObject): void {
    this.group = params.group as DayGroup
    this.onOpen = params.onOpen as (r: LocalRecord) => void
  }

  build() {
    Column({ space: Space.MD }) {
      Row() {
        Text(this.group.label)
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        CfPill({ text: this.group.items.length + ' 条', tone: 'muted' })
        Blank()
        Text('-' + fmtNum(this.group.kg) + ' kg · +' + this.group.points + ' 分')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
      }
      .width('100%')

      CfCard({ pad: Space.MD }) {
        Column({ space: 2 }) {
          // 组内行数通常个位数，保持 ForEach 急切构建（卡片是回收单位）
          ForEach(this.group.items, (r: LocalRecord) => {
            this.RecordRow(r)
          }, (r: LocalRecord): string => r.recordId.toString())
        }
        .width('100%')
      }
    }
    .width('100%')
    // themeTick 恒读钩子：静态色值换血后驱动本条目重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }

  @Builder
  RecordRow(r: LocalRecord) {
    Row({ space: Space.MD }) {
      // 行为图标：按大类取浅底
      Column() {
        CfIcon({ kind: 'factor', code: r.itemCode, iconSize: 20, tone: IconTone.ofCategory(r.category) })
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.tc(CategoryMeta.bg(r.category)))
      .borderRadius(Radius.SM)

      Column({ space: 4 }) {
        Row() {
          Text(r.itemName)
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          Text('+' + r.points + ' 分')
            .fontSize(FontSize.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Accent.SUCCESS))
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(fmtNum(r.amount) + ' ' + r.unit)
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text(timeText(r))
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          CfPill({ text: sourceText(r), tone: sourceTone(r) })
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('-' + fmtNum(r.reduceKg))
        .fontSize(FontSize.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
      Text('kg')
        .fontSize(10)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    .border({ width: { bottom: 1 }, color: this.tc(Neutral.BORDER) })
    .onClick((): void => this.onOpen(r))
  }
}

/**

 * P04 低碳记录（Tab2）
 */
@Component
export struct RecordListPage {
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

  @StorageProp('themeTick') @Watch('onThemeTick') themeTick: number = 0
  @State private records: LocalRecord[] = []
  /**
   * 分页游标与「还有更多」开关（2026-10-23 RDB 化）。
 */
  private pageOffset: number = 0
  @State private hasMore: boolean = false
  @State private loadingMore: boolean = false
  /**
   * 顶部合计的 SQL 聚合结果（全量口径）。
   * 与分页解耦：列表读一页，合计仍是全量筛选结果（见 rebuild 注释）。
   */
  @State private summaryKg: number = 0
  @State private summaryPoints: number = 0
  @State private summaryDays: number = 0
  /**
   * 筛选后的记录总条数（SQL COUNT 全量口径）。
 */
  @State private summaryCount: number = 0
  /** 分组懒加载数据源（替代原 @State groups 数组） */
  private groupsSource: LazySource<DayGroup> = new LazySource<DayGroup>()
  /**
   * 空态分支开关 + 天数响应式镜像。
 */
  @State private emptyView: boolean = true
  @State private dayCount: number = 0
  @State private filter: string = 'all'
  @State private loading: boolean = true
  /** 筛选后的合计（条数 / 减排 / 积分） */
  @State private sumKg: number = 0
  @State private sumPoints: number = 0
  /**
   * 换机型/换字号都不会错位（与 TrendChartPage.trackW 同思路）。
   */
  @State private filterTrackW: number = 0

  /** 筛选项：全部 + 四大类 */
  private tabs: FilterTab[] = [
    { key: 'all', name: '全部' },
    { key: CategoryMeta.TRAVEL, name: '出行' },
    { key: CategoryMeta.ENERGY, name: '节能' },
    { key: CategoryMeta.RECYCLE, name: '回收' },
    { key: CategoryMeta.FOOD, name: '饮食' }
  ]

  aboutToAppear(): void {
    this.load()
  }

  /**

   * 刷新时机有三个，任一满足即重新拉取：
 */
  onPageShow(): void {
    this.load()
  }

  /** 每页条数：首屏一页，记录涨到几千条也不拖慢首屏查询与构建 */
  private static readonly PAGE_SIZE: number = 50
  /** 加载代数：快速切筛选/连续刷新时丢弃过期页，避免旧页追加进新列表 */
  private loadSeq_: number = 0

  /**

   * 拉取记录（分页）。
   * reset=true 时清空已加载内容从第一页重读（首屏/切筛选/数据变更）；
   * reset=false 时追加下一页（「加载更多」）。
   */
  private async load(reset: boolean = true): Promise<void> {
    // 单机版：本地读取接近瞬时，不展示 loading 转圈，避免视觉闪烁
    const seq: number = ++this.loadSeq_
    if (reset) {
      this.pageOffset = 0
      this.records = []
      this.hasMore = false
    }
    try {
      const cat: string = this.filter === 'all' ? '' : this.filter
      const page: LocalRecord[] = await DataSource.recordsPage(cat, this.pageOffset, RecordListPage.PAGE_SIZE)
      // 已有更新的加载发起（切筛选/再次刷新）→ 丢弃本次过期页
      if (seq !== this.loadSeq_) return
      if (page.length > 0) {
        this.records = this.records.concat(page)
        this.pageOffset += page.length
        // 尾页不足一页即到底，隐藏「加载更多」
        this.hasMore = page.length >= RecordListPage.PAGE_SIZE
      }
      // 合计走全量聚合（与分页解耦，见 rebuild 注释）
      const sum: RecordSummary = await DataSource.recordsSummary(cat)
      if (seq !== this.loadSeq_) return
      this.summaryKg = sum.totalKg
      this.summaryPoints = sum.totalPoints
      this.summaryDays = sum.dayCount
      this.summaryCount = sum.recordCount
    } catch (err) {
      // 读取失败保持已有数据，不清空（避免存储抖动导致列表闪空）
      if (seq !== this.loadSeq_) return
    }
    this.rebuild()
  }

  /** 加载更多（尾部按钮点击） */
  private async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore) return
    this.loadingMore = true
    await this.load(false)
    this.loadingMore = false
  }

  /**

   * 按当前筛选条件重算分组。
 */
  private rebuild(): void {
    const src: LocalRecord[] = this.filter === 'all'
      ? this.records
      : this.records.filter((r: LocalRecord): boolean => r.category === this.filter)

    const out: DayGroup[] = []
    for (let i = 0; i < src.length; i++) {
      const r: LocalRecord = src[i]
      // 命中已有分组则追加，否则新建一组（各组 kg/points 按本组记录累加）
      let hit: DayGroup | null = null
      for (let g = 0; g < out.length; g++) {
        if (out[g].date === r.dateStr) {
          hit = out[g]
          break
        }
      }
      if (hit === null) {
        const ng: DayGroup = {
          date: r.dateStr,
          label: this.dateLabel(r.dateStr),
          kg: r.reduceKg,
          points: r.points,
          items: [r]
        }
        out.push(ng)
      } else {
        hit.kg = Math.round((hit.kg + r.reduceKg) * 1000) / 1000
        hit.points += r.points
        hit.items.push(r)
      }
    }
    // 走数据源 reload：LazyForEach 只重建可见条目，不可见的延迟到滚到位
    this.groupsSource.reload(out)
    // 同步维护响应式镜像：out.length 同时覆盖「无记录」与「筛选后无匹配」两种空态
    this.emptyView = out.length === 0
    // 合计读 SQL 聚合结果（全量口径，与分页解耦）
    this.dayCount = this.summaryDays
    this.sumKg = Math.round(this.summaryKg * 1000) / 1000
    this.sumPoints = this.summaryPoints
  }
private todayStr(): string {
    return AppClock.dateStr()
  }

  private offsetStr(days: number): string {
    return AppClock.fmtDate(AppClock.offsetDays(days))
  }

  /** 分组标题：今天 / 昨天 / M月D日 */
  private dateLabel(ds: string): string {
    if (ds === this.todayStr()) return '今天'
    if (ds === this.offsetStr(1)) return '昨天'
    return parseInt(ds.substring(5, 7)) + '月' + parseInt(ds.substring(8, 10)) + '日'
  }
private pickFilter(key: string): void {
    if (this.filter === key) return
    this.filter = key
    // 筛选条件下推 SQL：重置游标，从第一页重读
    this.load(true)
  }

  private openDetail(r: LocalRecord): void {
    goWithParam(RouteName.BEHAVIOR_DETAIL, 'detailRecordId', r.recordId)
  }

  private openManual(): void {
    AppStorage.set('showAddSheet', true)
    toast('请选择行为类型并填写数量')
  }

  private openAi(): void {
    AppRouter.pathStack.pushPathByName(RouteName.AI_RECOGNIZE, null)
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

  /**

   * 当前激活 Tab（Index 在点击/滑动切换时写入）。
   * （首页注释已确认），因此「回到记录页看最新数据」不能依赖 onPageShow，
   * 改由 activeTab 信号兜底：切回本页（index=1）立刻重拉。
   */
  @StorageLink('activeTab') @Watch('onActiveTab') activeTab: number = 0

  /**

   * ecoTick 变化的**真正**回调入口（@Watch 驱动）。
 */
  onEcoTick(): void {
    this.onStorageChange('ecoTick')
  }

  /**

   * 切回「记录」Tab 的刷新入口（@Watch 驱动，理由同 onEcoTick）。
   * activeTab 由 Index.applyActiveTab 写入（点击与滑动共用），
   * 这里只在本页被选中时重拉，兜住「页面常驻、切回来时数据已变」的场景。
   */
  onActiveTab(): void {
    this.onStorageChange('activeTab')
  }

  /**

   * 深色换血 → 强制懒列表全量重建。
 */
  onThemeTick(): void {
    this.rebuild()
  }

  onStorageChange(key: string): void {
    if (key === 'ecoTick') {
      // 数据真的变了（手动/AI 录入或删除）：即时重算档位 + 重拉列表
      EcoMoodState.refresh()
      this.load()
    } else if (key === 'activeTab' && this.activeTab === 1) {
      // 切回「记录」页：补 onPageShow 的不可靠，保证看到最新记录
      EcoMoodState.refresh()
      this.load()
    }
  }

  build() {
    /*
     * 记录/科普只能看见一层页面」）：
     * 旧结构是 Column { Header(固定) + Summary(固定) + FilterBar(固定) +
     *   List.layoutWeight(1) } —— 头部三件套钉死在顶部，列表只占剩余空间。
     * 看板是根节点直接一个全屏 Scroll，**所有内容都在滚动流里**，
     * 滚动中卡片能从底部胶囊后面穿过，backdropBlur 糊出来的是
     * 「活的内容」；而旧结构的记录页内容结束后，胶囊后面永远是
     * 空白底色 —— 这就是用户说的「只能看见一层页面」。
     * 现在头部三件套（Header / Summary / FilterBar）也进 List 滚动流：
     * 列表从屏幕顶铺到屏幕底，内容穿过胶囊后面，玻璃下有东西可看。
     * FilterBar 的 onAreaChange 只测宽度、与滚动无关，平移进 List 安全。
     */
    // ⚠️ 空态判断读 @State emptyView（由 rebuild() 维护），不能读
    // groupsSource.totalCount() —— 非响应式对象不会触发 if 分支重新求值
    if (this.emptyView) {
      // 空态：内容少，胶囊后面是什么无关紧要，保留固定头 + 居中空态
      Column() {
        this.Header()
        this.Summary()
        this.FilterBar()
        Column() {
          CfEmpty({ icon: 'inbox', text: '还没有低碳记录', sub: '点击下方 ＋ 记录你的第一笔绿色行为' })
          Row({ space: Space.MD }) {
            this.ActionCell('edit', '手动录入', false)
            this.ActionCell('camera', 'AI 识图', true)
          }
          .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
          .padding({ left: Space.XL, right: Space.XL })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      // ⚠️ 本轮改回**半透明 bg()（62%）**：根层实色锚已由 Index 根 Stack 的
      // bgSolid 提供（Navigation/Tabs 已显式透明），半透明底落上去不会再遇白；
      // 根层的径向环境光晕（EcoTheme.glow）透过这 38% 上来，
      // 玻璃条与卡片的模糊才有「环境纵深」可采样。
      .backgroundColor(this.tc(EcoTheme.bg(this.ecoLevel)))
      .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
      .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    } else {
      /*
       * 懒加载列表：List + LazyForEach + @Reusable 条目。
       * 头部三件套作为前三个 ListItem 进滚动流（各自的边距已内建）；
       * List 自身只保留 left/right（条目内容不带边距）与 bottom 96
       * （给底部胶囊让出滚动余量，最后一张卡能滚出胶囊）。
       */
      List() {
        ListItem() {
          this.Header()
        }
        .width('100%')

        ListItem() {
          this.Summary()
        }
        .width('100%')

        ListItem() {
          this.FilterBar()
        }
        .width('100%')

        LazyForEach(this.groupsSource, (g: DayGroup, index: number) => {
          ListItem() {
            RecordDayItem({
              group: g,
              onOpen: (r: LocalRecord): void => this.openDetail(r)
            })
          }
          .width('100%')
          .margin({ bottom: index === this.groupsSource.totalCount() - 1 ? 0 : Space.LG })
          /*
           * ⚠️ key 必须带**内容签名**（2026-10-24 筛选失效 bug 的第二道闸）：
           * 只用 g.date 做键时，切筛选后仍是「同一天」→ 同 key → ArkUI
           * 匹配到旧实例沿用；加上条数/积分/减排后，数据一变 key 就变，
           * 保证旧条目销毁、新条目按新数据重建（@Prop 同步之外的双保险）。
           */
        }, (g: DayGroup): string => g.date + '|' + g.items.length + '|' + g.points + '|' + Math.round(g.kg * 1000))

        /*
         * 「加载更多」尾项：RDB 分页的第二页入口。
         * 放在尾部占位项之前 —— 点它追加下一页，滚到底仍由占位项
         * 让最后一张卡能滚出胶囊（两个 ListItem 各司其职）。
         */
        if (this.hasMore) {
          ListItem() {
            Row({ space: Space.SM }) {
              Text(this.loadingMore ? '加载中…' : '加载更多')
                .fontSize(FontSize.BODY)
                .fontColor(this.tc(Neutral.TEXT_SUB))
            }
            .width('100%')
            .height(48)
            .justifyContent(FlexAlign.Center)
            .onClick((): void => {
              this.loadMore()
            })
          }
        }

        /*
         * ⚠️ 尾部占位 ListItem —— 这才是「滚动余量」的正确放法。
         * 旧写法把 `.padding({ bottom: 68 })` 挂在 **List 自身**（滚动视口上），
         * 而首页/我的页是 `Scroll { Column().padding(bottom) }` —— padding 在**子节点**上。
         * 两者语义完全不同：
         *   · padding 挂子节点 → 撑出可滚动溢出区，内容能一路滚到屏幕最底边
         *   · padding 挂视口   → 视口直接被压掉 68，内容**永远滚不进**胶囊区域
         * 这就是「看板能透过胶囊看见内容，记录/科普只能看见一层页面」的根因：
         * 不是玻璃不透明，是胶囊后面**物理上就没有内容可透**。
         * 现在底部余量改成尾随占位项，视口铺满全屏，内容从胶囊下面穿过。
         */
        ListItem() {
          Column()
            .width('100%')
            .height(68)
        }
      }
      .width('100%')
      .height('100%')
      // ⚠️ 这里**只留左右**内边距，绝不能再挂 bottom：
      // 挂到 List（滚动视口）上会把视口压短，让最后一段内容无法进入胶囊区域。
      // 底部余量由上面的尾部占位 ListItem 承担。
      .padding({ left: Space.PAGE, right: Space.PAGE })
      .scrollBar(BarState.Off)
      // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
      // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
      .edgeEffect(EdgeEffect.None)
      .cachedCount(1)
      /*
       * List 视口显式透明，让根层深色实底透上来。
       * 同一容器只能有一个 backgroundColor；以后改背景必须就地替换这一行。
       */
      .backgroundColor(Color.Transparent)
      // 上沿一道高光，模拟玻璃受光面（顶边更亮，视觉上「有厚度」）
      .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
      .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    }
  }
@Builder
  Header() {
    /*
     * 旧结构把标题+长副标题与两个按钮挤进同一行 —— 副标题带上
     * 「账号 xxx」后变长，列宽膨胀，Blank 被压没，相机圆盘被推出
     * 右缘只露半边。现在按钮上移到**标题行**（标题短，屏内放得下），
     * 长副标题独占第二行自由换行，两不抢占。
     */
    Column({ space: 3 }) {
      Row() {
        Text('低碳记录')
          .fontSize(FontSize.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Blank()
        // 手动录入：玻璃药丸（旧版为实色浅绿药珠）
        Row({ space: 5 }) {
          CfIcon({ kind: 'ui', code: 'edit', iconSize: 14 })
          Text('手动录入')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, '', 1)))
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT))
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
        .borderRadius(Radius.PILL)
        .onClick((): void => this.openManual())
        // AI 识图：玻璃圆盘（与手动录入同一材质）
        CfGlassDisc({ diameter: 38, onTap: (): void => this.openAi() }) {
          CfIcon({ kind: 'ui', code: 'camera', iconSize: 18 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      // 副标题带上当前账号：多账号数据隔离后，切了账号列表就是另一片命名空间，
      // 不标账号容易把「换号后为空」误判成「记录丢了」（账号变化必然整树重建，原地读即可）
      // 天数读响应式镜像 dayCount（rebuild 同步维护），同 emptyView 口径
      Text('共 ' + this.dayCount + ' 天 · 每 1 kg 减排 = 10 积分 · 账号 '
        + (AccountStore.currentUser().length > 0 ? AccountStore.currentUser() : '未登录'))
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
    }
    .width('100%')
    .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.MD })
  }
@Builder
  Summary() {
    Row({ space: Space.MD }) {
      /*
       * ⚠️ 每张 tile 必须包一层 `Column().layoutWeight(1)`，不能直接把
       * CfStatTile 放进 Row —— 那是「只显示一张 + 右侧多出一条边」的根因：
       * tile 自身是 width('100%')，三个直接放进 Row 会超出容器宽度，
       * 后两个被推出屏幕右侧只剩一条边。
       * ⚠️ 权重加在**这层 Column** 上、而不是加到 CfStatTile 里：
       * ArkUI 的 layoutWeight 按父容器主轴生效，本组件的通用用法是
       * `Row > Column(layoutWeight) > tile`。若把 layoutWeight 写进 tile，
       * 当它的父容器是 Column 时会被**纵向拉伸**，四宫格会塌成两条垂到底的
       * 色带（MinePage 即踩过这个坑）。权重必须留在包裹层。
       * 全库 10+ 处宫格都是这个写法，这里保持一致。
       */
      Column() {
        CfStatTile({
          label: '减排合计',
          value: fmtNum(this.sumKg) + ' kg',
          icon: 'world',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)

      Column() {
        CfStatTile({
          label: '获得积分',
          value: '' + this.sumPoints,
          icon: 'coin',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)

      Column() {
        CfStatTile({
          label: '记录条数',
          value: '' + this.summaryCount,
          icon: 'note',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: Space.PAGE, right: Space.PAGE })
  }
@Builder
  FilterBar() {
    // 与 TrendChartPage 的粒度切换同一套范式：轨道承载 + 滑动药丸 + 文字层。
    // 旧版是横向 Scroll 的实色药珠串，选中态各自一块实色；
    // 换成苹果 segmented control 式等宽分段：选中块是独立图层，
    // 用 translate 平移 + 实时背景模糊，滑动时玻璃是「活」的。
    Column() {
      Stack({ alignContent: Alignment.Start }) {
        /*
         * 轨道：**唯一的玻璃层**（单层范式）。
         * 宽高撑满父 Stack（父层 padding(3) 只作药丸活动余量），
         * 玻璃渐变 + 四边异色描边都只在这一层上，不再与外层重复。
         */
        Row()
          .width('100%')
          .height(36)
          .borderRadius(Radius.PILL)
          // 轨道底：玻璃染色层（半透），让下方页面能微微透上来
          .linearGradient(this.tw(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1)))
          // 四边异色：上/左受光边亮、下/右背光边深（统一 135° 光源），
          // 玻璃的「厚度」由这一组方向反差建立。
          .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

        // 选中药丸：随 filter 平移
        Row()
          .width(this.filterCellW())
          .height(36)
          // ⚠️ 报告问题②③「选中项要有顶部高光和底部内阴影，像一颗饱满玻璃胶囊」。
          // 原来是 angle 90（左→右）的均匀绿渐变 —— 横向染色在
          // 135° 主光源下等于「侧光」，凸不起来。
          // 改为 135° 左上亮 → 右下深：受光面在左上、背光面在右下，
          // 与全库玻璃同一条对角轴，视觉上是一颗凸起的水滴。
          .linearGradient({
            angle: 135,
            colors: [
              [this.tc(EcoTheme.heroMid(this.ecoLevel)), 0],
              [this.tc(EcoTheme.heroTo(this.ecoLevel)), 0.62],
              [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]
            ]
          })
          .borderRadius(Radius.PILL)
          // 顶部一道亮边：模拟凸透镜上缘接受主光源的镜面反射。
          // 品牌实底上不能套用白色 borderColors（会发脏），只提亮受光边。
          // ⚠️ 深色下 0.55 的白顶边实测把「全部」chip 推到 L≈250（环境仅 34），
          //    亮成一片惨白、盖过了碳情绪的薄荷身份。现深色收敛到 0.22/0.14：
          //    保留「上缘受光」的立体提示，但梯度回到与其它玻璃同一层级，
          //    药丸底色（EcoTheme.primary，碳情绪原色）保持不变。
          .border({
            width: 1,
            color: {
              top: this.td() ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.55)',
              left: this.td() ? 'rgba(255,255,255,0.14)' : 'rgba(255,255,255,0.38)',
              right: this.td() ? 'rgba(6,14,12,0.22)' : 'rgba(10,16,14,0.10)',
              bottom: this.td() ? 'rgba(6,14,12,0.30)' : 'rgba(10,16,14,0.16)'
            }
          })
          // 紧致投影：无偏移、小半径，只做「浮起一点」的层次，
          // 不会在轨道外缘留下彩色光晕（Shadow.brand 的教训）。
          // 不挂 backdropBlur、不加整体白描边：渐变底是不透明实色，
          // blur 被盖住只会白建离屏层、边缘渗出半透明晕。
          .shadow({ radius: 4, color: this.tc(EcoTheme.shadowColor(this.ecoLevel)), offsetX: 0, offsetY: 1 })
          .translate({ x: this.filterPillX() })
          // 弹簧感曲线：起步快、收尾带轻微回弹，模仿苹果 segmented control
          .animation({ duration: 320, curve: Curve.Friction })
          .hitTestBehavior(HitTestMode.None)

        // 文字层：承接点击（药丸是 HitTestMode.None 的装饰图层）
        Row() {
          ForEach(this.tabs, (t: FilterTab) => {
            this.FilterChip(t.key, t.name)
          }, (t: FilterTab): string => t.key)
        }
        .width('100%')
        .height(36)
      }
      .width('100%')
      .onAreaChange((old: Area, area: Area): void => {
        this.onFilterTrackArea(area.width as number | string)
      })
      /*
       * 原来的结构是两层玻璃套娃：
       *   外层 Stack → .linearGradient(surface(CARD_BG)) + .borderColors() + .shadow()
       *   └ 内层轨道 Row → .linearGradient(surface(SEGMENT_TRACK_BG)) + .borderColors()
       * 两层各带一套渐变与描边，外层 padding(3) 又让内层轨道缩进一圈，
       * 于是屏幕上出现「一个玻璃圆角框里又套一个玻璃圆角框」，
       * 两道描边叠在 3vp 的缝隙里互相加亮 → 视觉上就是双层壳。
       * 现改为**单层玻璃**：玻璃职责全部交给内层轨道（唯一一层渐变+描边），
       * 外层只做三件事：裁剪（clip 药丸溢出）、透明（不画任何底）、
       * BehaviorAddSheet 分类栏统一为同一范式。
       */
      .padding(3)
      .borderRadius(Radius.PILL)
      // clip 加在 Stack（轨道与药丸的共同父级）上：药丸是轨道的兄弟节点，
      // clip 加在轨道自身裁不到它；最右一档选中时投影会溢出轨道外缘
      .clip(true)
      .backgroundColor(Color.Transparent)
  }
    .width('100%')
    .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.XS })
  }

  @Builder
  FilterChip(key: string, name: string) {
    Text(name)
      .fontSize(FontSize.BODY)
      // 药丸高度写死 36，字号被系统放大就会溢出，这里钳住
      .maxFontScale(FontSize.SCALE_NUM)
      .fontWeight(this.filter === key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.filter === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .layoutWeight(1)
      .height(36)
      // 选中项轻微放大：苹果 segmented control 的标志性手感
      .scale({ x: this.filter === key ? 1.06 : 1, y: this.filter === key ? 1.06 : 1 })
      .animation({ duration: this.filter === key ? 260 : 200, curve: Curve.EaseOut })
      .onClick((): void => this.pickFilter(key))
  }

  /** 筛选栏单项宽度：药丸必须与文字槽位严格同宽，否则滑过去会错位。
   *  ⚠️ filterTrackW 是含 Stack 左右各 3vp 内边距的总宽，须扣 6vp。
   *  早期漏扣导致药丸每格宽 2vp，最右档溢出被 clip 裁成直边（圆角消失）。 */
  private filterCellW(): number {
    const track: number = this.filterTrackW > 0 ? this.filterTrackW : 300
    return (track - 6) / this.tabs.length
  }

  /** 筛选栏药丸位移 = 选中项序号 × 单项宽度 */
  private filterPillX(): number {
    return this.filterCellW() * this.filterIndex()
  }

  /** 当前筛选项下标；找不到时兜底 0 */
  private filterIndex(): number {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].key === this.filter) return i
    }
    return 0
  }

  /** 记录轨道实测宽度；百分比形式的 Length 直接忽略 */
  private onFilterTrackArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.filterTrackW) > 0.5) {
      this.filterTrackW = w
    }
  }
@Builder
  ActionCell(icon: string, label: string, goAi: boolean) {
    Column({ space: 5 }) {
      CfIcon({ kind: 'ui', code: icon, iconSize: 20 })
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
    .onClick((): void => {
      if (goAi) {
        this.openAi()
      } else {
        this.openManual()
      }
    })
  }
}
