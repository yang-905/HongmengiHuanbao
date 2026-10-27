import { toast } from '../../ui/Toast'
import { EcoMoodState } from '../../data/EcoMoodState'
import { Accent, FontSize, Glass, Neutral, Radius, Space, EcoMood, EcoTheme } from '../../ui/Theme';
import { CfButton, CfCard, CfCloseIcon } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/**

 * 题目：ArkTS 严格模式下对象字面量必须对应显式类型，故用 class 承载
 */
class QuizQuestion {
  /** 题干 */
  text: string = '';
  /** 选项文本 */
  options: string[] = [];
  /** 正确选项下标 */
  answer: number = 0;
  /** 答案解析 */
  tip: string = '';

  constructor(t: string, o: string[], a: number, tip: string) {
    this.text = t;
    this.options = o;
    this.answer = a;
    this.tip = tip;
  }
}

/** 三道低碳单选题（题库与 MockStore 科普文章口径一致） */
const QUESTIONS: QuizQuestion[] = [
  new QuizQuestion(
    '我国提出的"双碳"目标是指哪两项？',
    ['2030 年前碳达峰、2060 年前碳中和', '2025 年前碳达峰、2050 年前碳中和',
      '2035 年前碳达峰、2060 年前碳中和', '2030 年前碳中和、2060 年前碳达峰'],
    0,
    '双碳目标即 2030 年前实现碳达峰、2060 年前实现碳中和。'
  ),
  new QuizQuestion(
    '按 1 公里出行计算，排放量最低的是？',
    ['私家车', '地铁', '公交', '步行与骑行'],
    3,
    '步行与骑行几乎不产生直接排放，接近于零。'
  ),
  new QuizQuestion(
    '本 App 中「1 kg CO₂e 减排」可以兑换多少积分？',
    ['1 积分', '5 积分', '10 积分', '100 积分'],
    2,
    '碳积分与后端口径一致：1 kg 减排 = 10 积分，3000 积分 = 1 棵树。'
  )
]

/** 选项序号：A / B / C / D */
const LETTERS: string[] = ['A', 'B', 'C', 'D']

/**

 * P23 低碳小测验（半模态）
 * 保持原有用法：普通 @Component（不是 @CustomDialog），由宿主页 bindSheet 挂载。
 * 通过 onClose 回调交回关闭权，宿主页负责收起面板。
 * 3 道单选题：选项可点 → 提交后展示对错 → 给出得分与鼓励文案。
 */
@Component
export struct QuizSheet {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  @StorageProp('themeTick') themeTick: number = 0
  /** 关闭回调（宿主页 bindSheet 收起用） */
  onClose: () => void = (): void => {}

  /** 每题当前选择的选项下标，-1 表示未选 */
  @State private picked: number[] = [-1, -1, -1]
  /** 是否已提交 */
  @State private submitted: boolean = false

  /** 全部答完才允许提交 */
  private allPicked(): boolean {
    return this.picked[0] >= 0 && this.picked[1] >= 0 && this.picked[2] >= 0
  }

  /** 答对题数 */
  private score(): number {
    let n: number = 0
    for (let i: number = 0; i < QUESTIONS.length; i++) {
      if (this.picked[i] === QUESTIONS[i].answer) n++
    }
    return n
  }

  /** 得分文案 */
  private scoreText(): string {
    return this.score() + ' / ' + QUESTIONS.length
  }

  /** 鼓励文案：按答对数分档 */
  private encourageText(): string {
    const s: number = this.score()
    if (s === QUESTIONS.length) return '满分！你已经是碳知识小专家啦'
    if (s === 2) return '答对 2 题，基础扎实，再看一篇科普就更稳了'
    if (s === 1) return '答对 1 题，别灰心，回头翻翻「基础概念」专栏'
    return '全都答错了也没关系，行动比知识更重要，去记录第一条低碳行为吧'
  }

  /** 选择某题的某个选项：提交后锁定答案 */
  private choose(qi: number, oi: number): void {
    if (this.submitted) return
    const next: number[] = [this.picked[0], this.picked[1], this.picked[2]]
    next[qi] = oi
    this.picked = next
  }

  /** 提交：给出得分与鼓励 */
  private submit(): void {
    if (!this.allPicked()) {
      toast('还有题目没作答哦')
      return
    }
    this.submitted = true
    const s: number = this.score()
    toast('答题完成，得分 ' + this.scoreText())
    if (s === QUESTIONS.length) {
      // 全对额外奖励积分（与后端口径一致，每题约 5 分）
      toast('额外奖励 ' + s * 5 + ' 碳积分')
    }
  }

