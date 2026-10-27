import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalTask } from '../../data/MockStore'
import { LocalStore } from '../../data/LocalStore'
import { Accent, CategoryMeta, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * P15 任务中心
 */
@Component
export struct TaskCenterPage {
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
  @State private tasks: LocalTask[] = []
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.tasks = await DataSource.tasks()
    } catch (err) {
      this.tasks = []
    }
  }
/** 任务完成度百分比 */
  private pctOf(t: LocalTask): number {
    if (t.targetValue <= 0) return 0
    return Math.min(100, Math.round((t.progress / t.targetValue) * 100))
  }

  /** 已完成（进度达标）任务数 */
  private doneCount(): number {
    let n: number = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.pctOf(this.tasks[i]) >= 100) n++
    }
    return n
  }

  /** 待领取任务数 */
  private claimableCount(): number {
    let n: number = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'done') n++
    }
    return n
  }

  /** 待领取的奖励积分合计 */
  private claimablePoints(): number {
    let s: number = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'done') s += this.tasks[i].rewardPoints
    }
    return s
  }

  /** 今日全部任务奖励上限 */
  private allPoints(): number {
    let s: number = 0
    for (let i = 0; i < this.tasks.length; i++) s += this.tasks[i].rewardPoints
    return s
  }

  /** 已领取的奖励积分合计 */
  private claimedPoints(): number {
    let s: number = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'claimed') s += this.tasks[i].rewardPoints
    }
    return s
  }

  /** 状态文案 */
  private statusText(t: LocalTask): string {
    if (t.status === 'claimed') return '已领取'
    if (t.status === 'done') return '待领取'
    return t.progress + '/' + t.targetValue
  }

  /** 状态色调 */
  private statusTone(t: LocalTask): string {
    if (t.status === 'claimed') return 'success'
    if (t.status === 'done') return 'warning'
    return 'muted'
  }

  /** 进度条颜色 */
  private barColor(t: LocalTask): string {
    if (t.status === 'claimed') return this.tc(Accent.SUCCESS)
    if (t.status === 'done') return this.tc(Accent.WARNING)
    return t.category.length > 0 ? this.tc(CategoryMeta.color(t.category)) : this.tc(EcoTheme.primary(this.ecoLevel))
  }
