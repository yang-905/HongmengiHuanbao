/**
 * 单机版本地数据仓库（唯一数据源）
 * ------------------------------------------------------------------
 * 2026-10-23 数据层重构：Preferences → RDB（relationalStore / SQLite）
 * ------------------------------------------------------------------
 * 旧口径（已废弃）：所有业务数据（记录/券/任务领取/文章互动/备份）都是
 * Preferences 里的大 JSON，整文件加载、整文件重写 —— 记录一多就
 * 「启动慢、内存高、写入贵」。
 * 新口径（本版）：
 *   · **行为记录**（无上限增长）→ RDB `carbon_record`，全部按需查询：
 *     统计走 SQL 聚合下推，列表走 ORDER BY + LIMIT/OFFSET 分页，
 *     单条写走 INSERT/DELETE，不再有任何「全量加载」路径；
 *   · **券 / 任务领取 / 文章互动**（量级小、有同步读 API）→ RDB 表 +
 *     LocalStore 内的内存镜像（init 读入、写穿落库），
 *     `couponStatus` 等同步方法因此不用改签名；
 *   · **备份快照** → RDB `backup_slot` 一行；
 *   · **Preferences 只留少量键值**：种子标记、备份份数、备份时间、
 *     迁移标记（账号表/登录态在 AccountStore，同文件不同键）。
 *
 * 账号隔离：RDB 行级 `user_key` 列（空串 = 未登录兼容命名空间），
 * 取代旧口径的「键名 @账号」后缀。切账号 = 换查询条件，不再需要
 * 会话内数据快照（预览器内存态也按 user_key 分桶，切号不丢）。
 *
 * 对外 API 基本不变；以下方法因「按需读取」改为异步：
 *   stats / allRecords / recordsOf / recordById / hasData /
 *   allForSync / mergeRemote / removeByClientId
 * 调用方全部在 DataSource（本就 async）与 EcoMoodState.refresh
 * （改为 async，浮动 Promise 不影响调用点）。
 */
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

/**
 * Preferences 存储名（与 AccountStore 共用同一文件，键不重叠）。
 * ⚠️ 本文件只往这里写**少量键值**；业务数据一律进 CarbonRdb。
 */
const STORE: string = 'yichu_qinglv'
/** 是否已灌入演示数据（种子标记，按账号隔离） */
const KEY_SEEDED: string = 'local_seeded'
/** 累计备份份数（轻量计数） */
const KEY_BACKUP_COUNT: string = 'local_backup_count'
/** 最近备份时间（轻量文本） */
const KEY_BACKUP_TIME: string = 'local_backup_time'
/**
 * RDB 迁移标记（轻量文本）：'v1' = 该账号命名空间的 Preferences 旧数据
 * 已迁入 RDB 且旧键已回收。未迁移时 init 走一次性迁移（见 migrateIfNeeded）。
 */
const KEY_RDB_MIGRATED: string = 'rdb_migrated'
/** 迁移标记版本 */
const MIGRATED_VER: string = 'v1'
/**
 * 可用积分**持久化余额**（轻量键值，按账号隔离）。
 * ------------------------------------------------------------------
 * 口径由来（2026-10-24 用户实测反馈「删了几条记录后，积分显示 0，
 * 再赚 12000 分却只到 7000 左右」）：
 *   旧口径 available = max(0, 累计获得 − 兑换消耗) 是**每次现算**的。
 *   删记录把「累计获得」砸到「兑换消耗」以下时，账面出现负坑；
 *   负坑不会消失，之后每赚 1 分都先进坑 —— 这就是「分赚不满」的根因。
 * 新口径 = **持久化余额**（随每笔加减写穿落盘）：
 *   · 加分类（记录积分 / 任务奖励 / 跨设备合并插入）：加多少算多少；
 *   · 扣分类（删除记录 / 兑换）：**扣到 0 即止**，超出部分当场抹平，
 *     不留负坑 —— 用户诉求「扣到 0 以后，再扣还是 0」；
 *   · 启动载入本键；首次无键 = 按旧口径迁移一份（负坑在迁移那一刻抹掉）。
 * 为什么必须持久化而不能现算：抹平是**有损**操作，余额取决于历史路径
 * （先赚后删 ≠ 先删后赚），任何「由当前数据重算」的公式都无法复现。
 */
const KEY_POINTS_BALANCE: string = 'points_balance'

/*
 * —— 以下为 Preferences 旧口径的遗留键，仅迁移时读取、读后即删 ——
 * 新代码不得再向这些键写入任何业务数据。
 */
const KEY_RECORDS: string = 'local_records'
const KEY_BACKUP: string = 'local_backup'
const KEY_ARTICLE: string = 'article_interact'
const KEY_COUPONS: string = 'coupons_v1'
const KEY_TASK_CLAIMS: string = 'task_claims_v1'

/**
 * 券有效期：领取后 7 天（ms）。
 * 口径：以**领取时间**起算而非自然日 —— 22:00 领的券也是整整 7×24h，
 * 「7 天后失效」的用户心智与时间戳口径一致，无需处理跨日边界。
 */
const COUPON_TTL: number = 7 * 24 * 60 * 60 * 1000
/** 植树认养权益 code：只有它进证书口径（见 LocalCoupon.kind 注释） */
const TREE_BENEFIT_CODE: string = 'b7'

/**
 * 种子版本标记（写入 KEY_SEEDED 的值）。
 * ------------------------------------------------------------------
 * 老构建曾给**每个注册账号**的命名空间灌演示数据并把标记写成 boolean true，
 * 与「注册账号零起步」的新口径冲突。v2 = 新口径：注册账号命名空间若
 * 标记不是 v2，init 时一次性清洗为空（老脏数据由此自愈），之后不再触发。
 * v3 = 时间口径切换到系统时钟（2026-10-20，见 AppClock）：v2 数据按旧
 * 固定锚点签发，切时钟后全部变成「未来日期」，迁移时按 needTimeShift
 * 分支一次性处理（演示命名空间重灌种子 / 注册账号整体平移时间）。
 * ⚠️ 版本只升不降：比较「是否已清洗」时 v2 与 v3 都算数（见 migrateIfNeeded
 *    与 ensureSeed），否则升级 SEED_VER 会把注册账号的真实数据误清零。
 *    迁移到 RDB 后该标记仍留 Preferences（轻量键值），口径不变。
 */
const SEED_VER: string = 'v3'

/**
 * 开发者模式内置账号（账号 '1'，密码由 AccountStore 持有明文口径）。
 * 该账号的数据命名空间保留演示数据 = 完整演示环境；
 * 普通注册账号一律空数据起步。常量定义在本文件，
 * 避免 AccountStore ↔ LocalStore 循环依赖。
 */
export const DEV_USER: string = '1'

/** 本地用户统计（记录侧聚合 + 券/任务侧派生，全部本地计算，无网络） */
export interface LocalStats {
  totalKg: number
  todayKg: number
  monthKg: number
  totalPoints: number
  /**
   * 可用积分 = **持久化余额**（非现算）：随每笔加减写穿落盘，
   * 删除/兑换扣到 0 即止、负坑当场抹平（口径详见 KEY_POINTS_BALANCE）。
   */
  availablePoints: number
  exchangedPoints: number
  /**
   * 兑换消耗中**认养植树**部分（kind='tree' 的累加）。
   * 证书口径专用：certificatesFrom 只按它推导，
   * 兑换公交券等权益不会顺带冒出证书（口径分离，见 LocalCoupon.kind）。
   */
  treeExchangedPoints: number
  recordCount: number
  continuousDays: number
  treeCount: number
  level: number
  /**
   * 今日任务奖励积分合计（已领取部分）。
   * 与记录积分一并计入 totalPoints —— 任务奖励是真实获得的积分；
   * 可用余额则另走持久化口径（claimTask 时即加进余额，与日期无关），
   * 不混进记录流（记录流驱动分类图表/连续天数等口径）。
   */
  taskPoints: number
}

