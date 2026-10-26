/**
 * 全局碳情绪状态（动态视觉主题的唯一数据源）
 * ------------------------------------------------------------------
 * 需求：所有一级/二级/三级页面的背景与组件配色，都随「当日碳排放」动态变化。
 *
 * 为什么必须做成全局单例，而不是每个页面自己判档：
 *   · 页面有 27 个，若各自调 LocalStore.stats() 判档，
 *     每进一页都多一次存储读取，且各页面档位可能短暂不一致
 *     （用户会看到「上一页是绿色、下一页变黄」的跳变）；
 *   · AppStorage 的 @StorageLink/@StorageProp 是响应式的：
 *     任意一处调用 refresh()，所有订阅页面/组件自动重渲染并做颜色过渡。
 *
 * 用法：
 *   // 1) 页面/组件里声明响应式链接
 *   @StorageLink('ecoLevel') level: string = 'none'
 *   // 2) 直接消费
 *   .backgroundColor(EcoTheme.bg(this.level))
 *   // 3) 数据变化后刷新
 *   EcoMoodState.refresh()
 */
import { EcoTheme } from '../ui/Theme'
import { LocalStats, LocalStore } from './LocalStore'

/** AppStorage 键：当前碳情绪档位 */
const KEY_LEVEL: string = 'ecoLevel'

/** AppStorage 键：今日碳排放量（供页面显示环形进度等） */
const KEY_TODAY: string = 'ecoToday'

/**
 * 记录变更信号（自增序号）。
 *
 * LocalStore 写入/删除记录后 bump 它，页面订阅 `@StorageLink('ecoTick')`
 * 即可在「记完行为切回来」时立刻重算档位。
 *
 * 为什么用信号而不是回调注入：ArkTS 严格模式禁止把函数类型用作
 * 字段/参数类型（见 DeviceKit.ets 的历史教训）。
 */
const KEY_TICK: string = 'ecoTick'

/**
 * 调试用强制档位。
 * '' 表示跟随真实判档（正常状态）；非空则强制覆盖，用于验证各档配色适配。
 * 由设置页的隐藏调试面板写入（见 EcoDebugSheet）。
 */
const KEY_OVERRIDE: string = 'ecoOverride'

export class EcoMoodState {
  /** 每日碳预算（kg CO₂e）：约一餐含荤正餐的碳足迹量级 */
  static readonly QUOTA: number = 5

  /**
   * 初始化：在 EntryAbility 启动时调用一次。
   * 提前把值塞进 AppStorage，页面创建时就能拿到初始档位，
   * 避免「先进页面显示默认灰、再跳变成绿」的闪烁。
   */
  static init(): void {
    if (!AppStorage.has(KEY_LEVEL)) {
      /*
       * ⚠️ 必须用 setOrCreate 而不是 set：set 对不存在的键**静默无效**
       * （本项目 PageMap 传参踩过同款坑）。本方法只在 EntryAbility 启动链
       * 被调用 —— 预览器不跑 UIAbility，这里根本不执行，键的创建只能靠
       * 各页 @StorageLink 的挂载顺序兜底；万一 bump() 先于某个链接挂载
       * 被调用，set 会把首次广播整个吞掉，记录页就「录入后不同步」。
       * setOrCreate 在键已存在时语义与 set 完全一致，缺失时补建，无副作用。
       */
      AppStorage.setOrCreate<string>(KEY_LEVEL, 'none')
      AppStorage.setOrCreate<number>(KEY_TODAY, 0)
      AppStorage.setOrCreate<number>(KEY_TICK, 0)
      AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    }
  }

