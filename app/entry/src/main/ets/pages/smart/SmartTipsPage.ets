import { AppRouter } from '../../common/router/AppRouter';
import { DataSource } from '../../net/DataSource'
import { LocalFocusTask, LocalSmartTip } from '../../data/MockStore'
import { FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfSection, CfTopBar } from '../../ui/Components'
import { toast } from '../../ui/Toast'
import { AppleMotion } from '../../ui/AppleMotion';
import { Clipboard } from '../../utils/Clipboard';
import { CfIcon } from '../../ui/Icon';

/**

 * P31 智慧服务 · 建议中心
 * 展示今日重点任务与个性化生活建议（最多 3 条）
 */
@Component
export struct SmartTipsPage {
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
  @State private focus: LocalFocusTask | null = null
  @State private tips: LocalSmartTip[] = []
  @State private loading: boolean = true
  /**
   * 分享成绩单文案（2026-10-23 起异步载入：统计改由 RDB 聚合查询得出，
   * DataSource.shareText() 随之改异步，build 里不能再同步调用）。
   * 入屏时随 load() 一并拉取；复制按钮现场再取一次最新值。
   */
  @State private shareText: string = ''

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.focus = await DataSource.focusTask()
    this.tips = await DataSource.smartTips()
    this.shareText = await DataSource.shareText()
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
          title: '智慧建议',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            if (this.focus !== null) {
              this.FocusBlock()
            }
            this.TipBlock()
            this.ShareBlock()
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
        .width('100%')
        .height('100%')
        // 页面底色必须铺满含顶栏的整列：顶栏区域无人上色时，
        // NavDestination 默认白底透出来 = 深色模式顶部「白额头」，
        // 白色顶栏文字压白底直接隐形（同设置页修复口径）
        .backgroundColor(this.ecoBg())
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

  @Builder
  FocusBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '今日重点任务' })
      Column({ space: Space.SM }) {
        Row({ space: Space.MD }) {
          CfIcon({ kind: 'task', code: this.focus!.taskCode, iconSize: 30 })
          Column({ space: 4 }) {
            Text(this.focus!.title)
              .fontSize(FontSize.HEADING)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
            Text(this.focus!.desc)
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .lineHeight(19)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Text('推荐任务')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          Blank()
          CfPill({ text: this.focus!.taskCode, tone: 'info' })
        }
        .width('100%')
        .padding({ top: Space.MD })
        .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
      }
      .width('100%')
      .padding(Space.XL)
      .backgroundColor(this.tc(Neutral.CARD))
      .borderRadius(Radius.LG)
      .shadow(this.tw(Shadow.card()))
    }
    .width('100%')
  }

  @Builder
  TipBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '生活建议' })
      if (this.tips.length === 0) {
        CfCard({}) {
          CfEmpty({ icon: 'bulb', text: '暂无建议', sub: '多记录几天就能收到个性化建议' })
        }
      } else {
        Column({ space: Space.SM }) {
          ForEach(this.tips, (t: LocalSmartTip) => {
            Row({ space: Space.MD }) {
              CfIcon({ kind: 'tip', code: t.id, iconSize: 22 })
              Column({ space: 4 }) {
                Text(t.title)
                  .fontSize(FontSize.BODY)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.tc(Neutral.TEXT))
                Text(t.content)
                  .fontSize(FontSize.SMALL)
                  .fontColor(this.tc(Neutral.TEXT_SUB))
                  .lineHeight(18)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(Space.LG)
            .backgroundColor(this.tc(Neutral.CARD))
            .borderRadius(Radius.MD)
            .shadow(this.tw(Shadow.card()))
          }, (t: LocalSmartTip) => t.id)
        }
      }
    }
    .width('100%')
  }

  @Builder
  ShareBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '分享我的成绩单' })
      Column({ space: Space.MD }) {
        Text(this.shareText)
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(20)
          .width('100%')
        Row() {
          Text('复制文案')
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .width('100%')
            .textAlign(TextAlign.Center)
            .height(40)
            .linearGradient({
              angle: 90,
              colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
            })
            .borderRadius(Radius.PILL)
            .onClick((): void => {
              // 真复制：写入系统剪贴板才提示成功（原实现只弹 toast 未复制）。
              // 文案异步生成（统计走 RDB 聚合查询）：.then 链式消费，
              // 同步点击回调里不等候，不阻塞 UI。
              DataSource.shareText().then((text: string): void => {
                if (Clipboard.copy(text)) {
                  toast('文案已复制到剪贴板')
                } else {
                  toast('复制失败，请重试')
                }
              })
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.LG)
      .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
      .borderRadius(Radius.MD)
    }
    .width('100%')
  }
}