/**
 * 备份槽结构（v2：记录 + 兑换券一起备份）。
 * v1 旧备份是纯 LocalRecord[] 数组 —— restore() 用 Array.isArray 判别兼容，
 * 老用户升级后恢复不会丢历史备份（见 restore() 注释）。
 * 落点：RDB backup_slot 表（v1 起不再进 Preferences）。
 */
class BackupPayload {
  records: LocalRecord[] = []
  coupons: LocalCoupon[] = []

  constructor(r: LocalRecord[], c: LocalCoupon[]) {
    this.records = r
    this.coupons = c
  }
}

export class LocalStore {
  /*
   * 小数据集内存镜像（init 时从 RDB 读入，写操作同步落库）。
   * 为什么券/任务/互动保留镜像而记录不做：
   *   · 它们量级有界（券 = 用户兑过的，几十张；任务领取 = 每日几条；
   *     文章互动 = 几十篇），全量常驻内存代价可忽略；
   *   · 页面侧存在**同步**读 API（couponStatus / availableCouponCount /
   *     articleState / claimedTaskCodesToday），改异步要动十几个页面；
   *   · 记录是唯一无上限增长的数据集，它的读取全部走 RDB 按需查询，
   *     这正是「规避全量加载」的核心对象。
   */
  /** 文章互动状态内存镜像（init 读库、setter 同步、switchUser 清空） */
  private static articleMap_: Record<string, ArticleInteract> = {}
  /** 兑换券内存镜像（碳惠券包；写穿落 RDB carbon_coupon） */
  private static coupons_: LocalCoupon[] = []
  /** 每日任务领取记录内存镜像（写穿落 RDB task_claim） */
  private static taskClaims_: LocalTaskClaim[] = []
  /**
   * 可用积分余额内存镜像（持久化口径，见 KEY_POINTS_BALANCE）。
   * 与 coupons_ 同范式：init 载入、每笔加减同步改镜像 + 写穿落盘。
   * switchUser 清空 → 下次 init 按新账号的键重载（账号隔离）。
   */
  private static balance_: number = 0
  /**
   * 余额镜像是否已载入（false = 尚未载入）。
   * 预览器无 Preferences 时也为 true（内存推导值即会话最终态）。
   */
  private static balanceLoaded_: boolean = false

  /** 是否已完成初始化（init 幂等闸门） */
  private static loaded_: boolean = false

  /**
   * 当前账号数据命名空间（多账号隔离的核心，RDB 行级 user_key）。
   * ------------------------------------------------------------------
   * 空串 = 未登录/旧数据兼容口径（user_key 为空串，老用户升级不丢数据）；
   * 非空 = 账号名。由 AccountStore 在登录/注册/启动恢复会话时经
   * switchUser() 切换；Index 登录闸门保证「未登录不渲染业务页面」，
   * 所以不存在「页面读到了别的账号数据」的窗口期。
   */
  private static user_: string = ''

  /**
   * Preferences 轻量键的账号隔离：键名拼上账号后缀；未登录保持原键
   * （兼容旧数据）。仅用于种子标记 / 备份计数 / 迁移标记这几个
   * 仍留在 Preferences 的小键 —— 业务数据已改 RDB user_key 列隔离。
   */
  private static keyFor(base: string): string {
    if (LocalStore.user_.length === 0) return base
    return base + '@' + LocalStore.user_
  }

  /* ================= 账号切换 ================= */

  /**
   * 切换账号数据命名空间（AccountStore.setSession / 启动恢复会话调用）。
   * ------------------------------------------------------------------
   * RDB 口径后不再需要会话内快照（旧代码的 userSnap_/couponSnap_ 等）：
   * 数据按 user_key 行级隔离在 SQLite 里，切号只是换查询条件，
   * 切回来重新查即是该账号最新态（含上次落盘失败时的补救写入）；
   * 预览器内存态同样按 user_key 分桶，切号不丢。
   * 最后广播 ecoTick 让已建页面刷新（挂载时机见 AccountStore.setSession
   * 里对 bump 时序的说明 —— 那里的 resetForAccount 才是档位重算的点）。
   */
  static async switchUser(user: string): Promise<void> {
    if (LocalStore.user_ === user && LocalStore.loaded_) return
    LocalStore.user_ = user
    LocalStore.loaded_ = false
    LocalStore.articleMap_ = {}
    LocalStore.coupons_ = []
    LocalStore.taskClaims_ = []
    // 余额镜像同步切换：清空后由下次 init 的 loadBalance 按新账号键重载
    LocalStore.balance_ = 0
    LocalStore.balanceLoaded_ = false
    await LocalStore.init()
    EcoMoodState.bump()
    // 券随账号切换 → 广播券信号，「我的」页角标与券包页重取新账号数据
    LocalStore.bumpCouponTick()
  }

  /** 互动字典浅拷贝（值整体替换式写入，浅拷足够） */
  private static copyArticle(src: Record<string, ArticleInteract>): Record<string, ArticleInteract> {
    const out: Record<string, ArticleInteract> = {}
    const keys: string[] = Object.keys(src)
    for (let i: number = 0; i < keys.length; i++) {
      out[keys[i]] = src[keys[i]]
    }
    return out
  }

  /** 取应用上下文 */
  private static ctx(): common.Context {
    const c: common.Context | undefined = AppStorage.get<common.Context>('appContext')
    if (c === undefined || c === null) {
      throw new Error('应用上下文未初始化')
    }
    return c
  }

  private static async prefs(): Promise<preferences.Preferences> {
    // preferences 读写都可能抛异常（磁盘满、文件损坏、上下文未就绪）。
    // ArkTS 静态检查要求显式处理，这里捕获后转成语义化错误再抛出，
    // 调用方的 try/catch 会走内存兜底，不会让页面崩掉。
    try {
      return await preferences.getPreferences(LocalStore.ctx(), STORE);
    } catch (err) {
      throw new Error('本机存储不可用');
    }
  }

  /* ================= 初始化 ================= */

  /**
   * 启动初始化：打开 RDB →（首次）迁移 Preferences 旧数据 → 读小数据集
   * 镜像 → 按口径灌演示种子。必须在 EntryAbility 或页面首次加载时调用一次。
   * 幂等：loaded_ 后直接返回。
   */
  static async init(): Promise<void> {
    if (LocalStore.loaded_) return
    try {
      await CarbonRdb.open(LocalStore.ctx())
    } catch (err) {
      // 上下文未就绪（预览器页面级预览）：CarbonRdb 保持 store_=null → 内存态
    }
    try {
      await LocalStore.migrateIfNeeded()
      // 小数据集镜像（券 / 任务领取 / 文章互动）同批读入内存
      LocalStore.articleMap_ = await CarbonRdb.articleMap(LocalStore.user_)
      LocalStore.coupons_ = await CarbonRdb.allCoupons(LocalStore.user_)
      LocalStore.taskClaims_ = await CarbonRdb.allClaims(LocalStore.user_)
      await LocalStore.ensureSeed()
    } catch (err) {
      // 读盘失败也要保证演示命名空间有数据可用（只对未登录/开发者账号灌种子）
      if (LocalStore.user_.length === 0 || LocalStore.user_ === DEV_USER) {
        await LocalStore.seedDemo()
      }
    }
    /*
     * 余额镜像**最后**载入：必须晚于 ensureSeed / 种子兜底 ——
     * 演示种子刚灌入的记录积分要计入首次迁移出来的余额，
     * 早于种子载入会让演示账号首启余额为 0。
     */
    await LocalStore.loadBalance()
    LocalStore.loaded_ = true
  }

