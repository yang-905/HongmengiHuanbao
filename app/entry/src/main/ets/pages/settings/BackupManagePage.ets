import { Toast, toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalOverview } from '../../data/MockStore'
import { LocalStore } from '../../data/LocalStore'
import { Accent, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfSection, CfStatTile, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * P25 数据备份与恢复（单机版）
 */
@Component
export struct BackupManagePage {
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
  @State private backing: boolean = false
  @State private lastBackup: string = ''
  @State private backupCount: number = 0
  @State private factorCount: number = 27

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    try {
      this.ov = await DataSource.overview()
      this.factors()
      this.lastBackup = await LocalStore.lastBackupTime()
      this.backupCount = await LocalStore.backupCount()
    } catch (err) {
      // DataSource 内部已兜底
    }
  }

  private async factors(): Promise<void> {
    const list = await DataSource.factors()
    this.factorCount = list.length
  }
private doBackup(): void {
    if (this.backing) return
    this.backing = true
    LocalStore.backup().then((n: number): void => {
      this.backing = false
      this.backupCount = n
      this.load()
      toast('已备份 ' + this.ov.recordCount + ' 条记录到本机')
    }).catch((): void => {
      this.backing = false
      toast('备份失败')
    })
  }

  private doRestore(): void {
    Toast.confirmWith(
      '恢复数据',
      '将用最近一次备份覆盖当前数据，当前未备份的修改会丢失。确定继续？',
      [
        { text: '取消', color: this.tc(Neutral.TEXT_SUB) },
        { text: '确定恢复', color: this.tc(EcoTheme.primaryDeep(this.ecoLevel)) }
      ],
      1
    ).then((ok: boolean): void => {
      if (!ok) {
        toast('已取消')
        return
      }
      LocalStore.restore().then((n: number): void => {
        // 统一信号：各页面 onStorageChange('ecoTick') 会重算档位 + 重拉数据
        EcoMoodState.broadcastDataChange()
        this.load()
        toast('已恢复 ' + n + ' 条记录')
      }).catch((): void => {
        toast('没有可用的备份')
      })
    })
  }

  private doClear(): void {
    Toast.confirmWith(
      '清空数据',
      '将删除本机全部 ' + this.ov.recordCount + ' 条低碳记录，且不可恢复。确定继续？',
      [
        { text: '我再想想', color: this.tc(Neutral.TEXT_SUB) },
        { text: '确认清空', color: this.tc(Accent.DANGER) }
      ],
      1
    ).then((ok: boolean): void => {
      if (!ok) {
        toast('已取消清空')
        return
      }
      LocalStore.clear().then((): void => {
        EcoMoodState.broadcastDataChange()
        this.load()
        toast('已清空全部本地数据')
      })
    })
  }

  /** 恢复演示数据，方便重新体验 */
  private doRestoreDemo(): void {
    LocalStore.restoreDemo().then((): void => {
      EcoMoodState.broadcastDataChange()
      this.load()
      toast('已恢复演示数据')
    })
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
          title: '数据备份',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.LocalStatCard()
            this.ActionCard()
            this.DeviceCard()
            this.TipCard()
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
@Builder
  LocalStatCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '本机数据' })
      if (this.ov.recordCount === 0) {
        CfCard({}) {
          CfEmpty({
            icon: 'folder',
            text: '暂无本地数据',
            sub: '记录几条低碳行为后即可备份'
          })
        }
      } else {
        // 用 Row + layoutWeight 显式分列替代 Grid：Grid 的列宽约束传不到子节点，
        // 文字被系统字体放大后会逐字竖排并撑出卡片
        Column({ space: Space.MD }) {
          Row({ space: Space.MD }) {
            Column() {
              CfStatTile({
                label: '低碳记录',
                value: '' + this.ov.recordCount,
                icon: 'record',
                accent: this.tc(EcoTheme.primaryDeep(this.ecoLevel)),
                tint: this.tc(EcoTheme.primaryPale(this.ecoLevel))
              })
            }
            .layoutWeight(1)
            Column() {
              CfStatTile({
                label: '累计减排',
                value: this.ov.totalKg.toFixed(2),
                icon: 'world',
                accent: this.tc(Accent.SUCCESS),
                tint: this.tc(Accent.SUCCESS_BG)
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Row({ space: Space.MD }) {
            Column() {
              CfStatTile({
                label: '碳积分',
                value: '' + this.ov.totalPoints,
                icon: 'coin',
                accent: this.tc(Accent.WARNING),
                tint: this.tc(Accent.WARNING_BG)
              })
            }
            .layoutWeight(1)
            Column() {
              CfStatTile({
                label: '因子库',
                value: this.factorCount + ' 项',
                icon: 'book',
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

        Row({ space: Space.SM }) {
          CfIcon({ kind: 'ui', code: 'clock', iconSize: 14 })
          Text('最近备份：')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text(this.lastBackup.length > 0 ? this.lastBackup : '从未备份')
            .fontSize(FontSize.SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.lastBackup.length > 0 ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_MUTED))
          Blank()
          if (this.lastBackup.length > 0) {
            CfPill({ text: '可恢复', tone: 'success' })
          }
        }
        .width('100%')
        .padding(Space.LG)
        .backgroundColor(this.tc(Neutral.CARD))
        .borderRadius(Radius.MD)
        .shadow(this.tw(Shadow.card()))
      }
    }
    .width('100%')
  }
@Builder
  ActionCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '备份与恢复' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          this.ActionRow('download', '备份', '把当前全部数据快照到本机', this.tc(EcoTheme.primary(this.ecoLevel)), this.tc(EcoTheme.primaryPale(this.ecoLevel)),
            (): void => this.doBackup())
          this.ActionRow('recycle', '恢复', '从最近一次备份还原', this.tc(Accent.INFO), this.tc(Accent.INFO_BG),
            (): void => this.doRestore())
          this.ActionRow('gift', '恢复演示数据', '还原为内置的 30 天样例数据', this.tc(Accent.RECYCLE), this.tc(Accent.RECYCLE_BG),
            (): void => this.doRestoreDemo())
          this.ActionRow('trash', '清空数据', '删除全部本地数据，不可恢复', this.tc(Accent.DANGER), this.tc(Accent.DANGER_BG),
            (): void => this.doClear())
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 操作行：图标 + 文案 + 状态药丸 */
  @Builder
  ActionRow(icon: string, title: string, sub: string, color: string, tint: string, act: () => void) {
    Row({ space: Space.MD }) {
      Stack() {
        CfIcon({ kind: 'ui', code: icon, iconSize: 18, color: color })
      }
      .width(36)
      .height(36)
      .backgroundColor(tint)
      .borderRadius(Radius.SM)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text(sub)
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.backing ? '处理中…' : '去操作')
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
    }
    .width('100%')
    .padding(Space.MD)
    .backgroundColor(this.tc(Neutral.SURFACE))
    .borderRadius(Radius.MD)
    .onClick((): void => act())
  }
@Builder
  DeviceCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '运行模式' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          Row() {
            Text('数据存储位置')
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(Neutral.TEXT))
            Blank()
            CfPill({ text: '本机 Preferences', tone: 'success' })
          }
          .width('100%')
          this.InfoLine('已备份份数', this.backupCount + ' 份')
          this.InfoLine('行为记录', this.ov.recordCount + ' 条')
          this.InfoLine('连续打卡', this.ov.continuousDays + ' 天')
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  TipCard() {
    CfCard({ pad: Space.LG }) {
      Column({ space: Space.SM }) {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: 'bulb', iconSize: 15, color: this.tc(Neutral.TEXT) })
          Text('备份说明')
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
        }
        .width('100%')
        Text('· 本应用为单机版，全部数据仅保存在本机，不会上传到任何服务器')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .width('100%')
        Text('· 备份数据同样存于本机沙箱，卸载应用会一并清除')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .width('100%')
        Text('· 家庭多设备数据在「我的 → 超级终端」中集中查看（演示数据）')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .lineHeight(17)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
@Builder
  InfoLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
      Blank()
      Text(value)
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .maxLines(1)
    }
    .width('100%')
  }
}