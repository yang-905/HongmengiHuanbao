/**
 * 账号系统：注册 / 登录 / 会话 / 个人资料 / 多账号数据隔离
 * ------------------------------------------------------------------
 * 单机版口径（与 LocalStore / ThemeMode 同策略）：
 *   · 内存是权威态，Preferences 是 best-effort 持久化 ——
 *     预览器（Previewer）不提供 Preferences，getPreferences 直接抛错，
 *     因此所有落盘调用都必须 try/catch，失败时仅退化为「运行内有效」，
 *     绝不阻塞登录/注册主流程（真机路径不受影响）。
 *   · 与 LocalStore 共用同一个 Preferences 文件（STORE='yichu_qinglv'），
 *     账号侧使用 acct_* 前缀键，与业务数据键互不重叠。
 *
 * 密码安全（演示级）：不存明文，存「盐 + FNV/xorshift 混淆哈希」。
 * 这是单机演示应用能做的最低限度防护（防肉眼翻库），不是加密学保证。
 *
 * 多账号数据隔离原理（与 LocalStore.switchUser 配合）：
 *   登录/注册成功 → setSession → LocalStore.switchUser(user) 把行为记录
 *   键空间切到 'local_records@<user>'；注销/切换账号 → Index 登录闸门
 *   整树重建 → 各页面 aboutToAppear 重跑 → 读到的都是新账号命名空间。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LocalStore, DEV_USER } from './LocalStore'
import { EcoMoodState } from './EcoMoodState'
import { AppClock } from '../utils/AppClock'

/** Preferences 文件名（与 LocalStore / ThemeMode 一致，同库不同键） */
const STORE: string = 'yichu_qinglv'
/** 账号注册表键（JSON 数组） */
const KEY_ACCOUNTS: string = 'acct_list'
/** 当前会话键（登录中的账号名） */
const KEY_SESSION: string = 'acct_session'
/** 个人资料键前缀：'acct_profile:<user>' 每账号一份 */
const KEY_PROFILE_PREFIX: string = 'acct_profile:'

/**
 * 个人资料（头像 / 名字 / 性别 / 手机号选填）。
 * 头像用 emoji 占位（本应用视觉语言即 emoji 圆盘，无图片资源依赖）。
 */
export class UserProfile {
  avatar: string = '🌱'
  name: string = ''
  // 性别默认空：注册后首次完善资料为强制选择项（男/女/保密三选一）
  gender: string = ''
  phone: string = ''
}

/** 账号条目（注册表最小字段） */
class Account {
  user: string = ''
  passHash: string = ''
  createdAt: string = ''
}

export class AccountStore {
  /** 会话账号在 AppStorage 里的键（Index 登录闸门据此翻转） */
  static readonly SESSION_KEY: string = 'sessionUser'
  /** 启动同步完成标记：true 后闸门才依据 sessionUser 分流，防止闪错屏 */
  static readonly READY_KEY: string = 'sessionReady'
  /** 资料变更信号：ProfilePage 保存后 +1，MinePage/Settings 据此重读 */
  static readonly PROFILE_TICK_KEY: string = 'profileTick'

  /** 账号注册表（内存权威态） */
  private static accounts_: Account[] = []
  /** 各账号资料缓存（内存权威态） */
  private static profiles_: Record<string, UserProfile> = {}
  /** 当前会话（内存权威态） */
  private static session_: string = ''
  /** init 只执行一次 */
  private static inited_: boolean = false

  /* ==================== 初始化 ==================== */

