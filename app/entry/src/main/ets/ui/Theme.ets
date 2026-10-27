/** 设计令牌库：所有页面从此取色与取圆角，禁止在页面里硬编码色值 */

/**
 * 主题明暗控制中心。
 * 色值类全部是可变 static 字段，applyDark 在启动和设置页切换时整组换血。
 */
export class ThemePalette {
  /** 当前是否深色模式 */
  static dark: boolean = false;

  /** 切换明暗：整组换血所有可变色值令牌 */
  static applyDark(dark: boolean): void {
    ThemePalette.dark = dark;
    if (dark) {
      ThemePalette.applyDarkValues();
    } else {
      ThemePalette.applyLightValues();
    }
  }

  private static applyDarkValues(): void {
    Brand.PRIMARY = '#4ECBA9';
    Brand.PRIMARY_DEEP = '#63D3B6';
    Brand.PRIMARY_LIGHT = '#7FD9C4';
    Brand.PRIMARY_PALE = 'rgba(63,191,159,0.16)';
    Brand.PRIMARY_MIST = 'rgba(63,191,159,0.18)';
    Brand.SPLASH_FROM = '#0E1312';
    Brand.SPLASH_TO = '#1C2523';

    Neutral.BG = '#141A18';
    Neutral.CARD = '#1E2523';
    Neutral.SURFACE = '#252D2A';
    Neutral.TEXT = '#FFFFFF';
    Neutral.TEXT_SUB = '#C7D7D2';
    Neutral.TEXT_MUTED = '#AEBEB8';
    Neutral.BORDER = '#3A4340';
    Neutral.INK = '#0B1211';

    Accent.TRAVEL = '#5CC2CE';
    Accent.TRAVEL_BG = 'rgba(79,184,196,0.18)';
    Accent.ENERGY = '#E8B268';
    Accent.ENERGY_BG = 'rgba(224,164,88,0.18)';
    Accent.RECYCLE = '#7FCB95';
    Accent.RECYCLE_BG = 'rgba(111,192,138,0.18)';
    Accent.FOOD = '#F0998C';
    Accent.FOOD_BG = 'rgba(232,139,126,0.18)';
    Accent.SUCCESS = '#5CBD8B';
    Accent.SUCCESS_BG = 'rgba(76,175,125,0.18)';
    Accent.WARNING = '#E8B268';
    Accent.WARNING_BG = 'rgba(224,164,88,0.18)';
    Accent.DANGER = '#EC8B83';
    Accent.DANGER_BG = 'rgba(224,115,107,0.18)';
    Accent.INFO = '#74AEE0';
    Accent.INFO_BG = 'rgba(91,155,213,0.18)';

    EcoMood.ECO_BG = 'rgba(20,44,28,0.62)';
    EcoMood.ECO_ACCENT = '#4ADE80';
    EcoMood.ECO_SOLID = '#142C1C';
    EcoMood.GOOD_BG = 'rgba(36,44,24,0.62)';
    EcoMood.GOOD_ACCENT = '#B5D98A';
    EcoMood.GOOD_SOLID = '#242C18';
    EcoMood.WARN_BG = 'rgba(46,40,24,0.62)';
    EcoMood.WARN_ACCENT = '#EAC78D';
    EcoMood.WARN_SOLID = '#2E2818';
    EcoMood.ALERT_BG = 'rgba(47,30,28,0.62)';
    EcoMood.ALERT_ACCENT = '#F2A49D';
    EcoMood.ALERT_SOLID = '#2A1C1A';
    EcoMood.NONE_BG = 'rgba(20,26,24,0.62)';
    EcoMood.NONE_SOLID = '#141A18';
    EcoMood.NONE_ACCENT = Neutral.TEXT_SUB;

    Glass.CARD_BG = 'rgba(255,255,255,0.07)';
    Glass.BOTTOM_BAR_BG = 'rgba(255,255,255,0.05)';
    Glass.PILL_BG = 'rgba(255,255,255,0.11)';
    Glass.TOPBAR_BG = 'rgba(255,255,255,0.06)';
    Glass.PANEL_LIVE_BG = 'rgba(255,255,255,0.06)';
    Glass.SEGMENT_TRACK_BG = 'rgba(255,255,255,0.07)';
    Glass.DISC_BG = 'rgba(255,255,255,0.09)';
    Glass.DISC_SOLID_BG = '#22322E';
    Glass.EDGE = 'rgba(236,244,246,0.14)';
    Glass.HIGHLIGHT = 'rgba(236,244,246,0.18)';

    Shadow.cardColor = '#0F000000';
    Shadow.cardOffsetY = 0;
    Shadow.brandColor = 'rgba(63,191,159,0.22)';
    Shadow.raisedColor = '#2B000000';
    Shadow.raisedOffsetY = 8;
  }

