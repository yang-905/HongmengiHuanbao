import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalDevice, LocalMember } from '../../data/MockStore'
import { Accent, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfEmpty, CfPill, CfProgress, CfSection, CfTopBar } from '../../ui/Components'
import { toast } from '../../ui/Toast'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**
 * P32 超级终端 · 设备编组与家庭合并
 * 展示家庭多设备在线状态、一键同步、家庭成员减排排行
 */
@Component
export struct SuperTerminalPage {
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
  /** 设备卡固定行高 / 每行台数 */
  private static readonly CARD_H: number = 132
  private static readonly COLS: number = 2

  @State private devices: LocalDevice[] = []
  @State private members: LocalMember[] = []
  @State private loading: boolean = true
  @State private syncing: boolean = false

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    // 纯单机模式：设备与成员数据均来自本地（演示数据），无需组网
    this.devices = await DataSource.devices()
    this.members = await DataSource.familyMembers()
    this.loading = false
  }

  /**
   * 刷新本页数据。
   * 原为「一键近场同步」（SyncEngine.run()），该分布式模块已从工程移除，
   * 这里降级为纯本地的重新拉取，保持按钮的交互反馈不丢失。
   */
  private async sync(): Promise<void> {
    if (this.syncing) return
    this.syncing = true
    try {
      await this.load()
      toast('已刷新本机数据')
    } finally {
      this.syncing = false
    }
  }

  /** 设备类型图标 code（IconMap 的 ui 表），原先是 emoji */
  private typeIcon(t: string): string {
    if (t === 'phone') return 'device'
    if (t === 'tablet') return 'device'
    if (t === 'watch') return 'clock'
    if (t === 'tv') return 'device'
    return 'device'
  }

  /** 家庭合并减排总量 */
  private familyKg(): number {
    let sum: number = 0
    for (let i = 0; i < this.members.length; i++) sum += this.members[i].reduction
    return Math.round(sum * 100) / 100
  }

  /** 排行最大值 */
  private maxKg(): number {
    let m: number = 0
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].reduction > m) m = this.members[i].reduction
    }
    return m <= 0 ? 1 : m
  }

  private deviceTone(d: LocalDevice): string {
    if (d.online) return 'success'
    return 'muted'
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
          title: '超级终端',
          onBack: (): void => {
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.Summary()
            this.DeviceBlock()
            this.MemberBlock()
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
  Summary() {
    Column({ space: Space.MD }) {
      Row() {
        Column({ space: 3 }) {
          Text('家庭累计减排')
            .fontSize(FontSize.SMALL)
            .fontColor('rgba(255,255,255,0.85)')
          Row({ space: 3 }) {
            Text(this.familyKg().toFixed(2))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('kg').fontSize(FontSize.BODY).fontColor('rgba(255,255,255,0.9)').margin({ top: 10 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Column({ space: 3 }) {
          Text('' + this.members.length)
            .fontSize(FontSize.HERO)
            .maxFontScale(FontSize.SCALE_NUM)
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('家庭成员').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      Row() {
        Text('一键同步')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(40)
          .backgroundColor('rgba(255,255,255,0.22)')
          .borderRadius(Radius.PILL)
          .enabled(!this.syncing)
          // sync() 已改为 async（返回 Promise），此处不能再标注 `: void`，
          // 否则类型不匹配：Promise<void> 不能赋给 void
          .onClick(() => {
            this.sync()
          })
      }
      .width('100%')
      .margin({ top: Space.SM })
    }
    .width('100%')
    .padding(Space.XL)
    .linearGradient({
      angle: 135,
      colors: [['#7FD9C4', 0], ['#2A9E82', 1]]
    })
    .borderRadius(Radius.XL)
    .shadow(this.tw(Shadow.brand()))
  }

  @Builder
  DeviceBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '我的设备' })
      if (this.devices.length === 0) {
        CfCard({}) {
          CfEmpty({ icon: 'device', text: '暂无设备', sub: '同一账号下的多设备会自动出现在这里' })
        }
      } else {
        // 用 Row + layoutWeight 显式分列替代 Grid（列宽约束传不到子 Text）
        Column({ space: Space.MD }) {
          ForEach(this.rowIndexes(), (r: number) => {
            Row({ space: Space.MD }) {
              ForEach(this.cellsOfRow(r), (d: LocalDevice) => {
                Column() {
                  this.DeviceCell(d)
                }
                .layoutWeight(1)
              }, (d: LocalDevice): string => d.deviceCode)
              if (this.cellsOfRow(r).length < SuperTerminalPage.COLS) {
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
    }
    .width('100%')
  }

  /** 单台设备卡 */
  @Builder
  DeviceCell(d: LocalDevice) {
    Column({ space: 6 }) {
      Row() {
        CfIcon({ kind: 'ui', code: this.typeIcon(d.deviceType), iconSize: 20 })
        Blank()
        Circle({ width: 7, height: 7 }).fill(d.online ? this.tc(Accent.SUCCESS) : this.tc(Neutral.TEXT_MUTED))
      }
      .width('100%')

      Text(d.deviceName)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(d.deviceModel)
        .fontSize(10)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(d.todayReduction.toFixed(2) + ' kg')
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor(d.online ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
        Text('今日')
          .fontSize(10)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
          .margin({ left: 4 })
      }
      .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height(SuperTerminalPage.CARD_H)
    .padding(Space.MD)
    .linearGradient(this.tw(GlassLight.surface(Glass.CARD_BG, GlassTier.CARD, '', 1)))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
    .clip(true)
  }

  /** 行号数组 */
  private rowIndexes(): number[] {
    const rows: number = Math.ceil(this.devices.length / SuperTerminalPage.COLS);
    const out: number[] = [];
    for (let i: number = 0; i < rows; i++) out.push(i);
    return out;
  }

  /** 第 r 行的设备（最多 COLS 台） */
  private cellsOfRow(r: number): LocalDevice[] {
    const out: LocalDevice[] = [];
    const start: number = r * SuperTerminalPage.COLS;
    for (let i: number = 0; i < SuperTerminalPage.COLS; i++) {
      const idx: number = start + i;
      if (idx < this.devices.length) out.push(this.devices[idx]);
    }
    return out;
  }

  /** 末行补齐占位下标 */
  private fillerIndexes(r: number): number[] {
    const used: number = this.cellsOfRow(r).length;
    const out: number[] = [];
    for (let i: number = used; i < SuperTerminalPage.COLS; i++) out.push(i);
    return out;
  }

  @Builder
  MemberBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '家庭成员减排排行' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          ForEach(this.members, (m: LocalMember, i: number) => {
            Row({ space: Space.MD }) {
              Text(m.avatar).fontSize(24)
              Column({ space: 5 }) {
                Row() {
                  Text(m.memberName)
                    .fontSize(FontSize.BODY)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.tc(Neutral.TEXT))
                  if (m.isSelf) {
                    CfPill({ text: '我', tone: 'info' })
                  }
                  Blank()
                  Text(m.reduction.toFixed(2) + ' kg')
                    .fontSize(FontSize.SMALL)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
                }
                .width('100%')
                CfProgress({
                  percent: (m.reduction / this.maxKg()) * 100,
                  color: m.isSelf ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Accent.RECYCLE),
barHeight: 6
                })
                .width('100%')
                Text(m.deviceName + ' · ' + m.points + ' 积分 · ' + m.count + ' 条记录')
                  .fontSize(10)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
          }, (m: LocalMember) => m.memberName)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
}