  /**
   * 启动读盘：恢复账号表 + 上次会话。
   * 由 EntryAbility 在 LocalStore.init **之前**调用 ——
   * 会话决定 LocalStore 切到哪个账号的数据命名空间。
   */
  static async init(): Promise<void> {
    if (AccountStore.inited_) return
    AccountStore.inited_ = true
    // 先把三个广播键占好位：后建的组件 @StorageLink 才有同步源
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, '')
    AppStorage.setOrCreate(AccountStore.READY_KEY, false)
    AppStorage.setOrCreate(AccountStore.PROFILE_TICK_KEY, 0)
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      const listJson: string = (await p.get(KEY_ACCOUNTS, '')) as string
      if (listJson.length > 0) {
        const arr: Account[] = JSON.parse(listJson) as Account[]
        if (arr !== undefined && arr !== null) {
          AccountStore.accounts_ = arr
        }
      }
      const sess: string = (await p.get(KEY_SESSION, '')) as string
      // 只恢复注册表里真实存在的会话（防脏数据）
      if (sess.length > 0 && AccountStore.indexOfUser(sess) >= 0) {
        await AccountStore.loadProfile(sess)
        AccountStore.session_ = sess
        // 行为数据命名空间跟上会话（开发者账号灌演示数据，注册账号空数据）
        await LocalStore.switchUser(sess)
      }
    } catch (err) {
      // 存储不可用（预览器典型路径）：空账号表起步，登录页照常可用
    }
    // 开发者模式内置账号：登录 '1' 即开发者模式（其数据命名空间保留
    // 完整演示数据，供开发调试对照；普通注册账号一律空数据起步）。
    // 放在 try/catch 之外：预览器读盘失败也保证开发者账号可用。
    // 密码明文只在此处参与哈希，不落盘。
    if (AccountStore.indexOfUser(DEV_USER) < 0) {
      const dev: Account = new Account()
      dev.user = DEV_USER
      dev.passHash = AccountStore.hashOf(DEV_USER, '12345678any')
      dev.createdAt = '内置开发者'
      AccountStore.accounts_.push(dev)
      // ⚠️ 落盘单独兜底：这是全库唯一无守卫的 Preferences 写路径。
      // 预览器不跑 UIAbility 生命周期（appContext 缺失），getPreferences
      // 直接抛「Preferences.getData is not supported on all devices」；
      // init() 又会被 login/register 入口在预览器调用，异常逃逸即成
      // 未捕获 rejection —— 表现为预览器红条崩溃（账号 push 保留在
      // try 外，落盘失败不影响开发者账号可用性）。
      try {
        await AccountStore.persistAccounts()
      } catch (err) {
        // 存储不可用（预览器典型路径）：内存账号表已就绪，忽略落盘失败
      }
    }
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, AccountStore.session_)
    AppStorage.setOrCreate(AccountStore.READY_KEY, true)
  }

  /* ==================== 校验 ==================== */

  /** 账号规则：trim 后非空、不含空格、最长 20 字符 */
  static validateAccount(user: string): string {
    const u: string = user.trim()
    if (u.length === 0) return '账号不能为空'
    if (u.indexOf(' ') >= 0) return '账号不能包含空格'
    if (u.length > 20) return '账号最长 20 个字符'
    return ''
  }

  /**
   * 密码规则：至少 8 位、仅字母和数字、须同时包含字母与数字。
   * 返回空串表示通过，否则返回可直接展示的错误文案。
   */
  static validatePassword(pass: string): string {
    if (pass.length === 0) return '请输入密码'
    // 报错带上当前已输入位数，提示能对上账
    if (pass.length < 8) return '密码至少 8 位（当前输入 ' + pass.length + ' 位）'
    let hasLetter: boolean = false
    let hasDigit: boolean = false
    for (let i = 0; i < pass.length; i++) {
      const ch: string = pass.charAt(i)
      const letter: boolean = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
      const digit: boolean = ch >= '0' && ch <= '9'
      if (!letter && !digit) return '密码只能包含字母和数字'
      if (letter) hasLetter = true
      if (digit) hasDigit = true
    }
    if (!hasLetter || !hasDigit) return '密码需同时包含字母和数字'
    return ''
  }

  /* ==================== 注册 / 登录 / 注销 ==================== */

  /**
   * 注册新账号（成功后自动登录）。
   * @return 空串 = 成功；否则为可直接 toast 的错误文案
   */
  static async register(user: string, pass: string): Promise<string> {
    await AccountStore.init() // 同 login：预览器无启动链，入口兜底（幂等）
    let e: string = AccountStore.validateAccount(user)
    if (e.length > 0) return e
    e = AccountStore.validatePassword(pass)
    if (e.length > 0) return e
    const u: string = user.trim()
    if (AccountStore.indexOfUser(u) >= 0) return '该账号已被注册，可直接登录'
    const acc: Account = new Account()
    acc.user = u
    acc.passHash = AccountStore.hashOf(u, pass)
    acc.createdAt = AccountStore.nowText()
    AccountStore.accounts_.push(acc)
    await AccountStore.persistAccounts()
    // 默认资料整体留空（头像除外）：注册成功后强制弹出资料页，
    // 昵称与性别为必填项（LoginGate 打 pendingProfileSetup 标记驱动）
    const def: UserProfile = new UserProfile()
    AccountStore.profiles_[u] = def
    await AccountStore.persistProfile(u)
    await AccountStore.setSession(u)
    return ''
  }

  /** 登录已有账号。@return 空串 = 成功；否则为错误文案 */
  static async login(user: string, pass: string): Promise<string> {
    // 兜底自愈：预览器不执行 UIAbility 生命周期，EntryAbility 启动链不跑，
    // 开发者内置账号/账号表可能尚未初始化 —— 在登录/注册入口补一次 init
    //（inited_ 守卫保证幂等：真机上已初始化则直接返回）
    await AccountStore.init()
    const e: string = AccountStore.validateAccount(user)
    if (e.length > 0) return e
    if (pass.length === 0) return '请输入密码'
    const u: string = user.trim()
    const idx: number = AccountStore.indexOfUser(u)
    if (idx < 0) return '账号不存在，请先注册'
    if (AccountStore.accounts_[idx].passHash !== AccountStore.hashOf(u, pass)) {
      return '密码不正确，请重新输入'
    }
    await AccountStore.setSession(u)
    return ''
  }

  /** 注销当前会话（行为数据留在本机原命名空间，重新登录即恢复） */
  static async logout(): Promise<void> {
    AccountStore.session_ = ''
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, '')
    /*
     * 碳情绪回初始档（用户反馈「切换账号后碳情绪颜色不会切换回初始颜色」）：
     * 未登录 = 无数据语境，登录页应呈中性底色；否则登录页的品牌渐变/
     * 背景会停留在旧账号的情绪档位上（如旧账号记录了高碳行为 = 全屏红）。
     * 与 Index 的 onSessionUser 双保险，都做且幂等。
     */
    EcoMoodState.reset()
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      await p.put(KEY_SESSION, '')
      await p.flush()
    } catch (err) {
      // 预览器/存储不可用：内存态注销即可
    }
  }

  /* ==================== 会话 / 资料 读 ==================== */

  /** 当前登录账号（未登录为空串） */
  static currentUser(): string {
    return AccountStore.session_
  }

  /** 已注册账号名列表（登录页快捷切换 chips 用） */
  static accountNames(): string[] {
    const out: string[] = []
    for (let i = 0; i < AccountStore.accounts_.length; i++) {
      out.push(AccountStore.accounts_[i].user)
    }
    return out
  }

  /**
   * 取某账号的资料（同步，读内存缓存；未缓存过则给默认资料）。
   * 默认资料：头像 🌱、名字 = 账号名、性别保密、手机号空。
   */
  static profileOf(user: string): UserProfile {
    const p: UserProfile | undefined = AccountStore.profiles_[user]
    if (p !== undefined && p !== null) return p
    const def: UserProfile = new UserProfile()
    def.name = user
    return def
  }

  /* ==================== 会话 / 资料 写 ==================== */

  /** 保存资料（内存 + 落盘 + 广播 profileTick） */
  static async saveProfile(user: string, prof: UserProfile): Promise<void> {
    if (user.length === 0) return
    AccountStore.profiles_[user] = prof
    await AccountStore.persistProfile(user)
    const t: number | undefined = AppStorage.get<number>(AccountStore.PROFILE_TICK_KEY)
    const next: number = (t === undefined || t === null) ? 1 : t + 1
    AppStorage.setOrCreate(AccountStore.PROFILE_TICK_KEY, next)
  }

  /**
   * 是否图片头像：本地相册上传的图片存应用沙箱，avatar 记 'file://<沙箱路径>'；
   * 非 file:// 开头的一律按 emoji 文本渲染。
   */
  static isImageAvatar(a: string): boolean {
    return a.length > 7 && a.indexOf('file://') === 0
  }

  /** 建立会话：加载资料 → 切换数据命名空间 → 重算碳情绪 → 广播闸门 */
  private static async setSession(user: string): Promise<void> {
    AccountStore.session_ = user
    await AccountStore.loadProfile(user)
    await LocalStore.switchUser(user)
    /*
     * 碳情绪必须在这里显式重算（用户反馈「切换账号后碳情绪颜色不重置」）：
     * switchUser 内部的 EcoMoodState.bump() 只递增 ecoTick，而此刻
     * 登录闸门还没翻转、业务页面全部未挂载 —— 广播没有订阅者，
     * 随后挂载的页面把已递增的值当初始值，@Watch 根本不触发；
     * 页面挂载后的 load() 也只拉业务数据，没人调 refresh()。
     * 结果：AppStorage('ecoLevel') 停留在旧账号档位，全应用配色不换。
     * resetForAccount = 清调试强制档位 + 按新命名空间真实数据判档。
     */
    EcoMoodState.resetForAccount()
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, user)
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      await p.put(KEY_SESSION, user)
      await p.flush()
    } catch (err) {
      // 预览器：会话仅运行内有效
    }
  }

  /** 从磁盘拉某账号资料进内存缓存；无记录则建默认资料 */
  private static async loadProfile(user: string): Promise<void> {
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      const json: string = (await p.get(KEY_PROFILE_PREFIX + user, '')) as string
      if (json.length > 0) {
        const prof: UserProfile = JSON.parse(json) as UserProfile
        if (prof !== undefined && prof !== null) {
          AccountStore.profiles_[user] = prof
          return
        }
      }
    } catch (err) {
      // 读盘失败走默认资料
    }
    if (AccountStore.profiles_[user] === undefined) {
      const def: UserProfile = new UserProfile()
      def.name = user
      AccountStore.profiles_[user] = def
    }
  }

  private static async persistProfile(user: string): Promise<void> {
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      await p.put(KEY_PROFILE_PREFIX + user, JSON.stringify(AccountStore.profiles_[user]))
      await p.flush()
    } catch (err) {
      // 预览器：资料仅运行内有效
    }
  }

  private static async persistAccounts(): Promise<void> {
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      await p.put(KEY_ACCOUNTS, JSON.stringify(AccountStore.accounts_))
      await p.flush()
    } catch (err) {
      // 预览器：账号表仅运行内有效
    }
  }

  /* ==================== 内部工具 ==================== */

  private static indexOfUser(user: string): number {
    for (let i = 0; i < AccountStore.accounts_.length; i++) {
      if (AccountStore.accounts_[i].user === user) return i
    }
    return -1
  }

  /**
   * 演示级口令混淆：账号名作盐 + xorshift 混淆，输出 8 位十六进制。
   * 不存明文；单机演示场景够用（防肉眼翻库），非加密学保证。
   */
  private static hashOf(user: string, pass: string): string {
    const salted: string = 'yichu#v1#' + user + '#' + pass
    let h: number = 0x9e3779b9
    for (let i = 0; i < salted.length; i++) {
      h ^= salted.charCodeAt(i)
      h = (h ^ (h << 13)) >>> 0
      h = (h ^ (h >>> 17)) >>> 0
      h = (h ^ (h << 5)) >>> 0
    }
    let s: string = h.toString(16)
    while (s.length < 8) {
      s = '0' + s
    }
    return s
  }

  private static nowText(): string {
    // 时间口径（本地时间校准，见 AppClock）：账号创建时间与业务数据同源
    return AppClock.dateTimeStr()
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
      return await preferences.getPreferences(AccountStore.ctx(), STORE)
    } catch (err) {
      throw new Error('本机存储不可用')
    }
  }
}
