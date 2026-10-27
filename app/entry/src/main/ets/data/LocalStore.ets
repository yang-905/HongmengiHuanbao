/** 单机版本地数据仓库：RDB 为后端，Preferences 仅保留轻量键值 */
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { common } from '@kit.AbilityKit'
import { Biz } from '../ui/Theme'
import {
  ArticleInteract,
  LocalArticle,
  LocalBenefit,
  LocalCoupon,
  LocalRecord,
  LocalTaskClaim,
  MockStore
} from './MockStore'
import { CarbonRdb, RecordAgg, RecordSummary } from './rdb/CarbonRdb'
import { EcoMoodState } from './EcoMoodState'
import { AppClock } from '../utils/AppClock'

const STORE: string = 'yichu_qinglv'
const KEY_SEEDED: string = 'local_seeded'
const KEY_BACKUP_COUNT: string = 'local_backup_count'
const KEY_BACKUP_TIME: string = 'local_backup_time'
const KEY_RDB_MIGRATED: string = 'rdb_migrated'
const MIGRATED_VER: string = 'v1'
const KEY_POINTS_BALANCE: string = 'points_balance'

// Preferences 旧口径遗留键，仅迁移时读取
const KEY_RECORDS: string = 'local_records'
const KEY_BACKUP: string = 'local_backup'
const KEY_ARTICLE: string = 'article_interact'
const KEY_COUPONS: string = 'coupons_v1'
const KEY_TASK_CLAIMS: string = 'task_claims_v1'

const COUPON_TTL: number = 7 * 24 * 60 * 60 * 1000
const TREE_BENEFIT_CODE: string = 'b7'
const SEED_VER: string = 'v3'

export const DEV_USER: string = '1'

/** 本地用户统计 */
export interface LocalStats {
  totalKg: number
  todayKg: number
  monthKg: number
  totalPoints: number
  availablePoints: number
  exchangedPoints: number
  treeExchangedPoints: number
  recordCount: number
  continuousDays: number
  treeCount: number
  level: number
  taskPoints: number
  taskPointsTotal: number
}

class BackupPayload {
  version: number = 3
  records: LocalRecord[] = []
  coupons: LocalCoupon[] = []
  claims: LocalTaskClaim[] = []
  balance: number = 0

  constructor(r: LocalRecord[], c: LocalCoupon[], tc: LocalTaskClaim[], b: number) {
    this.records = r
    this.coupons = c
    this.claims = tc
    this.balance = b
  }
}

export class LocalStore {
  private static articleMap_: Record<string, ArticleInteract> = {}
  private static coupons_: LocalCoupon[] = []
  private static taskClaims_: LocalTaskClaim[] = []
  private static balance_: number = 0
  private static balanceLoaded_: boolean = false

  private static loaded_: boolean = false
  private static user_: string = ''

  private static keyFor(base: string): string {
    if (LocalStore.user_.length === 0) return base
    return base + '@' + LocalStore.user_
  }

  /** 切换账号数据命名空间 */
  static async switchUser(user: string): Promise<void> {
    if (LocalStore.user_ === user && LocalStore.loaded_) return
    LocalStore.user_ = user
    LocalStore.loaded_ = false
    LocalStore.articleMap_ = {}
    LocalStore.coupons_ = []
    LocalStore.taskClaims_ = []
    LocalStore.balance_ = 0
    LocalStore.balanceLoaded_ = false
    await LocalStore.init()
    EcoMoodState.bump()
    LocalStore.bumpCouponTick()
  }

