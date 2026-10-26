/**
 * 全局路由：Navigation + NavPathStack 单例
 * 全应用共用此栈实例；统一使用 pushPathByName/pop，禁止使用 @ohos.router
 *
 * 关于「是否处于子页面」：NavPathStack 没有栈变化回调，
 * 因此由 Index 对 Tabs 挂 onVisibleAreaChange 来感知
 * （子页面压上后 Tabs 可见比例变 0），无需在 20+ 个跳转点插桩。
 */
export class AppRouter {
  static pathStack: NavPathStack = new NavPathStack()
}

/**
 * 路由名常量（与 PageMap 注册名、NavDestination 页面一一对应）
 */
export class RouteName {
  static readonly BEHAVIOR_DETAIL: string = 'BehaviorDetail'       // P08
  static readonly FACTOR_LIB: string = 'FactorLib'                 // P09
  static readonly AI_RECOGNIZE: string = 'AiRecognize'              // P27
  static readonly TREND_CHART: string = 'TrendChart'               // P10
  static readonly CATEGORY_ANALYSIS: string = 'CategoryAnalysis'   // P11
  static readonly LEVEL_TREE: string = 'LevelTree'                 // P12
  static readonly POINTS_HOME: string = 'PointsHome'               // P13
  static readonly POINTS_RECORD: string = 'PointsRecord'           // P14
  static readonly TASK_CENTER: string = 'TaskCenter'               // P15
  static readonly POINTS_MALL: string = 'PointsMall'               // P16
  static readonly BADGE_WALL: string = 'BadgeWall'                 // P17
  static readonly CERTIFICATE_LIST: string = 'CertificateList'     // P19
  static readonly CERTIFICATE_DETAIL: string = 'CertificateDetail' // P20
  static readonly ARTICLE_DETAIL: string = 'ArticleDetail'         // P21
  static readonly FAVORITE_LIST: string = 'FavoriteList'           // P22
  static readonly SETTINGS: string = 'Settings'                    // P24
  static readonly BACKUP_MANAGE: string = 'BackupManage'           // P25
  static readonly EXPORT_REPORT: string = 'ExportReport'           // P26
  static readonly MONTH_BILL: string = 'MonthBill'                 // P28
  static readonly FAMILY: string = 'Family'                        // P29
  static readonly ABOUT: string = 'About'                          // P30
  static readonly SMART_TIPS: string = 'SmartTips'                  // P31 智慧服务·全部建议
  static readonly SUPER_TERMINAL: string = 'SuperTerminal'          // P32 超级终端·设备编组
  static readonly PROFILE: string = 'Profile'                       // P33 个人资料·头像/名字/性别/手机号
  static readonly COUPON_LIST: string = 'CouponList'               // P34 碳惠券包·积分兑换的权益券
  static readonly COUPON_REDEEM: string = 'CouponRedeem'           // P35 核销成功凭证页·感谢仪式+核销二维码
}