/**
 * 应用内统一时钟（本地时间校准 · 系统时钟口径）
 * ------------------------------------------------------------------
 * 口径（2026-10-20 用户要求）：全应用日期时间**同步操作系统/运行时
 * 提供的系统时间 API** —— ArkTS 侧即 `new Date()` / `Date.now()`，
 * 取设备本地时区。本类是全应用唯一的时间读取入口：所有「当前
 * 日期/当前时刻」的业务判断与展示都走这里，由本类统一对系统
 * 时钟校准，**不再使用任何固定演示锚点**。
 *
 * 演进（为什么曾经有锚点）：
 *   v2 及以前按 **11 月**口径演示 —— 时间锚点固定在 2026-11-20
 *   12:00（AppClock.ANCHOR_MS），不跟随设备真实日期。该口径已
 *   废除：演示数据与用户数据的日期必须与设备时钟一致，否则今日
 *   统计、趋势分桶、券有效期全部对不上。历史数据的整体平移见
 *   LocalStore.shiftTimesToSystemClock()（v2 → v3 一次性迁移）。
 *
 * 使用规则：
 *   · 数据与展示类（趋势分桶、今日/本月统计、连续打卡、券有效期、
 *     记录/账单/报表的月份口径、备份/同步时间展示）→ 必须走本类；
 *   · 纯内部时序（首页刷新节流 lastLoadAt、recordId / updateTime 等
 *     ID 与同步戳）→ 仍用真实 Date.now()：ID 需要毫秒级唯一性与
 *     单调性，不能随时间口径调整而漂移（本类当前虽等价于系统
 *     时钟，但入口语义必须分开，防止未来再引入口径时 ID 撞号）。
 */
export class AppClock {
  /** 当前时间（毫秒）—— 业务判断统一入口，= 系统时钟 Date.now() */
  static now(): number {
    return Date.now()
  }

  /** 当前时间（每次返回新 Date 副本，调用方改派不污染其他读取）—— = 系统时钟 new Date() */
  static today(): Date {
    return new Date()
  }

  /** 'yyyy-MM-dd' */
  static dateStr(): string {
    return AppClock.fmtDate(AppClock.today())
  }

  /** 'yyyy-MM' */
  static monthStr(): string {
    return AppClock.dateStr().substring(0, 7)
  }

  /** 'yyyy-MM-dd HH:mm:ss' */
  static dateTimeStr(): string {
    const d: Date = AppClock.today()
    return AppClock.fmtDate(d) + ' ' + AppClock.fmtTime(d)
  }

  /** 以当前时间为基准偏移 days 天（days 为正 = 往过去） */
  static offsetDays(days: number): Date {
    const d: Date = AppClock.today()
    d.setDate(d.getDate() - days)
    return d
  }

  /** 以当前时间为基准偏移 months 个月（为正 = 往过去） */
  static offsetMonths(months: number): Date {
    const d: Date = AppClock.today()
    d.setMonth(d.getMonth() - months)
    return d
  }

  /** 以当前时间为基准偏移 years 年（为正 = 往过去） */
  static offsetYears(years: number): Date {
    const d: Date = AppClock.today()
    d.setFullYear(d.getFullYear() - years)
    return d
  }

  /** 'yyyy-MM-dd' */
  static fmtDate(d: Date): string {
    return d.getFullYear() + '-' + AppClock.pad2(d.getMonth() + 1) + '-' + AppClock.pad2(d.getDate())
  }

  /** 'HH:mm:ss' */
  static fmtTime(d: Date): string {
    return AppClock.pad2(d.getHours()) + ':' + AppClock.pad2(d.getMinutes()) + ':' + AppClock.pad2(d.getSeconds())
  }

  private static pad2(n: number): string {
    return n < 10 ? '0' + n : '' + n
  }
}