  private static applyLightValues(): void {
    Brand.PRIMARY = '#3FBF9F';
    Brand.PRIMARY_DEEP = '#2A9E82';
    Brand.PRIMARY_LIGHT = '#7FD9C4';
    Brand.PRIMARY_PALE = '#E4F6F0';
    Brand.PRIMARY_MIST = 'rgba(63,191,159,0.14)';
    Brand.SPLASH_FROM = '#E4F6F0';
    Brand.SPLASH_TO = '#7FD9C4';

    Neutral.BG = '#FBF8F3';
    Neutral.CARD = '#FFFFFF';
    Neutral.SURFACE = '#F6F3EE';
    Neutral.TEXT = '#2E3A36';
    Neutral.TEXT_SUB = '#6B7A75';
    Neutral.TEXT_MUTED = '#A3AEA9';
    Neutral.BORDER = '#EDE8E1';
    Neutral.INK = '#24322E';

    Accent.TRAVEL = '#4FB8C4';
    Accent.TRAVEL_BG = '#E4F4F6';
    Accent.ENERGY = '#E0A458';
    Accent.ENERGY_BG = '#FBF0DF';
    Accent.RECYCLE = '#6FC08A';
    Accent.RECYCLE_BG = '#E6F5EB';
    Accent.FOOD = '#E88B7E';
    Accent.FOOD_BG = '#FCEAE7';
    Accent.SUCCESS = '#4CAF7D';
    Accent.SUCCESS_BG = '#E3F4EA';
    Accent.WARNING = '#E0A458';
    Accent.WARNING_BG = '#FBF0DF';
    Accent.DANGER = '#E0736B';
    Accent.DANGER_BG = '#FBE8E6';
    Accent.INFO = '#5B9BD5';
    Accent.INFO_BG = '#E6F0F9';

    EcoMood.ECO_BG = 'rgba(242,251,247,0.62)';
    EcoMood.ECO_ACCENT = '#2A9E82';
    EcoMood.ECO_SOLID = '#F2FBF7';
    EcoMood.GOOD_BG = 'rgba(244,250,243,0.62)';
    EcoMood.GOOD_ACCENT = '#3E9A78';
    EcoMood.GOOD_SOLID = '#F4FAF3';
    EcoMood.WARN_BG = 'rgba(253,248,239,0.62)';
    EcoMood.WARN_ACCENT = '#C4863A';
    EcoMood.WARN_SOLID = '#FDF8EF';
    EcoMood.ALERT_BG = 'rgba(253,243,241,0.62)';
    EcoMood.ALERT_ACCENT = '#C4554C';
    EcoMood.ALERT_SOLID = '#FDF3F1';
    EcoMood.NONE_BG = 'rgba(251,248,243,0.62)';
    EcoMood.NONE_SOLID = '#FBF8F3';
    EcoMood.NONE_ACCENT = Neutral.TEXT_SUB;

    Glass.CARD_BG = 'rgba(255,255,255,0.72)';
    Glass.BOTTOM_BAR_BG = 'rgba(255,255,255,0.12)';
    Glass.PILL_BG = 'rgba(255,255,255,0.42)';
    Glass.TOPBAR_BG = 'rgba(255,255,255,0.50)';
    Glass.PANEL_LIVE_BG = 'rgba(255,255,255,0.50)';
    Glass.SEGMENT_TRACK_BG = 'rgba(255,255,255,0.38)';
    Glass.DISC_BG = 'rgba(255,255,255,0.52)';
    Glass.DISC_SOLID_BG = '#FFFFFF';
    Glass.EDGE = 'rgba(255,255,255,0.52)';
    Glass.HIGHLIGHT = 'rgba(255,255,255,0.60)';

    Shadow.cardColor = '#03000003';
    Shadow.cardOffsetY = 0;
    Shadow.brandColor = '#3FBF9F47';
    Shadow.raisedColor = '#0C000014';
    Shadow.raisedOffsetY = 6;
  }
}

