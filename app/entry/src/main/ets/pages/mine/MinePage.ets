import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalStore } from '../../data/LocalStore'
import { LocalBadge, LocalCert, LocalOverview } from '../../data/MockStore'
import { Accent, Biz, FontSize, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood, ThemePalette } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { AccountStore, UserProfile } from '../../data/AccountStore'
import {
  CfBackIcon,
  CfButton,
  CfCard,
  CfEmpty,
  CfGlassDisc,
  CfListRow,
  CfPill,
  CfProgress,
  CfSection,
  CfStatTile
} from '../../ui/Components'
import { CfIcon } from '../../ui/Icon';
import { AppleMotion } from '../../ui/AppleMotion'
import { Clipboard } from '../../utils/Clipboard'

/**

 * 我的页入口项：ArkTS 严格模式下对象字面量必须对应显式类型，故声明 class
 */
class MineEntry {
  /** 图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  title: string = '';
  sub: string = '';
  /** 目标路由，空串表示仅提示（子页未接入） */
  route: string = '';
  /** 右侧文案，空串则不显示 */
  right: string = '';
  /** 右侧文案颜色；留空 = 跟随主题（由 CfListRow 现取 static 值） */
  rightColor: string = '';

  constructor(e: string, t: string, s: string, r: string, right: string, rc: string) {
    this.icon = e;
    this.title = t;
    this.sub = s;
    this.route = r;
    this.right = right;
    this.rightColor = rc;
  }
}

/** 入口分组 */
class MineGroup {
  title: string = '';
  items: MineEntry[] = [];

  constructor(t: string, i: MineEntry[]) {
    this.title = t;
    this.items = i;
  }
}

/**

 * P06 我的（Tab4）
 */
@Component
export struct MinePage {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  @State private ov: LocalOverview = {
    totalKg: 0, todayKg: 0, monthKg: 0, totalPoints: 0, availablePoints: 0, exchangedPoints: 0,
    recordCount: 0, continuousDays: 0, treeCount: 0, badgeCount: 0, level: 1
  }
  @State private badges: LocalBadge[] = []
  @State private certs: LocalCert[] = []
  @State private loading: boolean = true
  @State private online: boolean = true
  /** 当前账号资料（头像/昵称）。ProfilePage 保存后经 profileTick 信号同步回本页 */
  @State private profile: UserProfile = new UserProfile()

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.ov = await DataSource.overview()
      this.badges = await DataSource.badges()
      this.certs = await DataSource.certificates()
      this.online = DataSource.online
      this.loadProfile()
      // 碳惠券包角标：同步重算（@State 赋值触发重渲染 + ForEach 行重建）
      this.couponCount = LocalStore.availableCouponCount()
    } catch (err) {
      // DataSource 内部已兜底，此处仅兜底极端异常
    }
  }

  /** 从账号层读当前用户资料（头像/昵称），切号后经 profileTick 触发重读 */
  private loadProfile(): void {
    this.profile = AccountStore.profileOf(AccountStore.currentUser())
  }
/** 等级进度百分比 */
  private levelPct(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    const span: number = r[1] - r[0];
    if (span <= 0) return 100
    return Math.max(2, Math.min(100, ((this.ov.totalKg - r[0]) / span) * 100))
  }

  /** 距下一级还差多少减排量 */
  private nextLevelKg(): number {
    const r: number[] = Biz.levelRange(this.ov.level)
    return Math.max(0, Math.round((r[1] - this.ov.totalKg) * 100) / 100)
  }

  /** 已解锁徽章数（本地统计，避免依赖服务端口径） */
  private unlockedCount(): number {
    let n: number = 0
    for (let i: number = 0; i < this.badges.length; i++) {
      if (this.badges[i].unlocked) n++
    }
    return n
  }

  /** 已解锁徽章取前 5 枚做缩览 */
  private topBadges(): LocalBadge[] {
    return this.badges.filter((b: LocalBadge): boolean => b.unlocked).slice(0, 5)
  }

  /** 证书总数对应的植树棵数 */
  private certTrees(): number {
    let n: number = 0
    for (let i: number = 0; i < this.certs.length; i++) {
      n += this.certs[i].treeCount
    }
    return n
  }

  /**

   * 可用兑换券数（未使用且未过期）——「碳惠券包」入口角标。
 */
  @State private couponCount: number = 0
