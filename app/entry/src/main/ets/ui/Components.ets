/** 通用 UI 组件库：液态玻璃卡、药丸、徽章、按钮、列表行等 */
import { Accent, Brand, EcoTheme, FontSize, Glass, Neutral, Radius, Shadow, Space } from './Theme';
import { GlassLight, GlassTier } from './GlassLight';
import { AppleMotion } from './AppleMotion';
import { CfIcon } from './Icon';

export class GlassLevel {
  static readonly SOLID: boolean = false;
  static readonly LIVE: boolean = true;
}

@Component
export struct CfCard {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  pad: number = Space.LG;
  bgColor: string = '';
  private bgValue(): string {
    return this.bgColor.length > 0 ? this.bgColor : this.tc(Glass.CARD_BG);
  }
  corner: number = Radius.MD;
  ambient: string = '';
  glass: boolean = GlassLevel.SOLID;
  onTap?: () => void;
  @State private pressed: boolean = false
  @BuilderParam contentSlot: () => void = this.emptySlot;

  @Builder
  emptySlot() {}

  private surfaceValue(): LinearGradient {
    return this.tw(GlassLight.surface(this.tc(this.bgValue()), GlassTier.CARD, this.ambient, 1));
  }

  private glassSurfaceValue(): LinearGradient {
    return this.tw(GlassLight.surface(this.tc(Glass.PANEL_LIVE_BG), GlassTier.CARD, this.ambient, 1));
  }

  build() {
    if (this.glass) {
      Column() {
        this.contentSlot()
      }
      .width('100%')
      .padding(this.pad)
      .linearGradient(this.glassSurfaceValue())
      .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .borderRadius(this.corner)
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 1 },
        color: this.tw(GlassLight.borderColors(GlassTier.CARD, this.ambient, 1))
      })
      .shadow(this.tw(GlassLight.shadowOf(GlassTier.CARD)))
      .clip(true)
    } else {
      Column() {
        this.contentSlot()
      }
      .width('100%')
      .padding(this.pad)
      .linearGradient(this.surfaceValue())
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .borderRadius(this.corner)
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 1 },
        color: this.tw(GlassLight.borderColors(GlassTier.CARD, this.ambient, 1))
      })
      .shadow(this.tw(GlassLight.shadowOf(GlassTier.CARD)))
      .clip(true)
      .scale({
        x: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1,
        y: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1
      })
      .animation(this.pressed
        ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
        : { duration: 0 })
      .onTouch((e: TouchEvent): void => {
        if (this.onTap === undefined) return;
        if (e.type === TouchType.Down) {
          this.pressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
        if (isExpanding && this.pressed) {
          this.pressed = false;
        }
      })
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    }
  }
}

@Component
export struct CfPill {
  @Prop text: string = '';
  @Prop tone: string = 'muted';

  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private bg(): string {
    if (this.tone === 'success') return this.tc(Accent.SUCCESS_BG);
    if (this.tone === 'warning') return this.tc(Accent.WARNING_BG);
    if (this.tone === 'danger') return this.tc(Accent.DANGER_BG);
    if (this.tone === 'info') return this.tc(Accent.INFO_BG);
    return this.tc(Neutral.SURFACE);
  }

  private fg(): string {
    if (this.tone === 'success') return this.tc(Accent.SUCCESS);
    if (this.tone === 'warning') return this.tc(Accent.WARNING);
    if (this.tone === 'danger') return this.tc(Accent.DANGER);
    if (this.tone === 'info') return this.tc(Accent.INFO);
    return this.tc(Neutral.TEXT_SUB);
  }

