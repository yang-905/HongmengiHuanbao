/** 统一玻璃光照模型：所有液态玻璃组件共享同一套光照计算 */
import { EcoTheme, Glass, ThemePalette } from './Theme'

/** 玻璃材质档位 */
export class GlassTier {
  static readonly PILL: string = 'pill';
  static readonly CARD: string = 'card';
  static readonly PANEL: string = 'panel';
}

/** 画质档位 */
export class GlassQualityLevel {
  static readonly CINEMATIC: string = 'cinematic';
  static readonly BALANCED: string = 'balanced';
  static readonly LITE: string = 'lite';
}

/** 玻璃按压反馈档 */
export class GlassPress {
  static readonly CARD: number = 0.98;
  static readonly PILL: number = 0.95;
  static readonly NONE: number = 1;
}

export class GlassLight {
  /** 主光源方向：左上 135°（linearGradient 从左上扫向右下） */
  static readonly LIGHT_ANGLE: number = 135;

  /** 视差状态在 AppStorage 里的键名 */
  static readonly PARALLAX_KEY: string = 'glassParallax';

  /** 深色模式高光色温（冷白） */
  static readonly DARK_LIT: string = '236,244,246';

  /** 深色模式背光面色（深青黑） */
  static readonly DARK_SHADE: string = '8,14,16';

  /** 深色模式玻璃基底色（白色微染） */
  static readonly DARK_TINT: string = '236,244,246';

  /** 深色模式文字区暗纱色 */
  static readonly DARK_SCRIM: string = '8,12,14';

  /** 当前画质档位 */
  static quality: string = GlassQualityLevel.CINEMATIC;

