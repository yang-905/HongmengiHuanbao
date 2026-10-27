/**
 * 碳情绪调试面板（开发者工具，正常用户不可见）
 */
import { EcoMood, EcoTheme, Neutral } from '../../ui/Theme'
import { GlassLight } from '../../ui/GlassLight'
import { EcoMoodState } from '../../data/EcoMoodState'
import { CfCloseIcon } from '../../ui/Components'
import { toast } from '../../ui/Toast'
import { AppleMotion } from '../../ui/AppleMotion';
import { CfIcon } from '../../ui/Icon';

/** 可选档位定义 */
interface LevelOption {
  key: string;
  name: string;
  desc: string;
}

@Component
export struct EcoDebugSheet {
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

  /** 当前生效的强制档位（'' = 跟随真实判档） */
  @StorageLink('ecoOverride') ecoOverride: string = ''

  /** 当前实际生效的档位 */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  /* 正向碳情绪 v2 档位：灰(静默) → 暖黄(升温) → 黄绿(渐入佳境) → 荧光绿(生机满格)。
   * alert 已退场（level() 不再返回该档），不再提供强制项。 */
  private options: LevelOption[] = [
    { key: '', name: '自动', desc: '按真实减排量判档' },
    { key: 'eco', name: '荧光绿 · 生机满格', desc: '达成日目标 · 全屏通透发光' },
    { key: 'good', name: '黄绿 · 渐入佳境', desc: '接近日目标 · 高光增亮' },
    { key: 'warn', name: '暖黄 · 升温', desc: '已有减排动作 · 氛围转暖' },
    { key: 'none', name: '灰 · 静默', desc: '今日尚无减排 · 中性安静' }
  ]