private async claim(t: LocalTask): Promise<void> {
    if (t.status !== 'done') return
    /*
     * 真领取（2026-10-23 修复「点完还是待领取」）：
     *   原实现只把页面内存里的 status 改成 claimed 就弹 toast ——
     *   既没落库，也没给账户加积分。而 status 每次都由
     *   MockStore.tasksFrom 按 progress>=target 重算，所以刷新/重进页面
     *   立刻回弹成「待领取」，积分也一分没到账。
     *   现在：LocalStore.claimTask 落库 + 幂等 + 并入今日任务积分，
     *   再重取一次让状态来自存储（而不是本地乐观改值），
     *   最后广播 ecoTick 让首页概览/积分页同步显示新积分。
     */
    const ok: boolean = await LocalStore.claimTask(t.taskCode, t.rewardPoints)
    if (!ok) {
      toast('「' + t.taskName + '」今日已领取过啦')
      await this.load()
      return
    }
    await this.load()
    EcoMoodState.broadcastDataChange()
    toast('已领取「' + t.taskName + '」+' + t.rewardPoints + ' 积分')
  }

  /** 领取全部待领任务（逐个走 claimTask：幂等 + 积分口径一致） */
  private async claimAll(): Promise<void> {
    if (this.claimableCount() === 0) {
      toast('暂无可领取的任务奖励')
      return
    }
    const targets: LocalTask[] = []
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'done') targets.push(this.tasks[i])
    }
    let pts: number = 0
    for (let i = 0; i < targets.length; i++) {
      const ok: boolean = await LocalStore.claimTask(targets[i].taskCode, targets[i].rewardPoints)
      if (ok) pts += targets[i].rewardPoints
    }
    await this.load()
    if (pts === 0) {
      toast('今日奖励已全部领取过了')
      return
    }
    EcoMoodState.broadcastDataChange()
    toast('已领取 ' + pts + ' 积分，积分已到账')
  }

  private openRecord(): void {
    AppRouter.pathStack.pushPathByName(RouteName.FACTOR_LIB, null)
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
        Column() {
          CfTopBar({
            title: '任务中心',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.SummaryCard()
              if (this.tasks.length === 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'target', text: '今日暂无任务', sub: '每天 0 点刷新，记得来打卡' })
                }
              } else {
                this.StatRow()
                this.TaskList()
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
@Builder
  SummaryCard() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日任务完成')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 4 }) {
            Text('' + this.doneCount())
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('/ ' + this.tasks.length)
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          Text('已完成任务可领取积分，每日 0 点重置')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        CfIcon({ kind: 'ui', code: 'target', iconSize: 34 })
      }
      .width('100%')

      Row() {
        Text(this.claimableCount() > 0 ? '一键领取 +' + this.claimablePoints() + ' 分' : '奖励已全部领取')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.claimableCount() > 0 ? '#FFFFFF' : 'rgba(255,255,255,0.7)')
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(42)
          .backgroundColor('rgba(255,255,255,0.22)')
          .borderRadius(Radius.PILL)
          .enabled(this.claimableCount() > 0)
          //块体调用：async 方法返回 Promise<void>，简写箭头（(): void => this.claimAll()）
          // 会把 Promise 当作返回值，与声明的 void 冲突（ArkTS 编译期报错）
          .onClick((): void => {
            this.claimAll()
          })
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
@Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '今日奖励',
          value: '+' + this.allPoints(),
          icon: 'gift',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '已领取',
          value: '+' + this.claimedPoints(),
          icon: 'check',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '待领取',
          value: '' + this.claimableCount() + ' 个',
          icon: 'mail',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  TaskList() {
    Column({ space: Space.MD }) {
      CfSection({ title: '每日任务', more: '去记录 ›', onMoreTap: (): void => this.openRecord() })
      Column({ space: Space.MD }) {
        ForEach(this.tasks, (t: LocalTask) => {
          this.TaskCard(t)
        }, (t: LocalTask): string => t.taskCode)
      }
    }
    .width('100%')
  }
@Builder
  TaskCard(t: LocalTask) {
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        Stack() {
          CfIcon({ kind: 'task', code: t.taskCode, iconSize: 22 })
        }
        .width(44)
        .height(44)
        .backgroundColor(this.pctOf(t) >= 100 ? this.tc(Accent.SUCCESS_BG) : this.tc(EcoTheme.primaryPale(this.ecoLevel)))
        .borderRadius(Radius.MD)
        Column({ space: 4 }) {
          Text(t.taskName)
            .fontSize(FontSize.TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
          Text(t.taskDesc)
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .lineHeight(18)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (t.category.length > 0) {
          CfPill({ text: CategoryMeta.label(t.category), tone: 'muted' })
        }
      }
      .width('100%')

      // 进度条 + 目标 + 奖励
      Column({ space: 6 }) {
        CfProgress({
          percent: this.pctOf(t),
          color: this.barColor(t),
          barHeight: 8
        })
        .width('100%')
        Row() {
          Text('目标 ' + t.progress + '/' + t.targetValue + ' 次')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          Blank()
          Text('+' + t.rewardPoints + ' 分')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        }
        .width('100%')
      }
      .width('100%')

      // 状态行：待领取时展示「领取」按钮
      Row() {
        CfPill({ text: this.statusText(t), tone: this.statusTone(t) })
        Blank()
        if (t.status === 'done') {
          Text('领取奖励')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .linearGradient({
              angle: 90,
              colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
            })
            .borderRadius(Radius.PILL)
            .shadow(this.tw(Shadow.brand()))
            .onClick((): void => {
              this.claim(t)
            })
        } else if (t.status === 'claimed') {
          Text('积分已到账')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Accent.SUCCESS))
        } else {
          Text('继续低碳记录即可达成')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
      }
      .width('100%')
      .padding({ top: Space.SM })
      .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
  }
}
