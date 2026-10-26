/**
 * 数据源（单机版：纯本地，无任何网络请求）
 * ------------------------------------------------------------------
 * 本工程已明确「不使用云服务器」，因此这里彻底移除了 HTTP 层。
 *
 * 改造原因：原实现每个接口先发请求、超时 10 秒后才降级本地，
 * 导致每次进页面都要空转 10 秒（商城页甚至一直转圈）。
 * 现在改为从 LocalStore 读取，await 一次立即返回。
 *
 * 存储口径（2026-10-23 RDB 化）：行为记录等业务数据在 RDB（SQLite）
 * 按需查询/分页读取；轻量键值（登录态、种子标记、备份计数）在
 * Preferences。方法名与原版保持一致，页面无需改动。
 */
import { LocalStore, LocalStats } from '../data/LocalStore'
import { RecordSummary } from '../data/rdb/CarbonRdb'
import { EcoMoodState } from '../data/EcoMoodState'
import { MockStore } from '../data/MockStore'
import {
  LocalArticle,
  LocalBadge,
  LocalBenefit,
  LocalCert,
  LocalCoupon,
  LocalDevice,
  LocalFactor,
  LocalFocusTask,
  LocalMember,
  LocalOverview,
  LocalPointsLog,
  LocalRecord,
  LocalSmartTip,
  LocalTask,
  TrendPoint
} from '../data/MockStore'

export class DataSource {
  /**
   * 单机版固定本地可用。
   * 保留该字段以兼容页面里已有的「演示模式」角标逻辑。
   */
  static get online(): boolean {
    return true
  }

  /**
   * 页面统一入口：确保本地库已加载。
   * 首次调用读盘（或灌入演示数据），之后命中内存，耗时接近 0。
   */
  static async ready(): Promise<void> {
    await LocalStore.init()
  }

  /* ================= 总览 / 统计 ================= */

  static async overview(): Promise<LocalOverview> {
    await LocalStore.init()
    const s: LocalStats = await LocalStore.stats()
    return {
      totalKg: s.totalKg,
      todayKg: s.todayKg,
      monthKg: s.monthKg,
      totalPoints: s.totalPoints,
      availablePoints: s.availablePoints,
      exchangedPoints: s.exchangedPoints,
      recordCount: s.recordCount,
      continuousDays: s.continuousDays,
      treeCount: s.treeCount,
      badgeCount: 0,
      level: s.level
    }
  }

  static async trend(granularity: string): Promise<TrendPoint[]> {
    await LocalStore.init()
    return MockStore.trendFrom(await LocalStore.allRecords(), granularity)
  }

  static async categoryStats(days: number): Promise<LocalRecord[]> {
    await LocalStore.init()
    return MockStore.categoryStatsFrom(await LocalStore.allRecords(), days)
  }

  /* ================= 因子库 ================= */

  static async factors(): Promise<LocalFactor[]> {
    return MockStore.factors()
  }

  /* ================= 记录 ================= */

