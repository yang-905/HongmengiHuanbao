import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration, common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { EcoMoodState } from '../data/EcoMoodState'
import { AccountStore } from '../data/AccountStore'
import { LocalStore } from '../data/LocalStore'
import { ThemeMode } from '../data/ThemeMode'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 供 net/Preferences 等非组件模块获取应用上下文
    AppStorage.setOrCreate('appContext', this.context)
    /*
     * 账号系统提前热启（onCreate 先于 loadContent，首帧前完成同步前缀）：
     * init 的同步前缀会立刻把 sessionReady 置 false，读盘（账号表/上次会话）
     * 完成后再置 true —— 保证 Index 首帧拿到的是真实会话态，
     * 不会先闪一下登录页再跳主界面。loadContent 回调里的完整启动链
     * 会再次调用 init()，inited_ 守卫使它变成幂等空跑，无副作用。
     */
    AccountStore.init().catch((err: Object): void => {
      // 存储不可用：init 内部已兜底，这里仅防未处理拒绝
    })
    // 碳情绪全局状态初始化：先占位再求值，
    // 这样首个页面创建时就能拿到初始档位，不会先闪一下默认色
    EcoMoodState.init()
    // 深色模式读盘换血：传入系统当前深色状态作为默认（跟随系统），
    // 异步不阻塞启动，完成后 bump themeTick 让可能已用浅色套值建完的
    // 页面按正确配色重建
    ThemeMode.init(this.systemInDarkMode())
  }

  /**
   * 读取系统当前是否处于深色模式。
   * ------------------------------------------------------------------
   * 这是「深色模式适配」的关键数据源：当用户**从没在设置页拨过开关**时，
   * app 直接采用系统深色状态（系统深 → app 深），而不是自己默认浅色。
   * 早前 app 只认自身持久化偏好（默认浅色）、从不读系统 colorMode，
   * 于是「系统已是深色、app 仍是浅色」——正是用户说的「深色模式没适配」。
   *
   * 任何读取异常都回退浅色，绝不阻塞启动。
   */
  private systemInDarkMode(): boolean {
    try {
      const ctx: common.UIAbilityContext = this.context as common.UIAbilityContext
      const cfg: Configuration | undefined = ctx.config
      if (cfg !== undefined && cfg !== null && cfg.colorMode !== undefined) {
        return cfg.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      }
    } catch (err) {
      console.warn('[EntryAbility] 读取系统 colorMode 失败，按浅色启动')
    }
    return false
  }

  /**
   * 系统配置变化（含深色模式切换）。
   * ------------------------------------------------------------------
   * 用户在系统设置里切深/浅色、或应用自身 colorMode=auto 时，
   * 系统会回调这里。只要用户没在 app 内手动锁定明暗，
   * 就实时跟随系统切换 app 主题（含换血 + 全局重建）。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig !== undefined && newConfig !== null && newConfig.colorMode !== undefined) {
      const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      ThemeMode.onSystemColorModeChange(isDark)
    }
  }

  onDestroy(): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    /*
     * 系统栏透明化（必须在 loadContent 之前，否则首帧会闪一下白）
     * ------------------------------------------------------------------
     * 现象：屏幕最底部一条纯白 #FFFFFF 的带子，所有页面都有
     * （记录/科普最明显，因为它们的底部导航胶囊位置略高；
     *   主页/我的其实也有，只是被导航盖住不易察觉）。
     *
     * 取证：像素扫描确认白带 = (255,255,255) 纯白，
     * 而浅色档根底色是 #FBF8F3、任何主题令牌都不是纯白 ——
     * 说明这块区域根本没被页面根容器绘制到，露的是**系统窗口底色**。
     *
     * 关键：只加 expandSafeArea 不够。那只让组件的**绘制区域**延伸进
     * 安全区，系统导航条本身仍是不透明的，会照旧盖在根底色上面。
     * 必须先在窗口层把系统栏背景设为透明（#00000000 = 全透明），
     * 两者配合才彻底消除白带。
     */
    windowStage.getMainWindow().then((mainWindow: window.Window): void => {
      /*
       * ⚠️ 深色模式的系统侧声明放在 module.json5 的 metadata
       * （ohos.extension.colorMode = dark）。
       *
       * 本项目**刻意不在运行时切系统色彩模式**（无 window.setColorMode，
       * 该 SDK 版本也不存在 updateColorMode），原因有二：
       *   ① 本应用是**应用内开关 + 持久化**（设置页手动切换），
       *      色彩基准完全由 ThemePalette.applyDark 自控；
       *   ② 若跟随系统深色，会与设置页开关**分裂** ——
       *      「系统深色 + 应用浅色」时页面底色与系统状态栏打架。
       * 所以深浅完全自洽，运行期只需要 metadata 声明能力 +
       * 状态栏/导航条背景透明 + **图标色跟随应用内主题**（后者是关键：
       * 系统不知道我们应用内切了深色，不显式下发图标色就会出现
       * 「深色界面 + 深色状态栏图标 = 时间/电量看不见」）。
       * 这两件事统一由 ThemeMode.attachWindow 负责（背景透明 + 图标反色），
       * 主题切换时 ThemeMode.setDark 会再次下发。
       */
      ThemeMode.attachWindow(mainWindow)
    }).catch((err: Object): void => {
      // 窗口 API 失败不阻塞启动：页面仍可正常显示，只是安全区可能露底
    })

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return
      }
      // 启动链顺序（多账号口径）：
      //   ① AccountStore.init：恢复账号表 + 上次会话，
      //      有会话则内部先把 LocalStore 切到该账号的数据命名空间
      //   ② LocalStore.init：无会话时加载未登录（旧数据兼容）命名空间
      //   ③ EcoMoodState.refresh：LocalStore 就绪后算全局碳档位，
      //      驱动所有页面背景与组件配色过渡
      // 最后推 sessionReady：登录闸门才开始依据会话分流（防止闪错屏）
      AccountStore.init().then((): Promise<void> => {
        return LocalStore.init()
      }).then((): void => {
        EcoMoodState.refresh()
      }).catch((err: Object): void => {
        // 存储不可用时保持默认档位与未登录态，不阻塞启动
      })
    })
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
    // 回到前台：日期可能已跨天，重新判档以免沿用昨天的档位
    EcoMoodState.refresh()
  }

  onBackground(): void {
  }
}