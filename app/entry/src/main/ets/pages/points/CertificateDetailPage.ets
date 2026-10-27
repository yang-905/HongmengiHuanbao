import { toast } from '../../ui/Toast'
import { AppRouter, RouteName } from '../../common/router/AppRouter'
import { DataSource } from '../../net/DataSource'
import { LocalCert } from '../../data/MockStore'
import { Accent, Biz, FontSize, Neutral, Radius, Shadow, Space, EcoTheme, EcoMood } from '../../ui/Theme';
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfButton, CfCard, CfEmpty, CfTopBar } from '../../ui/Components'
import { AppleMotion } from '../../ui/AppleMotion';
import { Clipboard } from '../../utils/Clipboard';
import { CfIcon } from '../../ui/Icon';

/** 证书详情路由参数：ArkTS 严格模式禁止无类型对象字面量，故声明 interface */
interface CertificateDetailParam {
  id: number
}

/**

 * P20 证书详情（电子证书）
 */
@Component
export struct CertificateDetailPage {
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
  @State private certId: number = -1
  @State private cert: LocalCert | null = null
  @State private loading: boolean = true
  @State private saving: boolean = false

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    // 路由参数由 PageMap 经 AppStorage 传入
    const id: number | undefined = AppStorage.get<number>('detailCertId')
    if (id !== undefined && id !== null) {
      this.certId = id
      AppStorage.delete('detailCertId')
    }
    this.load()
  }

  /** 按路由参数在证书列表中定位；参数缺失时默认取最新一张 */
  private async load(): Promise<void> {
    try {
      const list: LocalCert[] = await DataSource.certificates()
      if (list.length === 0) {
        this.cert = null
      } else if (this.certId < 0) {
        this.cert = list[0]
      } else {
        this.cert = null
        for (let i: number = 0; i < list.length; i++) {
          if (list[i].certId === this.certId) {
            this.cert = list[i]
            break
          }
        }
        // 路由 id 失效时兜底展示最新一张，避免证书页空白
        if (this.cert === null) this.cert = list[0]
      }
    } catch (err) {
      this.cert = null
    }
  }
