/**
 * P33 个人资料（设置「个人资料」/「我的」头像进入）
 */
import { Toast, toast } from '../../ui/Toast'
import { AppRouter } from '../../common/router/AppRouter'
import { AccountStore, UserProfile } from '../../data/AccountStore'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { EcoMoodState } from '../../data/EcoMoodState'
import {
  EcoMood,
  EcoTheme,
  FontSize,
  InputField,
  Neutral,
  Radius,
  Space,
  ThemePalette
} from '../../ui/Theme'
import { CfButton, CfCard, CfSection, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 头像候选（emoji 圆盘，与全应用视觉语言一致，无图片资源依赖） */
const AVATARS: string[] = ['🌱', '🐱', '🦊', '🐼', '🌸', '🚀', '🍀', '🌊', '⭐', '🌳']
/** 性别候选 */
const GENDERS: string[] = ['男', '女', '保密']

@Component
export struct ProfilePage {
  @StorageProp('themeTick') themeTick: number = 0

  /** 节点级主题透传：色值经本方法取值即建立 themeTick 依赖，换血后强制重取 static 新色 */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  @State private avatar: string = '🌱'
  @State private name: string = ''
  @State private gender: string = ''
  @State private phone: string = ''
  @State private nameFocused: boolean = false
  @State private phoneFocused: boolean = false
  /** 保存中防连点 */
  @State private busy: boolean = false
  /** 相册选图进行中（防重复拉起选择器） */
  @State private imgPicking: boolean = false
  /** 当前登录账号（只读展示） */
  @State private account: string = ''
  /**
   * 强制完善模式：注册成功后首次弹出（Index 打 profileMandatory 标记）。
   * 此时昵称与性别为必填项、返回被拦截、隐藏「切换账号」，保存后才能进入应用。
   */
  @StorageProp('profileMandatory') mandatory: boolean = false

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    Toast.bind(this.getUIContext())
    // 通知 Index 隐藏右下角「＋」悬浮球：本页是表单页，
    // 悬浮球会压住手机号输入框（barSlotDelete 同款 AppStorage 标记模式）
    AppStorage.setOrCreate('hideFab', true)
    this.loadProfile()
  }

  /**

   * 资料页「真正上屏」信号 → 解除 Index 的注册引导误触闸门。
 */
  private notifyShown(): void {
    AppStorage.setOrCreate('profileSetupShown', true)
  }

  /** onAppear 兜底上屏信号的延时定时器 id，-1 表示未启动 */
  private shownTimer: number = -1

  aboutToDisappear(): void {
    // 离开本页恢复悬浮球（push/pop、切账号清栈都会触发销毁）
    AppStorage.setOrCreate('hideFab', false)
    // 页面已销毁：兜底上屏定时器不必再跑（onShown 正常路径已发信号）
    if (this.shownTimer !== -1) {
      clearTimeout(this.shownTimer)
      this.shownTimer = -1
    }
  }

  private loadProfile(): void {
    const u: string = AccountStore.currentUser()
    this.account = u
    const p: UserProfile = AccountStore.profileOf(u)
    this.avatar = p.avatar
    this.name = p.name
    this.gender = p.gender
    this.phone = p.phone
  }
private async save(): Promise<void> {
    if (this.busy) return
    if (this.account.length === 0) {
      toast('登录状态异常，请重新登录')
      return
    }
    const nm: string = this.name.trim()
    const phone: string = this.phone.trim()
    // 强制项：注册后首次完善必须填昵称；性别任何路径都必须选
    if (this.mandatory && nm.length === 0) {
      toast('请填写昵称')
      return
    }
    if (this.gender.length === 0) {
      toast('请选择性别')
      return
    }
    // 选填字段：填了才校验（11 位、1 开头）
    if (phone.length > 0 && !/^1\d{10}$/.test(phone)) {
      toast('手机号格式不正确（11 位，1 开头）')
      return
    }
    this.busy = true
    try {
      const prof: UserProfile = new UserProfile()
      prof.avatar = this.avatar
      // 非强制路径名字留空回退账号名，保证「我的」页永远有称谓可显示
      prof.name = nm.length > 0 ? nm : this.account
      prof.gender = this.gender
      prof.phone = phone
      await AccountStore.saveProfile(this.account, prof)
      if (this.mandatory) {
        AppStorage.setOrCreate('profileMandatory', false)
      }
      toast(this.mandatory ? '设置完成，欢迎加入' : '资料已保存')
      AppRouter.pathStack.pop()
    } catch (err) {
      toast('保存失败，请重试')
    } finally {
      this.busy = false
    }
  }

  /**

   * 从相册选一张图作头像。
 */
  private async pickImage(): Promise<void> {
    if (this.imgPicking) return
    this.imgPicking = true
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      opts.maxSelectNumber = 1
      const res: photoAccessHelper.PhotoSelectResult = await picker.select(opts)
      if (res.photoUris.length === 0) {
        return // 用户取消选择
      }
      const c: common.Context | undefined = AppStorage.get<common.Context>('appContext')
      if (c === undefined || c === null) {
        toast('应用上下文未就绪，请重启应用')
        return
      }
      // 文件名只保留安全字符，账号里的中文/符号折叠成下划线
      const safeName: string = AccountStore.currentUser().replace(/[^0-9a-zA-Z]/g, '_')
      const dst: string = (c as common.UIAbilityContext).filesDir + '/avatar_' + safeName + '.img'
      const srcFile: fs.File = fs.openSync(res.photoUris[0], fs.OpenMode.READ_ONLY)
      const dstFile: fs.File = fs.openSync(dst, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.copyFileSync(srcFile.fd, dstFile.fd)
      fs.closeSync(srcFile)
      fs.closeSync(dstFile)
      this.avatar = 'file://' + dst
      toast('头像已选择，记得点保存资料')
    } catch (err) {
      toast('本环境不支持相册选图，请在真机/模拟器上使用')
    } finally {
      this.imgPicking = false
    }
  }

  /**

   * 切换账号：注销会话 → Index 登录闸门自动翻出登录页。
 */
  private async switchAccount(): Promise<void> {
    const ok: boolean = await Toast.confirm(
      '切换后需重新登录；当前账号的数据仍保留在本机，随时可以切回来',
      '切换账号'
    )
    if (!ok) return
    await AccountStore.logout()
  }
@StorageProp('ecoLevel') ecoLevel: string = 'none'

  private ecoBg(): string {
    return this.tc(EcoTheme.bg(this.ecoLevel))
  }

  @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0

  onEcoTick(): void {
    EcoMoodState.refresh()
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
          title: this.mandatory ? '完善资料' : '个人资料',
          onBack: (): void => {
            // 强制完善模式下不可跳过：昵称与性别是必填项
            if (this.mandatory) {
              toast('请先完善昵称和性别')
              return
            }
            AppRouter.pathStack.pop()
          }
        })
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.AccountBlock()
            this.AvatarBlock()
            this.InfoBlock()
            this.ActionBlock()
          }
          .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
          .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 30 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(this.ecoBg())
        .backdropBlur(EcoMood.blurOf(this.ecoLevel))
        .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
        /*
         * onAppear 兜底上屏信号（见 notifyShown 注释）：
         * 根节点挂载 = 内容已构建并挂到树上，虽早于转场结束，但比
         * aboutToAppear 晚；延 300ms 再发，覆盖 push 滑入动画时长。
         */
        .onAppear((): void => {
          this.shownTimer = setTimeout((): void => {
            this.shownTimer = -1
            this.notifyShown()
          }, 300)
        })
      }
      .width('100%')
      .height('100%')
      // 页面底色必须铺满含顶栏的整列：顶栏区域无人上色时，
      // NavDestination 默认白底透出来 = 深色模式顶部「白额头」，
      // 白色顶栏文字压白底直接隐形（同设置页修复口径）。
      // ⚠️ ProfilePage 必须有实底：FAB 已在本页隐藏，底色不能透明。
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
    /*
     * onShown：系统级「页面已显示」回调（转场结束、真正上屏）。
     * 这是解除误触闸门最准的信号 —— 主框架此刻已被完全盖住。
     */
    .onShown((): void => {
      this.notifyShown()
    })
  }
