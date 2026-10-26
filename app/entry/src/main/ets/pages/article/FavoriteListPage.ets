import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParam } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalArticle } from '../../data/MockStore'
import {
  Accent,
  FontSize,
  Neutral,
  Radius,
  Shadow,
  Space,
  EcoTheme,
  EcoMood,
} from '../../ui/Theme'
import { CfIcon } from '../../ui/Icon';
import { EcoMoodState } from '../../data/EcoMoodState'
import { LocalStore } from '../../data/LocalStore'
import { CfCatBadge, CfEmpty, CfSection, CfTopBar } from '../../ui/Components'
import { ArticleCat, fmtRead } from './ArticleCat'
import { AppleMotion } from '../../ui/AppleMotion';

/**
 * 详情页路由参数：ArkTS 严格模式禁止无类型对象字面量
 */
class ArticleDetailParam {
  id: number = 0;

  constructor(i: number) {
    this.id = i;
  }
}

/**
 * P22 我的收藏
 * ------------------------------------------------------------------
 * 真实实现：收藏文章卡片流（样式对齐 ArticleListPage）+ 一键取消收藏
 * 取消后即时从列表移除并给出 toast 反馈
 * 路由名：FAVORITE_LIST（NavDestination，PageMap 集中注册）
 */
@Component
export struct FavoriteListPage {
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
  @State private all: LocalArticle[] = []
  @State private favs: LocalArticle[] = []
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.all = await DataSource.articles()
    } catch (err) {
      this.all = []
    }
    this.rebuild()
  }

  /** 依据收藏状态重算列表。
   *  收藏集合存 @State 而非每次 filter：
   *  build 里要读它三次（空态判断 / 计数 / 列表），
   *  每次 filter 都新建数组会让三次读到三个不同引用，
   *  触发多余的差异比对与列表重建。 */
  private rebuild(): void {
    const favs: LocalArticle[] = []
    for (let i: number = 0; i < this.all.length; i++) {
      if (this.all[i].favorite) favs.push(this.all[i])
    }
    this.favs = favs
  }

  /** 收藏列表 */
  private favList(): LocalArticle[] {
    return this.favs
  }

  /* ---------- 交互 ---------- */

  private openDetail(a: LocalArticle): void {
    goWithParam(RouteName.ARTICLE_DETAIL, 'detailArticleId', a.articleId)
  }

  /** 取消收藏：就地更新并重算列表 */
  private removeFav(a: LocalArticle): void {
    // 持久化取消收藏（LocalStore 互动镜像）—— 否则重进页面/重启后
    // MockStore 静态 favorite 又把文章顶回来（用户诉求「保存记录」）
    const st = LocalStore.articleState(a.articleId)
    LocalStore.setArticleState(a.articleId, st.liked, false, st.likeDelta)
    for (let i: number = 0; i < this.all.length; i++) {
      if (this.all[i].articleId === a.articleId) {
        this.all[i].favorite = false
        break
      }
    }
    // 触发响应式：整体替换数组引用
    const next: LocalArticle[] = []
    for (let i: number = 0; i < this.all.length; i++) {
      next.push(this.all[i])
    }
    this.all = next
    this.rebuild()
    toast('已取消收藏《' + a.title + '》')
  }

  private back(): void {
    AppRouter.pathStack.pop()
  }

  private goList(): void {
    AppRouter.pathStack.pop()
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
   * 文章互动广播（详情页点赞/收藏、本页取消收藏都会 bump）。
   * 收藏列表据此自动重拉 —— 用户在详情页点了收藏，进本页立即看到。
   */
  @StorageProp('articleTick') @Watch('onArticleTick') articleTick: number = 0

  onArticleTick(): void {
    this.load()
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
          title: '我的收藏',
          onBack: (): void => this.back()
        })
        if (this.favList().length === 0) {
          Column() {
            CfEmpty({ icon: 'star', text: '还没有收藏文章', sub: '在科普列表点开文章即可收藏' })
            Row() {
              Text('去逛科普列表')
                .fontSize(FontSize.BODY).opacity(this.themeTick >= 0 ? 1 : 0)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .width('100%')
                .textAlign(TextAlign.Center)
                .height(42)
                .linearGradient({
                  angle: 90,
                  colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
                })
                .borderRadius(Radius.PILL)
                .onClick((): void => this.goList())
            }
            .width('100%')
            .padding({ left: 64, right: 64 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.SummaryBar()
              this.ListBlock()
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

  /* ---------- 顶部统计条 ---------- */
  @Builder
  SummaryBar() {
    Row() {
      Text('已收藏 ' + this.favList().length + ' 篇')
        .fontSize(FontSize.BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
      Blank()
      Text('随时回看，知识点不迷路')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.MD)
  }

  /* ---------- 收藏列表 ---------- */
  @Builder
  ListBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '收藏的文章' })
      Column({ space: Space.SM }) {
        ForEach(this.favList(), (a: LocalArticle) => {
          this.FavCard(a)
        }, (a: LocalArticle): string => a.articleId.toString())
      }
    }
    .width('100%')
  }

  @Builder
  FavCard(a: LocalArticle) {
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        // 图标：点击进详情
        Column() {
          CfIcon({ kind: 'article', code: '' + a.articleId, iconSize: 22 })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ArticleCat.bg(a.category))
        .borderRadius(Radius.MD)

        Column({ space: 5 }) {
          Text(a.title)
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(a.summary)
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .maxLines(2)
            .lineHeight(18)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: Space.MD }) {
            CfCatBadge({
              text: ArticleCat.label(a.category),
              bg: ArticleCat.bg(a.category),
              fg: ArticleCat.fg(a.category)
            })
            Row({ space: 3 }) {
              CfIcon({ kind: 'ui', code: 'eye', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
              Text(fmtRead(a.readCount))
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            Row({ space: 3 }) {
              CfIcon({ kind: 'ui', code: 'clock', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
              Text(a.readMinutes + ' 分钟')
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
      .onClick((): void => this.openDetail(a))

      // 底部操作条
      Row() {
        Text('查看全文 ›')
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .onClick((): void => this.openDetail(a))
        Blank()
        Row({ space: 5 }) {
          CfIcon({ kind: 'ui', code: 'trash', iconSize: 12 })
          Text('取消收藏')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Accent.DANGER))
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.tc(Accent.DANGER_BG))
        .borderRadius(Radius.PILL)
        .onClick((): void => this.removeFav(a))
      }
      .width('100%')
      .padding({ top: Space.MD })
      .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
  }
}
