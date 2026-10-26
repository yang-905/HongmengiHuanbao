/**
 * 图标资源映射表（Tabler Icons → 鸿蒙资源）
 * ==================================================================
 * 设计要点
 * ------------------------------------------------------------------
 * 1. 映射键用**语义 code**，不用 emoji 字符串。
 *    数据模型里 `icon` 字段存的是 emoji（'🚶' / '♻️'），直接当键用会踩变体
 *    选择符的坑：'♻️'(U+267B U+FE0F) 与 '♻'(U+267B) 是两个不同字符串，
 *    不同输入法/不同历史数据写进去的长度都不一样，查表必挂。
 *    而 itemCode / taskCode / badgeCode / benefitCode 是稳定的英文键。
 *
 * 2. 资源与 Tabler 图标 1:1（ic_<tabler-name>.svg），语义复用靠这张表。
 *    例如 route 同时被「绿色出行分类」「task_travel」「badge_travel」使用，
 *    资源层只有一个文件，不重复打包。
 *
 * 3. 图标资源由 scripts/sync-icons.sh 生成，本文件只负责「code → 资源」。
 *
 * 新增图标 = 在 sync-icons.sh 的 ICONS 里加名字 + 在这里加一行映射。
 */

/** 兜底图标：映射缺失时显示，避免整行空白（视觉上明显但不至于崩） */
const FALLBACK: Resource = $r('app.media.ic_target');

/* ---------- 27 个碳因子（LocalFactor.itemCode） ---------- */
const FACTOR: Record<string, Resource> = {
  // travel 绿色出行
  'walk': $r('app.media.ic_walk'),
  'bike': $r('app.media.ic_bike'),
  'bus': $r('app.media.ic_bus'),
  'metro': $r('app.media.ic_train'),
  // Tabler 没有 car-electric，用充电桩表达「新能源」
  'evcar': $r('app.media.ic_charging_pile'),
  'carpool': $r('app.media.ic_car'),
  // energy 节水节电
  'elec': $r('app.media.ic_bolt'),
  'water': $r('app.media.ic_droplet'),
  'gas': $r('app.media.ic_flame'),
  'paper': $r('app.media.ic_file_text'),
  'ac26': $r('app.media.ic_air_conditioning'),
  'unplug': $r('app.media.ic_plug_off'),
  // recycle 旧物回收
  'paper_waste': $r('app.media.ic_file_stack'),
  'plastic': $r('app.media.ic_bottle'),
  'metal': $r('app.media.ic_tools'),
  'glass': $r('app.media.ic_glass_full'),
  'clothes': $r('app.media.ic_shirt'),
  'ewaste': $r('app.media.ic_device_mobile'),
  'donate': $r('app.media.ic_gift'),
  'secondhand': $r('app.media.ic_arrows_exchange'),
  // food 光盘行动
  'clearplate': $r('app.media.ic_bowl'),
  'veggie': $r('app.media.ic_salad'),
  'lunchbox': $r('app.media.ic_tools_kitchen_2'),
  'bag': $r('app.media.ic_shopping_bag'),
  'cup': $r('app.media.ic_cup'),
  'nochopsticks': $r('app.media.ic_forbid'),
  'classify': $r('app.media.ic_trash')
};

/* ---------- 4 个因子分类 ---------- */
const CATEGORY: Record<string, Resource> = {
  'travel': $r('app.media.ic_route'),
  'energy': $r('app.media.ic_bulb'),
  'recycle': $r('app.media.ic_recycle'),
  'food': $r('app.media.ic_tools_kitchen')
};

/* ---------- 5 个每日任务（LocalTask.taskCode） ---------- */
const TASK: Record<string, Resource> = {
  'task_travel': $r('app.media.ic_route'),
  'task_energy': $r('app.media.ic_bulb'),
  'task_recycle': $r('app.media.ic_recycle'),
  'task_food': $r('app.media.ic_tools_kitchen'),
  'task_checkin': $r('app.media.ic_check')
};

