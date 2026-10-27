import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ThemePalette } from '../ui/Theme'
import { GlassLight, GlassQualityLevel } from '../ui/GlassLight'

const STORE: string = 'yichu_qinglv'
const KEY_DARK: string = 'dark_mode'
const KEY_DARK_LOCK: string = 'dark_mode_lock'
const KEY_QUALITY: string = 'glass_quality'

export class ThemeMode {
  static readonly TICK_KEY: string = 'themeTick'
  static readonly DARK_KEY: string = 'darkMode'

  private static memoryDark: boolean | null = null;
  private static manualOverride: boolean = false;
  private static systemApplied: boolean = false;
  private static systemDark: boolean = false;

  /* 系统栏适配 */
  private static mainWindow: window.Window | null = null;

  static attachWindow(win: window.Window): void {
    ThemeMode.mainWindow = win;
    ThemeMode.applySystemBar(ThemePalette.dark);
  }

  private static applySystemBar(dark: boolean): void {
    const w: window.Window | null = ThemeMode.mainWindow;
    if (w === null) {
      return;
    }
    const fg: string = dark ? '#F2F5F3' : '#1A1F1C';
    try {
      w.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: fg,
        navigationBarContentColor: fg
      });
    } catch (err) {
      console.warn('[ThemeMode] 系统栏配色更新失败（窗口不可用）');
    }
  }

  private static ctx(): common.Context {
    const c: common.Context | undefined = AppStorage.get<common.Context>('appContext')
    if (c === undefined || c === null) {
      throw new Error('应用上下文未初始化')
    }
    return c
  }

  private static async prefs(): Promise<preferences.Preferences> {
    try {
      return await preferences.getPreferences(ThemeMode.ctx(), STORE)
    } catch (err) {
      throw new Error('本机存储不可用')
    }
  }

  /* 初始化 */

  static async init(systemDark: boolean = false): Promise<void> {
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, ThemePalette.dark)
    AppStorage.setOrCreate(ThemeMode.TICK_KEY, 0)

    ThemeMode.systemDark = systemDark

    let p: preferences.Preferences | undefined = undefined;
    try {
      p = await ThemeMode.prefs()
    } catch (err) {
      console.warn('[ThemeMode] preferences 不可用，本次启动按内存默认值')
    }

    let dark: boolean;
    if (ThemeMode.memoryDark !== null) {
      dark = ThemeMode.memoryDark;
    } else {
      let locked: boolean = false;
      if (p !== undefined) {
        try {
          locked = (await p.get(KEY_DARK_LOCK, false)) as boolean
        } catch (err) {
          console.warn('[ThemeMode] 读取 dark_mode_lock 失败，按未锁定走')
        }
      }
      if (locked) {
        ThemeMode.manualOverride = true;
        let persisted: boolean = false;
        if (p !== undefined) {
          try {
            persisted = (await p.get(KEY_DARK, false)) as boolean
          } catch (err) {
            console.warn('[ThemeMode] 读取 dark_mode 失败，沿用当前值')
          }
        }
        dark = persisted;
      } else {
        dark = systemDark;
      }
    }
    ThemePalette.applyDark(dark)
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, dark)
    ThemeMode.memoryDark = dark;
    ThemeMode.applySystemBar(dark)

    let quality: string = GlassLight.quality
    if (p !== undefined) {
      try {
        quality = (await p.get(KEY_QUALITY, GlassQualityLevel.CINEMATIC)) as string
      } catch (err) {
        console.warn('[ThemeMode] 读取 glass_quality 失败，沿用当前档位')
      }
    }
    GlassLight.quality = quality

    ThemeMode.bumpRender()
  }

  /* 深色模式 */

  static isDark(): boolean {
    return ThemePalette.dark
  }

  static setDark(dark: boolean): void {
    ThemeMode.manualOverride = true
    ThemeMode.persistDark(dark)
    ThemeMode.applyTheme(dark)
  }

  static onSystemColorModeChange(isDark: boolean): void {
    ThemeMode.systemDark = isDark
    if (ThemeMode.manualOverride) return
    if (ThemeMode.memoryDark !== null) return
    ThemeMode.applyTheme(isDark)
  }

  private static applyTheme(dark: boolean): void {
    if (ThemePalette.dark === dark) return
    ThemePalette.applyDark(dark)
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, dark)
    ThemeMode.applySystemBar(dark)
    ThemeMode.memoryDark = dark
    ThemeMode.bumpRender()
  }

  static toggleDark(): void {
    ThemeMode.setDark(!ThemePalette.dark)
  }

  private static async persistDark(dark: boolean): Promise<void> {
    ThemeMode.memoryDark = dark;
    try {
      const p: preferences.Preferences = await ThemeMode.prefs()
      await p.put(KEY_DARK, dark)
      await p.put(KEY_DARK_LOCK, true)
      await p.flush()
    } catch (err) {
      console.warn('[ThemeMode] 深色状态仅存于内存（预览器/存储不可用）')
    }
  }

  /* 玻璃画质 */

  static quality(): string {
    return GlassLight.quality
  }

  static setQuality(quality: string): void {
    if (GlassLight.quality === quality) return
    GlassLight.quality = quality
    ThemeMode.persistQuality(quality)
    ThemeMode.bumpRender()
  }

  private static async persistQuality(quality: string): Promise<void> {
    try {
      const p: preferences.Preferences = await ThemeMode.prefs()
      await p.put(KEY_QUALITY, quality)
      await p.flush()
    } catch (err) {
      // 预览器/存储不可用时静默跳过
    }
  }

  /* 预览器兜底播种 */

  static ensureInit(systemDark: boolean = false): void {
    if (AppStorage.get<number>(ThemeMode.TICK_KEY) === undefined) {
      AppStorage.setOrCreate(ThemeMode.TICK_KEY, 0)
    }
    if (AppStorage.get<boolean>(ThemeMode.DARK_KEY) === undefined) {
      AppStorage.setOrCreate(ThemeMode.DARK_KEY, ThemePalette.dark)
    }
    if (!ThemeMode.systemApplied) {
      ThemeMode.systemApplied = true
      if (ThemeMode.memoryDark === null && !ThemeMode.manualOverride) {
        ThemeMode.applyTheme(systemDark)
      }
    }
  }

  /* 重新渲染 */

  static bumpRender(): void {
    const t: number | undefined = AppStorage.get<number>(ThemeMode.TICK_KEY)
    const next: number = (t === undefined || t === null) ? 1 : t + 1
    AppStorage.setOrCreate(ThemeMode.TICK_KEY, next)
  }
}

// 模块级兜底：任何页面挂载前尝试把广播键建好
try {
  if (AppStorage.get<number>(ThemeMode.TICK_KEY) === undefined) {
    AppStorage.setOrCreate(ThemeMode.TICK_KEY, 0)
  }
  if (AppStorage.get<boolean>(ThemeMode.DARK_KEY) === undefined) {
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, ThemePalette.dark)
  }
} catch (err) {
  // AppStorage 暂不可用：保持静默，等 ensureInit 再播种
}
