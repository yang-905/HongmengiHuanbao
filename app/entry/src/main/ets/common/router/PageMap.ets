/**
 * NavDestination 集中注册（P08-P30 共 21 个进栈页面）
 * 由 Index 的 Navigation.navDestination 引用
 */
import { AppRouter, RouteName } from './AppRouter'
import { BehaviorDetailPage } from '../../pages/behavior/BehaviorDetailPage'
import { FactorLibPage } from '../../pages/behavior/FactorLibPage'
import { AiRecognizePage } from '../../pages/behavior/AiRecognizePage'
import { TrendChartPage } from '../../pages/chart/TrendChartPage'
import { CategoryAnalysisPage } from '../../pages/chart/CategoryAnalysisPage'
import { LevelTreePage } from '../../pages/mine/LevelTreePage'
import { PointsHomePage } from '../../pages/points/PointsHomePage'
import { PointsRecordPage } from '../../pages/points/PointsRecordPage'
import { TaskCenterPage } from '../../pages/points/TaskCenterPage'
import { PointsMallPage } from '../../pages/points/PointsMallPage'
import { BadgeWallPage } from '../../pages/points/BadgeWallPage'
import { CertificateListPage } from '../../pages/points/CertificateListPage'
import { CertificateDetailPage } from '../../pages/points/CertificateDetailPage'
import { ArticleDetailPage } from '../../pages/article/ArticleDetailPage'
import { FavoriteListPage } from '../../pages/article/FavoriteListPage'
import { SettingsPage } from '../../pages/settings/SettingsPage'
import { BackupManagePage } from '../../pages/settings/BackupManagePage'
import { ExportReportPage } from '../../pages/settings/ExportReportPage'
import { MonthBillPage } from '../../pages/settings/MonthBillPage'
import { FamilyPage } from '../../pages/settings/FamilyPage'
import { AboutPage } from '../../pages/settings/AboutPage'
import { SmartTipsPage } from '../../pages/smart/SmartTipsPage'
import { SuperTerminalPage } from '../../pages/terminal/SuperTerminalPage'
import { ProfilePage } from '../../pages/mine/ProfilePage'
import { CouponListPage } from '../../pages/points/CouponListPage'
import { CouponRedeemPage } from '../../pages/points/CouponRedeemPage'

/**
 * 带参数跳转。
 * 说明：PageMap 已提供 NavDestination 容器，页面内部不能再包一层，
 * 因此拿不到 NavDestinationContext.onReady。统一改为把参数写入 AppStorage，
 * 由目标页在 aboutToAppear 中读取并清理。
 *
 * 统一出口：所有 push 都经由 go()，在这里同步路由栈深度，
 * 供 Index 的「＋」按钮判断该显示为胶囊第 5 格还是左下角悬浮球。
 */
export function go(route: string): void {
  AppRouter.pathStack.pushPathByName(route, null)
}

export function goWithParam(route: string, paramKey: string, paramValue: number): void {
  // ⚠️ 必须用 setOrCreate：AppStorage.set 对不存在的键是**静默 no-op**（返回 false），
  // 路由参数键通常没有 @StorageProp 预声明，用 set 会导致目标页读到 undefined ——
  // 正是「文章详情永远显示文章不存在或已下架」的根因。
  AppStorage.setOrCreate<number>(paramKey, paramValue)
  go(route)
}

/** 带字符串参数跳转（如月度账单的月份） */
export function goWithParamStr(route: string, paramKey: string, paramValue: string): void {
  AppStorage.setOrCreate<string>(paramKey, paramValue)
  go(route)
}

@Builder
export function PageMap(name: string) {
  if (name === RouteName.BEHAVIOR_DETAIL) {
    BehaviorDetailPage()
  }
  else if (name === RouteName.FACTOR_LIB) {
    FactorLibPage()
  }
  else if (name === RouteName.AI_RECOGNIZE) {
    AiRecognizePage()
  }
  else if (name === RouteName.TREND_CHART) {
    TrendChartPage()
  }
  else if (name === RouteName.CATEGORY_ANALYSIS) {
    CategoryAnalysisPage()
  }
  else if (name === RouteName.LEVEL_TREE) {
    LevelTreePage()
  }
  else if (name === RouteName.POINTS_HOME) {
    PointsHomePage()
  }
  else if (name === RouteName.POINTS_RECORD) {
    PointsRecordPage()
  }
  else if (name === RouteName.TASK_CENTER) {
    TaskCenterPage()
  }
  else if (name === RouteName.POINTS_MALL) {
    PointsMallPage()
  }
  else if (name === RouteName.BADGE_WALL) {
    BadgeWallPage()
  }
  else if (name === RouteName.CERTIFICATE_LIST) {
    CertificateListPage()
  }
  else if (name === RouteName.CERTIFICATE_DETAIL) {
    CertificateDetailPage()
  }
  else if (name === RouteName.ARTICLE_DETAIL) {
    ArticleDetailPage()
  }
  else if (name === RouteName.FAVORITE_LIST) {
    FavoriteListPage()
  }
  else if (name === RouteName.SETTINGS) {
    SettingsPage()
  }
  else if (name === RouteName.BACKUP_MANAGE) {
    BackupManagePage()
  }
  else if (name === RouteName.EXPORT_REPORT) {
    ExportReportPage()
  }
  else if (name === RouteName.MONTH_BILL) {
    MonthBillPage()
  }
  else if (name === RouteName.FAMILY) {
    FamilyPage()
  }
  else if (name === RouteName.ABOUT) {
    AboutPage()
  }
  else if (name === RouteName.SMART_TIPS) {
    SmartTipsPage()
  }
  else if (name === RouteName.SUPER_TERMINAL) {
    SuperTerminalPage()
  }
  else if (name === RouteName.PROFILE) {
    ProfilePage()
  }
  else if (name === RouteName.COUPON_LIST) {
    CouponListPage()
  }
  else if (name === RouteName.COUPON_REDEEM) {
    CouponRedeemPage()
  }
}
