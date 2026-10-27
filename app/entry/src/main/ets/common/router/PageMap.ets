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

export function go(route: string): void {
  AppRouter.pathStack.pushPathByName(route, null)
}

export function goWithParam(route: string, paramKey: string, paramValue: number): void {
  AppStorage.setOrCreate<number>(paramKey, paramValue)
  go(route)
}

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