/** 明暗状态钩子 */
export function isDarkMode(): boolean {
  return ThemePalette.dark
}

/** 品牌主色（薄荷绿） */
export class Brand {
  static PRIMARY: string = '#3FBF9F';
  static PRIMARY_DEEP: string = '#2A9E82';
  static PRIMARY_LIGHT: string = '#7FD9C4';
  static PRIMARY_PALE: string = '#E4F6F0';
  static PRIMARY_MIST: string = 'rgba(63,191,159,0.14)';
  static SPLASH_FROM: string = '#E4F6F0';
  static SPLASH_TO: string = '#7FD9C4';
}

/** 输入控件令牌（TextInput / TextArea / Search） */
export class InputField {
  static BG: string = '#FFFFFF';
  static BORDER: string = '#C9D2CE';
  static PLACEHOLDER: string = '#6B7A75';
  static TEXT: string = '#2E3A36';
  static CURSOR: string = '#3FBF9F';
  static FOCUS_BORDER: string = '#3FBF9F';
  static AFFIX: string = '#6B7A75';

  static focusBorder(dark: boolean): string {
    return dark ? '#4ECBA9' : '#3FBF9F';
  }

  static bg(dark: boolean): string {
    return dark ? 'rgba(255,255,255,0.10)' : '#FFFFFF';
  }

  static border(dark: boolean): string {
    return dark ? 'rgba(236,244,246,0.28)' : '#C9D2CE';
  }

  static placeholder(dark: boolean): string {
    return dark ? '#9DB1AC' : '#6B7A75';
  }

  static text(dark: boolean): string {
    return dark ? '#E9F0ED' : '#2E3A36';
  }

  static cursor(dark: boolean): string {
    return dark ? '#63D3B6' : '#3FBF9F';
  }
}

/** 中性色 */
export class Neutral {
  static BG: string = '#FBF8F3';
  static CARD: string = '#FFFFFF';
  static SURFACE: string = '#F6F3EE';
  static TEXT: string = '#2E3A36';
  static TEXT_SUB: string = '#6B7A75';
  static TEXT_MUTED: string = '#A3AEA9';
  static BORDER: string = '#EDE8E1';
  static INK: string = '#24322E';
}

/** 语义色：四大类低碳行为 + 状态 */
export class Accent {
  static TRAVEL: string = '#4FB8C4';
  static TRAVEL_BG: string = '#E4F4F6';
  static ENERGY: string = '#E0A458';
  static ENERGY_BG: string = '#FBF0DF';
  static RECYCLE: string = '#6FC08A';
  static RECYCLE_BG: string = '#E6F5EB';
  static FOOD: string = '#E88B7E';
  static FOOD_BG: string = '#FCEAE7';

  static SUCCESS: string = '#4CAF7D';
  static SUCCESS_BG: string = '#E3F4EA';
  static WARNING: string = '#E0A458';
  static WARNING_BG: string = '#FBF0DF';
  static DANGER: string = '#E0736B';
  static DANGER_BG: string = '#FBE8E6';
  static INFO: string = '#5B9BD5';
  static INFO_BG: string = '#E6F0F9';
}

/** 图标语义色（线色，比面色更高对比度） */
export class IconTone {
  static readonly NEUTRAL: string = 'neutral';
  static readonly TRAVEL: string = 'travel';
  static readonly ENERGY: string = 'energy';
  static readonly RECYCLE: string = 'recycle';
  static readonly FOOD: string = 'food';
  static readonly GOLD: string = 'gold';
  static readonly VIOLET: string = 'violet';
  static readonly DATA: string = 'data';