  build() {
    Row({ space: 5 }) {
      Circle({ width: 5, height: 5 }).fill(this.tc(this.fg()))
      Text(this.text)
        .fontSize(FontSize.SMALL)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(this.fg()))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 9, right: 9, top: 3, bottom: 3 })
    .backgroundColor(this.tc(this.bg()))
    .borderRadius(Radius.PILL)
    .clip(true)
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfCatBadge {
  text: string = '';
  bg: string = '';
  fg: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private bgValue(): string {
    return this.bg.length > 0 ? this.bg : this.tc(Brand.PRIMARY_PALE);
  }

  private fgValue(): string {
    return this.fg.length > 0 ? this.fg : this.tc(Brand.PRIMARY_DEEP);
  }

  build() {
    Text(this.text)
      .fontSize(FontSize.SMALL)
      .maxFontScale(FontSize.SCALE_TEXT)
      .fontColor(this.tc(this.fgValue()))
      .fontWeight(FontWeight.Medium)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 9, right: 9, top: 3, bottom: 3 })
      .backgroundColor(this.tc(this.bgValue()))
      .borderRadius(Radius.SM)
      .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfSection {
  @Prop title: string = '';
  @Prop more: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  onMoreTap?: () => void;
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  build() {
    Row() {
      Row()
        .width(3)
        .height(14)
        .backgroundColor(this.tc(EcoTheme.primary(this.ecoLevel)))
        .borderRadius(2)
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
      Text(this.title)
        .fontSize(FontSize.TITLE)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .margin({ left: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (this.more.length > 0) {
        Text(this.more)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
          .maxLines(1)
          .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
          .onClick((): void => {
            if (this.onMoreTap !== undefined) this.onMoreTap!();
          })
      }
    }
    .width('100%')
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

const EMPTY_ART: Record<string, string> = {
  'sprout': '🌱',
  'badge': '🏅',
  'book': '📚',
  'bulb': '💡',
  'calendar': '📅',
  'coin': '💎',
  'device': '📱',
  'folder': '📁',
  'home': '🏡',
  'inbox': '📭',
  'lock': '🔒',
  'mall': '🛍️',
  'note': '📄',
  'pie': '🥧',
  'receipt': '🧾',
  'star': '⭐',
  'target': '🎯',
  'ticket': '🎟️',
  'up': '📈'
}

@Component
export struct CfEmpty {
  @Prop icon: string = 'sprout';
  @Prop text: string = '暂无数据';
  @Prop sub: string = '';
  @Prop line: boolean = false;
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private art(): string {
    const v: string | undefined = EMPTY_ART[this.icon]
    return v !== undefined ? v : ''
  }

  build() {
    Column({ space: 8 }) {
      if (!this.line && this.art().length > 0) {
        Text(this.art())
          .fontSize(40)
          .maxFontScale(FontSize.SCALE_NUM)
      } else {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 40,
          color: this.tc(Neutral.TEXT_MUTED)
        })
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.tc(Neutral.TEXT_SUB))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_MUTED))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ top: 40, bottom: 40 })
    .alignItems(HorizontalAlign.Center)
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfStatTile {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @Prop label: string = '';
  @Prop value: string = '';
  @Prop icon: string = '';
  @Prop accent: string = '';
  @Prop tint: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private accentValue(): string {
    return this.accent.length > 0 ? this.accent : this.tc(Brand.PRIMARY);
  }

  private tintValue(): string {
    return this.tint.length > 0 ? this.tint : this.tc(Brand.PRIMARY_PALE);
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 14,
          color: this.tc(this.accentValue())
        })
        Text(this.label)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT_SUB))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(this.value)
        .fontSize(FontSize.HEADING)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(this.accentValue()))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.MD)
    .backgroundColor(this.tc(this.tintValue()))
    .borderRadius(Radius.MD)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.CARD, '', 1)) })
    .clip(true)
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfProgress {
  @Prop percent: number = 0;
  color: string = '';
  barHeight: number = 7;
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  track: string = '';
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  private trackValue(): string {
    return this.track.length > 0 ? this.track : this.tc(Neutral.SURFACE);
  }

  private barColor(): string {
    return this.color.length > 0 ? this.color : this.tc(EcoTheme.primary(this.ecoLevel))
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(this.barHeight)
        .backgroundColor(this.tc(this.trackValue()))
        .borderRadius(Radius.PILL)
      Row()
        .width(Math.max(2, Math.min(100, this.percent)) + '%')
        .height(this.barHeight)
        .backgroundColor(this.tc(this.barColor()))
        .borderRadius(Radius.PILL)
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    }
    .width('100%')
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfCloseIcon {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  onTap?: () => void;
  color: string = '';
  bg: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  private colorValue(): string {
    return this.color.length > 0 ? this.color : this.tc(Neutral.TEXT_SUB);
  }

  private bgValue(): string {
    return this.bg.length > 0 ? this.bg : this.tc(Neutral.SURFACE);
  }
  btnSize: number = 32;
  showBg: boolean = true;
  glass: boolean = false;

  @Builder
  Arms() {
    Stack() {
      Line()
        .width(this.btnSize)
        .height(this.btnSize)
        .startPoint([this.btnSize * 0.30, this.btnSize * 0.30])
        .endPoint([this.btnSize * 0.70, this.btnSize * 0.70])
        .strokeWidth(2)
        .stroke(this.tc(this.colorValue()))
        .strokeOpacity(1)
        .antiAlias(true)
      Line()
        .width(this.btnSize)
        .height(this.btnSize)
        .startPoint([this.btnSize * 0.70, this.btnSize * 0.30])
        .endPoint([this.btnSize * 0.30, this.btnSize * 0.70])
        .strokeWidth(2)
        .stroke(this.tc(this.colorValue()))
        .strokeOpacity(1)
        .antiAlias(true)
    }
    .width(this.btnSize)
    .height(this.btnSize)
  }

  build() {
    if (this.glass && this.showBg) {
      Stack() {
        this.Arms()
      }
      .width(this.btnSize)
      .height(this.btnSize)
      .alignContent(Alignment.Center)
      .borderRadius(this.btnSize / 2)
      .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.DISC_BG), GlassTier.PILL, '', 1)))
      .backdropBlur(GlassLight.blurScaled(Glass.DISC_BLUR))
      .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    } else {
      Stack() {
        this.Arms()
      }
      .width(this.btnSize)
      .height(this.btnSize)
      .alignContent(Alignment.Center)
      .borderRadius(this.btnSize / 2)
      .backgroundColor(this.showBg ? this.tc(this.bgValue()) : 'rgba(0,0,0,0)')
      .opacity(this.themeTick >= 0 ? 1 : 0)
      .onClick((): void => {
        if (this.onTap !== undefined) this.onTap!();
      })
    }
  }
}