private groups(): MineGroup[] {
    const g: MineGroup[] = []
    g.push(new MineGroup('我的低碳资产', [
      new MineEntry('coin', '碳积分', '积分余额 · 流水 · 权益兑换', RouteName.POINTS_HOME,
        this.ov.availablePoints + ' 分', this.tc(EcoTheme.primaryDeep(this.ecoLevel))),
      new MineEntry('badge', '徽章墙', '低碳成就陈列与解锁进度', RouteName.BADGE_WALL,
        this.unlockedCount() + ' 枚', this.tc(Accent.SUCCESS)),
      // 碳惠券包：证书夹上方的二级菜单入口（权益券存放处，7 天有效）
      new MineEntry('ticket', '碳惠券包', '积分兑换的权益券 · 7 天有效', RouteName.COUPON_LIST,
        this.couponCount + ' 张', this.tc(Accent.WARNING)),
      new MineEntry('certificate', '我的证书夹', '积分兑换的植树电子证书', RouteName.CERTIFICATE_LIST,
        this.certs.length + ' 张', this.tc(Accent.INFO)),
      new MineEntry('mall', '积分商城', '碳普惠权益兑换', RouteName.POINTS_MALL, '', '')
    ]))
    g.push(new MineGroup('内容与家庭', [
      new MineEntry('star', '我的收藏', '收藏的双碳科普文章', RouteName.FAVORITE_LIST, '', ''),
      new MineEntry('home', '家庭碳账户', '成员合并统计与减排排行', RouteName.FAMILY, '', ''),
      new MineEntry('bulb', '智慧建议', '今日重点与个性化生活建议', RouteName.SMART_TIPS, '', ''),
      new MineEntry('device', '超级终端', '家庭多设备在线与同步', RouteName.SUPER_TERMINAL, '', '')
    ]))
    g.push(new MineGroup('设置', [
      new MineEntry('settings', '设置', '账号资料 · 报表导出 · 月度账单', RouteName.SETTINGS, '', ''),
      new MineEntry('info', '关于一触青绿', '版本号 · 功能特性', RouteName.ABOUT, 'v1.0.0', '')
    ]))
    return g
  }