  /** 重做一轮 */
  private reset(): void {
    this.picked = [-1, -1, -1]
    this.submitted = false
  }

  /** 关闭面板 */
  private close(): void {
    this.onClose()
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

  build() {
    /*
     *   原写法把 Scroll 直接当根、只挂 layoutWeight(1) —— bindSheet 容器不是 flex 布局，
     *   layoutWeight 不生效 → Scroll 按内容撑高、超出 sheet 后被裁切、自身无滚动高度约束 → 滑不动。
     *   现外层包一层 Column(height 100%)：既填满 sheet，又让 Scroll 在 flex 容器内拿到
     *   剩余高度，内容超出时才能滚动。玻璃底/模糊/边框/入场过场移到外层，保证整块面板一致。
     */
    Column() {
      Scroll() {
        Column({ space: Space.LG }) {
          this.Header()

          ForEach(QUESTIONS, (q: QuizQuestion, qi: number) => {
            this.QuestionCard(q, qi)
          }, (q: QuizQuestion, qi: number): string => 'q' + qi)

          this.Footer()
        }
        .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
        .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 30 })
      }
      .scrollBar(BarState.Off)
      // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
      // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      // 关键：在 flex 父容器内占据剩余高度，内容超出才可滚动（根容器已 height 100%）
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    /*
     * 入场过场：面板插入时，内容从下方 40vp 淡入到原位。
     * 声明式 transition（非 animateTo 生命周期驱动），不依赖
     * aboutToAppear 回调，Previewer 与真机表现一致。
     */
    .transition({ translate: { y: 40 }, opacity: 0 })
    /*
     * 液态玻璃面板底：半透明 + 实时高斯模糊，
     * 让底下的文章/科普内容真实透出并虚化（此前完全透明，靠系统默认底色，
     * 没有玻璃质感）。材质口径见 Theme.ets Glass.SHEET_BG。
     */
    .backgroundColor(this.sheetBg())
    .backdropBlur(EcoMood.blurOf(this.ecoLevel) + 4)
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    // 底色/高光跟随碳档位平滑过渡，与页面根同一口径
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }
@Builder
  Header() {
    Row() {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          CfIcon({ kind: 'ui', code: 'brain', iconSize: 18, color: this.tc(Neutral.TEXT) })
          Text('低碳小测验')
            .fontSize(FontSize.HEADING)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
        }
        Text('共 ' + QUESTIONS.length + ' 题 · 答对可获额外积分')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      // 矢量叉号：'✕' 字符会触发字体回退，笔画出现灰色重影
      CfCloseIcon({
        btnSize: 32,
        glass: true,
        onTap: (): void => this.close()
      })
    }
    .width('100%')
  }
