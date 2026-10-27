/** RDB 数据层（SQLite 后端）；store_ 为 null 时退化为内存态，供预览器使用 */
import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { ArticleInteract, LocalCoupon, LocalRecord, LocalTaskClaim } from '../MockStore'

const DB_NAME: string = 'carbon.db'

/** 聚合统计结果 */
export interface RecordAgg {
  totalKg: number
  todayKg: number
  monthKg: number
  totalPoints: number
  recordCount: number
}

/** 列表页合计口径 */
export interface RecordSummary {
  recordCount: number
  dayCount: number
  totalKg: number
  totalPoints: number
}

/** 内存态单账号数据桶 */
interface MemUserData {
  records: LocalRecord[]
  coupons: LocalCoupon[]
  claims: LocalTaskClaim[]
  article: Record<string, ArticleInteract>
  backup: string
}

export class CarbonRdb {
  private static store_: relationalStore.RdbStore | null = null
  private static opened_: boolean = false
  private static memUsers_: Record<string, MemUserData> = {}

  /** 打开数据库并建表；失败走内存态 */
  static async open(ctx: common.Context): Promise<void> {
    if (CarbonRdb.opened_) return
    CarbonRdb.opened_ = true
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      }
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, config)
      await CarbonRdb.createTables(store)
      CarbonRdb.store_ = store
    } catch (err) {
      CarbonRdb.store_ = null
      CarbonRdb.memUsers_ = {}
    }
  }

  /** 建表建索引 */
  private static async createTables(store: relationalStore.RdbStore): Promise<void> {
    const ddl: string[] = [
      'CREATE TABLE IF NOT EXISTS carbon_record (' +
      'user_key TEXT NOT NULL,' +
      'record_id INTEGER NOT NULL,' +
      'item_id INTEGER NOT NULL,' +
      'item_code TEXT NOT NULL,' +
      'item_name TEXT NOT NULL,' +
      'icon TEXT NOT NULL,' +
      'category TEXT NOT NULL,' +
      'amount REAL NOT NULL,' +
      'unit TEXT NOT NULL,' +
      'reduce_kg REAL NOT NULL,' +
      'points INTEGER NOT NULL,' +
      'behavior_time TEXT NOT NULL,' +
      'date_str TEXT NOT NULL,' +
      'record_source TEXT NOT NULL,' +
      'remark TEXT NOT NULL,' +
      'client_record_id TEXT NOT NULL,' +
      'update_time INTEGER NOT NULL,' +
      'sync_flag TEXT NOT NULL)',
      'CREATE INDEX IF NOT EXISTS idx_record_user_date ON carbon_record (user_key, date_str)',
      'CREATE INDEX IF NOT EXISTS idx_record_user_cat ON carbon_record (user_key, category)',
      'CREATE INDEX IF NOT EXISTS idx_record_user_time ON carbon_record (user_key, behavior_time)',
      'CREATE TABLE IF NOT EXISTS carbon_coupon (' +
      'user_key TEXT NOT NULL,' +
      'coupon_id TEXT NOT NULL,' +
      'benefit_code TEXT NOT NULL,' +
      'benefit_name TEXT NOT NULL,' +
      'benefit_icon TEXT NOT NULL,' +
      'points INTEGER NOT NULL,' +
      'kind TEXT NOT NULL,' +
      'issued_at INTEGER NOT NULL,' +
      'expire_at INTEGER NOT NULL,' +
      'status TEXT NOT NULL,' +
      'used_at INTEGER NOT NULL,' +
      'qr_content TEXT NOT NULL)',
      'CREATE INDEX IF NOT EXISTS idx_coupon_user ON carbon_coupon (user_key, issued_at)',
      'CREATE TABLE IF NOT EXISTS task_claim (' +
      'user_key TEXT NOT NULL,' +
      'task_code TEXT NOT NULL,' +
      'date_str TEXT NOT NULL,' +
      'points INTEGER NOT NULL,' +
      'claim_time INTEGER NOT NULL)',
      'CREATE INDEX IF NOT EXISTS idx_task_user_date ON task_claim (user_key, date_str)',
      'CREATE TABLE IF NOT EXISTS article_interact (' +
      'user_key TEXT NOT NULL,' +
      'article_id INTEGER NOT NULL,' +
      'liked INTEGER NOT NULL,' +
      'faved INTEGER NOT NULL,' +
      'like_delta INTEGER NOT NULL)',
      'CREATE INDEX IF NOT EXISTS idx_article_user ON article_interact (user_key)',
      'CREATE TABLE IF NOT EXISTS backup_slot (' +
      'user_key TEXT NOT NULL,' +
      'payload TEXT NOT NULL,' +
      'backup_time INTEGER NOT NULL)'
    ]
    for (let i: number = 0; i < ddl.length; i++) {
      await store.executeSql(ddl[i])
    }
  }

  /** 是否 RDB 后端 */
  static get persistent(): boolean {
    return CarbonRdb.store_ !== null
  }

  /** 取（必要时新建）内存态账号桶 */
  private static memOf(userKey: string): MemUserData {
    let m: MemUserData | undefined = CarbonRdb.memUsers_[userKey]
    if (m === undefined || m === null) {
      const fresh: MemUserData = {
        records: [],
        coupons: [],
        claims: [],
        article: {},
        backup: ''
      }
      CarbonRdb.memUsers_[userKey] = fresh
      m = fresh
    }
    return m
  }

  private static recordToBucket(userKey: string, r: LocalRecord): relationalStore.ValuesBucket {
    const vb: relationalStore.ValuesBucket = {
      user_key: userKey,
      record_id: r.recordId,
      item_id: r.itemId,
      item_code: r.itemCode,
      item_name: r.itemName,
      icon: r.icon,
      category: r.category,
      amount: r.amount,
      unit: r.unit,
      reduce_kg: r.reduceKg,
      points: r.points,
      behavior_time: r.behaviorTime,
      date_str: r.dateStr,
      record_source: r.recordSource,
      remark: r.remark,
      client_record_id: r.clientRecordId === undefined ? '' : r.clientRecordId,
      update_time: r.updateTime === undefined ? 0 : r.updateTime,
      sync_flag: r.syncFlag === undefined ? 'local' : r.syncFlag
    }
    return vb
  }

  private static rowToRecord(rs: relationalStore.ResultSet): LocalRecord {
    const rec: LocalRecord = {
      recordId: rs.getLong(rs.getColumnIndex('record_id')),
      itemId: rs.getLong(rs.getColumnIndex('item_id')),
      itemCode: rs.getString(rs.getColumnIndex('item_code')),
      itemName: rs.getString(rs.getColumnIndex('item_name')),
      icon: rs.getString(rs.getColumnIndex('icon')),
      category: rs.getString(rs.getColumnIndex('category')),
      amount: rs.getDouble(rs.getColumnIndex('amount')),
      unit: rs.getString(rs.getColumnIndex('unit')),
      reduceKg: rs.getDouble(rs.getColumnIndex('reduce_kg')),
      points: rs.getLong(rs.getColumnIndex('points')),
      behaviorTime: rs.getString(rs.getColumnIndex('behavior_time')),
      dateStr: rs.getString(rs.getColumnIndex('date_str')),
      recordSource: rs.getString(rs.getColumnIndex('record_source')),
      remark: rs.getString(rs.getColumnIndex('remark')),
      clientRecordId: rs.getString(rs.getColumnIndex('client_record_id')),
      updateTime: rs.getLong(rs.getColumnIndex('update_time')),
      syncFlag: rs.getString(rs.getColumnIndex('sync_flag'))
    }
    return rec
  }

  private static readRecords(rs: relationalStore.ResultSet): LocalRecord[] {
    const out: LocalRecord[] = []
    if (rs.goToFirstRow()) {
      do {
        out.push(CarbonRdb.rowToRecord(rs))
      } while (rs.goToNextRow())
    }
    rs.close()
    return out
  }

  /** 新增一条记录 */
  static async insertRecord(userKey: string, rec: LocalRecord): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).records.unshift(rec)
      return
    }
    await store.insert('carbon_record', CarbonRdb.recordToBucket(userKey, rec))
  }

  /** 批量入库 */
  static async insertRecords(userKey: string, recs: LocalRecord[]): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < recs.length; i++) {
        m.records.push(recs[i])
      }
      return
    }
    const buckets: Array<relationalStore.ValuesBucket> =
      recs.map((r: LocalRecord): relationalStore.ValuesBucket => CarbonRdb.recordToBucket(userKey, r))
    if (buckets.length > 0) {
      await store.batchInsert('carbon_record', buckets)
    }
  }

  /** 更新一条记录 */
  static async updateRecord(userKey: string, rec: LocalRecord): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].recordId === rec.recordId) {
          m.records[i] = rec
          return
        }
      }
      return
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('record_id', rec.recordId)
    await store.update(CarbonRdb.recordToBucket(userKey, rec), predicates)
  }

  /** 删除一条记录，返回是否删到 */
  static async deleteRecord(userKey: string, recordId: number): Promise<boolean> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].recordId === recordId) {
          m.records.splice(i, 1)
          return true
        }
      }
      return false
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('record_id', recordId)
    const n: number = await store.delete(predicates)
    return n > 0
  }

  /** 按 clientRecordId 删除，返回是否删到 */
  static async deleteByClientId(userKey: string, uuid: string): Promise<boolean> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].clientRecordId === uuid) {
          m.records.splice(i, 1)
          return true
        }
      }
      return false
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('client_record_id', uuid)
    const n: number = await store.delete(predicates)
    return n > 0
  }

  /** 事务内整体替换记录（清空 + 批量插入） */
  static async replaceRecords(userKey: string, recs: LocalRecord[]): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).records = recs.slice()
      return
    }
    await store.beginTransaction()
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
      predicates.equalTo('user_key', userKey)
      await store.delete(predicates)
      const buckets: Array<relationalStore.ValuesBucket> =
        recs.map((r: LocalRecord): relationalStore.ValuesBucket => CarbonRdb.recordToBucket(userKey, r))
      if (buckets.length > 0) {
        await store.batchInsert('carbon_record', buckets)
      }
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }

  /** 全部记录 */
  static async allRecords(userKey: string): Promise<LocalRecord[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.memOf(userKey).records.slice()
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.orderByDesc('behavior_time')
    const rs: relationalStore.ResultSet = await store.query(predicates)
    return CarbonRdb.readRecords(rs)
  }

  /** 按分类过滤 */
  static async recordsOf(userKey: string, category: string): Promise<LocalRecord[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      const out: LocalRecord[] = []
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].category === category) out.push(m.records[i])
      }
      return out
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('category', category)
    predicates.orderByDesc('behavior_time')
    const rs: relationalStore.ResultSet = await store.query(predicates)
    return CarbonRdb.readRecords(rs)
  }

  /** 按 recordId 取单条 */
  static async recordById(userKey: string, recordId: number): Promise<LocalRecord | undefined> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].recordId === recordId) return m.records[i]
      }
      return undefined
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('record_id', recordId)
    const rs: relationalStore.ResultSet = await store.query(predicates)
    const out: LocalRecord[] = CarbonRdb.readRecords(rs)
    return out.length > 0 ? out[0] : undefined
  }

  /** 按 clientRecordId 取单条 */
  static async findByClientId(userKey: string, uuid: string): Promise<LocalRecord | undefined> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].clientRecordId === uuid) return m.records[i]
      }
      return undefined
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('client_record_id', uuid)
    const rs: relationalStore.ResultSet = await store.query(predicates)
    const out: LocalRecord[] = CarbonRdb.readRecords(rs)
    return out.length > 0 ? out[0] : undefined
  }

  /** 分页读记录 */
  static async recordsPage(userKey: string, category: string, offset: number, limit: number): Promise<LocalRecord[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      const out: LocalRecord[] = []
      for (let i: number = 0; i < m.records.length; i++) {
        if (category.length === 0 || m.records[i].category === category) out.push(m.records[i])
      }
      return out.slice(offset, offset + limit)
    }
    let sql: string = 'SELECT * FROM carbon_record WHERE user_key = ?'
    let rs: relationalStore.ResultSet
    if (category.length > 0) {
      sql += ' AND category = ?'
      sql += ' ORDER BY behavior_time DESC, record_id DESC LIMIT ? OFFSET ?'
      rs = await store.querySql(sql, [userKey, category, limit, offset])
    } else {
      sql += ' ORDER BY behavior_time DESC, record_id DESC LIMIT ? OFFSET ?'
      rs = await store.querySql(sql, [userKey, limit, offset])
    }
    return CarbonRdb.readRecords(rs)
  }

  /** 聚合统计（SQL 下推） */
  static async statsAgg(userKey: string, todayStr: string, monthPrefix: string): Promise<RecordAgg> {
    const agg: RecordAgg = {
      totalKg: 0,
      todayKg: 0,
      monthKg: 0,
      totalPoints: 0,
      recordCount: 0
    }
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.records.length; i++) {
        const r: LocalRecord = m.records[i]
        agg.totalKg += r.reduceKg
        agg.totalPoints += r.points
        if (r.dateStr === todayStr) agg.todayKg += r.reduceKg
        if (r.dateStr.indexOf(monthPrefix) === 0) agg.monthKg += r.reduceKg
      }
      agg.recordCount = m.records.length
      return agg
    }
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT COUNT(*) AS cnt, COALESCE(SUM(reduce_kg), 0) AS total_kg, ' +
      'COALESCE(SUM(CASE WHEN date_str = ? THEN reduce_kg ELSE 0 END), 0) AS today_kg, ' +
      'COALESCE(SUM(CASE WHEN date_str LIKE ? THEN reduce_kg ELSE 0 END), 0) AS month_kg, ' +
      'COALESCE(SUM(points), 0) AS total_points FROM carbon_record WHERE user_key = ?',
      [todayStr, monthPrefix + '%', userKey])
    if (rs.goToFirstRow()) {
      agg.recordCount = rs.getLong(rs.getColumnIndex('cnt'))
      agg.totalKg = rs.getDouble(rs.getColumnIndex('total_kg'))
      agg.todayKg = rs.getDouble(rs.getColumnIndex('today_kg'))
      agg.monthKg = rs.getDouble(rs.getColumnIndex('month_kg'))
      agg.totalPoints = rs.getLong(rs.getColumnIndex('total_points'))
    }
    rs.close()
    return agg
  }

  /** 列表页合计口径 */
  static async summaryAgg(userKey: string, category: string): Promise<RecordSummary> {
    const sum: RecordSummary = {
      recordCount: 0,
      dayCount: 0,
      totalKg: 0,
      totalPoints: 0
    }
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      const days: Record<string, boolean> = {}
      for (let i: number = 0; i < m.records.length; i++) {
        const r: LocalRecord = m.records[i]
        if (category.length > 0 && r.category !== category) continue
        sum.recordCount++
        sum.totalKg += r.reduceKg
        sum.totalPoints += r.points
        days[r.dateStr] = true
      }
      sum.dayCount = Object.keys(days).length
      return sum
    }
    let sql: string = 'SELECT COUNT(*) AS cnt, COUNT(DISTINCT date_str) AS days, ' +
      'COALESCE(SUM(reduce_kg), 0) AS kg, COALESCE(SUM(points), 0) AS pts ' +
      'FROM carbon_record WHERE user_key = ?'
    let rs: relationalStore.ResultSet
    if (category.length > 0) {
      sql += ' AND category = ?'
      rs = await store.querySql(sql, [userKey, category])
    } else {
      rs = await store.querySql(sql, [userKey])
    }
    if (rs.goToFirstRow()) {
      sum.recordCount = rs.getLong(rs.getColumnIndex('cnt'))
      sum.dayCount = rs.getLong(rs.getColumnIndex('days'))
      sum.totalKg = rs.getDouble(rs.getColumnIndex('kg'))
      sum.totalPoints = rs.getLong(rs.getColumnIndex('pts'))
    }
    rs.close()
    return sum
  }

  /** 有记录的日期集合 */
  static async distinctDates(userKey: string): Promise<string[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      const set: Record<string, boolean> = {}
      for (let i: number = 0; i < m.records.length; i++) {
        set[m.records[i].dateStr] = true
      }
      return Object.keys(set)
    }
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT DISTINCT date_str FROM carbon_record WHERE user_key = ? ORDER BY date_str DESC',
      [userKey])
    const out: string[] = []
    if (rs.goToFirstRow()) {
      do {
        out.push(rs.getString(rs.getColumnIndex('date_str')))
      } while (rs.goToNextRow())
    }
    rs.close()
    return out
  }

  /** 记录条数 */
  static async countRecords(userKey: string): Promise<number> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.memOf(userKey).records.length
    }
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT COUNT(*) AS cnt FROM carbon_record WHERE user_key = ?',
      [userKey])
    let n: number = 0
    if (rs.goToFirstRow()) {
      n = rs.getLong(rs.getColumnIndex('cnt'))
    }
    rs.close()
    return n
  }

  /** 当前账号最大 recordId */
  static async maxRecordId(userKey: string): Promise<number> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      let max: number = 0
      for (let i: number = 0; i < m.records.length; i++) {
        if (m.records[i].recordId > max) max = m.records[i].recordId
      }
      return max
    }
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT MAX(record_id) AS mx FROM carbon_record WHERE user_key = ?',
      [userKey])
    let max: number = 0
    if (rs.goToFirstRow()) {
      const idx: number = rs.getColumnIndex('mx')
      if (!rs.isColumnNull(idx)) {
        max = rs.getLong(idx)
      }
    }
    rs.close()
    return max
  }

  /* ---------- 兑换券 ---------- */

  private static couponToBucket(userKey: string, c: LocalCoupon): relationalStore.ValuesBucket {
    const vb: relationalStore.ValuesBucket = {
      user_key: userKey,
      coupon_id: c.couponId,
      benefit_code: c.benefitCode,
      benefit_name: c.benefitName,
      benefit_icon: c.benefitIcon,
      points: c.points,
      kind: c.kind,
      issued_at: c.issuedAt,
      expire_at: c.expireAt,
      status: c.status,
      used_at: c.usedAt,
      qr_content: c.qrContent
    }
    return vb
  }

  private static rowToCoupon(rs: relationalStore.ResultSet): LocalCoupon {
    const c: LocalCoupon = {
      couponId: rs.getString(rs.getColumnIndex('coupon_id')),
      benefitCode: rs.getString(rs.getColumnIndex('benefit_code')),
      benefitName: rs.getString(rs.getColumnIndex('benefit_name')),
      benefitIcon: rs.getString(rs.getColumnIndex('benefit_icon')),
      points: rs.getLong(rs.getColumnIndex('points')),
      kind: rs.getString(rs.getColumnIndex('kind')),
      issuedAt: rs.getLong(rs.getColumnIndex('issued_at')),
      expireAt: rs.getLong(rs.getColumnIndex('expire_at')),
      status: rs.getString(rs.getColumnIndex('status')),
      usedAt: rs.getLong(rs.getColumnIndex('used_at')),
      qrContent: rs.getString(rs.getColumnIndex('qr_content'))
    }
    return c
  }

  /** 全部券（领取时间倒序） */
  static async allCoupons(userKey: string): Promise<LocalCoupon[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.memOf(userKey).coupons.slice()
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_coupon')
    predicates.equalTo('user_key', userKey)
    predicates.orderByDesc('issued_at')
    const rs: relationalStore.ResultSet = await store.query(predicates)
    const out: LocalCoupon[] = []
    if (rs.goToFirstRow()) {
      do {
        out.push(CarbonRdb.rowToCoupon(rs))
      } while (rs.goToNextRow())
    }
    rs.close()
    return out
  }

  /** 新增一张券 */
  static async insertCoupon(userKey: string, c: LocalCoupon): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).coupons.unshift(c)
      return
    }
    await store.insert('carbon_coupon', CarbonRdb.couponToBucket(userKey, c))
  }

  /** 更新一张券 */
  static async updateCoupon(userKey: string, c: LocalCoupon): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      for (let i: number = 0; i < m.coupons.length; i++) {
        if (m.coupons[i].couponId === c.couponId) {
          m.coupons[i] = c
          return
        }
      }
      return
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_coupon')
    predicates.equalTo('user_key', userKey)
    predicates.equalTo('coupon_id', c.couponId)
    await store.update(CarbonRdb.couponToBucket(userKey, c), predicates)
  }

  /** 事务内整体替换券 */
  static async replaceCoupons(userKey: string, cps: LocalCoupon[]): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).coupons = cps.slice()
      return
    }
    await store.beginTransaction()
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_coupon')
      predicates.equalTo('user_key', userKey)
      await store.delete(predicates)
      const buckets: Array<relationalStore.ValuesBucket> =
        cps.map((c: LocalCoupon): relationalStore.ValuesBucket => CarbonRdb.couponToBucket(userKey, c))
      if (buckets.length > 0) {
        await store.batchInsert('carbon_coupon', buckets)
      }
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }

  /* ---------- 每日任务领取 ---------- */

  /** 全部领取记录 */
  static async allClaims(userKey: string): Promise<LocalTaskClaim[]> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.memOf(userKey).claims.slice()
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('task_claim')
    predicates.equalTo('user_key', userKey)
    const rs: relationalStore.ResultSet = await store.query(predicates)
    const out: LocalTaskClaim[] = []
    if (rs.goToFirstRow()) {
      do {
        out.push({
          taskCode: rs.getString(rs.getColumnIndex('task_code')),
          dateStr: rs.getString(rs.getColumnIndex('date_str')),
          points: rs.getLong(rs.getColumnIndex('points'))
        })
      } while (rs.goToNextRow())
    }
    rs.close()
    return out
  }

  /** 新增一条领取记录 */
  static async insertClaim(userKey: string, claim: LocalTaskClaim): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).claims.push(claim)
      return
    }
    const vb: relationalStore.ValuesBucket = {
      user_key: userKey,
      task_code: claim.taskCode,
      date_str: claim.dateStr,
      points: claim.points,
      claim_time: Date.now()
    }
    await store.insert('task_claim', vb)
  }

  /** 事务内整体替换领取记录 */
  static async replaceClaims(userKey: string, claims: LocalTaskClaim[]): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).claims = claims.slice()
      return
    }
    await store.beginTransaction()
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('task_claim')
      predicates.equalTo('user_key', userKey)
      await store.delete(predicates)
      const buckets: Array<relationalStore.ValuesBucket> =
        claims.map((c: LocalTaskClaim): relationalStore.ValuesBucket => {
          return {
            user_key: userKey,
            task_code: c.taskCode,
            date_str: c.dateStr,
            points: c.points,
            claim_time: Date.now()
          }
        })
      if (buckets.length > 0) {
        await store.batchInsert('task_claim', buckets)
      }
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }

  /* ---------- 文章互动 ---------- */

  /** 全部互动状态 → { articleId: 状态 } */
  static async articleMap(userKey: string): Promise<Record<string, ArticleInteract>> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.copyArticle(CarbonRdb.memOf(userKey).article)
    }
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('article_interact')
    predicates.equalTo('user_key', userKey)
    const rs: relationalStore.ResultSet = await store.query(predicates)
    const out: Record<string, ArticleInteract> = {}
    if (rs.goToFirstRow()) {
      do {
        const id: number = rs.getLong(rs.getColumnIndex('article_id'))
        out['' + id] = {
          liked: rs.getLong(rs.getColumnIndex('liked')) !== 0,
          faved: rs.getLong(rs.getColumnIndex('faved')) !== 0,
          likeDelta: rs.getLong(rs.getColumnIndex('like_delta'))
        }
      } while (rs.goToNextRow())
    }
    rs.close()
    return out
  }

  private static copyArticle(src: Record<string, ArticleInteract>): Record<string, ArticleInteract> {
    const out: Record<string, ArticleInteract> = {}
    const keys: string[] = Object.keys(src)
    for (let i: number = 0; i < keys.length; i++) {
      out[keys[i]] = src[keys[i]]
    }
    return out
  }

  /** 写入单条互动状态（幂等） */
  static async upsertArticle(userKey: string, articleId: number, st: ArticleInteract): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).article['' + articleId] = st
      return
    }
    await store.executeSql(
      'DELETE FROM article_interact WHERE user_key = ? AND article_id = ?',
      [userKey, articleId])
    await store.executeSql(
      'INSERT INTO article_interact (user_key, article_id, liked, faved, like_delta) VALUES (?, ?, ?, ?, ?)',
      [userKey, articleId, st.liked ? 1 : 0, st.faved ? 1 : 0, st.likeDelta])
  }

  /** 事务内整体替换互动状态 */
  static async replaceArticle(userKey: string, map: Record<string, ArticleInteract>): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).article = CarbonRdb.copyArticle(map)
      return
    }
    await store.beginTransaction()
    try {
      const del: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('article_interact')
      del.equalTo('user_key', userKey)
      await store.delete(del)
      const keys: string[] = Object.keys(map)
      for (let i: number = 0; i < keys.length; i++) {
        const st: ArticleInteract = map[keys[i]]
        await store.executeSql(
          'INSERT INTO article_interact (user_key, article_id, liked, faved, like_delta) VALUES (?, ?, ?, ?, ?)',
          [userKey, parseInt(keys[i]), st.liked ? 1 : 0, st.faved ? 1 : 0, st.likeDelta])
      }
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }

  /* ---------- 备份槽 ---------- */

  /** 写入备份快照（同账号只保留一行） */
  static async saveBackup(userKey: string, payload: string): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      CarbonRdb.memOf(userKey).backup = payload
      return
    }
    await store.executeSql('DELETE FROM backup_slot WHERE user_key = ?', [userKey])
    await store.executeSql(
      'INSERT INTO backup_slot (user_key, payload, backup_time) VALUES (?, ?, ?)',
      [userKey, payload, Date.now()])
  }

  /** 读备份快照 */
  static async loadBackup(userKey: string): Promise<string> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      return CarbonRdb.memOf(userKey).backup
    }
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT payload FROM backup_slot WHERE user_key = ? LIMIT 1',
      [userKey])
    let payload: string = ''
    if (rs.goToFirstRow()) {
      payload = rs.getString(rs.getColumnIndex('payload'))
    }
    rs.close()
    return payload
  }

  /* ---------- 账号级清理 ---------- */

  /** 清空账号业务数据（记录+券+任务领取，不清文章互动） */
  static async clearUser(userKey: string): Promise<void> {
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      m.records = []
      m.coupons = []
      m.claims = []
      return
    }
    await store.beginTransaction()
    try {
      const p1: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
      p1.equalTo('user_key', userKey)
      await store.delete(p1)
      const p2: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_coupon')
      p2.equalTo('user_key', userKey)
      await store.delete(p2)
      const p3: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('task_claim')
      p3.equalTo('user_key', userKey)
      await store.delete(p3)
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }

  /** 事务内整体替换记录+券+可选任务领取（恢复备份用） */
  static async replaceUserData(
    userKey: string,
    recs: LocalRecord[],
    cps: LocalCoupon[],
    claims?: LocalTaskClaim[]
  ): Promise<void> {
    const replaceClaims: boolean = claims !== undefined
    let claimList: LocalTaskClaim[] = []
    if (claims !== undefined) {
      claimList = claims
    }
    const store: relationalStore.RdbStore | null = CarbonRdb.store_
    if (store === null) {
      const m: MemUserData = CarbonRdb.memOf(userKey)
      m.records = recs.slice()
      m.coupons = cps.slice()
      if (replaceClaims) {
        m.claims = claimList.slice()
      }
      return
    }
    await store.beginTransaction()
    try {
      const p1: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_record')
      p1.equalTo('user_key', userKey)
      await store.delete(p1)
      const p2: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('carbon_coupon')
      p2.equalTo('user_key', userKey)
      await store.delete(p2)
      if (replaceClaims) {
        const p3: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('task_claim')
        p3.equalTo('user_key', userKey)
        await store.delete(p3)
      }
      const rBuckets: Array<relationalStore.ValuesBucket> =
        recs.map((r: LocalRecord): relationalStore.ValuesBucket => CarbonRdb.recordToBucket(userKey, r))
      if (rBuckets.length > 0) {
        await store.batchInsert('carbon_record', rBuckets)
      }
      const cBuckets: Array<relationalStore.ValuesBucket> =
        cps.map((c: LocalCoupon): relationalStore.ValuesBucket => CarbonRdb.couponToBucket(userKey, c))
      if (cBuckets.length > 0) {
        await store.batchInsert('carbon_coupon', cBuckets)
      }
      if (replaceClaims) {
        const tBuckets: Array<relationalStore.ValuesBucket> =
          claimList.map((c: LocalTaskClaim): relationalStore.ValuesBucket => {
            return {
              user_key: userKey,
              task_code: c.taskCode,
              date_str: c.dateStr,
              points: c.points,
              claim_time: Date.now()
            }
          })
        if (tBuckets.length > 0) {
          await store.batchInsert('task_claim', tBuckets)
        }
      }
      await store.commit()
    } catch (err) {
      await store.rollBack()
      throw err as Error
    }
  }
}
