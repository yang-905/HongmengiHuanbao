import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParam } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalArticle } from '../../data/MockStore'
import {
  FontSize,
  Neutral,
  Radius,
  Space,
  EcoTheme,
  EcoMood,
  ThemePalette,
  IconTone,
} from '../../ui/Theme'
import { CfIcon } from '../../ui/Icon';
import { EcoMoodState } from '../../data/EcoMoodState'
import { LazySource } from '../../ui/LazyList'
import { CfCatBadge, CfEmpty, CfPill, CfSection } from '../../ui/Components';
import { GlassPanel, GlassPill } from '../../ui/GlassSurface';
import { GlassLight, GlassTier } from '../../ui/GlassLight';
import { QuizSheet } from './QuizSheet'
import { ArticleCat, fmtRead } from './ArticleCat'
import { AppleMotion } from '../../ui/AppleMotion';

/**

 * 详情页路由参数：ArkTS 严格模式下对象字面量必须对应显式类型，故声明 class
 */
class ArticleDetailParam {
  id: number = 0;

  constructor(i: number) {
    this.id = i;
  }
}

/** 科普分类筛选项 */
interface ArticleTab {
  key: string;
  name: string;
}

/**

 * 分类 chip 的选中态文字色（用户要求「选中后字体改为黑色」）。
 */
/**
 * 选中 chip 的文字色（**必须每次现取，不能用模块级 const**）。
 */
function chipActiveFg(): string {
  return '#1A1F1C';
}

/**

 * 分类栏每行放几个 chip。
 * ⚠️ 取 2 而非 3/4：4 个分类排 3 列时，第 4 个必然孤行；
 *   2×2 是唯一不留孤行、且每个 chip 都够宽放下四字标题的排法。
 */
const CHIP_PER_ROW: number = 2;

/** 文章卡条目空占位（@State 初值，进池复用前不会上屏） */
const EMPTY_ARTICLE: LocalArticle = {
  articleId: 0, title: '', category: '', icon: '', summary: '', content: '',
  readCount: 0, likeCount: 0, readMinutes: 0, isTop: false, favorite: false
};

/**

 * 文章卡条目（懒加载 + 回收复用）
 */
@Reusable
@Component
struct ArticleCardItem {
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

  /**

   * 文章数据（父组件 → 子组件单向同步）。
   * ⚠️ 必须是 @Prop 而不是 @State（同 RecordDayItem 2026-10-24 教训）：
   * @State 只在创建时拷一次初值，父侧 restSource.reload 后进不来
   * （key 用 articleId 时筛选切换能重建，但文章自身数据变更不会同步）。
   */
  @Prop article: LocalArticle = EMPTY_ARTICLE
  onOpen: (a: LocalArticle) => void = (a: LocalArticle): void => {}

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  aboutToReuse(params: ESObject): void {
    this.article = params.article as LocalArticle
    this.onOpen = params.onOpen as (a: LocalArticle) => void
  }