@Component
export struct CfBackIcon {
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  iconSize: number = 30;
  color: string = '';
  onTap?: () => void;
  pointRight: boolean = false;

  private strokeColor(): string {
    return this.color.length > 0 ? this.color : this.tc(Neutral.TEXT);
  }

  build() {
    Stack() {
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint(this.pointRight
          ? [this.iconSize * 0.40, this.iconSize * 0.24]
          : [this.iconSize * 0.60, this.iconSize * 0.24])
        .endPoint(this.pointRight
          ? [this.iconSize * 0.62, this.iconSize * 0.50]
          : [this.iconSize * 0.38, this.iconSize * 0.50])
        .strokeWidth(2.2)
        .stroke(this.tc(this.strokeColor()))
        .strokeOpacity(1)
        .antiAlias(true)
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint(this.pointRight
          ? [this.iconSize * 0.62, this.iconSize * 0.50]
          : [this.iconSize * 0.38, this.iconSize * 0.50])
        .endPoint(this.pointRight
          ? [this.iconSize * 0.40, this.iconSize * 0.76]
          : [this.iconSize * 0.60, this.iconSize * 0.76])
        .strokeWidth(2.2)
        .stroke(this.tc(this.strokeColor()))
        .strokeOpacity(1)
        .antiAlias(true)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}

@Component
export struct CfTopBar {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  title: string = '';
  showBack: boolean = true;
  onBack?: () => void;
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  build() {
    Row() {
      if (this.showBack) {
        CfBackIcon({
          iconSize: 30,
          color: this.tc(Neutral.TEXT),
          onTap: (): void => {
            if (this.onBack !== undefined) this.onBack!();
          }
        })
      } else {
        Blank().width(4)
      }
      Text(this.title)
        .fontSize(FontSize.HEADING)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tc(Neutral.TEXT))
        .margin({ left: 4 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: Space.PAGE, right: Space.PAGE })
    .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.TOPBAR_BG), GlassTier.PILL, '', 1)))
    .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT))
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
  }
}

@Component
export struct CfButton {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  text: string = '';
  icon: string = '';
  primary: boolean = true;
  block: boolean = false;
  flex: boolean = false;
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  onTap?: () => void;
  @State private pressed: boolean = false
  @StorageProp('ecoLevel') ecoLevel: string = 'none'

  private themeShadow(): ShadowOptions {
    return {
      radius: 18,
      color: this.tc(EcoTheme.shadowColor(this.ecoLevel)),
      offsetX: 0,
      offsetY: 6
    }
  }

  @Builder
  ButtonBody(full: boolean) {
    Row({ space: 6 }) {
      if (this.icon.length > 0) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 16,
          color: this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel))
        })
          .flexShrink(0)
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minWidth: 0 })
    }
    .justifyContent(FlexAlign.Center)
    .height(44)
    .backgroundColor(this.primary ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Glass.CARD_BG))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(Radius.PILL)
    .shadow(this.primary ? this.themeShadow() : Shadow.none())
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .clip(true)
    .scale({ x: this.pressed ? AppleMotion.PRESS_SCALE : 1, y: this.pressed ? AppleMotion.PRESS_SCALE : 1 })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
    .width(full ? '100%' : 'auto')
    .padding({ left: full ? 0 : 22, right: full ? 0 : 22 })
    .constraintSize({ minWidth: full ? 0 : 96 })
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }

  build() {
    if (this.flex) {
      CfButtonFlexBody({
        text: this.text,
        icon: this.icon,
        primary: this.primary,
        onTap: this.onTap
      })
    } else {
      this.ButtonBody(this.block)
    }
  }
}

@Component
struct CfButtonFlexBody {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  text: string = '';
  icon: string = '';
  primary: boolean = true;
  onTap?: () => void;
  @State private pressed: boolean = false

