/**
 * 深色模式 / 全局重新渲染 管理
 * ------------------------------------------------------------------
 * 职责：
 *   1. 深色模式开关：持久化到 Preferences，切换时整组换血色值令牌
 *      （ThemePalette.applyDark）并广播重渲染信号；
 *   2. 玻璃画质档位：LITE / BALANCED / CINEMATIC 持久化（降级策略入口）；
 *   3. 重新渲染开关：推进 AppStorage('themeTick') 全局序号，
 *      强制全应用界面重建。
 *
 * 重渲染机制（为什么需要 themeTick）：
 *   Theme.ets 的色值是 static 字段，ArkTS 的静态字段**不响应**——
 *   applyDark 换血后，已经建完的页面不会自己重读新值。
 *   因此每个页面都订阅 @StorageProp('themeTick')，并在 build() 里
 *   读一次（恒 1 的 opacity 钩子）：themeTick 变化 → 组件标记脏 →
 *   build() 重执行 → 重新读取 static 色值 → 新配色上屏。
 *   这就是设置页「重新渲染」开关能做到「整页重建」的原因。
 *
 * 持久化与 LocalStore 同模式：Preferences（STORE='yichu_qinglv'），
 * 上下文从 AppStorage('appContext') 取（EntryAbility.onCreate 注入）。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ThemePalette } from '../ui/Theme'
import { GlassLight, GlassQualityLevel } from '../ui/GlassLight'

/** Preferences 文件名（与 LocalStore 一致，同库不同键） */
const STORE: string = 'yichu_qinglv'
/** 深色模式开关键（用户手动锁定的明暗值） */
const KEY_DARK: string = 'dark_mode'
/**
 * 深色「手动锁定」标记键。
 * ------------------------------------------------------------------
 * 用于区分两种来源：
 *   · 未锁定（本键不存在/为 false）= 跟随系统深色（默认行为，
 *     这也是「深色模式适配」的标准含义：系统深 → app 深）；
 *   · 已锁定（用户在设置页拨过开关）= 以用户选择为准，
 *     系统切换不再覆盖，避免「系统浅了 app 又被拉回浅」。
 * 单凭 KEY_DARK 无法区分「用户主动选了浅色」与「默认浅色」，
 * 因此必须单独记一个锁定标记。
 */
const KEY_DARK_LOCK: string = 'dark_mode_lock'
/** 玻璃画质档位键 */
const KEY_QUALITY: string = 'glass_quality'

export class ThemeMode {
  /** 重渲染信号在 AppStorage 里的键名 */
  static readonly TICK_KEY: string = 'themeTick'
  /** 深色开关状态在 AppStorage 里的键名（设置页 Switch 直接绑它） */
  static readonly DARK_KEY: string = 'darkMode'

  /**
   * 深色状态的内存镜像（Preferences 不可用时的兜底，见 persistDark 注释）。
   * null= 尚未设置过；true/false = 本次运行内的实际状态。
   */
  private static memoryDark: boolean | null = null;

  /**
   * 用户是否在设置页手动锁定过明暗。
   * true = 以用户选择为准，不跟随系统；false = 跟随系统深色（默认）。
   */
  private static manualOverride: boolean = false;

  /**
   * 本进程是否已按系统深色定过首帧。
   * ------------------------------------------------------------------
   * 预览器刷新 / 冷启动时 memoryDark 会重置为 null（Preferences 在预览器
   * 不可用，用户拨过的开关活不过一次刷新）。此时 App 应回到「跟随系统」
   * 语义 —— 预览器工具栏把设备切成深色，App 初次打开就是深色，刷新后
   * 也保持一致（用户截图反馈「初次打开刷新有 bug」的根因）。
   * 真机路径由 init() 先行定过首帧，本标记防止 ensureInit 二次翻面。
   */
  private static systemApplied: boolean = false;

  /**
   * 最近一次获知的系统深色状态（onConfigurationUpdate 实时刷新）。
   * 用于「未手动锁定时」决定 app 明暗；同时也是启动时
   * 首帧判定的来源（用户没拨过开关 → 直接用系统值）。
   */
  private static systemDark: boolean = false;

  /* ==================== 系统栏（状态栏 / 导航条）适配 ==================== */

  /** 主窗口引用（EntryAbility.onWindowStageCreate 注入，用于主题切换时反色） */
  private static mainWindow: window.Window | null = null;

