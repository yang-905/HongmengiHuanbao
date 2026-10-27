import { Brand, FontSize, Glass, Neutral, Radius, Shadow, Space } from '../ui/Theme';
import { GlassLight, GlassTier } from '../ui/GlassLight';
import { CfIcon } from '../ui/Icon';

/**

 * P01 启动页（由 Index 条件渲染为全屏覆盖层，不占路由）
 */
@Component
export struct SplashPage {
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
  /** 跳过回调（由 Index 关闭启动页） */
  onSkip: () => void = (): void => {}

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 渐变底（深色模式换深墨绿渐变，保证深色套文字可读）
      Column()
        .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [[this.tc(Brand.SPLASH_FROM), 0], [this.tc(Brand.SPLASH_TO), 1]]
        })

      Column({ space: Space.XL }) {
        // 品牌徽标：实底圆盘 + 品牌绿圆环 + 叶片
        // （弃用 CfGlassDisc：其 backdropBlur 在预览器下整盘发黑，见文件头说明）
        Stack({ alignContent: Alignment.Center }) {
          CfIcon({ kind: 'ui', code: 'sprout', iconSize: 46 })
          // 强调色圆环：内缩 4vp 的细环，与圆盘边缘形成「双环」层次
          //
          // ⚠️ Circle() 必须显式 fill(Color.Transparent)：
          // ArkUI 的形状组件（Circle/Shape）**默认填充纯黑**，
          // 只写 .border() 不会把它变成「描边圆环」——
          // 黑色实心圆会直接盖住下面的 emoji，
          // 表现为启动页 logo 是一个纯黑大圆（品牌环与叶片全被吞）。
          // 这是「形状组件默认填充黑」的坑，不是尺寸或层级问题。
          Circle()
            .width(100)
            .height(100)
            .fill(Color.Transparent)
            .stroke(this.tc(Brand.PRIMARY))
            .strokeWidth(2)
        }
        .width(108)
        .height(108)
        .backgroundColor(this.tc(Glass.DISC_SOLID_BG))
        .borderRadius(54)
        .shadow(this.tw(Shadow.raised()))

        Column({ space: Space.SM }) {
          Text('一触青绿')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Brand.PRIMARY_DEEP))
          Text('一触之间，青绿相随')
            .fontSize(FontSize.BODY)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text('记录每一次绿色选择，攒出一片森林')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        .alignItems(HorizontalAlign.Center)

        // 加载指示
        Column({ space: Space.MD }) {
          LoadingProgress()
            .width(26)
            .height(26)
            .color(this.tc(Brand.PRIMARY))
        }
        .margin({ top: Space.XL })
      }

      /*
       * 底部版本信息：玻璃小条，锚定屏幕底部（红圈标注位置）。
       * 原为 Stack 居中子元素 + margin 下移，实际停在屏幕中段、
       * 夹在徽标与标题之间很突兀；版本信息按惯例沉到屏幕底部。
       */
      Column() {
        Column({ space: 3 }) {
          Text('碳足迹 · 碳积分 · 减排指南')
            .fontSize(FontSize.CAPTION)
            .fontColor(this.tc(Neutral.TEXT_SUB))
          Text('v1.0.0')
            .fontSize(10)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
        }
        .alignItems(HorizontalAlign.Center)
        .padding({ left: Space.LG, right: Space.LG, top: Space.SM, bottom: Space.SM })
        .linearGradient(GlassLight.panelSurface(''))
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT))
        .borderRadius(Radius.LG)
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PANEL, '', 1)) })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 48 })
    }
    .width('100%')
    .height('100%')
    /*
     * 不设 opacity：启动页必须**任何环境下都完全不透明**。
     * 曾在这里用 `@State alpha = 0` + aboutToAppear 改成 1 做淡入，
     * 结果 Previewer 里 aboutToAppear 不触发，alpha 永远停在 0，
     * 整个启动页全透明 → 表现为「开屏页不见了」（调成 2 秒也没用，因为根本不是时长问题）。
     * 淡入淡出交给宿主页：移除本组件时由 Index 的 animateTo 交叉过渡。
     */
    // 兜底：万一定时器没触发，点击任意处也能进入主界面，
    // 避免启动页全屏盖住导致「整个界面点不动」
    .onClick((): void => {
      this.onSkip()
    })
  }
}
