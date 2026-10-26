import { Toast, toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalFactor, LocalRecord } from '../../data/MockStore'
import { AiVisionRecognizer, AiVisionResult } from '../../data/ai/AiVisionRecognizer'
import { Accent, Biz, CategoryMeta, FontSize, IconTone, InputField, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood, ThemePalette } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCard, CfCatBadge, CfEmpty, CfPill, CfProgress, CfSection, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 识别阶段：待选图 / 识别中 / 已出结果 */
class RecognizeStage {
  static readonly IDLE: number = 0;
  static readonly RUNNING: number = 1;
  static readonly DONE: number = 2;
}

/**
 * P27 AI 拍照识别录入（创新拓展 · 端侧 AI）
 * ------------------------------------------------------------------
 * 路由名：AI_RECOGNIZE（NavDestination，PageMap 集中注册）
 *
 * 完整链路：
 *   ① 选图：PhotoViewPicker 系统相册（免权限）→ 真实图片 uri
 *      （保留演示样例 chips 与文件名输入，供无端侧模型环境降级体验）
 *   ② 点「开始识别」→ AiVisionRecognizer（MindSpore Lite 端侧真推理）
 *      演示模式则走 DataSource.recognize 词库链路
 *   ③ 展示识别结果：行为图标 / 名称 / 置信度 / 预估减排 / 预估积分 / 识别依据
 *   ④ 数量步进器可调，实时联动减排与积分
 *   ⑤ 点「确认录入」写入本地待同步队列（服务端接口后续接入）
 */
@Component
export struct AiRecognizePage {
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
  /** 真实选图的图片 uri（PhotoViewPicker 返回，content:// 形式） */
  @State private photoUri: string = ''
  /** 演示模式输入（文件名），端侧不可用时的降级输入 */
  @State private label: string = ''
  /** 当前阶段 */
  @State private stage: number = RecognizeStage.IDLE
  /** 识别结果（未出结果时为 null） */
  @State private result: LocalRecord | null = null
  /** 识别出的因子，用于按数量重算 */
  @State private factor: LocalFactor | undefined = undefined
  /** 置信度 0~1 */
  @State private confidence: number = 0
  /** 匹配方式（端侧模型推理 / 演示词库） */
  @State private matchWay: string = ''
  /** 端侧识别依据：Top 3 类别概率摘要 */
  @State private snippet: string = ''
  /** 当前数量 */
  @State private amount: number = 1
  /** 提交中 */
  @State private submitting: boolean = false
  /** 页面已消失标志：setTimeout 回弹栈前判断，防用户快速返回时二次 pop */
  private gone: boolean = false

  private scroller: Scroller = new Scroller()

  /** 演示样例（模拟器/无端侧模型环境的关键词链路输入），降低体验门槛 */
  private samples: string[] = ['bike.jpg', 'bus.jpg', 'clearplate.jpg', 'plastic.jpg', 'paper.jpg']

  /* ---------- 工具方法 ---------- */

  private fmtNum(n: number): string {
    const v: number = Math.round(n * 1000) / 1000
    if (Math.abs(v - Math.round(v)) < 0.0001) {
      return '' + Math.round(v)
    }
    return v.toFixed(3)
  }