private go(route: string): void {
    AppRouter.pathStack.pushPathByName(route, null)
  }

  private onEntryTap(it: MineEntry): void {
    if (it.route.length === 0) {
      toast('「' + it.title + '」子页面正在规划中')
      return
    }
    this.go(it.route)
  }

  /**

   * 分享成绩单：把演示文案写入系统剪贴板并给出反馈（真复制，见 Clipboard）。
   * 文案异步生成（统计走 RDB 聚合查询，2026-10-23）：.then 链式消费，
   * 同步点击回调里不等候。
   */
  private shareMine(): void {
    DataSource.shareText().then((text: string): void => {
      if (Clipboard.copy(text)) {
        toast('低碳成绩单已复制，快去分享给好友')
      } else {
        toast('复制失败，请重试')
      }
    })
  }

  /** 头像点击：进入个人资料页（头像/名字/性别/手机号编辑 + 切换账号） */
  private tapAvatar(): void {
    this.go(RouteName.PROFILE)
  }

  /** 资料保存信号：原地重读头像与昵称（ProfilePage 保存后 pop 回本页即生效） */
  @StorageLink('profileTick') @Watch('onProfileTick') profileTick: number = 0

  onProfileTick(): void {
    this.loadProfile()
  }

  /**

   * 券变更信号（响应式）：兑换 / 核销后 LocalStore.bumpCouponTick +1，
   * 本页据此重拉 —— 「兑完券回到我的，入口角标立刻多一张」靠它。
   * 只订阅 @StorageLink 不够（ArkUI 无 onStorageChange 生命周期），
   * 必须配 @Watch 才会真正回调（全库同款教训，见 onEcoTick 注释）。
   */
  @StorageLink('couponTick') @Watch('onCouponTick') couponTick: number = 0

  onCouponTick(): void {
    this.load()
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

  build() {
    Scroll(this.scroller) {
      Column({ space: Space.LG }) {
        this.Header()
        this.UserCard()
        if (this.ov.recordCount === 0) {
          // 空态：还没有任何低碳记录
          CfCard({}) {
            CfEmpty({
              icon: 'sprout',
              text: '还没有低碳记录',
              sub: '点击底部「记录」，从一次绿色出行开始吧'
            })
          }
        } else {
          this.StatGrid()
          this.AssetBlock()
          this.EntryList()
        }
        this.QuickLinks()
        this.FooterNote()
      }
      .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
      .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 96 })
    }
    .scrollBar(BarState.Off)
    // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
    // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    /*
     * ⚠️ themeTick 恒读钩子必须挂在**本 Scroll 根容器**上（不能只在内部 Column）。
     * 记录/科普是深色，这两个页仍是浅色。
     * 根因：`.backgroundColor(EcoTheme.bgSolid(...))` 挂在 Scroll 上，
     * 而 themeTick 的读取钩子只写在 Scroll **内部的 Column**。
     * 换血时 AppStorage 推 themeTick → 只有订阅它的组件会重建，
     * Scroll 自身没订阅 → **背景色停留在建页那一刻的旧值（浅色）**。
     * 截图特征完全吻合：顶部安全区是深色（Index 根层重建了），
     * 正文却浅色（本页根没重建）。
     * 记录/科普之所以正常，是因为它们的**条目**额外订阅了 themeTick，
     * 条目重建把父级一起带上了；MinePage / DashboardPage 的条目没有
     * 这层订阅，所以只有它俩出问题。
     * 值恒为 1，无视觉影响，只为触发本组件重建、重新读取 static 色值。
     */
    .opacity(this.themeTick >= 0 ? 1 : 0)
    // ⚠️ 本轮改回**半透明 bg()（62%）**（与看板/记录/科普同口径）：
    // 根层实色锚已由 Index 根 Stack 的 bgSolid 提供（Navigation/Tabs 已显式
    // 透明），半透明底落上去不会再遇白；根层的径向环境光晕（EcoTheme.glow）
    // 透过这 38% 上来，玻璃条与卡片的模糊才有「环境纵深」可采样。
    .backgroundColor(this.tc(EcoTheme.bg(this.ecoLevel)))
    // 动态碳主题：背景随当日碳排放档位过渡（全局 AppStorage 驱动）
    /*
     * 不再挂全屏 backdropBlur（原 EcoMood.blurOf）：
     * 一级 Tab 页根节点后方只有 Index 根层的实色底（同色系），
     * 模糊一个纯色 = 视觉零收益，却要常驻一张全屏离屏渲染层；
     * 子页面压住本页时的磨砂效果由子页面自己的根模糊负责，不受影响。
     * 与 Dashboard / RecordList / ArticleList 三页口径一致。
     */
    // 上沿一道高光，模拟玻璃受光面（顶边更亮，视觉上「有厚度」）
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }
@Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: 'mine', iconSize: 20, color: this.tc(Neutral.TEXT) })
          Text('我的')
            .fontSize(FontSize.HEADING)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
        }
        Text('你的每一份绿色，都被记下了')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      if (!this.online) {
        CfPill({ text: '演示模式', tone: 'warning' })
      }
    }
    .width('100%')
  }
