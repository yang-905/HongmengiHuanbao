/** 账号系统：注册 / 登录 / 会话 / 多账号数据隔离 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LocalStore, DEV_USER } from './LocalStore'
import { EcoMoodState } from './EcoMoodState'
import { AppClock } from '../utils/AppClock'

const STORE: string = 'yichu_qinglv'
const KEY_ACCOUNTS: string = 'acct_list'
const KEY_SESSION: string = 'acct_session'
const KEY_PROFILE_PREFIX: string = 'acct_profile:'

/** 个人资料 */
export class UserProfile {
  avatar: string = '🌱'
  name: string = ''
  gender: string = ''
  phone: string = ''
}

class Account {
  user: string = ''
  passHash: string = ''
  createdAt: string = ''
}

export class AccountStore {
  static readonly SESSION_KEY: string = 'sessionUser'
  static readonly READY_KEY: string = 'sessionReady'
  static readonly PROFILE_TICK_KEY: string = 'profileTick'

  private static accounts_: Account[] = []
  private static profiles_: Record<string, UserProfile> = {}
  private static session_: string = ''
  private static inited_: boolean = false

  /** 启动读盘：恢复账号表 + 上次会话 */
  static async init(): Promise<void> {
    if (AccountStore.inited_) return
    AccountStore.inited_ = true
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
      if (sess.length > 0 && AccountStore.indexOfUser(sess) >= 0) {
        await AccountStore.loadProfile(sess)
        AccountStore.session_ = sess
        await LocalStore.switchUser(sess)
      }
    } catch (err) {
      // 存储不可用（预览器典型路径）：空账号表起步
    }
    // 开发者模式内置账号
    if (AccountStore.indexOfUser(DEV_USER) < 0) {
      const dev: Account = new Account()
      dev.user = DEV_USER
      dev.passHash = AccountStore.hashOf(DEV_USER, '12345678any')
      dev.createdAt = '内置开发者'
      AccountStore.accounts_.push(dev)
      try {
        await AccountStore.persistAccounts()
      } catch (err) {
        // 存储不可用：内存账号表已就绪
      }
    }
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, AccountStore.session_)
    AppStorage.setOrCreate(AccountStore.READY_KEY, true)
  }

  /** 账号规则：trim 后非空、不含空格、最长 20 字符 */
  static validateAccount(user: string): string {
    const u: string = user.trim()
    if (u.length === 0) return '账号不能为空'
    if (u.indexOf(' ') >= 0) return '账号不能包含空格'
    if (u.length > 20) return '账号最长 20 个字符'
    return ''
  }

  /** 密码规则：至少 8 位、仅字母和数字、须同时包含字母与数字 */
  static validatePassword(pass: string): string {
    if (pass.length === 0) return '请输入密码'
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

  /** 注册新账号（成功后自动登录），空串 = 成功 */
  static async register(user: string, pass: string): Promise<string> {
    await AccountStore.init()
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
    const def: UserProfile = new UserProfile()
    AccountStore.profiles_[u] = def
    await AccountStore.persistProfile(u)
    await AccountStore.setSession(u)
    return ''
  }

  /** 登录已有账号，空串 = 成功 */
  static async login(user: string, pass: string): Promise<string> {
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

  /** 注销当前会话 */
  static async logout(): Promise<void> {
    AccountStore.session_ = ''
    AppStorage.setOrCreate(AccountStore.SESSION_KEY, '')
    EcoMoodState.reset()
    try {
      const p: preferences.Preferences = await AccountStore.prefs()
      await p.put(KEY_SESSION, '')
      await p.flush()
    } catch (err) {
      // 预览器/存储不可用：内存态注销即可
    }
  }

  /** 当前登录账号（未登录为空串） */
  static currentUser(): string {
    return AccountStore.session_
  }

  /** 已注册账号名列表 */
  static accountNames(): string[] {
    const out: string[] = []
    for (let i = 0; i < AccountStore.accounts_.length; i++) {
      out.push(AccountStore.accounts_[i].user)
    }
    return out
  }

  /** 取某账号的资料（同步，读内存缓存） */
  static profileOf(user: string): UserProfile {
    const p: UserProfile | undefined = AccountStore.profiles_[user]
    if (p !== undefined && p !== null) return p
    const def: UserProfile = new UserProfile()
    def.name = user
    return def
  }

  /** 保存资料（内存 + 落盘 + 广播 profileTick） */
  static async saveProfile(user: string, prof: UserProfile): Promise<void> {
    if (user.length === 0) return
    AccountStore.profiles_[user] = prof
    await AccountStore.persistProfile(user)
    const t: number | undefined = AppStorage.get<number>(AccountStore.PROFILE_TICK_KEY)
    const next: number = (t === undefined || t === null) ? 1 : t + 1
    AppStorage.setOrCreate(AccountStore.PROFILE_TICK_KEY, next)
  }

  /** 是否图片头像（file:// 开头） */
  static isImageAvatar(a: string): boolean {
    return a.length > 7 && a.indexOf('file://') === 0
  }

  /** 建立会话：加载资料 → 切换数据命名空间 → 重算碳情绪 → 广播闸门 */
  private static async setSession(user: string): Promise<void> {
    AccountStore.session_ = user
    await AccountStore.loadProfile(user)
    await LocalStore.switchUser(user)
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

  private static indexOfUser(user: string): number {
    for (let i = 0; i < AccountStore.accounts_.length; i++) {
      if (AccountStore.accounts_[i].user === user) return i
    }
    return -1
  }

  /** 演示级口令混淆：账号名作盐 + xorshift 混淆，输出 8 位十六进制 */
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