  /** 确定性伪随机：由图片标识推导一个稳定的置信度，避免每次刷新跳动 */
  private hash01(s: string): number {
    let h: number = 2166136261;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = (h * 16777619) >>> 0;
    }
    return (h % 10000) / 10000
  }

  private unit(): string {
    if (this.result === null) return ''
    return this.result.unit
  }

  private factorValue(): number {
    if (this.factor !== undefined) return this.factor.factorValue
    if (this.result === null || this.result.amount <= 0) return 0
    // 没有因子兜底时，用「减排量 / 数量」反推
    return this.result.reduceKg / this.result.amount
  }

  /** 当前数量下的减排量 */
  private curKg(): number {
    return Math.round(this.amount * this.factorValue() * 1000) / 1000
  }

  /** 当前数量下的积分 */
  private curPoints(): number {
    return Biz.pointsOf(this.curKg())
  }

  /** 置信度百分比（整数） */
  private confPct(): number {
    return Math.round(Math.max(0, Math.min(1, this.confidence)) * 100)
  }

  private confTone(): string {
    if (this.confPct() >= 90) return 'success'
    if (this.confPct() >= 75) return 'warning'
    return 'danger'
  }

  private confLabel(): string {
    if (this.confPct() >= 90) return '高置信'
    if (this.confPct() >= 75) return '待确认'
    return '低置信'
  }

  /* ---------- 交互 ---------- */

  /** ① 唤起系统相册选图（免权限） */
  private async pickPhoto(): Promise<void> {
    try {
      const uri: string = await AiVisionRecognizer.pickPhoto();
      if (uri.length === 0) return; // 用户取消
      this.photoUri = uri
      this.label = ''
      this.stage = RecognizeStage.IDLE
      this.result = null
      toast('已选择图片，点「开始识别」')
    } catch (err) {
      toast('调起相册失败，可用下方演示样例体验')
    }
  }

  private useSample(s: string): void {
    this.label = s
    this.photoUri = ''
    toast('已选择演示样例 ' + s)
  }

  /** ② 开始识别（有真图走端侧模型推理，否则走演示词库） */
  private async startRecognize(): Promise<void> {
    if (this.stage === RecognizeStage.RUNNING) return
    if (this.photoUri.length === 0 && this.label.trim().length === 0) {
      toast('请先选择一张图片')
      return
    }
    this.stage = RecognizeStage.RUNNING
    this.result = null
    try {
      if (this.photoUri.length > 0) {
        await this.recognizeOnDevice()
      } else {
        await this.recognizeDemo()
      }
    } catch (err) {
      /*
       * 2026-10-23：原提示把一切失败都归因为「未安装 mobilenetv2.ms」，
       * 但文件已确认打进 HAP（MSL2 魔数 + 13.9MB 实体）。真实原因多为
       * ① 模拟器缺 MindSporeLite 系统能力 / ② content:// 解码姿势 /
       * ③ 线程亲和配置不被接受。现在把真实原因透出来，便于对症下药，
       * 也保留「改用演示样例」的引导（演示链路不依赖任何模型）。
       */
      this.stage = RecognizeStage.IDLE
      const e: Error = err as Error
      const msg: string = (e !== undefined && e !== null && e.message !== undefined
        && e.message.length > 0)
        ? e.message
        : '未知错误'
      toast('端侧识别不可用：' + msg)
    }
  }

  /** 端侧链路：AiVisionRecognizer 真推理 */
  private async recognizeOnDevice(): Promise<void> {
    const r: AiVisionResult | undefined = await AiVisionRecognizer.recognize(this.photoUri)
    if (r === undefined) {
      this.stage = RecognizeStage.IDLE
      toast('没识别出低碳行为，换张更清晰的照片试试')
      return
    }
    this.applyResult(r.record, r.confidence, '端侧模型推理', r.snippet)
  }

  /** 演示链路：文件名关键词匹配（无端侧模型环境的降级） */
  private async recognizeDemo(): Promise<void> {
    const r: LocalRecord | undefined = await DataSource.recognize(this.label.trim())
    if (r === undefined) {
      this.stage = RecognizeStage.IDLE
      toast('没能识别出低碳行为，换张图片试试')
      return
    }
    // 从 remark 里解析匹配方式：形如「AI识图：骑行」
    let way: string = '图片特征推断'
    const prefix: string = 'AI识图：'
    if (r.remark.length > prefix.length && r.remark.indexOf(prefix) === 0) {
      way = r.remark.substring(prefix.length)
    }
    // 命中关键词词库 → 高置信；仅靠图像特征推断 → 中低置信
    const base: number = way === '图片特征推断' ? 0.66 : 0.9
    const jitter: number = this.hash01(this.label) * (way === '图片特征推断' ? 0.22 : 0.09)
    this.applyResult(r, Math.round((base + jitter) * 100) / 100, '演示词库匹配', '')
  }

  /** 识别成功落地：填结果 + 找因子 + 切 DONE */
  private async applyResult(r: LocalRecord, conf: number, way: string, snip: string): Promise<void> {
    this.result = r
    this.amount = r.amount > 0 ? r.amount : 1
    this.confidence = conf
    this.matchWay = way
    this.snippet = snip
    // 取对应因子，便于按数量精确重算
    const factors: LocalFactor[] = await DataSource.factors()
    for (let i = 0; i < factors.length; i++) {
      if (factors[i].itemId === r.itemId) {
        this.factor = factors[i]
        break
      }
    }
    this.stage = RecognizeStage.DONE
  }

  /** 预热端侧视觉模型：把模型加载藏在用户操作间隙 */
  aboutToAppear(): void {
    AiVisionRecognizer.warmUp()
  }

  /** ④ 数量步进器 */
  private step(delta: number): void {
    const next: number = Math.round((this.amount + delta) * 100) / 100
    if (next <= 0) {
      toast('数量需大于 0')
      return
    }
    this.amount = next
  }

  private onAmountInput(v: string): void {
    const n: number = parseFloat(v)
    this.amount = isNaN(n) || n <= 0 ? 0 : Math.round(n * 100) / 100
  }

  /** ⑤ 确认录入 */
  private async confirm(): Promise<void> {
    if (this.result === null) return
    if (this.amount <= 0) {
      toast('请填写正确的数量')
      return
    }
    if (this.submitting) return
    this.submitting = true
    const r: LocalRecord = this.result
    try {
      /*
       * ⚠️ 本轮修复：这里原先**只弹了个 toast 就返回**，从未写入数据库 ——
       * 用户点「确认录入」看到成功提示，但首页/记录的减排量纹丝不动。
       * 根因是识别链路的 `DataSource.recognize()` 只产出**预览对象**，
       * 并不落库（落库需要 quantity/factorValue 等写入参数），
       * 而确认环节漏了补上这一步。
       *
       * 现在真正调 DataSource.addRecord 写入；该方法内部会
       * `EcoMoodState.broadcastDataChange()`，于是：
       *   首页 DashboardPage / 科普页 / 记录页 → ecoTick → load() 自动重拉
       *   全应用配色 → EcoMoodState.refresh() 重算档位
       * 即「AI 识别录入后自动刷新」由数据层统一保证，不依赖页面各自处理。
       *
       * 数量口径：用户可在「确认数量」步进器里改 amount，所以写入时用
       * this.amount 而非识别结果的 r.amount；因子取this.factor（识别时
       * 已按 itemId 匹配到，匹配不到则退回用识别结果里的字段）。
       */
      const f: LocalFactor | undefined = this.factor
      const amount: number = this.amount
      // 因子缺失时按 1 单位计：宁可少算也不能让factorValue 为 undefined
      // 参与乘法（会得到 NaN 并污染累计减排量）。
      const factorValue: number = f !== undefined && f.factorValue > 0
        ? f.factorValue
        : (r.amount > 0 ? r.reduceKg / r.amount : 0)
      await DataSource.addRecord(
        r.itemId,
        r.itemCode,
        r.itemName,
        r.icon,
        r.category,
        r.unit,
        amount,
        factorValue,
        'ai',
        r.remark.length > 0 ? r.remark :('AI识别：' + this.matchWay)
      )
      // 落库成功后再提示：口径以实际写入为准，不沿用识别时的预估
      const kg: string = this.fmtNum(factorValue * amount)
      toast('已录入：减排 ' + kg + ' kg，+' + Math.round(factorValue * amount * 10) + ' 积分')
      this.reset()
      // 用户可能在返回动画期间已手动返回：此时页面即将销毁，
      // 再 pop 会把上一页也弹掉，出现「连退两级」
      if (!this.gone) AppRouter.pathStack.pop()
    } catch (err) {
      toast('录入失败，请重试')
    } finally {
      this.submitting = false
    }
  }

  aboutToDisappear(): void {
    this.gone = true
  }

  private reset(): void {
    this.photoUri = ''
    this.label = ''
    this.stage = RecognizeStage.IDLE
    this.result = null
    this.factor = undefined
    this.confidence = 0
    this.matchWay = ''
    this.snippet = ''
    this.amount = 1
  }

  private resetConfirm(): void {
    // AlertDialog.show 自 API 18 起废弃，改用 Toast.confirmWith（内部走 UIContext.getPromptAction）
    Toast.confirm(
      '将清空当前图片与识别结果。',
      '重新识别？'
    ).then((ok: boolean): void => {
      if (ok) {
        this.reset()
      }
    })
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
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisAppear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Column() {
        Column() {
          CfTopBar({
            title: 'AI 拍照识别',
            onBack: (): void => {
              AppRouter.pathStack.pop()
            }
          })

          Scroll(this.scroller) {
            Column({ space: Space.LG }) {
              this.PickerCard()
              if (this.stage === RecognizeStage.RUNNING) {
                this.RecognizingCard()
              } else if (this.stage === RecognizeStage.DONE && this.result !== null) {
                this.ResultCard()
                this.StepperCard()
                this.ConfirmButton()
              } else {
                this.GuideCard()
              }
            }
            .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
            .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: Space.XL })
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

  /* ---------- ① 图片选择区 ---------- */
  @Builder
  PickerCard() {
    Column({ space: Space.MD }) {
      // 取景区：选到真图显示预览，否则占位提示
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.photoUri.length > 0) {
          Image(this.photoUri)
            .width('100%')
            .height(150)
            .objectFit(ImageFit.Cover)
            .borderRadius(Radius.MD)
        } else {
          Column({ space: Space.SM }) {
            CfIcon({
              kind: 'ui',
              code: this.label.length > 0 ? 'flask' : 'camera',
              iconSize: 38,
              color: this.tc(Neutral.TEXT_MUTED)
            })
            Text(this.label.length > 0 ? '演示样例：' + this.label : '尚未选择图片')
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.label.length > 0 ? this.tc(Neutral.TEXT) : this.tc(Neutral.TEXT_MUTED))
            Text(this.label.length > 0 ? '点击上方按钮可换真实图片' : '拍下或选择一张低碳行为照片')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
          }
          .width('100%')
          .height(150)
          .justifyContent(FlexAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [[this.tc(EcoTheme.primaryPale(this.ecoLevel)), 0], [this.tc(Neutral.SURFACE), 1]]
          })
          .borderRadius(Radius.MD)
        }
        // 角标：端侧真图 / 演示
        if (this.photoUri.length > 0) {
          Text('端侧识别')
            .fontSize(FontSize.CAPTION)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
            .borderRadius(Radius.PILL)
            .margin({ right: Space.SM, bottom: Space.SM })
        }
      }
      .width('100%')

      // 主入口：唤起系统相册（PhotoViewPicker 免权限）
      Row({ space: 6 }) {
        CfIcon({ kind: 'ui', code: 'camera', iconSize: 15 })
        Text('拍照 / 从相册选择')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(46)
      .linearGradient({
        angle: 90,
        colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
      })
      .borderRadius(Radius.PILL)
      .shadow(this.tw(Shadow.brand()))
      .onClick((): void => {
        this.pickPhoto()
      })

      // 演示区：模拟器/无端侧模型环境的降级体验
      Column({ space: Space.SM }) {
        Text('演示模式（模拟器或无端侧模型时使用）')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .width('100%')
        Row({ space: Space.SM }) {
          CfIcon({ kind: 'ui', code: 'note', iconSize: 14, color: this.tc(Neutral.TEXT_MUTED) })
          TextInput({
            text: this.label,
            placeholder: '输入图片文件名，如 bike.jpg'
          })
            .layoutWeight(1)
            .height(40)
            .fontSize(FontSize.BODY)
            /*
             * 与 BehaviorAddSheet 的数量输入框同一套修复：
             * 显式 placeholderColor 是关键 —— 不设就用系统默认灰，
             * 在本项目两种主题下对比度都只有 1.0 上下（实测 1.09:1），
             * 提示文字等于不存在。描边则让"这里可以输入"成为确定事实。
             */
            .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
            .fontColor(this.tc(InputField.text(ThemePalette.dark)))
            .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
            .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
            .borderRadius(Radius.SM)
            .border({ width: 1.5, color: this.tc(InputField.border(ThemePalette.dark)) })
            .onChange((v: string): void => {
              this.label = v
              this.photoUri = ''
            })
        }
        .width('100%')
        .padding({ left: Space.MD, right: Space.MD })
        .backgroundColor(this.tc(Neutral.SURFACE))
        .borderRadius(Radius.SM)

        // 样例快捷选择
        Scroll() {
          Row({ space: Space.SM }) {
            ForEach(this.samples, (s: string) => {
              Text(s)
                .fontSize(FontSize.CAPTION)
                .fontColor(this.label === s ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.label === s ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(EcoTheme.primaryPale(this.ecoLevel)))
                .borderRadius(Radius.PILL)
                .onClick((): void => this.useSample(s))
            }, (s: string): string => s)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .width('100%')
      }
      .width('100%')

      // ② 开始识别
      Row({ space: 6 }) {
        if (this.stage === RecognizeStage.RUNNING) {
          LoadingProgress().width(16).height(16).color('#FFFFFF')
        } else {
          CfIcon({ kind: 'ui', code: 'search', iconSize: 15 })
        }
        Text(this.stage === RecognizeStage.RUNNING ? '识别中…'
          : (this.photoUri.length > 0 ? '开始识别' : '演示识别'))
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(46)
      .linearGradient({
        angle: 90,
        colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 1]]
      })
      .borderRadius(Radius.PILL)
      .shadow(this.tw(Shadow.brand()))
      .enabled(this.stage !== RecognizeStage.RUNNING)
      .onClick((): void => {
        this.startRecognize()
      })
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }

  /* ---------- 识别中 ---------- */
  @Builder
  RecognizingCard() {
    Column({ space: Space.MD }) {
      Column({ space: 6 }) {
        Text('AI 正在分析图片中的低碳行为')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
        Text(this.photoUri.length > 0 ? '端侧视觉模型正在分析图片内容，匹配行为因子库…'
          : '演示引擎匹配行为因子库…')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .width('100%')
      CfProgress({ percent: 68, color: this.tc(EcoTheme.primary(this.ecoLevel)), barHeight: 6 })
      Row() {
        Text('图像解码')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Accent.SUCCESS))
        Text('→')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .margin({ left: 6, right: 6 })
        Text('模型推理')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Accent.WARNING))
        Text('→')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .margin({ left: 6, right: 6 })
        Text('因子匹配')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.XL)
    .backgroundColor(this.tc(Neutral.CARD))
    .borderRadius(Radius.LG)
    .shadow(this.tw(Shadow.card()))
  }

  /* ---------- ③ 识别结果卡 ---------- */
  @Builder
  ResultCard() {
    Column({ space: Space.MD }) {
      CfSection({
        title: '识别结果',
        more: '重新识别',
        onMoreTap: (): void => this.resetConfirm()
      })

      CfCard({ pad: Space.LG }) {
        Column({ space: Space.LG }) {
          // 行为图标 + 名称 + 分类
          Row({ space: Space.MD }) {
            Column() {
              CfIcon({ kind: 'factor', code: this.result!.itemCode, iconSize: 26, tone: IconTone.ofCategory(this.result!.category) })
            }
            .width(50)
            .height(50)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.tc(CategoryMeta.bg(this.result!.category)))
            .borderRadius(Radius.MD)

            Column({ space: 5 }) {
              Text(this.result!.itemName)
                .fontSize(FontSize.HEADING)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(Neutral.TEXT))
              Row({ space: Space.SM }) {
                CfCatBadge({
                  text: CategoryMeta.label(this.result!.category),
                  bg: this.tc(CategoryMeta.bg(this.result!.category)),
                  fg: this.tc(CategoryMeta.color(this.result!.category))
                })
                CfPill({ text: '单位：' + this.unit(), tone: 'muted' })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')

          // 置信度
          Column({ space: 6 }) {
            Row() {
              Text('识别置信度')
                .fontSize(FontSize.SMALL)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
              Blank()
              CfPill({ text: this.confLabel(), tone: this.confTone() })
              Text(this.confPct() + '%')
                .fontSize(FontSize.BODY)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
            }
            .width('100%')
            CfProgress({
              percent: this.confPct(),
              color: this.confPct() >= 90 ? this.tc(Accent.SUCCESS) : this.tc(Accent.WARNING),
              barHeight: 6
            })
            .width('100%')
          }
          .width('100%')

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))

          // 预估减排 / 预估积分
          Row({ space: Space.MD }) {
            Column({ space: 3 }) {
              Row({ space: 3 }) {
                Text(this.fmtNum(this.result!.reduceKg))
                  .fontSize(FontSize.TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
                Text('kg')
                  .fontSize(FontSize.CAPTION)
                  .fontColor(this.tc(Neutral.TEXT_SUB))
              }
              Text('预估减排 CO₂e')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 3 }) {
              Text('+' + this.result!.points)
                .fontSize(FontSize.TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(Accent.WARNING))
              Text('预估碳积分')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          // 匹配方式
          Row() {
            Text('识别方式')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
            Blank()
            Text(this.matchWay)
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.matchWay === '端侧模型推理' ? this.tc(Accent.SUCCESS) : this.tc(Neutral.TEXT_SUB))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: Space.MD })
          .border({ width: { top: 1 }, color: this.tc(Neutral.BORDER) })

          // 识别依据：端侧模型的 Top 3 类别概率（演示模式无此信息，不展示）
          if (this.snippet.length > 0) {
            Column({ space: 3 }) {
              Text('识别依据（Top 3 类别概率）')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
              Text(this.snippet)
                .fontSize(FontSize.SMALL)
                .fontColor(this.tc(Neutral.TEXT_SUB))
                .width('100%')
            }
            .width('100%')
            .padding(Space.MD)
            .backgroundColor(this.tc(Neutral.SURFACE))
            .borderRadius(Radius.SM)
          }

          if (this.factor !== undefined) {
            Text('核算口径：' + this.fmtNum(this.factor.factorValue) + ' kg / ' + this.unit() +
              ' × 数量')
              .fontSize(FontSize.CAPTION)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
              .width('100%')
          }
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /* ---------- ④ 数量步进器 ---------- */
  @Builder
  StepperCard() {
    Column({ space: Space.MD }) {
      CfSection({ title: '确认数量' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          Row({ space: Space.LG }) {
            // －
            Text('－')
              .fontSize(22)
              .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
              .borderRadius(Radius.PILL)
              .onClick((): void => this.step(-1))

            Column({ space: 2 }) {
              TextInput({
                text: '' + this.amount,
                placeholder: '数量'
              })
                .type(InputType.Number)
                .layoutWeight(1)
                .height(44)
                .fontSize(FontSize.HEADING)
                .fontWeight(FontWeight.Bold)
                /* 同上：显式 placeholderColor + 描边，缺一即隐形 */
                .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
                .fontColor(this.tc(InputField.text(ThemePalette.dark)))
                .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
                .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
                .borderRadius(Radius.SM)
                .border({ width: 1.5, color: this.tc(InputField.border(ThemePalette.dark)) })
                .textAlign(TextAlign.Center)
                .onChange((v: string): void => this.onAmountInput(v))
              Text('单位：' + this.unit())
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // ＋
            Text('＋')
              .fontSize(22)
              .fontColor('#FFFFFF')
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
              .borderRadius(Radius.PILL)
              .onClick((): void => this.step(1))
          }
          .width('100%')

          // 快捷数量
          Row({ space: Space.SM }) {
            ForEach(this.quickAmounts(), (q: number) => {
              Text(this.fmtNum(q) + ' ' + this.unit())
                .fontSize(FontSize.CAPTION)
                .fontColor(this.amount === q ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.amount === q ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.SURFACE))
                .borderRadius(Radius.PILL)
                .onClick((): void => {
                  this.amount = q
                })
            }, (q: number): string => q.toString())
          }
          .width('100%')

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.tc(Neutral.BORDER))

          // 实时联动
          Row({ space: Space.MD }) {
            Column({ space: 2 }) {
              Text('预计减排')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
              Text(this.fmtNum(this.curKg()) + ' kg')
                .fontSize(FontSize.HEADING)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 2 }) {
              Text('预计积分')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
              Text('+' + this.curPoints())
                .fontSize(FontSize.HEADING)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.tc(Accent.WARNING))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  /** 快捷数量：默认量、2 倍、5 倍、10 倍 */
  private quickAmounts(): number[] {
    const base: number = this.factor !== undefined ? this.factor.defaultAmount : 1
    const out: number[] = [base]
    const mult: number[] = [2, 5, 10]
    for (let i = 0; i < mult.length; i++) {
      const v: number = Math.round(base * mult[i] * 100) / 100
      let dup: boolean = false
      for (let k = 0; k < out.length; k++) {
        if (out[k] === v) dup = true
      }
      if (!dup) out.push(v)
    }
    return out
  }

  /* ---------- ⑤ 确认录入 ---------- */
  @Builder
  ConfirmButton() {
    Row({ space: 6 }) {
      if (this.submitting) {
        LoadingProgress().width(16).height(16).color('#FFFFFF')
      } else {
        CfIcon({ kind: 'ui', code: 'check', iconSize: 15 })
      }
      Text(this.submitting ? '录入中…' : '确认录入')
        .fontSize(FontSize.BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(48)
    .linearGradient({
      angle: 90,
      colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
    })
    .borderRadius(Radius.PILL)
    .shadow(this.tw(Shadow.brand()))
    .enabled(!this.submitting)
    .onClick((): void => {
      this.confirm()
    })
  }

  /* ---------- 未识别时的引导 ---------- */
  @Builder
  GuideCard() {
    Column({ space: Space.MD }) {
      CfEmpty({
        icon: 'robot',
        line: true,
        text: '还没有识别结果',
        sub: '拍一张自行车、公交车、塑料瓶或食堂餐桌的照片，点「开始识别」由端侧模型匹配因子'
      })
      // 端侧引擎不可用时常驻显示真实原因（会话内预热失败后出现），
      // 取代原先只在 toast 里一闪而过的笼统提示
      if (AiVisionRecognizer.unavailableReason().length > 0) {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: 'warn', iconSize: 13 })
          Text('端侧识别不可用：' + AiVisionRecognizer.unavailableReason() +
            '，可点上方演示样例体验完整录入流程')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: Space.MD, right: Space.MD, top: Space.SM, bottom: Space.SM })
        .backgroundColor(this.tc(Neutral.SURFACE))
        .borderRadius(Radius.SM)
      }
      // 拍摄建议（与端侧模型的识别能力对齐）
      Column({ space: Space.MD }) {
        this.TipRow('bike', '骑行出行', '拍自行车 / 共享单车的整车照片')
        this.TipRow('bus', '公交出行', '拍公交车、站台或行程小票')
        this.TipRow('recycle', '回收分类', '拍塑料瓶、购物袋、纸巾或垃圾回收车')
        this.TipRow('plate', '光盘行动', '拍食堂餐桌、餐盘或用餐场景')
        this.TipRow('plate', '素食水果', '拍水果、蔬菜等餐食照片')
      }
      .width('100%')
      .padding(Space.LG)
      .backgroundColor(this.tc(Neutral.CARD))
      .borderRadius(Radius.MD)
      .shadow(this.tw(Shadow.card()))
    }
    .width('100%')
  }

  @Builder
  TipRow(icon: string, title: string, desc: string) {
    Row({ space: Space.MD }) {
      CfIcon({ kind: 'ui', code: icon, iconSize: 18 })
      Column({ space: 2 }) {
        Text(title)
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tc(Neutral.TEXT))
        Text(desc)
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }
}