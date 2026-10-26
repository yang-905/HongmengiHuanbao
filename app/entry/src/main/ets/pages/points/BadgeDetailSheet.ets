import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { LocalBadge } from '../../data/MockStore'
import { EcoMoodState } from '../../data/EcoMoodState'
import { CategoryMeta, FontSize, Glass, Neutral, Radius, Shadow, Space, EcoMood, EcoTheme } from '../../ui/Theme';
import { CfButton, CfCard, CfCloseIcon, CfPill, CfProgress } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**
 * P18 徽章详情（半模态）
 * ------------------------------------------------------------------
 * bindSheet 半模态面板，不占路由；由宿主页（徽章墙）bindSheet 挂载。
 * 与 QuizSheet 同一约定：通过 onClose 回调交回关闭权，宿主页负责收起面板。
 * 展示：icon / 名称 / 描述 / 判定指标 / 阈值 / 达成度 / 解锁状态 / 解锁日期
 */
@Component
export struct BadgeDetailSheet {
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
  /** 待展示的徽章；null 时展示空态 */
  badge: LocalBadge | null = null
  /** 关闭回调（宿主页 bindSheet 收起用） */
  onClose: () => void = (): void => {}

  /* ---------- 判定指标口径 ---------- */

  /** 指标中文名 */
  private metricName(b: LocalBadge): string {
    if (b.metric === 'reduction') return '累计减排';
    if (b.metric === 'count') return '低碳记录条数';
    if (b.metric === 'days') return '连续打卡天数';
    if (b.metric === 'tree') return '植树棵数';
    if (b.metric === 'categoryCount') return CategoryMeta.label(b.category) + '次数';
    return '低碳成就';
  }

  /** 指标单位后缀 */
  private unitOf(b: LocalBadge): string {
    if (b.metric === 'reduction') return ' kg';
    if (b.metric === 'count') return ' 条';
    if (b.metric === 'days') return ' 天';
    if (b.metric === 'tree') return ' 棵';
    if (b.metric === 'categoryCount') return ' 次';
    return '';
  }

  /** 阈值文案：分类指标带上分类名 */
  private thresholdText(b: LocalBadge): string {
    const suffix: string = this.unitOf(b)
    if (b.metric === 'categoryCount' && b.category.length > 0) {
      return CategoryMeta.label(b.category) + ' 累计 ' + b.threshold + suffix
    }
    return b.threshold + suffix
  }

  /** 渐变起始色：已解锁给主色，未解锁给灰 */
  private gradFrom(): string {
    if (this.badge === null) return this.tc(Neutral.TEXT_MUTED)
    return this.badge!.unlocked ? this.tc(EcoTheme.primaryLight(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED)
  }

  /** 渐变尾色 */
  private gradTo(): string {
    if (this.badge === null) return this.tc(Neutral.TEXT_SUB)
    return this.badge!.unlocked ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_SUB)
  }

  /** 达成度：已解锁满格；未解锁无真实进度来源，按 0 展示，不编造数值 */
  private pct(): number {
    if (this.badge === null) return 0
    return this.badge!.unlocked ? 100 : 0
  }

  /** 解锁日期文案 */
  private unlockText(): string {
    if (this.badge === null) return ''
    return this.badge!.unlockDate.length > 0 ? this.badge!.unlockDate : '已解锁'
  }

  /* ---------- 交互 ---------- */

  private close(): void {
    this.onClose()
  }

  /** 未解锁时引导去赚积分 */
  private goTask(): void {
    this.close()
    AppRouter.pathStack.pushPathByName(RouteName.TASK_CENTER, null)
  }

  private share(): void {
    if (this.badge === null) return
    toast('「' + this.badge!.badgeName + '」成就卡已生成')
  }

  /* ---------- 动态碳主题（与页面背景同步） ---------- */

  /** 全局碳情绪档位（响应式，AppStorage 驱动） */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 记录变更信号 */
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

