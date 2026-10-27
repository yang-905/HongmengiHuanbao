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
  static get online(): boolean {
    return true
  }

  static async ready(): Promise<void> {
    await LocalStore.init()
  }

  /* 总览 / 统计 */

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

  /* 因子库 */

  static async factors(): Promise<LocalFactor[]> {
    return MockStore.factors()
  }

  /* 记录 */

  static async records(): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.allRecords()
  }

  static async recordsOf(category: string): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.recordsOf(category)
  }

  static async recordsPage(category: string, offset: number, limit: number): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await LocalStore.recordsPage(category, offset, limit)
  }

  static async recordsSummary(category: string): Promise<RecordSummary> {
    await LocalStore.init()
    return await LocalStore.recordsSummary(category)
  }

  /* 任务 */

  static async tasks(): Promise<LocalTask[]> {
    await LocalStore.init()
    return MockStore.tasksFrom(await LocalStore.allRecords(), LocalStore.claimedTaskCodesToday())
  }

  /* 徽章 / 积分 / 证书 */

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
    return MockStore.certificatesFrom(LocalStore.treeCoupons())
  }

  /* 权益 */

  static async benefits(): Promise<LocalBenefit[]> {
    return MockStore.benefits()
  }

  static async coupons(): Promise<LocalCoupon[]> {
    await LocalStore.init()
    return LocalStore.allCoupons()
  }

  /* 科普 */

  static async articles(): Promise<LocalArticle[]> {
    await LocalStore.init()
    return LocalStore.applyArticleInteract(MockStore.articles())
  }

  /* 智慧服务 */

  static async focusTask(): Promise<LocalFocusTask> {
    await LocalStore.init()
    return MockStore.focusFrom(await LocalStore.allRecords())
  }

  static async smartTips(): Promise<LocalSmartTip[]> {
    await LocalStore.init()
    return MockStore.tipsFrom(await LocalStore.allRecords())
  }

  /* 超级终端（纯单机模式） */

  static async devices(): Promise<LocalDevice[]> {
    await LocalStore.init()
    return MockStore.devices()
  }

  static async familyMembers(): Promise<LocalMember[]> {
    await LocalStore.init()
    return MockStore.membersFrom(await LocalStore.stats())
  }

  /* 写入（直接落本地库） */

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
    EcoMoodState.broadcastDataChange()
    return rec
  }

  static async removeRecord(recordId: number): Promise<boolean> {
    const ok: boolean = await LocalStore.removeRecord(recordId)
    if (ok) {
      EcoMoodState.broadcastDataChange()
    }
    return ok
  }

  /* AI 识别 */

  static async recognize(imageUri: string): Promise<LocalRecord | undefined> {
    return MockStore.recognize(imageUri)
  }

  /* 本地纯计算 */

  static async shareText(): Promise<string> {
    return MockStore.shareText(await LocalStore.stats())
  }
}