  /** tone → 当前主题下的描边色 */
  static color(tone: string): string {
    if (ThemePalette.dark) {
      if (tone === IconTone.TRAVEL) return '#5CC2CE';
      if (tone === IconTone.ENERGY) return '#E8B268';
      if (tone === IconTone.RECYCLE) return '#7FCB95';
      if (tone === IconTone.FOOD) return '#F0998C';
      if (tone === IconTone.GOLD) return '#E8C062';
      if (tone === IconTone.VIOLET) return '#A79BF0';
      if (tone === IconTone.DATA) return '#74AEE0';
      return '#9AA8A3';
    }
    if (tone === IconTone.TRAVEL) return '#178A9E';
    if (tone === IconTone.ENERGY) return '#BE7A12';
    if (tone === IconTone.RECYCLE) return '#2E9463';
    if (tone === IconTone.FOOD) return '#CE5B47';
    if (tone === IconTone.GOLD) return '#B0860F';
    if (tone === IconTone.VIOLET) return '#6C5CE0';
    if (tone === IconTone.DATA) return '#2F76C6';
    return '#5C6B66';
  }

  /** 四大类 key 直接当 tone；未知分类回落中性 */
  static ofCategory(cat: string): string {
    if (cat === IconTone.TRAVEL || cat === IconTone.ENERGY
      || cat === IconTone.RECYCLE || cat === IconTone.FOOD) {
      return cat;
    }
    return IconTone.NEUTRAL;
  }

  /** 科普分类：政策→数据蓝、概念→青、技巧→绿 */
  static ofArticle(cat: string): string {
    if (cat === 'policy') return IconTone.DATA;
    if (cat === 'concept') return IconTone.TRAVEL;
    if (cat === 'tips') return IconTone.RECYCLE;
    return IconTone.NEUTRAL;
  }

  /** 通用入口 code → tone */
  static ofUi(code: string): string {
    if (code === 'coin' || code === 'badge' || code === 'star') return IconTone.GOLD;
    if (code === 'mall' || code === 'ticket' || code === 'gift') return IconTone.VIOLET;
    if (code === 'tree' || code === 'certificate' || code === 'home'
      || code === 'recycle' || code === 'sprout' || code === 'leaf') {
      return IconTone.RECYCLE;
    }
    if (code === 'bulb' || code === 'pie' || code === 'calendar' || code === 'flame') {
      return IconTone.ENERGY;
    }
    if (code === 'trend' || code === 'device' || code === 'world' || code === 'chart') {
      return IconTone.DATA;
    }
    if (code === 'commute' || code === 'factor' || code === 'route'
      || code === 'bike' || code === 'bus') {
      return IconTone.TRAVEL;
    }
    if (code === 'target' || code === 'plate') return IconTone.FOOD;
    return IconTone.NEUTRAL;
  }
}

/** 四大类 key 与展示信息 */
export class CategoryMeta {
  static readonly TRAVEL: string = 'travel';
  static readonly ENERGY: string = 'energy';
  static readonly RECYCLE: string = 'recycle';
  static readonly FOOD: string = 'food';

  static label(key: string): string {
    if (key === CategoryMeta.TRAVEL) return '绿色出行';
    if (key === CategoryMeta.ENERGY) return '节水节电';
    if (key === CategoryMeta.RECYCLE) return '旧物回收';
    if (key === CategoryMeta.FOOD) return '光盘行动';
    return '低碳生活';
  }

  static color(key: string): string {
    if (key === CategoryMeta.TRAVEL) return Accent.TRAVEL;
    if (key === CategoryMeta.ENERGY) return Accent.ENERGY;
    if (key === CategoryMeta.RECYCLE) return Accent.RECYCLE;
    if (key === CategoryMeta.FOOD) return Accent.FOOD;
    return Brand.PRIMARY;
  }

  static bg(key: string): string {
    if (key === CategoryMeta.TRAVEL) return Accent.TRAVEL_BG;
    if (key === CategoryMeta.ENERGY) return Accent.ENERGY_BG;
    if (key === CategoryMeta.RECYCLE) return Accent.RECYCLE_BG;
    if (key === CategoryMeta.FOOD) return Accent.FOOD_BG;
    return Brand.PRIMARY_PALE;
  }

  static icon(key: string): string {
    if (key === CategoryMeta.TRAVEL) return 'commute';
    if (key === CategoryMeta.ENERGY) return 'bulb';
    if (key === CategoryMeta.RECYCLE) return 'recycle';
    if (key === CategoryMeta.FOOD) return 'plate';
    return 'sprout';
  }

  static all(): string[] {
    return [CategoryMeta.TRAVEL, CategoryMeta.ENERGY, CategoryMeta.RECYCLE, CategoryMeta.FOOD];
  }
}