/* ---------- 10 枚徽章（LocalBadge.badgeCode） ---------- */
const BADGE: Record<string, Resource> = {
  'badge_first': $r('app.media.ic_seedling'),
  'badge_sprout': $r('app.media.ic_plant_2'),
  'badge_lowcarbon': $r('app.media.ic_leaf'),
  'badge_pioneer': $r('app.media.ic_award'),
  'badge_guardian': $r('app.media.ic_trophy'),
  'badge_streak7': $r('app.media.ic_flame'),
  'badge_travel': $r('app.media.ic_route'),
  'badge_recycle': $r('app.media.ic_recycle'),
  'badge_food': $r('app.media.ic_bowl'),
  'badge_tree': $r('app.media.ic_trees')
};

/* ---------- 8 项碳普惠权益（LocalBenefit.benefitCode） ---------- */
const BENEFIT: Record<string, Resource> = {
  'b1': $r('app.media.ic_bus'),          // 公交地铁乘车券
  'b2': $r('app.media.ic_ticket'),       // 公园门票折扣
  'b3': $r('app.media.ic_bike'),         // 共享骑行月卡
  'b4': $r('app.media.ic_charging_pile'),// 充电服务优惠券
  'b5': $r('app.media.ic_gift'),         // 环保周边礼包
  'b6': $r('app.media.ic_shopping_cart'),// 绿色超市券
  'b7': $r('app.media.ic_trees'),        // 公益植树认养
  'b8': $r('app.media.ic_award')         // 碳普惠纪念徽章
};

/*
 * ---------- 10 篇科普文章 ----------
 * 按 articleId 映射而不是按分类：policy 有 3 篇、concept 有 3 篇、tips 有 4 篇，
 * 只按分类会给同屏多条一模一样的图标，辨识度反而低于原 emoji。
 * articleId 由种子数据 800+i 生成，稳定不变。
 */
const ARTICLE: Record<string, Resource> = {
  '800': $r('app.media.ic_building_bank'), // 碳达峰碳中和的基本内涵
  '801': $r('app.media.ic_footsteps'),     // 什么是碳足迹
  '802': $r('app.media.ic_bike'),          // 绿色出行能减多少碳
  '803': $r('app.media.ic_recycle'),       // 家庭垃圾分类
  '804': $r('app.media.ic_tools_kitchen'), // 光盘行动
  '805': $r('app.media.ic_refresh'),       // 旧物循环利用
  '806': $r('app.media.ic_charging_pile'), // 新能源汽车
  '807': $r('app.media.ic_building'),      // 建筑节能
  '808': $r('app.media.ic_award'),         // 碳积分机制
  '809': $r('app.media.ic_school')         // 青少年如何参与
};

/* ---------- 5 级成长树（LevelStep.level） ---------- */
const LEVEL: Record<string, Resource> = {
  '1': $r('app.media.ic_seedling'),  // 碳芽
  '2': $r('app.media.ic_plant_2'),   // 新芽
  '3': $r('app.media.ic_leaf'),      // 绿芽
  '4': $r('app.media.ic_award'),     // 低碳达人
  '5': $r('app.media.ic_trees')      // 森林卫士
};

/* ---------- 智慧建议（LocalSmartTip.id） ---------- */
const TIP: Record<string, Resource> = {
  't1': $r('app.media.ic_route'),
  't2': $r('app.media.ic_bulb'),
  't3': $r('app.media.ic_recycle'),
  't4': $r('app.media.ic_tools_kitchen'),
  't5': $r('app.media.ic_target'),
  't6': $r('app.media.ic_trees')
};

