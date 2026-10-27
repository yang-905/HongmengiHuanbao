export class AppClock {
  static now(): number {
    return Date.now()
  }

  static today(): Date {
    return new Date()
  }

  static dateStr(): string {
    return AppClock.fmtDate(AppClock.today())
  }

  static monthStr(): string {
    return AppClock.dateStr().substring(0, 7)
  }

  static dateTimeStr(): string {
    const d: Date = AppClock.today()
    return AppClock.fmtDate(d) + ' ' + AppClock.fmtTime(d)
  }

  static offsetDays(days: number): Date {
    const d: Date = AppClock.today()
    d.setDate(d.getDate() - days)
    return d
  }

  static offsetMonths(months: number): Date {
    const d: Date = AppClock.today()
    d.setMonth(d.getMonth() - months)
    return d
  }

  static offsetYears(years: number): Date {
    const d: Date = AppClock.today()
    d.setFullYear(d.getFullYear() - years)
    return d
  }

  static fmtDate(d: Date): string {
    return d.getFullYear() + '-' + AppClock.pad2(d.getMonth() + 1) + '-' + AppClock.pad2(d.getDate())
  }

  static fmtTime(d: Date): string {
    return AppClock.pad2(d.getHours()) + ':' + AppClock.pad2(d.getMinutes()) + ':' + AppClock.pad2(d.getSeconds())
  }

  private static pad2(n: number): string {
    return n < 10 ? '0' + n : '' + n
  }
}