  /**
   * Preferences → RDB 一次性迁移（幂等，按账号命名空间独立执行）。
   * ------------------------------------------------------------------
   * 步骤：读旧键 → 沿用旧 init 的清洗口径（注册账号清零 / 时间平移 /
   * 补同步字段）→ 写入 RDB（各自带事务）→ 删除旧大 JSON 键回收体积 →
   * 打迁移标记。任一步失败即抛出：旧键保留、标记不写，下次启动重试，
   * 不会出现「数据迁了一半」的中间态。
   * 标记已就绪 / 无旧数据 / 无 Preferences（预览器）时静默跳过。
   */
  private static async migrateIfNeeded(): Promise<void> {
    let p: preferences.Preferences
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      return // 预览器无 Preferences：没有旧数据可迁
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
    /*
     * 「是否已清洗」兼容口径：v2 / v3 版本串都视为已清洗过。
     * ⚠️ 不能只比 SEED_VER —— v2 → v3 升级时，只比 v3 会让带 v2 标记的
     *    注册账号重新踩中「老脏数据清零」分支，把用户的真实记录删掉。
     */
    const cleaned: boolean = typeof rawSeeded === 'string' &&
      (rawSeeded === 'v2' || rawSeeded === SEED_VER)
    const needTimeShift: boolean = typeof rawSeeded === 'string' && rawSeeded === 'v2'
    const isReg: boolean = LocalStore.user_.length > 0 && LocalStore.user_ !== DEV_USER

    // —— 记录：清洗后整体入 RDB ——
    let recs: LocalRecord[] = LocalStore.parseRecords(recJson)
    if (recs.length > 0) {
      // 老数据懒迁移：补齐跨设备同步所需字段（与旧 init 同一时点执行）
      LocalStore.ensureSyncFields(recs)
      if (isReg && !cleaned) {
        // 注册账号 + 未清洗标记（v2 之前的 boolean true / 空）= 老构建
        // 灌入的演示脏数据 → 一次性清零
        recs = []
      } else if (needTimeShift) {
        if (isReg) {
          // 注册账号：保留记录内容，时间整体平移回系统时钟
          LocalStore.shiftRecords(recs)
        } else {
          // 演示命名空间：旧锚点种子没有保留价值 → 置空，
          // 由 ensureSeed 按「无记录 + 未灌种子」口径重灌（相对真实今天）
          recs = []
        }
      }
    }
    // —— 券 / 任务领取 / 文章互动：原样迁移（券同样按差量平移时间）——
    let cps: LocalCoupon[] = LocalStore.parseCoupons(cpJson)
    if (needTimeShift && cps.length > 0) {
      LocalStore.shiftCouponArray(cps)
    }
    const tcs: LocalTaskClaim[] = LocalStore.parseClaims(tcJson)
    const art: Record<string, ArticleInteract> = LocalStore.parseArticle(artJson)

    // —— 写入 RDB（任一失败抛出，旧键不删，下次重试）——
    await CarbonRdb.replaceRecords(LocalStore.user_, recs)
    await CarbonRdb.replaceCoupons(LocalStore.user_, cps)
    await CarbonRdb.replaceClaims(LocalStore.user_, tcs)
    await CarbonRdb.replaceArticle(LocalStore.user_, art)
    if (backupJson.length > 0) {
      await CarbonRdb.saveBackup(LocalStore.user_, backupJson)
    }

    // —— 回收 Preferences 体积：大 JSON 键全部删除，只留迁移标记 ——
    await p.delete(LocalStore.keyFor(KEY_RECORDS))
    await p.delete(LocalStore.keyFor(KEY_COUPONS))
    await p.delete(LocalStore.keyFor(KEY_TASK_CLAIMS))
    await p.delete(LocalStore.keyFor(KEY_ARTICLE))
    await p.delete(LocalStore.keyFor(KEY_BACKUP))
    await LocalStore.markMigrated(p)
  }

  /** 打迁移标记（轻量键值，随 Preferences 文件保留） */
  private static async markMigrated(p: preferences.Preferences): Promise<void> {
    await p.put(LocalStore.keyFor(KEY_RDB_MIGRATED), MIGRATED_VER)
    await p.flush()
  }

  /* ================= 可用积分持久化余额 ================= */