  @StorageProp('ecoLevel') ecoLevel: string = 'none'
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  build() {
    Row({ space: 6 }) {
      if (this.icon.length > 0) {
        CfIcon({
          kind: 'ui',
          code: this.icon,
          iconSize: 16,
          color: this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel))
        })
          .flexShrink(0)
      }
      Text(this.text)
        .fontSize(FontSize.BODY)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primary ? '#FFFFFF' : this.tc(EcoTheme.primaryDeep(this.ecoLevel)))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minWidth: 0 })
    }
    .justifyContent(FlexAlign.Center)
    .height(44)
    .backgroundColor(this.primary ? this.tc(EcoTheme.primary(this.ecoLevel)) : this.tc(Glass.CARD_BG))
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(Radius.PILL)
    .shadow(this.primary ? {
      radius: 18,
      color: this.tc(EcoTheme.shadowColor(this.ecoLevel)),
      offsetX: 0,
      offsetY: 6
    } : Shadow.none())
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .clip(true)
    .scale({ x: this.pressed ? AppleMotion.PRESS_SCALE : 1, y: this.pressed ? AppleMotion.PRESS_SCALE : 1 })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .layoutWeight(1)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}

@Component
export struct CfListRow {
  @Prop icon: string = '';
  @Prop tone: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @Prop right: string = '';
  @Prop rightColor: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  @Prop showArrow: boolean = true;
  onTap?: () => void;
  @State private pressed: boolean = false

  private rightColorValue(): string {
    return this.rightColor.length > 0 ? this.rightColor : this.tc(Neutral.TEXT_SUB);
  }

  build() {
    Row({ space: Space.MD }) {
      if (this.icon.length > 0) {
        Stack() {
          CfIcon({ kind: 'ui', code: this.icon, iconSize: 20, tone: this.tone })
        }
        .width(38)
        .height(38)
        .backgroundColor(this.tc(Brand.PRIMARY_PALE))
        .borderRadius(Radius.SM)
      }
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.right.length > 0) {
        Text(this.right)
          .fontSize(FontSize.SMALL)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(this.rightColorValue()))
          .maxLines(1)
      }
      if (this.showArrow) {
        CfBackIcon({
          iconSize: 18,
          color: this.tc(Neutral.TEXT_MUTED),
          pointRight: true
        })
      }
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
    .scale({
      x: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1,
      y: this.onTap !== undefined && this.pressed ? AppleMotion.PRESS_SCALE : 1
    })
    .animation(this.pressed
      ? { duration: AppleMotion.PRESS_MS, curve: AppleMotion.EASE }
      : { duration: 0 })
    .onTouch((e: TouchEvent): void => {
      if (this.onTap === undefined) return;
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onVisibleAreaChange([0, 1], (isExpanding: boolean, ratio: number): void => {
      if (isExpanding && this.pressed) {
        this.pressed = false;
      }
    })
  }
}

@Component
export struct CfSwitchRow {
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop sub: string = '';
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  @Prop on: boolean = false;
  onChange?: (isOn: boolean) => void;

  build() {
    Row({ space: Space.MD }) {
      Stack() {
        CfIcon({ kind: 'ui', code: this.icon, iconSize: 20 })
      }
      .width(38)
      .height(38)
      .backgroundColor(this.tc(Brand.PRIMARY_PALE))
      .borderRadius(Radius.SM)
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(FontSize.BODY)
          .maxFontScale(FontSize.SCALE_TEXT)
          .fontColor(this.tc(Neutral.TEXT))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.sub.length > 0) {
          Text(this.sub)
            .fontSize(FontSize.SMALL)
            .maxFontScale(FontSize.SCALE_TEXT)
            .fontColor(this.tc(Neutral.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.on })
        .selectedColor(this.tc(Brand.PRIMARY))
        .onChange((isOn: boolean): void => {
          if (this.onChange !== undefined) this.onChange!(isOn);
        })
    }
    .width('100%')
    .padding({ top: Space.MD, bottom: Space.MD })
    .opacity(this.themeTick >= 0 ? 1 : 0)
  }
}

@Component
export struct CfGlassDisc {
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }

  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  diameter: number = 56;
  @BuilderParam contentSlot: () => void = this.emptySlot;
  ringColor: string = '';
  onTap?: () => void;

  @Builder
  emptySlot() {}

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.contentSlot()
      if (this.ringColor.length > 0) {
        Circle()
          .width(this.diameter - 8)
          .height(this.diameter - 8)
          .fill(Color.Transparent)
          .stroke(this.ringColor)
          .strokeWidth(2)
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .linearGradient(this.tw(GlassLight.surface(this.tc(Glass.DISC_BG), GlassTier.PILL, '', 1)))
    .backdropBlur(GlassLight.blurScaled(Glass.DISC_BLUR))
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, '', 1)) })
    .borderRadius(this.diameter / 2)
    .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
    .clip(true)
    .onClick((): void => {
      if (this.onTap !== undefined) this.onTap!();
    })
  }
}
