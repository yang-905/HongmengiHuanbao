import { Toast, toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalFactor, LocalRecord } from '../../data/MockStore'
import { Accent, CategoryMeta, FontSize, IconTone, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood, ThemePalette } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfCatBadge, CfEmpty, CfPill, CfSection, CfTopBar } from '../../ui/Components'
import { GlassLight } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 路由参数 */
interface BehaviorDetailParam {
  id: number;
}

/**
 * P08 记录详情
 * ------------------------------------------------------------------
 * 路由名：BEHAVIOR_DETAIL（NavDestination，PageMap 集中注册）
 * 真实实现：大图标 + 行为快照 + 因子核算口径 + 来源说明 + 底部删除
 */
@Component
export struct BehaviorDetailPage {
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
  @State private record: LocalRecord | null = null
  @State private factor: LocalFactor | undefined = undefined
  @State private loading: boolean = true
  @State private deleting: boolean = false
  /**
   * ⚠️ 原 `barEntered`（删除条入场动画状态）已删除。
   * 它住在本页，而删除条现已渲染在 Index 的底部栏覆盖层里 ——
   * 状态与组件不同属，动画彻底失效（用户反馈「弹出太快了」）。
   * 动画状态已迁到 Index 的 `slotDeleteIn`，与删除条同组件。
   */
  /** 页面已消失标志：setTimeout 回弹栈前判断，防用户快速返回时二次 pop */
  private gone: boolean = false

