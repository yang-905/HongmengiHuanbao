import { toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { Biz, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfListRow, CfSection, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 功能特性条目 */
class FeatureItem {
  /** 图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  title: string = '';
  desc: string = '';

  constructor(e: string, t: string, d: string) {
    this.icon = e;
    this.title = t;
    this.desc = d;
  }
}

/** 碳足迹小科普条目 */
class KnowledgeItem {
  /** 语义 code，对应 IconMap 的 ui 表（原先是 emoji，「🚶」这类字符换成矢量图标） */
  code: string = '';
  title: string = '';
  desc: string = '';

  constructor(c: string, t: string, d: string) {
    this.code = c;
    this.title = t;
    this.desc = d;
  }
}

/** 版本号（与 AppScope/app.json5 versionName 保持一致） */
const APP_VERSION: string = '1.0.0'

/** 功能特性 */
const FEATURES: FeatureItem[] = [
  new FeatureItem('ruler', '碳足迹核算', '27 项行为因子，覆盖出行、节水节电、旧物回收、光盘行动'),
  new FeatureItem('robot', 'AI 智能识别', '拍一张照片即可识别行为类型，自动折算减排量'),
  new FeatureItem('coin', '积分激励', '1 kg 减排 = 10 积分，3000 积分可认养 1 棵真树'),
  new FeatureItem('tree', '成长树与徽章', '累计减排养大你的专属成长树，10 枚徽章记录低碳里程碑'),
  new FeatureItem('home', '家庭碳账户', '多设备数据合并，家人一起减排更有动力'),
  new FeatureItem('chart', '数据看板', '趋势、占比、账单多维分析，让每一份努力都看得见')
]

/** 碳足迹小科普 */
const KNOWLEDGE: KnowledgeItem[] = [
  new KnowledgeItem('footprint', '什么是碳足迹',
    '碳足迹是某个人、产品或活动在全生命周期内产生的温室气体排放总量，单位是 kgCO₂e。'),
  new KnowledgeItem('commute', '一次通勤的差别',
    '1 公里出行：私家车约 0.19 kgCO₂e，地铁 0.12 kg，公交 0.10 kg，步行与骑行接近于零。'),
  new KnowledgeItem('plate', '光盘也是减排',
    '全球约三分之一食物被浪费，减少食物浪费是最直接的减排行动之一。'),
  new KnowledgeItem('recycle', '回收的价值',
    '1 千克废纸回收约减少 1.3 kgCO₂e，金属回收的减排效益更高。')
]

/**
 * P30 关于
 * ------------------------------------------------------------------
 * 真实实现：应用 logo / 名称「一触青绿」/ 版本号 / 一句话介绍
 *          + 功能特性列表 + 碳足迹知识小科普 + 数据来源声明
 * 路由名：ABOUT（NavDestination，PageMap 集中注册）
 */
@Component
export struct AboutPage {
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

  private scroller: Scroller = new Scroller()

  /* ---------- 交互 ---------- */

  private checkUpdate(): void {
    toast('已是最新版本 v' + APP_VERSION)
  }

  private openPolicy(): void {
    toast('隐私政策：数据仅存于你的设备与账号，不做广告用途')
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
    }
  }

  /**
   * 页面入场动画状态（苹果口径，见下方最外层容器的 onAppear）。
   * 每次 push 进入本页都会重放到 0→1，观感是「内容错峰上浮」。
   */
  @State private pageIn: boolean = false
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisappear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Column() {
        CfTopBar({
          title: '关于',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.LogoBlock()
            this.FeatureBlock()
            this.KnowledgeBlock()
            this.DataBlock()
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
      .opacity(this.pageIn ? this.themeTick >= 0 ? 1 : 0 : 0)
      .translate({ y: this.pageIn ? 0 : 12 })

    }
    .hideTitleBar(true)
  }

  /* ---------- Logo / 名称 / 版本 ---------- */
  @Builder
  LogoBlock() {
    Column({ space: Space.MD }) {
      // 应用 Logo：主色渐变圆角块 + 品牌字形
      Column() {
        CfIcon({ kind: 'ui', code: 'sprout', iconSize: 44 })
      }
      .width(96)
      .height(96)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
      })
      .borderRadius(Radius.XL)
      .shadow(this.tw(Shadow.brand()))

      Text('一触青绿')
        .fontSize(FontSize.DISPLAY)
        .maxFontScale(FontSize.SCALE_NUM)
        .maxLines(1)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))

      Text('版本 v' + APP_VERSION)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
        .borderRadius(Radius.PILL)

      Text('轻轻一点，记录你的绿色日常')
        .fontSize(FontSize.BODY)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .lineHeight(21)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text('本应用把日常行为折算成碳减排量，帮你把抽象的"低碳"变成看得见的积分、徽章与真实的树。')
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: Space.SM })

      Row() {
        Text('检查更新')
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
          .onClick((): void => this.checkUpdate())
      }
      .width('100%')
      .padding({ top: Space.SM })
    }
    .width('100%')
    .padding(Space.XL)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }

  /* ---------- 功能特性 ---------- */
  @Builder
  FeatureBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '功能特性' })
      Column({ space: Space.SM }) {
        ForEach(FEATURES, (f: FeatureItem) => {
          this.FeatureRow(f)
        }, (f: FeatureItem): string => f.title)
      }
    }
    .width('100%')
  }

  @Builder
  FeatureRow(f: FeatureItem) {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: f.icon, iconSize: 20 })
      Column({ space: 2 }) {
        Text(f.title)
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text(f.desc)
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
  }

  /* ---------- 碳足迹小科普 ---------- */
  @Builder
  KnowledgeBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '碳足迹小科普' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          ForEach(KNOWLEDGE, (k: KnowledgeItem, i: number) => {
            this.KnowledgeRow(k, i)
          }, (k: KnowledgeItem, i: number): string => k.title)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  KnowledgeRow(k: KnowledgeItem, i: number) {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: k.code, iconSize: 20 })
      Column({ space: 3 }) {
        Text(k.title)
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text(k.desc)
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(19)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ bottom: Space.LG })
    .border({ width: { bottom: i < KNOWLEDGE.length - 1 ? 1 : 0 }, color: this.tc(Neutral.BORDER) })
  }

  /* ---------- 数据与声明 ---------- */
  @Builder
  DataBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '数据与声明' })
      CfCard({ pad: Space.LG }) {
        Column() {
          CfListRow({
            icon: 'ruler',
            title: '碳排放因子来源',
            sub: '依据 IPCC 与国家标准《温室气体排放核算通则》',
            right: '',
            showArrow: false,
            onTap: (): void => this.openPolicy()
          })
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
            .margin({ left: 50 })
          CfListRow({
            icon: 'calculator',
            title: '积分换算口径',
            sub: '1 kg CO₂e = ' + Biz.POINTS_PER_KG + ' 积分',
            right: Biz.POINTS_PER_KG + ' 分/kg',
            rightColor: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
            showArrow: false,
            onTap: (): void => {
              toast('换算口径与后端 Biz 常量严格一致')
            }
          })
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
            .margin({ left: 50 })
          CfListRow({
            icon: 'tree',
            title: '植树证书',
            sub: Biz.POINTS_PER_TREE + ' 积分 = 1 棵树的认养凭证',
            right: Biz.POINTS_PER_TREE + ' 分/棵',
            rightColor: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
            showArrow: false,
            onTap: (): void => this.openPolicy()
          })
        }
        .width('100%')
      }
      Text('一触青绿 v' + APP_VERSION + ' · 低碳生活，从我做起')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }
}