  /**
   * 载入余额镜像（init 末尾调用一次，幂等由 init 的 loaded_ 闸门保证）。
   * ------------------------------------------------------------------
   * 三条路径：
   *   ① 键存在（≥0）→ 直接采用：持久化余额口径，历史负坑已在过去各次
   *      写入时被抹平（删到 0 即止，见 subBalance）；
   *   ② 键不存在 → 旧口径一次性迁移：按当前数据算 max(0, 获得−消耗)
   *      落一份。历史负坑在迁移这一刻被抹掉 —— 这正是用户诉求的
   *      「扣到 0 就停住，不留负数坑」；正常用户（无负坑）迁移值
   *      与旧口径完全一致，无感升级；
   *   ③ 预览器无 Preferences → 内存推导值（不持久化，会话内仍正确，
   *      与文章互动等小键的预览器降级口径一致）。
   * ⚠️ 默认值用 **-1** 而不是 0：preferences 的默认值在「键缺失」与
   *    「键 = 默认值」两种场景下不可区分，用 -1 才能识别首次迁移
   *    （余额合法值恒 ≥0）。
   */
  private static async loadBalance(): Promise<void> {
    let p: preferences.Preferences | null = null
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      p = null // 预览器：Preferences 不可用，余额走内存推导
    }
    if (p !== null) {
      const raw: number = (await p.get(LocalStore.keyFor(KEY_POINTS_BALANCE), -1)) as number
      if (raw >= 0) {
        LocalStore.balance_ = raw
        LocalStore.balanceLoaded_ = true
        return
      }
    }
    // 无键 / 预览器：按旧口径迁移值兜底（负坑在此抹平）
    LocalStore.balance_ = await LocalStore.computeLegacyBalance()
    LocalStore.balanceLoaded_ = true
    if (p !== null) {
      // 迁移落盘：之后每笔增减都写穿，负坑不会再出现
      await LocalStore.saveBalance(p)
    }
  }

  /**
   * 旧口径余额（一次性迁移 / 预览器兜底专用）：
   * 累计获得（记录积分 + 今日任务奖励）− 兑换消耗，钳 0。
   * ------------------------------------------------------------------
   * ⚠️ 不调 stats() 出口：迁移发生在 init 尾部、早于任何 stats() 调用，
   *    而 stats() 首行就是 await init() —— 直接调会递归init（loaded_
   *    还是 false）。这里按同源口径内联重算。
   */
  private static async computeLegacyBalance(): Promise<number> {
    try {
      const agg: RecordAgg = await CarbonRdb.statsAgg(LocalStore.user_,
        AppClock.dateStr(), AppClock.monthStr())
      const earned: number = agg.totalPoints + LocalStore.taskPointsToday()
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

  /**
   * 余额写穿落盘（best-effort）：镜像已由调用方改好，这里只负责持久化。
   * 失败只影响重启后的恢复，本次会话镜像态照常可用 —— 与
   * setArticleState 的小键降级口径一致（磁盘满/文件损坏是极端场景）。
   */
  private static async saveBalance(p?: preferences.Preferences): Promise<void> {
    let prefsObj: preferences.Preferences | null = p === undefined ? null : p
    if (prefsObj === null) {
      try {
        prefsObj = await LocalStore.prefs()
      } catch (err) {
        return // 预览器：无 Preferences，内存态即最终态
      }
    }
    try {
      await prefsObj.put(LocalStore.keyFor(KEY_POINTS_BALANCE), LocalStore.balance_)
      await prefsObj.flush()
    } catch (err) {
      // ignore：持久化失败不阻塞业务（镜像仍是会话内真值）
    }
  }

  /**
   * 余额加项（记录积分 / 任务奖励 / 跨设备合并插入）：加多少算多少。
   * 调用方须保证在对应业务落库成功之后调用（落库失败不加分）。
   */
  private static async addBalance(delta: number): Promise<void> {
    LocalStore.balance_ += delta
    await LocalStore.saveBalance()
  }

  /**
   * 余额扣项（删除记录 / 兑换消耗 / 跨设备删除）：**扣到 0 即止**。
   * ------------------------------------------------------------------
   * 用户诉求（2026-10-24）：「扣到 0 以后，再扣还是 0」。删除把余额砸到
   * 0 以下时，超出部分**当场抹平**（不记负坑）—— 之后赚的每一分都从 0
   * 起算。旧口径现算 max(0, 获得−消耗) 的负坑会永久吞掉后续积分，
   * 这就是「删了记录再赚 12000 分只到 7000」的根因。
   */
  private static async subBalance(delta: number): Promise<void> {
    const next: number = LocalStore.balance_ - delta
    LocalStore.balance_ = next > 0 ? next : 0
    await LocalStore.saveBalance()
  }

  /**
   * 余额整体重置（清空数据 / 演示种子 / 备份恢复后按快照重算）。
   * 用于「整体替换」类操作：增量加减不适用（旧余额可能与新快照无关）。
   */
  private static async setBalance(v: number): Promise<void> {
    LocalStore.balance_ = v > 0 ? v : 0
    await LocalStore.saveBalance()
  }

  /**
   * 种子策略（多账号口径，与旧版一致）：
   *   · 注册账号（非访客兼容命名空间、非开发者）= 零起步，只补版本标记；
   *   · 未登录兼容命名空间 / 开发者账号 = 无记录且未灌过种子时灌演示数据。
   * 老口径 boolean true 与新版本串都视为已灌过，避免重复灌。
   */
  private static async ensureSeed(): Promise<void> {
    let p: preferences.Preferences | null = null
    try {
      p = await LocalStore.prefs()
    } catch (err) {
      p = null // 预览器：种子照灌（内存态），只是不写标记
    }
    const rawSeeded: Object = p === null ? '' : (await p.get(LocalStore.keyFor(KEY_SEEDED), '')) as Object
    const seededV3: boolean = typeof rawSeeded === 'string' && rawSeeded === SEED_VER
    const isReg: boolean = LocalStore.user_.length > 0 && LocalStore.user_ !== DEV_USER
    if (isReg) {
      // 注册账号零起步：确保标记就绪（后续重启不再触发清洗/灌种子判断）
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

  /** 灌入 30 天演示数据，让各页面首启即有内容（RDB 事务内整体替换） */
  private static async seedDemo(): Promise<void> {
    const arr: LocalRecord[] = MockStore.records()
    await CarbonRdb.replaceRecords(LocalStore.user_, arr)
    /*
     * 余额按种子记录积分**整体重算**（不用增量）：种子是整体替换语义，
     * 调用点（ensureSeed 首启 / restoreDemo 恢复演示）的旧余额与新快照
     * 无关。种子无兑换券，余额 = 种子记录积分合计。
     * 演示命名空间的余额键在此首次落盘 → loadBalance 之后直接采用。
     */
    let pts: number = 0
    for (let i: number = 0; i < arr.length; i++) {
      pts += arr[i].points
    }
    await LocalStore.setBalance(pts)
  }

  /**
   * 旧锚点（AppClock v2 及以前的固定演示时间）：2026-11-20 12:00:00 本地时区。
   * 仅用于 v2 → v3 一次性时间迁移的差量计算，迁移完成后不再引用。
   */
  private static readonly OLD_ANCHOR_MS: number = new Date(2026, 10, 20, 12, 0, 0).getTime()

  /**
   * 时间口径一次性迁移（v2 → v3）：按旧锚点签发的数据整体平移到系统时钟。
   * ------------------------------------------------------------------
   * 背景（2026-10-20 用户要求「日期时间全用系统时间 API 同步」，见 AppClock）：
   * v2 数据的日期相对设备时钟全是**未来值** —— 今日/本月统计为空、趋势图
   * 出现未来分桶、券显示 30+ 天后失效。
   * 做法：按「旧锚点 → 真实当前时间」的差量整体平移，保留相对间隔：
   *   delta = OLD_ANCHOR_MS - Date.now();  新值 = 旧值 - delta
   * 记录平移 behaviorTime / dateStr（同源重算，只改一半会对不上统计分桶）；
   * 券平移 issuedAt / expireAt / usedAt（数值戳）。
   * ⚠️ qrContent 是核销凭证快照（历史凭据），不回改；
   * ⚠️ recordId / updateTime 是 ID 与同步戳，不平移（与时间口径无关）；
   * ⚠️ 解析失败回退当前时间的记录（timeOf 兜底）平移后会落在未来 ——
   *    用「平移结果不超过当前时间 + 1min」识别并跳过。
   */
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

  /**
   * 券时间戳整体平移（差量同 shiftRecords）。
   * 单独抽出：演示命名空间重灌种子时记录换新、券是用户兑换所得资产要保留，
   * 只平移券的时间（见 migrateIfNeeded 的 needTimeShift 分支）。
   */
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

  /** 时间戳平移 delta 毫秒后格式化为 'yyyy-MM-dd HH:mm:ss'（迁移辅助） */
  private static shiftStr(ts: number, delta: number): string {
    const d: Date = new Date(ts - delta)
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
      ' ' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds())
  }

  /* ================= 旧数据解析（迁移专用，容错返回空） ================= */

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

  /* ================= 文章互动（点赞/收藏持久化） ================= */

  /**
   * 取单篇文章的互动状态（无记录返回默认值）。
   * 同步读内存镜像，页面/数据源可直接调用。
   */
  static articleState(articleId: number): ArticleInteract {
    const st: ArticleInteract | undefined = LocalStore.articleMap_['' + articleId]
    if (st !== undefined && st !== null) {
      return st
    }
    return { liked: false, faved: false, likeDelta: 0 }
  }

  /**
   * 写入互动状态：内存镜像同步 + 落库（best-effort）+ 广播 articleTick。
   * 广播让列表页/收藏页自动重拉数据（「点赞收藏自动刷新」的信号源），
   * 详情页自己是写方、手动维护状态，无需订阅。
   * 落库失败只影响重启后的恢复，本次会话镜像态照常可用。
   */
  static setArticleState(articleId: number, liked: boolean, faved: boolean, likeDelta: number): void {
    LocalStore.articleMap_['' + articleId] = { liked: liked, faved: faved, likeDelta: likeDelta }
    CarbonRdb.upsertArticle(LocalStore.user_, articleId,
      { liked: liked, faved: faved, likeDelta: likeDelta }).catch((): void => {})
    const t: number | undefined = AppStorage.get<number>('articleTick')
    AppStorage.setOrCreate<number>('articleTick', (t === undefined ? 0 : t) + 1)
  }

  /**
   * 把互动状态合并进文章列表（原地修改，返回同引用）。
   * DataSource.articles() 统一调用 —— 列表页/收藏页/详情页拿到的
   * favorite / likeCount 自动带上用户的互动增量，页面代码零改动。
   */
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

  /* ================= 读（全部按需查 RDB，无全量加载路径） ================= */

  /**
   * 全部记录（behavior_time 倒序，索引排序）。
   * ⚠️ 异步：数据在 RDB 里按需查，不再有内存全量副本。
   * 图表/统计类全量消费仍走本方法（一次查询）；列表类消费请用
   * recordsPage 分页，避免记录涨到几千条时一次全捞。
   */
  static async allRecords(): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await CarbonRdb.allRecords(LocalStore.user_)
  }

  /**
   * 分页读记录（列表「加载更多」数据源）。
   * category 传空串表示全部；offset/limit 下推 SQL LIMIT/OFFSET。
   */
  static async recordsPage(category: string, offset: number, limit: number): Promise<LocalRecord[]> {
    await LocalStore.init()
    return await CarbonRdb.recordsPage(LocalStore.user_, category, offset, limit)
  }

  /** 按分类过滤（传空串表示全部） */
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

  /**
   * 列表页合计口径（全量筛选结果，SQL 聚合下推）。
   * ------------------------------------------------------------------
   * 与 recordsPage 配套：列表按页读，合计必须是**全量**的，
   * 否则记录多的时候合计会随翻页变大（数字一直跳）。
   * category 传空串表示全部。
   */
  static async recordsSummary(category: string): Promise<RecordSummary> {
    await LocalStore.init()
    return await CarbonRdb.summaryAgg(LocalStore.user_, category)
  }

  /* ================= 写 ================= */

  /**
   * 新增一条行为记录（减排量与积分端侧按因子核算，与服务端口径一致）。
   * ------------------------------------------------------------------
   * 落库顺序（与旧口径相反，刻意为之）：旧口径是「先广播后落盘」，
   * 因为 Preferences 在预览器里会抛异常/挂起，广播不能依赖落盘结果；
   * RDB 单行 INSERT 是真正的持久化动作 —— 失败即未保存，此时若广播
   * 会让页面显示一条并不存在的记录。所以：INSERT 成功才广播，
   * 失败抛错由调用方提示「保存失败」（DataSource/页面已有 toast 兜底）。
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
    await LocalStore.init()
    const kg: number = Math.round(factorValue * amount * 1000) / 1000
    const pts: number = Biz.pointsOf(kg)
    // 时间口径（本地时间校准，见 AppClock）：记录日期/时间与统计分桶同源，
    // 都取系统时钟。
    // ⚠️ recordId / updateTime 仍用真实 Date.now()：它们是 ID 与跨设备
    // LWW 同步戳，需要毫秒级唯一性与单调性，不能随时间口径调整而漂移
    // （入口语义与 AppClock 分开，防止未来再引入时间口径时同会话撞号）。
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
    // 落库成功才加余额：INSERT 失败即未保存，不能出现「记录没有、积分到了」
    await LocalStore.addBalance(pts)
    LocalStore.syncEcoMood()
    return rec
  }

  /** 删除一条记录（积分与统计随之回退） */
  static async removeRecord(recordId: number): Promise<boolean> {
    await LocalStore.init()
    // 先取到被删记录的积分：余额扣减按「这一笔实际加了的分」扣，
    // 扣到 0 即止（负坑当场抹平，见 subBalance）
    const rec: LocalRecord | undefined = await CarbonRdb.recordById(LocalStore.user_, recordId)
    const ok: boolean = await CarbonRdb.deleteRecord(LocalStore.user_, recordId)
    if (ok) {
      if (rec !== undefined && rec !== null) {
        await LocalStore.subBalance(rec.points)
      }
      // 与 addRecord 同口径：删除落库成功后广播，页面即时重拉
      LocalStore.syncEcoMood()
    }
    return ok
  }

  /**
   * 广播当前碳情绪档位到全局。
   *
   * 实现说明（踩坑记录）：
   *   最初用「注入刷新函数」切断循环引用，但 **ArkTS 严格模式不支持把
   *   函数类型用作字段/参数类型**（报 Unexpected token /
   *   arkts-no-untyped-obj-literals），写成 `(x: void): void` 也不行。
   *   最终方案：只推进一个自增信号（EcoMoodState 内部持有），
   *   编译期依赖单向（LocalStore → EcoMoodState），不会成环；
   *   真正判档由订阅方（EntryAbility / 各页面 @Watch）执行。
   */
  /** 通知情绪层「记录变了，请重算档位」 */
  private static syncEcoMood(): void {
    EcoMoodState.bump()
  }

  /* ================= 跨设备（超级终端）合并 ================= */

  /** 老数据懒迁移：补齐 clientRecordId / updateTime / syncFlag（原地修改入参数组） */
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

  /**
   * 'yyyy-MM-dd HH:mm:ss' → 毫秒时间戳（解析失败回退当前时间）。
   * 回退值走 AppClock（本地时间校准口径）：与其他业务日期同源。
   */
  private static timeOf(s: string): number {
    if (s.length === 0) return AppClock.now()
    const t: number = new Date(s.replace(/-/g, '/')).getTime()
    return isNaN(t) ? AppClock.now() : t
  }

  /**
   * 合并一条来自其他设备的记录（幂等）：
   * - 按 clientRecordId 去重，updateTime 新者胜（LWW）
   * - 只同步原始记录；积分、等级、连续天数等派生值一律本地重算
   * 返回 'inserted' | 'updated' | 'ignored'
   */
  static async mergeRemote(rec: LocalRecord): Promise<string> {
    await LocalStore.init()
    if (rec === undefined || rec === null) return 'ignored'
    const uuid: string | undefined = rec.clientRecordId
    if (uuid === undefined || uuid.length === 0) return 'ignored'
    const old: LocalRecord | undefined = await CarbonRdb.findByClientId(LocalStore.user_, uuid)
    if (old === undefined || old === null) {
      // 撞号防护：本地已存在更大 recordId 时重新分配（Date.now() 跨设备
      // 可能取到同一毫秒，直接插入会出现主键视角的重复号）
      const maxId: number = await CarbonRdb.maxRecordId(LocalStore.user_)
      if (rec.recordId <= maxId) {
        rec.recordId = maxId + 1
      }
      rec.syncFlag = 'synced'
      await CarbonRdb.insertRecord(LocalStore.user_, rec)
      // 合并插入 = 本地新增一条记录：余额按该笔积分加
      await LocalStore.addBalance(rec.points)
      LocalStore.syncEcoMood()
      return 'inserted'
    }
    const oldU: number = old.updateTime !== undefined ? old.updateTime : 0
    const newU: number = rec.updateTime !== undefined ? rec.updateTime : 0
    if (newU <= oldU) return 'ignored'
    rec.syncFlag = 'synced'
    await CarbonRdb.updateRecord(LocalStore.user_, rec)
    /*
     * LWW 更新可能改写积分（同一行为重新识别出不同数量）：余额按差值调整。
     * 差值为负走扣项（扣到 0 即止，与删除同口径）；为正走加项。
     */
    const diff: number = rec.points - old.points
    if (diff > 0) {
      await LocalStore.addBalance(diff)
    } else if (diff < 0) {
      await LocalStore.subBalance(-diff)
    }
    LocalStore.syncEcoMood()
    return 'updated'
  }

  /** 按 clientRecordId 删除（对端删除事件落地），返回是否删到 */
  static async removeByClientId(uuid: string): Promise<boolean> {
    await LocalStore.init()
    if (uuid.length === 0) return false
    // 先取被删记录的积分（余额扣减口径同 removeRecord：扣到 0 即止）
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

  /** 供近场推送的原始记录快照（含 clientRecordId） */
  static async allForSync(): Promise<LocalRecord[]> {
    return await LocalStore.allRecords()
  }

  /** 清空全部数据（设置页「清空数据」用：记录 + 券 + 任务领取，单事务） */
  static async clear(): Promise<void> {
    await LocalStore.init()
    await CarbonRdb.clearUser(LocalStore.user_)
    // 券同步清空：不清的话「清空数据」后可用积分口径与券包自相矛盾
    LocalStore.coupons_ = []
    // 任务领取记录同理：清空后已领状态要回到「待领取」，否则积分口径对不上
    LocalStore.taskClaims_ = []
    // 余额整体归零：记录/券/任务都没了，持久化余额同步清零
    // （负坑更不该留 —— 清空就是「全新开始」）
    await LocalStore.setBalance(0)
    // 广播让各页重拉：记录列表/看板/积分页立即反映「已清空」
    LocalStore.syncEcoMood()
  }

  /** 恢复演示数据（事务内整体替换记录） */
  static async restoreDemo(): Promise<void> {
    await LocalStore.init()
    await LocalStore.seedDemo()
    LocalStore.syncEcoMood()
  }

  /* ================= 备份 / 恢复 ================= */

  private static nowText(): string {
    // 时间口径（本地时间校准，见 AppClock）：备份时间展示与记录同源
    return AppClock.dateTimeStr()
  }

  /**
   * 备份：把当前记录 + 券快照写入 RDB 备份槽，返回累计备份份数。
   * 份数与时间是轻量键值，仍走 Preferences；快照本身进 RDB
   * （备份大小随数据增长，不能再放 Preferences）。
   */
  static async backup(): Promise<number> {
    // preferences 与 RDB 的读写都可能抛异常（磁盘满、文件损坏等）。
    // ArkTS 要求显式处理，这里捕获后转成语义化错误再抛出，
    // 调用方原有的 .catch() 仍能正常收到失败通知。
    try {
      const p: preferences.Preferences = await LocalStore.prefs()
      const recs: LocalRecord[] = await LocalStore.allRecords()
      // v2 格式：记录 + 兑换券一起备份（只备份记录会让恢复后券包清空、
      // 可用积分口径回跳 —— 兑换过的券是真实资产，必须进备份）
      await CarbonRdb.saveBackup(LocalStore.user_,
        JSON.stringify(new BackupPayload(recs, LocalStore.coupons_.slice())))
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
      /*
       * 备份格式双兼容：
       *   v1（旧构建）= 纯 LocalRecord[] 数组 → 券按空列表恢复；
       *   v2（本版）  = BackupPayload {records, coupons}。
       * 用 Array.isArray 判别，别用 try/catch 探形状 —— 解析失败要走
       * 外层 catch 转「恢复失败」，探形状会把真错误吞掉。
       */
      const parsed: Object = JSON.parse(json) as Object
      let recs: LocalRecord[] = []
      let cps: LocalCoupon[] = []
      if (Array.isArray(parsed)) {
        recs = parsed as LocalRecord[]
      } else {
        const payload: BackupPayload = parsed as BackupPayload
        recs = payload.records
        cps = payload.coupons
      }
      if (recs === undefined || recs === null || recs.length === 0) {
        throw new Error('备份内容为空')
      }
      if (cps === undefined || cps === null) {
        cps = []
      }
      // 跨表单事务：记录与券要么整体恢复、要么整体回滚
      await CarbonRdb.replaceUserData(LocalStore.user_, recs, cps)
      LocalStore.coupons_ = cps
      /*
       * 余额按恢复后的快照**整体重算**（不用增量）：备份是整账户快照，
       * 恢复前的余额与新快照无关。口径与 loadBalance 的首次迁移一致 ——
       * max(0, 记录积分合计 + 今日任务奖励 − 券积分合计)，负坑当场抹平。
       * 任务领取不在备份内，但当前会话的今日领取仍算数（已领 = 已到账）。
       */
      await LocalStore.setBalance(await LocalStore.computeLegacyBalance())
      return recs.length
    } catch (err) {
      throw new Error('恢复失败：' + ((err as Error).message ?? '本机存储不可用'))
    }
  }

  /** 最近备份时间（从未备份返回空串） */
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

  /** 是否已有数据（COUNT(*) 查询，不捞数据） */
  static async hasData(): Promise<boolean> {
    await LocalStore.init()
    return await CarbonRdb.countRecords(LocalStore.user_) > 0
  }

  /* ================= 派生统计（记录侧 SQL 下推，全部本地计算，无网络） ================= */

  /**
   * 累计统计。
   * ------------------------------------------------------------------
   * 记录侧口径（累计/今日/本月减排、累计积分、条数）由 CarbonRdb.statsAgg
   * 一条 SQL 条件聚合出，不把记录捞进内存；连续天数取 DISTINCT 日期集；
   * 券消耗与任务奖励来自小数据集内存镜像（有界，常驻可忽略）。
   */
  static async stats(): Promise<LocalStats> {
    // 时间口径（本地时间校准，见 AppClock）：今日/本月分桶与录入日期同源
    await LocalStore.init()
    const todayStr: string = AppClock.dateStr()
    const monthPrefix: string = AppClock.monthStr()

    const agg: RecordAgg = await CarbonRdb.statsAgg(LocalStore.user_, todayStr, monthPrefix)
    const dates: string[] = await CarbonRdb.distinctDates(LocalStore.user_)

    /*
     * 任务奖励积分并入 earned（2026-10-23）：每日任务奖励是**真实可用积分**，
     * 必须计入累计获得与可用余额，否则「领取成功却一分没到账」。
     * 口径分离：它不混进记录流 —— 记录流驱动分类图表/连续天数/等级等，
     * 塞进任务奖励会让「步行 2 次」这类图表口径失真。
     */
    const taskPts: number = LocalStore.taskPointsToday()
    const earned: number = agg.totalPoints + taskPts

    // ⚠️ 口径沿革（两次整改，用户反馈驱动）：
    //   ① 旧逻辑 available = earned − floor(earned/POINTS_PER_TREE)×POINTS_PER_TREE，
    //      把「每 3000 分 ≈ 一棵树」的**等价折算**当成了**真实扣分** ——
    //      添加记录一旦跨过 200 的边界，可用积分不增反降（如 195 分时加一条
    //      +10 分记录 → 只剩 5 分），用户视角就是「记了一笔，积分反而少了」。
    //   ② 再改为现算 max(0, 累计获得 − 实际兑换消耗)：兑换消耗 = 券流水逐笔
    //      累加（exchange 写入）；无任何兑换时累加值为 0。但「现算」仍有负坑
    //      —— 删记录把获得砸到消耗以下后，坑不消失、永久吞掉后续积分。
    //   ③ 本轮（2026-10-24）定稿：**持久化余额**，见下方 availablePoints
    //      注释与 KEY_POINTS_BALANCE 口径。兑换消耗仍按券流水累加，供
    //      exchangedPoints / 证书推导使用（与余额口径分离）。
    // 口径分离：其中认养植树（kind='tree'）的部分才进证书推导，
    //   兑换公交券等权益不产生证书（见 LocalCoupon.kind）。
    let exchanged: number = 0
    let treeExchanged: number = 0
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      const cp: LocalCoupon = LocalStore.coupons_[i]
      exchanged += cp.points
      if (cp.kind === 'tree') {
        treeExchanged += cp.points
      }
    }
    // ⚠️ 口径对齐（用户反馈「植树棵数 2 棵，证书夹却没有证书」）：
    //   treeCount 必须与植树证书**同源** —— 只统计真实兑换出的树
    //   （每 POINTS_PER_TREE 分兑换 1 棵 = 1 张证书），
    //   不再用「累计获得积分的等价折算」充数；等价折算展示一律走 Biz.treesOf()。
    const treeCount: number = Math.floor(treeExchanged / Biz.POINTS_PER_TREE)

    return {
      totalKg: Math.round(agg.totalKg * 100) / 100,
      // ⚠️ 除数必须是 1000（保留 3 位小数）：曾误写成 / 100，
      // 0.19 kg 被放大成 1.90（round(0.19*1000)=190，190/1000=0.19 ✓）
      todayKg: Math.round(agg.todayKg * 1000) / 1000,
      monthKg: Math.round(agg.monthKg * 100) / 100,
      totalPoints: earned,
      /*
       * ⚠️ 可用积分 = **持久化余额**（2026-10-24 用户反馈整改，口径详见
       *   KEY_POINTS_BALANCE 注释）：随每笔加减写穿的余额镜像，删除扣到
       *   0 即止、负坑当场抹平 —— 之后赚的每一分都从 0 起算。
       *   旧口径是这里现算 max(0, earned − exchanged)：删记录把 earned
       *   砸到 exchanged 以下后负坑不消失，永久吞掉后续积分（实测
       *   「删几条记录 → 显示 0 → 再赚 12000 只到 7000」）。
       * 镜像由 init 尾部的 loadBalance 载入（首次按旧口径迁移落盘），
       *   增删改入口全部写穿（addRecord / removeRecord / claimTask /
       *   exchange / clear / restore / seedDemo / merge*）。
       * balanceLoaded_ 为 false 只可能是极端降级路径（init 未跑完）：
       *   兜底退回旧口径现算，至少不会显示未定义。
       */
      availablePoints: LocalStore.balanceLoaded_ ? LocalStore.balance_ : Math.max(0, earned - exchanged),
      exchangedPoints: exchanged,
      treeExchangedPoints: treeExchanged,
      taskPoints: taskPts,
      recordCount: agg.recordCount,
      continuousDays: LocalStore.calcStreak(dates),
      treeCount: treeCount,
      level: Biz.levelOf(agg.totalKg)
    }
  }

  /* ================= 每日任务领取 ================= */

  /**
   * 某任务今天是否已领取。
   * 只认「今天」的记录：任务每日重置，昨天领的不算今天领过。
   */
  static taskClaimed(taskCode: string): boolean {
    const today: string = AppClock.dateStr()
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      const c: LocalTaskClaim = LocalStore.taskClaims_[i]
      if (c.taskCode === taskCode && c.dateStr === today) return true
    }
    return false
  }

  /** 今天已领取的任务 code 列表（供 tasksFrom 推导 claimed 状态） */
  static claimedTaskCodesToday(): string[] {
    const today: string = AppClock.dateStr()
    const out: string[] = []
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      const c: LocalTaskClaim = LocalStore.taskClaims_[i]
      if (c.dateStr === today && out.indexOf(c.taskCode) < 0) out.push(c.taskCode)
    }
    return out
  }

  /**
   * 领取任务奖励（幂等）。
   * ------------------------------------------------------------------
   * 修复「点完还是待领取」：原实现只把页面内存里的 status 改成 claimed，
   * 既不落库、也没给账户加积分 —— 而 status 每次都由
   * tasksFrom 按 progress>=target 重算，于是刷新/重进页面立刻回弹。
   * 现在：落库（RDB task_claim，镜像同步写）+ 加进持久化余额
   *   （addBalance，与日期无关 —— 领到的分不会因为过了一天而蒸发），
   *   并广播 ecoTick 让首页/积分页同步。
   *
   * @return true=本次真实发放；false=今天已领过（不重复发）
   */
  static async claimTask(taskCode: string, points: number): Promise<boolean> {
    // 先 init：taskClaims_ 镜像就绪后才能判「今天领过没有」
    await LocalStore.init()
    if (LocalStore.taskClaimed(taskCode)) return false
    const claim: LocalTaskClaim = {
      taskCode: taskCode,
      dateStr: AppClock.dateStr(),
      points: points
    }
    LocalStore.taskClaims_.push(claim)
    await CarbonRdb.insertClaim(LocalStore.user_, claim)
    // 任务奖励是真实可用积分：落库成功才加余额（口径同 addRecord）
    await LocalStore.addBalance(points)
    return true
  }

  /** 今日任务奖励积分合计（已领取部分） */
  static taskPointsToday(): number {
    const today: string = AppClock.dateStr()
    let s: number = 0
    for (let i = 0; i < LocalStore.taskClaims_.length; i++) {
      if (LocalStore.taskClaims_[i].dateStr === today) s += LocalStore.taskClaims_[i].points
    }
    return s
  }

  /* ================= 兑换券（碳惠券包） ================= */

  /**
   * 全部券（含已使用/已过期），按领取时间倒序。
   * 返回副本：页面拿到的是快照，避免 ForEach 期间被写入改动数组。
   * 同步读内存镜像（券量级有界，见类注释）。
   */
  static allCoupons(): LocalCoupon[] {
    return LocalStore.coupons_.slice()
  }

  /** 单张券（找不到返回 null） */
  static couponById(couponId: string): LocalCoupon | null {
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      if (LocalStore.coupons_[i].couponId === couponId) {
        return LocalStore.coupons_[i]
      }
    }
    return null
  }

  /**
   * 券的实时状态：'unused' / 'used' / 'expired'。
   * expired 由时间推导不落盘：过期本质是「now 到达 expireAt」的比较，
   * 写成持久状态反而要在每次启动时批量翻牌，容易漏。
   * ⚠️ 边界用 >= 而非 >：expireAt 是**第一个失效时刻**——恰好到期那刻
   * 必须判 expired，与 daysLeft（剩余 0 天）口径一致；用 > 会出现
   * 「券面显示 0 天后失效、却仍可点击使用」的自相矛盾状态。
   */
  static couponStatus(c: LocalCoupon): string {
    if (c.status === 'used') return 'used'
    // 时间口径（本地时间校准，见 AppClock）：与 exchange() 的 now 同源，
    // 都取系统时钟 —— 过期判断不会与券面倒计时对不上
    return AppClock.now() >= c.expireAt ? 'expired' : 'unused'
  }

  /** 可用券数（未使用且未过期）——「我的」页「碳惠券包」入口角标 */
  static availableCouponCount(): number {
    let n: number = 0
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      if (LocalStore.couponStatus(LocalStore.coupons_[i]) === 'unused') n++
    }
    return n
  }

  /**
   * 兑换权益 → 生成券（积分商城确认弹窗的落地点）。
   * ------------------------------------------------------------------
   * 事务口径：校验余额（stats 聚合下推）→ 生成券入队 + 落库 →
   * 返回新券。落库失败抛错：兑换是资产操作，不能「内存生效、磁盘丢失」
   * （旧口径的 best-effort 是为 Preferences 预览器 flakiness 兜底，
   * RDB 单行 INSERT 失败应如实上报，调用方 toast 兜底）。
   *
   * @return 成功返回新券；积分不足返回 null（调用方 toast 兜底）
   */
  static async exchange(benefit: LocalBenefit): Promise<LocalCoupon | null> {
    const s: LocalStats = await LocalStore.stats()
    if (s.availablePoints < benefit.points) return null
    // 时间口径（本地时间校准，见 AppClock）：签发/失效/券号时间戳全按系统时钟
    const now: number = AppClock.now()
    const cp: LocalCoupon = {
      couponId: 'CP-' + LocalStore.couponStamp(now) + '-' + LocalStore.rand4(),
      benefitCode: benefit.benefitCode,
      benefitName: benefit.benefitName,
      benefitIcon: benefit.icon,
      points: benefit.points,
      // 只有公益植树认养进证书口径，其余权益券不产生证书
      kind: benefit.benefitCode === TREE_BENEFIT_CODE ? 'tree' : 'coupon',
      issuedAt: now,
      expireAt: now + COUPON_TTL,
      status: 'unused',
      usedAt: 0,
      qrContent: ''
    }
    LocalStore.coupons_.unshift(cp)
    await CarbonRdb.insertCoupon(LocalStore.user_, cp)
    // 兑换 = 资产操作：券落库成功后扣余额。闸门（上面 availablePoints
    // 校验）保证余额 ≥ 券面，扣后不会为负；真出现异常也只是会话内数字，
    // 不阻断已生成的券（券已是真实资产）。
    await LocalStore.subBalance(benefit.points)
    return cp
  }

  /**
   * 确认使用券：状态置 used + 当场生成核销二维码内容（「假二维码」）。
   * ------------------------------------------------------------------
   * payload 为**中文感谢语 + 精简凭证字段**的多行纯文本而不是 URL
   * （URL 会跳到不存在的域名、显示错误页，不可取），格式与容量
   * 红线见 buildQr 注释 —— v0 六段式中文长文本约 200 字节，码图
   * 模块过密，微信/相机扫不出任何内容（2026-10-21 用户反馈）。
   * 时间口径走 AppClock（本地时间校准）：核销时间与 usedAt 同源。
   * 已使用的券重复进入返回同一 qrContent（幂等，可回看，旧格式现场补发）。
   *
   * @return 二维码内容；券不存在返回 null；已过期返回 null（不可用）
   */
  static async useCoupon(couponId: string): Promise<string | null> {
    for (let i: number = 0; i < LocalStore.coupons_.length; i++) {
      const c: LocalCoupon = LocalStore.coupons_[i]
      if (c.couponId !== couponId) continue
      if (LocalStore.couponStatus(c) === 'expired') return null
      if (c.status === 'used') {
        // 幂等回看：已使用过 → 返回已生成的内容（空串/旧中文格式由
        // ensureQrContent 现场补生成，见其注释）
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

  /**
   * 核销二维码内容：英文感谢语 + 精简凭证字段（**单行纯 ASCII**）。
   * ------------------------------------------------------------------
   * 微信扫纯文本码的结果页 UI 归微信，我们只能控制文本本身。
   * ⚠️ 格式红线（2026-10-21 四轮实测校准）：
   *   · v0 多行中文长文本 ~200 字节 → 码图过密，扫不出任何内容；
   *   · v1 单行纯 ASCII ~70 字节 → 秒扫，微信文本结果页正常展示（实测）；
   *   · v2 多行中文 + 🌱 emoji ~160 字节 → 码能解出，微信报「不支持演示该效果」；
   *   · v3 **单行**纯中文 ~155 字节 → 仍报「不支持演示该效果」（用户实测）
   *     —— 与 v1 的差异只剩「字符集」：微信文本结果页对**中文内容**
   *     走拒绝路径，此场景只能用 ASCII（机理未公开，实测结论如此）；
   *   · 本版（v4）= 英文感谢语两句 + 英文短标签字段，单行空格分隔，
   *     ~146 字节（与 v3 字节数相当，码图密度不变，可扫性同 v2/v3）。
   *   往码里加字前先数字节：内容超容量整体升版、模块暴涨，是官方
   *   FAQ 里「扫不出」的首因；行首勿放 emoji/特殊符号。
   * 字段口径：Coupon（券号）| Code（核销码，rand6）| Time（系统时钟）|
   * Valid to（有效期至）。
   */
  private static buildQr(c: LocalCoupon, code: string, redeemedAt: number): string {
    const d: Date = new Date(redeemedAt)
    return 'Thanks for living low-carbon! Thanks for greening the city!' +
      ' Coupon ' + c.couponId +
      ' Code ' + code +
      ' Time ' + AppClock.fmtDate(d) + ' ' + AppClock.fmtTime(d) +
      ' Valid to ' + AppClock.fmtDate(new Date(c.expireAt))
  }

  /**
   * 确保已核销券持有**当前格式**核销凭证内容（历史数据兜底，幂等）。
   * ------------------------------------------------------------------
   * 旧数据在凭证页/幂等回看时现场重生成并落库：
   *   · 空串 —— 更早期构建核销的券根本没有 qrContent 字段；
   *   · 非 'Thanks for living' 开头 —— 旧格式内容（v0 中文长文本
   *     '【碳惠券…' 扫不出、v1 ASCII 短串无感谢语、v2 多行中文+🌱 与
   *     v3 单行中文均被微信结果页拒绝），统一补生成 v4 英文版。
   * 核销时间沿用 usedAt（保持凭证页大字时间与码内一致）；usedAt
   * 异常为 0 时兜底当前时间。未核销券原样返回（空串）。
   */
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

  /**
   * 递增券变更信号（兑换/核销/切账号后调用）。
   * 订阅方：「我的」页入口角标、券包页列表。
   * 与 ecoTick 同范式：setOrCreate 而非 set（预览器没有 EntryAbility 预建键）。
   */
  static bumpCouponTick(): void {
    const t: number | undefined = AppStorage.get<number>('couponTick')
    AppStorage.setOrCreate<number>('couponTick', (t === undefined ? 0 : t) + 1)
  }

  /** 券号时间戳部分：YYYYMMDDHHmmss（本地时区，与 nowText 同口径） */
  private static couponStamp(now: number): string {
    const d: Date = new Date(now)
    const p = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString())
    return '' + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) +
      p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
  }

  /** 4 位随机串（券号后缀，保证同一秒兑换多张也不重号） */
  private static rand4(): string {
    const n: number = Math.floor(Math.random() * 10000)
    return (n < 1000 ? '0' : '') + (n < 100 ? '0' : '') + (n < 10 ? '0' : '') + n.toString()
  }

  /** 6 位随机核销码（确认使用时生成，扫码结果的「随机」部分） */
  private static rand6(): string {
    const n: number = Math.floor(Math.random() * 1000000)
    const s: string = (n < 100000 ? '0' : '') + (n < 10000 ? '0' : '') + (n < 1000 ? '0' : '') +
      (n < 100 ? '0' : '') + (n < 10 ? '0' : '') + n.toString()
    return s
  }

  /**
   * 连续打卡天数：从今天（或昨天）起往回数有记录的连续天数。
   * 入参为 DISTINCT 日期集合（SQL 下推，最多天数行），不再全量扫描记录。
   */
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
    // 今天没记录则从昨天起算，避免白天未打卡就显示断签
    // 时间口径（本地时间校准，见 AppClock）：与演示种子日期同源
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
