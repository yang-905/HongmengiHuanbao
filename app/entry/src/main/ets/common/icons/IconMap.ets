const FALLBACK: Resource = $r('app.media.ic_target');

const FACTOR: Record<string, Resource> = {
  'walk': $r('app.media.ic_walk'),
  'bike': $r('app.media.ic_bike'),
  'bus': $r('app.media.ic_bus'),
  'metro': $r('app.media.ic_train'),
  'evcar': $r('app.media.ic_charging_pile'),
  'carpool': $r('app.media.ic_car'),
  'elec': $r('app.media.ic_bolt'),
  'water': $r('app.media.ic_droplet'),
  'gas': $r('app.media.ic_flame'),
  'paper': $r('app.media.ic_file_text'),
  'ac26': $r('app.media.ic_air_conditioning'),
  'unplug': $r('app.media.ic_plug_off'),
  'paper_waste': $r('app.media.ic_file_stack'),
  'plastic': $r('app.media.ic_bottle'),
  'metal': $r('app.media.ic_tools'),
  'glass': $r('app.media.ic_glass_full'),
  'clothes': $r('app.media.ic_shirt'),
  'ewaste': $r('app.media.ic_device_mobile'),
  'donate': $r('app.media.ic_gift'),
  'secondhand': $r('app.media.ic_arrows_exchange'),
  'clearplate': $r('app.media.ic_bowl'),
  'veggie': $r('app.media.ic_salad'),
  'lunchbox': $r('app.media.ic_tools_kitchen_2'),
  'bag': $r('app.media.ic_shopping_bag'),
  'cup': $r('app.media.ic_cup'),
  'nochopsticks': $r('app.media.ic_forbid'),
  'classify': $r('app.media.ic_trash')
};

const CATEGORY: Record<string, Resource> = {
  'travel': $r('app.media.ic_route'),
  'energy': $r('app.media.ic_bulb'),
  'recycle': $r('app.media.ic_recycle'),
  'food': $r('app.media.ic_tools_kitchen')
};

const TASK: Record<string, Resource> = {
  'task_travel': $r('app.media.ic_route'),
  'task_energy': $r('app.media.ic_bulb'),
  'task_recycle': $r('app.media.ic_recycle'),
  'task_food': $r('app.media.ic_tools_kitchen'),
  'task_checkin': $r('app.media.ic_check')
};

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

const BENEFIT: Record<string, Resource> = {
  'b1': $r('app.media.ic_bus'),
  'b2': $r('app.media.ic_ticket'),
  'b3': $r('app.media.ic_bike'),
  'b4': $r('app.media.ic_charging_pile'),
  'b5': $r('app.media.ic_gift'),
  'b6': $r('app.media.ic_shopping_cart'),
  'b7': $r('app.media.ic_trees'),
  'b8': $r('app.media.ic_award')
};

const ARTICLE: Record<string, Resource> = {
  '800': $r('app.media.ic_building_bank'),
  '801': $r('app.media.ic_footsteps'),
  '802': $r('app.media.ic_bike'),
  '803': $r('app.media.ic_recycle'),
  '804': $r('app.media.ic_tools_kitchen'),
  '805': $r('app.media.ic_refresh'),
  '806': $r('app.media.ic_charging_pile'),
  '807': $r('app.media.ic_building'),
  '808': $r('app.media.ic_award'),
  '809': $r('app.media.ic_school')
};

const LEVEL: Record<string, Resource> = {
  '1': $r('app.media.ic_seedling'),
  '2': $r('app.media.ic_plant_2'),
  '3': $r('app.media.ic_leaf'),
  '4': $r('app.media.ic_award'),
  '5': $r('app.media.ic_trees')
};

const TIP: Record<string, Resource> = {
  't1': $r('app.media.ic_route'),
  't2': $r('app.media.ic_bulb'),
  't3': $r('app.media.ic_recycle'),
  't4': $r('app.media.ic_tools_kitchen'),
  't5': $r('app.media.ic_target'),
  't6': $r('app.media.ic_trees')
};

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
  'arrowup': $r('app.media.ic_arrow_up_right'),
  'robot': $r('app.media.ic_robot'),
  'folder': $r('app.media.ic_folder'),
  'unlock': $r('app.media.ic_lock_open'),
  'mail': $r('app.media.ic_mail'),
  'cash': $r('app.media.ic_cash'),
  'moon': $r('app.media.ic_moon'),
  'sun': $r('app.media.ic_sun'),
  'close': $r('app.media.ic_x'),
  'footprint': $r('app.media.ic_footsteps'),
  'commute': $r('app.media.ic_walk'),
  'plate': $r('app.media.ic_bowl'),
  'trophy': $r('app.media.ic_trophy')
};

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