@Builder
  QuestionCard(q: QuizQuestion, qi: number) {
    // 半透明卡：面板根已有实时模糊，卡片不再叠加第二层（性能纪律），
    // 只把 0.86 实色换成 0.55 半透明透出根的模糊内容
    CfCard({ pad: Space.LG, bgColor: this.tc(Glass.PANEL_LIVE_BG) }) {
      Column({ space: Space.MD }) {
        // 题干
        Row({ space: Space.SM }) {
          Column() {
            Text('' + (qi + 1))
              .fontSize(FontSize.SMALL)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(22)
          .height(22)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.submitted && this.picked[qi] === q.answer ? this.tc(Accent.SUCCESS) : this.tc(EcoTheme.primary(this.ecoLevel)))
          .borderRadius(11)
          Text(q.text)
            .fontSize(FontSize.BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .lineHeight(21)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 选项
        Column({ space: Space.SM }) {
          ForEach(q.options, (opt: string, oi: number) => {
            this.OptionRow(q, qi, oi, opt)
          }, (opt: string, oi: number): string => 'o' + qi + '_' + oi)
        }
        .width('100%')

        // 提交后展示解析
        if (this.submitted) {
          Row({ space: Space.SM }) {
            CfIcon({ kind: 'ui', code: 'bulb', iconSize: 12 })
            Text(q.tip)
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_SUB))
              .lineHeight(18)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(Space.MD)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.SM)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  OptionRow(q: QuizQuestion, qi: number, oi: number, opt: string) {
    Row({ space: Space.MD }) {
      // 选项字母
      Column() {
        Text(LETTERS[oi])
          .fontSize(FontSize.SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.optionFg(qi, oi))
      }
      .width(26)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.optionBg(qi, oi))
      .borderRadius(Radius.PILL)

      Text(opt)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT))
        .lineHeight(19)
        .layoutWeight(1)

      // 提交后：对勾 / 叉
      if (this.submitted && oi === q.answer) {
        CfIcon({ kind: 'ui', code: 'check', iconSize: 17, color: this.tc(Accent.SUCCESS) })
      } else if (this.submitted && this.picked[qi] === oi) {
        // 矢量叉号（无底色）：同样是 '✕' 字符会触发字体回退出现重影
        CfCloseIcon({
          btnSize: 18,
          showBg: false,
          color: this.tc(Accent.DANGER)
        })
      }
    }
    .width('100%')
    .padding(Space.MD)
    .backgroundColor(this.rowBg(qi, oi))
    .borderRadius(Radius.SM)
    .border({ width: 1, color: this.rowBorder(qi, oi) })
    .onClick((): void => this.choose(qi, oi))
  }
private isPicked(qi: number, oi: number): boolean {
    return this.picked[qi] === oi
  }

  private isAnswer(qi: number, oi: number): boolean {
    return oi === QUESTIONS[qi].answer
  }

  /** 行底色 */
  private rowBg(qi: number, oi: number): string {
    if (!this.submitted) {
      return this.isPicked(qi, oi) ? this.tc(EcoTheme.primaryPale(this.ecoLevel)) : this.tc(Neutral.SURFACE)
    }
    if (this.isAnswer(qi, oi)) return this.tc(Accent.SUCCESS_BG)
    if (this.isPicked(qi, oi)) return this.tc(Accent.DANGER_BG)
    return this.tc(Neutral.SURFACE)
  }

  /** 行描边 */
  private rowBorder(qi: number, oi: number): string {
    if (!this.submitted) {
      return this.isPicked(qi, oi) ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.BORDER)
    }
    if (this.isAnswer(qi, oi)) return this.tc(Accent.SUCCESS)
    if (this.isPicked(qi, oi)) return this.tc(Accent.DANGER)
    return this.tc(Neutral.BORDER)
  }

  /** 选项圆底色 */
  private optionBg(qi: number, oi: number): string {
    if (!this.submitted) {
      return this.isPicked(qi, oi) ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Neutral.CARD)
    }
    if (this.isAnswer(qi, oi)) return this.tc(Accent.SUCCESS)
    if (this.isPicked(qi, oi)) return this.tc(Accent.DANGER)
    return this.tc(Neutral.CARD)
  }

  /** 选项圆前景色 */
  private optionFg(qi: number, oi: number): string {
    if (!this.submitted) {
      return this.isPicked(qi, oi) ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB)
    }
    if (this.isAnswer(qi, oi) || this.isPicked(qi, oi)) return '#FFFFFF'
    return this.tc(Neutral.TEXT_SUB)
  }
@Builder
  Footer() {
    Column({ space: Space.MD }) {
      if (this.submitted) {
        // 结果卡：得分 + 鼓励文案
        Column({ space: Space.SM }) {
          // 庆祝瞬间用卡通 emoji：这是情绪高点，线稿奖杯太冷静
          Text('🎉').fontSize(34).maxFontScale(FontSize.SCALE_NUM)
          Text('得分 ' + this.scoreText())
            .fontSize(FontSize.DISPLAY)
            .maxFontScale(FontSize.SCALE_NUM)
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          Text(this.encourageText())
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .lineHeight(19)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(Space.XL)
        .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
        .borderRadius(Radius.LG)
      }

      Row({ space: Space.MD }) {
        if (this.submitted) {
          CfButton({
            text: '再做一次',
            icon: 'refresh',
            primary: false,
            onTap: (): void => this.reset()
          })
          CfButton({
            text: '完成',
            icon: 'check',
            flex: true,
            onTap: (): void => this.close()
          })
        } else {
          CfButton({
            text: this.allPicked() ? '提交答案' : '还有 ' + this.unpickedCount() + ' 题未答',
            icon: 'note',
            flex: true,
            onTap: (): void => this.submit()
          })
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  /** 未作答题数 */
  private unpickedCount(): number {
    let n: number = 0
    for (let i: number = 0; i < QUESTIONS.length; i++) {
      if (this.picked[i] < 0) n++
    }
    return n
  }
}
