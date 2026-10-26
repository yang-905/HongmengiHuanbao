import { toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalFactor } from '../../data/MockStore'
import { Accent, CategoryMeta, FontSize, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfEmpty, CfPill, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 分类分栏 */
interface CategoryTab {
  key: string;
  name: string;
  /** 图标 code（IconMap 的 ui 表） */
  icon: string;
}

/**
 * P09 碳排放因子库
 * ------------------------------------------------------------------
 * 路由名：FACTOR_LIB（NavDestination，PageMap 集中注册）
 * 真实实现：全部 + 四大类分栏，每项因子一张卡（图标/名称/单位/因子值/默认量）
 * 点击卡片唤起行为录入面板，并把该因子预选
 */
@Component
export struct FactorLibPage {
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
  @State private factors: LocalFactor[] = []
  @State private tab: string = 'all'
  @State private loading: boolean = true

  private scroller: Scroller = new Scroller()

  private tabs: CategoryTab[] = [
    { key: 'all', name: '全部', icon: 'sprout' },
    { key: CategoryMeta.TRAVEL, name: '绿色出行', icon: CategoryMeta.icon(CategoryMeta.TRAVEL) },
    { key: CategoryMeta.ENERGY, name: '节水节电', icon: CategoryMeta.icon(CategoryMeta.ENERGY) },
    { key: CategoryMeta.RECYCLE, name: '旧物回收', icon: CategoryMeta.icon(CategoryMeta.RECYCLE) },
    { key: CategoryMeta.FOOD, name: '光盘行动', icon: CategoryMeta.icon(CategoryMeta.FOOD) }
  ]

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.factors = await DataSource.factors()
    } catch (err) {
      this.factors = []
    }
  }

  /* ---------- 展示辅助 ---------- */

  /** 当前分栏下的因子 */
  private visible(): LocalFactor[] {
    if (this.tab === 'all') return this.factors
    return this.factors.filter((f: LocalFactor): boolean => f.category === this.tab)
  }

  private fmtNum(n: number): string {
    const v: number = Math.round(n * 1000) / 1000
    if (Math.abs(v - Math.round(v)) < 0.0001) {
      return '' + Math.round(v)
    }
    return v.toFixed(3)
  }

  /** 按默认量试算的减排量，用于卡片右侧提示 */
  private previewKg(f: LocalFactor): number {
    return Math.round(f.factorValue * f.defaultAmount * 1000) / 1000
  }

  /* ---------- 交互 ---------- */

  private pickTab(key: string): void {
    if (this.tab === key) return
    this.tab = key
  }

  /** 点击因子 → 打开录入面板，并按 itemId 预选该因子 */
  private useFactor(f: LocalFactor): void {
    // 预选项写入 AppStorage，由 BehaviorAddSheet 消费后高亮对应因子
    AppStorage.set('presetItemId', f.itemId)
    AppStorage.set('showAddSheet', true)
    toast('已带入「' + f.itemName + '」，填写数量即可记录')
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
            title: '碳排放因子库',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          this.TabBar()
          if (this.visible().length === 0) {
            Column() {
              CfEmpty({ icon: 'book', text: '该分类暂无因子', sub: '换个分类看看，或稍后重试' })
            }
            .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll(this.scroller) {
              Column({ space: Space.MD }) {
                this.HintBar()
                ForEach(this.visible(), (f: LocalFactor) => {
                  this.FactorCard(f)
                }, (f: LocalFactor): string => f.itemCode)
                Text('共 ' + this.visible().length + ' 项因子 · 口径来源：国家温室气体排放因子数据库')
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding({ top: Space.SM, bottom: Space.MD })
              }
              .width('100%')
              .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.SM, bottom: Space.XL })
            }
            .scrollBar(BarState.Off)
            // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
            // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
            .edgeEffect(EdgeEffect.None)
            .width('100%')
            .layoutWeight(1)
          }
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

  /* ---------- 顶部 5 个分栏 ---------- */
  @Builder
  TabBar() {
    Scroll() {
      Row({ space: Space.SM }) {
        ForEach(this.tabs, (t: CategoryTab) => {
          this.TabChip(t.key, t.icon, t.name)
        }, (t: CategoryTab): string => t.key)
      }
      .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.XS, bottom: Space.SM })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
    // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
    .edgeEffect(EdgeEffect.None)
    .width('100%')
  }

  @Builder
  TabChip(key: string, icon: string, name: string) {
    Row({ space: 5 }) {
      CfIcon({
        kind: 'ui',
        code: icon,
        iconSize: 13,
        // 选中态压在主色药丸上，必须反白；未选中给本类色
        color: this.tab === key ? '#FFFFFF' : this.tc(IconTone.color(IconTone.ofCategory(key)))
      })
      Text(name)
        .fontSize(FontSize.SMALL)
        .fontWeight(this.tab === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.tab === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
    }
    .padding({ left: 13, right: 13, top: 8, bottom: 8 })
    .backgroundColor(this.tab === key ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.CARD))
    .borderRadius(Radius.PILL)
    .shadow(this.tab === key ? this.tw(Shadow.brand()) : this.tw(Shadow.card()))
    .onClick((): void => this.pickTab(key))
  }

  /* ---------- 说明条 ---------- */
  @Builder
  HintBar() {
    Row({ space: Space.MD }) {
      Row()
        .width(3)
        .height(14)
        .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
        .borderRadius(2)
      Text('点击任一因子即可带入录入面板，系统按「数量 × 因子值」自动核算减排')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .layoutWeight(1)
        .lineHeight(17)
    }
    .width('100%')
    .padding({ top: Space.XS, bottom: Space.XS })
  }

  /* ---------- 单个因子卡 ---------- */
  @Builder
  FactorCard(f: LocalFactor) {
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        Column() {
          CfIcon({ kind: 'factor', code: f.itemCode, iconSize: 22, tone: IconTone.ofCategory(f.category) })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.tc(CategoryMeta.bg(f.category)))
        .borderRadius(Radius.SM)

        Column({ space: 5 }) {
          Row({ space: 6 }) {
            Text(f.itemName)
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            CfPill({ text: f.unit, tone: 'muted' })
          }
          .width('100%')

          // 因子值：1 单位行为对应的碳排放
          Row({ space: 4 }) {
            Text('因子值')
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
            Text(this.fmtNum(f.factorValue))
              .fontSize(FontSize.TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(CategoryMeta.color(f.category)))
            Text('kg / ' + f.unit)
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(Neutral.TEXT_SUB))
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('去记录')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .width(66)
            .height(30)
            .textAlign(TextAlign.Center)
            .linearGradient({
              angle: 90,
              colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
            })
            .borderRadius(Radius.PILL)
          Text('默认 ' + this.fmtNum(f.defaultAmount) + ' ' + f.unit)
            .fontSize(10)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 分割线
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(this.tc(Neutral.BORDER))

      // 默认量试算：约减多少 / 约得多少分
      Row() {
        Row({ space: 4 }) {
          Text('按默认量可减')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text(this.previewKg(f) + ' kg')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Accent.SUCCESS))
        }
        Blank()
        Row({ space: 4 }) {
          Text('约')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text('' + Math.max(1, Math.round(this.previewKg(f) * 10)))
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Accent.WARNING))
          Text('积分')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
    .onClick((): void => this.useFactor(f))
  }
}