  /**
   * 调试：强制指定档位（传 '' 恢复自动判档）。
   * 立即重算并广播，无需重启应用。
   */
  static override(level: string): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, level)
    // 异步重算：本方法保持同步签名（调用方是调试面板的同步回调），
    // Promise 浮动不阻塞 UI；判档结果由 apply() 写回响应式键。
    EcoMoodState.refresh()
  }

  /** 当前强制档位；'' 表示自动 */
  static overrideLevel(): string {
    const v: string | undefined = AppStorage.get<string>(KEY_OVERRIDE)
    return v === undefined ? '' : v
  }

  /**
   * 注销 / 切换账号时的碳情绪重置。
   * ------------------------------------------------------------------
   * 未登录 = 无数据语境：清掉调试强制档位，档位与今日碳量回到初始值，
   * 登录页（LoginGate）呈中性底色。
   *
   * 背景（用户实测反馈「记录过碳情绪变色后，切换账号碳情绪颜色不会
   * 切换回初始颜色」）：旧口径注销只翻转 sessionUser，ecoLevel 停留
   * 在旧账号的档位上 —— 登录页背景/品牌渐变全是旧账号的情绪色。
   */
  static reset(): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    AppStorage.setOrCreate<number>(KEY_TODAY, 0)
    AppStorage.setOrCreate<string>(KEY_LEVEL, 'none')
  }

  /**
   * 登录 / 注册 / 恢复会话后的碳情绪重算。
   * ------------------------------------------------------------------
   * 两件事必须一起做，缺一不可（同一则用户反馈的两条路径）：
   *   ① ecoOverride 是**全局**调试强制档位，不随账号携带 ——
   *      不清掉的话换账号后档位仍被旧强制值把持，永远「不变色」；
   *   ② switchUser 内部的 EcoMoodState.bump() 只递增 ecoTick，
   *      而彼时登录闸门尚未翻转、业务页面全部未挂载，广播被吞
   *      （没有订阅者，新挂载的页面把已递增的值当初始值，不触发
   *      @Watch），页面挂载后也没有任何人重算档位 ——
   *      AppStorage('ecoLevel') 就这么留在旧账号的档位上。
   * 这里显式 refresh：清 override 后按新命名空间的真实数据判档。
   */
  static resetForAccount(): void {
    AppStorage.setOrCreate<string>(KEY_OVERRIDE, '')
    EcoMoodState.refresh()
  }

  /**
   * 重算并广播档位。
   * ------------------------------------------------------------------
   * 2026-10-23 RDB 化后改为异步：当日统计改由 LocalStore.stats()
   * 从 SQLite 聚合查询按需得出（不再有内存全量副本），查询是 Promise。
   * 调用方无需改动 —— 本方法返回的 Promise 可以浮动（不 await 也不报错），
   * 判档结果由 apply() 写回响应式键，档位一变全应用自动重渲染。
   * ⚠️ 唯一注意：EntryAbility 启动链里它是 .then() 的一环，
   *    那里保持「不 await」语义即可（首帧档位允许晚一帧到位）。
   *
   * 调用时机：EntryAbility 启动 / 任意页面 load() 完成后 / 记录写入后。
   */
  static async refresh(): Promise<void> {
    try {
      const s: LocalStats = await LocalStore.stats()
      EcoMoodState.apply(s.todayKg)
    } catch (err) {
      // 存储尚未初始化时忽略：保持默认档位，等首次 refresh
    }
  }

  /**
   * 以指定碳量更新档位。
   *
   * 调试覆盖优先级：若设置了 ecoOverride，则**直接采用强制档位**，
   * 忽略真实判档结果。这样既保留完整的判档逻辑（切回「自动」立即恢复），
   * 又能强制预览任意档位来验证配色适配。
   *
   * ⚠️ 递归陷阱（本轮修复，用户反馈「科普页 UI 没随碳行为动态变换」）：
   * 本方法早前在末尾调用 `EcoMoodState.bump()`，而调用链是
   *   refresh() → apply() → bump() → AppStorage 写 ecoTick
   *     → 各页 onStorageChange('ecoTick') → EcoMoodState.refresh() → ……
   * 形成**无限递归**。ArkTS 的 AppStorage 写入是同步的，递归会真的压栈：
   *   · 首页 / 科普页等页面在递归的不同深度被重建，各自读到的
   *     `ecoLevel` 可能来自递归中的**中间态**；
   *   · 像素取证（用户截图）：同一屏内首页卡片是绿色（eco 档），
   *     而科普页根底却是 (254,243,241) = ALERT_SOLID（alert 档）——
   *     同一份AppStorage 出现两个档位，正是递归重入的证据。
   *
   * 现在 apply() **不再 bump**：它的职责只有一个 ——「按碳量算档位并写入
   * KEY_LEVEL」。KEY_LEVEL 本身就是响应式的（各页 `@StorageProp('ecoLevel')`
   * 直接订阅），档位一变全应用自动重渲染，不需要额外信号。
   * 「数据变了请重新拉数据」是**另一件事**，由 broadcastDataChange() 负责，
   * 两者本就不该耦合。
   */
  static apply(todayKg: number): void {
    // setOrCreate：键缺失（预览器 init 未跑）时补建，set 会静默丢值
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

  /** 递增记录变更信号 */
  static bump(): void {
    const t: number | undefined = AppStorage.get<number>(KEY_TICK)
    /*
     * ⚠️ setOrCreate 而非 set（2026-10-20 修复「录入后记录页不同步」）：
     * set 对不存在的键静默无效。'ecoTick' 键在预览器里没有 EntryAbility
     * 的 init() 预创建，只能靠记录页 @StorageLink 挂载顺带创建 —— 若
     * bump 先于挂载被调用（录入弹窗挂在 Index 层，时序不保证），
     * 首次广播整个被吞，页面的 @Watch 永远不触发，表现就是
     * 「加了记录，记录页纹丝不动」。
     */
    AppStorage.setOrCreate<number>(KEY_TICK, (t === undefined ? 0 : t) + 1)
  }

  /**
   * 广播「数据已变更，请重新拉取」。
   *
   * 背景：项目里曾并存两套信号，互不相通 ——
   *   · `dataVersion`：录入/备份恢复时广播，但**只有注释提到，无人监听**（死信）
   *   · `ecoTick`：27 个页面在监听，但只用于重算碳档位，**不触发重新拉数据**
   * 结果就是：预览器里记录完新行为，切到别的页面仍显示旧数据。
   *
   * ⚠️⚠️ 真正的断点（2026-10-19 定位，用户反馈「记录完还要手动刷新」）：
   * 页面上写的 `onStorageChange(key: string)` **不是 ArkUI 生命周期**，
   * SDK d.ts 里根本没有这个回调，框架永远不会调用它 ——
   * `@StorageLink('ecoTick')` 只让组件重建，重建时用的还是旧数据，
   * 所以「记完一笔 → 列表不动 → 必须手动刷新」。
   *
   * 正确接法（全库 31 个页面已统一）：
   *   @StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0
   *   onEcoTick(): void { this.onStorageChange('ecoTick') }
   * 即：用官方支持的 @Watch 把「响应式变量变化」接到已有的处理函数上。
   *
   * 链路：写入方 → broadcastDataChange() → bump() → AppStorage('ecoTick')+1
   *       → 各页 @Watch → 重算碳档位（refresh）+ 重新 load() 数据。
   */
  static broadcastDataChange(): void {
    EcoMoodState.bump()
  }

  /** 当前档位（非响应式，仅供逻辑判断；UI 请用 @StorageLink） */
  static level(): string {
    const v: string | undefined = AppStorage.get<string>(KEY_LEVEL)
    return v === undefined ? 'none' : v
  }

  /** 今日碳排放量 */
  static todayKg(): number {
    const v: number | undefined = AppStorage.get<number>(KEY_TODAY)
    return v === undefined ? 0 : v
  }

  /** 今日碳预算消耗百分比（0~100，超额时封顶 100） */
  static quotaPct(): number {
    if (EcoMoodState.QUOTA <= 0) return 0
    return Math.min(100, Math.round((EcoMoodState.todayKg() / EcoMoodState.QUOTA) * 100))
  }
}