  build() {
    // 根节点必须是内置容器（ArkTS 限制）：GlassPanel 是自定义组件，
    // 不能直接做 build 根再挂属性链，故包一层 Column（单子节点，布局零影响）
    Column() {
      // 文章卡：统一光照玻璃卡（card 档：半透实底 + 零模糊，
      // 一屏十几张各一层离屏渲染会掉帧，透出的底色来自页面环境色）
      GlassPanel({
        tier: GlassTier.CARD,
        ambient: this.tc(EcoTheme.bg(this.ecoLevel)),
        corner: Radius.MD,
        pad: Space.MD,
        onTap: (): void => this.onOpen(this.article)
      }) {
        Row({ space: Space.MD }) {
          // 文章图标：按科普分类取浅底，外圈一道白色玻璃描边
          Column() {
            CfIcon({ kind: 'article', code: '' + this.article.articleId, iconSize: 22 })
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          /*
           * 图标底：分类色相保留，但**按碳情绪整体偏移**
           * 原写法固定取 `ArticleCat.bg(category)` —— 无论今天碳排如何，
           * 四类色标永远是一片薄荷/青/蓝/珊瑚的固定色；
           * 而页面底色已随档位变暖（ALERT 档底部那道橙光晕就是证据）。
           * 结果「背景在报警、色标还是绿的」，情绪表达被割裂。
           * 现走 EcoTheme.moodTint：保留分类色相（信息编码不丢），
           * 按档位向麦黄/珊瑚轻移，让整屏色调随碳排走。
           */
          .backgroundColor(this.tc(EcoTheme.moodTint(this.ecoLevel, ArticleCat.bg(this.article.category))))
          .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
          .borderRadius(Radius.MD)

          Column({ space: 5 }) {
            Text(this.article.title)
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.article.summary)
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .maxLines(2)
              .lineHeight(18)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Row({ space: Space.MD }) {
              CfCatBadge({
                text: ArticleCat.label(this.article.category),
                // 同样走 moodTint：分类色相保留，参与碳情绪表达
                bg: this.tc(EcoTheme.moodTint(this.ecoLevel, ArticleCat.bg(this.article.category))),
                fg: ArticleCat.fg(this.article.category)
              })
              Row({ space: 3 }) {
                CfIcon({ kind: 'ui', code: 'eye', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
                Text(fmtRead(this.article.readCount))
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
              }
              Row({ space: 3 }) {
                CfIcon({ kind: 'ui', code: 'heart', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
                Text(fmtRead(this.article.likeCount))
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
              }
              Blank()
              Row({ space: 3 }) {
                CfIcon({ kind: 'ui', code: 'clock', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
                Text(this.article.readMinutes + ' 分钟')
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
              }
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
    // themeTick 恒读钩子：静态色值换血后驱动本条目重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

/**

 * P05 双碳科普专栏（Tab3）
 * 真实实现：置顶大卡 + 分类 Tab（全部/双碳政策/基础概念/减碳技巧）+ 文章卡片流
 * 每张卡片：图标 / 标题 / 摘要 / 阅读数 / 点赞数 / 预计阅读时长
 * Tab 根内容，不进导航栈（由 Index 的 Tabs 承载）
 */
@Component
export struct ArticleListPage {
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
  @State private articles: LocalArticle[] = []
  /** 普通文章流懒加载数据源（替代原 ForEach(this.rest()) 急切构建） */
  private restSource: LazySource<LocalArticle> = new LazySource<LocalArticle>()
  @State private filter: string = 'all'
  @State private loading: boolean = true
  /** 小测验半模态面板可见性 */
  @State private showQuiz: boolean = false
  /**
   * 选中 chip 的回弹系数：选中瞬间放大到 1.08 再归位，
   * 由 pickFilter 里两段定时器驱动，像一颗水珠被按下去又弹起。
   */
  @State private chipPop: number = 1
  /**
   * 内容区的切换动画两件套（纯视觉）：
 */
  @State private contentAlpha: number = 1
  @State private contentShift: number = 0
  /** chip 回弹定时器 id，-1 表示未启动（纯视觉，可安全丢弃） */
  private popTimer: number = -1

  private scroller: Scroller = new Scroller()

  /** 筛选项：全部 + 三个科普分类 */
  private tabs: ArticleTab[] = [
    { key: ArticleCat.ALL, name: '全部' },
    { key: ArticleCat.POLICY, name: '双碳政策' },
    { key: ArticleCat.CONCEPT, name: '基础概念' },
    { key: ArticleCat.TIPS, name: '减碳技巧' }
  ]

  aboutToAppear(): void {
    this.load()
  }

  /**

   * 销毁前收尾：清掉 chip 回弹定时器。
   * 不清理的话，页面已销毁回调仍会跑，往失效组件的 @State 里写值属于无意义开销。
   */
  aboutToDisappear(): void {
    if (this.popTimer !== -1) {
      clearTimeout(this.popTimer)
      this.popTimer = -1
    }
    // 复位玻璃视差：清掉 80ms 心跳与 AppStorage 残余偏移，
    // 避免下次进入本页时玻璃高光带着上一次的偏移
    GlassLight.resetParallax()
  }

  private async load(): Promise<void> {
    try {
      this.articles = await DataSource.articles()
    } catch (err) {
      this.articles = []
    }
    this.syncRest()
  }
/** 当前筛选结果 */
  private filtered(): LocalArticle[] {
    if (this.filter === ArticleCat.ALL) {
      return this.articles
    }
    return this.articles.filter((a: LocalArticle): boolean => a.category === this.filter)
  }

  /** 置顶文章（特殊样式） */
  private pinned(): LocalArticle[] {
    return this.filtered().filter((a: LocalArticle): boolean => a.isTop)
  }

  /** 普通文章 */
  private rest(): LocalArticle[] {
    return this.filtered().filter((a: LocalArticle): boolean => !a.isTop)
  }

  /** 把当前筛选下的普通文章推进懒加载数据源（切分类/数据就绪时调用） */
  private syncRest(): void {
    this.restSource.reload(this.rest())
  }
/** 筛选项在 tabs 里的序号：决定内容切入方向（向后切从右进、向前切从左进） */
  private tabIndexOf(key: string): number {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].key === key) return i
    }
    return 0
  }

  /**

   * 切换分类：chip 弹一下 + 下方内容「淡出 → 换数据 → 淡入归位」。
 */
  private pickFilter(key: string): void {
    if (this.filter === key) return
    const from: number = this.tabIndexOf(this.filter)
    const to: number = this.tabIndexOf(key)
    const dir: number = to > from ? 1 : -1
    /*
     * ⚠️ 状态切换必须**同步且唯一**，绝不能藏进 setTimeout。
     *   历史 bug（用户两次截图反馈「点了减碳技巧却仍高亮全部」）：
     *   旧实现把 `this.filter = key` 放进 120ms 的 swapTimer 回调，
     *   而 FilterBar 是 List 的 ListItem，点 chip 会引发列表滚动/重建，
     *   aboutToDisappear 会 `clearTimeout(swapTimer)` → 定时器被清 →
     *   `this.filter` 永远停在旧值 → 点 chip 毫无反应。
     *   正确分工：**状态与数据同步是即时的、唯一的**，
     *   动画只是视觉表现，绝不能承担状态切换的职责。
     */
    // ① 同步切状态 + 换数据（唯一入口，不依赖任何定时器）
    this.filter = key
    this.syncRest()
    // ② 视觉层：从新状态淡入归位（animateTo 以「当前渲染态」为起点补间，
    //    不需要先淡出、不需要定时器，天然对连点免疫）
    this.contentAlpha = 0
    this.contentShift = dir * 14
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, (): void => {
      this.contentAlpha = 1
      this.contentShift = 0
    })
    // ③ 选中 chip 液态回弹
    if (this.popTimer !== -1) {
      clearTimeout(this.popTimer)
      this.popTimer = -1
    }
    this.chipPop = 1.08
    this.popTimer = setTimeout((): void => {
      this.chipPop = 1
      this.popTimer = -1
    }, 150)
  }

  private openDetail(a: LocalArticle): void {
    goWithParam(RouteName.ARTICLE_DETAIL, 'detailArticleId', a.articleId)
  }

  private openFavorite(): void {
    AppRouter.pathStack.pushPathByName(RouteName.FAVORITE_LIST, null)
  }

  private startQuiz(): void {
    this.showQuiz = true
  }

  @Builder
  QuizSheetContent() {
    QuizSheet({
      onClose: (): void => {
        this.showQuiz = false
      }
    })
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

   * 文章互动广播（详情页点赞/收藏、收藏页取消收藏都会 bump）。
   * 列表据此自动重拉：likeCount 已由 DataSource 合并点赞 delta，
   * 不刷新的话列表数字会停在旧值（用户诉求「自动刷新」）。
   */
  @StorageProp('articleTick') @Watch('onArticleTick') articleTick: number = 0

  onArticleTick(): void {
    this.load()
  }

  build() {
    /*
     * 胶囊看见下面的东西，记录/科普只能看见一层页面」）：
     * 旧结构 Header / FilterBar 固定在顶部、List 只占剩余空间，
     * 内容结束后胶囊后面永远是空白底色。
     * 现在头部两件套也进 List 滚动流（作为前两个 ListItem），
     * 列表从屏幕顶铺到屏幕底，滚动中卡片穿过底部胶囊后面，
     * backdropBlur 糊出来的是「活的内容」。分类切换动画（opacity/
     * translate）挂在 List 上，头部随内容一起切换，观感更整体。
     */
    Column() {
      if (this.filtered().length === 0) {
        this.Header()
        this.FilterBar()
        Column() {
          // 空态也坐一块玻璃面板，与文章流材质统一（走 GlassPanel 统一光照）
          GlassPanel({
            tier: GlassTier.CARD,
            ambient: this.ecoBg(),
            corner: Radius.LG,
            pad: Space.XL
          }) {
            CfEmpty({ icon: 'book', text: '该分类暂无文章', sub: '换个分类看看吧' })
          }
        }
        .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: Space.PAGE, right: Space.PAGE })
        // 与文章流共用同一套切换动画（pickFilter 驱动）
        .opacity(this.contentAlpha)
        .translate({ x: this.contentShift })
      } else {
        /*
         * 懒加载列表：List + LazyForEach + @Reusable 文章卡。
         * 头部两件套（Header / FilterBar）作为前两个 ListItem 进滚动流
         * （各自边距已内建）；List 自身只保留 left/right 与 bottom 96
         * （给底部胶囊让出滚动余量，最后一张卡能滚出胶囊）。
         */
        List({ scroller: this.scroller }) {
          // ⓪ 页面标题
          ListItem() {
            this.Header()
          }
          .width('100%')

          // ⓪ 分类筛选
          ListItem() {
            this.FilterBar()
          }
          .width('100%')

          // ① 置顶大卡块（固定内容，条目少保持急切构建）
          if (this.pinned().length > 0) {
            ListItem() {
              this.PinnedBlock()
            }
            .width('100%')
            .margin({ bottom: Space.LG })
          }
          // ② 文章流标题
          ListItem() {
            CfSection({ title: ArticleCat.label(this.filter) + '文章' })
          }
          .width('100%')
          .margin({ bottom: Space.MD })
          // ③ 文章卡流（懒加载 + 回收复用，见 ArticleCardItem）
          LazyForEach(this.restSource, (a: LocalArticle) => {
            ListItem() {
              ArticleCardItem({
                article: a,
                onOpen: (x: LocalArticle): void => this.openDetail(x)
              })
            }
            .width('100%')
            .margin({ bottom: Space.SM })
          }, (a: LocalArticle): string => a.articleId.toString())
          // ④ 测验入口
          ListItem() {
            this.QuizEntry()
          }
          .width('100%')
          .margin({ top: Space.LG })

          /*
           * ⚠️ 尾部占位 ListItem —— 滚动余量的正确放法。
           * 旧写法是 `.padding({ bottom: 68 })` 挂在 **List 自身**（滚动视口上），
           * 而首页/我的页是 `Scroll { Column().padding(bottom) }` —— padding 在子节点上。
           * 语义完全不同：
           *   · padding 挂子节点 → 撑出可滚动溢出区，内容能滚到屏幕最底边
           *   · padding 挂视口   → 视口被压短 68，内容**永远滚不进**胶囊区域
           * 所以科普页胶囊后面物理上没有内容，backdropBlur 采到的只有底色。
           * 现在底部余量交给尾随占位项，视口铺满全屏。
           */
          ListItem() {
            Column()
              .width('100%')
              .height(68)
          }
        }
        .width('100%')
        .height('100%')
        // ⚠️ 视口上**只留左右**内边距，不能挂 bottom（会把视口压短）。
        .padding({ left: Space.PAGE, right: Space.PAGE })
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .cachedCount(1)
        /*
         * List 视口显式透明，让根层深色实底透上来。
         * List 自带不透明默认底色，会把根层实底盖住，深色模式下整页发灰。
         */
        .backgroundColor(Color.Transparent)
        // 滚动视差：本帧滚动量喂给 GlassLight，玻璃面的高光随之平移
        // （80ms 节流 + 衰减归位，见 GlassLight.nudge）
        .onDidScroll((scrollOffset: number, scrollState: ScrollState): void => {
          GlassLight.nudge(scrollOffset)
        })
        // 分类切换动画：整块内容淡出换数据再淡入归位 + 同向轻移。
        // opacity/translate 不参与布局计算，动画期间主线程空闲。
        .opacity(this.contentAlpha)
        .translate({ x: this.contentShift })
      }
    }
    .width('100%')
    .height('100%')
    /*
     * 早前铺 62% 的 bg(ecoLevel)，但四档 bg 都是极浅粉彩
     * （NONE #F8F9F6 / WARN #FDFAED / GOOD #F7FBEC / ECO #F0FBF4，
     * 相差不足 10 个 RGB 点），62% 一盖，Index 根 Stack 的档位色
     * 径向光晕只剩 38% 透上来 —— 档位怎么切整页都像没变。
     * 看板/记录/我的三个 Tab 根节点都是**全透明**，档位变色由
     * Index 根层的 bgSolid 锚 + 档位色光晕直接承担，肉眼可见。
     * 本页对齐同一口径；List 视口自身已显式透明（见上），
     * 玻璃照常采样到根层实色与光晕，「环境纵深」不受影响。
     */
    .backgroundColor(Color.Transparent)
    // 动态碳主题：背景随当日碳排放档位过渡（全局 AppStorage 驱动）
    /*
     * 不再挂全屏 backdropBlur（原 EcoMood.blurOf）：
     * 一级 Tab 页根节点后方只有 Index 根层的实色底（同色系），
     * 模糊一个纯色 = 视觉零收益，却要常驻一张全屏离屏渲染层；
     * 子页面压住本页时的磨砂效果由子页面自己的根模糊负责，不受影响。
     * 与 Dashboard / RecordListPage 的处理保持一致。
     */
    // 上沿一道高光，模拟玻璃受光面（顶边更亮，视觉上「有厚度」）
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .bindSheet(this.showQuiz, this.QuizSheetContent(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // 下滑关闭时系统不回写开关，需在消失时复位才能重复打开
      onDisappear: (): void => {
        this.showQuiz = false
      }
    })
  }
@Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Text('双碳科普')
          .fontSize(FontSize.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Text(this.articles.length + ' 篇 · 读懂碳，才知道怎么减')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      // 收藏钮：玻璃胶囊（统一光照模型的未选中态，与分类 chip 同材质）
      GlassPill({
        ambient: this.ecoBg(),
        onTap: (): void => this.openFavorite()
      }) {
        Row({ space: 5 }) {
          CfIcon({ kind: 'ui', code: 'star', iconSize: 14 })
          Text('我的收藏')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.MD })
  }
/**
 * 分类栏：**竖排换行**（Flex wrap），不再是横向 Scroll。
 */
  @Builder
  FilterBar() {
    /*
     * ⚠️ FlexWrap.Wrap 的折行是**按 fit-content 硬塞**：4 个 chip 总宽超出
     *   容器时，第一行的项会被**压窄**而不是整体换到下一行 ——
     *   （注释里写的「每个 chip 都完整可见」在窄屏下并不成立。）
     * 按「每行 3 个」算出 cellW，每个 chip 占固定一格 —— 文字长短不再
     * 影响排版，也永远不会出现半截 chip。与记录页筛选栏 / 行为面板分类栏
     * 同一范式（全库统一）。
     */
    Column() {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        ForEach(this.tabs, (t: ArticleTab) => {
          /*
           * 玻璃形态与三段反馈（全部由 GlassPill 按左上 45° 光源渲染）：
           *   · 未选中 = 磨砂胶囊（半透底 + 轻模糊 + 四边异色描边
           *     + 对角光染 + 顶/左菲涅尔亮边）；
           *   · 选中 = 近白实底 + 近黑字，光照层减半（实底上 gloss 克制）。
           * 反馈三段（200ms EaseInOut，同帧开始同时结束）：
           *   ① 按下：整颗轻缩 95%（GlassPill 内部态）；
           *   ② 选中：放大到 1.08 再归位（chipPop 经 popScale 传入）；
           *   ③ 颜色：底色 / 文字 / 字重 / 边框色同步渐变。
           * ⚠️ 必须包一层 Column 承载 margin：GlassPill 是 fit-content 尺寸
           * （内部不设 width('100%')，横向排列时百分比宽会撑满整行），
           * 直接给自定义组件挂 margin 不可靠，外层容器是最稳的做法。
           * 外层不设背景/描边 —— 只做间距，视觉完全由内层药丸提供。
           */
          Column() {
            GlassPill({
              active: this.filter === t.key,
              /*
               * 选中底色：**品牌绿实底** —— activeBg 留空，GlassPill 内部
               * 现取 Brand.PRIMARY（每次构建重新求值，深色换血自动跟随，
               * 选中投影也经 shadowTintOf 自动带绿色光晕）。
               * 历史坑（三条叠加，本次用户截图反馈「选中只有字变粗」）：
               * ① 最早取 `EcoTheme.primaryDeep(level)` → `accent(level)`，
               *    而 `ecoLevel` 初值 'none' 对应的 `EcoMood.NONE_ACCENT`
               *    被定义成 `Neutral.TEXT_SUB`（#6B7A75 中灰绿）——
               *    选中态底根本不是品牌绿而是灰，白字压上去本就勉强。
               * ② 之后改为「近白玻璃底 rgba(255,255,255,0.92) + 近黑字」，
               *    但浅色奶油底上未选中的 chip 本就是白色玻璃胶囊 ——
               *    近白实底与未选中几乎无法区分，选中的唯一可感知变化
               *    只剩字重加粗，用户读作「点了没反应」。
               * ③ 结论：选中底必须与白色玻璃未选中态反差最大。
               *    EcoTheme.primary(this.ecoLevel)：GlassPill 的 activeBg
               *    已是 @Prop，档位一换新值进得来，选中底随档位走 ——
               *    none 灰绿 / warn 暖黄 / good 黄绿 / eco 荧光绿；
               *    文字走 chipActiveFg()（黑 + 加粗），四档底上均可读。
               */
              activeBg: this.tc(EcoTheme.primary(this.ecoLevel)),
              ambient: this.ecoBg(),
              // 撑满外层格宽：均分排版下由 cellW 决定宽度，
              // 不再由文字内容决定（那正是 chip 被裁的根因）
              fillWidth: true,
              popScale: this.filter === t.key ? this.chipPop : 1,
              onTap: (): void => this.pickFilter(t.key)
            }) {
              Row({ space: 5 }) {
                if (t.key !== ArticleCat.ALL) {
                  CfIcon({
                    kind: 'ui',
                    code: ArticleCat.icon(t.key),
                    iconSize: 12,
                    color: this.filter === t.key ? chipActiveFg() : this.tc(IconTone.color(IconTone.ofArticle(t.key)))
                  })
                }
                Text(t.name)
                  .fontSize(FontSize.SMALL)
                  // ⚠️ 均分格宽后必须锁 1 行：文字再长也只是省略号，
                  //   绝不允许把 chip 撑宽/挤窄（那正是本次被裁的根因）。
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontWeight(this.filter === t.key ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.filter === t.key ? chipActiveFg() : this.tc(Neutral.TEXT_SUB))
              }
              .padding({ left: 8, right: 8, top: 9, bottom: 9 })
              // 关键：内层内容撑满药丸格宽，文字才有确定的可用宽度
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            // 药丸宽度由 GlassPill 的 fillWidth 撑满本格
          }
          .width(this.chipCellW())
          /*
           * ⚠️ 间距**只加在非末列**（用户截图反馈 4 个 chip 竖成 4 行、
           *   每行只占一半宽度）。两处错叠加导致每行塞不下 2 个：
           *   ① `chipCellW()` 里已经扣掉了 `(PER_ROW-1) × 间隔`，
           *      若每个 chip 再无条件挂 `margin.right`，间距就被**扣两次**
           *      —— 实际占位 = cellW + 间隔 > 可用宽的一半 → 每行只放得下一个；
           *   ② 每行**末列**也挂了 margin，右边凭空多出一个空档。
           * 现改为按列位判断：只有非末列才加右间距。
           */
          .margin({
            right: this.chipCol(t.key) < CHIP_PER_ROW - 1 ? Space.SM : 0,
            bottom: Space.SM
          })
        }, (t: ArticleTab): string => t.key)
      }
      .width('100%')
    }
    .width('100%')
    // 实测容器宽度：格宽 = (容器宽 - 间隔) / 每行个数
    .onAreaChange((old: Area, area: Area): void => {
      this.onChipArea(area.width as number | string)
    })
    // 上下内边距由容器提供（Flex 自身无 padding 语义差异）
    .padding({ top: Space.MD, bottom: Space.XS })
  }

  /** 分类栏实测宽度（0 = 未就绪，先用经验值兜底） */
  @State private chipTrackW: number = 0

  /**

   * 单个 chip 的格宽。
   * ⚠️ 口径：这里扣掉的是**整行**的列间距总和 `(PER_ROW-1) × 间隔`，
   *   调用侧只给**非末列**加 `margin.right` —— 两者必须配套，
   *   否则间距会被扣两次（曾导致每行塞不下 2 个 chip）。
   */
  private chipCellW(): number {
    const track: number = this.chipTrackW > 0 ? this.chipTrackW : 300
    return (track - Space.SM * (CHIP_PER_ROW - 1)) / CHIP_PER_ROW
  }

  /** 某个 chip 在网格中的列位（0 起）—— 决定是否需要右间距 */
  private chipCol(key: string): number {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].key === key) return i % CHIP_PER_ROW
    }
    return 0
  }

  /** 记录分类栏容器宽度 */
  private onChipArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.chipTrackW) > 0.5) {
      this.chipTrackW = w
    }
  }
@Builder
  PinnedBlock() {
    if (this.pinned().length > 0) {
      Column({ space: Space.MD }) {
        CfSection({ title: '置顶推荐' })
        ForEach(this.pinned(), (a: LocalArticle) => {
          this.PinnedCard(a)
        }, (a: LocalArticle): string => 'pin' + a.articleId)
      }
      .width('100%')
    }
  }

  /**

   * 置顶大卡（Hero）：品牌渐变实底 + 统一玻璃光照。
   * 实底是为了撑住视觉层级与白字对比度，但受光面语言与玻璃卡一致 ——
   * 顶/左亮边、右下内阴影、右下投影，整页光源统一。
   */
  @Builder
  PinnedCard(a: LocalArticle) {
    GlassPanel({
      tier: GlassTier.CARD,
      ambient: this.ecoBg(),
      corner: Radius.XL,
      pad: Space.XL,
      bgGradient: {
        angle: 135,
        colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
      },
      shadowOverride: {
        radius: 20,
        color: this.tw(GlassLight.shadowTintOf(EcoTheme.primary(this.ecoLevel))),
        offsetX: 2,
        offsetY: 8
      },
      onTap: (): void => this.openDetail(a)
    }) {
      Column({ space: Space.MD }) {
        Row() {
          CfPill({ text: '置顶', tone: 'warning' })
          CfCatBadge({
            text: ArticleCat.label(a.category),
            bg: 'rgba(255,255,255,0.24)',
            fg: '#FFFFFF'
          })
          Blank()
          CfIcon({ kind: 'article', code: '' + a.articleId, iconSize: 26, color: '#FFFFFF' })
        }
        .width('100%')

        Text(a.title)
          .fontSize(FontSize.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .lineHeight(27)
          .width('100%')

        Text(a.summary)
          .fontSize(FontSize.SMALL)
          .fontColor('rgba(255,255,255,0.88)')
          .lineHeight(20)
          .width('100%')

        Row({ space: Space.LG }) {
          Row({ space: 3 }) {
            CfIcon({ kind: 'ui', code: 'eye', iconSize: 12, color: 'rgba(255,255,255,0.9)' })
            Text(fmtRead(a.readCount))
              .fontSize(FontSize.CAPTION)
              .fontColor('rgba(255,255,255,0.9)')
          }
          Row({ space: 3 }) {
            CfIcon({ kind: 'ui', code: 'heart', iconSize: 12, color: 'rgba(255,255,255,0.9)' })
            Text(fmtRead(a.likeCount))
              .fontSize(FontSize.CAPTION)
              .fontColor('rgba(255,255,255,0.9)')
          }
          Row({ space: 3 }) {
            CfIcon({ kind: 'ui', code: 'clock', iconSize: 12, color: 'rgba(255,255,255,0.9)' })
            Text(a.readMinutes + ' 分钟')
              .fontSize(FontSize.CAPTION)
              .fontColor('rgba(255,255,255,0.9)')
          }
          Blank()
          Text('去阅读 ›')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .padding({ top: Space.MD })
        .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.24)' })
      }
      .width('100%')
    }
  }
@Builder
  QuizEntry() {
    // 测验入口：与文章卡同材质同光源的玻璃卡
    GlassPanel({
      tier: GlassTier.CARD,
      ambient: this.ecoBg(),
      corner: Radius.LG,
      pad: Space.LG,
      onTap: (): void => this.startQuiz()
    }) {
      Row({ space: Space.MD }) {
        CfIcon({ kind: 'ui', code: 'brain', iconSize: 26 })
        Column({ space: 3 }) {
          Text('低碳小测验')
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
          Text('3 道题，检验一下你的碳知识')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('开始 ›')
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
      }
      .width('100%')
    }
  }
}
