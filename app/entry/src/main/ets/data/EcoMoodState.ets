import { EcoTheme } from '../ui/Theme'
import { LocalStats, LocalStore } from './LocalStore'

const KEY_LEVEL: string = 'ecoLevel'
const KEY_TODAY: string = 'ecoToday'
const KEY_TICK: string = 'ecoTick'
const KEY_OVERRIDE: string = 'ecoOverride'

export class EcoMoodState {
  static readonly QUOTA: number = 5

  static init(): void {
    if (!AppStorage.has(KEY_LEVEL)) {
      AppStorage.setOrCreate<string>(KEY_LEVEL, 'none')
      AppStorage.setOrCreate<number>(KEY_TODAY, 0)
      AppStorage.setOrCreate<number>(KEY_TICK, 0)
      AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    }
  }

  static override(level: string): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, level)
    EcoMoodState.refresh()
  }

  static overrideLevel(): string {
    const v: string | undefined = AppStorage.get<string>(KEY_OVERRIDE)
    return v === undefined ? '' : v
  }

  static reset(): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    AppStorage.setOrCreate<number>(KEY_TODAY, 0)
    AppStorage.setOrCreate<string>(KEY_LEVEL, 'none')
  }

  static resetForAccount(): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    EcoMoodState.refresh()
  }

  static async refresh(): Promise<void> {
    try {
      const s: LocalStats = await LocalStore.stats()
      EcoMoodState.apply(s.todayKg)
    } catch (err) {
      // 存储尚未初始化时忽略
    }
  }

  static apply(todayKg: number): void {
    AppStorage.setOrCreate<number>(KEY_TODAY, todayKg)
    const forced: string = EcoMoodState.overrideLevel()
    const next: string = forced.length > 0
      ? forced
      : EcoTheme.level(todayKg, EcoMoodState.QUOTA)
    const prev: string | undefined = AppStorage.get<string>(KEY_LEVEL)
    if (prev !== next) {
      AppStorage.setOrCreate<string>(KEY_LEVEL, next)
    }
  }

  static bump(): void {
    const t: number | undefined = AppStorage.get<number>(KEY_TICK)
    AppStorage.setOrCreate<number>(KEY_TICK, (t === undefined ? 0 : t) + 1)
  }

  static broadcastDataChange(): void {
    EcoMoodState.bump()
  }

  static level(): string {
    const v: string | undefined = AppStorage.get<string>(KEY_LEVEL)
    return v === undefined ? 'none' : v
  }

  static todayKg(): number {
    const v: number | undefined = AppStorage.get<number>(KEY_TODAY)
    return v === undefined ? 0 : v
  }

  static quotaPct(): number {
    if (EcoMoodState.QUOTA <= 0) return 0
    return Math.min(100, Math.round((EcoMoodState.todayKg() / EcoMoodState.QUOTA) * 100))
  }
}