  /** 解析颜色字符串并返回 Rec.709 感知亮度（0~1） */
  static luma(color: string): number {
    let r: number = 255;
    let g: number = 255;
    let b: number = 255;
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1);
      if (hex.length === 6) {
        r = parseInt(hex.substring(0, 2), 16);
        g = parseInt(hex.substring(2, 4), 16);
        b = parseInt(hex.substring(4, 6), 16);
      }
    } else if (color.indexOf('rgba') === 0) {
      const inner: string = color.substring(color.indexOf('(') + 1, color.indexOf(')'));
      const parts: string[] = inner.split(',');
      if (parts.length >= 3) {
        r = Number(parts[0].trim());
        g = Number(parts[1].trim());
        b = Number(parts[2].trim());
      }
    }
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return 1;
    }
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  }

  /** 浅色环境自适应系数 */
  static adapt(ambient: string): number {
    const l: number = GlassLight.luma(ambient);
    if (l > 0.78) return 0.92;
    if (l < 0.40) return 1.22;
    return 1;
  }

  /** 深色环境自适应系数：背景越暗边缘越亮 */
  static darkAdapt(ambient: string): number {
    const l: number = GlassLight.luma(ambient);
    if (l < 0.12) return 1.10;
    if (l < 0.25) return 1.05;
    return 1;
  }

  /** 玻璃层数预算 */
  static layerBudget(): number {
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (GlassLight.quality === GlassQualityLevel.BALANCED) return 3;
    return 4;
  }

  static fresnelLeftOn(): boolean {
    return GlassLight.layerBudget() >= 4;
  }

  /** 玻璃底色 alpha（受背景亮度影响） */
  static tintAlpha(tier: string, ambient: string): number {
    if (ThemePalette.dark) {
      let a: number = 0.09;
      if (tier === GlassTier.PILL) {
        a = 0.13;
      } else if (tier === GlassTier.PANEL) {
        a = 0.11;
      }
      const l: number = GlassLight.luma(ambient);
      if (l < 0.12) {
        a += 0.02;
      } else if (l > 0.25) {
        a -= 0.02;
      }
      return Math.min(0.20, Math.max(0.05, a));
    }
    const f: number = GlassLight.adapt(ambient);
    let a: number = 0.72;
    if (tier === GlassTier.PILL) {
      a = 0.42 * f;
    } else if (tier === GlassTier.PANEL) {
      a = 0.50 * f;
    } else {
      a = 0.72 + (f - 1) * 0.1;
    }
    return Math.min(0.92, Math.max(0.26, a));
  }

  /** 玻璃底色颜色 */
  static tintColor(tier: string, ambient: string): string {
    const a: number = GlassLight.tintAlpha(tier, ambient);
    if (ThemePalette.dark) {
      return 'rgba(' + GlassLight.DARK_TINT + ',' + a.toFixed(2) + ')';
    }
    return 'rgba(255,255,255,' + a.toFixed(2) + ')';
  }

  /** 可读性接触纱（亮背景下的定向暗纱） */
  static scrim(ambient: string): string {
    const l: number = GlassLight.luma(ambient);
    if (l > 0.78) return 'rgba(12,18,16,0.10)';
    if (l > 0.62) return 'rgba(12,18,16,0.05)';
    return 'rgba(0,0,0,0)';
  }

  /** 接触纱的定向渐变（135°） */
  static scrimColors(ambient: string): [string, number][] {
    const c: string = GlassLight.scrim(ambient);
    if (c === 'rgba(0,0,0,0)') {
      return [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0)', 1]];
    }
    return [
      ['rgba(12,18,16,0)', 0],
      [c, 1]
    ];
  }

  static scrimOn(ambient: string): boolean {
    return GlassLight.scrim(ambient) !== 'rgba(0,0,0,0)';
  }

  /* ---------- 光照 alpha ---------- */

  /** 对角光染强度 */
  static washAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.11;
    if (tier === GlassTier.PILL) {
      base = 0.10;
    } else if (tier === GlassTier.PANEL) {
      base = 0.13;
    }
    return base * f;
  }

  /** 菲涅尔亮边强度 */
  static edgeAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.30;
    if (tier === GlassTier.PILL) {
      base = 0.26;
    } else if (tier === GlassTier.PANEL) {
      base = 0.34;
    }
    return base * f;
  }

  /** 内阴影强度（背光面厚度感） */
  static innerAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.02;
    if (tier === GlassTier.PILL) {
      base = 0.02;
    } else if (tier === GlassTier.PANEL) {
      base = 0.03;
    }
    return base * f;
  }

  /** 1px 描边：受光边 alpha */
  static edgeBorderAlpha(tier: string, ambient: string): number {
    const f: number = GlassLight.adapt(ambient);
    let base: number = 0.46;
    if (tier === GlassTier.PILL) {
      base = 0.40;
    } else if (tier === GlassTier.PANEL) {
      base = 0.52;
    }
    return Math.min(0.92, base * f);
  }

  /** 1px 描边：背光边 alpha */
  static shadeBorderAlpha(tier: string, ambient: string): number {
    let base: number = 0.02;
    if (tier === GlassTier.PILL) {
      base = 0.025;
    } else if (tier === GlassTier.PANEL) {
      base = 0.03;
    }
    if (GlassLight.luma(ambient) < 0.40) base *= 0.6;
    return base;
  }

  /* ---------- 深色模式 ---------- */

  /** 深色：对角光染强度 */
  static washAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    let base: number = 0.07;
    if (tier === GlassTier.PILL) {
      base = 0.06;
    } else if (tier === GlassTier.PANEL) {
      base = 0.07;
    }
    return base * f;
  }

  /** 深色：菲涅尔亮边强度 */
  static edgeAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    let base: number = 0.52;
    if (tier === GlassTier.PILL) {
      base = 0.60;
    } else if (tier === GlassTier.PANEL) {
      base = 0.56;
    }
    return Math.min(0.62, base * f);
  }

  /** 深色：内阴影强度 */
  static innerAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    let base: number = 0.04;
    if (tier === GlassTier.PILL) {
      base = 0.05;
    } else if (tier === GlassTier.PANEL) {
      base = 0.045;
    }
    return base * f;
  }

  /** 深色：1px 描边受光边 */
  static edgeBorderAlphaDark(tier: string, ambient: string): number {
    const f: number = GlassLight.darkAdapt(ambient);
    let base: number = 0.18;
    if (tier === GlassTier.PILL) {
      base = 0.22;
    } else if (tier === GlassTier.PANEL) {
      base = 0.16;
    }
    return Math.min(0.26, base * f);
  }

  /** 深色：1px 描边背光边 */
  static shadeBorderAlphaDark(tier: string, ambient: string): number {
    let base: number = 0.06;
    if (tier === GlassTier.PILL) {
      base = 0.07;
    } else if (tier === GlassTier.PANEL) {
      base = 0.065;
    }
    return base;
  }

  /* ---------- 外投影 ---------- */

  /** 外投影：与内阴影同向（右下） */
  static shadowOf(tier: string): ShadowOptions {
    if (ThemePalette.dark) {
      if (tier === GlassTier.PILL) {
        return { radius: 6, color: '#06000000', offsetX: 0, offsetY: 1 };
      }
      if (tier === GlassTier.PANEL) {
        return { radius: 14, color: '#0A000010', offsetX: 1, offsetY: 3 };
      }
      return { radius: 10, color: '#08000000', offsetX: 0, offsetY: 2 };
    }
    if (tier === GlassTier.PILL) {
      return { radius: 8, color: '#02000002', offsetX: 0, offsetY: 0 };
    }
    if (tier === GlassTier.PANEL) {
      return { radius: 12, color: '#03000004', offsetX: 0, offsetY: 0 };
    }
    return { radius: 10, color: '#03000003', offsetX: 0, offsetY: 0 };
  }

  /* ---------- 模糊 ---------- */

  /** 按画质档位缩放模糊半径 */
  static blurScaled(base: number): number {
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (GlassLight.quality === GlassQualityLevel.BALANCED) return Math.round(base * 0.7);
    return base;
  }

  /** 实时模糊半径：card 档一律 0（性能红线） */
  static blurOf(tier: string, glass: boolean): number {
    if (!glass) return 0;
    if (GlassLight.quality === GlassQualityLevel.LITE) return 0;
    if (tier === GlassTier.PILL) return GlassLight.blurScaled(Glass.LIVE_BLUR_SOFT);
    if (tier === GlassTier.PANEL) return GlassLight.blurScaled(Glass.LIVE_BLUR);
    return 0;
  }

  /** 品牌色投影（供选中态药丸使用） */
  static shadowTintOf(color: string): string {
    if (color.charAt(0) === '#' && color.length === 7) {
      const r: number = parseInt(color.substring(1, 3), 16);
      const g: number = parseInt(color.substring(3, 5), 16);
      const b: number = parseInt(color.substring(5, 7), 16);
      if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b)) {
        return 'rgba(' + r + ',' + g + ',' + b + ',0.30)';
      }
    }
    return 'rgba(63,191,159,0.30)';
  }

  /* ---------- 颜色解析 / α 合成 ---------- */

  /** 解析颜色字符串 → [r, g, b, a] */
  static rgbaOf(color: string): number[] {
    if (color.charAt(0) === '#') {
      const hex: string = color.substring(1);
      const ok: boolean = hex.length === 6 || hex.length === 8;
      if (ok) {
        let r: number = 255;
        let g: number = 255;
        let b: number = 255;
        let a: number = 1;
        if (hex.length === 8) {
          a = parseInt(hex.substring(0, 2), 16) / 255;
          r = parseInt(hex.substring(2, 4), 16);
          g = parseInt(hex.substring(4, 6), 16);
          b = parseInt(hex.substring(6, 8), 16);
        } else {
          r = parseInt(hex.substring(0, 2), 16);
          g = parseInt(hex.substring(2, 4), 16);
          b = parseInt(hex.substring(4, 6), 16);
        }
        if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b) && !Number.isNaN(a)) {
          return [r, g, b, a];
        }
      }
    } else if (color.indexOf('rgb') === 0) {
      const open: number = color.indexOf('(');
      const close: number = color.indexOf(')');
      if (open >= 0 && close > open) {
        const parts: string[] = color.substring(open + 1, close).split(',');
        if (parts.length >= 3) {
          const r: number = Number(parts[0].trim());
          const g: number = Number(parts[1].trim());
          const b: number = Number(parts[2].trim());
          let a: number = 1;
          if (parts.length >= 4) {
            a = Number(parts[3].trim());
          }
          if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b) && !Number.isNaN(a)) {
            return [r, g, b, a];
          }
        }
      }
    }
    return [255, 255, 255, 1];
  }

  /** α 合成：把 top 叠在 base 之上，返回 rgba 字符串 */
  static over(base: number[], top: number[], alphaScale: number): string {
    const ba: number = Math.max(0, Math.min(1, base[3]));
    const ta: number = Math.max(0, Math.min(1, top[3] * alphaScale));
    const outA: number = ta + ba * (1 - ta);
    if (outA <= 0.001) {
      return 'rgba(0,0,0,0)';
    }
    const k: number = ba * (1 - ta);
    const r: number = (top[0] * ta + base[0] * k) / outA;
    const g: number = (top[1] * ta + base[1] * k) / outA;
    const b: number = (top[2] * ta + base[2] * k) / outA;
    return 'rgba(' + Math.round(r) + ',' + Math.round(g) + ',' + Math.round(b) +
      ',' + outA.toFixed(3) + ')';
  }

  /* ---------- 渐变构造 ---------- */

  /** 通用单层合成 135° 渐变（预合成光照层到底色上） */
  static surface(base: string, tier: string, ambient: string, gloss: number): LinearGradient {
    const baseRgba: number[] = GlassLight.rgbaOf(base);
    const wash: [string, number][] = GlassLight.washColors(tier, ambient, gloss);
    const colors: [string, number][] = [];
    let last: number = -1;
    for (let i = 0; i < wash.length; i++) {
      let pos: number = wash[i][1];
      if (pos < 0) {
        pos = 0;
      }
      if (pos > 1) {
        pos = 1;
      }
      if (pos <= last) {
        continue;
      }
      colors.push([GlassLight.over(baseRgba, GlassLight.rgbaOf(wash[i][0]), 1),
        Number(pos.toFixed(3))]);
      last = pos;
    }
    if (colors.length === 0) {
      colors.push([base, 0]);
      colors.push([base, 1]);
    }
    return { angle: GlassLight.LIGHT_ANGLE, colors: colors };
  }

  /** 药丸专用渐变 */
  static pillSurface(base: string, tier: string, ambient: string, gloss: number): LinearGradient {
    return GlassLight.surface(base, tier, ambient, gloss);
  }

  /** 大面积玻璃面板渐变入口 */
  static panelSurface(ambient: string): LinearGradient {
    return GlassLight.surface(Glass.PANEL_LIVE_BG, GlassTier.PANEL, ambient, 1);
  }

  /** 等色双停渐变 */
  static flat(color: string): LinearGradient {
    return { angle: 180, colors: [[color, 0], [color, 1]] };
  }

  /** 球面渐变（＋圆钮） */
  static orbSurface(): LinearGradient {
    if (ThemePalette.dark) {
      const baseD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_TINT + ',0.09)');
      const litD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_LIT + ',1)');
      const shadeD: number[] = GlassLight.rgbaOf('rgba(' + GlassLight.DARK_SHADE + ',1)');
      const colorsD: [string, number][] = [
        [GlassLight.over(baseD, litD, 0.05), 0],
        [GlassLight.over(baseD, litD, 0.09), 0.22],
        [GlassLight.over(baseD, litD, 0.13), 0.38],
        [GlassLight.over(baseD, shadeD, 0.03), 0.72],
        [GlassLight.over(baseD, shadeD, 0.05), 1]
      ];
      return { angle: GlassLight.LIGHT_ANGLE, colors: colorsD };
    }
    const baseL: number[] = GlassLight.rgbaOf('rgba(255,255,255,0.34)');
    const litL: number[] = [255, 255, 255, 1];
    const shadeL: number[] = [10, 16, 14, 1];
    const colorsL: [string, number][] = [
      [GlassLight.over(baseL, litL, 0.30), 0],
      [GlassLight.over(baseL, litL, 0.55), 0.22],
      [GlassLight.over(baseL, litL, 0.70), 0.38],
      [GlassLight.over(baseL, shadeL, 0.05), 0.72],
      [GlassLight.over(baseL, shadeL, 0.09), 1]
    ];
    return { angle: GlassLight.LIGHT_ANGLE, colors: colorsL };
  }

  /** 品牌档位色球面渐变（FAB 用） */
  static orbAccentSurface(level: string): LinearGradient {
    const fromC: number[] = GlassLight.rgbaOf(EcoTheme.primaryLight(level));
    const toC: number[] = GlassLight.rgbaOf(EcoTheme.primary(level));
    const lit: number[] = [255, 255, 255, 1];
    const shade: number[] = [10, 16, 14, 1];
    const colors: [string, number][] = [
      [GlassLight.over([fromC[0], fromC[1], fromC[2], 0.78], lit, 0.30), 0],
      [GlassLight.over([fromC[0], fromC[1], fromC[2], 0.84], lit, 0.50), 0.22],
      [GlassLight.over([toC[0], toC[1], toC[2], 0.90], lit, 0.38), 0.38],
      [GlassLight.over([toC[0], toC[1], toC[2], 0.93], shade, 0.05), 0.72],
      [GlassLight.over([toC[0], toC[1], toC[2], 0.95], shade, 0.10), 1]
    ];
    return { angle: GlassLight.LIGHT_ANGLE, colors: colors };
  }

  /** 对角光染 + 内阴影的多段渐变（光照层） */
  static washColors(tier: string, ambient: string, gloss: number): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'w|' + tier + '|' + ambient + '|' + gloss + '|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.washColorsImpl(tier, ambient, gloss));
  }

  private static washColorsImpl(tier: string, ambient: string, gloss: number): [string, number][] {
    if (ThemePalette.dark) {
      const wa: number = GlassLight.washAlphaDark(tier, ambient) * gloss;
      const ia: number = GlassLight.innerAlphaDark(tier, ambient) * gloss;
      return [
        ['rgba(' + GlassLight.DARK_LIT + ',' + wa.toFixed(3) + ')', 0],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.72).toFixed(3) + ')', 0.16],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.40).toFixed(3) + ')', 0.34],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (wa * 0.16).toFixed(3) + ')', 0.50],
        ['rgba(' + GlassLight.DARK_LIT + ',0)', 0.62],
        ['rgba(' + GlassLight.DARK_SHADE + ',' + (ia * 0.35).toFixed(3) + ')', 0.88],
        ['rgba(' + GlassLight.DARK_SHADE + ',' + ia.toFixed(3) + ')', 1]
      ];
    }
    const wa: number = GlassLight.washAlpha(tier, ambient) * gloss;
    const ia: number = GlassLight.innerAlpha(tier, ambient) * gloss;
    return [
      ['rgba(255,255,255,' + wa.toFixed(3) + ')', 0],
      ['rgba(255,255,255,' + (wa * 0.62).toFixed(3) + ')', 0.12],
      ['rgba(255,255,255,' + (wa * 0.16).toFixed(3) + ')', 0.38],
      ['rgba(255,255,255,0)', 0.55],
      ['rgba(10,16,14,' + (ia * 0.30).toFixed(3) + ')', 0.90],
      ['rgba(10,16,14,' + ia.toFixed(3) + ')', 1]
    ];
  }

  /** 菲涅尔亮边渐变（边缘处更亮） */
  static fresnelColors(tier: string, ambient: string, gloss: number): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'f|' + tier + '|' + ambient + '|' + gloss + '|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.fresnelColorsImpl(tier, ambient, gloss));
  }

  private static fresnelColorsImpl(tier: string, ambient: string, gloss: number): [string, number][] {
    if (ThemePalette.dark) {
      const ea: number = GlassLight.edgeAlphaDark(tier, ambient) * gloss;
      return [
        ['rgba(' + GlassLight.DARK_LIT + ',' + ea.toFixed(3) + ')', 0],
        ['rgba(' + GlassLight.DARK_LIT + ',' + (ea * 0.45).toFixed(3) + ')', 0.03],
        ['rgba(' + GlassLight.DARK_LIT + ',0)', 0.09]
      ];
    }
    const ea: number = GlassLight.edgeAlpha(tier, ambient) * gloss;
    return [
      ['rgba(255,255,255,' + ea.toFixed(3) + ')', 0],
      ['rgba(255,255,255,' + (ea * 0.35).toFixed(3) + ')', 0.05],
      ['rgba(255,255,255,0)', 0.13]
    ];
  }

  /** 四边异色描边（受光边亮，背光边深） */
  static borderColors(tier: string, ambient: string, gloss: number): EdgeColors {
    if (ThemePalette.dark) {
      const lit: string = 'rgba(' + GlassLight.DARK_LIT + ',' +
        (GlassLight.edgeBorderAlphaDark(tier, ambient) * gloss).toFixed(2) + ')';
      const shade: string = 'rgba(' + GlassLight.DARK_SHADE + ',' +
        (GlassLight.shadeBorderAlphaDark(tier, ambient) * gloss).toFixed(2) + ')';
      return { top: lit, right: shade, bottom: shade, left: lit };
    }
    const lit: string = 'rgba(255,255,255,' + (GlassLight.edgeBorderAlpha(tier, ambient) * gloss).toFixed(2) + ')';
    const shade: string = 'rgba(10,16,14,' + (GlassLight.shadeBorderAlpha(tier, ambient) * gloss).toFixed(2) + ')';
    return { top: lit, right: shade, bottom: shade, left: lit };
  }

  /** 深色文字区暗纱 */
  static textScrim(): [string, number][] {
    return GlassLight.memoPut<[string, number][]>(
      'ts|' + GlassLight.sig(),
      (): [string, number][] => GlassLight.textScrimImpl());
  }

  private static textScrimImpl(): [string, number][] {
    return [
      ['rgba(' + GlassLight.DARK_SCRIM + ',0.02)', 0],
      ['rgba(' + GlassLight.DARK_SCRIM + ',0.08)', 1]
    ];
  }

  /* ---------- 滚动视差 ---------- */

  private static parallaxValue: number = 0;
  private static parallaxPending: number = 0;
  private static parallaxTimer: number = -1;

  static parallaxFactor(): number {
    return ThemePalette.dark ? 0.11 : 0.22;
  }

  static parallaxLimit(): number {
    return ThemePalette.dark ? 5 : 10;
  }

  /** 滚动视差累加（由列表 onScroll(dy) 调用） */
  static nudge(dy: number): void {
    GlassLight.parallaxPending = GlassLight.parallaxPending + dy * GlassLight.parallaxFactor();
    GlassLight.ensureTick();
  }

  /** 复位视差 */
  static resetParallax(): void {
    GlassLight.parallaxPending = 0;
    GlassLight.parallaxValue = 0;
    if (GlassLight.parallaxTimer !== -1) {
      clearInterval(GlassLight.parallaxTimer);
      GlassLight.parallaxTimer = -1;
    }
    AppStorage.setOrCreate(GlassLight.PARALLAX_KEY, 0);
  }

  private static ensureTick(): void {
    if (GlassLight.parallaxTimer !== -1) return;
    GlassLight.parallaxTimer = setInterval((): void => {
      let v: number = GlassLight.parallaxValue + GlassLight.parallaxPending;
      GlassLight.parallaxPending = 0;
      v = v * 0.78;
      if (Math.abs(v) < 0.1) {
        v = 0;
      }
      GlassLight.parallaxValue = Math.max(-GlassLight.parallaxLimit(),
        Math.min(GlassLight.parallaxLimit(), v));
      AppStorage.setOrCreate(GlassLight.PARALLAX_KEY, GlassLight.parallaxValue);
      if (GlassLight.parallaxValue === 0) {
        clearInterval(GlassLight.parallaxTimer);
        GlassLight.parallaxTimer = -1;
      }
    }, 80);
  }

  /* ---------- 光照结果缓存 ---------- */

  private static gradMemo: Map<string, Object> = new Map();

  private static sig(): string {
    return (ThemePalette.dark ? 'd1' : 'd0') + '|' + GlassLight.quality;
  }

  private static memoPut<T>(key: string, make: () => T): T {
    const hit: Object | undefined = GlassLight.gradMemo.get(key);
    if (hit !== undefined) {
      return hit as T;
    }
    const made: T = make();
    GlassLight.gradMemo.set(key, made as Object);
    return made;
  }
}
