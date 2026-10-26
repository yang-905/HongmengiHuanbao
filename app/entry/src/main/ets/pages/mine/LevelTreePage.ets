import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalOverview } from '../../data/MockStore'
import { Accent, Biz, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 等级阶梯的一项 */
interface LevelStep {
  level: number;
  name: string;
  icon: string;
  /** 达到该等级所需累计减排下限 */
  from: number;
  /** 达到该等级所需累计减排上限（99999 表示无上限） */
  to: number;
}

/**
 * P12 成长树 / 等级
 * ------------------------------------------------------------------
 * 真实实现：等级进度环 + 五级阶梯（碳芽/新芽/绿芽/低碳达人/森林卫士）
 *          当前等级高亮，已达成 / 未解锁分态，顶部展示累计减排
 * 进度环使用系统 Progress 的 Ring 类型 + 居中文本叠层，零依赖实现。
 */
@Component
export struct LevelTreePage {
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
  @State private ov: LocalOverview = {
    totalKg: 0, todayKg: 0, monthKg: 0, totalPoints: 0, availablePoints: 0, exchangedPoints: 0,
    recordCount: 0, continuousDays: 0, treeCount: 0, badgeCount: 0, level: 1
  }
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.ov = await DataSource.overview()
    } catch (err) {
      // DataSource 内部已兜底
    }
  }

  /* ---------- 等级数据 ---------- */

  /** 五级阶梯定义（与 Biz.levelRange 口径一致） */
  private steps(): LevelStep[] {
    const out: LevelStep[] = []
    const icons: string[] = ['sprout', 'leaf', 'leaf', 'tree', 'trophy']
    for (let lv: number = 1; lv <= 5; lv++) {
      const r: number[] = Biz.levelRange(lv)
      const s: LevelStep = {
        level: lv,
        name: Biz.levelName(lv),
        icon: icons[lv - 1],
        from: r[0],
        to: r[1]
      }
      out.push(s)
    }
    return out
  }

  /** 当前等级在当前区间的进度百分比 */
  private levelPct(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    const span: number = r[1] - r[0]
    if (span <= 0) return 100
    return Math.max(2, Math.min(100, ((this.ov.totalKg - r[0]) / span) * 100))
  }

  /** 距下一级还差多少 kg（已满级返回 0） */
  private nextKg(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    if (r[1] >= 99999) return 0
    return Math.max(0, Math.round((r[1] - this.ov.totalKg) * 100) / 100)
  }

  /** 阶梯项状态：0 已达成 / 1 当前 / 2 未解锁 */
  private stateOf(s: LevelStep): number {
    if (this.ov.level > s.level) return 0
    if (this.ov.level === s.level) return 1
    return 2
  }

  /** 阶梯项的门槛文案 */
  private needText(s: LevelStep): string {
    if (s.to >= 99999) return '累计减排 ' + s.from + ' kg 起'
    return s.from + ' ~ ' + s.to + ' kg'
  }

  /** 阶梯项底部说明 */
  private tipText(s: LevelStep): string {
    const st: number = this.stateOf(s)
    if (st === 0) return '已达成'
    if (st === 1) return '当前等级 · 还差 ' + this.nextKg() + ' kg'
    return '还差 ' + Biz.formatKg(Math.max(0, s.from - this.ov.totalKg))
  }

  /** 阶梯项药丸色调 */
  private toneOf(s: LevelStep): string {
    const st: number = this.stateOf(s)
    if (st === 0) return 'success'
    if (st === 1) return 'info'
    return 'muted'
  }

  /* ---------- 交互 ---------- */

  private tapStep(s: LevelStep): void {
    const st: number = this.stateOf(s)
    if (st === 0) {
      toast('Lv.' + s.level + ' ' + s.name + ' 已达成，继续保持')
      return
    }
    if (st === 1) {
      toast('你当前正处于 Lv.' + s.level + ' ' + s.name)
      return
    }
    toast('再累计减排 ' + Biz.formatKg(Math.max(0, s.from - this.ov.totalKg)) + ' 即可解锁 ' + s.name)
  }

  private openPoints(): void {
    AppRouter.pathStack.pushPathByName(RouteName.POINTS_HOME, null)
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
        Column() {
          CfTopBar({
            title: '成长树',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.RingCard()
              if (this.ov.totalKg <= 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'sprout', text: '还没有减排数据', sub: '记录一笔低碳行为即可开始成长' })
                }
              } else {
                this.StatRow()
                this.Ladder()
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

  /* ---------- 等级进度环 ---------- */
  @Builder
  RingCard() {
    Column({ space: Space.LG }) {
      Row() {
        // 进度环：Ring 类型 + 居中文本
        Stack({ alignContent: Alignment.Center }) {
          Progress({
            value: this.levelPct(),
            total: 100,
            type: ProgressType.Ring
          })
            .width(112)
            .height(112)
            .color(Biz.levelColor(this.ov.level))
          Column({ space: 1 }) {
            Text('Lv.' + this.ov.level)
              .fontSize(FontSize.TITLE)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
            Text(Math.round(this.levelPct()) + '%')
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(Biz.levelColor(this.ov.level))
              .maxLines(1)
          }
        }
        .width(112)
        .height(112)

        Column({ space: 6 }) {
          Text(Biz.levelName(this.ov.level))
            .fontSize(FontSize.HEADING)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: 3 }) {
            Text(this.ov.totalKg.toFixed(2))
              .fontSize(FontSize.DISPLAY)
              .maxLines(1)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
            Text('kg')
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .margin({ top: 8 })
          }
          Text(this.ov.level >= 5 ? '已达最高等级，森林卫士' : '距 ' + Biz.levelName(this.ov.level + 1) + ' 还差 ' + this.nextKg() + ' kg')
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // 环外再补一条线性进度，便于精确感知当前区间位置
      CfProgress({
        percent: this.levelPct(),
        color: Biz.levelColor(this.ov.level),
        barHeight: 8
      })
      .width('100%')

      Row() {
        Text('Lv.' + this.ov.level + ' ' + Biz.levelName(this.ov.level))
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
        Blank()
        Text(this.ov.level >= 5 ? '已满级' : ('Lv.' + (this.ov.level + 1) + ' ' + Biz.levelName(this.ov.level + 1)))
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.XL)
    .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
    .borderRadius(Radius.XL)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(this.tw(Shadow.card()))
    .clip(true)
  }

  /* ---------- 数据三宫格 ---------- */
  @Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '今日减排',
          value: Biz.formatKg(this.ov.todayKg),
          icon: 'sun',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '认种树木',
          value: '' + this.ov.treeCount,
          icon: 'tree',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '连续天数',
          value: '' + this.ov.continuousDays,
          icon: 'flame',
          accent: this.tc(Accent.RECYCLE),
          tint: this.tc(Accent.RECYCLE_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  /* ---------- 五级阶梯 ---------- */
  @Builder
  Ladder() {
    Column({ space: Space.MD }) {
      CfSection({ title: '五级成长阶梯', more: '去赚积分 ›', onMoreTap: (): void => this.openPoints() })
      Column({ space: Space.SM }) {
        ForEach(this.steps(), (s: LevelStep) => {
          this.StepRow(s)
        }, (s: LevelStep): string => 'lv_' + s.level.toString())
      }
    }
    .width('100%')
  }

  @Builder
  StepRow(s: LevelStep) {
    Row() {
      // 阶梯项：当前等级用主色描边高亮，已达成白底，未解锁灰底
      Row({ space: Space.MD }) {
        Stack() {
          CfIcon({ kind: 'level', code: '' + s.level, iconSize: 24 })
        }
        .width(46)
        .height(46)
        .backgroundColor(this.stateOf(s) === 2 ? this.tc(Neutral.SURFACE) : this.tc(EcoTheme.primaryPale(this.ecoLevel)))
        .borderRadius(Radius.MD)

        Column({ space: 5 }) {
          Row() {
            Text('Lv.' + s.level + ' ' + s.name)
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(this.stateOf(s) === 1 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.stateOf(s) === 2 ? this.tc(Neutral.TEXT_MUTED) : this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            CfPill({ text: this.tipText(s), tone: this.toneOf(s) })
          }
          .width('100%')
          Text('需累计减排 ' + this.needText(s))
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(Space.LG)
      .backgroundColor(this.stateOf(s) === 2 ? this.tc(Neutral.SURFACE) : this.tc(Glass.CARD_BG))
      .borderRadius(Radius.MD)
      .border({
        width: this.stateOf(s) === 1 ? 1.5 : 1,
        color: this.stateOf(s) === 1 ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Glass.EDGE)
      })
      .shadow(this.stateOf(s) === 1 ? this.tw(Shadow.brand()) : this.tw(Shadow.card()))
      .clip(true)
      .onClick((): void => this.tapStep(s))
    }
    .width('100%')
  }
}
