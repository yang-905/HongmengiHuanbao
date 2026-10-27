import { toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalArticle, ArticleInteract } from '../../data/MockStore'
import {
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
import { CfBackIcon, CfCatBadge, CfEmpty, CfPill } from '../../ui/Components'
import { QuizSheet } from './QuizSheet'
import { ArticleCat, fmtRead } from './ArticleCat'
import { AppleMotion } from '../../ui/AppleMotion';
import { Clipboard } from '../../utils/Clipboard';

/** 路由参数：由 ArticleListPage 通过显式 class 传入 */
interface ArticleDetailParam {
  id: number
}

/**

 * P21 文章详情
 */
@Component
export struct ArticleDetailPage {
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
  @State private article: LocalArticle | null = null
  @State private loading: boolean = true
  @State private liked: boolean = false
  @State private faved: boolean = false
  @State private readCount: number = 0
  @State private likeCount: number = 0
  @State private showQuiz: boolean = false

  private articleId: number = -1

  aboutToAppear(): void {
    // 隐藏右下角「＋」悬浮球：本页底部有自己的点赞/收藏互动条，
    // ProfilePage 同款 AppStorage 标记模式）
    AppStorage.setOrCreate('hideFab', true)
    // 路由参数由 PageMap 经 AppStorage 传入（PageMap 已提供 NavDestination 容器）
    const id: number | undefined = AppStorage.get<number>('detailArticleId')
    if (id !== undefined && id !== null) {
      this.articleId = id
      AppStorage.delete('detailArticleId')
    }
    this.load()
  }

  aboutToDisappear(): void {
    // 离开本页恢复悬浮球（pop 返回列表、切账号清栈都会触发销毁）
    AppStorage.setOrCreate('hideFab', false)
  }

  private async load(): Promise<void> {
    if (this.articleId <= 0) return
    try {
      const list: LocalArticle[] = await DataSource.articles()
      for (let i: number = 0; i < list.length; i++) {
        if (list[i].articleId === this.articleId) {
          this.article = list[i]
          // 点赞/收藏从持久化互动状态恢复（用户诉求「保存记录」）：
          // likeCount 已由 DataSource 合并 likeDelta，布尔态直接读镜像
          const st: ArticleInteract = LocalStore.articleState(this.articleId)
          this.liked = st.liked
          this.faved = st.faved
          this.readCount = list[i].readCount
          this.likeCount = list[i].likeCount
          break
        }
      }
    } catch (err) {
      this.article = null
    }
  }
private paragraphs(): string[] {
    if (this.article === null) return []
    const out: string[] = []
    const raw: string[] = this.article.content.split('\n')
    for (let i: number = 0; i < raw.length; i++) {
      const t: string = raw[i].trim()
      if (t.length > 0) out.push(t)
    }
    return out
  }
private toggleLike(): void {
    this.liked = !this.liked
    this.likeCount = this.liked ? this.likeCount + 1 : Math.max(0, this.likeCount - 1)
    // 持久化互动增量（相对 MockStore 基准的 delta ±1）并广播 articleTick，
    // 列表页/收藏页自动刷新；本页状态手动维护，不依赖广播回读
    const st: ArticleInteract = LocalStore.articleState(this.articleId)
    const delta: number = st.likeDelta + (this.liked ? 1 : -1)
    LocalStore.setArticleState(this.articleId, this.liked, st.faved, delta)
    toast(this.liked ? '已点赞' : '已取消点赞')
  }

  private toggleFav(): void {
    this.faved = !this.faved
    const st: ArticleInteract = LocalStore.articleState(this.articleId)
    LocalStore.setArticleState(this.articleId, st.liked, this.faved, st.likeDelta)
    toast(this.faved ? '已加入收藏' : '已取消收藏')
  }

  /**

   * 分享：把文章标题 + 摘要组成分享文案写入**系统剪贴板**。
 */
  private share(): void {
    const a: LocalArticle | null = this.article
    if (a === null) {
      toast('文章加载中，稍后再试')
      return
    }
    const text: string = '【一触青绿】分享好文《' + a.title + '》：' + a.summary +
      '。一起来低碳生活，攒积分、种树！'
    if (Clipboard.copy(text)) {
      toast('分享文案已复制，去邀请朋友一起低碳吧')
    } else {
      toast('复制失败，请重试')
    }
  }

  private back(): void {
    AppRouter.pathStack.pop()
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

   * 页面入场动画状态（苹果口径，见下方最外层容器的 onAppear）。
   * 每次 push 进入本页都会重放到 0→1，观感是「内容错峰上浮」。
   */
  @State private pageIn: boolean = false
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisAppear 里清） */
  private pageInTimer: number = -1
  build() {
    /*
     * ⚠️ 根组件必须是 NavDestination（历史 bug，用户截图反馈「双碳科普子页面白屏」）：
     *   本页是全工程 23 个路由子页面中唯一一个根为裸 Column 的——
     *   pushPathByName 推入 Navigation 的内容必须是 NavDestination，
     *   否则 ArkUI 兜底生成一个**默认样式**的空 NavDestination：
     *   白底（非主题色）+ 系统默认圆形返回箭头 + 内容全空。
     *   修法与其余 22 个子页面口径一致：根包 NavDestination + hideTitleBar(true)，
     *   页面自绘 TopBar（返回逻辑走 AppRouter.pathStack.pop()）。
     */
    NavDestination() {
      Column() {
        this.TopBar()
        if (this.article === null) {
          Column() {
            CfEmpty({ icon: 'note', text: '文章不存在或已下架', sub: '返回列表看看其他科普' })
          }
          .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: Space.LG }) {
              this.ArticleHead()
              this.ArticleBody()
              this.QuizEntry()
            }
            .width('100%')
            .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.XL })
          }
          .scrollBar(BarState.Off)
          // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
          // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
          .edgeEffect(EdgeEffect.None)
          .width('100%')
          .layoutWeight(1)

          this.ActionBar()
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
      .bindSheet(this.showQuiz, this.QuizSheetContent(), {
        height: SheetSize.LARGE,
        dragBar: true,
        // 下滑关闭时系统不回写开关，需在消失时复位才能重复打开
        onDisappear: (): void => {
          this.showQuiz = false
        }
      })
    }
    // 系统默认标题栏关掉：页面自绘 TopBar（返回走 AppRouter.pathStack.pop()）。
    // 不关的话 NavDestination 会叠一条系统标题栏在自绘 TopBar 上面。
    .hideTitleBar(true)
  }