  /** Sheet 底色：在档位色基础上再压一层奶油基调，保持既有观感 */
  private sheetBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
  }

  build() {
    Column() {
      this.Header()
      if (this.badge === null) {
        Column({ space: 8 }) {
          CfIcon({ kind: 'ui', code: 'badge', iconSize: 40 })
            .opacity(this.themeTick >= 0 ? 1 : 0)
          Text('未选择徽章')
            .fontSize(FontSize.BODY)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .maxLines(1)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: Space.LG }) {
            this.BadgeHead()
            this.RuleCard()
            this.StatusCard()
            this.ActionRow()
          }
          .width('100%')
          .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.XL })
        }
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
        /*
         * 入场过场：面板插入时，内容从下方 40vp 淡入到原位。
         * 声明式 transition（非 animateTo 生命周期驱动）—— 组件首次挂载
         * 即由渲染引擎播放，不依赖 aboutToAppear 回调，
         * 规避 Previewer 里回调不触发导致「动画不播/初始态卡死」的问题。
         */
        .transition({ translate: { y: 40 }, opacity: 0 })
      }
    }
    .width('100%')
    .height('100%')
    /*
     * 液态玻璃面板底（修「面板像一张白纸、没有悬浮感」）：
     * 原来用 Neutral.BG = #FBF8F3 完全不透明，把底下的页面内容整个盖住，
     * 模糊自然一点也透不出来。改为半透明玻璃 + backdropBlur 实时高斯模糊，
     * 面板下方内容真实透出并虚化，形成苹果液态玻璃那种"浮在内容之上"的层次。
     *
     * 用 backdropBlur 而非 backgroundBlurStyle：后者只模糊系统壁纸/窗口背景，
     * 对组件下方的实时内容不生效（见 Theme.ets Glass.LIVE_BLUR 注释）。
     */
    .backgroundColor(this.sheetBg())
    .backdropBlur(EcoMood.blurOf(this.ecoLevel) + 4)
    // 顶缘一道白色高光，模拟玻璃上沿的受光面（苹果 sheet 的标志性细节）
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    // 底色/高光跟随碳档位平滑过渡，与页面根同一口径
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }

  /* ---------- 顶部标题与关闭 ---------- */
  @Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Text('低碳徽章')
          .fontSize(FontSize.HEADING)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
        Text('成就详情')
          .fontSize(FontSize.CAPTION)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      // 矢量叉号：'✕' 字符会触发字体回退，笔画出现灰色重影
      CfCloseIcon({
        btnSize: 32,
        glass: true,
        onTap: (): void => this.close()
      })
    }
    .width('100%')
    .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.LG, bottom: Space.SM })
  }

  /* ---------- 徽章主体 ---------- */
  @Builder
  BadgeHead() {
    Row() {
      Column({ space: 5 }) {
        Text('低碳成就')
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.85)')
          .maxLines(1)
        Text(this.badge!.badgeName)
          .fontSize(FontSize.DISPLAY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.badge!.description)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor('rgba(255,255,255,0.9)')
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      // 必须给宽度约束：否则系统字体放大时 Text 按内容撑开，
      // 会把右侧图标挤出卡片（这正是「记录第1条低」溢出的根因）
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })

      // 图标：已解锁彩色大圆，未解锁灰底带锁标
      Stack({ alignContent: Alignment.BottomEnd }) {
        // 已解锁展示徽章原画（卡通 emoji），未解锁用线稿锁
        if (this.badge!.unlocked) {
          Text(this.badge!.icon)
            .fontSize(34)
            .maxFontScale(FontSize.SCALE_NUM)
            .width(72)
            .height(72)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.tc(Neutral.CARD))
            .borderRadius(36)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            CfIcon({
              kind: 'ui',
              code: 'lock',
              iconSize: 30,
              color: this.tc(Neutral.TEXT_MUTED)
            })
          }
          .width(72)
          .height(72)
          .backgroundColor(this.tc(Neutral.CARD))
          .borderRadius(36)
        }
        if (!this.badge!.unlocked) {
          Text('未解锁')
            .fontSize(9)
            .maxFontScale(FontSize.SCALE_NUM)
            .fontColor('#FFFFFF')
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(this.tc(Neutral.TEXT_MUTED))
            .borderRadius(Radius.PILL)
            .margin({ right: -6, bottom: -2 })
        }
      }
      .width(72)
      .height(72)
      .flexShrink(0)
    }
    .width('100%')
    .padding(Space.XL)
    .linearGradient({
      angle: 135,
      colors: [[this.gradFrom(), 0], [this.gradTo(), 1]]
    })
    .borderRadius(Radius.XL)
    .shadow(this.tw(Shadow.brand()))
    // 字体放大时内容不允许顶出卡片
    .clip(true)
  }

  /* ---------- 判定指标与阈值 ---------- */
  @Builder
  RuleCard() {
    // 半透明卡（非实色）：面板根已有 backdropBlur 实时高斯模糊，
    // 卡片若再各挂一层模糊属于同区域叠加，会掉帧且过糊；
    // 因此这里只把 0.86 实色换成 0.55 半透明，透出根的模糊内容即可。
    CfCard({ pad: Space.LG, bgColor: this.tc(Glass.PANEL_LIVE_BG) }) {
      Column({ space: Space.MD }) {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: 'target', iconSize: 16, color: this.tc(Neutral.TEXT) })
          Text('判定指标')
            .fontSize(FontSize.TITLE)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
        }
        .width('100%')

        this.RuleLine('指标类型', this.metricName(this.badge!))
        this.RuleLine('解锁阈值', this.thresholdText(this.badge!))
        this.RuleLine('徽章编码', this.badge!.badgeCode)
        if (this.badge!.category.length > 0) {
          this.RuleLine('所属分类', CategoryMeta.label(this.badge!.category))
        }

        // 达成度：已解锁满格，未解锁仅提示不编造数值
        Column({ space: 6 }) {
          CfProgress({
            percent: this.pct(),
            color: this.badge!.unlocked ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED),
            barHeight: 8
          })
          .width('100%')
          Row() {
            Text(this.badge!.unlocked ? '已达成解锁条件' : '继续低碳记录即可解锁')
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .constraintSize({ minWidth: 0 })
            Blank().width(Space.SM)
            Text(this.badge!.unlocked ? '100%' : '待解锁')
              .fontSize(FontSize.CAPTION)
              .maxFontScale(FontSize.SCALE_NUM)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.badge!.unlocked ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT_MUTED))
              .maxLines(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: Space.XS })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  RuleLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
      Blank().width(Space.MD)
      Text(value)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tc(Neutral.TEXT))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    }
    .width('100%')
  }

  /* ---------- 解锁状态 ---------- */
  @Builder
  StatusCard() {
    Row() {
      if (this.badge!.unlocked) {
        Text(this.badge!.icon)
          .fontSize(22)
          .maxFontScale(FontSize.SCALE_NUM)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.SM)
          .flexShrink(0)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          CfIcon({
            kind: 'ui',
            code: 'lock',
            iconSize: 20,
            color: this.tc(Neutral.TEXT_MUTED)
          })
        }
        .width(44)
        .height(44)
        .backgroundColor(this.tc(Neutral.SURFACE))
        .borderRadius(Radius.SM)
        .flexShrink(0)
      }
      Column({ space: 3 }) {
        Text(this.badge!.unlocked ? '已解锁' : '解锁进度')
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
        Text(this.badge!.unlocked
          ? ('解锁于 ' + this.unlockText())
          : ('需 ' + this.thresholdText(this.badge!)))
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_NUM)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      if (this.badge!.unlocked) {
        CfPill({ text: '已获得', tone: 'success' })
      } else {
        CfPill({ text: '未解锁', tone: 'warning' })
      }
    }
    .width('100%')
    .padding(Space.LG)
    // 半透明卡：与 RuleCard 同口径，透出面板根的实时模糊（见 RuleCard 注释）
    .linearGradient(this.tw(GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, '', 1)))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
    .borderRadius(Radius.MD)
    .shadow(this.tw(Shadow.card()))
    .clip(true)
  }

  /* ---------- 底部操作 ---------- */
  @Builder
  ActionRow() {
    Row({ space: Space.MD }) {
      CfButton({
        text: '关闭',
        // 用 U+00D7 乘号而非 U+2715 '✕'：后者不在系统默认字体常用子集内，
        // 会触发字体回退，按钮里的小图标同样出现灰色重影
        icon: 'close',
        primary: false,
        onTap: (): void => this.close()
      })
      if (this.badge!.unlocked) {
        // flex：撑满剩余宽度，避免与「关闭」并排时把按钮挤出容器
        CfButton({
          text: '分享成就',
          icon: 'arrowup',
          flex: true,
          onTap: (): void => this.share()
        })
      } else {
        CfButton({
          text: '去赚积分',
          icon: 'target',
          flex: true,
          onTap: (): void => this.goTask()
        })
      }
    }
    .width('100%')
  }
}
