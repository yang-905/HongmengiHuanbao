/**
 * 登录 / 注册闸门（未登录时整屏唯一可见内容，由 Index 根 Stack 条件渲染）
 * ------------------------------------------------------------------
 * 非路由页面（不进 NavPathStack）：会话态由 AccountStore 写 AppStorage
 * ('sessionUser')，Index 闸门监听后自动挂载主框架，本组件随之退场。
 *
 * 规则（用户要求）：
 *   · 账号不能为空（trim 后非空、不含空格、≤20 字符）
 *   · 密码 = 8 位、仅字母和数字、须同时包含字母与数字
 *   · 注册成功自动登录；登录页提供已注册账号快捷预填 chips
 *     （同一台设备上切换账号 = 注销后在这里点另一个账号，数据互不冲突）
 *
 * 视觉：与全应用同一套「碳情绪 + 液态玻璃」语言 ——
 *   实色底（bgSolid）+ 顶部档位色径向光晕 + 玻璃卡 + 品牌渐变主按钮。
 *   ⚠️ 所有 static 取色点必须经 tc() 包裹建立 themeTick 依赖，
 *   否则深色换血后本页停留浅色套值（全库既有踩坑，见 Components.ets）。
 */
import { Toast, toast } from '../../ui/Toast'
import { AccountStore } from '../../data/AccountStore'
import {
  Accent,
  EcoTheme,
  FontSize,
  Glass,
  InputField,
  Neutral,
  Radius,
  Shadow,
  Space,
  ThemePalette
} from '../../ui/Theme'
import { CfButton, CfCard } from '../../ui/Components'
import { GlassLight, GlassTier } from '../../ui/GlassLight'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 模式：登录 / 注册 */
const MODE_LOGIN: string = 'login'
const MODE_REGISTER: string = 'register'

@Component
export struct LoginGate {
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

  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  @State private mode: string = MODE_LOGIN
  @State private user: string = ''
  @State private pass: string = ''
  @State private userFocused: boolean = false
  @State private passFocused: boolean = false
  /** 提交中：防连点重复注册/登录 */
  @State private busy: boolean = false
  /** 校验/登录失败文案（空串 = 无错误，不占位） */
  @State private err: string = ''
  /** 本机已注册账号（快捷预填 chips） */
  @State private knownUsers: string[] = []

  async aboutToAppear(): Promise<void> {
    Toast.bind(this.getUIContext())
    // 兜底自愈：预览器不走 EntryAbility 启动链，账号表（含内置开发者 '1'）
    // 可能未初始化，这里补一次 init（幂等），chips 才能列出已注册账号
    await AccountStore.init()
    this.knownUsers = AccountStore.accountNames()
  }

  /* ---------- 交互 ---------- */

  private switchMode(m: string): void {
    if (this.mode === m) return
    this.mode = m
    this.err = ''
  }

  /** 登录/注册提交。成功后 AccountStore 会广播 sessionUser，Index 闸门自动翻转 */
  private async submit(): Promise<void> {
    if (this.busy) return
    this.busy = true
    this.err = ''
    const isReg: boolean = this.mode === MODE_REGISTER
    /*
     * ⚠️ 注册意图标记必须落 在 await register() **之前**（用户反馈：
     * 「注册成功后信息录入页比主页面慢，手快能点到子页面」）。
     *
     * register() 内部最后一步是 setSession() → AppStorage.setOrCreate
     * ('sessionUser') → 立刻同步触发 Index 的 @Watch onSessionUser →
     * Index 重建、主框架挂载。也就是说：**onSessionUser 触发时刻，
     * 标记必须已经在位**，否则 Index 读不到「本次是注册」，就没法在
     * 主框架第一帧预置闸门（空窗期又露出来了）。
     *
     * 两个标记分工：
     *   · profileSetupIntent —— 只给 Index.onSessionUser 读，触发闸门
     *     预置，onSessionUser 里消费即清（一次性）；
     *   · pendingProfileSetup —— 给 Navigation.onAppear 读，触发
     *     强制 push 资料页（沿用原口径）。
     * 注册失败（重名/校验不过）两者都要撤销，否则下次登录会被误判成
     * 「注册流程」而白弹一次资料页。
     */
    if (isReg) {
      AppStorage.setOrCreate('profileSetupIntent', true)
      AppStorage.setOrCreate('pendingProfileSetup', true)
    }
    try {
      const u: string = this.user.trim()
      const err: string = isReg
        ? await AccountStore.register(u, this.pass)
        : await AccountStore.login(u, this.pass)
      if (err.length > 0) {
        this.err = err
        // 注册失败：撤销意图标记，别让本次失败污染后续流程
        if (isReg) {
          AppStorage.setOrCreate('profileSetupIntent', false)
          AppStorage.setOrCreate('pendingProfileSetup', false)
        }
      } else {
        // ⚠️ 成功路径**不要**清 profileSetupIntent：
        // 该标记由 Index.onSessionUser 消费（它会 clear 掉）。
        // 若这里抢先清掉，而 @Watch 回调恰好晚一拍触发，就丢了闸门
        // 预置的机会 —— 空窗期又会露出来。留着让 Index 兜底清理。
        toast(isReg ? '注册成功，请完善个人资料' : ('欢迎回来，' + u))
      }
    } catch (e) {
      this.err = '操作失败，请重试'
      if (isReg) {
        AppStorage.setOrCreate('profileSetupIntent', false)
        AppStorage.setOrCreate('pendingProfileSetup', false)
      }
    } finally {
      this.busy = false
    }
  }