/** 碳情绪色阶：把碳排放水平翻译成视觉语言 */
export class EcoMood {
  static ECO_FROM: string = '#B9F4CE';
  static ECO_TO: string = '#4ADE80';
  static ECO_BG: string = 'rgba(240,251,244,0.62)';
  static ECO_ACCENT: string = '#189A55';

  static GOOD_FROM: string = '#DDEFAF';
  static GOOD_TO: string = '#A3D977';
  static GOOD_BG: string = 'rgba(247,251,236,0.62)';
  static GOOD_ACCENT: string = '#6E9E2E';

  static WARN_FROM: string = '#F6E7AE';
  static WARN_TO: string = '#E9C55C';
  static WARN_BG: string = 'rgba(253,250,237,0.62)';
  static WARN_ACCENT: string = '#C0922C';

  static ALERT_FROM: string = '#F2B3AB';
  static ALERT_TO: string = '#E0736B';
  static ALERT_BG: string = 'rgba(253,243,241,0.62)';
  static ALERT_ACCENT: string = '#C4554C';

  static NONE_FROM: string = '#D3DCD6';
  static NONE_TO: string = '#A8B5AC';
  static NONE_BG: string = 'rgba(248,249,246,0.62)';
  static NONE_ACCENT: string = '#8A948F';

  static ECO_SOLID: string = '#F0FBF4';
  static GOOD_SOLID: string = '#F7FBEC';
  static WARN_SOLID: string = '#FDFAED';
  static ALERT_SOLID: string = '#FDF3F1';
  static NONE_SOLID: string = '#F8F9F6';

  static blurOf(level: string): number {
    if (level === 'eco') return 16
    if (level === 'good') return 14
    return 12
  }

  static edgeOf(level: string): string {
    if (ThemePalette.dark) {
      if (level === 'eco') return 'rgba(224,255,240,0.26)'
      if (level === 'good') return 'rgba(255,255,255,0.22)'
      return 'rgba(255,255,255,0.18)'
    }
    if (level === 'eco') return 'rgba(238,255,246,0.95)'
    if (level === 'good') return 'rgba(255,255,255,0.88)'
    return 'rgba(255,255,255,0.80)'
  }
}

/** 情绪化反馈：碳状态 → 主题色 + 文案 */
export class EcoTheme {
  /** 判定当日档位 */
  static level(todayKg: number, quotaKg: number): string {
    const quota: number = quotaKg > 0 ? quotaKg : 5
    if (todayKg < 1) return 'none'
    if (todayKg < 3) return 'warn'
    if (todayKg < quota) return 'good'
    return 'eco'
  }

  static from(level: string): string {
    if (level === 'eco') return EcoMood.ECO_FROM
    if (level === 'good') return EcoMood.GOOD_FROM
    if (level === 'warn') return EcoMood.WARN_FROM
    if (level === 'alert') return EcoMood.ALERT_FROM
    return EcoMood.NONE_FROM
  }

  static to(level: string): string {
    if (level === 'eco') return EcoMood.ECO_TO
    if (level === 'good') return EcoMood.GOOD_TO
    if (level === 'warn') return EcoMood.WARN_TO
    if (level === 'alert') return EcoMood.ALERT_TO
    return EcoMood.NONE_TO
  }

  static bg(level: string): string {
    if (level === 'eco') return EcoMood.ECO_BG
    if (level === 'good') return EcoMood.GOOD_BG
    if (level === 'warn') return EcoMood.WARN_BG
    if (level === 'alert') return EcoMood.ALERT_BG
    return EcoMood.NONE_BG
  }

  /** 页面根底实色（@Entry 根容器专用） */
  static bgSolid(level: string): string {
    if (level === 'eco') return EcoMood.ECO_SOLID
    if (level === 'good') return EcoMood.GOOD_SOLID
    if (level === 'warn') return EcoMood.WARN_SOLID
    if (level === 'alert') return EcoMood.ALERT_SOLID
    return EcoMood.NONE_SOLID
  }

  /** 环境光晕色（根层 radialGradient 用） */
  static glow(level: string): string {
    const c: number[] = EcoTheme.parseColor(EcoTheme.primaryLight(level))
    const a: number = ThemePalette.dark ? 0.12 : 0.10
    return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'
  }