/** 分享：调用系统分享面板（演示环境给出轻提示） */
  private shareCert(): void {
    if (this.cert === null) return
    toast('已生成证书「' + this.cert!.treeType + '」分享卡，去分享给好友吧')
  }

  /** 保存到相册：演示环境用延时模拟写入耗时 */
  private saveToAlbum(): void {
    if (this.saving) return
    if (this.cert === null) return
    this.saving = true
    setTimeout((): void => {
      this.saving = false
      toast('证书已保存到相册（演示环境不写入真实文件）')
    }, 700)
  }

  /** 复制编号：写入系统剪贴板才算成功（原实现只弹 toast 未真复制） */
  private copyNo(): void {
    if (this.cert === null) return
    if (Clipboard.copy(this.cert!.certNo)) {
      toast('证书编号已复制：' + this.cert!.certNo)
    } else {
      toast('复制失败，请重试')
    }
  }

  /** 认养更多 */
  private openMall(): void {
    AppRouter.pathStack.pushPathByName(RouteName.POINTS_MALL, null)
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
  /** 入场动画的延帧定时器 id，-1 表示未启动（onDisappear 里清） */
  private pageInTimer: number = -1
  build() {
    NavDestination() {
      Column() {
        this.DetailContent()
      }
      // 页面入场动画（苹果口径：整页淡入 + 下方 12vp 浮起，见 AppleMotion）
      // ⚠️ 必须延一帧再置 true：同帧内 false→true 会被 ArkUI 合并，
      //    opacity/translate 补间不播（同 Index slotDeleteIn / DashboardPage entered 手法）。
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
    .hideTitleBar(true).opacity(this.themeTick >= 0 ? 1 : 0)
  }
@Builder
  DetailContent() {
    Column() {
      CfTopBar({
        title: '电子证书',
        onBack: (): void => {
          AppRouter.pathStack.pop()
        }
      })
      if (this.cert === null) {
        Column() {
          CfEmpty({
            icon: 'certificate',
            line: true,
            text: '证书不存在或已失效',
            sub: '返回证书夹重新选择一张'
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column({ space: Space.LG }) {
            this.Certificate()
            this.CertNote()
            this.ActionBar()
          }
          .width('100%')
          .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.MD, bottom: 30 })
        }
        .scrollBar(BarState.Off)
        // 关闭 iOS 式回弹边缘辉光（EdgeEffect.Spring 默认开启，
        // 滚到边缘会在容器边沿泛白，表现为「右侧一根白色竖条」）
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
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
@Builder
  Certificate() {
    Column() {
      // 内层白底，外层用渐变做描边，形成"电子证书"质感边框
      Column({ space: Space.XL }) {
        this.CertHead()
        this.CertNo()
        this.CertBody()
        this.CertSeal()
      }
      .width('100%')
      .padding({ top: Space.XL, bottom: Space.XL, left: Space.LG, right: Space.LG })
      .backgroundColor(this.tc(Neutral.CARD))
      .borderRadius(Radius.LG)
    }
    .width('100%')
    .padding(3)
    .linearGradient({
      angle: 135,
      colors: [[this.tc(EcoTheme.heroFrom(this.ecoLevel)), 0], [this.tc(EcoTheme.heroMid(this.ecoLevel)), 0.5], [this.tc(EcoTheme.heroTo(this.ecoLevel)), 1]]
    })
    .borderRadius(Radius.XL)
    .shadow(this.tw(Shadow.brand()))
  }
@Builder
  CertHead() {
    Column({ space: Space.SM }) {
      CfIcon({ kind: 'ui', code: 'tree', iconSize: 40 })
      Text('碳中和植树认养证书')
        .fontSize(FontSize.DISPLAY)
        .maxFontScale(FontSize.SCALE_NUM)
        .maxLines(1)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
      Text('CERTIFICATE OF TREE PLANTING')
        .fontSize(10)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
      // 抬头下的主色细分割线
      Row()
        .width(64)
        .height(3)
        .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
        .borderRadius(2)
        .margin({ top: Space.XS })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
@Builder
  CertNo() {
    Column({ space: 5 }) {
      Text('证书编号')
        .fontSize(FontSize.CAPTION)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
      Row({ space: Space.SM }) {
        Text(this.cert!.certNo)
          .fontSize(FontSize.TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
          .fontFamily('monospace')
          .letterSpacing(1)
        Text('复制')
          .fontSize(10)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
          .borderRadius(Radius.PILL)
      }
      .onClick((): void => this.copyNo())
    }
    .width('100%')
    .padding(Space.MD)
    .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
    .borderRadius(Radius.MD)
  }
@Builder
  CertBody() {
    Column({ space: Space.LG }) {
      this.InfoLine('持有人', this.cert!.ownerName, true)
      this.InfoLine('认养树种', this.cert!.treeType + '（' + this.cert!.treeCount + ' 棵）', false)
      this.InfoLine('认养数量', this.cert!.treeCount + ' 棵', false)
      this.InfoLine('消耗积分', this.cert!.costPoints + ' 分', false)
      this.InfoLine('颁发日期', this.cert!.issueDate, false)
      this.InfoLine('颁发机构', '一触青绿 · 碳普惠平台', false)
    }
    .width('100%')
  }

  /** 证书字段行：左侧标签 + 右侧值 + 虚线感分割 */
  @Builder
  InfoLine(label: string, value: string, strong: boolean) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
      Blank()
      Text(value)
        .fontSize(strong ? FontSize.TITLE : FontSize.BODY)
        .fontWeight(strong ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(strong ? this.tc(EcoTheme.primaryDeep(this.ecoLevel)) : this.tc(Neutral.TEXT))
        .maxLines(2)
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ bottom: Space.SM })
    .border({ width: { bottom: 1 }, color: this.tc(Neutral.BORDER) })
  }
@Builder
  CertSeal() {
    Row() {
      Column({ space: 3 }) {
        Stack({ alignContent: Alignment.Center }) {
          CfIcon({ kind: 'ui', code: 'sprout', iconSize: 24, color: this.tc(Accent.SUCCESS) })
        }
        .width(56)
        .height(56)
        .border({ width: 2, color: this.tc(Accent.SUCCESS) })
        .borderRadius(28)
        Text('低碳认证')
          .fontSize(9)
          .fontColor(this.tc(Accent.SUCCESS))
      }
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('本证书由碳积分兑换生成，编号唯一可溯源。')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .lineHeight(18)
        Text('每 1 棵认养树年均固碳约 18 kg CO₂e，' +
          '相当于减排 ' + (this.cert!.treeCount * 18) + ' kg CO₂e。')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .lineHeight(18)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Space.LG)
    .backgroundColor(this.tc(Accent.SUCCESS_BG))
    .borderRadius(Radius.MD)
  }
@Builder
  CertNote() {
    CfCard({ pad: Space.LG }) {
      Column({ space: Space.MD }) {
        this.NoteLine('兑换比例', '1 kg 减排 = ' + Biz.POINTS_PER_KG +
          ' 积分；' + Biz.POINTS_PER_TREE + ' 积分 = 1 棵树')
        this.NoteLine('防重号规则', '编号 = CF-颁发日期(YYYYMMDD)-序列-校验位')
        this.NoteLine('有效期', '长期有效，可用于公益宣传与个人展示')
      }
      .width('100%')
    }
  }

  @Builder
  NoteLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_MUTED))
      Blank()
      Text(value)
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .textAlign(TextAlign.End)
        .layoutWeight(1)
        .margin({ left: Space.MD })
    }
    .width('100%')
  }
@Builder
  ActionBar() {
    Column({ space: Space.MD }) {
      Row({ space: Space.MD }) {
        CfButton({
          text: '保存到相册',
          icon: 'download',
          primary: false,
          onTap: (): void => this.saveToAlbum()
        })
        CfButton({
          text: this.saving ? '保存中…' : '分享证书',
          icon: 'arrowup',
          flex: true,
          onTap: (): void => this.shareCert()
        })
      }
      .width('100%')

      Text('再认养一棵树，让森林继续生长')
        .fontSize(FontSize.SMALL)
        .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(Space.MD)
        .backgroundColor(this.tc(EcoTheme.primaryPale(this.ecoLevel)))
        .borderRadius(Radius.MD)
        .onClick((): void => this.openMall())
    }
    .width('100%')
  }
}
