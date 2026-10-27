import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalBadge } from '../../data/MockStore'
import { Accent, CategoryMeta, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { BadgeDetailSheet } from './BadgeDetailSheet'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * P17 徽章墙
 * 真实实现：解锁进度头卡 + 10 枚徽章网格
 *          已解锁：彩色底 + 悬起投影 + 解锁日期
 *          未解锁：灰态 + 锁定图标 + 解锁阈值
 */
@Component
export struct BadgeWallPage {
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
  /**
   * 徽章卡固定行高。
   * 卡片内部是固定高度的定长排布，额度必须给足，否则最后一行药丸被裁掉。
   * 组成：图标 56 + 3×行距 6 + 名称 ~20 + 描述 2 行 ~30 + 药丸 ~22 + 内边距 20 ≈ 168
   */
  private static readonly CARD_H: number = 186
  /** 每行徽章数：同时决定列宽百分比与行拆分 */
  private static readonly COLS: number = 2

  @State private badges: LocalBadge[] = []
  @State private loading: boolean = true
  /** 徽章详情半模态开关 */
  @State private showBadgeSheet: boolean = false
  /** 当前查看的徽章 */
  @State private currentBadge: LocalBadge | null = null

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.badges = await DataSource.badges()
    } catch (err) {
      this.badges = []
    }
  }
/** 已解锁数量 */
  private unlockedCount(): number {
    let n: number = 0
    for (let i = 0; i < this.badges.length; i++) {
      if (this.badges[i].unlocked) n++
    }
    return n
  }

  /** 解锁进度百分比 */
  private pct(): number {
    if (this.badges.length === 0) return 0
    return Math.round((this.unlockedCount() / this.badges.length) * 100)
  }

  /** 下一个待解锁的徽章（按列表顺序取第一个未解锁） */
  private nextBadge(): LocalBadge | null {
    for (let i = 0; i < this.badges.length; i++) {
      if (!this.badges[i].unlocked) return this.badges[i]
    }
    return null
  }

  /** 指标单位：按 metric 给出阈值后缀 */
  private unitOf(b: LocalBadge): string {
    if (b.metric === 'reduction') return ' kg'
    if (b.metric === 'count') return ' 条'
    if (b.metric === 'days') return ' 天'
    if (b.metric === 'tree') return ' 棵'
    if (b.metric === 'categoryCount') return ' 次'
    return ''
  }

  /** 阈值文案 */
  private thresholdText(b: LocalBadge): string {
    const suffix: string = this.unitOf(b)
    if (b.metric === 'categoryCount' && b.category.length > 0) {
      return CategoryMeta.label(b.category) + ' ' + b.threshold + suffix
    }
    return b.threshold + suffix
  }

  /** 底部说明：已解锁显示日期，未解锁显示阈值 */
  private footText(b: LocalBadge): string {
    if (b.unlocked) {
      return b.unlockDate.length > 0 ? ('解锁于 ' + b.unlockDate) : '已解锁'
    }
    return '需 ' + this.thresholdText(b)
  }

  /** 徽章底色：已解锁给浅色，未解锁给灰 */
  private tintOf(b: LocalBadge): string {
    if (!b.unlocked) return this.tc(Neutral.SURFACE)
    const palette: string[] = [
      this.tc(EcoTheme.primaryPale(this.ecoLevel)), this.tc(Accent.TRAVEL_BG), this.tc(Accent.ENERGY_BG),
      this.tc(Accent.RECYCLE_BG), this.tc(Accent.FOOD_BG)
    ]
    const idx: number = this.badges.indexOf(b)
    return palette[idx % palette.length]
  }