  static accent(level: string): string {
    if (level === 'eco') return EcoMood.ECO_ACCENT
    if (level === 'good') return EcoMood.GOOD_ACCENT
    if (level === 'warn') return EcoMood.WARN_ACCENT
    if (level === 'alert') return EcoMood.ALERT_ACCENT
    return EcoMood.NONE_ACCENT
  }

  static primary(level: string): string {
    if (level === 'eco') return EcoMood.ECO_TO
    if (level === 'good') return EcoMood.GOOD_TO
    if (level === 'warn') return EcoMood.WARN_TO
    if (level === 'alert') return EcoMood.ALERT_TO
    return Brand.PRIMARY
  }

  static primaryLight(level: string): string {
    if (level === 'eco') return EcoMood.ECO_FROM
    if (level === 'good') return EcoMood.GOOD_FROM
    if (level === 'warn') return EcoMood.WARN_FROM
    if (level === 'alert') return EcoMood.ALERT_FROM
    return Brand.PRIMARY_LIGHT
  }

  static primaryDeep(level: string): string {
    return EcoTheme.accent(level)
  }

  /** Hero 渐变起始色 */
  static heroFrom(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primaryLight(level)
    if (level === 'eco') return 'rgba(34,84,64,0.94)'
    if (level === 'good') return 'rgba(52,72,44,0.94)'
    if (level === 'warn') return 'rgba(70,62,42,0.94)'
    if (level === 'alert') return 'rgba(72,48,44,0.94)'
    return 'rgba(34,54,48,0.94)'
  }

  /** Hero 渐变中段色 */
  static heroMid(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primary(level)
    if (level === 'eco') return 'rgba(28,68,52,0.94)'
    if (level === 'good') return 'rgba(42,60,36,0.94)'
    if (level === 'warn') return 'rgba(58,52,34,0.94)'
    if (level === 'alert') return 'rgba(60,40,36,0.94)'
    return 'rgba(28,44,40,0.94)'
  }

  /** Hero 渐变尾色 */
  static heroTo(level: string): string {
    if (!ThemePalette.dark) return EcoTheme.primaryDeep(level)
    if (level === 'eco') return 'rgba(22,54,42,0.96)'
    if (level === 'good') return 'rgba(33,48,29,0.96)'
    if (level === 'warn') return 'rgba(46,42,28,0.96)'
    if (level === 'alert') return 'rgba(47,31,29,0.96)'
    return 'rgba(22,35,32,0.96)'
  }

  static primaryPale(level: string): string {
    if (ThemePalette.dark) {
      if (level === 'eco') return 'rgba(63,191,159,0.16)'
      if (level === 'good') return 'rgba(95,184,148,0.16)'
      if (level === 'warn') return 'rgba(224,164,88,0.16)'
      if (level === 'alert') return 'rgba(224,115,107,0.16)'
      return 'rgba(63,191,159,0.12)'
    }
    if (level === 'eco') return 'rgba(226,246,239,0.92)'
    if (level === 'good') return 'rgba(230,245,236,0.92)'
    if (level === 'warn') return 'rgba(251,240,222,0.92)'
    if (level === 'alert') return 'rgba(251,233,230,0.92)'
    return Brand.PRIMARY_PALE
  }

  static shadowColor(level: string): string {
    if (ThemePalette.dark) {
      if (level === 'warn') return 'rgba(224,164,88,0.20)'
      if (level === 'alert') return 'rgba(224,115,107,0.20)'
      return 'rgba(63,191,159,0.20)'
    }
    if (level === 'warn') return 'rgba(224,164,88,0.28)'
    if (level === 'alert') return 'rgba(224,115,107,0.28)'
    return 'rgba(63,191,159,0.28)'
  }