@Builder
  TopBar() {
    Row() {
      // 返回符用矢量箭头（CfBackIcon），不用字符 '‹'：
      // 字符走字体回退时可能不继承 fontColor → 深色下渲染成黑、看不见
      CfBackIcon({
        iconSize: 30,
        color: this.tc(Neutral.TEXT),
        onTap: (): void => this.back()
      })
      Text('文章详情')
        .fontSize(FontSize.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
      Blank()
      CfPill({ text: this.readMinutes() + ' 分钟读完', tone: 'muted' })
    }
    .width('100%')
    .height(52)
    .padding({ left: Space.PAGE, right: Space.PAGE })
    .backgroundColor(this.ecoBg())
    // 动态碳主题：背景随当日碳排放档位过渡（全局 AppStorage 驱动）
    // 液态玻璃：半透明底 + 实时高斯模糊，让下层内容（导航栈 / 底部玻璃条）
    // 真实透出并虚化。⚠️ 底色必须是半透明，纯色会把模糊完全盖住。
    .backdropBlur(EcoMood.blurOf(this.ecoLevel))
    // 上沿一道高光，模拟玻璃受光面（顶边更亮，视觉上「有厚度」）
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }

  private readMinutes(): number {
    return this.article === null ? 0 : this.article.readMinutes
  }
@Builder
  ArticleHead() {
    Column({ space: Space.MD }) {
      // 大图标
      Column() {
        CfIcon({ kind: 'article', code: '' + this.article!.articleId, iconSize: 44 })
      }
      .width(88)
      .height(88)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(ArticleCat.bg(this.article!.category))
      .borderRadius(Radius.XL)

      Text(this.article!.title)
        .fontSize(FontSize.DISPLAY)
        .maxFontScale(FontSize.SCALE_NUM)
        .maxLines(1)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .lineHeight(34)
        .width('100%')

      Text(this.article!.summary)
        .fontSize(FontSize.BODY)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .lineHeight(21)
        .width('100%')

      Row({ space: Space.SM }) {
        CfCatBadge({
          text: ArticleCat.label(this.article!.category),
          bg: ArticleCat.bg(this.article!.category),
          fg: ArticleCat.fg(this.article!.category)
        })
        Row({ space: 3 }) {
          CfIcon({ kind: 'ui', code: 'eye', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
          Text(fmtRead(this.readCount) + ' 阅读')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        Row({ space: 3 }) {
          CfIcon({ kind: 'ui', code: 'heart', iconSize: 12, color: this.tc(Neutral.TEXT_MUTED) })
          Text(fmtRead(this.likeCount))
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
      }
      .width('100%')
      .padding({ top: Space.SM })
      .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
    }
    .width('100%')
    .padding(Space.XL)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }
@Builder
  ArticleBody() {
    Column({ space: Space.LG }) {
      ForEach(this.paragraphs(), (p: string, i: number) => {
        Text(p)
          .fontSize(FontSize.TITLE)
          .fontColor(this.tc(Neutral.TEXT))
          .lineHeight(30)
          .width('100%')
      }, (p: string, i: number): string => 'p' + i)
    }
    .width('100%')
    .padding(Space.XL)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }
@Builder
  QuizEntry() {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: 'brain', iconSize: 26 })
      Column({ space: 3 }) {
        Text('读完测一测')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Text('3 道碳知识单选题，答对有积分奖励')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('去答题 ›')
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.LG)
    .onClick((): void => {
      this.showQuiz = true
    })
  }
@Builder
  ActionBar() {
    Row() {
      /*
       * ⚠️ 单元格必须是独立组件 + @Prop 传参，不能是 @Builder 按值传参：
       * @Builder 按值参数不随状态刷新（ArkUI 官方行为），
       * 组件化后父状态变化 → @Prop 同步 → 子组件立即重渲染。
       */
      ActionCellItem({
        icon: 'thumbup',
        label: '点赞',
        active: this.liked,
        value: '' + fmtRead(this.likeCount),
        onTap: (l: string): void => this.toggleLike()
      })
      ActionCellItem({
        icon: 'star',
        label: '收藏',
        active: this.faved,
        value: this.faved ? '已收藏' : '收藏',
        onTap: (l: string): void => this.toggleFav()
      })
      ActionCellItem({
        icon: 'arrowup',
        label: '分享',
        active: false,
        value: '好友',
        onTap: (l: string): void => this.share()
      })
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    .backgroundColor(this.tc(Neutral.CARD))
    .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
  }
}

/**

 * 底部互动条单元格（点赞/收藏/分享共用）。
 * 原为页面内 @Builder ActionCell 按值传参 —— 不随状态刷新，
 * 「点赞收藏不刷新」的根因；改独立组件 + @Prop 后点击即时变色变数。
 * 静态取色经 tc() 建立 themeTick 依赖（深色换血后强制重取）。
 */
@Component
struct ActionCellItem {
  /** 互动图标 code（IconMap 的 ui 表），原先是 emoji */
  @Prop icon: string = ''
  @Prop label: string = ''
  @Prop active: boolean = false
  @Prop value: string = ''
  onTap: (label: string) => void = (l: string): void => {}

  @StorageProp('themeTick') themeTick: number = 0
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** themeTick 恒读透传：静态色值参数经此包裹，换血后重建取色依赖 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  build() {
    Column({ space: 3 }) {
      CfIcon({
        kind: 'ui',
        code: this.icon,
        iconSize: 20,
        color: this.tc(this.active
          ? EcoTheme.primaryDeep(this.ecoLevel)
          : Neutral.TEXT_SUB)
      })
      Text(this.label)
        .fontSize(FontSize.CAPTION)
        .fontWeight(this.active ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.tc(this.active
          ? EcoTheme.primaryDeep(this.ecoLevel)
          : Neutral.TEXT_SUB))
      Text(this.value)
        .fontSize(10)
        .fontColor(this.tc(this.active
          ? EcoTheme.primaryDeep(this.ecoLevel)
          : Neutral.TEXT_MUTED))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    // themeTick 恒读钩子：驱动本组件在深色换血后重建
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .onClick((): void => this.onTap(this.label))
  }
}
