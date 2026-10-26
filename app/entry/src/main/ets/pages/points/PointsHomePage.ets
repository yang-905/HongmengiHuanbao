import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalOverview } from '../../data/MockStore'
import {
  Accent,
  Biz,
  Brand,
  FontSize,
  Neutral,
  Radius,
  Shadow,
  Space,
  EcoTheme,
  EcoMood
} from '../../ui/Theme'
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 快捷入口项 */
interface QuickEntry {
  /** 图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string;
  label: string;
  route: string;
  color: string;
  tint: string;
}

/**
 * P13 积分首页
 * ------------------------------------------------------------------
 * 真实实现：积分余额大卡（渐变）+ 可用/累计获得/累计兑换三项统计
 *          + 四个快捷入口（流水/商城/证书/徽章）+ 积分规则说明
 */
@Component
export struct PointsHomePage {
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
  /** 快捷入口卡固定高度 / 每行个数 */
  private static readonly CARD_H: number = 78
  private static readonly COLS: number = 4

  @State private ov: LocalOverview = {
    totalKg: 0, todayKg: 0, monthKg: 0, totalPoints: 0, availablePoints: 0, exchangedPoints: 0,
    recordCount: 0, continuousDays: 0, treeCount: 0, badgeCount: 0, level: 1
  }
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  /**
 * 四个快捷入口。
 *
 * ⚠️ 这里**不能用** EcoTheme.xxx(this.ecoLevel)：
 *   字段初始化早于 @StorageProp 赋值，编译报
 *   "Property 'ecoLevel' is used before its initialization"。
 *   快捷入口是**静态清单**，入口色属于固定语义色（各入口本就有自己的
 *   主题色：流水=绿、商城=琥珀、证书=蓝、徽章=绿），
 *   不应跟随碳档位变化 —— 这里恢复为固定色。
 */
  private entries: QuickEntry[] = [
    { icon: 'certificate', label: '积分流水', route: RouteName.POINTS_RECORD, color: this.tc(Brand.PRIMARY_DEEP), tint: this.tc(Brand.PRIMARY_PALE) },
    { icon: 'mall', label: '积分商城', route: RouteName.POINTS_MALL, color: this.tc(Accent.WARNING), tint: this.tc(Accent.WARNING_BG) },
    { icon: 'book', label: '证书夹', route: RouteName.CERTIFICATE_LIST, color: this.tc(Accent.INFO), tint: this.tc(Accent.INFO_BG) },
    { icon: 'badge', label: '徽章墙', route: RouteName.BADGE_WALL, color: this.tc(Accent.SUCCESS), tint: this.tc(Accent.SUCCESS_BG) }
  ]

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

  /* ---------- 口径 ---------- */

  /**
   * 累计兑换（取券流水精确累加值）。
   * ⚠️ 曾用 totalPoints − availablePoints 反推：可用积分改成持久化余额后，
   *   删记录砸到 0 的超出部分被抹平，反推值会小于真实兑换消耗，
   *   与券包里躺着的券对不上。现直接取 ov.exchangedPoints（见 LocalOverview）。
   */
  private exchangedPoints(): number {
    return this.ov.exchangedPoints
  }

  /**
   * 下一棵树的兑换进度（3000 分一棵）。
   * ⚠️ 口径修正：可用积分现已是**真实余额**（不再被树的折算扣减），
   *   进度必须从「累计获得 mod POINTS_PER_TREE」取 —— 若仍用 availablePoints/POINTS_PER_TREE，
   *   余额超过 200 后进度条会恒停在 100%。
   */
  private treePct(): number {
    const inCycle: number = this.ov.totalPoints % Biz.POINTS_PER_TREE
    return Math.max(2, Math.min(100, (inCycle / Biz.POINTS_PER_TREE) * 100))
  }