  private static copyArticle(src: Record<string, ArticleInteract>): Record<string, ArticleInteract> {
    const out: Record<string, ArticleInteract> = {}
    const keys: string[] = Object.keys(src)
    for (let i: number = 0; i < keys.length; i++) {
      out[keys[i]] = src[keys[i]]
    }
    return out
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
      return await preferences.getPreferences(LocalStore.ctx(), STORE);
    } catch (err) {
      throw new Error('本机存储不可用');
    }
  }

  /** 启动初始化：打开 RDB → 迁移旧数据 → 读小数据集镜像 → 灌种子 */
  static async init(): Promise<void> {
    if (LocalStore.loaded_) return
    try {
      await CarbonRdb.open(LocalStore.ctx())
    } catch (err) {
      // 上下文未就绪（预览器页面级预览）：CarbonRdb 保持 store_=null → 内存态
    }
    try {
      await LocalStore.migrateIfNeeded()
      LocalStore.articleMap_ = await CarbonRdb.articleMap(LocalStore.user_)
      LocalStore.coupons_ = await CarbonRdb.allCoupons(LocalStore.user_)
      LocalStore.taskClaims_ = await CarbonRdb.allClaims(LocalStore.user_)
      await LocalStore.ensureSeed()
    } catch (err) {
      if (LocalStore.user_.length === 0 || LocalStore.user_ === DEV_USER) {
        await LocalStore.seedDemo()
      }
    }
    await LocalStore.loadBalance()
    LocalStore.loaded_ = true
  }

  /** Preferences → RDB 一次性迁移（幂等，按账号命名空间独立执行） */
  private static async migrateIfNeeded(): Promise<void> {
    let p: preferences.Preferences
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      return
    }
    const flag: string = (await p.get(LocalStore.keyFor(KEY_RDB_MIGRATED), '')) as string
    if (flag === MIGRATED_VER) return

    const recJson: string = (await p.get(LocalStore.keyFor(KEY_RECORDS), '')) as string
    const cpJson: string = (await p.get(LocalStore.keyFor(KEY_COUPONS), '')) as string
    const tcJson: string = (await p.get(LocalStore.keyFor(KEY_TASK_CLAIMS), '')) as string
    const artJson: string = (await p.get(LocalStore.keyFor(KEY_ARTICLE), '')) as string
    const backupJson: string = (await p.get(LocalStore.keyFor(KEY_BACKUP), '')) as string
    if (recJson.length === 0 && cpJson.length === 0 && tcJson.length === 0 &&
      artJson.length === 0 && backupJson.length === 0) {
      await LocalStore.markMigrated(p)
      return
    }

    const rawSeeded: Object = (await p.get(LocalStore.keyFor(KEY_SEEDED), '')) as Object
    const cleaned: boolean = typeof rawSeeded === 'string' &&
      (rawSeeded === 'v2' || rawSeeded === SEED_VER)
    const needTimeShift: boolean = typeof rawSeeded === 'string' && rawSeeded === 'v2'
    const isReg: boolean = LocalStore.user_.length > 0 && LocalStore.user_ !== DEV_USER

    let recs: LocalRecord[] = LocalStore.parseRecords(recJson)
    if (recs.length > 0) {
      LocalStore.ensureSyncFields(recs)
      if (isReg && !cleaned) {
        recs = []
      } else if (needTimeShift) {
        if (isReg) {
          LocalStore.shiftRecords(recs)
        } else {
          recs = []
        }
      }
    }
    let cps: LocalCoupon[] = LocalStore.parseCoupons(cpJson)
    if (needTimeShift && cps.length > 0) {
      LocalStore.shiftCouponArray(cps)
    }
    const tcs: LocalTaskClaim[] = LocalStore.parseClaims(tcJson)
    const art: Record<string, ArticleInteract> = LocalStore.parseArticle(artJson)

    await CarbonRdb.replaceRecords(LocalStore.user_, recs)
    await CarbonRdb.replaceCoupons(LocalStore.user_, cps)
    await CarbonRdb.replaceClaims(LocalStore.user_, tcs)
    await CarbonRdb.replaceArticle(LocalStore.user_, art)
    if (backupJson.length > 0) {
      await CarbonRdb.saveBackup(LocalStore.user_, backupJson)
    }

    await p.delete(LocalStore.keyFor(KEY_RECORDS))
    await p.delete(LocalStore.keyFor(KEY_COUPONS))
    await p.delete(LocalStore.keyFor(KEY_TASK_CLAIMS))
    await p.delete(LocalStore.keyFor(KEY_ARTICLE))
    await p.delete(LocalStore.keyFor(KEY_BACKUP))
    await LocalStore.markMigrated(p)
  }

  private static async markMigrated(p: preferences.Preferences): Promise<void> {
    await p.put(LocalStore.keyFor(KEY_RDB_MIGRATED), MIGRATED_VER)
    await p.flush()
  }

  /** 载入余额镜像，init 末尾调用 */
  private static async loadBalance(): Promise<void> {
    let p: preferences.Preferences | null = null
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      p = null
    }
    if (p !== null) {
      const raw: number = (await p.get(LocalStore.keyFor(KEY_POINTS_BALANCE), -1)) as number
      if (raw >= 0) {
        LocalStore.balance_ = raw
        LocalStore.balanceLoaded_ = true
        return
      }
    }
    LocalStore.balance_ = await LocalStore.computeLegacyBalance()
    LocalStore.balanceLoaded_ = true
    if (p !== null) {
      await LocalStore.saveBalance(p)
    }
  }

  /** 旧口径余额（一次性迁移 / 备份恢复兜底专用） */
  private static async computeLegacyBalance(): Promise<number> {
    try {
      const agg: RecordAgg = await CarbonRdb.statsAgg(LocalStore.user_,
        AppClock.dateStr(), AppClock.monthStr())
      const earned: number = agg.totalPoints + LocalStore.taskPointsTotal()
      let exchanged: number = 0
      for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
        exchanged += LocalStore.coupons_[i].points
      }
      const raw: number = earned - exchanged
      return raw > 0 ? raw : 0
    } catch (err) {
      return 0
    }
  }

  private static async saveBalance(p?: preferences.Preferences): Promise<void> {
    let prefsObj: preferences.Preferences | null = p === undefined ? null : p
    if (prefsObj === null) {
      try {
        prefsObj = await LocalStore.prefs()
      } catch (err) {
        return
      }
    }
    try {
      await prefsObj.put(LocalStore.keyFor(KEY_POINTS_BALANCE), LocalStore.balance_)
      await prefsObj.flush()
    } catch (err) {
      // ignore
    }
  }

  /** 余额加项：加多少算多少 */
  private static async addBalance(delta: number): Promise<void> {
    LocalStore.balance_ += delta
    await LocalStore.saveBalance()
  }

  /** 余额扣项：扣到 0 即止 */
  private static async subBalance(delta: number): Promise<void> {
    const next: number = LocalStore.balance_ - delta
    LocalStore.balance_ = next > 0 ? next : 0
    await LocalStore.saveBalance()
  }

  /** 余额整体重置 */
  private static async setBalance(v: number): Promise<void> {
    LocalStore.balance_ = v > 0 ? v : 0
    await LocalStore.saveBalance()
  }

  /** 种子策略：注册账号零起步，其余灌演示数据 */
  private static async ensureSeed(): Promise<void> {
    let p: preferences.Preferences | null = null
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      p = null
    }
    const rawSeeded: Object = p === null ? '' : (await p.get(LocalStore.keyFor(KEY_SEEDED), '')) as Object
    const seededV3: boolean = typeof rawSeeded === 'string' && rawSeeded === SEED_VER
    const isReg: boolean = LocalStore.user_.length > 0 && LocalStore.user_ !== DEV_USER
    if (isReg) {
      if (!seededV3 && p !== null) {
        await p.put(LocalStore.keyFor(KEY_SEEDED), SEED_VER)
        await p.flush()
      }
      return
    }
    const cnt: number = await CarbonRdb.countRecords(LocalStore.user_)
    if (cnt === 0 && !seededV3 && rawSeeded !== true) {
      await LocalStore.seedDemo()
      if (p !== null) {
        await p.put(LocalStore.keyFor(KEY_SEEDED), SEED_VER)
        await p.flush()
      }
    }
  }

  /** 灌入 30 天演示数据 */
  private static async seedDemo(resetAssets: boolean = false): Promise<void> {
    const arr: LocalRecord[] = MockStore.records()
    if (resetAssets) {
      await CarbonRdb.replaceUserData(LocalStore.user_, arr, [], [])
      LocalStore.coupons_ = []
      LocalStore.taskClaims_ = []
    } else {
      await CarbonRdb.replaceRecords(LocalStore.user_, arr)
    }
    let pts: number = 0
    for (let i: number = 0; i < arr.length; i++) {
      pts += arr[i].points
    }
    await LocalStore.setBalance(pts)
  }

  private static readonly OLD_ANCHOR_MS: number = new Date(2026, 10, 20, 12, 0, 0).getTime()

  private static shiftRecords(recs: LocalRecord[]): void {
    const delta: number = LocalStore.OLD_ANCHOR_MS - Date.now()
    if (delta === 0) return
    const cap: number = Date.now() + 60000
    for (let i: number = 0; i < recs.length; i++) {
      const r: LocalRecord = recs[i]
      const bt: number = LocalStore.timeOf(r.behaviorTime)
      if (bt > 0 && bt - delta <= cap) {
        r.behaviorTime = LocalStore.shiftStr(bt, delta)
      }
      const ds: number = LocalStore.timeOf(r.dateStr)
      if (ds > 0 && ds - delta <= cap) {
        r.dateStr = LocalStore.shiftStr(ds, delta).substring(0, 10)
      }
    }
  }

  private static shiftCouponArray(cps: LocalCoupon[]): void {
    const delta: number = LocalStore.OLD_ANCHOR_MS - Date.now()
    if (delta === 0) return
    for (let i: number = 0; i < cps.length; i++) {
      const c: LocalCoupon = cps[i]
      if (c.issuedAt > 0) c.issuedAt -= delta
      if (c.expireAt > 0) c.expireAt -= delta
      if (c.usedAt > 0) c.usedAt -= delta
    }
  }

  private static shiftStr(ts: number, delta: number): string {
    const d: Date = new Date(ts - delta)
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
      ' ' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds())
  }

  private static parseRecords(json: string): LocalRecord[] {
    if (json.length === 0) return []
    try {
      const arr: LocalRecord[] = JSON.parse(json) as LocalRecord[]
      if (arr === undefined || arr === null) return []
      return arr
    } catch (err) {
      return []
    }
  }

  private static parseCoupons(json: string): LocalCoupon[] {
    if (json.length === 0) return []
    try {
      const arr: LocalCoupon[] = JSON.parse(json) as LocalCoupon[]
      if (arr === undefined || arr === null) return []
      return arr
    } catch (err) {
      return []
    }
  }

  private static parseClaims(json: string): LocalTaskClaim[] {
    if (json.length === 0) return []
    try {
      const arr: LocalTaskClaim[] = JSON.parse(json) as LocalTaskClaim[]
      if (arr === undefined || arr === null) return []
      return arr
    } catch (err) {
      return []
    }
  }

  private static parseArticle(json: string): Record<string, ArticleInteract> {
    if (json.length === 0) return {}
    try {
      const m: Record<string, ArticleInteract> = JSON.parse(json) as Record<string, ArticleInteract>
      if (m === undefined || m === null) return {}
      return m
    } catch (err) {
      return {}
    }
  }

  /** 取单篇文章的互动状态 */
  static articleState(articleId: number): ArticleInteract {
    const st: ArticleInteract | undefined = LocalStore.articleMap_['' + articleId]
    if (st !== undefined && st !== null) {
      return st
    }
    return { liked: false, faved: false, likeDelta: 0 }
  }

  /** 写入互动状态：内存镜像 + 落库 + 广播 articleTick */
  static setArticleState(articleId: number, liked: boolean, faved: boolean, likeDelta: number): void {
    LocalStore.articleMap_['' + articleId] = { liked: liked, faved: faved, likeDelta: likeDelta }
    CarbonRdb.upsertArticle(LocalStore.user_, articleId,
      { liked: liked, faved: faved, likeDelta: likeDelta }).catch((): void => {})
    const t: number | undefined = AppStorage.get<number>('articleTick')
    AppStorage.setOrCreate<number>('articleTick', (t === undefined ? 0 : t) + 1)
  }

  /** 把互动状态合并进文章列表（原地修改） */
  static applyArticleInteract(list: LocalArticle[]): LocalArticle[] {
    for (let i = 0; i < list.length; i++) {
      const st: ArticleInteract = LocalStore.articleState(list[i].articleId)
      if (st.faved !== list[i].favorite) {
        list[i].favorite = st.faved
      }
      if (st.likeDelta !== 0) {
        list[i].likeCount = Math.max(0, list[i].likeCount + st.likeDelta)
      }
    }
    return list
  }

  /** 全部记录（behavior_time 倒序） */
  static async allRecords(): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await CarbonRdb.allRecords(LocalStore.user_)
  }

  /** 分页读记录 */
  static async recordsPage(category: string, offset: number, limit: number): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await CarbonRdb.recordsPage(LocalStore.user_, category, offset, limit)
  }

  /** 按分类过滤 */
  static async recordsOf(category: string): Promise<LocalRecord[]> {
    await LocalStore.init()
    if (category.length === 0) return await LocalStore.allRecords()
    return await CarbonRdb.recordsOf(LocalStore.user_, category)
  }

  /** 按 recordId 取单条 */
  static async recordById(recordId: number): Promise<LocalRecord | undefined> {
    await LocalStore.init()
    return await CarbonRdb.recordById(LocalStore.user_, recordId)
  }

  /** 列表页合计口径（SQL 聚合下推） */
  static async recordsSummary(category: string): Promise<RecordSummary> {
    await LocalStore.init()
    return await CarbonRdb.summaryAgg(LocalStore.user_, category)
  }

  /** 新增一条行为记录 */
  static async addRecord(
    itemId: number,
    itemCode: string,
    itemName: string,
    icon: string,
    category: string,
    unit: string,
    amount: number,
    factorValue: number,
    source: string,
    remark: string
  ): Promise<LocalRecord> {
    await LocalStore.init()
    const kg: number = Math.round(factorValue * amount * 1000) / 1000
    const pts: number = Biz.pointsOf(kg)
    const d: Date = AppClock.today()
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    const dateStr: string = d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate())
    const timeStr: string = dateStr + ' ' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds())

    const rec: LocalRecord = {
      recordId: Date.now(),
      itemId: itemId,
      itemCode: itemCode,
      itemName: itemName,
      icon: icon,
      category: category,
      amount: amount,
      unit: unit,
      reduceKg: kg,
      points: pts,
      behaviorTime: timeStr,
      dateStr: dateStr,
      recordSource: source,
      remark: remark,
      clientRecordId: util.generateRandomUUID(false),
      updateTime: Date.now(),
      syncFlag: 'local'
    }
    await CarbonRdb.insertRecord(LocalStore.user_, rec)
    await LocalStore.addBalance(pts)
    LocalStore.syncEcoMood()
    return rec
  }

  /** 删除一条记录 */
  static async removeRecord(recordId: number): Promise<boolean> {
    await LocalStore.init()
    const rec: LocalRecord | undefined = await CarbonRdb.recordById(LocalStore.user_, recordId)
    const ok: boolean = await CarbonRdb.deleteRecord(LocalStore.user_, recordId)
    if (ok) {
      if (rec !== undefined && rec !== null) {
        await LocalStore.subBalance(rec.points)
      }
      LocalStore.syncEcoMood()
    }
    return ok
  }

  /** 通知情绪层重算档位 */
  private static syncEcoMood(): void {
    EcoMoodState.bump()
  }

  /** 补齐 clientRecordId / updateTime / syncFlag */
  private static ensureSyncFields(recs: LocalRecord[]): void {
    for (let i: number = 0; i < recs.length; i++) {
      const r: LocalRecord = recs[i]
      if (r.clientRecordId === undefined || r.clientRecordId.length === 0) {
        r.clientRecordId = util.generateRandomUUID(false)
      }
      if (r.updateTime === undefined || r.updateTime === 0) {
        r.updateTime = LocalStore.timeOf(r.behaviorTime)
      }
      if (r.syncFlag === undefined) {
        r.syncFlag = 'local'
      }
    }
  }

  private static timeOf(s: string): number {
    if (s.length === 0) return AppClock.now()
    const t: number = new Date(s.replace(/-/g, '/')).getTime()
    return isNaN(t) ? AppClock.now() : t
  }

  /** 合并一条来自其他设备的记录，返回 'inserted' | 'updated' | 'ignored' */
  static async mergeRemote(rec: LocalRecord): Promise<string> {
    await LocalStore.init()
    if (rec === undefined || rec === null) return 'ignored'
    const uuid: string | undefined = rec.clientRecordId
    if (uuid === undefined || uuid.length === 0) return 'ignored'
    const old: LocalRecord | undefined = await CarbonRdb.findByClientId(LocalStore.user_, uuid)
    if (old === undefined || old === null) {
      const maxId: number = await CarbonRdb.maxRecordId(LocalStore.user_)
      if (rec.recordId <= maxId) {
        rec.recordId = maxId + 1
      }
      rec.syncFlag = 'synced'
      await CarbonRdb.insertRecord(LocalStore.user_, rec)
      await LocalStore.addBalance(rec.points)
      LocalStore.syncEcoMood()
      return 'inserted'
    }
    const oldU: number = old.updateTime !== undefined ? old.updateTime : 0
    const newU: number = rec.updateTime !== undefined ? rec.updateTime : 0
    if (newU <= oldU) return 'ignored'
    rec.syncFlag = 'synced'
    await CarbonRdb.updateRecord(LocalStore.user_, rec)
    const diff: number = rec.points - old.points
    if (diff > 0) {
      await LocalStore.addBalance(diff)
    } else if (diff < 0) {
      await LocalStore.subBalance(-diff)
    }
    LocalStore.syncEcoMood()
    return 'updated'
  }

  /** 按 clientRecordId 删除 */
  static async removeByClientId(uuid: string): Promise<boolean> {
    await LocalStore.init()
    if (uuid.length === 0) return false
    const old: LocalRecord | undefined = await CarbonRdb.findByClientId(LocalStore.user_, uuid)
    const ok: boolean = await CarbonRdb.deleteByClientId(LocalStore.user_, uuid)
    if (ok) {
      if (old !== undefined && old !== null) {
        await LocalStore.subBalance(old.points)
      }
      LocalStore.syncEcoMood()
    }
    return ok
  }

  /** 供近场推送的原始记录快照 */
  static async allForSync(): Promise<LocalRecord[]> {
    return await LocalStore.allRecords()
  }

  /** 清空全部数据 */
  static async clear(): Promise<void> {
    await LocalStore.init()
    await CarbonRdb.clearUser(LocalStore.user_)
    LocalStore.coupons_ = []
    LocalStore.taskClaims_ = []
    await LocalStore.setBalance(0)
    LocalStore.syncEcoMood()
  }

  /** 恢复演示数据 */
  static async restoreDemo(): Promise<void> {
    await LocalStore.init()
    await LocalStore.seedDemo(true)
    LocalStore.syncEcoMood()
  }

  private static nowText(): string {
    return AppClock.dateTimeStr()
  }

  /** 备份：记录 + 券 + 任务领取 + 余额快照写入 RDB，返回累计备份份数 */
  static async backup(): Promise<number> {
    try {
      const p: preferences.Preferences = await LocalStore.prefs()
      const recs: LocalRecord[] = await LocalStore.allRecords()
      const bal: number = LocalStore.balanceLoaded_
        ? LocalStore.balance_
        : await LocalStore.computeLegacyBalance()
      await CarbonRdb.saveBackup(LocalStore.user_,
        JSON.stringify(new BackupPayload(recs, LocalStore.coupons_.slice(),
          LocalStore.taskClaims_.slice(), bal)))
      await p.put(LocalStore.keyFor(KEY_BACKUP_TIME), LocalStore.nowText())
      const prev: number = (await p.get(LocalStore.keyFor(KEY_BACKUP_COUNT), 0)) as number
      const next: number = prev + 1
      await p.put(LocalStore.keyFor(KEY_BACKUP_COUNT), next)
      await p.flush()
      return next
    } catch (err) {
      throw new Error('备份失败：本机存储不可用')
    }
  }

  /** 恢复：用备份槽覆盖当前数据，返回恢复条数 */
  static async restore(): Promise<number> {
    await LocalStore.init()
    try {
      const json: string = await CarbonRdb.loadBackup(LocalStore.user_)
      if (json.length === 0) {
        throw new Error('没有可用的备份')
      }
      const parsed: Object = JSON.parse(json) as Object
      let recs: LocalRecord[] = []
      let cps: LocalCoupon[] = []
      let claims: LocalTaskClaim[] = []
      let savedBalance: number = 0
      let hasClaims: boolean = false
      if (Array.isArray(parsed)) {
        recs = parsed as LocalRecord[]
      } else {
        const payload: BackupPayload = parsed as BackupPayload
        if (payload.records !== undefined && payload.records !== null) {
          recs = payload.records
        }
        if (payload.coupons !== undefined && payload.coupons !== null) {
          cps = payload.coupons
        }
        if (payload.version === 3 && Array.isArray(payload.claims) &&
          typeof payload.balance === 'number' && !isNaN(payload.balance)) {
          hasClaims = true
          claims = payload.claims as LocalTaskClaim[]
          savedBalance = payload.balance
        }
      }
      if (hasClaims) {
        if (recs.length === 0 && cps.length === 0 && claims.length === 0 && savedBalance <= 0) {
          throw new Error('备份内容为空')
        }
      } else if (recs.length === 0) {
        throw new Error('备份内容为空')
      }
      if (hasClaims) {
        await CarbonRdb.replaceUserData(LocalStore.user_, recs, cps, claims)
        LocalStore.taskClaims_ = claims.slice()
      } else {
        await CarbonRdb.replaceUserData(LocalStore.user_, recs, cps)
      }
      LocalStore.coupons_ = cps.slice()
      if (hasClaims) {
        await LocalStore.setBalance(savedBalance)
      } else {
        await LocalStore.setBalance(await LocalStore.computeLegacyBalance())
      }
      return recs.length
    } catch (err) {
      throw new Error('恢复失败：' + ((err as Error).message ?? '本机存储不可用'))
    }
  }

  /** 最近备份时间 */
  static async lastBackupTime(): Promise<string> {
    try {
      const p: preferences.Preferences = await LocalStore.prefs()
      return (await p.get(LocalStore.keyFor(KEY_BACKUP_TIME), '')) as string
    } catch (err) {
      return ''
    }
  }

  /** 累计备份份数 */
  static async backupCount(): Promise<number> {
    try {
      const p: preferences.Preferences = await LocalStore.prefs()
      return (await p.get(LocalStore.keyFor(KEY_BACKUP_COUNT), 0)) as number
    } catch (err) {
      return 0
    }
  }

  /** 是否已有数据 */
  static async hasData(): Promise<boolean> {
    await LocalStore.init()
    return await CarbonRdb.countRecords(LocalStore.user_) > 0
  }

  /** 累计统计（SQL 下推，全部本地计算） */
  static async stats(): Promise<LocalStats> {
    await LocalStore.init()
    const todayStr: string = AppClock.dateStr()
    const monthPrefix: string = AppClock.monthStr()

    const agg: RecordAgg = await CarbonRdb.statsAgg(LocalStore.user_, todayStr, monthPrefix)
    const dates: string[] = await CarbonRdb.distinctDates(LocalStore.user_)

    const taskPts: number = LocalStore.taskPointsToday()
    const taskPtsTotal: number = LocalStore.taskPointsTotal()
    const earned: number = agg.totalPoints + taskPtsTotal

    let exchanged: number = 0
    let treeExchanged: number = 0
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      const cp: LocalCoupon = LocalStore.coupons_[i]
      exchanged += cp.points
      if (cp.kind === 'tree') {
        treeExchanged += cp.points
      }
    }
    const treeCount: number = Math.floor(treeExchanged / Biz.POINTS_PER_TREE)

    return {
      totalKg: Math.round(agg.totalKg * 100) / 100,
      todayKg: Math.round(agg.todayKg * 1000) / 1000,
      monthKg: Math.round(agg.monthKg * 100) / 100,
      totalPoints: earned,
      availablePoints: LocalStore.balanceLoaded_ ? LocalStore.balance_ : Math.max(0, earned - exchanged),
      exchangedPoints: exchanged,
      treeExchangedPoints: treeExchanged,
      taskPoints: taskPts,
      taskPointsTotal: taskPtsTotal,
      recordCount: agg.recordCount,
      continuousDays: LocalStore.calcStreak(dates),
      treeCount: treeCount,
      level: Biz.levelOf(agg.totalKg)
    }
  }

  /** 某任务今天是否已领取 */
  static taskClaimed(taskCode: string): boolean {
    const today: string = AppClock.dateStr()
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      const c: LocalTaskClaim = LocalStore.taskClaims_[i]
      if (c.taskCode === taskCode && c.dateStr === today) return true
    }
    return false
  }

  /** 今天已领取的任务 code 列表 */
  static claimedTaskCodesToday(): string[] {
    const today: string = AppClock.dateStr()
    const out: string[] = []
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      const c: LocalTaskClaim = LocalStore.taskClaims_[i]
      if (c.dateStr === today && out.indexOf(c.taskCode) < 0) out.push(c.taskCode)
    }
    return out
  }

  /** 领取任务奖励（幂等），true=本次真实发放 */
  static async claimTask(taskCode: string, points: number): Promise<boolean> {
    await LocalStore.init()
    if (LocalStore.taskClaimed(taskCode)) return false
    const claim: LocalTaskClaim = {
      taskCode: taskCode,
      dateStr: AppClock.dateStr(),
      points: points
    }
    LocalStore.taskClaims_.push(claim)
    await CarbonRdb.insertClaim(LocalStore.user_, claim)
    await LocalStore.addBalance(points)
    return true
  }

  /** 今日任务奖励积分合计 */
  static taskPointsToday(): number {
    const today: string = AppClock.dateStr()
    let s: number = 0
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      if (LocalStore.taskClaims_[i].dateStr === today) s += LocalStore.taskClaims_[i].points
    }
    return s
  }

  /** 全部历史任务奖励积分合计 */
  static taskPointsTotal(): number {
    let s: number = 0
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      s += LocalStore.taskClaims_[i].points
    }
    return s
  }

  /** 全部券（含已使用/已过期），按领取时间倒序 */
  static allCoupons(): LocalCoupon[] {
    return LocalStore.coupons_.slice()
  }

  /** 植树兑换券列表（kind='tree'），按签发时间倒序（新在前） */
  static treeCoupons(): LocalCoupon[] {
    const out: LocalCoupon[] = [];
    for (let i = 0; i < LocalStore.coupons_.length; i++) {
      const cp: LocalCoupon = LocalStore.coupons_[i];
      if (cp.kind === 'tree') out.push(cp);
    }
    // coupons_ 是 unshift 插入（新在前），这里按签发时间显式倒序，
    // 保证「最新认养的证书排在最前」，与证书夹的时间线阅读习惯一致。
    out.sort((a: LocalCoupon, b: LocalCoupon): number => {
      return b.issuedAt - a.issuedAt;
    });
    return out;
  }
  /** 单张券 */
  static couponById(couponId: string): LocalCoupon | null {
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      if (LocalStore.coupons_[i].couponId === couponId) {
        return LocalStore.coupons_[i]
      }
    }
    return null
  }

  /** 券的实时状态：'unused' / 'used' / 'expired' */
  static couponStatus(c: LocalCoupon): string {
    if (c.status === 'used') return 'used'
    return AppClock.now() >= c.expireAt ? 'expired' : 'unused'
  }

  /** 可用券数（未使用且未过期） */
  static availableCouponCount(): number {
    let n: number = 0
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      if (LocalStore.couponStatus(LocalStore.coupons_[i]) === 'unused') n++
    }
    return n
  }

  /** 兑换权益 → 生成券，成功返回新券；积分不足返回 null */
  static async exchange(benefit: LocalBenefit): Promise<LocalCoupon | null> {
    const s: LocalStats = await LocalStore.stats()
    if (s.availablePoints < benefit.points) return null
    const now: number = AppClock.now()
    const cp: LocalCoupon = {
      couponId: 'CP-' + LocalStore.couponStamp(now) + '-' + LocalStore.rand4(),
      benefitCode: benefit.benefitCode,
      benefitName: benefit.benefitName,
      benefitIcon: benefit.icon,
      points: benefit.points,
      kind: benefit.benefitCode === TREE_BENEFIT_CODE ? 'tree' : 'coupon',
      issuedAt: now,
      expireAt: now + COUPON_TTL,
      status: 'unused',
      usedAt: 0,
      qrContent: ''
    }
    LocalStore.coupons_.unshift(cp)
    await CarbonRdb.insertCoupon(LocalStore.user_, cp)
    await LocalStore.subBalance(benefit.points)
    return cp
  }

  /** 确认使用券：状态置 used + 生成核销二维码内容 */
  static async useCoupon(couponId: string): Promise<string | null> {
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      const c: LocalCoupon = LocalStore.coupons_[i]
      if (c.couponId !== couponId) continue
      if (LocalStore.couponStatus(c) === 'expired') return null
      if (c.status === 'used') {
        return await LocalStore.ensureQrContent(couponId)
      }
      c.status = 'used'
      c.usedAt = AppClock.now()
      c.qrContent = LocalStore.buildQr(c, LocalStore.rand6(), c.usedAt)
      await CarbonRdb.updateCoupon(LocalStore.user_, c)
      return c.qrContent
    }
    return null
  }

  private static buildQr(c: LocalCoupon, code: string, redeemedAt: number): string {
    const d: Date = new Date(redeemedAt)
    return 'Thanks for living low-carbon! Thanks for greening the city!' +
      ' Coupon ' + c.couponId +
      ' Code ' + code +
      ' Time ' + AppClock.fmtDate(d) + ' ' + AppClock.fmtTime(d) +
      ' Valid to ' + AppClock.fmtDate(new Date(c.expireAt))
  }

  /** 确保已核销券持有当前格式的核销凭证内容（历史数据兜底） */
  static async ensureQrContent(couponId: string): Promise<string> {
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      const c: LocalCoupon = LocalStore.coupons_[i]
      if (c.couponId !== couponId) continue
      if (c.qrContent.startsWith('Thanks for living')) return c.qrContent
      if (c.status !== 'used') return c.qrContent
      if (!(c.usedAt > 0)) c.usedAt = AppClock.now()
      c.qrContent = LocalStore.buildQr(c, LocalStore.rand6(), c.usedAt)
      await CarbonRdb.updateCoupon(LocalStore.user_, c)
      return c.qrContent
    }
    return ''
  }

  /** 递增券变更信号（订阅方：我的页角标、券包页列表） */
  static bumpCouponTick(): void {
    const t: number | undefined = AppStorage.get<number>('couponTick')
    AppStorage.setOrCreate<number>('couponTick', (t === undefined ? 0 : t) + 1)
  }

  private static couponStamp(now: number): string {
    const d: Date = new Date(now)
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    return '' + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) +
      p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
  }

  private static rand4(): string {
    const n: number = Math.floor(Math.random() * 10000)
    return (n < 1000 ? '0' : '') + (n < 100 ? '0' : '') + (n < 10 ? '0' : '') + n.toString()
  }

  private static rand6(): string {
    const n: number = Math.floor(Math.random() * 1000000)
    const s: string = (n < 100000 ? '0' : '') + (n < 10000 ? '0' : '') + (n < 1000 ? '0' : '') +
      (n < 100 ? '0' : '') + (n < 10 ? '0' : '') + n.toString()
    return s
  }

  /** 连续打卡天数：从今天（或昨天）起往回数有记录的连续天数 */
  private static calcStreak(dates: string[]): number {
    if (dates.length === 0) return 0
    const set: Record<string, boolean> = {}
    for (let i: number = 0; i < dates.length; i++) {
      set[dates[i]] = true
    }
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    const fmt = (dt: Date): string => {
      return dt.getFullYear() + '-' + p(dt.getMonth() + 1) + '-' + p(dt.getDate())
    }
    let cursor: Date = AppClock.today()
    if (!set[fmt(cursor)]) {
      cursor.setDate(cursor.getDate() - 1)
      if (!set[fmt(cursor)]) return 0
    }
    let streak: number = 0
    while (set[fmt(cursor)]) {
      streak++
      cursor.setDate(cursor.getDate() - 1)
    }
    return streak
  }
}
