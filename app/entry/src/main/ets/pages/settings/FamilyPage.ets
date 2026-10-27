import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalMember } from '../../data/MockStore'
import { Accent, Biz, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { Clipboard } from '../../utils/Clipboard';
import { CfIcon } from '../../ui/Icon';

/**

 * P29 家庭碳账户（创新拓展）
 */
@Component
export struct FamilyPage {
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
  @State private members: LocalMember[] = []
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.members = await DataSource.familyMembers()
    } catch (err) {
      this.members = []
    }
  }
/** 家庭合计减排（kg） */
  private familyKg(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.members.length; i++) {
      sum += this.members[i].reduction
    }
    return Math.round(sum * 100) / 100
  }

  /** 家庭合计积分 */
  private familyPoints(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.members.length; i++) {
      sum += this.members[i].points
    }
    return sum
  }

  /** 家庭合计记录数 */
  private familyCount(): number {
    let sum: number = 0
    for (let i: number = 0; i < this.members.length; i++) {
      sum += this.members[i].count
    }
    return sum
  }

  /** 在线成员数 */
  private onlineCount(): number {
    let n: number = 0
    for (let i: number = 0; i < this.members.length; i++) {
      if (this.members[i].online) n++
    }
    return n
  }

  /** 排行最大值（用于进度条归一化） */
  private maxKg(): number {
    let m: number = 0
    for (let i: number = 0; i < this.members.length; i++) {
      if (this.members[i].reduction > m) m = this.members[i].reduction
    }
    return m <= 0 ? 1 : m
  }

  /** 排名（1 起） */
  private rankOf(i: number): number {
    let r: number = 1
    for (let k: number = 0; k < this.members.length; k++) {
      if (this.members[k].reduction > this.members[i].reduction) r++
    }
    return r
  }

  /** 角色文案 */
  private roleText(m: LocalMember): string {
    if (m.isSelf) return '我'
    if (m.role === 'owner') return '管理员'
    return '成员'
  }

  /** 成员进度条配色：自己主色，他人按名次区分 */
  private barColor(m: LocalMember, idx: number): string {
    const r: number = this.rankOf(idx)
    if (m.isSelf) return this.tc(EcoTheme.primary(this.ecoLevel))
    if (r === 1) return this.tc(Accent.SUCCESS)
    if (r === 2) return this.tc(Accent.TRAVEL)
    return this.tc(Accent.WARNING)
  }
private goTerminal(): void {
    AppRouter.pathStack.pushPathByName(RouteName.SUPER_TERMINAL, null)
  }

  /**

   * 邀请家人：把邀请文案写入系统剪贴板（真复制，见 Clipboard）。
   * 文案引导家人从「我的 → 家庭账户」加入，信息真实可执行。
   */
  private invite(): void {
    const text: string = '【一触青绿】邀请你加入家庭碳账户：一起记录低碳行为、攒积分、种树。' +
      '打开一触青绿 → 我的 → 家庭账户，即可加入。'
    if (Clipboard.copy(text)) {
      toast('邀请文案已复制，发给家人即可一起加入家庭账户')
    } else {
      toast('复制失败，请重试')
    }
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
          title: '家庭碳账户',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        if (this.members.length === 0) {
          Column() {
            CfEmpty({ icon: 'home', text: '还没有家庭成员', sub: '邀请家人一起记录低碳生活吧' })
            this.InviteButton()
          }
          .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.SummaryCard()
              this.StatRow()
              this.MemberBlock()
              this.TerminalEntry()
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
  InviteButton() {
    Row() {
      Text('邀请家人')
        .fontSize(FontSize.BODY)
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
        .onClick((): void => this.invite())
    }
    .width('100%')
    .padding({ left: 80, right: 80 })
  }
@Builder
  SummaryCard() {
    Column({ space: Space.MD }) {
      Row() {
        Column({ space: 3 }) {
          Text('家庭合并减排')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 3 }) {
            Text(Biz.formatKg(this.familyKg()))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          Text('减排量 ≈ 种下 ' + Biz.treesOf(this.familyPoints()) + ' 棵树')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()

        Column({ space: 2 }) {
          CfIcon({ kind: 'ui', code: 'home', iconSize: 30 })
          Text(this.members.length + ' 位成员')
            .fontSize(FontSize.CAPTION)
            .fontColor('rgba(255,255,255,0.88)')
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      Row() {
        Text('邀请家人加入')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(40)
          .backgroundColor('rgba(255,255,255,0.22)')
          .borderRadius(Radius.PILL)
          .onClick((): void => this.invite())
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
          label: '合计积分',
          value: '' + this.familyPoints(),
          icon: 'coin',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '记录条数',
          value: '' + this.familyCount(),
          icon: 'note',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '在线成员',
          value: this.onlineCount() + '/' + this.members.length,
          icon: 'wifi',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  MemberBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '家庭成员', more: '按减排排行 ›' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          ForEach(this.members, (m: LocalMember, i: number) => {
            this.MemberRow(m, i)
          }, (m: LocalMember): string => m.memberName)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  MemberRow(m: LocalMember, i: number) {
    Row({ space: Space.MD }) {
      // 头像 + 排名
      Column({ space: 2 }) {
        Text(m.avatar).fontSize(24)
      }
      .width(46)
      .height(46)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(m.isSelf ? this.tc(EcoTheme.primaryPale(this.ecoLevel)) : this.tc(Neutral.SURFACE))
      .borderRadius(Radius.PILL)

      Column({ space: 5 }) {
        Row({ space: Space.SM }) {
          Text('No.' + this.rankOf(i))
            .fontSize(FontSize.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
          Text(m.memberName)
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(Neutral.TEXT))
          CfPill({ text: this.roleText(m), tone: m.isSelf ? 'info' : 'muted' })
          if (!m.online) {
            CfPill({ text: '离线', tone: 'warning' })
          }
          Blank()
          Text(Biz.formatKg(m.reduction))
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        }
        .width('100%')

        // 进度条：按减排量归一化
        CfProgress({
          percent: (m.reduction / this.maxKg()) * 100,
          color: this.barColor(m, i),
          barHeight: 6
        })
        .width('100%')

        Text(m.deviceName + ' · ' + m.points + ' 积分 · ' + m.count + ' 条记录')
          .fontSize(10)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .onClick((): void => {
      toast(m.memberName + ' 累计减排 ' + Biz.formatKg(m.reduction))
    })
  }
@Builder
  TerminalEntry() {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: 'device', iconSize: 26 })
      Column({ space: 3 }) {
        Text('超级终端 · 家庭设备')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Text(this.onlineCount() + ' 台设备在线，自动汇总到家庭账户')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('查看 ›')
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
    .onClick((): void => this.goTerminal())
  }
}