  private recordId: number = -1
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    // 路由参数由 PageMap 通过 AppStorage 传入（PageMap 已提供 NavDestination 容器，
    // 页面内部不能再包一层，也拿不到 NavDestinationContext）
    const id: number | undefined = AppStorage.get<number>('detailRecordId')
    if (id !== undefined && id !== null) {
      this.recordId = id
      AppStorage.delete('detailRecordId')
    }
    /*
     * 接管底部栏插槽：删除条**由 Index 渲染**（ArkTS 不允许跨组件传函数），
     * 本页只置一个布尔 flag —— Index 会在导航胶囊退场后，
     * 于**同一个槽位**改渲染删除条，宽高底边与胶囊天然一致。
     * 必须在 aboutToAppear 注册（早于胶囊退场动画播完的 capsuleGone=true），
     * 否则插槽会先空一帧。
     */
    AppStorage.setOrCreate<boolean>('barSlotDelete', true)
    AppStorage.setOrCreate<number>('barSlotDeleteTick', 0)
    AppStorage.setOrCreate<string>('barSlotDeleteLabel', '删除记录')
    this.load()
  }

  /**
   * Index 里删除条被点击 → 转发为删除确认。
   * （删除条 UI 在 Index，故点击信号也走 AppStorage 回传本页。）
   */
  @StorageLink('barSlotDeleteTick') @Watch('onDeleteTick') deleteTick: number = 0

  onDeleteTick(): void {
    if (this.deleteTick > 0) {
      this.confirmDelete()
    }
  }

  private async load(): Promise<void> {
    try {
      const list: LocalRecord[] = await DataSource.records()
      for (let i = 0; i < list.length; i++) {
        if (list[i].recordId === this.recordId) {
          this.record = list[i]
          break
        }
      }
      /*
       * ⚠️ 兜底：没有拿到 id（或 id 对应的记录已被删除）时，
       * 退而展示**最新一条**记录，而不是给用户一片空白加一句
       * 「记录不存在」——那既不好看，也无法自证页面是否正常。
       *
       * 真实起因：设置页「低碳记录」入口直接 push 本页却没传
       * detailRecordId（早前的死路），用户在设置里点进来必然空态。
       * 入口已改为 goWithParam 传真实 id，这里是第二道保险：
       * 以后再有新入口漏传，也不会退化成空白页。
       */
      if (this.record === null && list.length > 0) {
        this.record = list[0]
      }
      // 同步取该行为的因子，用于展示核算口径
      const factors: LocalFactor[] = await DataSource.factors()
      for (let i = 0; i < factors.length; i++) {
        if (this.record !== null && factors[i].itemId === this.record.itemId) {
          this.factor = factors[i]
          break
        }
      }
    } catch (err) {
      // DataSource 内部已兜底
    }
  }

  /* ---------- 展示辅助 ---------- */

  private fmtNum(n: number): string {
    const v: number = Math.round(n * 100) / 100
    if (Math.abs(v - Math.round(v)) < 0.001) {
      return '' + Math.round(v)
    }
    return v.toFixed(2)
  }

  private sourceText(): string {
    if (this.record === null) return ''
    return this.record.recordSource === 'ai' ? 'AI 拍照识别' : '手动录入'
  }

  private sourceDesc(): string {
    if (this.record === null) return ''
    if (this.record.recordSource === 'ai') {
      return '由端侧 AI 图像识别引擎匹配低碳行为因子，自动核算减排量'
    }
    return '用户在行为录入面板手动选择因子并填写数量'
  }

  private timeText(): string {
    if (this.record === null) return ''
    const t: string = this.record.behaviorTime
    if (t.length >= 16) return t.substring(5, 16).replace('-', '/')
    return t
  }

  /** 换算说明：数量 × 因子值 = 减排 kg */
  private formulaText(): string {
    if (this.record === null) return ''
    if (this.factor === undefined) {
      return this.fmtNum(this.record.amount) + ' × 因子值 = ' + this.fmtNum(this.record.reduceKg) + ' kg'
    }
    return this.fmtNum(this.record.amount) + ' ' + this.record.unit +
      ' × ' + this.factor.factorValue + ' = ' + this.fmtNum(this.record.reduceKg) + ' kg'
  }

  /* ---------- 删除 ---------- */

  private confirmDelete(): void {
    if (this.record === null || this.deleting) return
    // AlertDialog.show 自 API 18 起废弃，改用 Toast.confirmWith（内部走 UIContext.getPromptAction）
    Toast.confirmWith(
      '删除这条记录？',
      '删除后将退回对应的 ' + this.record.points + ' 碳积分，操作不可撤销。',
      [
        { text: '取消', color: this.tc(Neutral.TEXT_SUB) },
        { text: '确认删除', color: this.tc(Accent.DANGER) }
      ],
      1
    ).then((ok: boolean): void => {
      if (ok) {
        this.doDelete()
      }
    })
  }
  private async doDelete(): Promise<void> {
    if (this.deleting || this.record === null) return
    this.deleting = true
    /*
     * ⚠️ 早前这里只有一个 setTimeout + toast，**记录根本没被删除** ——
     * 用户点了「确认删除」却发现记录还在，是与「记录不存在」同源的
     * 半成品实现（注释里写着「端侧演示：本地移除后回退详情」，
     * 但移除那一步从来没写）。
     * DataSource.removeRecord 已存在且内部会 broadcastDataChange，
     * 记录页/统计/碳档位都会同步刷新。
     */
    const id: number = this.record.recordId
    try {
      const ok: boolean = await DataSource.removeRecord(id)
      this.deleting = false
      if (!ok) {
        toast('记录已不存在，可能刚被删除')
        this.gone = true
        AppRouter.pathStack.pop()
        return
      }
      toast('记录已删除')
      // 置 gone 后再 pop：此刻页面即将销毁，避免用户手动返回后被二次 pop
      this.gone = true
      AppRouter.pathStack.pop()
    } catch (err) {
      this.deleting = false
      toast('删除失败，请重试')
    }
  }

  aboutToDisappear(): void {
    this.gone = true
    /*
     * 释放底部栏插槽：必须在本页消失时清理，
     * 否则回到一级页后底部还会挂着一颗红色删除条。
     */
    AppStorage.setOrCreate<boolean>('barSlotDelete', false)
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
            title: '记录详情',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })
          if (this.record === null) {
            Column() {
              /*
               * 只有在**确实一条记录都没有**时才会走到这里
               * （load() 已对「id 缺失/记录被删」做了回退到最新一条的处理）。
               * 文案因此要说清是"库为空"而非"这一条不见了"——
               * 否则用户会以为是数据丢了。
               */
              CfEmpty({ icon: 'inbox', text: '还没有低碳记录', sub: '回到记录页，点击 ＋ 记下第一笔绿色行为' })
            }
            .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll(this.scroller) {
              Column({ space: Space.LG }) {
                this.HeroCard()
                this.Snapshot()
                this.SourceCard()
              }
              .width('100%')
              /*
               * bottom 96：删除条虽然是**覆盖层**（不占布局），但它浮在底部
               * 56vp 高 —— 若底部余量不足，「记录来源」的最后一行会被压在
               * 删除条下面看不到。96 = 56(条高) + 24(呼吸) + 16(安全区余量)，
               * 保证最后一张卡片能完整滚到删除条上方。
               */
              .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 96 })
            }
            .scrollBar(BarState.Off)
            // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
            // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
            .edgeEffect(EdgeEffect.None)
            .width('100%')
            .layoutWeight(1)

            /*
             * 底部删除条：从右侧「＋」圆钮弹出的**液态玻璃**悬浮胶囊。
             * ------------------------------------------------------------------
             * 用户诉求：「改成从右边加号弹出的动画，让他属于从导航栏出来的液态玻璃效果，
             *          白色底层去掉，做成和一级页面的导航栏一样」。
             *
             * 改前的问题（两张截图对照）：
             *   ① 底下压着一条 `Neutral.CARD`（**不透明纯白**）实心横条，
             *      与一级页面底部那条玻璃胶囊**完全两套语言** —— 一进二级页
             *      导航栏质感突然消失，像掉回了原生页面；
             *   ② 删除按钮孤零零占满整行，没有来由 —— 用户看不出它属于
             *      底部导航体系。
             *
             * 改后的口径（与 Index 底部胶囊完全一致）：
             *   · 材质：`GlassLight.surface(BOTTOM_BAR_BG, PILL)` 单层 135° 合成渐变
             *     + `backdropBlur` + 四边异色描边 + `shadowOf(PILL)`，
             *     与 Index 的玻璃胶囊同参数、同光照模型（同一左上 45° 主光源）；
             *   · 底色：**去掉 Neutral.CARD 白条**，改为透明 —— 内容从胶囊下穿过，
             *     胶囊糊到的是真实内容（这是液态玻璃的"活"，纯色底会把它拍死）；
             *   · 动效：从右侧「＋」圆钮中心**弹出**—— translate 从右侧起、
             *     缩放 0.6→1、透明度 0→1，与 Index 里胶囊退出时
             *     「被 ＋ 钮吸进去」是同一条运动曲线（Friction 收尾），
             *     所以视觉上是"＋ 钮把这条胶囊吐出来"，而不是凭空出现。
             *
             * ⚠️ 布局要点：不能再用 `.width('100%')` 的实心条，
             *   必须是「左右留边距 + 悬浮」的胶囊，否则左右两端会贴到屏幕边缘，
             *   玻璃的圆角与描边就退化成直角，观感立刻变回"白条"。
             */
            /*
             * ⚠️ 删除条**不再在本页渲染**（用户诉求「导航条消失后，
             *   让同尺寸的删除按键代替导航条的位置」）。
             *
             * 原来它渲染在本页布局里 —— 而导航胶囊在 Index 的底部栏，
             * 两者是**不同父容器**，所以删除条只能「自己另占一行」，
             * 永远填不进导航条退场后留下的空位（截图里就是条与胶囊错位）。
             *
             * 删除条已完全移出本页（改由 Index 的底部栏插槽渲染，见
             * `aboutToAppear` 的 `barSlotDelete` flag），本页**不再需要**任何占位元素。
             *
             * ⚠️ 这里曾多写了一个空的 `Column().layoutWeight(1)` 想"给滚动区留底"，
             *   结果它与上面的 Scroll **抢 layoutWeight** → Scroll 被压到只剩
             *   HeroCard 那么高，「行为快照」「记录来源」两个区块整块看不见
             *   （用户截图：页面下半截一片空白）。
             *   删除条是**覆盖层**、不占布局，所以这里什么都不需要留。
             */
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

  /* ---------- 主视觉：大图标 + 名称 ---------- */
  @Builder
  HeroCard() {
    Column({ space: Space.MD }) {
      Column() {
        CfIcon({ kind: 'factor', code: this.record!.itemCode, iconSize: 46, tone: IconTone.ofCategory(this.record!.category) })
      }
      .width(88)
      .height(88)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
      .borderRadius(Radius.XL)

      Text(this.record!.itemName)
        .fontSize(FontSize.DISPLAY)
        .maxFontScale(FontSize.SCALE_NUM)
        .maxLines(1)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .textAlign(TextAlign.Center)

      Row({ space: Space.SM }) {
        CfCatBadge({
          text: CategoryMeta.label(this.record!.category),
          bg: this.tc(CategoryMeta.bg(this.record!.category)),
          fg: this.tc(CategoryMeta.color(this.record!.category))
        })
        CfPill({ text: this.timeText(), tone: 'muted' })
      }

      // 减排 + 积分双数据
      Row() {
        Column({ space: 3 }) {
          Row({ space: 3 }) {
            Text(this.fmtNum(this.record!.reduceKg))
              .fontSize(FontSize.HERO)
              .maxFontScale(FontSize.SCALE_NUM)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text('kg')
              .fontSize(FontSize.BODY)
              .fontColor('rgba(255,255,255,0.9)')
              .margin({ top: 12 })
          }
          Text('本次减排 CO₂e').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Blank()
        Column({ space: 3 }) {
          Text('+' + this.record!.points)
            .fontSize(FontSize.HERO)
            .maxFontScale(FontSize.SCALE_NUM)
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('获得碳积分').fontSize(FontSize.CAPTION).fontColor('rgba(255,255,255,0.85)')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
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
    .width('100%')
    .padding({ top: Space.XL, bottom: Space.XL })
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }

  /* ---------- 行为快照 ---------- */
  @Builder
  Snapshot() {
    Column({ space: Space.MD }) {
      CfSection({ title: '行为快照' })
      CfCard({ pad: Space.LG }) {
        Column({ space: 0 }) {
          this.InfoRow('行为类型', this.record!.itemName)
          this.InfoRow('所属分类', CategoryMeta.label(this.record!.category))
          this.InfoRow('发生时间', this.record!.behaviorTime)
          this.InfoRow('行为数量',
            this.fmtNum(this.record!.amount) + ' ' + this.record!.unit, true)
          this.InfoRow('减排量', this.fmtNum(this.record!.reduceKg) + ' kg CO₂e', true)
          this.InfoRow('碳积分', '+' + this.record!.points + ' 分', true)
          this.InfoRow('核算口径', this.formulaText(), true)
          this.InfoRow('备注',
            this.record!.remark.length > 0 ? this.record!.remark : '未填写备注', true)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 快照行，最后一行不画分割线 */
  @Builder
  InfoRow(label: string, value: string, last: boolean = false) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
        Blank()
        Text(value)
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
          .textAlign(TextAlign.End)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if (!last) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.tc(Neutral.BORDER))
      }
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
  }

  /* ---------- 记录来源 ---------- */
  @Builder
  SourceCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '记录来源' })
      Row({ space: Space.MD }) {
        Column() {
          CfIcon({
            kind: 'ui',
            code: this.record!.recordSource === 'ai' ? 'robot' : 'edit',
            iconSize: 20
          })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.record!.recordSource === 'ai' ? this.tc(Accent.INFO_BG) : this.tc(Neutral.SURFACE))
        .borderRadius(Radius.SM)

        Column({ space: 4 }) {
          Row() {
            Text(this.sourceText())
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))
            Blank()
            CfPill({
              text: this.record!.recordSource === 'ai' ? 'AI' : 'MANUAL',
              tone: this.record!.recordSource === 'ai' ? 'info' : 'muted'
            })
          }
          .width('100%')
          Text(this.sourceDesc())
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
    .width('100%')
  }

}