private tapBadge(b: LocalBadge): void {
    this.currentBadge = b
    this.showBadgeSheet = true
  }

  @Builder
  BadgeSheetContent() {
    BadgeDetailSheet({
      badge: this.currentBadge,
      onClose: (): void => {
        this.showBadgeSheet = false
      }
    })
  }

  private openTask(): void {
    AppRouter.pathStack.pushPathByName(RouteName.TASK_CENTER, null)
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
            title: '徽章墙',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.HeaderCard()
              if (this.badges.length === 0) {
                CfCard({}) {
                  CfEmpty({ icon: 'badge', text: '暂无徽章', sub: '完成低碳目标即可解锁徽章' })
                }
              } else {
                this.StatRow()
                this.BadgeGrid()
                this.NextCard()
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
        .bindSheet(this.showBadgeSheet, this.BadgeSheetContent(), {
          height: SheetSize.LARGE,
          dragBar: true,
          // 关键：sheet 消失时（下滑关闭 / 点遮罩 / 返回键）必须把开关复位。
          // dragBar 允许用户下滑收起，但系统**不会**回写 showBadgeSheet，
          // 开关仍是 true；下次 tapBadge 再赋 true 不产生状态变化，
          // bindSheet 收不到「false→true」的跃迁，面板就再也不弹了。
          onDisappear: (): void => {
            this.showBadgeSheet = false
          }
        })
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
  HeaderCard() {
    Column({ space: Space.LG }) {
      Row() {
        Column({ space: 3 }) {
          Text('已解锁徽章')
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 4 }) {
            Text('' + this.unlockedCount())
              .fontSize(FontSize.HERO)
              .maxLines(1)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('/ ' + this.badges.length)
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 10 })
          }
          Text(this.unlockedCount() >= this.badges.length ? '恭喜全部徽章已集齐' : '坚持记录低碳行为，逐枚解锁')
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor('rgba(255,255,255,0.85)')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        CfIcon({ kind: 'ui', code: 'trophy', iconSize: 34 })
      }
      .width('100%')

      Column({ space: 6 }) {
        CfProgress({
          percent: this.pct(),
          color: '#FFFFFF',
          barHeight: 7,
          track: 'rgba(255,255,255,0.28)'
        })
        .width('100%')
        Row() {
          Text('收集进度')
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor('rgba(255,255,255,0.9)')
          Blank()
          Text(this.pct() + '%')
            .fontSize(FontSize.CAPTION)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
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
    // 玻璃质感：渐变之上压一层极淡的模糊高光，边缘给一亮一暗的玻璃厚度
    .borderRadius(Radius.XL)
    .border({ width: 1, color: 'rgba(255,255,255,0.55)' })
    .shadow(this.tw(Shadow.brand()))
    .clip(true)
  }
@Builder
  StatRow() {
    Row({ space: Space.MD }) {
      Column() {
        CfStatTile({
          label: '已解锁',
          value: '' + this.unlockedCount(),
          icon: 'badge',
          accent: this.tc(Accent.SUCCESS),
          tint: this.tc(Accent.SUCCESS_BG)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '待解锁',
          value: '' + (this.badges.length - this.unlockedCount()),
          icon: 'lock',
          accent: this.tc(Neutral.TEXT_SUB),
          tint: this.tc(Neutral.SURFACE)
        })
      }
      .layoutWeight(1)
      Column() {
        CfStatTile({
          label: '收集进度',
          value: this.pct() + '%',
          icon: 'chart',
          accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
          tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  BadgeGrid() {
    Column({ space: Space.MD }) {
      CfSection({ title: '全部徽章', more: '去赚积分 ›', onMoreTap: (): void => this.openTask() })
      // 为什么不用 Grid：
      // Grid + columnsTemplate('1fr 1fr') 下，GridItem 的宽度约束不会被可靠地
      // 传递到子节点——子 Text 会按「内容宽度」排版，卡片宽度被压到几十 vp，
      // 于是 14fp 的名称被逐字换行、撑出卡片边界（截图里的超大竖排文字）。
      // 改为显式行/列 + layoutWeight 均分：Row 的剩余宽度会真实下发到卡片，
      // 与统计小卡（CfStatTile + Row + layoutWeight）的可靠行为保持一致。
      Column({ space: Space.MD }) {
        ForEach(this.rowIndexes(), (r: number) => {
          Row({ space: Space.MD }) {
            ForEach(this.cellsOfRow(r), (b: LocalBadge) => {
              Column() {
                this.BadgeCell(b)
              }
              .layoutWeight(1)
            }, (b: LocalBadge): string => b.badgeCode)
            // 补齐奇数个徽章时的末行空位，保证最后一张卡不横向拉满
            if (this.cellsOfRow(r).length < BadgeWallPage.COLS) {
              ForEach(this.fillerIndexes(r), (f: number) => {
                Column().layoutWeight(1)
              }, (f: number): string => 'fill_' + r.toString() + '_' + f.toString())
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (r: number): string => 'row_' + r.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  /** 需要渲染的行号数组：[0, 1, ... rows-1] */
  private rowIndexes(): number[] {
    const rows: number = Math.ceil(this.badges.length / BadgeWallPage.COLS);
    const out: number[] = [];
    for (let i: number = 0; i < rows; i++) out.push(i);
    return out;
  }

  /** 第 r 行的徽章（最多 COLS 个） */
  private cellsOfRow(r: number): LocalBadge[] {
    const out: LocalBadge[] = [];
    const start: number = r * BadgeWallPage.COLS;
    for (let i: number = 0; i < BadgeWallPage.COLS; i++) {
      const idx: number = start + i;
      if (idx < this.badges.length) out.push(this.badges[idx]);
    }
    return out;
  }

  /** 末行补齐用的占位下标 */
  private fillerIndexes(r: number): number[] {
    const used: number = this.cellsOfRow(r).length;
    const out: number[] = [];
    for (let i: number = used; i < BadgeWallPage.COLS; i++) out.push(i);
    return out;
  }
@Builder
  BadgeCell(b: LocalBadge) {
    Column({ space: 6 }) {
      // 徽章主体：已解锁彩色悬起，未解锁灰态带锁标
      Stack({ alignContent: Alignment.TopEnd }) {
        // 已解锁：徽章原画用卡通 emoji（成就的「收集感」靠彩色立住）；
        // 未解锁：统一线稿锁，避免一排彩色图标里混进灰锁显得脏。
        if (b.unlocked) {
          Text(b.icon)
            .fontSize(28)
            .maxFontScale(FontSize.SCALE_NUM)
            .width(56)
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.tintOf(b))
            .borderRadius(28)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            CfIcon({
              kind: 'ui',
              code: 'lock',
              iconSize: 24,
              color: this.tc(Neutral.TEXT_MUTED)
            })
          }
          .width(56)
          .height(56)
          .backgroundColor(this.tintOf(b))
          .borderRadius(28)
        }
        if (!b.unlocked) {
          Text('未解锁')
            .fontSize(9)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.tc(Neutral.TEXT_MUTED))
            .borderRadius(Radius.PILL)
            .margin({ right: -4, top: -2 })
        }
      }
      .width('100%')
      .height(60)

      Text(b.badgeName)
        .fontSize(FontSize.BODY)
        // 关键修复：系统字体放大时不允许把卡片撑破，钳到 1.15
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(b.unlocked ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(b.description)
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .lineHeight(15)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      // 底部：解锁日期或解锁阈值
      Row() {
        if (b.unlocked) {
          CfPill({ text: this.footText(b), tone: 'success' })
        } else {
          CfPill({ text: this.thresholdText(b), tone: 'muted' })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: Space.XS })
      .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height(BadgeWallPage.CARD_H)
    .padding(Space.MD)
    .backgroundColor(b.unlocked ? this.tc(Neutral.CARD) : this.tc(Neutral.SURFACE))
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .shadow(b.unlocked ? this.tw(Shadow.card()) : Shadow.none())
    // 兜底：任何异常放大都被裁在卡片内部，不会污染相邻卡片
    .clip(true)
    .onClick((): void => this.tapBadge(b))
  }
@Builder
  NextCard() {
    if (this.nextBadge() !== null) {
      Column({ space: Space.MD }) {
        CfSection({ title: '下一个目标' })
        Row({ space: Space.MD }) {
          Stack() {
            CfIcon({ kind: 'badge', code: this.nextBadge()!.badgeCode, iconSize: 26 })
          }
          .width(48)
          .height(48)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.MD)
          Column({ space: 3 }) {
            Text(this.nextBadge()!.badgeName)
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.nextBadge()!.description)
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .lineHeight(17)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(Space.LG)
        .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
        .borderRadius(Radius.MD)
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
        .clip(true)
        .onClick((): void => this.openTask())
      }
      .width('100%')
    }
  }
}