  static async records(): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.allRecords()
  }

  static async recordsOf(category: string): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.recordsOf(category)
  }

  /**
   * 分页读记录（列表「加载更多」）。
   * category 传空串 = 全部；offset/limit 下推 SQL LIMIT/OFFSET，
   * 记录涨到几千条时首屏也只读一页（RDB 按需读取的核心路径）。
   */
  static async recordsPage(category: string, offset: number, limit: number): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.recordsPage(category, offset, limit)
  }

  /**
   * 列表页合计（全量筛选结果，SQL 聚合）。
   * 与 recordsPage 配套：列表按页读、合计按全量算，
   * 避免「翻一页合计涨一截」的口径错误。
   */
  static async recordsSummary(category: string): Promise<RecordSummary> {
    await LocalStore.init()
    return await LocalStore.recordsSummary(category)
  }

  /* ================= 任务 ================= */

  static async tasks(): Promise<LocalTask[]> {
    await LocalStore.init()
    // 传入今天已领取的任务（LocalStore 持久化），status 才能算成 claimed
    return MockStore.tasksFrom(await LocalStore.allRecords(), LocalStore.claimedTaskCodesToday())
  }

  /* ================= 徽章 / 积分 / 证书 ================= */

  static async badges(): Promise<LocalBadge[]> {
    await LocalStore.init()
    const s: LocalStats = await LocalStore.stats()
    return MockStore.badgesBy(s.totalKg, s.recordCount, s.continuousDays, s.treeCount)
  }

  static async pointsLogs(): Promise<LocalPointsLog[]> {
    await LocalStore.init()
    return MockStore.pointsLogsFrom(await LocalStore.allRecords())
  }

  static async certificates(): Promise<LocalCert[]> {
    await LocalStore.init()
    // 口径与 pointsLogs 一致：证书从真实兑换消耗推导（未兑换 → 空列表 → 证书夹空态引导）。
    // ⚠️ 只取 treeExchangedPoints（认养植树部分）—— 用总 exchangedPoints 会让
    //    兑换公交券等权益也顺带生成植树证书，两类资产口径必须分离。
    return MockStore.certificatesFrom((await LocalStore.stats()).treeExchangedPoints)
  }

  /* ================= 权益 ================= */

  static async benefits(): Promise<LocalBenefit[]> {
    return MockStore.benefits()
  }

  /**
   * 兑换券列表（碳惠券包页数据源）。
   * ------------------------------------------------------------------
   * 与 certificates() 的「推导式」不同，券是**落盘的真实资产**
   * （LocalStore.coupons_ 镜像 + RDB carbon_coupon 表），直接全量返回副本，
   *  newest-first（exchange 时 unshift 到队首）。
   * 'expired' 不落盘：由调用方按 LocalStore.couponStatus 现算，
   * 避免过期态写死后再也翻不了身（见 LocalStore 该函数注释）。
   */
  static async coupons(): Promise<LocalCoupon[]> {
    await LocalStore.init()
    return LocalStore.allCoupons()
  }

  /* ================= 科普 ================= */

  static async articles(): Promise<LocalArticle[]> {
    // 合并用户互动状态（点赞 delta / 收藏标记，LocalStore 持久化）：
    // 列表页 / 收藏页 / 详情页统一从这里拿数据，互动结果全库自动联动。
    await LocalStore.init()
    return LocalStore.applyArticleInteract(MockStore.articles())
  }

  /* ================= 智慧服务 ================= */

  static async focusTask(): Promise<LocalFocusTask> {
    await LocalStore.init()
    return MockStore.focusFrom(await LocalStore.allRecords())
  }

  static async smartTips(): Promise<LocalSmartTip[]> {
    await LocalStore.init()
    return MockStore.tipsFrom(await LocalStore.allRecords())
  }

  /* ================= 超级终端（纯单机模式） ================= */
  /*
   * 说明：近场分布式同步模块（sync/SyncEngine + distributed/DeviceKit）
   * 已从工程移除，本应用现为**纯单机版**——数据只落本地 RDB，
   * 不做任何组网与跨设备同步。原「未就绪时回落演示数据」的语义依然成立：
   * 设备列表直接取 MockStore 演示数据，页面无感。
   */

  static async devices(): Promise<LocalDevice[]> {
    await LocalStore.init()
    return MockStore.devices()
  }

  static async familyMembers(): Promise<LocalMember[]> {
    await LocalStore.init()
    return MockStore.membersFrom(await LocalStore.stats())
  }

  /* ================= 写入（单机版：直接落本地库） ================= */

  /**
   * 记录一条低碳行为 —— 这是「行为记录」功能的真正落地点。
   * 写入后立即可被 records() 读到，列表刷新即可看到。
   */
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
    const rec: LocalRecord = await LocalStore.addRecord(
      itemId, itemCode, itemName, icon, category, unit, amount, factorValue, source, remark
    )
    /*
     * ⚠️ 数据层兜底广播（用户诉求「每次上传记录后自动刷新」）。
     *
     * 早前广播只写在调用方（BehaviorAddSheet.submit）里，属于「谁写谁负责」：
     * 任何新增的写入路径（比如以后加的批量导入、AI 识别落库）若忘了广播，
     * 首页就静默显示旧数据，且没有任何报错，极难排查。
     *
     * 写入路径是**唯一**的真相来源 —— 数据落库的同一处广播，
     * 才是真正可靠的做法。调用方那处broadcastDataChange() 保留无害
     * （bump 自增，重复调用只是多推一次 tick，不影响正确性）。
     */
    EcoMoodState.broadcastDataChange()
    // 纯单机：写入即完成，无需跨设备同步
    return rec
  }

  static async removeRecord(recordId: number): Promise<boolean> {
    const ok: boolean = await LocalStore.removeRecord(recordId)
    // 删除同样会让首页的统计口径变化（累计减排、记录条数、等级）
    if (ok) {
      EcoMoodState.broadcastDataChange()
    }
    return ok
  }

  /* ================= AI 识别（端侧本地引擎） ================= */

  static async recognize(imageUri: string): Promise<LocalRecord | undefined> {
    return MockStore.recognize(imageUri)
  }

  /* ================= 本地纯计算 ================= */

  /**
   * 分享文案（2026-10-23 改异步：统计改由 RDB 聚合查询按需得出）。
   * 调用方两处：智慧建议页（入屏时载入 @State）+ 两处复制按钮
   * （.then 链式处理），均已适配。
   */
  static async shareText(): Promise<string> {
    return MockStore.shareText(await LocalStore.stats())
  }
}