/* ---------- 界面通用图标（kind = 'ui'） ---------- */
const UI: Record<string, Resource> = {
  'home': $r('app.media.ic_home'),
  'record': $r('app.media.ic_clipboard_list'),
  'article': $r('app.media.ic_book'),
  'book': $r('app.media.ic_book'),
  'mine': $r('app.media.ic_user'),
  'trend': $r('app.media.ic_chart_bar'),
  'pie': $r('app.media.ic_chart_pie'),
  'line': $r('app.media.ic_chart_line'),
  'target': $r('app.media.ic_target'),
  'badge': $r('app.media.ic_award'),
  'mall': $r('app.media.ic_shopping_bag'),
  'factor': $r('app.media.ic_books'),
  'certificate': $r('app.media.ic_certificate'),
  'plus': $r('app.media.ic_plus'),
  'camera': $r('app.media.ic_camera'),
  'search': $r('app.media.ic_search'),
  'star': $r('app.media.ic_star'),
  'heart': $r('app.media.ic_heart'),
  'eye': $r('app.media.ic_eye'),
  'clock': $r('app.media.ic_clock'),
  // 「我的」页 / 设置页 / 关于页的列表行图标（CfListRow 的 icon 槽）
  'coin': $r('app.media.ic_coin'),
  'settings': $r('app.media.ic_settings'),
  'info': $r('app.media.ic_info_circle'),
  'edit': $r('app.media.ic_edit'),
  'cloud': $r('app.media.ic_cloud'),
  'upload': $r('app.media.ic_upload'),
  'receipt': $r('app.media.ic_receipt'),
  'flask': $r('app.media.ic_flask'),
  'ruler': $r('app.media.ic_ruler'),
  'calculator': $r('app.media.ic_calculator'),
  'bulb': $r('app.media.ic_bulb'),
  'device': $r('app.media.ic_device_mobile'),
  'tree': $r('app.media.ic_plant_2'),
  'sprout': $r('app.media.ic_seedling'),
  'leaf': $r('app.media.ic_leaf'),
  'world': $r('app.media.ic_world'),
  'inbox': $r('app.media.ic_inbox'),
  'lock': $r('app.media.ic_lock'),
  'photo': $r('app.media.ic_photo'),
  'brain': $r('app.media.ic_brain'),
  'thumbup': $r('app.media.ic_thumb_up'),
  'warn': $r('app.media.ic_alert_triangle'),
  'note': $r('app.media.ic_note'),
  'pin': $r('app.media.ic_pin'),
  'up': $r('app.media.ic_trending_up'),
  'down': $r('app.media.ic_trending_down'),
  'chart': $r('app.media.ic_chart_bar'),
  'calendar': $r('app.media.ic_calendar'),
  'wifi': $r('app.media.ic_wifi'),
  'download': $r('app.media.ic_download'),
  'gift': $r('app.media.ic_gift'),
  'ticket': $r('app.media.ic_ticket'),
  'refresh': $r('app.media.ic_refresh'),
  'trash': $r('app.media.ic_trash'),
  // 组件槽位扫尾（按钮/统计卡/空态/引导页）
  'arrowup': $r('app.media.ic_arrow_up_right'),
  'robot': $r('app.media.ic_robot'),
  'folder': $r('app.media.ic_folder'),
  'unlock': $r('app.media.ic_lock_open'),
  'mail': $r('app.media.ic_mail'),
  'cash': $r('app.media.ic_cash'),
  'moon': $r('app.media.ic_moon'),
  'sun': $r('app.media.ic_sun'),
  'close': $r('app.media.ic_x'),
  // 「关于」页碳足迹小科普的 4 条
  'footprint': $r('app.media.ic_footsteps'),
  'commute': $r('app.media.ic_walk'),
  'plate': $r('app.media.ic_bowl'),
  'trophy': $r('app.media.ic_trophy')
};

/**
 * 取图标资源。
 * @param kind factor / category / task / badge / benefit / article / level / tip / ui
 * @param code 语义 code（itemCode、taskCode、badgeCode、benefitCode、articleId、level、tipId、ui 名）
 */
export function iconOf(kind: string, code: string): Resource {
  let r: Resource | undefined = undefined;
  if (kind === 'factor') {
    r = FACTOR[code];
  } else if (kind === 'category') {
    r = CATEGORY[code];
  } else if (kind === 'task') {
    r = TASK[code];
  } else if (kind === 'badge') {
    r = BADGE[code];
  } else if (kind === 'benefit') {
    r = BENEFIT[code];
  } else if (kind === 'article') {
    r = ARTICLE[code];
  } else if (kind === 'level') {
    r = LEVEL[code];
  } else if (kind === 'tip') {
    r = TIP[code];
  } else {
    r = UI[code];
  }
  return r !== undefined ? r : FALLBACK;
}
