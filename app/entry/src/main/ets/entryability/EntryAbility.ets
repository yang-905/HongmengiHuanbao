import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration, common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { EcoMoodState } from '../data/EcoMoodState'
import { AccountStore } from '../data/AccountStore'
import { LocalStore } from '../data/LocalStore'
import { ThemeMode } from '../data/ThemeMode'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate('appContext', this.context)
    AccountStore.init().catch((err: Object): void => {
      // init 内部已兜底，这里仅防未处理拒绝
    })
    EcoMoodState.init()
    ThemeMode.init(this.systemInDarkMode())
  }

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

  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig !== undefined && newConfig !== null && newConfig.colorMode !== undefined) {
      const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      ThemeMode.onSystemColorModeChange(isDark)
    }
  }

  onDestroy(): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((mainWindow: window.Window): void => {
      ThemeMode.attachWindow(mainWindow)
    }).catch((err: Object): void => {
      // 窗口 API 失败不阻塞启动
    })

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return
      }
      AccountStore.init().then((): Promise<void> => {
        return LocalStore.init()
      }).then((): void => {
        EcoMoodState.refresh()
      }).catch((err: Object): void => {
        // 存储不可用时保持默认档位与未登录态
      })
    })
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
    // 回到前台可能已跨天，重新判档
    EcoMoodState.refresh()
  }

  onBackground(): void {
  }
}