@Builder
  UserCard() {
    Column({ space: Space.LG }) {
      Row() {
        // 圆形头像：液态玻璃圆盘（旧版为半透明白底圆，无磨砂质感）
        // 图片头像（相册上传，file:// 沙箱路径）铺满圆盘；emoji 头像维持文字渲染
        CfGlassDisc({ diameter: 58, onTap: (): void => this.tapAvatar() }) {
          if (AccountStore.isImageAvatar(this.profile.avatar)) {
            Image(this.profile.avatar)
              .width(58)
              .height(58)
              .objectFit(ImageFit.Cover)
              .borderRadius(29)
          } else {
            Text(this.profile.avatar)
              .fontSize(30)
              .maxFontScale(FontSize.SCALE_NUM)
          }
        }

        Column({ space: 5 }) {
          Row({ space: Space.SM }) {
            Text(this.profile.name.length > 0 ? this.profile.name : '低碳行者')
              .fontSize(FontSize.HEADING)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            // 等级药丸
            Text('Lv.' + this.ov.level + ' ' + Biz.levelName(this.ov.level))
              .fontSize(FontSize.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
              .padding({ left: 9, right: 9, top: 3, bottom: 3 })
              .backgroundColor(this.tc(ThemePalette.dark ? 'rgba(255,255,255,0.16)' : '#FFFFFF'))
              .borderRadius(Radius.PILL)
          }
          .width('100%')

          Row({ space: 4 }) {
            CfIcon({ kind: 'ui', code: 'flame', iconSize: 13, color: 'rgba(255,255,255,0.88)' })
            Text('已连续打卡 ' + this.ov.continuousDays + ' 天')
              .fontSize(FontSize.SMALL)
              .fontColor('rgba(255,255,255,0.88)')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 更多按钮：玻璃圆盘（与头像同一材质）
        CfGlassDisc({ diameter: 34, onTap: (): void => this.shareMine() }) {
          Text('⋯')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .width('100%')

      // 等级进度
      Column({ space: 5 }) {
        CfProgress({
          percent: this.levelPct(),
          color: '#FFFFFF',
          barHeight: 6,
          track: 'rgba(255,255,255,0.28)'
        })
        Row() {
          Text('累计减排 ' + Biz.formatKg(this.ov.totalKg))
            .fontSize(FontSize.CAPTION)
            .fontColor('#FFFFFF')
          Blank()
          Text(this.ov.level >= 5 ? '已达最高等级' : ('再减 ' + this.nextLevelKg() + ' kg 升级'))
            .fontSize(FontSize.CAPTION)
            .fontColor('rgba(255,255,255,0.9)')
        }
        .width('100%')
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
  StatGrid() {
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        Column() {
          CfStatTile({
            label: '累计减排',
            value: this.ov.totalKg.toFixed(2),
            icon: 'world',
            accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
            tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
          })
        }
        .layoutWeight(1)
        Column() {
          CfStatTile({
            label: '可用积分',
            value: '' + this.ov.availablePoints,
            icon: 'coin',
            accent: this.tc(Accent.WARNING),
            tint: this.tc(Accent.WARNING_BG)
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: Space.MD }) {
        Column() {
          CfStatTile({
            label: '徽章数',
            value: this.unlockedCount() + ' 枚',
            icon: 'badge',
            accent: this.tc(Accent.SUCCESS),
            tint: this.tc(Accent.SUCCESS_BG)
          })
        }
        .layoutWeight(1)
        Column() {
          CfStatTile({
            label: '植树棵数',
            value: this.ov.treeCount + ' 棵',
            icon: 'tree',
            accent: this.tc(Accent.INFO),
            tint: this.tc(Accent.INFO_BG)
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }
@Builder
  AssetBlock() {
    Column({ space: Space.MD }) {
      // 徽章缩览
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          Row({ space: 6 }) {
            CfIcon({ kind: 'ui', code: 'badge', iconSize: 17, color: this.tc(Neutral.TEXT) })
            Text('我的徽章')
              .fontSize(FontSize.TITLE)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(this.unlockedCount() + '/' + this.badges.length)
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
          }
          .width('100%')

          if (this.topBadges().length === 0) {
            CfEmpty({ icon: 'lock', text: '还没有解锁徽章', sub: '完成低碳目标即可点亮徽章' })
          } else {
            Row({ space: Space.SM }) {
              ForEach(this.topBadges(), (b: LocalBadge) => {
                Column({ space: 4 }) {
                  // 图标：emoji 圆形底座，固定尺寸，字体缩放钳死避免撑破圆形
                  Stack() {
                    CfIcon({ kind: 'badge', code: b.badgeCode, iconSize: 22 })
                  }
                  .width(42)
                  .height(42)
                  .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
                  .borderRadius(21)
                  // 名称：宽度跟随槽位而非写死 46vp。
                  // 写死宽度时「连续 7 天」这类长名会被逐字竖排并溢出圆形，
                  // 这里让槽位均分宽度 + 单行省略号，名字再长也只占一行。
                  Text(b.badgeName)
                    .fontSize(FontSize.CAPTION)
                    .maxFontScale(FontSize.SCALE_NUM)
                    .fontColor(this.tc(Neutral.TEXT_MUTED))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                .onClick((): void => this.go(RouteName.BADGE_WALL))
              }, (b: LocalBadge): string => b.badgeCode)
            }
            .width('100%')
          }
        }
        .width('100%')
      }

      // 证书夹摘要：液态玻璃卡（与徽章缩览卡同材质）
      CfCard({ pad: Space.LG, glass: true }) {
        Row({ space: Space.MD }) {
          Stack() {
            CfIcon({ kind: 'ui', code: 'certificate', iconSize: 22 })
          }
          .width(44)
          .height(44)
          .backgroundColor(this.tc(Accent.INFO_BG))
          .borderRadius(Radius.SM)
          Column({ space: 3 }) {
            Text('我的证书夹')
              .fontSize(FontSize.BODY)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.certs.length > 0
              ? (this.certs.length + ' 张证书 · 累计认种 ' + this.certTrees() + ' 棵树')
              : '还没有兑换证书，去积分商城看看')
              .fontSize(FontSize.SMALL)
              .maxFontScale(FontSize.SCALE_TEXT)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          // '›' 字符走字体回退可能不继承 fontColor → 改用矢量箭头
          CfBackIcon({
            iconSize: 18,
            color: this.tc(Neutral.TEXT_MUTED),
            pointRight: true
          })
        }
        .width('100%')
        .onClick((): void => this.go(RouteName.CERTIFICATE_LIST))
      }
    }
    .width('100%')
  }
@Builder
  EntryList() {
    Column({ space: Space.LG }) {
      ForEach(this.groups(), (g: MineGroup) => {
        this.GroupBlock(g)
      }, (g: MineGroup): string => {
        // ⚠️ 键必须掺入行尾动态文案（right）：ForEach 键稳定时复用旧子树、
        // itemGenerator 不重新执行，行内「N 张 / N 分」永远冻结在首帧值
        // （用户实测：兑换成功后「碳惠券包」仍显示 0 张）。与趋势图表
        // 「ForEach 键必须包含动态数值」同一条铁律。
        // ⚠️ 还要掺 themeTick：深色换血靠 themeTick 广播，若只靠行组件的
        //   tc() 重建，ForEach 复用场景下会概率失效（用户实测：切换深色
        //   模式后子菜单小字概率停留浅色套值、压深底看不清）。键变 →
        //   整组行强制全新构造，所有 static 色值必然现取，杜绝复用残留。
        let ks: string = g.title + '#tt' + this.themeTick.toString()
        for (let i = 0; i < g.items.length; i++) {
          ks += '#' + g.items[i].right
        }
        return ks
      })
    }
    .width('100%')
  }

  @Builder
  GroupBlock(g: MineGroup) {
    Column({ space: Space.MD }) {
      CfSection({ title: g.title })
      CfCard({ pad: Space.LG }) {
        Column() {
          ForEach(g.items, (it: MineEntry, i: number) => {
            CfListRow({
              icon: it.icon,
              tone: IconTone.ofUi(it.icon),
              title: it.title,
              sub: it.sub,
              right: it.right,
              rightColor: it.rightColor,
              onTap: (): void => this.onEntryTap(it)
            })
            if (i < g.items.length - 1) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor(this.tc(Neutral.BORDER))
                .margin({ left: 50 })
            }
          }, (it: MineEntry): string => it.title + '#' + it.right)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  QuickLinks() {
    Row({ space: Space.SM }) {
      Column() {
        CfButton({
          text: '设置',
          icon: 'settings',
          block: true,
          primary: false,
          onTap: (): void => this.go(RouteName.SETTINGS)
        })
      }
      .layoutWeight(1)

      Column() {
        CfButton({
          text: '关于',
          icon: 'bulb',
          block: true,
          primary: false,
          onTap: (): void => this.go(RouteName.ABOUT)
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
@Builder
  FooterNote() {
    Column({ space: Space.MD }) {
      Text('低碳不是一次冲刺，而是每天一点点')
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text('一触青绿 v1.0.0 · 单机版：全部数据仅保存在本机')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }
}