  /** 极简颜色解析（避免循环依赖） */
  private static parseColor(color: string): number[] {
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1)
      if (hex.length >= 6) {
        return [parseInt(hex.substring(0, 2), 16), parseInt(hex.substring(2, 4), 16),
          parseInt(hex.substring(4, 6), 16), hex.length >= 8 ? parseInt(hex.substring(6, 8), 16) / 255 : 1]
      }
      return [0, 0, 0, 1]
    }
    if (color.indexOf('rgba') === 0) {
      const inner: string = color.substring(color.indexOf('(') + 1, color.indexOf(')'))
      const parts: string[] = inner.split(',')
      if (parts.length >= 3) {
        const a: number = parts.length >= 4 ? Number(parts[3].trim()) : 1
        return [Number(parts[0].trim()), Number(parts[1].trim()), Number(parts[2].trim()), a]
      }
    }
    return [0, 0, 0, 1]
  }

  /** 把固定主题色按当前档位混合情绪色 */
  static tintByMood(base: string, blend: string, ratio: number): string {
    const b: number[] = EcoTheme.parseColor(base);
    const t: number[] = EcoTheme.parseColor(blend);
    if (b.length < 4 || t.length < 4) return base
    const r: number = Math.round(b[0] + (t[0] - b[0]) * ratio)
    const g: number = Math.round(b[1] + (t[1] - b[1]) * ratio)
    const bl: number = Math.round(b[2] + (t[2] - b[2]) * ratio)
    const a: number = Math.min(0.92, Math.max(b[3], 0.62))
    return 'rgba(' + r + ',' + g + ',' + bl + ',' + a.toFixed(2) + ')'
  }

  static moodMix(level: string): number {
    if (level === 'alert') return 0.55
    if (level === 'warn') return 0.30
    if (level === 'eco' || level === 'good') return 0
    return 0.12
  }

  static moodColor(level: string): string {
    if (level === 'alert') return Accent.FOOD
    if (level === 'warn') return Accent.ENERGY
    return Brand.PRIMARY
  }

  static moodTint(level: string, base: string, rank: number = 2): string {
    const step: number = EcoTheme.moodStep(level)
    if (step <= 0) return base
    const graded: number = Math.min(1, step * (0.55 + rank * 0.22))
    return EcoTheme.tintByMood(base, EcoTheme.moodColor(level), graded)
  }

  static moodStep(level: string): number {
    if (level === 'alert') return 0.55
    if (level === 'warn') return 0.30
    if (level === 'eco' || level === 'good') return 0
    return 0.10
  }

  static moodAccent(level: string): string {
    return EcoTheme.accent(level)
  }

  static icon(level: string): string {
    if (level === 'eco') return 'leaf'
    if (level === 'good') return 'sprout'
    if (level === 'warn') return 'sun'
    if (level === 'alert') return 'flame'
    return 'world'
  }

  static title(level: string): string {
    if (level === 'eco') return '生机满格'
    if (level === 'good') return '渐入佳境'
    if (level === 'warn') return '减排升温'
    if (level === 'alert') return '超出阈值'
    return '静默时刻'
  }

  static desc(level: string, todayKg: number, quotaKg: number): string {
    if (quotaKg <= 0) return '记录一次低碳行为，开启今日生机'
    if (level === 'eco') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，达成日目标，生机满格'
    }
    if (level === 'good') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，接近日目标，渐入佳境'
    }
    if (level === 'warn') {
      return '今日已减排 ' + todayKg.toFixed(2) + ' kg，绿色正在升温'
    }
    return '今日已减排 ' + todayKg.toFixed(2) + ' kg，从一点一滴开始积累'
  }

  static advice(level: string): string {
    if (level === 'warn') return '再记一次骑行或光盘行动，让今日绿色升温'
    if (level === 'good') return '只差一步达成日目标，试试素食一餐或随手关灯'
    return ''
  }
}

/** 圆角与间距 */
export class Radius {
  static readonly SM: number = 8;
  static readonly MD: number = 14;
  static readonly LG: number = 20;
  static readonly XL: number = 28;
  static readonly PILL: number = 999;
}

export class Space {
  static readonly XS: number = 4;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 24;
  static readonly PAGE: number = 18;
}

/** 字号 */
export class FontSize {
  static readonly CAPTION: number = 11;
  static readonly SMALL: number = 12;
  static readonly BODY: number = 14;
  static readonly TITLE: number = 16;
  static readonly HEADING: number = 19;
  static readonly DISPLAY: number = 26;
  static readonly HERO: number = 34;
  static readonly SCALE_TEXT: number = 1.15;
  static readonly SCALE_NUM: number = 1;
}

/** 阴影构造辅助 */
export class Shadow {
  static cardColor: string = '#03000003';
  static cardOffsetY: number = 0;
  static brandColor: string = '#3FBF9F47';
  static raisedColor: string = '#0C000014';
  static raisedOffsetY: number = 6;

