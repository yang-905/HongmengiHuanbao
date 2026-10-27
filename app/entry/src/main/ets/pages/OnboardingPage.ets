import { toast } from '../ui/Toast'
import { Accent, Brand, FontSize, Glass, Neutral, Radius, Shadow, Space,
  EcoTheme,
  EcoMood,
} from '../ui/Theme'
import { EcoMoodState } from '../data/EcoMoodState'
import { CfGlassDisc } from '../ui/Components'
import { GlassLight, GlassTier } from '../ui/GlassLight'
import { AppleMotion } from '../ui/AppleMotion';
import { CfIcon } from '../ui/Icon';

/**

 * 引导页单屏内容：ArkTS 严格模式下对象字面量必须对应显式类型，故声明 class
 */
class GuidePage {
  /** 主图标 code（IconMap 的 ui 表），原先是 emoji */
  icon: string = '';
  /** 标题 */
  title: string = '';
  /** 说明文案 */
  desc: string = '';
  /** 本屏强调色（取自 Theme 令牌，禁止硬编码） */
  accent: string = '';
  /** 本屏浅底色（取自 Theme 令牌，禁止硬编码） */
  tint: string = '';

  constructor(e: string, t: string, d: string, a: string, c: string) {
    this.icon = e;
    this.title = t;
    this.desc = d;
    this.accent = a;
    this.tint = c;
  }
}

/**

 * 三屏引导内容：低碳核算 / 积分激励 / 数据看板
 */
const PAGES: GuidePage[] = [
  new GuidePage('sprout', '记录低碳，算清碳账',
    '27 项绿色行为因子，步行、公交、节电、回收、光盘……随手记一笔，' +
    'App 就按权威排放因子帮你算出这天的碳减排量。',
    Brand.PRIMARY, Brand.PRIMARY_PALE),
  new GuidePage('coin', '减排变积分，积分变树',
    '每 1 kg 减排得 10 碳积分，3000 积分就能认养 1 棵真实的树并拿到电子证书，' +
    '让看不见的减排变成看得见的绿色。',
    Accent.WARNING, Accent.WARNING_BG),
  new GuidePage('chart', '看板趋势，全家一起减',
    '月度账单、四大类占比、成长等级、家庭碳账户一应俱全，' +
    '把个人记录汇成家庭合力，一起把低碳坚持下来。',
    Accent.INFO, Accent.INFO_BG)
]

/**

 * P02 功能引导页（仅首次启动展示，由 Index 条件渲染）
 * 三屏轮播：用 @State 索引切换当前屏，不使用 Swiper，
 * 保证 Previewer 与低版本设备都能稳定渲染；
 * 底部「下一步 / 跳过」按钮，末屏文案变为「开始体验」。
 */
@Component
export struct OnboardingPage {
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
  /** 宿主回调：完成或跳过后收起引导 */
  onFinish: () => void = (): void => {}

  /** 当前屏索引 */
  @State private index: number = 0

  /** 当前屏数据 */
  private current(): GuidePage {
    return PAGES[this.index]
  }

  /** 是否最后一屏 */
  private isLast(): boolean {
    return this.index >= PAGES.length - 1
  }

  /** 下一步：末屏则完成引导 */
  private next(): void {
    if (this.isLast()) {
      this.onFinish()
      return
    }
    this.index = this.index + 1
  }

  /** 跳过：直接完成引导 */
  private skip(): void {
    toast('随时可在「设置」里重新查看引导')
    this.onFinish()
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
    }
  }

  build() {
    Column() {
      // 顶部：可跳过
      Row() {
        Text('')
          .fontSize(FontSize.CAPTION).opacity(this.themeTick >= 0 ? 1 : 0)
          .layoutWeight(1)
        Text('跳过')
          .fontSize(FontSize.SMALL)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .padding({ left: Space.MD, right: Space.MD, top: 6, bottom: 6 })
          .onClick((): void => this.skip())
      }
      .width('100%')
      .padding({ left: Space.PAGE, right: Space.PAGE, top: Space.LG })

      // 主体：单屏内容，按索引切换
      Column({ space: Space.XL }) {
        // 图标：液态玻璃圆盘 + 本屏强调色圆环 + emoji
        // （旧版为不透明白底圆；玻璃盘透出并虚化背景，与整体玻璃语言一致）
        CfGlassDisc({ diameter: 150, ringColor: this.current().accent }) {
          CfIcon({ kind: 'ui', code: this.current().icon, iconSize: 64 })
        }

        Column({ space: Space.MD }) {
          Text(this.current().title)
            .fontSize(FontSize.DISPLAY)
            .maxFontScale(FontSize.SCALE_NUM)
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .textAlign(TextAlign.Center)
            .width('100%')

          Text(this.current().desc)
            .fontSize(FontSize.BODY)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .lineHeight(23)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ left: Space.XL, right: Space.XL })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部：页码点 + 按钮
      Column({ space: Space.XL }) {
        // 页码指示点
        Row({ space: Space.SM }) {
          ForEach(PAGES, (p: GuidePage, i: number) => {
            Row()
              .width(i === this.index ? 22 : 8)
              .height(8)
              .backgroundColor(i === this.index ? this.current().accent : this.tc(Neutral.BORDER))
              .borderRadius(Radius.PILL)
          }, (p: GuidePage, i: number): string => 'dot' + i)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        // 主按钮：下一步 / 开始体验
        Text(this.isLast() ? '开始体验' : '下一步')
          .fontSize(FontSize.BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .width('100%')
          .textAlign(TextAlign.Center)
          .height(48)
          .linearGradient({
            angle: 90,
            colors: [[this.current().tint, 0], [this.current().accent, 1]]
          })
          .borderRadius(Radius.PILL)
          .shadow(this.tw(Shadow.brand()))
          .onClick((): void => this.next())

        // 底部说明条：玻璃底（旧版为本屏 tint 实色条，换成统一玻璃材质）
        Text(this.isLast() ? '低碳不是一次冲刺，而是每天一点点' : '随时可在「设置」里重新查看引导')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(Space.SM)
          .linearGradient(GlassLight.panelSurface(''))
          .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT))
          .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
          .borderRadius(Radius.SM)

        Text('第 ' + (this.index + 1) + ' / ' + PAGES.length + ' 屏')
          .fontSize(FontSize.CAPTION)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
      }
      .width('100%')
      .padding({ left: Space.PAGE, right: Space.PAGE, bottom: Space.XL })
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
}