  /** 点已注册账号 chip：预填账号名并聚焦到密码框语义（直接置登录模式） */
  private pickKnown(u: string): void {
    this.mode = MODE_LOGIN
    this.user = u
    this.err = ''
  }

  /* ---------- 输入框通用样式 ---------- */

  private fieldBorder(focused: boolean): string {
    if (focused) return this.tc(InputField.focusBorder(ThemePalette.dark))
    return this.tc(InputField.border(ThemePalette.dark))
  }

  @Builder
  FieldInput(placeholder: string, isPass: boolean) {
    TextInput({
      placeholder: placeholder,
      text: isPass ? this.pass : this.user
    })
      .type(isPass ? InputType.Password : InputType.Normal)
      // 密码至少 8 位、账号最长 20：统一封顶 20，不会出现多敲收不进
      .maxLength(20)
      .fontSize(FontSize.BODY)
      .fontColor(this.tc(InputField.text(ThemePalette.dark)))
      .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
      .placeholderFont({ size: FontSize.BODY })
      .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
      .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
      .borderRadius(Radius.MD)
      .border({ width: 1.5, color: this.fieldBorder(isPass ? this.passFocused : this.userFocused) })
      .padding({ left: 14, right: 14 })
      .height(46)
      .onFocus((): void => {
        if (isPass) {
          this.passFocused = true
        } else {
          this.userFocused = true
        }
      })
      .onBlur((): void => {
        if (isPass) {
          this.passFocused = false
        } else {
          this.userFocused = false
        }
      })
      .onChange((v: string): void => {
        if (isPass) {
          this.pass = v
        } else {
          this.user = v
        }
        // 用户开始修改即清错，避免旧错误一直挂着
        if (this.err.length > 0) this.err = ''
      })
  }

  @Builder
  FieldLabel(text: string) {
    Text(text)
      .fontSize(FontSize.SMALL)
      .fontColor(this.tc(Neutral.TEXT_SUB))
      .width('100%')
  }

  @Builder
  ModeChip(label: string, key: string) {
    Text(label)
      .fontSize(FontSize.BODY)
      .fontWeight(this.mode === key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.mode === key ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
      .textAlign(TextAlign.Center)
      .height(38)
      .layoutWeight(1)
      .borderRadius(Radius.PILL)
      .backgroundColor(this.mode === key
        ? this.tc(EcoTheme.primary(this.ecoLevel))
        : Color.Transparent)
      .animation({ duration: 220, curve: Curve.EaseOut })
      .onClick((): void => this.switchMode(key))
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: Space.LG }) {
          /* 品牌区 */
          Column({ space: Space.MD }) {
            Column() {
              CfIcon({ kind: 'ui', code: 'sprout', iconSize: 40 })
            }
            .width(84)
            .height(84)
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
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tc(Neutral.TEXT))

            Text('轻轻一点，记录你的绿色日常')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: Space.XL })

          /* 模式切换：登录 / 注册 */
          Row() {
            this.ModeChip('登录', MODE_LOGIN)
            this.ModeChip('注册', MODE_REGISTER)
          }
          .width('100%')
          .padding(3)
          .borderRadius(Radius.PILL)
          .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.SEGMENT_TRACK_BG), GlassTier.PILL, '', 1)))
          .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })

          /* 表单卡（CfCard 统一光照/深色口径） */
          CfCard({ pad: Space.LG }) {
            Column({ space: Space.MD }) {
              this.FieldLabel('账号')
              this.FieldInput('请输入账号（不能为空）', false)

              this.FieldLabel('密码')
              this.FieldInput('请输入密码', true)

              Text((this.mode === MODE_REGISTER
                ? '密码规则：至少 8 位，须同时包含字母和数字（如 ab12cd34）'
                : '密码为注册时设置的字母 + 数字组合（至少 8 位）')
                + (this.pass.length > 0 ? ' · 已输 ' + this.pass.length + ' 位' : ''))
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .width('100%')

              if (this.err.length > 0) {
                Row({ space: 4 }) {
                  CfIcon({ kind: 'ui', code: 'warn', iconSize: 13, color: this.tc(Accent.DANGER) })
                  Text(this.err)
                    .fontSize(FontSize.SMALL)
                    .fontColor(this.tc(Accent.DANGER))
                    .layoutWeight(1)
                }
                .width('100%')
              }

              CfButton({
                text: this.busy ? '请稍候…' : (this.mode === MODE_LOGIN ? '登录' : '注册并登录'),
                block: true,
                primary: true,
                onTap: (): void => {
                  this.submit()
                }
              })
            }
            .width('100%')
          }

          /* 已注册账号快捷切换（登录模式 & 本机已有账号时展示） */
          if (this.mode === MODE_LOGIN && this.knownUsers.length > 0) {
            Column({ space: Space.SM }) {
              Text('本机已注册账号 · 点击直接预填')
                .fontSize(FontSize.CAPTION)
                .fontColor(this.tc(Neutral.TEXT_MUTED))
                .width('100%')
              // chips 自动换行：账号数量不定，固定两列会溢出
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.knownUsers, (u: string) => {
                  Text(u)
                    .fontSize(FontSize.SMALL)
                    .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
                    .borderRadius(Radius.PILL)
                    .margin({ right: 8, bottom: 8 })
                    .onClick((): void => this.pickKnown(u))
                }, (u: string): string => u)
              }
              .width('100%')
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 40 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    // 键盘弹出时整页上抬，输入框不被遮挡（expandSafeArea 已由根 Stack 处理）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
    .backgroundColor(this.tc(EcoTheme.bgSolid(this.ecoLevel)))
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
  }
}
