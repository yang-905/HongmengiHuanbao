/**
 * P07 行为录入面板（中央＋/右下＋唤起，半模态）
 */
import { toast } from '../../ui/Toast'
import { DataSource } from '../../net/DataSource'
import { LocalFactor } from '../../data/MockStore'
import { EcoMoodState } from '../../data/EcoMoodState'
import { CategoryMeta, FontSize, Glass, IconTone, InputField, Neutral, Radius, Space, EcoMood, EcoTheme, ThemePalette, Accent, Biz } from '../../ui/Theme';
import { CfButton } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

@Component
export struct BehaviorAddSheet {
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
  @State private currentCat: string = 'travel'
  @State private selectedId: number = 1
  @State private amountText: string = ''
  /** 数量输入框是否聚焦：描边转品牌色，给出"正在这里输入"的确定反馈 */
  @State private amountFocused: boolean = false
  @State private submitting: boolean = false
  @State private cats: string[] = CategoryMeta.all()
  /** 分类栏轨道实测宽度（等宽分段的依据，换机型不错位） */
  @State private catTrackW: number = 0

  async aboutToAppear(): Promise<void> {
    this.factors = await DataSource.factors()
    this.applyPreset()
  }

  /**

   * 接收因子库/AI 识别带入的预选项：
   * 以 AppStorage 的 presetItemId 为准，命中则切到该因子所属分类并选中。
   * 消费后立即清空，避免下次打开面板被上一次选择污染。
   */
  private applyPreset(): void {
    const presetId: number | undefined = AppStorage.get<number>('presetItemId')
    if (presetId === undefined || presetId === null) {
      return
    }
    for (let i: number = 0; i < this.factors.length; i++) {
      if (this.factors[i].itemId === presetId) {
        this.selectedId = presetId
        this.currentCat = this.factors[i].category
        break
      }
    }
    AppStorage.delete('presetItemId')
    AppStorage.delete('presetCategory')
  }

  private itemsOfCategory(cat: string): LocalFactor[] {
    const out: LocalFactor[] = []
    for (let i: number = 0; i < this.factors.length; i++) {
      if (this.factors[i].category === cat) out.push(this.factors[i])
    }
    return out
  }

  private findSelected(): LocalFactor | undefined {
    for (let i: number = 0; i < this.factors.length; i++) {
      if (this.factors[i].itemId === this.selectedId) return this.factors[i]
    }
    return undefined
  }

  private selectCategory(cat: string): void {
    this.currentCat = cat
    const first: LocalFactor | undefined = this.itemsOfCategory(cat)[0]
    if (first !== undefined) {
      this.selectedId = first.itemId
      this.amountText = ''
    }
  }

  private selectFactor(id: number): void {
    this.selectedId = id
    this.amountText = ''
  }

  private amountValue(): number {
    const n: number = parseFloat(this.amountText)
    if (isNaN(n) || n <= 0) return 0
    return n
  }

  /** 试算减排量 */
  private previewKg(): number {
    const f: LocalFactor | undefined = this.findSelected()
    if (f === undefined) return 0
    return Math.round(f.factorValue * this.amountValue() * 1000) / 1000
  }

  /** 试算积分（round(kg×10)，减排>0 时保底 1 分） */
  private previewPoints(): number {
    const kg: number = this.previewKg()
    if (kg <= 0) return 0
    const p: number = Math.round(kg * 10)
    return p < 1 ? 1 : p
  }

  private unitText(): string {
    const f: LocalFactor | undefined = this.findSelected()
    return f === undefined ? '' : f.unit
  }

  /**

   * 占位提示文案。
 */
  private placeholderText(): string {
    const f: LocalFactor | undefined = this.findSelected()
    if (f === undefined) return '请输入数值'
    return f.unit.length > 0 ? ('输入' + f.unit + '数') : '请输入数值'
  }