@Builder
  AccountBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '当前账号' })
      CfCard({ pad: Space.LG }) {
        Row({ space: Space.MD }) {
          Stack({ alignContent: Alignment.Center }) {
            CfIcon({ kind: 'ui', code: 'user', iconSize: 20 })
          }
          .width(44)
          .height(44)
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.SM)
          Column({ space: 2 }) {
            Text(this.account.length > 0 ? this.account : '未登录')
              .fontSize(FontSize.BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tc(Neutral.TEXT))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('本账号的行为记录、积分、徽章与其他账号完全独立')
              .fontSize(FontSize.SMALL)
              .fontColor(this.tc(Neutral.TEXT_MUTED))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  AvatarBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '头像' })
      CfCard({ pad: Space.LG }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          // 本地图片格：当前头像是图片时显示图片本体（常亮选中环），否则显示上传入口
          if (AccountStore.isImageAvatar(this.avatar)) {
            Image(this.avatar)
              .width(52)
              .height(52)
              .objectFit(ImageFit.Cover)
              .borderRadius(16)
              .border({ width: 2, color: this.tc(EcoTheme.primary(this.ecoLevel)) })
              .scale({ x: 1.08, y: 1.08 })
              .animation({ duration: 200, curve: Curve.EaseOut })
              .margin({ bottom: 10 })
              .onClick((): void => {
                this.pickImage()
              })
          } else {
            Stack({ alignContent: Alignment.Center }) {
              CfIcon({ kind: 'ui', code: 'photo', iconSize: 26 })
            }
            .width(52)
            .height(52)
            .backgroundColor(this.tc(Neutral.SURFACE))
            .borderRadius(16)
            .margin({ bottom: 10 })
            .onClick((): void => {
              this.pickImage()
            })
          }
          ForEach(AVATARS, (a: string) => {
            Text(a)
              .fontSize(26)
              .maxFontScale(FontSize.SCALE_NUM)
              .width(52)
              .height(52)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.avatar === a
                ? this.tc(EcoTheme.primaryPale(this.ecoLevel))
                : this.tc(Neutral.SURFACE))
              .borderRadius(16)
              .border({
                width: 2,
                color: this.avatar === a
                  ? this.tc(EcoTheme.primary(this.ecoLevel))
                  : Color.Transparent
              })
              .scale({
                x: this.avatar === a ? 1.08 : 1,
                y: this.avatar === a ? 1.08 : 1
              })
              .animation({ duration: 200, curve: Curve.EaseOut })
              .margin({ bottom: 10 })
              .onClick((): void => {
                this.avatar = a
              })
            }, (a: string): string => a)
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  InfoBlock() {
    Column({ space: Space.MD }) {
      CfSection({ title: '基本资料' })
      CfCard({ pad: Space.LG }) {
        Column({ space: Space.MD }) {
          Text('名字')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .width('100%')
          TextInput({ placeholder: '给自己起个名字', text: this.name })
            .maxLength(12)
            .fontSize(FontSize.BODY)
            .fontColor(this.tc(InputField.text(ThemePalette.dark)))
            .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
            .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
            .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
            .borderRadius(Radius.MD)
            .border({
              width: 1.5,
              color: this.nameFocused
                ? this.tc(InputField.focusBorder(ThemePalette.dark))
                : this.tc(InputField.border(ThemePalette.dark))
            })
            .padding({ left: 14, right: 14 })
            .height(46)
            .onFocus((): void => {
              this.nameFocused = true
            })
            .onBlur((): void => {
              this.nameFocused = false
            })
            .onChange((v: string): void => {
              this.name = v
            })

          Text('性别')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .width('100%')
          Row({ space: Space.SM }) {
            ForEach(GENDERS, (g: string) => {
              Text(g)
                .fontSize(FontSize.SMALL)
                .fontWeight(this.gender === g ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.gender === g ? '#FFFFFF' : this.tc(Neutral.TEXT_SUB))
                .textAlign(TextAlign.Center)
                .height(34)
                .layoutWeight(1)
                .borderRadius(Radius.PILL)
                .backgroundColor(this.gender === g
                  ? this.tc(EcoTheme.primary(this.ecoLevel))
                  : this.tc(Neutral.SURFACE))
                .animation({ duration: 200, curve: Curve.EaseOut })
                .onClick((): void => {
                  this.gender = g
                })
            }, (g: string): string => g)
          }
          .width('100%')

          Text('手机号（选填）')
            .fontSize(FontSize.SMALL)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .width('100%')
          TextInput({ placeholder: '选填，仅用于找回账号', text: this.phone })
            .type(InputType.PhoneNumber)
            .maxLength(11)
            .fontSize(FontSize.BODY)
            .fontColor(this.tc(InputField.text(ThemePalette.dark)))
            .placeholderColor(this.tc(InputField.placeholder(ThemePalette.dark)))
            .caretColor(this.tc(InputField.cursor(ThemePalette.dark)))
            .backgroundColor(this.tc(InputField.bg(ThemePalette.dark)))
            .borderRadius(Radius.MD)
            .border({
              width: 1.5,
              color: this.phoneFocused
                ? this.tc(InputField.focusBorder(ThemePalette.dark))
                : this.tc(InputField.border(ThemePalette.dark))
            })
            .padding({ left: 14, right: 14 })
            .height(46)
            .onFocus((): void => {
              this.phoneFocused = true
            })
            .onBlur((): void => {
              this.phoneFocused = false
            })
            .onChange((v: string): void => {
              this.phone = v
            })
        }
        .width('100%')
      }
    }
    .width('100%')
  }
@Builder
  ActionBlock() {
    Column({ space: Space.MD }) {
      CfButton({
        text: this.busy ? '保存中…' : (this.mandatory ? '完成并进入' : '保存资料'),
        icon: 'download',
        block: true,
        primary: true,
        onTap: (): void => {
          this.save()
        }
      })
      // 强制完善模式下不提供切换账号（还没真正进入应用）
      if (!this.mandatory) {
        CfButton({
          text: '切换账号',
          icon: 'refresh',
          block: true,
          primary: false,
          onTap: (): void => {
            this.switchAccount()
          }
        })
        Text('切换账号后需重新登录，各账号数据互不影响')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: Space.SM })
  }
}
