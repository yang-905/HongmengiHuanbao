import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { goWithParam } from '../../common/router/PageMap'
import { DataSource } from '../../net/DataSource'
import { LocalOverview } from '../../data/MockStore'
import { Biz, Brand, FontSize, Neutral, Radius, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { AccountStore, UserProfile } from '../../data/AccountStore'
import { ThemeMode } from '../../data/ThemeMode'
import { GlassQualityLevel } from '../../ui/GlassLight'
import { CfCard, CfListRow, CfSection, CfTopBar, CfSwitchRow } from '../../ui/Components'
import { EcoDebugSheet } from './EcoDebugSheet'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 设置项：分组内的单行条目 */
class SettingItem {
  /** 图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  title: string = '';
  sub: string = '';
  /** 目标路由，空串表示仅提示（未接入子页） */
  route: string = '';
  /** 右侧文案，空串则不显示 */
  right: string = '';

  constructor(e: string, t: string, s: string, r: string, right: string) {
    this.icon = e;
    this.title = t;
    this.sub = s;
    this.route = r;
    this.right = right;
  }
}

/** 设置分组 */
class SettingGroup {
  title: string = '';
  items: SettingItem[] = [];

  constructor(t: string, i: SettingItem[]) {
    this.title = t;
    this.items = i;
  }
}

/**

 * P24 设置
 */
@Component
export struct SettingsPage {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  @StorageProp('themeTick') @Watch('onThemeTick') themeTick: number = 0
  @State private level: number = 1
  @State private totalKg: number = 0
  @State private continuousDays: number = 0
  @State private recordCount: number = 0
  /** 最近一条记录的 id：设置页「低碳记录」入口跳详情用（-1 = 尚无记录） */
  @State private latestRecordId: number = -1
  @State private loading: boolean = true
  /** 碳情绪调试面板是否展开（由「开发者」分组直接打开） */
  @State private showDebug: boolean = false
  /**
   * 深色模式开关状态。
 */
  @State private darkOn: boolean = false
  /** 重新渲染开关：瞬时动作，触发后自动弹回（见 onRerender） */
  @State private rerenderFlash: boolean = false
  /** 玻璃画质档位（静态字段的本地镜像，供 UI 高亮） */
  @State private quality: string = GlassQualityLevel.CINEMATIC
  /** 当前账号资料（账号卡头像/昵称展示），ProfilePage 保存后经 profileTick 同步 */
  @State private profile: UserProfile = new UserProfile()

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
    // 画质档位存在 GlassLight 静态字段里（非响应式），
    // 进入页面时同步一次当前值供档位 chips 高亮
    this.quality = ThemeMode.quality()
    // 深色开关同样回读静态状态（启动时 ThemeMode.init 已换血）
    this.darkOn = ThemeMode.isDark()
    this.loadProfile()
  }

  private loadProfile(): void {
    this.profile = AccountStore.profileOf(AccountStore.currentUser())
  }

  /** 资料保存信号（ProfilePage 广播）：原地重读账号卡头像/昵称 */
  @StorageLink('profileTick') @Watch('onProfileTick') profileTick: number = 0

  onProfileTick(): void {
    this.loadProfile()
  }

  private async load(): Promise<void> {
    try {
      const ov: LocalOverview = await DataSource.overview()
      this.level = ov.level
      this.totalKg = ov.totalKg
      this.continuousDays = ov.continuousDays
      this.recordCount = ov.recordCount
      /*
       * 顺带取最近一条记录的 id：设置页「低碳记录」入口要用它跳详情
       * （见 groups() 注释 —— 早前不传 id 导致详情页永远空态）。
       * 列表按时间倒序返回，取第 0 条即可；没有记录时保持 -1，
       * 由 openDetail 给出「还没有记录」的提示而不是跳进空页面。
       */
      const list = await DataSource.records()
      this.latestRecordId = list.length > 0 ? list[0].recordId : -1
    } catch (err) {
      // DataSource 内部已兜底
    }
  }
private groups(): SettingGroup[] {
    const g: SettingGroup[] = []
    g.push(new SettingGroup('账号资料', [
      new SettingItem('user', '个人资料', '头像 · 名字 · 性别 · 手机号', RouteName.PROFILE, 'Lv.' + this.level),
      new SettingItem('sprout', '我的等级', Biz.levelName(this.level) + ' · 累计 ' + this.totalKg.toFixed(2) + ' kg',
        RouteName.LEVEL_TREE, Biz.levelName(this.level)),
      /**
       * ⚠️ 这里曾直接 push BEHAVIOR_DETAIL 却不带 detailRecordId，
 */
      new SettingItem('edit', '低碳记录', '共 ' + this.recordCount + ' 条行为记录',
        RouteName.BEHAVIOR_DETAIL, this.recordCount + ' 条')
    ]))
    g.push(new SettingGroup('数据与备份', [
      new SettingItem('cloud', '备份与云同步', '多设备数据一致 · 离线队列补传', RouteName.BACKUP_MANAGE, ''),
      new SettingItem('upload', '报表导出', '月报预览与导出', RouteName.EXPORT_REPORT, ''),
      new SettingItem('receipt', '月度绿色账单', '每月减排账单与对比', RouteName.MONTH_BILL, '')
    ]))
    /*
     * 「家庭与设备」分组（家庭碳账户 / 超级终端）已按用户要求从设置页移除。
     * 底层不动：FAMILY / SUPER_TERMINAL 路由与对应页面原样保留，
     * 后续需要时把 push 加回来即可恢复入口。
     */
    g.push(new SettingGroup('智慧服务', [
      new SettingItem('bulb', '全部建议', '今日重点与个性化生活建议', RouteName.SMART_TIPS, ''),
      new SettingItem('article', '科普专栏', '双碳知识与减碳技巧', '', ''),
      new SettingItem('star', '我的收藏', '收藏的文章列表', RouteName.FAVORITE_LIST, '')
    ]))
    g.push(new SettingGroup('其他', [
      new SettingItem('info', '关于', '版本号 · 功能特性 · 碳足迹知识', RouteName.ABOUT, 'v1.0.0'),
      new SettingItem('gift', '积分商城', '积分兑换低碳权益', RouteName.POINTS_MALL, ''),
      new SettingItem('badge', '徽章墙', '低碳成就陈列', RouteName.BADGE_WALL, '')
    ]))
    return g
  }
private onItemTap(it: SettingItem): void {
    // 「关于」是调试入口的解锁键：连点 7 次才显形
    if (it.route === RouteName.ABOUT) {
      this.tapAbout()
      return
    }
    // 「低碳记录」必须带 recordId 进详情，否则详情页读不到参数直接空态
    if (it.route === RouteName.BEHAVIOR_DETAIL) {
      this.openLatestRecord()
      return
    }
    if (it.route.length === 0) {
      toast('「' + it.title + '」子页面正在规划中')
      return
    }
    AppRouter.pathStack.pushPathByName(it.route, null)
  }

  /**

   * 打开最近一条低碳记录的详情。
   * 走 goWithParam 与记录列表页同一路径（AppStorage 传参 → aboutToAppear 读取），
   * 保证两条入口行为一致。一条记录都没有时不跳空页面，直接给提示。
   */
  private openLatestRecord(): void {
    if (this.latestRecordId < 0) {
      toast('还没有低碳记录，先去记录一笔吧')
      return
    }
    goWithParam(RouteName.BEHAVIOR_DETAIL, 'detailRecordId', this.latestRecordId)
  }

  /**

   * 「关于」连点解锁调试面板。
 */
  private tapAbout(): void {
    // 「关于」是正常入口，点它就该跳关于页。
    // ⚠️ 曾把调试解锁逻辑挂在这里，导致每次点击都跳走、用户点不满 7 次；
    //    现已移除连点机制，调试入口改为「开发者」分组的直接可见项。
    AppRouter.pathStack.pushPathByName(RouteName.ABOUT, null)
  }

  private clearData(): void {
    toast('演示环境暂不支持清空数据')
  }

  /**

   * 强制全应用重新拉取数据。
 */
  private rerenderAll(): void {
    EcoMoodState.broadcastDataChange()
    toast('已重新渲染全应用数据')
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
    if (key === 'themeTick') {
      // 深色/画质/重新渲染都会推 themeTick：回读静态字段，
      // 让开关与档位 chips 与全局状态保持一致
      this.darkOn = ThemeMode.isDark()
      this.quality = ThemeMode.quality()
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
          title: '设置',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.AccountCard()
            /*
             * 外观分组紧跟账号卡：深色模式是高频开关，
             * 放在首屏一屏内可达的位置（曾考虑放页面最底部，否决）。
             */
            this.AppearanceSection()
            /*
             * 开发者分组放在「数据管理」之前 ——
             * 调试入口最怕的就是「用户找不到」，之前放在页面最底部
             * 需要下滑到底才看得见，现挪到中段位置，一屏内可达。
             */
            this.DevSection()
            this.GroupList()
            this.DangerZone()
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

      // 页面底色必须铺到根节点：根 Column 不上色时，CfTopBar 后面
      // 露出 NavDestination 默认白底，深色模式下就是顶部一条浅色横带
      //（Scroll 只盖住自身区域，顶栏区域无人上色）
      .backgroundColor(this.ecoBg())
      /*
       * 调试面板（bindSheet 半模态）。
       * onDisappear 必须复位 showDebug：dragBar 允许下滑关闭，
       * 系统不会回写绑定变量，开关仍是 true 时再次解锁不会弹出。
       */
      .bindSheet(this.showDebug, this.DebugSheetContent(), {
        height: SheetSize.LARGE,
        dragBar: true,
        onDisappear: (): void => {
          this.showDebug = false
        }
      })
    }
    .hideTitleBar(true)
  }
@Builder
  DebugSheetContent() {
    EcoDebugSheet({
      onClose: (): void => {
        this.showDebug = false
      }
    })
  }
@Builder
  AccountCard() {
    Row() {
      // 图片头像（相册上传，file:// 沙箱路径）直接铺圆；emoji 头像维持文字渲染
      if (AccountStore.isImageAvatar(this.profile.avatar)) {
        Image(this.profile.avatar)
          .width(58)
          .height(58)
          .objectFit(ImageFit.Cover)
          .borderRadius(Radius.PILL)
      } else {
        Text(this.profile.avatar)
          .fontSize(30)
          .width(58)
          .height(58)
          .textAlign(TextAlign.Center)
          .backgroundColor('rgba(255,255,255,0.22)')
          .borderRadius(Radius.PILL)
      }

      Column({ space: 3 }) {
        Text(this.profile.name.length > 0 ? this.profile.name : '低碳行者')
          .fontSize(FontSize.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Biz.levelName(this.level) + ' · 连续打卡 ' + this.continuousDays + ' 天')
          .fontSize(FontSize.CAPTION)
          .fontColor('rgba(255,255,255,0.88)')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 2 }) {
        Text('Lv.' + this.level)
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('累计 ' + Biz.formatKg(this.totalKg))
          .fontSize(FontSize.CAPTION)
          .fontColor('rgba(255,255,255,0.88)')
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(Space.XL)
    .linearGradient({
      angle: 135,
      colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
    })
    .borderRadius(Radius.XL)
    .onClick((): void => {
      AppRouter.pathStack.pushPathByName(RouteName.PROFILE, null)
    })
  }
/**
 * 外观分组。
 */
  @Builder
  AppearanceSection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '外观' })
      CfCard({ pad: Space.LG }) {
        Column() {
          CfSwitchRow({
            icon: 'moon',
            title: '深色模式',
            sub: this.darkDesc(),
            on: this.darkOn,
            onChange: (on: boolean): void => this.onDarkChange(on)
          })
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
            .margin({ left: 50 })
          CfSwitchRow({
            icon: 'refresh',
            title: '重新渲染',
            sub: '强制重建全部界面：主题、配色、玻璃光照一并刷新',
            on: this.rerenderFlash,
            onChange: (on: boolean): void => this.onRerender(on)
          })
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
            .margin({ left: 50 })
          /* 玻璃画质：三档降级（统一光照模型的性能开关） */
          Row({ space: Space.MD }) {
            Stack({ alignContent: Alignment.Center }) {
              CfIcon({ kind: 'ui', code: 'photo', iconSize: 20 })
            }
            .width(38)
            .height(38)
            .backgroundColor(this.tc(Brand.PRIMARY_PALE))
            .borderRadius(Radius.SM)
            Column({ space: 2 }) {
              Text('玻璃画质')
                .fontSize(FontSize.BODY)
                .fontColor(this.tc(Neutral.TEXT))
                .fontWeight(FontWeight.Medium)
              Text(this.qualityDesc())
                .fontSize(FontSize.SMALL)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: Space.MD, bottom: Space.SM })

          Row({ space: Space.SM }) {
            this.QualityChip('流畅', GlassQualityLevel.LITE)
            this.QualityChip('均衡', GlassQualityLevel.BALANCED)
            this.QualityChip('电影', GlassQualityLevel.CINEMATIC)
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 画质档位 chip（选中 = 主题实底；未选 = 次级面底） */
  @Builder
  QualityChip(label: string, key: string) {
    Text(label)
      .fontSize(FontSize.CAPTION)
      .fontColor(this.quality === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.quality === key ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.SURFACE))
      .borderRadius(Radius.PILL)
      .onClick((): void => this.onQualityPick(key))
  }

  /** 深色模式副标题：说明当前状态与碳情绪反馈的联动 */
  private darkDesc(): string {
    if (this.darkOn) {
      return '深炭绿界面；碳情绪反馈同步切换为深色调染'
    }
    return '奶油白界面；碳情绪四档配色随今日排放变化'
  }

  /** 画质档位副标题 */
  private qualityDesc(): string {
    const q: string = this.quality
    if (q === GlassQualityLevel.LITE) return '流畅：零光照层、零模糊，只留底色描边（最省电）'
    if (q === GlassQualityLevel.CINEMATIC) return '电影：4 层光照 + 满值实时模糊（默认，最耗电）'
    return '均衡：3 层光照 + 七成模糊，砍掉左侧边缘反射'
  }

  /**

   * themeTick 变化（@Watch 驱动）：回读深色/画质状态，让开关与档位 chips
   * 与全局状态保持一致。此前 onStorageChange('themeTick') 写了回读逻辑，
   * 却没有任何 @Watch 调用它，导致拨动开关后本页 darkOn 不更新、开关不翻面。
   */
  onThemeTick(): void {
    this.darkOn = ThemeMode.isDark()
    this.quality = ThemeMode.quality()
  }

  /** 深色模式开关：换血色值令牌并广播重渲染 */
  private onDarkChange(on: boolean): void {
    // 即时翻面，避免依赖异步重建的视觉延迟
    this.darkOn = on
    ThemeMode.setDark(on)
    toast(on ? '已开启深色模式' : '已关闭深色模式')
  }

  /**

   * 重新渲染开关（瞬时动作）。
   * 打开 → 推 themeTick 强制全应用界面重建 → 900ms 后自动弹回，
   * 避免开关停在「开」让用户误以为是持续状态。
   */
  private onRerender(on: boolean): void {
    if (!on) return
    ThemeMode.bumpRender()
    toast('已重新渲染全部界面')
    setTimeout((): void => {
      this.rerenderFlash = false
    }, 900)
  }

  /** 画质档位选择 */
  private onQualityPick(key: string): void {
    if (this.quality === key) return
    ThemeMode.setQuality(key)
    this.quality = key
    toast('玻璃画质已切换为「' + this.qualityLabel(key) + '」')
  }

  /** 档位 key → 展示名 */
  private qualityLabel(key: string): string {
    if (key === GlassQualityLevel.LITE) return '流畅'
    if (key === GlassQualityLevel.CINEMATIC) return '电影'
    return '均衡'
  }
@Builder
  GroupList() {
    Column({ space: Space.LG }) {
      ForEach(this.groups(), (g: SettingGroup) => {
        this.GroupBlock(g)
      }, (g: SettingGroup): string => g.title)
    }
    .width('100%')
  }

  @Builder
  GroupBlock(g: SettingGroup) {
    Column({ space: Space.MD }) {
      CfSection({ title: g.title })
      CfCard({ pad: Space.LG }) {
        Column() {
          ForEach(g.items, (it: SettingItem, i: number) => {
            CfListRow({
              icon: it.icon,
              title: it.title,
              sub: it.sub,
              right: it.right,
              rightColor: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
              onTap: (): void => this.onItemTap(it)
            })
            if (i < g.items.length - 1) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor(this.tc(Neutral.BORDER))
                .margin({ left: 50 })
            }
          }, (it: SettingItem): string => it.title)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  DangerZone() {
    Column({ space: Space.MD }) {
      CfSection({ title: '数据管理' })
      CfCard({ pad: Space.LG }) {
        Column() {
          /*
           * 「刷新数据」常驻入口（不隐藏）。
           * 与外观分组的「重新渲染」开关分工不同：
           *   重新渲染 = 重建**界面**（themeTick：主题/配色/光照）；
           *   刷新数据 = 重拉**数据**（ecoTick：记录/统计/档位）。
           * 本操作**不改变任何显示数据**，只是强制全应用重新拉取本地数据，
           * 因此对普通用户也无害：预览器里记录完行为看不到新记录时，
           * 点一下即可刷出来。
           */
          CfListRow({
            icon: 'refresh',
            title: '刷新数据',
            sub: '强制刷新全应用数据（预览器调试用）',
            right: '',
            onTap: (): void => this.rerenderAll()
          })
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))
          CfListRow({
            icon: 'trash',
            title: '清空本地数据',
            sub: '需二次确认，操作不可恢复',
            right: '',
            onTap: (): void => this.clearData()
          })
        }
        .width('100%')
      }
      Text('一触青绿 v1.0.0 · 演示环境数据为本地模拟')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }
/**
 * 开发者分组。
 */
  @Builder
  DevSection() {
    Column({ space: Space.MD }) {
      CfSection({ title: '开发者' })
      CfCard({ pad: Space.LG }) {
        Column() {
          /*
           * 调试入口：直接打开碳情绪调试面板。
           * 面板可强制切换 eco/good/warn/alert 档位，用于验证全应用配色适配。
           */
          CfListRow({
            icon: 'flask',
            title: '碳情绪调试面板',
            sub: this.devDebugDesc(),
            right: '',
            onTap: (): void => this.openDevPanel()
          })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 调试面板入口的副标题：显示当前档位，让入口状态一目了然 */
  private devDebugDesc(): string {
    const forced: string = EcoMoodState.overrideLevel()
    if (forced.length > 0) {
      return '已强制档位：' + this.levelLabel(forced) + '（点此切换/恢复）'
    }
    return '强制切换碳情绪档位，验证各档配色适配'
  }

  /** 档位 key → 中文名 */
  private levelLabel(key: string): string {
    if (key === 'eco') return '生态极佳'
    if (key === 'good') return '状态良好'
    if (key === 'warn') return '接近阈值'
    if (key === 'alert') return '超出阈值'
    return '无数据'
  }

  /** 打开调试面板 */
  private openDevPanel(): void {
    this.showDebug = true
  }
}