  /**

   * 提交：写入本地库（单机版核心）。
   * 写入后通过 AppStorage 打一个标记，列表页 onPageShow 时据此自动刷新。
   */
  private async submit(): Promise<void> {
    const f: LocalFactor | undefined = this.findSelected()
    if (f === undefined) {
      toast('请先选择一个低碳行为')
      return
    }
    const amount: number = this.amountValue()
    if (amount <= 0) {
      toast('请输入大于 0 的数量')
      return
    }
    this.submitting = true
    try {
      const rec = await DataSource.addRecord(
        f.itemId,
        f.itemCode,
        f.itemName,
        f.icon,
        f.category,
        f.unit,
        amount,
        f.factorValue,
        'manual',
        ''
      )
      /*
       * 刷新通知：**DataSource.addRecord 内部已兜底广播**
       * EcoMoodState.broadcastDataChange()（见该方法注释：写入路径是
       * 唯一真相来源，广播放在落库同一处）。
       * 早前这里额外再调一次，属冗余 —— bump 只是自增序号，
       * 重复调用会让所有订阅 onStorageChange 的页面多跑一轮 load()，
       * 在低端机上是白耗IO。保留本页原有的 sheet 关闭与提示逻辑即可。
       */
      AppStorage.set('showAddSheet', false)
      this.amountText = ''
      toast('已记录：减排 ' + rec.reduceKg + ' kg，获得 ' + rec.points + ' 积分')
    } catch (err) {
      toast('保存失败，请重试')
    } finally {
      this.submitting = false
    }
  }
/** 全局碳情绪档位（响应式，AppStorage 驱动） */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /** 记录变更信号 */
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
    }
  }

  /** Sheet 底色：在档位色基础上再压一层奶油基调，保持既有观感 */
  private sheetBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
  }

  @Builder
  CatChip(cat: string) {
    Row({ space: 4 }) {
      CfIcon({
        kind: 'ui',
        code: CategoryMeta.icon(cat),
        iconSize: 13,
        // 未选中也保留本类色：一眼分清四类，文字仍用弱色，避免整条 chip 花掉
        color: this.currentCat === cat ? '#FFFFFF' : this.tc(IconTone.color(IconTone.ofCategory(cat)))
      })
      Text(CategoryMeta.label(cat))
        .fontSize(FontSize.CAPTION)
        // 药丸高度写死 34，字号被系统放大就会溢出，这里钳住
        .maxFontScale(FontSize.SCALE_NUM)
        .fontWeight(this.currentCat === cat ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentCat === cat ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height(34)
      // 选中项轻微放大：苹果 segmented control 的标志性手感
      .scale({ x: this.currentCat === cat ? 1.06 : 1, y: this.currentCat === cat ? 1.06 : 1 })
      .animation({ duration: this.currentCat === cat ? 260 : 200, curve: Curve.EaseOut })
      .onClick((): void => this.selectCategory(cat))
  }

  /** 分类栏单项宽度：药丸必须与文字槽位严格同宽，否则滑过去会错位。
   *  ⚠️ catTrackW 是含 Stack 左右各 3vp 内边距的总宽，须扣 6vp。
   *  早期漏扣导致药丸每格宽 2vp，最右档溢出被 clip 裁成直边（圆角消失）。 */
  private catCellW(): number {
    const track: number = this.catTrackW > 0 ? this.catTrackW : 300
    return (track - 6) / this.cats.length
  }

  /** 分类栏药丸位移 = 选中项序号 × 单项宽度 */
  private catPillX(): number {
    return this.catCellW() * this.catIndex()
  }

  /** 当前分类下标；找不到时兜底 0 */
  private catIndex(): number {
    for (let i = 0; i < this.cats.length; i++) {
      if (this.cats[i] === this.currentCat) return i
    }
    return 0
  }

  /** 记录分类轨道实测宽度；百分比形式的 Length 直接忽略 */
  private onCatTrackArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.catTrackW) > 0.5) {
      this.catTrackW = w
    }
  }

  build() {
    Scroll() {
      Column({ space: Space.MD }) {
        /* 标题 */
        Row() {
          Text('记录一次低碳行为')
            .fontSize(FontSize.HEADING).opacity(this.themeTick >= 0 ? 1 : 0)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
          Blank()
          Text('单机版 · 数据仅存本机')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        .width('100%')

        /* 分类切换（液态玻璃分段控件，范式同 TrendChartPage / RecordListPage） */
        Column() {
          Stack({ alignContent: Alignment.Start }) {
            // 轨道：极淡玻璃底，只做承载
            Row()
              .width('100%')
              .height(34)
              .borderRadius(Radius.PILL)
              .linearGradient(this.tw(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1)))
              .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

            // 选中药丸：随 currentCat 平移
            Row()
              .width(this.catCellW())
              .height(34)
              .linearGradient({
                angle: 90,
                colors: [[this.tc(EcoTheme.heroMid(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
              })
              .borderRadius(Radius.PILL)
              // 不挂 backdropBlur、不加白描边：渐变底是不透明实色，
              // blur 被盖住只会白建离屏层、边缘渗出半透明晕；
              // 白描边压绿底上也显脏——通透感交给未选中的半透明轨道。
              .shadow({ radius: 4, color: this.tc(EcoTheme.shadowColor(this.ecoLevel)), offsetX: 0, offsetY: 1 })
              .translate({ x: this.catPillX() })
              .animation({ duration: 320, curve: Curve.Friction })
              .hitTestBehavior(HitTestMode.None)

            // 文字层：承接点击（药丸是 HitTestMode.None 的装饰图层）
            Row() {
              ForEach(this.cats, (cat: string) => {
                this.CatChip(cat)
              }, (cat: string): string => cat)
            }
            .width('100%')
            .height(34)
          }
          .width('100%')
          .onAreaChange((old: Area, area: Area): void => {
            this.onCatTrackArea(area.width as number | string)
          })
          /*
           * ⚠️ 外层**不再画玻璃**（与 RecordListPage 筛选栏同一问题：
           *   「这里的液态玻璃为什么是双层」）。
           * 原来外层 Stack 挂了 surface(CARD_BG) + borderColors + shadow，
           * 内层轨道 Row 又挂了 surface(SEGMENT_TRACK_BG) + borderColors，
           * 两层玻璃套娃 + 外层 padding(3) 造成两道描边叠在缝隙里 → 双层壳。
           * 现统一为单层玻璃：职责全交给内层轨道，外层只做裁剪与透明。
           */
          .padding(3)
          .borderRadius(Radius.PILL)
          // 裁剪加在 Stack（轨道与药丸的共同父级）：药丸是轨道的兄弟节点，
          // 最右一档选中时投影会溢出轨道外缘
          .clip(true)
          .backgroundColor(Color.Transparent)
      }
      .width('100%')

        /* 行为选择 */
        Column({ space: Space.SM }) {
          ForEach(this.itemsOfCategory(this.currentCat), (f: LocalFactor) => {
            Row({ space: Space.MD }) {
              CfIcon({ kind: 'factor', code: f.itemCode, iconSize: 20, tone: IconTone.ofCategory(f.category) })
              Column({ space: 2 }) {
                Text(f.itemName)
                  .fontSize(FontSize.BODY)
                  .fontColor(this.selectedId === f.itemId ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT))
                  .fontWeight(this.selectedId === f.itemId ? FontWeight.Bold : FontWeight.Normal)
                Text(f.factorValue + ' kg / ' + f.unit)
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_MUTED))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.selectedId === f.itemId) {
                CfIcon({ kind: 'ui', code: 'check', iconSize: 16, color: this.tc(EcoTheme.primary(this.ecoLevel)) })
              }
            }
            .width('100%')
            .padding(Space.MD)
            .backgroundColor(this.selectedId === f.itemId ? this.tc(EcoTheme.primaryPale(this.ecoLevel)) : this.tc(Neutral.CARD))
            .borderRadius(Radius.MD)
            .border({
              width: this.selectedId === f.itemId ? 1.5 : 1,
              color: this.selectedId === f.itemId ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.BORDER)
            })
            .onClick((): void => this.selectFactor(f.itemId))
          }, (f: LocalFactor): string => f.itemCode)
        }
        .width('100%')

        /*
         * 输入框四件事：InputField.* 专用令牌（底色+描边）+ placeholderColor +
         * 聚焦描边转品牌色 + 标签提级。缺一件都可能看不清。
         */
        Column({ space: Space.SM }) {
          Row({ space: 6 }) {
            Text('数量')
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(Neutral.TEXT))
            // 必填标记：让"这里必须填"在余光里就能捕捉到
            Text('*')
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Accent.DANGER))
            Blank()
            Text(this.unitText())
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(InputField.AFFIX))
          }
          .width('100%')

          TextInput({
            placeholder: this.placeholderText(),
            text: this.amountText
          })
            .type(InputType.Number)
            .width('100%')
            .height(48)
            /*
             * 占位文字显式上色（**本轮最关键的一行**）：
             * 不设它就用 ArkUI 默认的系统灰，在本项目两种主题下
             * 对比度都只有 1.0 上下，等于没有提示。
             */
            .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
            .fontSize(FontSize.HEADING)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tc(InputField.text(ThemePalette.dark)))
            .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
            .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
            .borderRadius(Radius.MD)
            // 描边让"这是一个可以点的框"变成确定的事实，而不只是暗示
            .border({
              width: 1.5,
              color: this.amountFocused ? this.tc(InputField.focusBorder(ThemePalette.dark)) : this.tc(InputField.border(ThemePalette.dark))
            })
            .padding({ left: 14, right: 14 })
            .onFocus((): void => {
              this.amountFocused = true
            })
            .onBlur((): void => {
              this.amountFocused = false
            })
            .onChange((v: string): void => {
              this.amountText = v
            })

          /* 试算结果 */
          if (this.previewKg() > 0) {
            Row({ space: Space.LG }) {
              Text('预计减排 ' + this.previewKg() + ' kg')
                .fontSize(FontSize.SMALL)
                .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
              Text('+' + this.previewPoints() + ' 积分')
                .fontSize(FontSize.SMALL)
                .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
              Blank()
              Text('≈ ' + Math.floor(this.previewPoints() / Biz.POINTS_PER_TREE) + ' 棵树')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            .width('100%')
            .padding(Space.MD)
            .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
            .borderRadius(Radius.SM)
          }
        }
        .width('100%')

        /* 提交按钮 */
        CfButton({
          text: this.submitting ? '保存中…' : '保存这条记录',
          icon: 'check',
          primary: true,
          block: true,
          onTap: (): void => {
            this.submit()
          }
        })

        if (this.submitting) {
          Column() {
            LoadingProgress().width(22).height(22).color(this.tc(EcoTheme.primary(this.ecoLevel)))
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.LG, bottom: 30 })
    }
    .scrollBar(BarState.Off)
    // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
    // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    /*
     * 液态玻璃面板底：原来是 Neutral.BG（#FBF8F3 不透明实色），
     * 把底下的页面内容整个盖住，模糊一点也透不出来。
     * 改为半透明玻璃 + 实时高斯模糊，让底层内容真实透出并虚化。
     */
    .backgroundColor(this.sheetBg())
    .backdropBlur(EcoMood.blurOf(this.ecoLevel) + 4)
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    // 底色/高光跟随碳档位平滑过渡，与页面根同一口径
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    /*
     * 入场过场：面板插入时，内容从下方 40vp 淡入到原位。
     * 声明式 transition，不依赖生命周期回调，Previewer 与真机一致。
     */
    .transition({ translate: { y: 40 }, opacity: 0 })
  }
}