  build() {
    Column() {
      // 顶部标题
      Row() {
        Column({ space: 3 }) {
          Text('碳情绪调试')
            .fontSize(19).opacity(this.themeTick >= 0 ? 1 : 0)
            .maxFontScale(1.15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
          Text('强制切换档位 · 验证全应用配色适配')
            .fontSize(11)
            .maxFontScale(1)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
        CfCloseIcon({
          btnSize: 32,
          glass: true,
          onTap: (): void => this.onClose()
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
this.RerenderCard()

          // 档位列表
          ForEach(this.options, (o: LevelOption) => {
            this.OptionRow(o)
          }, (o: LevelOption): string => 'ecoopt_' + o.key)

          // 色板预览：直观确认四档主色 / 底色 / 强调色
          this.PaletteCard()

          // 当前状态
          this.StatusCard()

          Text('提示：切到「自动」即恢复按真实减排量判档。' +
            '预览时可逐页浏览，检查文字对比度与组件配色是否跟随。')
            .fontSize(11)
            .maxFontScale(1)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .lineHeight(17)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 24 })
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
    /*
     * 液态玻璃面板底：半透明 + 实时高斯模糊。
     * 原来只有一层 rgba(255,255,255,0.42) 白底、**没有任何模糊**——
     * 底下的设置页内容直接透出（不虚化），文字叠文字糊成一片。
     * 补 backdropBlur 后底层内容真实虚化，面板才「浮」起来。
     * 模糊半径取 EcoMood.blurOf（与全应用页面根一致），
     * 比 BadgeDetailSheet 的 +4 弱一档：这是调试面板，不需抢戏。
     */
    .linearGradient(GlassLight.panelSurface(this.tc(EcoTheme.bg(this.ecoLevel))))
    .backdropBlur(EcoMood.blurOf(this.ecoLevel))
    // 顶缘一道高光，模拟玻璃上沿受光面（sheet 的标志性细节）
    .border({ width: { top: 1 }, color: this.tc(EcoMood.edgeOf(this.ecoLevel)) })
    // 底色/高光跟随碳档位平滑过渡，与页面根同一口径
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    /*
     * 入场过场：面板插入时，内容从下方 40vp 淡入到原位。
     * 声明式 transition，不依赖生命周期回调，Previewer 与真机一致。
     */
    .transition({ translate: { y: 40 }, opacity: 0 })
  }

  /**

   * 「重新渲染」卡片
 */
  @Builder
  RerenderCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('重新渲染全应用')
            .fontSize(16)
            .maxFontScale(1.15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tc(Neutral.TEXT))
            .maxLines(1)
          Text('预览器里记录后用它把新数据刷进各页面')
            .fontSize(11)
            .maxFontScale(1)
            .fontColor(this.tc(Neutral.TEXT_SUB))
            .maxLines(2)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
        Blank().width(10)
        Text('刷新')
          .fontSize(14)
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
          .borderRadius(999)
          .flexShrink(0)
      }
      .width('100%')
      .onClick((): void => this.rerender())
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .linearGradient(GlassLight.panelSurface(this.tc(EcoTheme.bg(this.ecoLevel))))
    .borderRadius(14)
    .border({ width: 1, color: this.tc(EcoTheme.primaryLight(this.ecoLevel)) })
  }

  /** 触发全应用重渲染 */
  private rerender(): void {
    EcoMoodState.broadcastDataChange()
    toast('已广播刷新信号，各页面将重新拉取数据')
  }

  /** 单个档位行 */
  @Builder
  OptionRow(o: LevelOption) {
    Row() {
      // 色块：直观展示该档主色
      Row()
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor(o.key.length > 0 ? this.tc(EcoTheme.primary(o.key)) : 'rgba(0,0,0,0)')
        .border({
          width: o.key.length > 0 ? 0 : 1,
          color: this.tc(Neutral.TEXT_MUTED)
        })
        .flexShrink(0)
      Column({ space: 2 }) {
        Text(o.name)
          .fontSize(14)
          .maxFontScale(1)
          .fontWeight(this.ecoOverride === o.key ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
          .width('100%')
        Text(o.desc)
          .fontSize(11)
          .maxFontScale(1)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      Blank().width(8)
      // 选中态
      if (this.ecoOverride === o.key) {
        Text('当前')
          .fontSize(11)
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
          .borderRadius(999)
          .flexShrink(0)
      }
    }
    .width('100%')
    .padding(12)
    .linearGradient(GlassLight.panelSurface(this.tc(EcoTheme.bg(this.ecoLevel))))
    .borderRadius(14)
    .border({ width: 1, color: this.ecoOverride === o.key
      ? this.tc(EcoTheme.primary(this.ecoLevel))
      : this.tc(Neutral.BORDER) })
    .onClick((): void => this.pick(o))
  }

  /** 色板预览卡 */
  @Builder
  PaletteCard() {
    Column({ space: 10 }) {
      Text('色板对照')
        .fontSize(16)
        .maxFontScale(1.15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .width('100%')
        .maxLines(1)
      Row({ space: 8 }) {
        this.Swatch('eco')
        this.Swatch('good')
        this.Swatch('warn')
        this.Swatch('none')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .linearGradient(GlassLight.panelSurface(this.tc(EcoTheme.bg(this.ecoLevel))))
    .borderRadius(14)
    .border({ width: 1, color: this.tc(Neutral.BORDER) })
  }

  /** 单个色块：上为主色、下为底色 */
  @Builder
  Swatch(key: string) {
    Column({ space: 4 }) {
      Row()
        .width('100%')
        .height(32)
        .backgroundColor(this.tc(EcoTheme.primary(key)))
        .borderRadius(8)
      Row()
        .width('100%')
        .height(32)
        .backgroundColor(this.tc(EcoTheme.bg(key)))
        .borderRadius(8)
        .border({ width: 1, color: this.tc(Neutral.BORDER) })
      CfIcon({ kind: 'ui', code: EcoTheme.icon(key), iconSize: 22 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  /** 当前状态卡：显示强制档与真实判档 */
  @Builder
  StatusCard() {
    Column({ space: 8 }) {
      Row() {
        Text('模式')
          .fontSize(12)
          .maxFontScale(1)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
        Blank()
        Text(this.ecoOverride.length > 0 ? ('强制：' + this.labelOf(this.ecoOverride)) : '自动')
          .fontSize(12)
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(EcoTheme.accent(this.ecoLevel)))
          .maxLines(1)
      }
      .width('100%')
      Row() {
        Text('生效档位')
          .fontSize(12)
          .maxFontScale(1)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
        Blank()
        Text(this.labelOf(this.ecoLevel))
          .fontSize(12)
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
      }
      .width('100%')
      Row() {
        Text('今日减排量')
          .fontSize(12)
          .maxFontScale(1)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
        Blank()
        Text(EcoMoodState.todayKg().toFixed(2) + ' kg / 目标 ' + EcoMoodState.QUOTA + ' kg')
          .fontSize(12)
          .maxFontScale(1)
          .fontColor(this.tc(Neutral.TEXT))
          .maxLines(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .linearGradient(GlassLight.panelSurface(this.tc(EcoTheme.bg(this.ecoLevel))))
    .borderRadius(14)
    .border({ width: 1, color: this.tc(Neutral.BORDER) })
  }
/** 档位中文名 */
  private labelOf(key: string): string {
    for (let i = 0; i < this.options.length; i++) {
      if (this.options[i].key === key) return this.options[i].name
    }
    return key
  }

  /** 切换强制档位 */
  private pick(o: LevelOption): void {
    EcoMoodState.override(o.key)
    // ⚠️ override 只写了 AppStorage['ecoOverride']，apply() 不重跑的话
    //   KEY_LEVEL（ecoLevel）不会更新 —— 27 个订阅页全部不变色，
    //   直到某页因 onPageShow/load 触发 refresh（用户实测「要手动切换
    //   本页刷新」）。这里必须立即 refresh：按 override 重算档位并广播，
    //   所有页面的 @StorageProp('ecoLevel') 当帧生效。
    EcoMoodState.refresh()
    if (o.key.length > 0) {
      toast('已强制切换为「' + o.name + '」，可返回逐页查看')
    } else {
      toast('已恢复自动判档')
    }
  }
}