  /** 距下一棵树还差多少分（同样按折算周期取模，与进度条同源） */
  private toNextTree(): number {
    return Biz.POINTS_PER_TREE - (this.ov.totalPoints % Biz.POINTS_PER_TREE)
  }

  private go(route: string): void {
    AppRouter.pathStack.pushPathByName(route, null)
  }

  private openTask(): void {
    AppRouter.pathStack.pushPathByName(RouteName.TASK_CENTER, null)
  }

  /* ---------- 动态碳主题 ---------- */

  /** 全局碳情绪档位（响应式，AppStorage 驱动） */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 记录变更信号：写入记录后立即重算档位 */
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

  /** 当前档位对应的页面底色 */
  private ecoBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
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
            title: '碳积分',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.BalanceCard()
              if (this.ov.totalPoints <= 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'coin', text: '还没有积分', sub: '每 1 kg 减排可得 10 积分' })
                }
              } else {
                this.StatRow()
                this.TreeCard()
                this.QuickGrid()
                this.TaskTip()
                this.RuleCard()
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
    // 动态碳主题 + 液态玻璃：半透明底 + 实时高斯模糊
    .backdropBlur(EcoMood.blurOf(this.ecoLevel))
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

  /* ---------- 积分余额大卡 ---------- */
  @Builder
  BalanceCard() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text('可用积分')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 4 }) {
            Text('' + this.ov.availablePoints)
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
          Text('累计减排 ' + Biz.formatKg(this.ov.totalKg) + ' · Lv.' + this.ov.level + ' ' + Biz.levelName(this.ov.level))
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        CfIcon({ kind: 'ui', code: 'coin', iconSize: 34 })
      }
      .width('100%')

      // 三项数据
      Row() {
        this.WhiteStat('累计获得', '' + this.ov.totalPoints)
        this.WhiteStat('累计兑换', '' + this.exchangedPoints())
        this.WhiteStat('已认种', '' + this.ov.treeCount + ' 棵')
      }
      .width('100%')
      .padding({ top: Space.MD })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.22)' })

      // 快捷入口：卡内一行四列
      Row() {
        ForEach(this.entries, (e: QuickEntry) => {
          this.WhiteEntry(e.icon, e.label, e.route)
        }, (e: QuickEntry): string => e.route)
      }
      .width('100%')
      .padding({ top: Space.MD })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.22)' })
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

  /** 大卡内的白色小指标 */
  @Builder
  WhiteStat(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(FontSize.TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text(label)
        .fontSize(FontSize.CAPTION)
        .fontColor('rgba(255,255,255,0.85)')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** 大卡内的白色快捷入口 */
  @Builder
  WhiteEntry(icon: string, label: string, route: string) {
    Column({ space: 4 }) {
      CfIcon({ kind: 'ui', code: icon, iconSize: 19, color: '#FFFFFF' })
      Text(label)
        .fontSize(FontSize.CAPTION)
        .fontColor('#FFFFFF')
    }
    .layoutWeight(1)
    .onClick((): void => this.go(route))
  }

  /* ---------- 统计三宫格 ---------- */
  @Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '可用积分',
          value: '' + this.ov.availablePoints,
          icon: 'cash',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '累计获得',
          value: '' + this.ov.totalPoints,
          icon: 'up',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '累计兑换',
          value: '' + this.exchangedPoints(),
          icon: 'gift',
          accent: this.tc(Accent.WARNING),
          tint: this.tc(Accent.WARNING_BG)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  /* ---------- 兑换进度 ---------- */
  @Builder
  TreeCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '积分兑换进度' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          Row() {
            Text('每 ' + Biz.POINTS_PER_TREE + ' 积分可兑换 1 棵植树证书')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
            Blank()
            CfPill({ text: '种树 ' + this.treePct().toFixed(0) + '%', tone: 'info' })
          }
          .width('100%')
          CfProgress({
            percent: this.treePct(),
            color: this.tc(EcoTheme.primary(this.ecoLevel)),
            barHeight: 8
          })
          .width('100%')
          Row() {
            Text(this.ov.availablePoints + ' / ' + Biz.POINTS_PER_TREE + ' 分')
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
            Blank()
            Text(this.toNextTree() > 0 ? ('还差 ' + this.toNextTree() + ' 分') : '可立即兑换 1 棵树')
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /* ---------- 快捷入口网格 ---------- */
  @Builder
  QuickGrid() {
    Column({ space: Space.MD }) {
      CfSection({ title: '积分去哪用' })
      // 用 Row + layoutWeight 显式分列替代 Grid（列宽约束传不到子 Text，
      // 格子会退化成内容宽度，字体放大后文字逐字竖排）
      Column({ space: Space.MD }) {
        ForEach(this.rowIndexes(), (r: number) => {
          Row({ space: Space.MD }) {
            ForEach(this.cellsOfRow(r), (e: QuickEntry) => {
              Column() {
                this.QuickCell(e)
              }
              .layoutWeight(1)
            }, (e: QuickEntry): string => e.route)
            if (this.cellsOfRow(r).length < PointsHomePage.COLS) {
              ForEach(this.fillerIndexes(r), (f: number) => {
                Column().layoutWeight(1)
              }, (f: number): string => 'fill_' + r.toString() + '_' + f.toString())
            }
          }
          .width('100%')
        }, (r: number): string => 'row_' + r.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  QuickCell(e: QuickEntry) {
    Column({ space: 6 }) {
      CfIcon({ kind: 'ui', code: e.icon, iconSize: 22 })
      Text(e.label)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(PointsHomePage.CARD_H)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(e.tint)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .borderRadius(Radius.MD)
    .clip(true)
    .onClick((): void => this.go(e.route))
  }

  /** 行号数组 */
  private rowIndexes(): number[] {
    const rows: number = Math.ceil(this.entries.length / PointsHomePage.COLS);
    const out: number[] = [];
    for (let i: number = 0; i < rows; i++) out.push(i);
    return out;
  }

  /** 第 r 行的入口（最多 COLS 个） */
  private cellsOfRow(r: number): QuickEntry[] {
    const out: QuickEntry[] = [];
    const start: number = r * PointsHomePage.COLS;
    for (let i: number = 0; i < PointsHomePage.COLS; i++) {
      const idx: number = start + i;
      if (idx < this.entries.length) out.push(this.entries[idx]);
    }
    return out;
  }

  /** 末行补齐占位下标 */
  private fillerIndexes(r: number): number[] {
    const used: number = this.cellsOfRow(r).length;
    const out: number[] = [];
    for (let i: number = used; i < PointsHomePage.COLS; i++) out.push(i);
    return out;
  }

  /* ---------- 任务提示 ---------- */
  @Builder
  TaskTip() {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: 'target', iconSize: 22 })
      Column({ space: 3 }) {
        Text('完成任务赚积分')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text('每日 5 个低碳任务，最高可得 70 分')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('去完成 ›')
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.MD)
    .onClick((): void => this.openTask())
  }

  /* ---------- 积分规则 ---------- */
  @Builder
  RuleCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '积分规则' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          this.RuleLine('记录低碳行为', '1 kg 减排 = ' + Biz.POINTS_PER_KG + ' 积分')
          this.RuleLine('兑换植树证书', Biz.POINTS_PER_TREE + ' 积分 = 1 棵树')
          this.RuleLine('积分有效期', '长期有效，过期将提前公告')
          Row() {
            Text('碳积分规则')
              .fontSize(FontSize.SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
              .width('100%')
              .textAlign(TextAlign.Center)
              .height(40)
              .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
              .borderRadius(Radius.PILL)
              .onClick((): void => {
                toast('积分规则以平台公告为准')
              })
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  RuleLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
      Blank()
      Text(value)
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
    }
    .width('100%')
  }
}