  /**
   * 绑定主窗口：系统栏背景透明 + 图标色跟随**应用内**主题。
   * 由 EntryAbility.onWindowStageCreate 调用（必须早于 loadContent，
   * 否则首帧会闪一下系统默认底的白色）。
   */
  static attachWindow(win: window.Window): void {
    ThemeMode.mainWindow = win;
    ThemeMode.applySystemBar(ThemePalette.dark);
  }

  /**
   * 系统栏图标 / 文字反色。
   * ------------------------------------------------------------------
   * ⚠️ 这是「深色模式适配」最容易漏的一环（也是真机上最常见的
   *    「深色模式下状态栏时间/电量看不见」的原因）：
   * 系统只认 module.json5 里的 colorMode 声明，**并不知道**用户在
   * 设置页把界面切成了深色；状态栏图标默认按浅色主题渲染成**深色**。
   * 于是深色界面 + 深色图标 = 状态栏内容「消失」。
   *
   * 因此每次换血都要显式下发 statusBarContentColor /
   * navigationBarContentColor（本 SDK 版本的正确字段，已核对
   * @ohos.window.d.ts 的 SystemBarProperties）。
   */
  private static applySystemBar(dark: boolean): void {
    const w: window.Window | null = ThemeMode.mainWindow;
    if (w === null) {
      return;
    }
    // 深色界面给近白图标，浅色界面给近黑图标（不用纯黑/纯白：
    // 与界面正文同族，避免状态栏比正文更抢眼）
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

  /** 取应用上下文 */
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

  /* ==================== 初始化 ==================== */

  /**
   * 启动时读盘：恢复上次的明暗与画质档位。
   * 由 EntryAbility.onCreate 调用（不阻塞启动流程，失败保持浅色默认）。
   *
   * ⚠️ 本轮加固（用户反馈「深色模式没有适配」，截图证实整个深色套值没被应用）：
   * 早前 try 块把「读盘失败」与「读盘成功但dark=false」混为一谈，
   * 且 catch 里**完全静默**。一旦 `prefs()` 抛错（比如 AppStorage
   * ('appContext') 尚未注入 —— onCreate 里 setOrCreate 与本调用同帧，
   * 跨语言初始化顺序并不可靠），整段换血被跳过，
   * 表现为「设置里明明开了深色，重启后所有页面仍是浅色」，
   * 而且没有任何报错可查。
   *
   * 现在分三步独立处理，每步失败都单独兜底并留日志：
   *   ① 取 preferences（失败 → 只放弃持久化，仍按当前内存态走完流程）
   *   ② 读 dark（失败 → 保持默认浅色）
   *   ③ 读 quality（失败 → 保持默认 CINEMATIC）
   * 关键：③ 失败绝不能连坐 ②，画质与明暗是两个独立开关。
   */
  /**
   * 启动读盘 + 决定首帧明暗。
   * @param systemDark 系统当前是否深色（由 EntryAbility 从
   *        this.context.config.colorMode 读取后传入）。
   *
   * 明暗决策优先级（从高到低）：
   *   ① 内存镜像 memoryDark ≠ null —— 预览器落盘失败时的运行内态，最高优先；
   *   ② 用户手动锁定（KEY_DARK_LOCK=true）—— 以用户选择为准；
   *   ③ 跟随系统 systemDark —— 默认行为，即「深色模式适配」。
   */
  static async init(systemDark: boolean = false): Promise<void> {
    // 广播键先建好：后进入的页面 @StorageProp 才有同步源
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, ThemePalette.dark)
    AppStorage.setOrCreate(ThemeMode.TICK_KEY, 0)

    ThemeMode.systemDark = systemDark

    let p: preferences.Preferences | undefined = undefined;
    try {
      p = await ThemeMode.prefs()
    } catch (err) {
      // 上下文不可用是最可能的失败原因：此时仍要把后续流程走完，
      // 否则 dark/quality 两个开关会一起被跳过（早前就是这个问题）。
      console.warn('[ThemeMode] preferences 不可用，本次启动按内存默认值')
    }

    // ① 内存镜像优先（预览器典型路径：落盘必然失败）
    let dark: boolean;
    if (ThemeMode.memoryDark !== null) {
      dark = ThemeMode.memoryDark;
    } else {
      // ② 用户是否手动锁定过明暗
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
        // ③ 跟随系统：用户从没拨过开关，直接用系统深色状态
        dark = systemDark;
      }
    }
    ThemePalette.applyDark(dark)
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, dark)
    ThemeMode.memoryDark = dark;
    // 系统栏图标色跟上（深色界面必须给近白图标，否则状态栏内容看不见）
    ThemeMode.applySystemBar(dark)

    // ② 画质：与深色**完全独立**，失败绝不能连坐
    let quality: string = GlassLight.quality
    if (p !== undefined) {
      try {
        quality = (await p.get(KEY_QUALITY, GlassQualityLevel.CINEMATIC)) as string
      } catch (err) {
        console.warn('[ThemeMode] 读取 glass_quality 失败，沿用当前档位')
      }
    }
    GlassLight.quality = quality

    // 读盘是异步的：init 完成前可能已有页面用浅色套值建完，
    // 推一次 themeTick 让全部页面按正确配色重建。
    // ⚠️ 无论读盘成功与否都要推：失败时也可能是「内存态已是深色、
    // 但页面用早期浅色值建过」，同样需要一次重建。
    ThemeMode.bumpRender()
  }

  /* ==================== 深色模式 ==================== */

  /** 当前是否深色模式 */
  static isDark(): boolean {
    return ThemePalette.dark
  }

  /**
   * 切换深色模式（设置页开关调用）。
   * 用户手动拨动 = 锁定个人选择：之后不再跟随系统，
   * 避免「系统切回浅色、刚设好的深色又被拉回」。
   */
  static setDark(dark: boolean): void {
    ThemeMode.manualOverride = true
    ThemeMode.persistDark(dark)
    ThemeMode.applyTheme(dark)
  }

  /**
   * 系统深色状态变化（EntryAbility.onConfigurationUpdate 回调）。
   * 仅当**用户没手动锁定**时才跟随系统切换；
   * 已手动锁定（或预览器内存态）则忽略系统变化，保持用户/运行内选择。
   */
  static onSystemColorModeChange(isDark: boolean): void {
    ThemeMode.systemDark = isDark
    if (ThemeMode.manualOverride) return
    if (ThemeMode.memoryDark !== null) return
    ThemeMode.applyTheme(isDark)
  }

  /**
   * 真正执行换血 + 广播（setDark / onSystemColorModeChange 共用）。
   * 值未变化直接返回，避免无谓的全应用重建。
   */
  private static applyTheme(dark: boolean): void {
    if (ThemePalette.dark === dark) return
    ThemePalette.applyDark(dark)
    AppStorage.setOrCreate(ThemeMode.DARK_KEY, dark)
    // 系统栏图标色同步反色：晚一帧都能看见「状态栏闪一下深色图标」
    ThemeMode.applySystemBar(dark)
    ThemeMode.memoryDark = dark
    // 换血后必须广播：static 色值不响应，全靠 themeTick 驱动重建
    ThemeMode.bumpRender()
  }

  /** 反转深色模式 */
  static toggleDark(): void {
    ThemeMode.setDark(!ThemePalette.dark)
  }

  private static async persistDark(dark: boolean): Promise<void> {
    /*
     * ⚠️ 先写内存镜像再落盘（用户反馈「深色模式没有适配」的第三层原因）。
     *
     * 预览器（DevEco Previewer）不提供 Preferences 持久化，`getPreferences`
     * 直接抛错 → persistDark 失败 → 刷新预览器后深色状态**完全丢失**，
     * 于是永远只能看到浅色，真机却可能是好的。这个坑让人误判问题范围。
     *
     * 内存镜像保证：即便落盘失败，**本次运行内**开关依然有效可感知，
     * 只是重启后不保留（真机路径不受影响）。
     */
    ThemeMode.memoryDark = dark;
    try {
      const p: preferences.Preferences = await ThemeMode.prefs()
      await p.put(KEY_DARK, dark)
      // 同时写入「手动锁定」标记：用户拨过开关即视为显式选择，
      // 之后不再被系统深色状态覆盖。
      await p.put(KEY_DARK_LOCK, true)
      await p.flush()
    } catch (err) {
      // 落盘失败不阻塞内存态（预览器必然走这条路径，属预期内）
      console.warn('[ThemeMode] 深色状态仅存于内存（预览器/存储不可用）')
    }
  }

  /* ==================== 玻璃画质 ==================== */

  /** 当前画质档位 */
  static quality(): string {
    return GlassLight.quality
  }

  /** 设置玻璃画质档位（LITE / BALANCED / CINEMATIC） */
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
      // 同上
    }
  }

  /* ==================== 预览器兜底播种 ==================== */

  /**
   * 预览器兜底：在任意页面挂载前，把换肤广播键建好。
   * ------------------------------------------------------------------
   * 预览器（DevEco Previewer）**不执行 UIAbility 生命周期**，
   * EntryAbility.onCreate 里的 ThemeMode.init 永远不会运行，
   * 于是 AppStorage 的 'themeTick' / 'darkMode' 两个广播键无人创建。
   *
   * 各页面靠 @StorageProp('themeTick') 订阅换肤信号：键不存在时，
   * ArkUI 不会建立订阅链路。于是设置页拨动深色开关 → setDark → bumpRender
   * 推了新值，已挂载的页面却收不到通知 —— 表现为「预览器里深色模式没反应」。
   * （真机由 init 在启动期播种，所以正常；问题只在预览器。）
   *
   * 修复：由 @Entry 的 aboutToAppear（预览器里唯一稳定会跑的生命周期）
   * 调本方法补一次，保证键在任意页面挂载前就已存在，订阅链路完整。
   * 与 sessionReady 默认 true 是同一套「预览器不跑 Ability」的兜底思路。
   *
   * 幂等：键已存在则直接返回，绝不重复换血、不覆盖用户已选的明暗。
   *
   * @param systemDark 当前系统（或预览器设备）是否深色。仅在**本进程首次**
   *        调用、且用户从未手动锁定时用于决定首帧明暗；传入后
   *        「预览器设备=深色」的场景初次打开即深色，刷新后也保持一致。
   */
  static ensureInit(systemDark: boolean = false): void {
    if (AppStorage.get<number>(ThemeMode.TICK_KEY) === undefined) {
      AppStorage.setOrCreate(ThemeMode.TICK_KEY, 0)
    }
    if (AppStorage.get<boolean>(ThemeMode.DARK_KEY) === undefined) {
      // 预览器下没跑过 init，ThemePalette 停在浅色初始值（dark=false），
      // 这里照实写入即可；若用户此前已拨过开关，内存态已是 true。
      AppStorage.setOrCreate(ThemeMode.DARK_KEY, ThemePalette.dark)
    }
    // 本进程首次：跟随系统定首帧（memoryDark=null 说明本次运行内
    // 既没跑过 init 也没拨过开关 —— 典型就是预览器刷新后的全新进程）
    if (!ThemeMode.systemApplied) {
      ThemeMode.systemApplied = true
      if (ThemeMode.memoryDark === null && !ThemeMode.manualOverride) {
        ThemeMode.applyTheme(systemDark)
      }
    }
  }

  /* ==================== 重新渲染 ==================== */

  /**
   * 强制全应用重新渲染（设置页「重新渲染」开关的动力源）。
   *
   * 推进 AppStorage('themeTick') 全局序号：所有订阅该键的页面/组件
   * 重建 build()，重新读取 Theme 静态色值与本地数据。
   * 与 EcoMoodState.broadcastDataChange() 的区别：那个只广播数据信号
   * （ecoTick，让各页重拉数据），本方法广播的是「界面重建」信号，
   * 连色值/光照一起刷新。
   */
  static bumpRender(): void {
    const t: number | undefined = AppStorage.get<number>(ThemeMode.TICK_KEY)
    const next: number = (t === undefined || t === null) ? 1 : t + 1
    AppStorage.setOrCreate(ThemeMode.TICK_KEY, next)
  }
}

/*
 * 模块级兜底播种（最后一道防线）。
 * ------------------------------------------------------------------
 * 常规路径：Index.aboutToAppear 调 ensureInit()。
 * 但预览器里用户可以直接预览「非 Index 的页面」作为入口（绕过 Index），
 * 此时 ensureInit 不会运行，@StorageProp('themeTick'/'darkMode') 的
 * 订阅链路在键不存在时建立不起来 → 深色开关推了值却没人收。
 *
 * 这里在模块首次被 import 时（任何页面挂载之前）就尝试把两个广播键建好。
 * 用 try/catch 包裹：预览器早期 AppStorage 未就绪时静默失败，
 * 由 ensureInit 在页面 aboutToAppear 里再兜底一次，绝不拖垮模块导入。
 * setOrCreate 保证不会覆盖已被 init 写好的真实明暗值。
 */
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