  static card(): ShadowOptions {
    return { radius: 8, color: Shadow.cardColor, offsetX: 0, offsetY: Shadow.cardOffsetY };
  }

  static brand(): ShadowOptions {
    return { radius: 18, color: Shadow.brandColor, offsetX: 0, offsetY: 6 };
  }

  static none(): ShadowOptions {
    return { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 };
  }

  static raised(): ShadowOptions {
    return { radius: 20, color: Shadow.raisedColor, offsetX: 0, offsetY: Shadow.raisedOffsetY };
  }
}

/** 液态玻璃材质令牌 */
export class Glass {
  static CARD_BG: string = 'rgba(255,255,255,0.72)';
  static BOTTOM_BAR_BG: string = 'rgba(255,255,255,0.12)';
  static PILL_BG: string = 'rgba(255,255,255,0.42)';
  static readonly LIVE_BLUR: number = 30;
  static readonly LIVE_BLUR_SOFT: number = 12;
  static TOPBAR_BG: string = 'rgba(255,255,255,0.50)';
  static PANEL_LIVE_BG: string = 'rgba(255,255,255,0.50)';
  static SEGMENT_TRACK_BG: string = 'rgba(255,255,255,0.38)';
  static DISC_BG: string = 'rgba(255,255,255,0.52)';
  static DISC_SOLID_BG: string = '#FFFFFF';
  static readonly DISC_BLUR: number = 18;
  static EDGE: string = 'rgba(255,255,255,0.52)';
  static HIGHLIGHT: string = 'rgba(255,255,255,0.60)';

  static edge(): BorderOptions {
    return { width: 1, color: Glass.EDGE };
  }
}

/** 图表布局常量 */
export class Chart {
  static readonly AXIS_W: number = 40;
  static readonly AXIS_RIGHT_W: number = 44;
  static readonly PLOT_H: number = 180;
  static readonly BAR_W: number = 18;
  static readonly AXIS_GAP: number = 6;
  static readonly AXIS_FONT: number = 8;
  static readonly VALUE_FONT: number = 8;
  static readonly VALUE_H: number = 12;
  static readonly XAXIS_H: number = 16;
}

/** 业务常量 */
export class Biz {
  static readonly POINTS_PER_KG: number = 10;
  static readonly POINTS_PER_TREE: number = 3000;

  static levelOf(totalKg: number): number {
    if (totalKg >= 1000) return 5;
    if (totalKg >= 500) return 4;
    if (totalKg >= 100) return 3;
    if (totalKg >= 10) return 2;
    return 1;
  }

  static levelName(level: number): string {
    if (level >= 5) return '森林卫士';
    if (level === 4) return '低碳达人';
    if (level === 3) return '绿芽';
    if (level === 2) return '新芽';
    return '碳芽';
  }

  static levelArt(level: number): string {
    if (level >= 5) return '🌲';
    if (level === 4) return '🌳';
    if (level === 3) return '🍀';
    if (level === 2) return '🌿';
    return '🌱';
  }

  static levelRange(level: number): number[] {
    const bounds: number[][] = [[0, 10], [10, 100], [100, 500], [500, 1000], [1000, 99999]];
    const idx: number = Math.min(Math.max(level, 1), 5) - 1;
    return bounds[idx];
  }

  static levelColor(level: number): string {
    if (level >= 5) return '#3FBF9F';
    if (level === 4) return '#6FC08A';
    if (level === 3) return '#4FB8C4';
    if (level === 2) return '#E0A458';
    return '#E88B7E';
  }

  /** kg 格式化 */
  static formatKg(kg: number): string {
    if (kg >= 1000) return (kg / 1000).toFixed(2) + ' t';
    if (kg >= 10) return kg.toFixed(1) + ' kg';
    return kg.toFixed(2) + ' kg';
  }

  /** 积分换算 */
  static pointsOf(kg: number): number {
    if (kg <= 0) return 0;
    const p: number = Math.round(kg * Biz.POINTS_PER_KG);
    return p < 1 ? 1 : p;
  }

  /** 抵扣的树数量 */
  static treesOf(points: number): number {
    return Math.floor(points / Biz.POINTS_PER_TREE);
  }
}
