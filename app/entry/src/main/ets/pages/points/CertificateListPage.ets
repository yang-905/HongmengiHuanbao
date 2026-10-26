import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParam } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalCert } from '../../data/MockStore'
import { Accent, Biz, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfBackIcon, CfCard, CfEmpty, CfPill, CfSection, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 证书详情路由参数：ArkTS 严格模式禁止无类型对象字面量，故声明 class */
class CertificateDetailParam {
  id: number = 0;

  constructor(i: number) {
    this.id = i;
  }
}

/**
 * P19 证书夹
 * ------------------------------------------------------------------
 * 真实实现：证书概览卡（张数 / 植树棵数 / 已消耗积分）
 *          + 证书卡列表（编号等宽显示、树种、棵数、消耗积分、颁发日期）
 *          + 空态引导去积分商城兑换
 * 路由名：CERTIFICATE_LIST（NavDestination，PageMap 集中注册）
 */
@Component
export struct CertificateListPage {
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
  @State private certs: LocalCert[] = []
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.certs = await DataSource.certificates()
    } catch (err) {
      this.certs = []
    }
  }

  /* ---------- 口径 ---------- */

  /** 累计认种棵数 */
  private totalTrees(): number {
    let n: number = 0
    for (let i: number = 0; i < this.certs.length; i++) {
      n += this.certs[i].treeCount
    }
    return n
  }

  /** 累计消耗积分 */
  private totalPoints(): number {
    let n: number = 0
    for (let i: number = 0; i < this.certs.length; i++) {
      n += this.certs[i].costPoints
    }
    return n
  }

  /** 证书卡左侧色条：按证书序号轮换语义色 */
  private barColor(i: number): string {
    const palette: string[] = [
      this.tc(EcoTheme.primary(this.ecoLevel)), this.tc(Accent.TRAVEL), this.tc(Accent.RECYCLE), this.tc(Accent.ENERGY), this.tc(Accent.FOOD)
    ]
    return palette[i % palette.length]
  }

  /** 卡片底色：与左侧色条同族浅色 */
  private tintColor(i: number): string {
    const palette: string[] = [
      this.tc(EcoTheme.primaryPale(this.ecoLevel)), this.tc(Accent.TRAVEL_BG), this.tc(Accent.RECYCLE_BG),
      this.tc(Accent.ENERGY_BG), this.tc(Accent.FOOD_BG)
    ]
    return palette[i % palette.length]
  }

  /* ---------- 交互 ---------- */

  private openDetail(c: LocalCert): void {
    goWithParam(RouteName.CERTIFICATE_DETAIL, 'detailCertId', c.certId)
  }

  private openMall(): void {
    AppRouter.pathStack.pushPathByName(RouteName.POINTS_MALL, null)
  }

  /**
   * 打开碳惠券包（证书夹 → 券包快捷入口）。
   * 用户原话「我的证书夹上面加入一个二级菜单入口」：二级菜单本体在
   * 「我的」页（MineEntry 碳惠券包），这里补一条证书夹内的直达链，
   * 两类资产（证书 / 权益券）相邻可查。
   */
  private openCoupons(): void {
    AppRouter.pathStack.pushPathByName(RouteName.COUPON_LIST, null)
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
          title: '证书夹',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            if (this.certs.length === 0) {
              CfCard({}) {
                CfEmpty({
                  icon: 'certificate',
                  line: true,
                  text: '暂无证书',
                  sub: '继续加油！每 ' + Biz.POINTS_PER_TREE + ' 积分可兑换 1 棵树'
                })
              }
              this.EmptyAction()
            } else {
              this.SummaryCard()
              this.CertSection()
              this.MallTip()
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

  /* ---------- 概览大卡 ---------- */
  /**
   * 概览卡：左「已获证书」+ 右「累计认种 / 累计消耗」
   * ------------------------------------------------------------------
   * 排版修复（数字被截断、右侧两组指标挤成一团）：
   *   · 左侧大数字用 HERO 字号(34)，**必须给宽度约束**，
   *     否则它按内容无限撑开，把右侧两行指标挤出卡片右缘
   *     （截图里「1800 分」被切掉一半就是这个原因）。
   *   · 右侧两行改为「标签在上、数值在下」的竖排卡片，
   *     每行 layoutWeight(1) 均分，数值右对齐并允许省略，
   *     这样 4 位数积分也不会顶破边界。
   */
  @Builder
  SummaryCard() {
    Row({ space: Space.LG }) {
      Column({ space: 3 }) {
        Text('已获证书')
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.85)')
          .maxLines(1)
        Row({ space: 4 }) {
          Text('' + this.certs.length)
            .fontSize(FontSize.HERO)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1)
          Text('张')
            .fontSize(FontSize.BODY)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor('rgba(255,255,255,0.9)')
            .margin({ top: 10 })
            .maxLines(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minWidth: 0 })
      .flexShrink(0)

      // 右侧两组指标：竖排 + 均分，保证 4 位数也不溢出
      Row({ space: Space.SM }) {
        this.MetricCell('tree', '累计认种', this.totalTrees() + ' 棵')
        this.MetricCell('coin', '累计消耗', this.totalPoints() + ' 分')
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
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

  /**
   * 概览卡右侧的单个指标格。
   * 竖排「标签 / 数值」而非左右挤压：数值再长（4 位积分）也只占一行，
   * 且 layoutWeight 均分保证两格等宽。
   */
  @Builder
  MetricCell(icon: string, label: string, value: string) {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        CfIcon({ kind: 'ui', code: icon, iconSize: 12, color: 'rgba(255,255,255,0.85)' })
        Text(label)
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.85)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(value)
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .constraintSize({ minWidth: 0 })
  }

  /* ---------- 证书列表 ---------- */
  @Builder
  CertSection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '全部证书', more: '券包 ›', onMoreTap: (): void => this.openCoupons() })
      Column({ space: Space.MD }) {
        ForEach(this.certs, (c: LocalCert, i: number) => {
          this.CertCard(c, i)
        }, (c: LocalCert): string => c.certNo)
      }
      .width('100%')
    }
    .width('100%')
  }

  /* ---------- 单张证书卡 ---------- */
  @Builder
  CertCard(c: LocalCert, i: number) {
    Row() {
      // 左侧语义色条（右侧留 8vp 间距，避免色条紧贴证书文字）
      Row()
        .width(4)
        .height(56)
        .backgroundColor(this.barColor(i))
        .borderRadius(2)
        .margin({ right: Space.SM })

      Column({ space: Space.SM }) {
Row() {
          Row({ space: 4 }) {
            CfIcon({ kind: 'ui', code: 'tree', iconSize: 14, color: this.tc(Neutral.TEXT) })
            Text(c.treeType + ' 认养证书')
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ minWidth: 0 })
              .layoutWeight(1)
          }
          .layoutWeight(1)
          CfPill({ text: c.treeCount + ' 棵', tone: 'success' })
        }
        .width('100%')

        // 证书编号：等宽字体便于核对防重号。
        // 必须加宽度约束 + 省略号：certNo 较长（CF-2026101810153000），
        // 不约束会把下方「消耗 / 颁发于」挤到同一行甚至顶出卡片。
        Text(c.certNo)
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .fontFamily('monospace')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text('消耗 ' + c.costPoints + ' 积分')
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ minWidth: 0 })
            .layoutWeight(1)
          Blank().width(Space.SM)
          Text('颁发于 ' + c.issueDate)
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ minWidth: 0 })
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })

      // '›' 字符走字体回退可能不继承 fontColor → 改用矢量箭头
      CfBackIcon({
        iconSize: 18,
        color: this.tc(Neutral.TEXT_MUTED),
        pointRight: true
      })
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tintColor(i))
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
    .onClick((): void => this.openDetail(c))
  }

  /* ---------- 空态操作 ---------- */
  @Builder
  EmptyAction() {
    Row() {
      Text('去积分商城兑换证书')
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
    }
    .width('100%')
    .onClick((): void => this.openMall())
  }

  /* ---------- 兑换提示 ---------- */
  @Builder
  MallTip() {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: 'gift', iconSize: 20 })
      Column({ space: 3 }) {
        Text('公益植树认养')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text('消耗 ' + (Biz.POINTS_PER_TREE * 3) + ' 积分可认养 3 棵树并获电子证书')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(17)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.MD)
    .onClick((): void => {
      toast('认养后证书将在 1 分钟内生成，可在证书夹查看')
    })
  }
}
