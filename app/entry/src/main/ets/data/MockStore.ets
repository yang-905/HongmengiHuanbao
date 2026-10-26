/**
 * 本地演示数据仓库（兜底层）
 * ------------------------------------------------------------------
 * 设计目的：后端未启动 / 网络不可达时，App 依然能呈现完整界面，
 *           便于设计与评审。所有结构与后端 Carbon* 域对象一一对应。
 *
 * 数据特征：
 * - 使用确定性伪随机（同一 seed 每次结果一致），避免每次进入页面数据乱跳
 * - 减排量、积分严格按 Biz 口径换算
 * - 27 项因子与后端种子数据完全一致
 */
import { Biz } from '../ui/Theme';
import { LocalStats } from './LocalStore';
import { AppClock } from '../utils/AppClock';

/** 确定性伪随机：FNV-1a → [0,1) */
function hash01(s: string): number {
  let h: number = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = (h * 16777619) >>> 0;
  }
  return (h % 10000) / 10000;
}

/** 今日日期字符串（本地时间校准，见 AppClock：跟随系统时钟） */
function today(): string {
  return AppClock.dateStr();
}

function dateOffset(days: number): string {
  return AppClock.fmtDate(AppClock.offsetDays(days));
}

function pad(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

/** ---- 数据模型（对应后端字段，驼峰） ---- */

export interface LocalFactor {
  itemId: number;
  itemCode: string;
  category: string;
  itemName: string;
  unit: string;
  factorValue: number;
  inputHint: string;
  defaultAmount: number;
  stepNum: number;
  icon: string;
  status: string;
}

export interface LocalRecord {
  recordId: number;
  itemId: number;
  itemCode: string;
  itemName: string;
  icon: string;
  category: string;
  amount: number;
  unit: string;
  reduceKg: number;
  points: number;
  behaviorTime: string;
  dateStr: string;
  recordSource: string;
  remark: string;
  /** 全局唯一键：跨设备同步与后端幂等共用（老数据由 LocalStore 启动时懒迁移补齐） */
  clientRecordId?: string;
  /** 最近修改时间戳：跨设备合并时「新者胜」的依据 */
  updateTime?: number;
  /** 同步标记 local / synced（仅作状态展示，不参与合并判定） */
  syncFlag?: string;
}

export interface LocalTask {
  taskId: number;
  taskCode: string;
  taskName: string;
  taskDesc: string;
  icon: string;
  category: string;
  targetType: string;
  targetValue: number;
  rewardPoints: number;
  progress: number;
  status: string;
}

/**
 * 单条任务领取记录（每日任务奖励的落库单元）。
 * ------------------------------------------------------------------
 * 带 dateStr 而非只存 code：任务每日重置，用领取日期做键，
 * 跨天自然失效（今天查「今天领过没有」只比对今天的记录），
 * 不需要额外的清空逻辑，也不会把昨天的领取算进今天。
 * 落库表：RDB task_claim（见 CarbonRdb）。
 */
export interface LocalTaskClaim {
  /** 任务 code（与 LocalTask.taskCode 对应） */
  taskCode: string;
  /** 领取日期 yyyy-MM-dd（AppClock 口径） */
  dateStr: string;
  /** 本次发放的奖励积分（用于累计今日任务积分） */
  points: number;
}

export interface LocalBadge {
  badgeId: number;
  badgeCode: string;
  badgeName: string;
  icon: string;
  description: string;
  metric: string;
  category: string;
  threshold: number;
  unlocked: boolean;
  unlockDate: string;
}

export interface LocalArticle {
  articleId: number;
  title: string;
  category: string;
  icon: string;
  summary: string;
  content: string;
  readCount: number;
  likeCount: number;
  readMinutes: number;
  isTop: boolean;
  favorite: boolean;
}

/**
 * 单篇文章的互动状态（用户诉求「点赞收藏要保存记录」）。
 * ------------------------------------------------------------------
 * MockStore 的文章是纯静态演示数据（favorite 固定前 3 篇、likeCount 固定），
 * 详情页点赞/收藏只改页面内存的话，重进页面/重启应用就打回原形。
 * 这里把互动增量按账号落盘（RDB article_interact 表，见 CarbonRdb）：
 *   · liked / faved —— 布尔状态本身；
 *   · likeDelta —— 相对 MockStore 基准数的点赞偏移（+1/-1），
 *     展示值 = 基准 + delta，基准不落盘（跟演示数据走）。
 */
export interface ArticleInteract {
  liked: boolean
  faved: boolean
  likeDelta: number
}

export interface LocalBenefit {
  benefitId: number;
  benefitCode: string;
  benefitName: string;
  points: number;
  description: string;
  icon: string;
}

/**
 * 兑换券（积分商城兑换的权益券，「碳惠券包」页的数据单元）。
 * ------------------------------------------------------------------
 * 与植树证书（LocalCert）的关系：
 *   · 证书 = 兑换消耗中**认养植树**部分的派生视图（certificatesFrom 按积分推导）；
 *   · 券   = 权益兑换部分的**流水实体**，本身即持久化对象。
 * 两者共用 LocalStore 的兑换流水，但口径分离：
 *   · kind='coupon'（公交券/门票/月卡…）只进可用积分扣减，不产生证书；
 *   · kind='tree'（公益植树认养 b7）同时进证书口径，证书自动生成。
 *
 * status 只落盘 'unused' / 'used'：'expired' 由 couponStatus() 按时间推导，
 * 避免「过期态写死后再也翻不了身」——实际产品里过期就是时间比较，不是状态机。
 */
export interface LocalCoupon {
  /** 券唯一号：'CP-' + 领取时间戳 + 随机串 */
  couponId: string;
  /** 来源权益 code（b1~b8） */
  benefitCode: string;
  /** 权益名（冗余存储：权益下架后已兑换的券仍可展示） */
  benefitName: string;
  /** 权益图标 emoji */
  benefitIcon: string;
  /** 兑换消耗积分 */
  points: number;
  /** 券类型：'coupon' 权益券 / 'tree' 植树认养（进证书口径） */
  kind: string;
  /** 领取时间戳（ms） */
  issuedAt: number;
  /** 过期时间戳（ms）= issuedAt + 7 天 */
  expireAt: number;
  /** 使用状态：'unused' / 'used'（'expired' 不落盘，见接口注释） */
  status: string;
  /** 使用时间戳（ms），0 = 未使用 */
  usedAt: number;
  /** 核销二维码内容（确认使用时生成；'' = 未生成） */
  qrContent: string;
}

export interface LocalCert {
  certId: number;
  certNo: string;
  treeType: string;
  treeCount: number;
  costPoints: number;
  ownerName: string;
  issueDate: string;
}

export interface LocalPointsLog {
  logId: number;
  changeType: string;
  points: number;
  balanceAfter: number;
  remark: string;
  createTime: string;
}

export interface LocalDevice {
  deviceId: number;
  deviceCode: string;
  deviceName: string;
  deviceModel: string;
  deviceType: string;
  online: boolean;
  todayReduction: number;
  lastSyncTime: string;
}

export interface LocalMember {
  memberId: number;
  memberName: string;
  avatar: string;
  role: string;
  deviceName: string;
  online: boolean;
  reduction: number;
  points: number;
  count: number;
  isSelf: boolean;
}

export interface LocalSmartTip {
  id: string;
  icon: string;
  title: string;
  content: string;
}

export interface LocalFocusTask {
  category: string;
  taskCode: string;
  icon: string;
  title: string;
  desc: string;
}

export interface LocalOverview {
  totalKg: number;
  todayKg: number;
  monthKg: number;
  totalPoints: number;
  availablePoints: number;
  /**
   * 真实兑换消耗（券流水逐笔累加，与 LocalStats.exchangedPoints 同源）。
   * ⚠️ 不能用 totalPoints − availablePoints 反推：可用积分是**持久化余额**，
   *   删记录把余额砸到 0 时超出部分被当场抹平（用户诉求「扣到 0 就停住」），
   *   反推值会小于真实兑换消耗（2026-10-24 口径整改，见 LocalStore）。
   */
  exchangedPoints: number;
  recordCount: number;
  continuousDays: number;
  treeCount: number;
  badgeCount: number;
  level: number;
}

export interface TrendPoint {
  label: string;
  kg: number;
  points: number;
}

/**
 * 本地数据仓库
 */
export class MockStore {
  /* ---------- 27 项行为因子（与后端种子一致） ---------- */
  static factors(): LocalFactor[] {
    const raw: string[][] = [
      // travel 绿色出行 6
      ['walk', '步行出行', 'travel', '公里', '0.19', '1', '🚶'],
      ['bike', '骑行出行', 'travel', '公里', '0.19', '1', '🚴'],
      ['bus', '公交出行', 'travel', '公里', '0.10', '5', '🚌'],
      ['metro', '地铁出行', 'travel', '公里', '0.12', '5', '🚇'],
      ['evcar', '新能源汽车', 'travel', '公里', '0.10', '10', '🔋'],
      ['carpool', '拼车合乘', 'travel', '公里', '0.10', '10', '🚗'],
      // energy 节水节电 6
      ['elec', '节约用电', 'energy', '度', '0.785', '1', '⚡'],
      ['water', '节约用水', 'energy', '升', '0.0009', '50', '💧'],
      ['gas', '节约燃气', 'energy', '立方米', '2.1', '1', '🔥'],
      ['paper', '节约用纸', 'energy', '张', '0.015', '20', '📄'],
      ['ac26', '空调26℃', 'energy', '次', '0.5', '1', '🌡️'],
      ['unplug', '随手断电', 'energy', '次', '0.3', '1', '🔌'],
      // recycle 旧物回收 8
      ['paper_waste', '废纸回收', 'recycle', '千克', '1.3', '1', '📰'],
      ['plastic', '塑料回收', 'recycle', '千克', '2.7', '1', '🧴'],
      ['metal', '金属回收', 'recycle', '千克', '8.0', '1', '🥫'],
      ['glass', '玻璃回收', 'recycle', '千克', '0.85', '1', '🍾'],
      ['clothes', '旧衣回收', 'recycle', '千克', '6.0', '1', '👕'],
      ['ewaste', '电子废弃物', 'recycle', '千克', '5.0', '1', '📱'],
      ['donate', '旧物捐赠', 'recycle', '件', '3.5', '1', '🎁'],
      ['secondhand', '二手转卖', 'recycle', '件', '4.0', '1', '🔄'],
      // food 光盘行动 7
      ['clearplate', '光盘行动', 'food', '餐', '0.8', '1', '🍽️'],
      ['veggie', '素食一餐', 'food', '次', '1.5', '1', '🥗'],
      ['lunchbox', '自带餐盒', 'food', '次', '0.15', '1', '🥡'],
      ['bag', '自带购物袋', 'food', '次', '0.05', '1', '🛍️'],
      ['cup', '自带水杯', 'food', '次', '0.1', '1', '🥤'],
      ['nochopsticks', '拒一次性餐具', 'food', '次', '0.08', '1', '🥢'],
      ['classify', '垃圾分类', 'food', '次', '0.2', '1', '🗑️']
    ];
    const out: LocalFactor[] = [];
    for (let i = 0; i < raw.length; i++) {
      const r: string[] = raw[i];
      out.push({
        itemId: i + 1,
        itemCode: r[0],
        category: r[2],
        itemName: r[1],
        unit: r[3],
        factorValue: parseFloat(r[4]),
        inputHint: '请输入' + r[3] + '数量',
        defaultAmount: parseFloat(r[5]),
        stepNum: 1,
        icon: r[6],
        status: '0'
      });
    }
    return out;
  }

  /* ---------- 行为记录：近 30 天 ---------- */
  static records(): LocalRecord[] {
    const factors: LocalFactor[] = MockStore.factors();
    const out: LocalRecord[] = [];
    let id: number = 1000;
    /*
     * ⚠️ 种子口径修正（用户反馈「一进来碳足迹就那么多」）：
     * 旧种子在全量 27 个因子里随机挑 + 1~4 倍数量 —— roll 到金属回收(8.0)、
     * 旧衣(6.0)、电子废弃物(5.0) 这类重因子时，单条就是 20~32 kg 减排，
     * 首日直接 20+ kg，「已超出 5 kg 目标」的红色告警开机即见，完全失真。
     * 三重约束修正：
     *   1. 种子池只取低排放因子（factorValue ≤ 2.8，重因子留给用户手动记）；
     *   2. 数量倍率 1~2×（原 1~4×）；
     *   3. 每天 1~2 条（原 1~3 条）。
     * 修正后单日减排 ≈ 0.1~5 kg，贴合 5 kg 日目标的真实观感。
     */
    const pool: LocalFactor[] = factors.filter((f: LocalFactor): boolean => f.factorValue <= 2.8);
    for (let day: number = 0; day < 30; day++) {
      const dateStr: string = dateOffset(day);
      const n: number = 1 + Math.floor(hash01('count' + dateStr) * 2);
      for (let k: number = 0; k < n; k++) {
        const seed: string = dateStr + '#' + k;
        const f: LocalFactor = pool[Math.floor(hash01(seed) * pool.length)];
        const amount: number = f.defaultAmount * (1 + Math.floor(hash01(seed + 'a') * 2));
        const kg: number = Math.round(f.factorValue * amount * 1000) / 1000;
        const pts: number = Biz.pointsOf(kg);
        const hour: number = 7 + Math.floor(hash01(seed + 'h') * 14);
        out.push({
          recordId: id++,
          itemId: f.itemId,
          itemCode: f.itemCode,
          itemName: f.itemName,
          icon: f.icon,
          category: f.category,
          amount: amount,
          unit: f.unit,
          reduceKg: kg,
          points: pts,
          behaviorTime: dateStr + ' ' + pad(hour) + ':' + pad(Math.floor(hash01(seed + 'm') * 60)) + ':00',
          dateStr: dateStr,
          recordSource: hash01(seed + 'src') > 0.86 ? 'ai' : 'manual',
          remark: ''
        });
      }
    }
    return out;
  }

  /* ---------- 碳普惠权益 8 项 ---------- */
  static benefits(): LocalBenefit[] {
    const raw: string[][] = [
      ['b1', '公交地铁乘车券', '500', '兑换 1 张 2 元公共交通乘车券', '🚌'],
      ['b2', '公园门票折扣', '800', '城市公园门票立减 10 元', '🏞️'],
      ['b3', '共享骑行月卡', '1200', '共享单车 30 天骑行月卡', '🚲'],
      ['b4', '充电服务优惠券', '900', '新能源充电 10 元抵扣券', '🔋'],
      ['b5', '环保周边礼包', '2000', '帆布袋、绿植、环保餐具套装', '🎁'],
      ['b6', '绿色超市券', '1500', '绿色有机食品专区 20 元券', '🛒'],
      ['b7', '公益植树认养', '3000', '认养 1 棵树并获电子证书', '🌳'],
      ['b8', '碳普惠纪念徽章', '300', '城市低碳达人电子纪念徽章', '🏅']
    ];
    const out: LocalBenefit[] = [];
    for (let i = 0; i < raw.length; i++) {
      const r: string[] = raw[i];
      out.push({
        benefitId: i + 1,
        benefitCode: r[0],
        benefitName: r[1],
        points: parseInt(r[2]),
        description: r[3],
        icon: r[4]
      });
    }
    return out;
  }

  /* ---------- 植树证书 ---------- */
  /**
   * 植树证书：从**真实兑换消耗**推导（每 POINTS_PER_TREE 分 = 1 棵树 = 1 张证书）。
   * ------------------------------------------------------------------
   * ⚠️ 口径修正（用户反馈「新号只添加一次记录就显示已发证书 3 张」）：
   *   旧版写死 3 张演示证书（梭梭/沙枣/胡杨 1+3+5 棵、消耗 1800 分），
   *   与用户数据完全无关 —— 新号一条记录都还没兑换也"已发 3 张"。
   *   现与 pointsLogsFrom 同口径：证书只来自真实兑换行为。
   *   当前商城尚无真实扣分渠道（LocalStore.stats().exchangedPoints 恒为 0）
   *   → 未兑换账号返回空列表，证书夹展示空态引导（继续加油 / 去商城兑换）。
   *   真实兑换通道上线后**此处无需再改**：按 exchangedPoints 自动生成。
   */
  static certificatesFrom(exchangedPoints: number): LocalCert[] {
    const out: LocalCert[] = [];
    const totalTrees: number = Math.floor(exchangedPoints / Biz.POINTS_PER_TREE);
    if (totalTrees <= 0) return out;
    const names: string[] = ['梭梭树', '沙枣树', '胡杨', '柠条'];
    // 真实兑换流水的逐笔粒度落地前，先把已兑换棵数合成一张汇总证书；
    // 届时改为按每笔兑换流水各生成一张（certId 取流水 id 即可防重）。
    out.push({
      certId: 700,
      certNo: 'CF-' + dateOffset(0).replace(/-/g, '') + pad(10) + pad(15) + '300',
      treeType: names[totalTrees % names.length],
      treeCount: totalTrees,
      costPoints: totalTrees * Biz.POINTS_PER_TREE,
      ownerName: '低碳行者',
      issueDate: dateOffset(0)
    });
    return out;
  }

  /* ---------- 科普文章 10 篇 ---------- */
  static articles(): LocalArticle[] {
    const raw: string[][] = [
      ['碳达峰碳中和的基本内涵', 'policy', '🌏', '双碳目标的时代背景、时间表与实施路径，一次读懂国家战略。',
        '碳达峰是指二氧化碳排放总量由增长阶段转向平台期并实现下降；碳中和是指排放量与吸收量相抵，实现净零排放。\n\n我国提出 2030 年前碳达峰、2060 年前碳中和的"双碳"目标。实现路径涵盖能源结构转型、产业结构优化、碳市场建设与全民参与四个层面。\n\n个人减碳虽小，但汇聚億万人的日常选择，就能形成改变社会的强大力量。'],
      ['什么是碳足迹', 'concept', '📐', '从一顿早餐到一件外套，教你读懂自己的排放清单。',
        '碳足迹指一个人、一件商品或一项活动在整个生命周期内产生的温室气体排放总量，单位为 kgCO₂e。\n\n计算公式很简单：排放量 = 数量 × 单位排放因子。\n\n日常生活中的碳足迹主要来自饮食、出行、居住与购物四个场景。从记录开始，是最有效的减碳起点。'],
      ['绿色出行能减多少碳', 'tips', '🚲', '步行、骑行、公交、地铁与私家车的碳排放对比。',
        '以 1 公里出行计算：私家车约 0.19 kgCO₂e，地铁约 0.12 kg，公交约 0.10 kg，而步行与骑行接近于零。\n\n短途出行改乘公共交通或骑行，一年轻松减少数十公斤碳排放。\n\n建议每周至少选择 3 次绿色出行。'],
      ['家庭垃圾分类的正确打开方式', 'tips', '♻️', '四类垃圾怎么分，一次讲清不再搞混。',
        '可回收物：纸箱、塑料瓶、金属、玻璃、旧衣物。\n厨余垃圾：剩菜剩饭、果皮果核。\n有害垃圾：电池、药品、灯管。\n其他垃圾：纸巾、陶瓷、烟蒂。\n\n分类投放能让回收物真正进入再生循环，是最直接的减碳行动。'],
      ['光盘行动：从餐桌开始的低碳', 'tips', '🍚', '减少食物浪费就是最直接的减排。',
        '全球约三分之一的食物被浪费，而生产这些被浪费的食物所排放的温室气体，相当于每年约 10 亿吨。\n\n按需取餐、光盘行动、妥善储存，每减少一次浪费都在为地球减负。'],
      ['旧物循环利用的价值', 'tips', '🎁', '闲置流转比丢弃更有价值。',
        '一件旧衣重新流转，可减少约 5.7 kgCO₂e 的排放；一台旧手机回收再利用，价值远超其金属本身。\n\n捐赠、转赠、二手交易，都是让物品延长生命周期的良性方式。'],
      ['新能源汽车是否真的零排放', 'concept', '🔋', '全生命周期视角下的真实答案。',
        '电动车行驶阶段零排放，但生产电池与发电环节仍有碳排放。\n\n在电网结构逐步清洁的前提下，电动车的全生命周期排放已明显低于同级燃油车。\n\n结论：电动车不是绝对零碳，但是低碳出行的重要组成。'],
      ['建筑节能的三个关键', 'concept', '🏠', '保温、采光与空调系统决定家居碳足迹。',
        '第一，提升围护结构保温性能，减少空调能耗。\n\n第二，合理利用自然采光，降低白天的照明需求。\n\n第三，选择高能效比的空调与家电设备。\n\n这三项合计可为家庭减少约 30% 的能源碳排放。'],
      ['碳积分机制如何激励大众', 'policy', '🏅', '积分、权益与荣誉三者如何形成正向激励。',
        '碳积分机制把抽象的减排量转化为可感的正向反馈：积分可兑换实用权益，减排可获得荣誉徽章。\n\n目前各地碳普惠平台普遍采用"积分—权益—核销"的闭环，让减排行为有即时的现实价值。'],
      ['青少年如何参与低碳生活', 'policy', '👦', '从校园到家庭，青少年可以这样做。',
        '校园层面：组织垃圾分类督导、发起骑行打卡、参加环保社团。\n\n家庭层面：随手关灯、光盘行动、物品二手流转。\n\n青少年还可参与碳普惠平台的社会实践项目，把减排实践转化为公共服务。']
    ];
    const out: LocalArticle[] = [];
    for (let i = 0; i < raw.length; i++) {
      const r: string[] = raw[i];
      out.push({
        articleId: 800 + i,
        title: r[0],
        category: r[1],
        icon: r[2],
        summary: r[3],
        content: r[4],
        readCount: 1200 + Math.floor(hash01('rc' + i) * 2800),
        likeCount: 120 + Math.floor(hash01('lc' + i) * 460),
        readMinutes: 3 + Math.floor(hash01('rm' + i) * 5),
        isTop: i < 2,
        favorite: i < 3
      });
    }
    return out;
  }

  /* ---------- 超级终端：家庭设备 ---------- */
  static devices(): LocalDevice[] {
    const raw: string[][] = [
      ['1', '爸爸的手机', 'HUAWEI Mate 60', 'phone', '1', '0'],
      ['2', '妈妈的平板', 'HUAWEI MatePad', 'tablet', '1', '0'],
      ['3', '孩子的手表', 'HUAWEI WATCH 4', 'watch', '0', '0'],
      ['4', '客厅电视', 'HUAWEI Vision', 'tv', '1', '0']
    ];
    const out: LocalDevice[] = [];
    for (let i = 0; i < raw.length; i++) {
      const r: string[] = raw[i];
      const online: boolean = r[4] === '1';
      const kg: number = online
        ? Math.round((2 + hash01('dev' + i) * 8) * 100) / 100
        : 0;
      out.push({
        deviceId: parseInt(r[0]),
        deviceCode: 'dev-' + (1000 + i),
        deviceName: r[1],
        deviceModel: r[2],
        deviceType: r[3],
        online: online,
        todayReduction: kg,
        lastSyncTime: online ? dateOffset(0) + ' 09:2' + i + ':00' : dateOffset(1) + ' 20:10:00'
      });
    }
    return out;
  }

  /* ---------- 分享文案 ---------- */
  /**
   * 分享文案：入参改为真实统计 LocalStats（原 MockStore.overview() 已随
   * 死链清理移除）。徽章数按真实口径现算（badgesBy 与 DataSource.badges
   * 同一实现），文案结构与字段插值位置保持不变。
   */
  static shareText(s: LocalStats): string {
    const badgeCount: number = MockStore.badgesBy(s.totalKg, s.recordCount, s.continuousDays, s.treeCount)
      .filter((b: LocalBadge): boolean => b.unlocked).length;
    return '🌱 我的低碳成绩单\n' +
      '我在「一触青绿」已累计减排 ' + s.totalKg.toFixed(2) + ' kg CO₂e，' +
      '累计 ' + s.recordCount + ' 条低碳记录、坚持打卡 ' + s.continuousDays + ' 天；\n' +
      '共获得 ' + s.totalPoints + ' 碳积分、' + badgeCount + ' 枚低碳徽章，' +
      '相当于种下 ' + Biz.treesOf(s.totalPoints) + ' 棵树。\n' +
      '低碳生活，从我做起，一起来记录你的绿色日常吧！🌍';
  }

  /* ---------- AI 识别（复刻端侧演示引擎） ---------- */

  /**
   * 低碳行为关键词 → 因子 code 词库。
   * 提取为静态常量：演示词库链路（recognize）与端侧 OCR 识别链路
   * （AiVisionRecognizer）共用，保证两处命中口径一致。
   */
  static readonly KEYWORD_PAIRS: string[][] = [
    ['自行车', 'bike'], ['骑行', 'bike'], ['bike', 'bike'], ['bicycle', 'bike'],
    ['公交', 'bus'], ['bus', 'bus'], ['地铁', 'metro'], ['metro', 'metro'],
    ['步行', 'walk'], ['走路', 'walk'], ['walk', 'walk'],
    ['光盘', 'clearplate'], ['餐盘', 'clearplate'], ['空盘', 'clearplate'],
    ['塑料', 'plastic'], ['塑料瓶', 'plastic'],
    ['废纸', 'paper_waste'], ['纸箱', 'paper_waste'], ['报纸', 'paper_waste'],
    ['玻璃', 'glass'], ['酒瓶', 'glass'],
    ['旧衣', 'clothes'], ['金属', 'metal'], ['易拉罐', 'metal'],
    ['关灯', 'unplug'], ['断电', 'unplug'], ['节电', 'elec'], ['节水', 'water'],
    ['素食', 'veggie'], ['蔬菜', 'veggie'], ['水杯', 'cup'], ['购物袋', 'bag'],
    ['垃圾分类', 'classify'], ['餐盒', 'lunchbox'], ['餐具', 'nochopsticks']
  ];

  static recognize(label: string): LocalRecord | undefined {
    const pairs: string[][] = MockStore.KEYWORD_PAIRS;
    const low: string = label.toLowerCase();
    let code: string = '';
    let matched: string = '';
    let conf: number = 0.92;
    for (let i = 0; i < pairs.length; i++) {
      if (low.indexOf(pairs[i][0]) >= 0) {
        code = pairs[i][1];
        matched = pairs[i][0];
        break;
      }
    }
    if (code === '') {
      const pool: string[] = ['bike', 'bus', 'metro', 'walk', 'clearplate', 'plastic',
        'paper_waste', 'classify', 'cup', 'bag', 'unplug', 'veggie'];
      const idx: number = Math.min(Math.floor(hash01(label) * pool.length), pool.length - 1);
      code = pool[idx];
      conf = Math.round((0.62 + hash01(label + 'conf') * 0.3) * 100) / 100;
      matched = '图片特征推断';
    }
    const f: LocalFactor | undefined = MockStore.factorByCode(code);
    if (f === undefined) return undefined;
    return {
      recordId: 0,
      itemId: f.itemId,
      itemCode: f.itemCode,
      itemName: f.itemName,
      icon: f.icon,
      category: f.category,
      amount: f.defaultAmount,
      unit: f.unit,
      reduceKg: Math.round(f.factorValue * f.defaultAmount * 1000) / 1000,
      points: Biz.pointsOf(f.factorValue * f.defaultAmount),
      behaviorTime: AppClock.dateTimeStr(),
      dateStr: AppClock.dateStr(),
      recordSource: 'ai',
      remark: 'AI识图：' + matched
    };
  }

  static factorByCode(code: string): LocalFactor | undefined {
    const list: LocalFactor[] = MockStore.factors();
    for (let i = 0; i < list.length; i++) {
      if (list[i].itemCode === code) return list[i];
    }
    return undefined;
  }

  /* ================================================================
   * 以下方法基于「用户真实记录」计算，而非预生成的演示数据。
   * 单机版所有统计页都应走这里，保证录入的行为能立刻反映到各页面。
   * ================================================================ */

  private static sumKg(records: LocalRecord[], cat: string, fromDate: string): number {
    let sum: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].category !== cat) continue;
      if (records[i].dateStr < fromDate) continue;
      sum += records[i].reduceKg;
    }
    return sum;
  }

  private static countOf(records: LocalRecord[], cat: string, fromDate: string): number {
    let n: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].category !== cat) continue;
      if (records[i].dateStr < fromDate) continue;
      n++;
    }
    return n;
  }

  /** 趋势：基于真实记录聚合（day=近7天 / week=近8周 / month=近6月 / year=近6年） */
  static trendFrom(records: LocalRecord[], granularity: string): TrendPoint[] {
    const out: TrendPoint[] = [];
    if (granularity === 'day') {
      for (let d: number = 6; d >= 0; d--) {
        const ds: string = dateOffset(d);
        let kg: number = 0;
        for (let i: number = 0; i < records.length; i++) {
          if (records[i].dateStr === ds) kg += records[i].reduceKg;
        }
        out.push({
          label: d === 0 ? '今天' : (parseInt(ds.substring(8)) + '日'),
          kg: Math.round(kg * 1000) / 1000,
          points: Biz.pointsOf(kg)
        });
      }
    } else if (granularity === 'week') {
      for (let w: number = 7; w >= 0; w--) {
        const end: number = w * 7;
        let kg: number = 0;
        for (let i: number = 0; i < records.length; i++) {
          const diff: number = daysBetween(records[i].dateStr, today());
          // 每根柱子只统计「该周自身」的 7 天窗口 [end, end+7)
          // end = w*7，w=0 为含今天的最近 7 天，w=7 为 49~55 天前
          if (diff >= end && diff < end + 7) kg += records[i].reduceKg;
        }
        out.push({
          label: w === 0 ? '本周' : (w + '周前'),
          kg: Math.round(kg * 100) / 100,
          points: Biz.pointsOf(kg)
        });
      }
    } else if (granularity === 'year') {
      // 年：近 6 年，按日期字符串的年份前缀聚合。
      // dateStr 形如 '2026-10-20'，前缀 '2026' 只会命中该年，
      // 不会误匹配 '2027-...'（四位年份前缀是互斥的）。
      for (let y: number = 5; y >= 0; y--) {
        const d: Date = AppClock.offsetYears(y);
        const prefix: string = '' + d.getFullYear();
        let kg: number = 0;
        for (let i: number = 0; i < records.length; i++) {
          if (records[i].dateStr.indexOf(prefix) === 0) kg += records[i].reduceKg;
        }
        out.push({
          label: d.getFullYear() + '年',
          kg: Math.round(kg * 100) / 100,
          points: Biz.pointsOf(kg)
        });
      }
    } else {
      for (let m: number = 5; m >= 0; m--) {
        const d: Date = AppClock.offsetMonths(m);
        const prefix: string = d.getFullYear() + '-' + pad(d.getMonth() + 1);
        let kg: number = 0;
        for (let i: number = 0; i < records.length; i++) {
          if (records[i].dateStr.indexOf(prefix) === 0) kg += records[i].reduceKg;
        }
        out.push({
          label: (d.getMonth() + 1) + '月',
          kg: Math.round(kg * 100) / 100,
          points: Biz.pointsOf(kg)
        });
      }
    }
    return out;
  }

  /** 分类统计：基于真实记录（reduceKg 为各类合计，便于复用渲染） */
  static categoryStatsFrom(records: LocalRecord[], days: number): LocalRecord[] {
    const cats: string[] = ['travel', 'energy', 'recycle', 'food'];
    const from: string = dateOffset(days - 1);
    const out: LocalRecord[] = [];
    for (let c: number = 0; c < cats.length; c++) {
      const kg: number = MockStore.sumKg(records, cats[c], from);
      out.push({
        recordId: c + 1,
        itemId: c + 1,
        itemCode: cats[c],
        itemName: '',
        icon: '',
        category: cats[c],
        amount: MockStore.countOf(records, cats[c], from),
        unit: '次',
        reduceKg: Math.round(kg * 1000) / 1000,
        points: Biz.pointsOf(kg),
        behaviorTime: '',
        dateStr: '',
        recordSource: '',
        remark: ''
      });
    }
    return out;
  }

  /** 每日任务：进度按今日真实记录计算 */
  static tasksFrom(records: LocalRecord[], claimed: string[] = []): LocalTask[] {
    const td: string = today();
    const defs: string[][] = [
      ['task_travel', '绿色出行', '今日记录 2 次绿色出行', '🚲', 'travel', '2', '15'],
      ['task_energy', '节能小卫士', '今日完成 1 次节水节电', '💡', 'energy', '1', '10'],
      ['task_recycle', '回收好习惯', '今日完成 1 次旧物回收', '♻️', 'recycle', '1', '20'],
      ['task_food', '光盘惜粮', '今日记录 2 次光盘或绿色消费', '🍚', 'food', '2', '15'],
      ['task_checkin', '低碳打卡', '今日累计记录 3 条低碳行为', '✅', '', '3', '10']
    ];
    const out: LocalTask[] = [];
    let todayCount: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].dateStr === td) todayCount++;
    }
    for (let i: number = 0; i < defs.length; i++) {
      const d: string[] = defs[i];
      const target: number = parseInt(d[5]);
      let progress: number = 0;
      if (d[4] === '') {
        progress = todayCount;
      } else {
        progress = MockStore.countOf(records, d[4], td);
      }
      progress = Math.min(progress, target);
      /*
       * status 三态（2026-10-23 修复「点完还是待领取」）：
       *   claimed 必须由**持久化的领取记录**推导，不能只看进度。
       *   原实现只有 done/doing 两态，页面把内存里改成 claimed 后，
       *   下次 tasksFrom 重算又变回 done —— 用户点完刷新就回弹。
       *   claimed 优先于进度判定：已发放的任务即使进度归零也仍是已领取。
       */
      const isClaimed: boolean = claimed.indexOf(d[0]) >= 0;
      out.push({
        taskId: i + 1,
        taskCode: d[0],
        taskName: d[1],
        taskDesc: d[2],
        icon: d[3],
        category: d[4],
        targetType: 'times',
        targetValue: target,
        rewardPoints: parseInt(d[6]),
        progress: progress,
        status: isClaimed ? 'claimed' : (progress >= target ? 'done' : 'doing')
      });
    }
    return out;
  }

  /** 徽章：按真实累计值判定解锁 */
  static badgesBy(totalKg: number, recordCount: number, days: number, treeCount: number): LocalBadge[] {
    const defs: string[][] = [
      ['badge_first', '初次行动', '记录第 1 条低碳行为', '🌱', 'count', '', '1'],
      ['badge_sprout', '绿色新星', '累计减排达到 10 kg', '🌿', 'reduction', '', '10'],
      ['badge_lowcarbon', '低碳达人', '累计减排达到 100 kg', '🍃', 'reduction', '', '100'],
      ['badge_pioneer', '减排先锋', '累计减排达到 500 kg', '🏅', 'reduction', '', '500'],
      ['badge_guardian', '碳中和卫士', '累计减排达到 1000 kg', '🏆', 'reduction', '', '1000'],
      ['badge_streak7', '坚持一周', '连续 7 天记录低碳行为', '🔥', 'days', '', '7'],
      ['badge_travel', '绿色出行家', '绿色出行累计 50 次', '🚲', 'categoryCount', 'travel', '50'],
      ['badge_recycle', '回收能手', '旧物回收累计 20 次', '♻️', 'categoryCount', 'recycle', '20'],
      ['badge_food', '光盘达人', '光盘绿色消费累计 30 次', '🍚', 'categoryCount', 'food', '30'],
      ['badge_tree', '植树达人', '累计兑换 5 棵植树证书', '🌳', 'tree', '', '5']
    ];
    const out: LocalBadge[] = [];
    for (let i: number = 0; i < defs.length; i++) {
      const d: string[] = defs[i];
      const metric: string = d[4];
      const threshold: number = parseFloat(d[6]);
      let current: number = 0;
      if (metric === 'reduction') current = totalKg;
      else if (metric === 'count') current = recordCount;
      else if (metric === 'days') current = days;
      else if (metric === 'tree') current = treeCount;
      const unlocked: boolean = current >= threshold;
      // unlockDate 存真实日期；未解锁留空（由页面显示阈值文案）
      const unlockDate: string = unlocked
        ? dateOffset(Math.floor(hash01(d[0] + 'unlock') * 20))
        : '';
      out.push({
        badgeId: i + 1,
        badgeCode: d[0],
        badgeName: d[1],
        // 与 badges() 保持一致：icon 取 emoji 列 d[3]，description 取文案列 d[2]
        icon: d[3],
        description: d[2],
        metric: metric,
        category: d[5],
        threshold: threshold,
        unlocked: unlocked,
        unlockDate: unlockDate
      });
    }
    return out;
  }

  /** 积分流水：按真实记录生成（倒序，含余额） */
  static pointsLogsFrom(records: LocalRecord[]): LocalPointsLog[] {
    const out: LocalPointsLog[] = [];
    let balance: number = 0;
    const asc: LocalRecord[] = records.slice().sort((a: LocalRecord, b: LocalRecord): number => {
      return a.behaviorTime < b.behaviorTime ? -1 : 1;
    });
    for (let i: number = 0; i < asc.length; i++) {
      balance += asc[i].points;
    }
    for (let i: number = records.length - 1; i >= 0; i--) {
      const r: LocalRecord = records[i];
      const log: LocalPointsLog = {
        logId: r.recordId,
        changeType: r.recordSource === 'ai' ? 'task' : 'earn',
        points: r.points,
        balanceAfter: balance,
        remark: r.itemName,
        createTime: r.behaviorTime
      };
      out.push(log);
      balance -= r.points;
    }
    return out;
  }

  /** 今日重点：按近 7 天真实分类统计找最薄弱项 */
  static focusFrom(records: LocalRecord[]): LocalFocusTask {
    const cats: string[] = ['travel', 'energy', 'recycle', 'food'];
    const from: string = dateOffset(6);
    let minCat: string = 'travel';
    let minVal: number = -1;
    let allZero: boolean = true;
    for (let i: number = 0; i < cats.length; i++) {
      const v: number = MockStore.sumKg(records, cats[i], from);
      if (v > 0) allZero = false;
      if (minVal < 0 || v < minVal) {
        minVal = v;
        minCat = cats[i];
      }
    }
    if (allZero || records.length === 0) {
      return {
        category: 'travel', taskCode: 'task_travel', icon: '🚲',
        title: '今日重点：绿色出行',
        desc: '新的一天，先从步行、骑行或公交开始，记录 2 次绿色出行即可领取积分。'
      };
    }
    if (minCat === 'travel') {
      return {
        category: 'travel', taskCode: 'task_travel', icon: '🚲',
        title: '今日重点：多绿色出行',
        desc: '你最近的绿色出行减排偏少，试试短途步行或骑行、通勤乘公交地铁。'
      };
    } else if (minCat === 'energy') {
      return {
        category: 'energy', taskCode: 'task_energy', icon: '💡',
        title: '今日重点：节约用电',
        desc: '节水节电还有提升空间，随手关灯、空调调高 1℃、拔掉待机插头。'
      };
    } else if (minCat === 'recycle') {
      return {
        category: 'recycle', taskCode: 'task_recycle', icon: '♻️',
        title: '今日重点：旧物回收',
        desc: '记得把纸箱、塑料瓶、旧衣物分类回收，闲置物品优先转赠。'
      };
    }
    return {
      category: 'food', taskCode: 'task_food', icon: '🍚',
      title: '今日重点：光盘行动',
      desc: '适量点餐、按需取餐，自带水杯购物袋，减少食物浪费与一次性用品。'
    };
  }

  /** 生活建议：最薄弱分类专项 + 两条通用，截断前 3 */
  static tipsFrom(records: LocalRecord[]): LocalSmartTip[] {
    const cats: string[] = ['travel', 'energy', 'recycle', 'food'];
    const from: string = dateOffset(6);
    let minCat: string = '';
    let minVal: number = -1;
    for (let i: number = 0; i < cats.length; i++) {
      const v: number = MockStore.sumKg(records, cats[i], from);
      if (minVal < 0 || v < minVal) {
        minVal = v;
        minCat = cats[i];
      }
    }
    const out: LocalSmartTip[] = [];
    const ids: string[] = ['t1', 't2', 't3', 't4'];
    const icons: string[] = ['🚲', '💡', '♻️', '🍚'];
    const titles: string[] = ['多绿色出行', '节约用电', '旧物回收', '光盘行动'];
    const contents: string[] = [
      '试试短途步行或骑行，通勤选公交地铁，每公里都能减碳。',
      '随手关灯、空调调高 1℃，使用节能家电，减少待机能耗。',
      '纸箱、塑料瓶、旧衣物记得分类回收，闲置物品优先转赠。',
      '适量点餐、按需取餐，减少食物浪费就是低碳。'
    ];
    const idx: number = cats.indexOf(minCat);
    if (idx >= 0) {
      const t: LocalSmartTip = {
        id: ids[idx], icon: icons[idx], title: titles[idx], content: contents[idx]
      };
      out.push(t);
    }
    const t5: LocalSmartTip = {
      id: 't5', icon: '🎯', title: '坚持每日打卡',
      content: '连续完成今日低碳任务，可获得更多积分与徽章。'
    };
    out.push(t5);
    const t6: LocalSmartTip = {
      id: 't6', icon: '🌳', title: '积分变树木',
      content: '每 3000 积分可兑换 1 棵植树证书，让减排看得见。'
    };
    out.push(t6);
    return out.length > 3 ? out.slice(0, 3) : out;
  }

  /** 家庭成员：以本人真实统计为基准 + 模拟同账号家人设备 */
  static membersFrom(stats: LocalStats): LocalMember[] {
    const self: LocalMember = {
      memberId: 0,
      memberName: '低碳行者（我）',
      avatar: '🌱',
      role: 'owner',
      deviceName: '本机',
      online: true,
      reduction: stats.totalKg,
      points: stats.totalPoints,
      count: stats.recordCount,
      isSelf: true
    };
    const out: LocalMember[] = [self];
    const names: string[][] = [
      ['爸爸', '👨', 'owner'],
      ['妈妈', '👩', 'member'],
      ['孩子', '👧', 'member']
    ];
    const devices: LocalDevice[] = MockStore.devices();
    const ranges: number[][] = [[2, 12], [0.5, 5], [0.5, 9], [0.4, 3.2]];
    for (let i: number = 0; i < names.length; i++) {
      let kg: number = 0;
      for (let c: number = 0; c < ranges.length; c++) {
        kg += ranges[c][0] + hash01(names[i][0] + 'c' + c) * (ranges[c][1] - ranges[c][0]);
      }
      const d: LocalDevice = devices[i];
      out.push({
        memberId: i + 1,
        memberName: names[i][0],
        avatar: names[i][1],
        role: names[i][2],
        deviceName: d.deviceName,
        online: d.online,
        reduction: Math.round(kg * 100) / 100,
        points: Biz.pointsOf(kg),
        count: 12 + Math.floor(hash01(names[i][0] + 'n') * 40),
        isSelf: false
      });
    }
    return out;
  }
}

/** 两个日期相差天数（b - a） */
function daysBetween(a: string, b: string): number {
  const da: Date = new Date(a.replace(/-/g, '/'));
  const db: Date = new Date(b.replace(/-/g, '/'));
  return Math.floor((db.getTime() - da.getTime()) / 86400000);
}