import { Toast, toast } from '../ui/Toast'
import { AppRouter, RouteName } from '../common/router/AppRouter'
import { PageMap } from '../common/router/PageMap'
import { SplashPage } from './SplashPage'
import { OnboardingPage } from './OnboardingPage'
import { LoginGate } from './auth/LoginGate'
import { DashboardPage } from './dashboard/DashboardPage'
import { RecordListPage } from './record/RecordListPage'
import { ArticleListPage } from './article/ArticleListPage'
import { MinePage } from './mine/MinePage'
import { BehaviorAddSheet } from './behavior/BehaviorAddSheet'
import { Accent, EcoTheme, FontSize, Glass, Neutral, Radius, Space, ThemePalette, isDarkMode } from '../ui/Theme';
import { CfIcon } from '../ui/Icon';
import { GlassLight, GlassTier } from '../ui/GlassLight';
import { ThemeMode } from '../data/ThemeMode';
import { EcoMoodState } from '../data/EcoMoodState';
import { Configuration, ConfigurationConstant, common } from '@kit.AbilityKit';
import { AppleMotion } from '../ui/AppleMotion';

// 注：底部胶囊 / 滑动药丸 / 圆钮均改走 GlassLight.surface() 单层 135° 合成渐变，
// 不再需要 GlassLightLayers（平涂底色会把光照层盖住，两层打架只剩不透观感）。

/**
 * 底部胶囊形态切换时长（ms）。
 * 与 animateCapsule 里 setTimeout 收尾的时长必须一致，
 * 否则 capsuleGone 提前/延后切换会看到胶囊「闪没」或「滞留」。
 */
const CAPSULE_ANIM_MS: number = 360
/**
 * 胶囊退场缩放。
 * ⚠️ 0.12 → 0.34（本轮调整）：0.12 把胶囊压成一个几乎看不见的点，
 *   加上 opacity 归零，观感是「凭空消失」而不是「被吸进加号」；
 *   0.34 保留了「一颗小胶囊滑进加号」的完整动作语义，
 *   且缩放幅度小 → backdropBlur 离屏层的重算面积更小、更流畅。
 */
const CAPSULE_EXIT_SCALE: number = 0.34
/**
 * Tab 切换时长（ms）：药丸滑动、文字高亮、整页滑动共用同一段动画。
 * 三者由 switchTab 里**同一个 animateTo** 驱动 —— 同帧开始、
 * 同时长、同曲线（EaseInOut），因此同时结束，观感是一个整体动作。
 * 300ms 是「滑得到位又不拖沓」的平衡点。
 */
const TAB_ANIM_MS: number = 300

/**
 * P00 主框架：唯一 @Entry
 * ------------------------------------------------------------------
 *结构：Stack 叠两层
 *   ① Navigation(Tabs) —— 四个业务 Tab 承载内容与进栈页面
 *   ② 液态玻璃底部导航（参考鸿蒙 7 / 大疆 DJI MIMO 布局）：
 *      左侧「4 格胶囊」+ 右侧「独立圆形 ＋ 按钮」，二者并列、间距 10。
 *      · 主 Tab 页：两者都显示，选中药丸随 currentTab 平移滑动
 *      · 子页面  ：左侧胶囊整体隐藏（含药丸 / 图标 / 文字 / 玻璃），
 *        只留右侧那颗圆钮，点击照样弹出行为录入面板
 *
 * 首屏 Splash / 首启引导以条件渲染覆盖，不占路由。
 *
 * ── 性能要点（实测踩坑，务必保留）────────────────────────
 * 1. backdropBlur 会为组件创建离屏渲染层，每帧重新采样背景像素。
 *    同一区域**不可叠加两层** —— 药丸若再套一层 backdropBlur，
 *    滑动时会明显掉帧。因此药丸只用半透明色 + 描边，不加模糊。
 * 2. 药丸的 shadow 同样每帧重绘，卡顿明显，已去掉。
 * 3. 药丸平移只改 translate（纯合成层操作，不触发布局重排）。
 * 4. Tab 切换：药丸 / 文字高亮 / 整页滑动由**同一个 animateTo** 驱动
 *    （300ms EaseInOut），同帧开始同时结束；页面位移只改 translate
 *    （纯合成层），页面本身不重建，动画期间主线程空闲
 *    （见 switchTab / contentTransition）。
 * 5. 胶囊进出子页面**不是** visibility 秒切：秒切等于「直接消失」，
 *    观感简陋，且 Blank 不占位会让「＋」钮同时跳到左侧。
 *    现改为 translate（滑向＋钮）+ scale（缩小）+ opacity（淡出）
 *    三件套补间 360ms，播完才 visibility 移除（见 animateCapsule）。
 *    translate/scale/opacity 均不参与布局计算，动画期间
 *    胶囊仍占 layoutWeight(1)，「＋」钮不会被挤动。
 * 6. 「＋」圆钮进出表单页（hideFab 标记）同样不是秒切：缩放 + 淡出
 *    补间 360ms、与胶囊同参数，播完才置 fabGone 退布局（见 onHideFab）。
 *    胶囊**返场改原位展开**（不再从＋钮位置长回）—— 用户反馈
 *    「导航栏动画会占据加号位置」，与同时返场的圆钮糊成一团。
 */
@Entry
@Component
struct Index {
  /*
   * 深色模式依赖注入（ArkUI 按属性表达式粒度更新）：
   * 色值/光照经 tc/tw 取值即建立 themeTick 依赖，换肤广播后强制重取
   * static 新色；td 同型用于 ThemePalette.dark 布尔分流。
   */
  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }
  private tw<T>(v: T): T {
    return this.themeTick >= 0 ? v : v
  }
  private td(): boolean {
    return this.themeTick >= 0 ? isDarkMode() : isDarkMode()
  }

  @StorageProp('themeTick') themeTick: number = 0
  @State private currentTab: number = 0
  /**
   * 主内容区实测宽度（vp）：Tab 切换时整页滑动一屏的距离。
   * 由包裹 Tabs 的 Column 的 onAreaChange 实测提供。
   */
  @State private contentW: number = 0

  /**
   * 四个一级页的横向位移（vp）：Tab 切换时旧页滑出、新页滑入。
   * ⚠️ 用四个独立 @State 而不是 number[]：@State 数组**元素**赋值
   * （this.pageShift[0] = x）不会触发刷新，必须整数组替换才行，
   * 四个独立变量写起来反而更直白。
   */
  @State private pageShift0: number = 0
  @State private pageShift1: number = 0
  @State private pageShift2: number = 0
  @State private pageShift3: number = 0
  @State private showSplash: boolean = true
  @State private showOnboarding: boolean = false
  /** 是否处于子页面（路由栈有内容）：决定胶囊是长条还是右侧圆珠 */
  @State private onSubPage: boolean = false
  /** 胶囊长条状态的实测宽度，供药丸平移计算 */
  @State private barW: number = 0
  /**
   * 底部栏容器实测宽度（**胶囊自身**的宽度）。
   * ⚠️ 与 `barW`（内层 4 格文字 Row 的宽度）区分开：
   *   退场位移必须用**胶囊自身宽度**，用内层文字宽度会在胶囊
   *   visibility(None) 时跟着漂移 —— 那正是「＋ 钮进入二级页会往左一点」
   *   的成因（`capsuleShift` 终点变了，整条底栏视觉上像被推着挪了位）。
   */
  @State private capsuleW: number = 0
  /**
   * 底部栏插槽：**二级页是否接管了导航条的位置**。
   * ------------------------------------------------------------------
   * 用户诉求「有个导航条消失的动画吗，然后让同尺寸的删除按键代替导航条的位置」。
   * 删除条原先渲染在 BehaviorDetailPage **自己的布局里**（页面内另占一行），
   * 而导航胶囊渲染在 Index 的底部栏 —— 两个不同父容器，
   * 所以删除条永远只能"另起一行"，无法"填补导航条消失后的空位"。
   *
   * 现改为插槽：二级页进入时 `AppStorage.set('barSlotDelete', true)`，
   * Index 在**同一个槽位**里改渲染删除条（取代导航胶囊）——
   * 宽高、底边、间距天然一致，视觉上就是「导航条收起来、删除条原地接班」。
   *
   * ⚠️ 为什么传**布尔标志**而不是传渲染函数：
   *   ArkTS 禁止把函数当值传递（编译报 `arkts-no-func-apply-call`，`.call()` 不支持），
   *   @StorageLink 存函数类型无法通过编译。故只传 flag，组件仍由 Index 本地渲染。
   *
   * @StorageLink 订阅：进入/退出二级页都会触发 Index 重建。
   */
  @StorageLink('barSlotDelete') barSlotDelete: boolean = false
  /**
   * 隐藏右下角「＋」悬浮球标记（ProfilePage 等表单页置 true）。
   * 表单页底部有输入框，悬浮球压字；页面 aboutToAppear/Disappear 维护本标记，
   * @StorageLink 订阅变化 → onHideFab 驱动**补间动画**后置 fabGone 退布局
   * （旧版 visibility 秒切，退出资料页时圆钮「直接出来没有动画」——
   *  2026-10-20 用户反馈，见 onHideFab）。
   */
  @StorageLink('hideFab') @Watch('onHideFab') hideFab: boolean = false
  /**
   * 删除条入场动画状态（用户反馈「弹出太快了，改成和导航栏一样的」）。
   * 初值 false → 缩放小 / 右偏 / 透明；onAppear 后置 true 触发 360ms 补间，
   * 与导航胶囊退场/返场（CAPSULE_ANIM_MS）**同一时长、互为逆过程**。
   * ⚠️ 必须在删除条所在组件（Index）里持有 —— 原先放在详情页的
   * `barEntered` 与删除条不同组件，搬成覆盖层后动画彻底失效。
   */
  @State private slotDeleteIn: boolean = false
  /**
   * 删除条点击信号：Index 渲染删除条（因函数不可跨组件传递），
   * 真正的删除确认由二级页监听本计数器的自增来触发。
   */
  @StorageLink('barSlotDeleteTick') slotDeleteTick: number = 0
  /** 删除条文案（「删除中…」态由二级页回写） */
  @StorageLink('barSlotDeleteLabel') slotDeleteLabel: string = '删除记录'
  /** 右侧圆钮按下态：用于缩放反馈 */
  @State private orbPressed: boolean = false

  /**
   * 底部胶囊退场三件套：位移 / 缩放 / 透明度。
   * 进入子页面时胶囊「滑向＋钮 → 缩成小点 → 淡出」一气呵成，
   * 取代原来的 visibility 秒切（那才是「直接消失、太简陋」的根因）。
   */
  @State private capsuleShift: number = 0
  @State private capsuleScale: number = 1
  @State private capsuleAlpha: number = 1

  /**
   * 退场动画播完才置 true，胶囊才真正退出布局。
   * ⚠️ 不能提前：visibility 一旦为 None，组件当场退出渲染，
   * 位移/缩放/淡出一帧都看不到，等于没做动画。
   */
  @State private capsuleGone: boolean = false
  /** 胶囊退场动画收尾定时器 id，-1 表示未启动 */
  private capsuleTimer: number = -1

  /**
   * 「＋」圆钮退场三件套：缩放 / 透明度 / 退布局。
   * ------------------------------------------------------------------
   * 用户反馈（2026-10-20）：「从二级菜单退出，那个＋号会直接出来没有动画」。
   * 根因：圆钮 visibility 由 hideFab 直接驱动，true/false 都是**瞬间切换**，
   * 没有任何补间 —— 退场像「闪没」，返场像「闪现」。
   * 现与胶囊同范式：hideFab 变化 → onHideFab 播 CAPSULE_ANIM_MS 补间
   * （缩放 + 淡出，EaseIn 退 / EaseOut 返），播完才置 fabGone 退布局。
   * 中途反复切（快速进出资料页）先清定时器，animateTo 从当前渲染态续补。
   */
  @State private fabScale: number = 1
  @State private fabAlpha: number = 1
  @State private fabGone: boolean = false
  /** 圆钮退场动画收尾定时器 id，-1 表示未启动 */
  private fabTimer: number = -1

  /**
   * 注册引导误触闸门（用户反馈「注册后资料页出来有点慢，会提前摁到
   * 主页的东西」）。
   * ------------------------------------------------------------------
   * 时序断点：注册成功 → 本组件重建挂载主框架 → Navigation onAppear 才
   * push 强制资料页。从主框架可见到资料页盖住屏幕有一段转场空窗
   * （主框架淡入 + push 滑入），这期间主页（Tab/卡片/底部＋钮）
   * 完全是可点的 —— 用户注册完手指正悬在屏上，一戳就误触。
   *
   * 闸门口径（三段式）：
   *   ① **预置**：注册意图标记在 register() 之前就落，onSessionUser
   *      （@Watch，早于重建）读到即把闸门拉起 —— 主框架**第一帧**
   *      就是锁死的，空窗期被彻底消除；
   *   ② **保持**：Navigation onAppear 里 push 前再置一次（兜底路径）；
   *   ③ **解除**：资料页真正上屏（ProfilePage 根节点 onAppear）后
   *      延迟一拍解锁，避开 push 滑入动画期间主框架仍可见的那一段。
   *
   * ⚠️ 为什么闸门不用 @State 而是普通字段 + tick：
   *   闸门必须在**主框架挂载的那一帧**就生效。@State 的赋值要等下一
   *   次 build 才落到属性上（理论上可能晚一帧 ≈16ms），而普通字段在
   *   build() 里读到的一定是最新值 —— 用「普通字段存真值 + @State
   *   tick 触发重渲染」的口径，零帧延迟。
   */
  private profileGate: boolean = false
  /** 闸门真值变更的强制重渲染触发器（数值本身无意义，只看变化次数） */
  @State private profileGateTick: number = 0
  /** 闸门兜底解封定时器 id（信号丢失时防永久锁死），-1 表示未启动 */
  private profileGateTimer: number = -1
  /** 资料页上屏后的解封宽限定时器 id（避开 push 滑入动画），-1 表示未启动 */
  private profileUnlockTimer: number = -1
  /** 资料页已上屏信号（ProfilePage 根节点 onAppear 时置 true，本类一次性消费） */
  @StorageProp('profileSetupShown') @Watch('onProfileSetupShown') profileSetupShown: boolean = false

  /** 置闸门（true = 锁死主框架交互）。普通字段立即生效 + tick 驱动重渲染 */
  private setProfileGate(on: boolean): void {
    if (this.profileGate === on) return
    this.profileGate = on
    this.profileGateTick++
  }

  /** 清闸门兜底定时器 */
  private clearProfileGateTimer(): void {
    if (this.profileGateTimer !== -1) {
      clearTimeout(this.profileGateTimer)
      this.profileGateTimer = -1
    }
  }

  /** 清解封宽限定时器 */
  private clearProfileUnlockTimer(): void {
    if (this.profileUnlockTimer !== -1) {
      clearTimeout(this.profileUnlockTimer)
      this.profileUnlockTimer = -1
    }
  }

  /**
   * 全局碳情绪档位（响应式）。
   * 底部导航常驻全局，Tab 选中色与加号图标色需跟随档位，
   * 否则一级页面已是红色警示、底部导航却还是绿，自相矛盾。
   */
  @StorageProp('ecoLevel') ecoLevel: string = 'none'
  @StorageLink('showAddSheet') private showAddSheet: boolean = false

  /**
   * 登录闸门状态（AccountStore 驱动）。
   * ------------------------------------------------------------------
   * sessionReady = 启动同步（账号表/上次会话读盘）已完成，才允许分流。
   * ⚠️ 默认值必须是 **true**：预览器不执行 UIAbility 生命周期，
   *   EntryAbility 里的 AccountStore.init 永远不会运行，若默认 false
   *   闸门会卡死在「启动同步中」的空底 → 整页白屏（实际踩坑）。
   *   真机路径由 onCreate 提前踢 AccountStore.init()，其同步前缀
   *   先于首帧把本值写回 false，读盘后再置 true —— 不受此默认影响。
   * sessionUser = 当前会话账号，空串 = 未登录 → 整屏渲染 LoginGate。
   * 登录/注册成功 → AccountStore 写 AppStorage → 本组件重建 →
   * else 分支（主框架）整体挂载；注销/切换账号反向翻转。
   * 整树挂载/卸载正是多账号数据隔离的机制：各页 aboutToAppear 重跑，
   * 读到的是新账号命名空间的 LocalStore。
   */
  @StorageLink('sessionReady') sessionReady: boolean = true
  @StorageLink('sessionUser') @Watch('onSessionUser') sessionUser: string = ''
  private pathStack: NavPathStack = AppRouter.pathStack
  /**
   * Tabs 控制器。⚠️ Tab 切换必须走 changeIndex()，**不能改 index 属性**：
   * 官方文档明确「直接修改 index 跳页时，切换动效不生效」，
   * customContentTransition 自定义转场也只由「点击页签 /
   * changeIndex()」两种场景触发。index 属性已从 Tabs 上移除，
   * currentTab 只作我们自己的簿记（药丸/高亮/守卫用）。
   */
  private tabsController: TabsController = new TabsController()
  /** 路由栈轮询定时器 id，-1 表示未启动 */
  private stackTimer: number = -1
  /** 启动页关闭定时器 id，-1 表示未启动 */
  private splashTimer: number = -1

  /**
   * 启动页之下的主体内容透明度。
   * 启动页显示时为 0（完全隐藏），启动页开始淡出时过渡到 1，
   * 避免「启动页突然消失 + 主体突然出现」的生硬切换。
   */
  @State private splashContentOpacity: number = 0
  /** 主体内容的入场缩放（配合透明度做轻微推近） */
  @State private splashContentScale: number = 0.98

  /**
   * 关闭启动页：主体内容淡入 + 启动页淡出（420ms）。
   * 定时器与点击跳过两条路径都走这里，保证观感一致。
   */
  private fadeOutSplash(): void {
    if (this.splashTimer !== -1) {
      clearTimeout(this.splashTimer)
      this.splashTimer = -1
    }
    this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseInOut }, (): void => {
      // 先让底层内容浮现，再撤掉启动页，两者在同一段动画里交叉过渡
      this.splashContentOpacity = 1
      this.splashContentScale = 1
      this.showSplash = false
    })
  }

  /**
   * 读取当前系统 / 预览器设备的深色状态。
   * ------------------------------------------------------------------
   * 真机路径由 EntryAbility.systemInDarkMode() 读取后传给 ThemeMode.init；
   * 预览器不跑 UIAbility 生命周期，只能由 @Entry 在这里补读
   * （预览器工具栏把预览设备切成深色时，config.colorMode 即反映该状态）。
   * 读不到按浅色兜底，绝不抛错中断启动链。
   */
  private systemInDarkMode(): boolean {
    try {
      // config 挂在 UIAbilityContext 上（getHostContext() 返回基类 Context，需强转）
      const hostCtx: common.UIAbilityContext | undefined =
        this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
      const cfg: Configuration | undefined = hostCtx?.config
      if (cfg !== undefined && cfg !== null && cfg.colorMode !== undefined) {
        return cfg.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      }
    } catch (err) {
      console.warn('[Index] 读取系统 colorMode 失败，按浅色兜底')
    }
    return false
  }

aboutToAppear(): void {
    // 绑定 UI 上下文，让 Toast 走 UIContext 新 API（消除 deprecation 告警）
    Toast.bind(this.getUIContext())
    /*
     * 预览器兜底：预览器不执行 UIAbility 生命周期，EntryAbility.onCreate 里的
     * ThemeMode.init 永不运行，AppStorage 的换肤广播键（themeTick / darkMode）
     * 无人创建 → 各页 @StorageProp('themeTick') 订阅链路断掉 →
     * 设置页拨动深色开关后页面收不到通知，表现为「预览器里深色模式没反应」。
     * 真机由 init 在启动期播种；预览器改由这里（@Entry 唯一稳定会跑的生命周期）
     * 补一次，保证键在任意页面挂载前已存在。幂等：键已存在则直接返回。
     * 传入系统深色状态：预览器刷新后用户拨过的开关活不过一次刷新
     * （Preferences 在预览器不可用），此时按「跟随系统」语义定首帧 ——
     * 预览器设备切深色 → 初次打开即深色、刷新后也保持一致。
     */
    ThemeMode.ensureInit(this.systemInDarkMode())
    /*
     * 启动页时序：停留 → 淡出。
     *   · 停留 1600ms：让「一触青绿」品牌名与 logo 有完整展示时间
     *     （原为 1400ms，稍显仓促；这里放宽到 1600ms）
     *   · 再用 420ms 的 animateTo 做透明度淡出 + 轻微缩放，
     *     直接置 false 会是硬切，观感像闪屏
     *   · 兜底：SplashPage 自带 onClick，用户随时可跳过
     */
    this.splashTimer = setTimeout((): void => {
      this.fadeOutSplash()
    }, 1600)
    // 广播初始激活页：供各一级页「切回本页即刷新」使用
    // （本应用自定义 Tab 转场下 onPageShow 不可靠，见 RecordListPage 注释）
    AppStorage.set<number>('activeTab', this.currentTab)
    // 路由栈没有变化回调，这里用低频轮询感知进出子页面。
    // 频率 400ms：pathStack.size() 是 ArkTS→C++ 的跨语言调用，
    // 频率太高会持续占用主线程，间接导致动画掉帧。
    // 返回操作另有 onPageShow 立即同步，所以 400ms 完全够用。
    this.stackTimer = setInterval((): void => {
      this.syncStackState()
    }, 400)
  }

aboutToDisappear(): void {
    if (this.stackTimer !== -1) {
      clearInterval(this.stackTimer)
      this.stackTimer = -1
    }
    if (this.splashTimer !== -1) {
      clearTimeout(this.splashTimer)
      this.splashTimer = -1
    }
    if (this.capsuleTimer !== -1) {
      clearTimeout(this.capsuleTimer)
      this.capsuleTimer = -1
    }
    if (this.fabTimer !== -1) {
      clearTimeout(this.fabTimer)
      this.fabTimer = -1
    }
    if (this.profileGateTimer !== -1) {
      clearTimeout(this.profileGateTimer)
      this.profileGateTimer = -1
    }
    if (this.profileUnlockTimer !== -1) {
      clearTimeout(this.profileUnlockTimer)
      this.profileUnlockTimer = -1
    }
  }

  /**
   * 会话变化善后（登录 / 注销 / 切换账号全走这里，@Watch 在重建前触发）。
   * ------------------------------------------------------------------
   * 背景（用户实测反馈「切换账号后再次进入白屏，只能点导航栏刷新」）：
   *   旧口径 ProfilePage 在自己还压栈于 AppRouter.pathStack 上时就
   *   pathStack.clear()，紧接着 logout 经闸门把整棵 Navigation 卸载 ——
   *   弹栈与页面销毁被整体卸载打断，NavPathStack 内部态留在半销毁状态；
   *   重新登录后新 Navigation 复用同一栈实例，内容区渲染不出来 = 白屏
   *   （点一下底部 Tab 触发重建才恢复）。
   *   同时旧会话残留（currentTab / 位移 / 底部栏插槽标记 / 路由栈记录）
   *   会让新会话第一帧就错位或缺件。
   *
   * 现在统一在这里善后：
   *   · 登录侧（sessionUser 非空）：Tab 簿记与位移复位、底部导航/删除条/
   *     悬浮球标记清回主 Tab 形态、清空路由栈记录（此刻旧会话的整棵树
   *     已随上次闸门翻转销毁，没有任何 Navigation 挂在栈上，纯数据操作，
   *     安全）、碳情绪按新账号数据重算；
   *   · 注销侧（sessionUser 空）：碳情绪回初始档，登录页中性底色。
   */
  private onSessionUser(): void {
    if (this.sessionUser.length === 0) {
      // 注销 / 切换账号：未登录 = 无数据语境，碳情绪回初始档
      EcoMoodState.reset()
      return
    }
    // ---- 登录 / 注册 / 恢复会话：主框架即将整体挂载，先清残留 ----
    /*
     * ⚠️ 注册引导闸门**预置**（用户反馈「注册成功后信息录入页比主页面
     * 弹出的慢，手快能立即点到子页面」）。
     *
     * 为什么必须在这里预置：@Watch 回调在状态变化时触发、**早于**本组件
     * 重建。Navigation.onAppear 是渲染后才触发的 —— 四个 TabContent
     * （Dashboard/Record/Article/Mine）构造开销大，首帧成本高，onAppear
     * 迟到；主框架「已可见可点」而闸门「还没关」的空窗就是这么来的。
     * 在 onSessionUser（重建前）预置，主框架第一帧就是锁死的。
     *
     * 判定依据是 LoginGate 在 await register() **之前**落的
     * profileSetupIntent 标记 —— register() 内部 setSession 会同步触发
     * 本回调，标记晚一步就读不到（这正是「意图标记晚于会话变更」的
     * 竞态）。消费即清，避免下次登录被误判成注册流程。
     */
    if (AppStorage.get<boolean>('profileSetupIntent') === true) {
      AppStorage.setOrCreate('profileSetupIntent', false)
      this.setProfileGate(true)
      this.clearProfileGateTimer()
      /*
       * 兜底解封：资料页上屏信号（profileSetupShown）万一丢失
       * （push 失败 / 页面构建异常），不能让用户被永久锁在主框架外。
       * 4s 足够长 —— 覆盖 push 动画 + 资料页首帧构建的全部延迟。
       */
      this.profileGateTimer = setTimeout((): void => {
        this.setProfileGate(false)
        this.profileGateTimer = -1
      }, 4000)
    }
    this.currentTab = 0
    AppStorage.setOrCreate<number>('activeTab', 0)
    this.setPageShift(0, 0)
    this.setPageShift(1, 0)
    this.setPageShift(2, 0)
    this.setPageShift(3, 0)
    // 底部导航形态复位：旧会话停在子页面时胶囊是收起态，不复位的话
    // 新会话第一帧底部只剩「＋」圆钮（要等 400ms 轮询才恢复）
    this.onSubPage = false
    this.capsuleGone = false
    this.capsuleShift = 0
    this.capsuleScale = 1
    this.capsuleAlpha = 1
    // 圆钮同步复位：旧会话若停在表单页（hideFab=true 且退场定时器还在跑），
    // 新会话第一帧圆钮必须是完整可见态 —— 先清定时器防它播完又把
    // fabGone 置 true（复位白做），再复位三件套。
    if (this.fabTimer !== -1) {
      clearTimeout(this.fabTimer)
      this.fabTimer = -1
    }
    this.fabGone = false
    this.fabScale = 1
    this.fabAlpha = 1
    this.slotDeleteIn = false
    AppStorage.setOrCreate('barSlotDelete', false)
    AppStorage.setOrCreate('hideFab', false)
    /*
     * 路由栈记录不会随 Navigation 卸载自动消失：不清的话新 Navigation
     * 挂载时会尝试恢复旧会话的页面（半销毁栈 + 旧页面 = 白屏元凶）。
     * 此刻没有任何 Navigation 绑着这个栈（旧会话的树已销毁），
     * clear 是纯数据操作，不会重演「弹栈被卸载打断」事故。
     */
    if (this.pathStack.size() > 0) {
      this.pathStack.clear()
    }
    /*
     * 碳情绪按新账号数据重算。setSession 里已做过一次 resetForAccount，
     * 这里兜底覆盖「启动恢复会话」等不经 setSession 的路径
     * （EntryAbility 直接写 session_ + SESSION_KEY）。幂等，无副作用。
     */
    EcoMoodState.refresh()
  }

  /**
   * 资料页已上屏 → 解除注册引导误触闸门（一次性消费信号）。
   * ProfilePage 根节点 onAppear 时置 true；此处消费后复位键。
   * 闸门本就没开（普通入口进资料页）时静默跳过。
   *
   * ⚠️ 解封不是立刻：资料页「出现」到「完全盖住屏幕」还有一段 push
   * 滑入动画，动画期间主框架仍部分可见可点。延后一帧宽限期再解锁，
   * 让这段动画完整跑完 —— 这是用户「手快点到子页面」的最后一环。
   */
  private onProfileSetupShown(): void {
    if (!this.profileSetupShown) return
    AppStorage.setOrCreate('profileSetupShown', false)
    this.clearProfileGateTimer()
    this.clearProfileUnlockTimer()
    this.profileUnlockTimer = setTimeout((): void => {
      this.setProfileGate(false)
      this.profileUnlockTimer = -1
    }, 420)
  }

  /**
   * 页面重新可见时同步路由栈（返回操作会触发，比等轮询快）。
   *
   * ⚠️ 这里**不能**顺手关闭启动页：
   *   ArkUI 在页面**首次创建后就会立刻触发一次 onPageShow**，
   *   若在此处 `showSplash = false`，开屏页刚显示就被立刻关掉（一闪而过，
   *   实际等于没有开屏页）。
   *   启动页的关闭只走两条正路：
   *     1) 定时器（aboutToAppear 里启动，到时自动关闭）
   *     2) 用户点击（SplashPage 自带 onClick 兜底）
   *   两者都在 aboutToAppear 中挂载，与 onPageShow 无关。
   */
  onPageShow(): void {
    this.syncStackState()
  }

  /** 同步路由栈状态：栈非空 = 处于子页面，胶囊收成右侧圆珠 */
  private syncStackState(): void {
    const deep: boolean = this.pathStack.size() > 0
    if (deep === this.onSubPage) return
    this.onSubPage = deep
    this.animateCapsule(deep)
  }

  /**
   * 胶囊形态切换动画（进/出子页面时由 syncStackState 调用）。
   *
   * 退场（deep）：胶囊**向右滑向「＋」钮 → 缩成小点 → 淡出**，
   *   位移量 = 胶囊半宽 + 10vp 间距 + 28vp 圆钮半径，
   *   保证胶囊中心正好落进＋钮中心 —— 即「在加号处消失」。
   *   动画播完（setTimeout 与 CAPSULE_ANIM_MS 等长）才置 capsuleGone
   *   让它退出布局；提前切 visibility 会一帧动画都看不到。
   * 返场：**原位展开**（不从＋钮里长回来）—— 先同步复位到「原位 +
   *   微缩小 + 透明」再动画展开，避免导航栏返场动画霸占＋钮位置
   *   （2026-10-20 用户反馈，详见返场分支注释）。
   *
   * ⚠️ 这里不用 animateTo 的完成回调 —— 该 SDK 的签名没有 onFinish 参数，
   * 只能用同 duration 的 setTimeout 收尾。
   * ⚠️ 中断安全：连点 push/pop 会先清掉上一个收尾定时器，
   *  animateTo 从「当前渲染态」补间，不会跳变。
   */
  private animateCapsule(deep: boolean): void {
    if (this.capsuleTimer !== -1) {
      clearTimeout(this.capsuleTimer)
      this.capsuleTimer = -1
    }
    if (deep) {
      this.getUIContext().animateTo({ duration: CAPSULE_ANIM_MS, curve: Curve.EaseIn }, (): void => {
        /*
         * ⚠️ 位移基准必须是**胶囊自身宽度**（capsuleW），不是内层文字 Row 宽度（barW）。
         *   原先 `barW / 2 + 38` 用的 barW 来自**内层 4 格文字 Row** 的 onAreaChange；
         *   胶囊退场时内层宽度会变 → 退场终点随之漂移，整条底栏像被推着挪位。
         *   capsuleW 挂在胶囊自身，一级/二级都不变，位移终点因此稳定。
         *
         * ⚠️ **不流畅的真正原因（本轮修复）**：位移量过大。
         *   原 `w/2 + 38` ≈ 300vp，而胶囊只有 56vp 高 —— 一个又宽又扁的胶囊
         *   要横跨 300vp 滑进加号，位移时长 360ms 意味着**平均速度 >800vp/s**，
         *   肉眼看到的是"被甩出去"，而不是"被吸进去"；而且胶囊带
         *   `backdropBlur`（每帧重建离屏渲染层），大范围位移会让离屏层
         *   每帧全量重算 —— 位移越大越卡。
         *
         *   现改为**短位移 + 快收缩**：横向只走到 `w*0.5+30`（约半程），
         *   缩放从 0.12 提到 0.34（更接近真实观感，不会缩成一个点），
         *   Curve.EaseIn 让它"越走越快"地滑入加号 —— 符合"被吸入"的物理直觉，
         *   位移量减半也让 blur 离屏层的重算面积大幅下降。
         */
        const w: number = this.capsuleW > 0 ? this.capsuleW : this.barW
        this.capsuleShift = w * 0.5 + 30
        this.capsuleScale = CAPSULE_EXIT_SCALE
        this.capsuleAlpha = 0
      })
      this.capsuleTimer = setTimeout((): void => {
        this.capsuleGone = true
        this.capsuleTimer = -1
      }, CAPSULE_ANIM_MS)
    } else {
      // 返场：胶囊重新参与布局（此刻仍是缩小透明态），
      // 同时**复位删除条入场状态** —— 保证下一次进二级页还能播入场动画。
      // ⚠️ 不能在 build() 里做这种复位（渲染期改状态过于脆弱）：
      //   放这里，与胶囊返场同一时机，语义也更清晰。
      this.slotDeleteIn = false
      this.capsuleGone = false
      /*
       * ⚠️ 原位展开（2026-10-20 用户反馈「导航栏动画会占据加号位置」）：
       *   旧口径直接 animateTo(0/1/1)，起点是退场态（位移到＋钮处、
       *   scale 0.34、alpha 0）—— EaseOut 让 alpha 快速升起时胶囊
       *   **还在＋钮位置**，导航栏动画视觉上霸占了加号的位置，与同时
       *   返场的＋圆钮糊成一团。
       *   现先**同步复位**到「原位 + 微缩小 + 透明」（alpha=0 的同帧
       *   跳变肉眼不可见，胶囊从自己槽位原地长出），再动画展开到
       *   0/1/1 —— 全程不经过＋钮位置。退场「被吸进＋钮」的效果保留
       *   （用户此前认可的方向），只改返场。
       */
      this.capsuleShift = 0
      this.capsuleScale = 0.92
      this.capsuleAlpha = 0
      this.getUIContext().animateTo({ duration: CAPSULE_ANIM_MS, curve: Curve.EaseOut }, (): void => {
        this.capsuleShift = 0
        this.capsuleScale = 1
        this.capsuleAlpha = 1
      })
    }
  }

  /**
   * 「＋」圆钮显隐补间（@Watch on hideFab，ProfilePage/ArticleDetailPage
   * 在 aboutToAppear/Disappear 维护该标记）。
   * ------------------------------------------------------------------
   * 用户反馈（2026-10-20）：「从二级菜单退出，那个＋号会直接出来
   * 没有动画」。根因：圆钮 visibility 直接绑 hideFab，true/false 都是
   * **瞬间切换**，没有任何补间。
   * 现与胶囊退场同范式、同参数（CAPSULE_ANIM_MS / CAPSULE_EXIT_SCALE）：
   *   退场 EaseIn 缩小淡出 → 播完才置 fabGone 退布局（提前切
   *     visibility 会一帧动画都看不到，同 capsuleGone 的教训）；
   *   返场先恢复可见（此刻仍是缩小透明态，肉眼不可见）→ EaseOut
   *     原地展开，互为逆过程。
   * ⚠️ animateTo 从当前渲染态补间：连点进出资料页不会跳变；
   * ⚠️ 收尾定时器先清再启，与 capsuleTimer 同款中断安全。
   */
  private onHideFab(): void {
    if (this.fabTimer !== -1) {
      clearTimeout(this.fabTimer)
      this.fabTimer = -1
    }
    if (this.hideFab) {
      this.getUIContext().animateTo({ duration: CAPSULE_ANIM_MS, curve: Curve.EaseIn }, (): void => {
        this.fabScale = CAPSULE_EXIT_SCALE
        this.fabAlpha = 0
      })
      this.fabTimer = setTimeout((): void => {
        this.fabGone = true
        this.fabTimer = -1
      }, CAPSULE_ANIM_MS)
    } else {
      // 返场：重新参与布局（此刻仍是缩小透明态），原地展开
      this.fabGone = false
      this.getUIContext().animateTo({ duration: CAPSULE_ANIM_MS, curve: Curve.EaseOut }, (): void => {
        this.fabScale = 1
        this.fabAlpha = 1
      })
    }
  }

  /**
   * 记录胶囊长条的实测宽度。
   * onAreaChange 回调里的 width 是 Length（number | string 百分比），
   * 这里只接受像素值，百分比形式直接忽略。
   */
  private onBarArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.barW) > 0.5) {
      this.barW = w
    }
  }

  /**
   * 记录**胶囊自身**宽度（退场位移基准）。
   * ⚠️ 必须挂在外层胶囊 Stack 上，不可与 barW（内层文字 Row）混用：
   *   胶囊 visibility(None) 时内层宽度会漂移，用它算终点会让＋钮「往左一点」。
   */
  private onCapsuleArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.capsuleW) > 0.5) {
      this.capsuleW = w
    }
  }

  /** 单格宽度（胶囊内均分 4 格） */
  private cellW(): number {
    return this.barW > 0 ? this.barW / 4 : 60
  }

  /** 药丸左偏移 = 选中序号 × 单格宽度（跟着 currentTab） */
  private pillX(): number {
    return this.cellW() * this.currentTab
  }

  /** 记录主内容区实测宽度（onAreaChange 的 width 可能是百分比，忽略） */
  private onContentArea(w: number | string): void {
    if (typeof w === 'string') return
    if (w > 0 && Math.abs(w - this.contentW) > 0.5) {
      this.contentW = w
    }
  }

  /** 按页索引写位移（四个独立 @State，绕开数组元素赋值不刷新的坑） */
  private setPageShift(index: number, v: number): void {
    if (index === 0) {
      this.pageShift0 = v
    } else if (index === 1) {
      this.pageShift1 = v
    } else if (index === 2) {
      this.pageShift2 = v
    } else if (index === 3) {
      this.pageShift3 = v
    }
  }

  /**
   * Tab 切换：**药丸、文字高亮、整页滑动由同一个 animateTo 驱动**，
   * 同帧开始、同时长同曲线（TAB_ANIM_MS / EaseInOut）、同时结束。
   *
   * ① 起始帧：新页先甩到一侧屏外（直接赋值即动画起点，
   *    官方 customContentTransition 示例同款写法）。旧页**不重置** ——
   *    若它正被上一次切换推送中（连点场景），让它从当前所在处
   *    继续滑离，避免位置跳变。
   * ② 结束帧（animateTo 闭包）：旧页滑出另一侧、新页归位。
   *    药丸 translate 与文字高亮都读 currentTab，同样在这段动画里补间。
   * ③ changeIndex 触发 Tabs 自定义内容转场：转场期间两页以 Stack
   *    布局叠放（树序即层序 —— 前进时新页在上、后退时旧页在上，
   *    均为自然滑动观感），位移全部由上面的 animateTo 驱动，
   *    转场代理只负责到点收尾（见 contentTransition）。
   *
   * 为什么原来不流畅：旧写法在同一个 animateTo 里改 currentTab，
   * 药丸滑动（200ms）与整页重渲染（Dashboard 等页全是卡片/渐变/模糊）
   * 挤在同一批帧里，主线程被页面构建占满，合成层动画跟着掉帧。
   * 现在页面位移只改 translate（纯合成层），页面本身不重建，
   * 动画期间主线程空闲；Scroll 位置等页内状态也原样保留。
   */
  private switchTab(index: number): void {
    if (this.currentTab === index) return
    const from: number = this.currentTab
    const dir: number = index > from ? 1 : -1
    // 兜底：onAreaChange 一定早于首次点击到达，真为 0 时用常见屏宽
    const w: number = this.contentW > 0 ? this.contentW : 360
    this.currentTab = index
    // 广播当前激活 Tab：记录页等据此「切回本页即重拉」，
    // 避免自定义转场下 onPageShow 不触发导致回到本页仍显示旧数据
    AppStorage.set<number>('activeTab', index)
    // ① 新页起始帧：甩到一侧屏外（旧页不重置，理由见上）
    this.setPageShift(index, dir * w)
    // ② 结束帧：旧页滑出另一侧、新页归位（与药丸/高亮同一段动画）
    this.getUIContext().animateTo({ duration: TAB_ANIM_MS, curve: Curve.EaseInOut }, (): void => {
      this.setPageShift(from, -dir * w)
      this.setPageShift(index, 0)
    })
    // ③ 换页：走控制器而不是 index 属性（改属性跳页不动画）
    this.tabsController.changeIndex(index)
  }

  /**
   * Tabs 自定义内容转场：**只负责「让两页叠放一段时间」**。
   *
   * 真正的位移由 switchTab 的 animateTo 统一驱动（与药丸同一段动画），
   * 这里绝不碰位移 —— 两段动画各滑各的反而会互相打断。
   * 代理不主动调 finishTransition：靠 timeout（动画时长 + 60ms 缓冲）
   * 到点自动结束，保证 Stack 叠放布局至少活到位移动画完全播完 ——
   * 旧页不会滑到一半被 Tabs 收回布局（那会看到内容「闪断」）。
   */
  private contentTransition(from: number, to: number): TabContentAnimatedTransition {
    return {
      timeout: TAB_ANIM_MS + 60,
      transition: (proxy: TabContentTransitionProxy): void => {
        // 位移见 switchTab；此处无需做事，等超时收尾即可
      }
    }
  }

  /** 「记录」入口：唤起行为录入半模态面板（长条第 5 格与圆珠共用） */
  private openAddSheet(): void {
    this.showAddSheet = true
    // showToast 可能抛异常（ArkTS 静态检查要求显式处理），这里吞掉即可，
    // 面板已弹出，提示失败不影响主流程
    try {
      toast('选择行为类型，填写数量即可记录')
    } catch (err) {
      // ignore
    }
  }

  @Builder
  PageMapWrapper(name: string) {
    PageMap(name)
  }

  @Builder
  AddSheetContent() {
    BehaviorAddSheet()
  }

  /**
   * 删除条（渲染在底部栏插槽内 —— **完全取代导航胶囊的位置**）。
   * ------------------------------------------------------------------
   * 材质与导航胶囊同一套光照模型（PILL 档单层 135° 渐变 + backdropBlur +
   * 四边异色描边 + 同档投影），仅染色换成危险红，语义一眼可辨。
   * 宽度撑满插槽（外层已固定 layoutWeight(1)×56），所以与胶囊严格等长、平行。
   */
  @Builder
  DeleteBarInSlot() {
    Row({ space: 6 }) {
      /*
       * 图标放大并用**深红**（Accent.DANGER）：它是主视觉，
       * 深色 + 大字号在浅玻璃上有足够对比，压得住。
       */
      CfIcon({ kind: 'ui', code: 'trash', iconSize: 17 })
      /*
       * 文字降一档 + 用**弱一级的红**：旧版图标与文字同色同权重，
       * 红色面积翻倍显得压迫。文字改为「深一档红」并降字号后，
       * 主次分明，整体也更像玻璃上的蚀刻字而不是色块。
       */
      Text(this.slotDeleteLabel)
        .fontSize(FontSize.SMALL)
        .fontWeight(FontWeight.Medium)
        .maxFontScale(FontSize.SCALE_TEXT)
        .fontColor(this.td() ? '#F2A49D' : '#C4554C')
    }
    .justifyContent(FlexAlign.Center)
    /*
     * ⚠️ 撑满外层定位容器（外层已用 position 精确覆盖胶囊槽位）。
     * 这里**绝不能自带 layoutWeight** —— 那是 Row 的职责，
     * 重复声明会破坏底栏权重分配（＋ 钮偏移的根因）。
     */
    .width('100%')
    .height('100%')
    /*
     * 材质：本轮重做（用户反馈「液态玻璃状态有点丑」）。
     *
     * 旧版三处把玻璃做成了「红塑料板」：
     *   ① 染色 0.22/0.26 —— 半透明玻璃叠这么厚的色，等于不透明色块，
     *      backdropBlur 被完全盖住，液态感归零；
     *   ② 描边 0.46/0.52 纯红 —— 一圈高饱和红框把胶囊箍死，
     *      与导航胶囊的冷白受光边一对比，显得又脏又廉价；
     *   ③ 文字与图标同色 —— 🗑 与「删除记录」都是同一个饱和红，
     *      红色面积翻倍，视觉过载。
     *
     * 现按「玻璃先成立、危险其次」的顺序重做：
     *   ① 染色降到 **0.10/0.13**（与导航胶囊同一量级），
     *      玻璃保持通透，danger 感改由文字与图标承担；
     *   ② 描边**不再用纯红**，改回玻璃本来的四边异色
     *      （受光边冷白 0.34 / 背光边深色 0.16）——
     *      只在最上/左侧留一道若隐若现的红调（0.22），
     *      观感是「玻璃上泛起一层暖意」，而不是「红框」；
     *   ③ 图标放大加粗、文字降一档字号，形成主次层级；
     *   ④ 投影沿用 PILL 档（跟随主光源落右下），不加额外红投影。
     */
    .linearGradient(this.tw(GlassLight.surface(this.deleteTint(), GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)))
    .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
    .borderRadius(Radius.PILL)
    .border({ width: 1, color: this.deleteBorder() })
    .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
    .clip(true)
    .onClick((): void => {
      /*
       * 转发点击给二级页执行删除确认（删除条 UI 在 Index，逻辑在二级页）。
       * ⚠️ AppStorage.get 返回 `T | undefined`，不能直接 `+ 1`
       *    （编译报 Object is possibly 'undefined'），先兜底为 0。
       */
      const tick: number | undefined = AppStorage.get<number>('barSlotDeleteTick')
      AppStorage.set<number>('barSlotDeleteTick', (tick === undefined ? 0 : tick) + 1)
    })
  }

  /**
   * 删除条玻璃染色：**极轻**（用户反馈「液态玻璃状态有点丑」）。
   * ------------------------------------------------------------------
   * 原 0.22 / 0.26 太重 —— 玻璃叠这么厚的色就变成不透明色块，
   * backdropBlur 被完全盖住、液态感消失，观感是「红塑料板」。
   * 现降到 0.10 / 0.13，与导航胶囊同一量级：
   * 玻璃保持通透，danger 语义交给文字与图标（见 DeleteBarInSlot）。
   * 深色用珊瑚调而非粉色 —— 粉色染色压在深底上会发灰、显脏。
   */
  private deleteTint(): string {
    return this.td() ? 'rgba(236,131,124,0.13)' : 'rgba(224,115,107,0.10)'
  }

  /**
   * 删除条描边：**玻璃四边异色 + 一道极轻红调**（不再是纯红框）。
   * ------------------------------------------------------------------
   * 原 0.46/0.52 纯红 → 一圈高饱和红把胶囊箍死，与导航胶囊的冷白受光边
   * 一比显得又脏又廉价。现改为：
   *   受光边：上边冷白叠暖红调（0.22，"玻璃上缘泛起暖意"），
   *          左边纯冷白（0.34，与导航胶囊同一受光语义）；
   *   背光边：深色收边（0.14/0.16），与浅色胶囊同口径建立厚度方向差。
   */
  private deleteBorder(): EdgeColors {
    const warm: string = this.td() ? 'rgba(236,131,124,0.26)' : 'rgba(224,115,107,0.22)'
    const lit: string = 'rgba(236,244,246,0.34)'
    const shade: string = this.td() ? 'rgba(10,16,14,0.22)' : 'rgba(10,16,14,0.14)'
    return { top: warm, left: lit, right: shade, bottom: shade }
  }

  /* ---------- 滑动的选中药丸（独立图层，不叠加模糊以保性能） ---------- */
  @Builder
  SlidingPill() {
    // 药丸自身是玻璃底色，统一光照层垫在下面（左上 45° 主光源）。
    // ⚠️ 不加投影：投影每帧重绘，实测滑动时卡顿明显（见文件头性能要点 2）。
    Stack() {
      /*
       * ⚠️ 这里**不再**叠 GlassLightLayers。
       * 药丸自身已走 `GlassLight.surface()` —— 底色 + 左上白光 + 右下内阴影
       * 压进同一条 135° 渐变（与全库 CfCard / 导航胶囊同一口径）。
       * 之前是「平涂药丸 + 底下垫一层光照层」，两层打架：
       * 平涂不透明 → 光照层被完全盖住 → 只剩平涂观感（详见下方注释）。
       * 单层合成后这里必须留空，否则高光与内阴影会叠成两倍、发脏。
       *
       * ⚠️ 不加投影：投影每帧重绘，实测滑动时卡顿明显（见文件头性能要点 2）。
       */
      Row()
        .width('100%')
        .height(46)
        // ⚠️ 取证结论（记录页深色模拟器截图，449×194 逐像素扫描）：
        //   页面底色 (241,250,247)，而胶囊/药丸区域实测
        //   左上 (250,255,254) → 右下 (211,220,217)。
        //   药丸此前是 `.backgroundColor(Glass.PILL_BG)` **平涂**，
        //   全库唯一没接光照模型的玻璃面 —— 底下那层 GlassLightLayers
        //   的 135° 对角光染被一块不透明平涂整个盖住，
        //   于是药丸只剩「左上很白、右下很脏」的平涂观感，
        //   视觉上就是用户说的「底部白条，不通透」。
        //
        //   现与导航胶囊、CfCard 全库口径一致：底面走 135° 合成渐变，
        //   底色 + 左上白光 + 右下内阴影同在一条对角轴上。
        .linearGradient(this.tw(GlassLight.surface(Glass.PILL_BG, GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)))
        .borderRadius(Radius.PILL)
        .border({ width: 1, color: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)) })
    }
    .width(this.cellW())
    .height(46)
    // 光照层裁成胶囊形：圆角与内层 Row 一致，否则四角漏直角光斑
    .borderRadius(Radius.PILL)
    .clip(true)
    .translate({ x: this.pillX() })
    .hitTestBehavior(HitTestMode.None)
  }

  /* ---------- Tab 单元格：图标 + 文字 ---------- */
  /**
   * 底部导航选中态文字色。
   *
   * ⚠️ 取证与用户反馈：原来选中态用 `EcoTheme.primaryDeep`（浅色下
   * 就是 accent `#2A9E82` 深绿）。但选中药丸本身是**白色玻璃**
   * （PILL_BG 浅色为近白半透明 + 全套光照层高光集中在左上），
   * 深绿字压在上面在小字号下对比度不足 —— 截图里「科普」两个字
   * 明显发飘、看不清。
   *
   * 口径：药丸是**近白玻璃**，四个 Tab 文字**一律黑色**（用户明确要求），
   * 主次靠字重（Bold/Normal）区分而非颜色深浅 ——
   * 近黑压近白对比度 ≈ 10.7:1，是全应用对比度最高处。
   *
   * ⚠️ 必须走方法现取，不能写成成员字段初值 ——
   * `ThemePalette.dark` 是 static 字段，主题切换不会回灌到已存在实例。
   * （深色模式下药丸依然是**近白玻璃**，不随主题变深 ——
   *  与 Navigation 胶囊的 BOTTOM_BAR_BG 口径一致，所以黑字两种模式都成立。）
   */
  private tabActiveColor(): string {
    /*
     * themeTick 恒读钩子：ThemePalette.dark 是 static 字段不响应，
     * 恒假分支仅为建立依赖 —— 换血后本属性重新求值、重取当前明暗。
     */
    if (this.themeTick < 0) {
      return '#1A1F1C'
    }
    // 深色底栏是暗玻璃（BOTTOM_BAR_BG 深色 = 白色 5% 透明），黑字直接隐形；
    // 仅深色模式改白色，浅色维持「全部黑色」口径，靠字重区分主次
    return this.td() ? '#FFFFFF' : '#1A1F1C'
  }

  @Builder
  TabCell(code: string, label: string, index: number, size: number = 22) {
    Column({ space: 2 }) {
      CfIcon({
        kind: 'ui',
        code: code,
        iconSize: size,
        color: this.tabActiveColor()
      })
        // 苹果 segmented control 的图标手感：选中项图标放大，与药丸滑动
        // 同帧触发、同时长同曲线（TAB_ANIM_MS / EaseInOut），同频不脱节。
        // scale 是纯绘制属性，不影响 46vp 行高的布局稳定。
        //
        // ⚠️ 曲线必须用**固定时长**的 EaseInOut，禁用物理弹簧（springHeavy）：
        //    EaseInOut 是确定性三次贝塞尔：同 duration 同曲线，中断后从
        //    当前值续补到目标值，不会留半截缩放（springHeavy 被转场打断会
        //    冻结在中间值 —— 即用户反馈的「底部 Tab 随机变大变小」）。
        //
        // 尺寸说明：emoji 时代「我的」用 18 号配平（👤 实心剪影比 🏠📋📚
        // 轮廓字形大）；换成 Tabler 线稿后四个图标视觉重量天然一致，
        // 统一 22 即可，不再需要逐 Tab 微调。
        .scale({
          x: this.currentTab === index ? 1.16 : 1,
          y: this.currentTab === index ? 1.16 : 1
        })
        .animation({ duration: TAB_ANIM_MS, curve: Curve.EaseInOut })
      Text(label)
        .fontSize(FontSize.CAPTION)
        .maxFontScale(FontSize.SCALE_NUM)
        // 高亮跟着 currentTab：点击瞬间新 tab 就开始点亮，与药丸滑动
        // 同一段 animateTo 补间，同频同步；换色时长与药丸一致（TAB_ANIM_MS）
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        /*
         * ⚠️ 四个 Tab 文字**一律用黑色**（用户反馈「这几个字全部替换成黑色，
         *   要不然看不清」）。
         *
         * 取证（截图逐列扫暗像素簇，按对比度排序）：
         *   "看板"（选中）#373B3A / 底 #EFFBFB = **10.74:1**  清晰
         *   "记录"       #C7935D / 底 #FFF3F3 = **1.48:1**  糊掉
         *   "我的"       #A0AFAC / 底 #FFF3F3 = **2.10:1**  糊掉
         *   另一块        #E0F3F7 / 底 #FEF3F1 = **1.05:1**  几乎隐形
         *
         * 根因：未选中 Tab 原用 `Neutral.TEXT_MUTED`
         *   （浅色 #A3AEA9 浅灰 / 深色 #9AA8A3），压在**近白玻璃胶囊**上
         *   对比度天然不足 —— 浅灰压近白，怎么调都上不了 3:1。
         *   选中态本就用了近黑（tabActiveColor），只有未选中态是"弱文字"配色，
         *   于是同一行里"选中的清楚、没选中的看不清"。
         *
         * 现按用户要求：**选中与未选中统一黑色**，靠字重（Bold/Normal）
         * 区分主次，而不是靠颜色深浅 —— 这也是 iOS/Material segmented
         * control 的通行做法。
         *
         * ⚠️ 深色模式修正（用户圈选反馈「底栏字看不清」）：深色下胶囊是
         * 暗玻璃（BOTTOM_BAR_BG 深色 = 白色 5% 透明），黑字直接隐形 ——
         * 仅深色模式改白色（见 tabActiveColor 内 ThemePalette.dark 分流），
         * 浅色仍全黑。上面的黑色对比度取证仅在浅色胶囊上成立。
         */
        .fontColor(this.tabActiveColor())
        // 与药丸滑动同时长（TAB_ANIM_MS），换色不脱节
        .animation({ duration: TAB_ANIM_MS, curve: Curve.EaseInOut })
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(46)
    .justifyContent(FlexAlign.Center)
    .onClick((): void => this.switchTab(index))
  }

  /**
   * 右侧独立圆形「＋」按钮 —— 行为录入入口。
   * 形态独立于胶囊：主 Tab 页与子页面都显示同一个圆钮，
   * 子页面时它是底部唯一可见的控件。
   *
   * ⚠️ 本轮从「白色玻璃球」改为**品牌档位色玻璃球**（用户反馈：
   * 「加号按钮有点灰，不够突出，液态玻璃的 FAB 应该是通透且带发光的」）：
   *   · 球面渐变走 GlassLight.orbAccentSurface(ecoLevel) ——
   *     保留球体五档光学结构，底色换成 primaryLight→primary 的
   *     半透明品牌绿（α 0.78~0.95，中心仍透出模糊背景）；
   *   · 图标改白色（绿色玻璃上白「＋」对比最清晰）；
   *   · 投影改**绿色辉光**（shadowTintOf：同色 30% α、radius 20、
   *     offsetY 8）—— FAB 靠「发光」浮起来，而不是靠黑影压边。
   */
  @Builder
  OrbButton() {
    Stack() {
      /*
       * ⚠️ 不叠 GlassLightLayers —— 圆钮自身已走 135° 合成渐变（见下）。
       * 与导航胶囊、滑动药丸同一口径：悬浮控件单层合成，
       * 平涂底色会把光照层盖住，两层打架只剩「不透」的平涂观感。
       */
      Column() {
        Text('＋')
          .fontSize(26)
          .maxFontScale(FontSize.SCALE_NUM)
          // 品牌绿玻璃底上白图标对比最清晰；加轻微投影防高光斑吃掉笔画
          .fontColor('#FFFFFF')
          .shadow({ radius: 6, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 1 })
          .fontWeight(FontWeight.Medium)
          .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(56)
    .height(56)
    // 资料页（hideFab 标记）等表单型子页面不显示悬浮球：
    // 圆钮会压住页面底部输入框。None 同时移除布局与命中，整颗退场。
    // ⚠️ 由 fabGone（退场动画播完）驱动，**不再**由 hideFab 直接驱动 ——
    //    秒切会让圆钮退场像「闪没」、返场像「闪现」（2026-10-20 用户
    //    反馈「＋号会直接出来没有动画」，补间见 onHideFab）。
    .visibility(this.fabGone ? Visibility.None : Visibility.Visible)
    /*
     * 品牌档位色球面渐变（orbAccentSurface）：
     * 0.00 中心透光 / 0.22 高光起始 / 0.38 高光峰值 / 0.72 边缘弯折 / 1.00 背光边缘。
     * 颜色全程由 over() 预合成，不会在停靠点之间插出灰色带。
     */
    .linearGradient(GlassLight.orbAccentSurface(this.ecoLevel))
    // 液态玻璃：圆钮与左侧胶囊是两块不相交的区域，各自一层模糊互不干扰
    .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
    .borderRadius(28)
    /*
     * 四边异色描边 = 凸透镜的边缘菲涅尔：正对视线时玻璃不反光，
     * 掠射角（也就是圆钮的四条边）反射率飙升 → 边缘比中心亮得多。
     * ⚠️ 四边**等宽 1vp**：非整数宽度（top: 1.5）配合 borderRadius 会在
     *    描边内侧留下一条未填充暗缝，横贯顶边（Components.ets 有逐像素
     *    取证记录）。凸透镜的厚度感靠 alpha 亮度差表达，不靠加宽。
     */
    .border({
      width: { top: 1, left: 1, right: 1, bottom: 1 },
      color: {
        top: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).top,
        left: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).left,
        right: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).right,
        bottom: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).bottom
      }
    })
    /*
     * 绿色辉光投影：FAB 是全屏唯一的光源色元素，
     * 影子跟主色走（同色 30% α）——「通透且带发光」的落点就在这。
     * 比平面胶囊的 PILL 投影更实（radius 20 / offsetY 8），
     * 球体悬空感才能立起来。
     */
    .shadow({
      radius: 20,
      color: this.tw(GlassLight.shadowTintOf(EcoTheme.primary(this.ecoLevel))),
      offsetX: 0,
      offsetY: 8
    })
    .clip(true)
    /*
     * 缩放二合一：按下反馈（0.9）× 显隐补间（fabScale，见 onHideFab）。
     * ⚠️ 两个 .scale 属性后者会整体覆盖前者，必须**相乘合成**到同一组，
     *    不能写成两个独立 .scale 链式调用。
     */
    .scale({
      x: this.fabScale * (this.orbPressed ? 0.9 : 1),
      y: this.fabScale * (this.orbPressed ? 0.9 : 1)
    })
    // 显隐补间的透明度（按下反馈不含透明度，避免与按压手势打架）
    .opacity(this.fabAlpha)
    .onClick((): void => this.openAddSheet())
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.orbPressed = true
      } else if (e.type === TouchType.Up) {
        this.orbPressed = false
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      /*
       * 登录闸门（多账号系统的总开关）
       * ------------------------------------------------------------------
       * 三分支条件渲染，任何时刻只有一支挂载：
       *   ① !sessionReady —— 启动同步中，垫一层与主题一致的实色底防白闪；
       *   ② sessionUser 为空 —— 未登录，整屏只渲染登录/注册页（LoginGate），
       *      主框架完全不挂载，业务页面读不到任何数据；
       *   ③ 已登录 —— 挂载下述全部内容（⓪光晕层 ①Navigation+Tabs ②底栏
       *      ③删除条 启动页/引导）。
       * 登录成功/注销时分支整体挂载/卸载：各页 aboutToAppear 重跑，
       * 自然读到新账号的 LocalStore 命名空间 —— 数据隔离由此成立。
       */
      if (!this.sessionReady) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.tc(EcoTheme.bgSolid(this.ecoLevel)))
          .opacity(this.themeTick >= 0 ? 1 : 0)
      } else if (this.sessionUser.length === 0) {
        LoginGate()
      } else {
      /*
       * ⓪ 环境光晕层（radialGradient 径向渐变，铺满根 Stack）
       * ------------------------------------------------------------------
       * 用户思路（对齐 iOS 液态玻璃）：根底若是纯平色，backdropBlur 采样到
       * 的永远是一块均匀色板 —— 玻璃再透也没有「环境纵深」可透。
       * 在最底层垫一道**极暗**的档位色径向光晕（顶部微亮 → 四周衰减），
       * 上层的半透明页底、玻璃条、卡片才有东西可以采样。
       *
       * 要点：
       * · 颜色走 EcoTheme.glow(ecoLevel)（α 仅 0.10~0.12，光晕不是光源）；
       * · hitTestBehavior(None)：纯视觉层，绝不参与命中，不挡任何触摸；
       * · 一级页根底已改为半透明 bg()（62%），这层光晕才能透上去。
       */
      Column()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .radialGradient({
          center: ['50%', '0%'],
          radius: 560,
          colors: [[this.tc(EcoTheme.glow(this.ecoLevel)), 0], ['rgba(0,0,0,0)', 1]]
        })
        .opacity(this.themeTick >= 0 ? 1 : 0)
        .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })

      /*
       * ① 内容层：Navigation + Tabs承载四个业务 Tab
       *
       * ⚠️ 布局要点（曾导致内容不渲染）：
       * Navigation 内的 Column **只能给 layoutWeight(1)，不能同时给 height('100%')**。
       * 两者并存时ArkUI 无法确定主轴尺寸，Tabs 拿到的高度会塌缩，
       * 表现为「页面只剩顶部一行文字，其余整片空白」。
       *
       * 底部余量**不要用 Blank 占位、也不要用 padding**（都干扰 Tabs 权重），
       * 直接让 Tabs 铺满全屏，滚到底的空间由各页 Scroll 的 bottom: 96 给 ——
       * 内容从底部玻璃条下穿过，玻璃才有真实内容可模糊。
       */
      Navigation(this.pathStack) {
        Column() {
          Tabs({ controller: this.tabsController }) {
            /*
             * 四个一级页各包一层全尺寸 Column 并挂 translate：
             * Tab 切换时旧页/新页的整页平移由 switchTab 驱动，
             * 页面本身不重建（Scroll 位置等页内状态原样保留）。
             */
            TabContent() {
              Column() {
                DashboardPage()
              }
              .width('100%').opacity(this.themeTick >= 0 ? 1 : 0)
              .height('100%')
              .translate({ x: this.pageShift0 })
            }

            TabContent() {
              Column() {
                RecordListPage()
              }
              // themeTick 恒读钩子：四页统一口径，保证换肤时四页同步重建
              .width('100%')
              .opacity(this.themeTick >= 0 ? 1 : 0)
              .height('100%')
              .translate({ x: this.pageShift1 })
            }

            TabContent() {
              Column() {
                ArticleListPage()
              }
              .width('100%')
              .opacity(this.themeTick >= 0 ? 1 : 0)
              .height('100%')
              .translate({ x: this.pageShift2 })
            }

            TabContent() {
              Column() {
                MinePage()
              }
              .width('100%')
              .opacity(this.themeTick >= 0 ? 1 : 0)
              .height('100%')
              .translate({ x: this.pageShift3 })
            }
          }
          .barHeight(0)
          .scrollable(false)
          .animationDuration(0)
          /*
           * Tabs 自身显式透明 —— 全链路「底色只由 Index 根层实色提供」：
           * Tab 内容层与根层之间隔着 Navigation + Tabs，任何一层带默认白底，
           * 页面半透明底就会落在白底上（62% 薄荷叠白 ≈ #F7FDFA，肉眼近白），
           * 胶囊 backdropBlur 采样到白 → 玻璃发白、液态感全无。
           */
          .backgroundColor(Color.Transparent)
          /*
           * 自定义内容转场：转场期间参与动画的两页以 Stack 布局叠放，
           * 整页位移由 switchTab 的 animateTo 驱动（与药丸同步），
           * 到点自动收尾。⚠️ 换页必须走 tabsController.changeIndex()，
           * 改 index 属性跳页不触发自定义转场（动效不生效）。
           */
          .customContentTransition((from: number, to: number): TabContentAnimatedTransition => {
            return this.contentTransition(from, to)
          })
          .layoutWeight(1)
          /*
           * 注册引导误触闸门（见 profileGate 注释）：资料页盖住屏幕前
           * 禁用 Tabs 整棵子树 —— Tab 点击、页面内卡片/按钮全部不可点。
           * 禁用态向子节点传递，不影响渲染与 Tabs 控制器本身。
           * ⚠️ profileGate 是普通字段（真值零帧延迟），改它靠
           * profileGateTick（@State）触发本组件重渲染 —— 此处恒读
           * tick 建立依赖，保证属性更新一定落地。
           */
          .opacity(this.profileGateTick >= 0 ? 1 : 0)
          .enabled(!this.profileGate)
        }
        .width('100%')
        .height('100%')
        // 实测内容区宽度：Tab 切换时整页滑动一屏的距离
        .onAreaChange((old: Area, area: Area): void => {
          this.onContentArea(area.width as number | string)
        })
        /*
         * 沉浸式底部：**不再留 76px 占位 Blank，也不铺底色**。
         *
         * 旧结构（Blank 76px + Column 半透明底）让胶囊坐在一块纯色面板上，
         * backdropBlur 采样到的永远是平色 —— 液态玻璃没有内容可模糊，
         * 看起来就是一块半透明白药片，效果完全体现不出来。
         *
         * 现在四个一级页的 Scroll 直接铺到屏幕底，卡片从玻璃条下面穿过，
         * 胶囊/圆钮模糊到的是真实内容，玻璃感才出得来。
         * 滚到底的余量改由各页 Scroll 的 bottom: 96 承担
         * （76 条约 + 20vp 呼吸），最后一张卡仍能滚出玻璃条。
         * 页面底色由根层 Stack 的 EcoTheme.bgSolid 统一提供。
         */
      }
      .navDestination(this.PageMapWrapper)
      .hideTitleBar(true)
      .onAppear((): void => {
        // 注册流程引导：注册成功自动登录后，主框架首次挂载时强制弹出
        // 资料页完善昵称与性别（LoginGate 注册提交时打的标记，一次性消费）。
        // 普通登录不含该标记，此处静默跳过。
        if (AppStorage.get<boolean>('pendingProfileSetup') === true) {
          AppStorage.setOrCreate('pendingProfileSetup', false)
          AppStorage.setOrCreate('profileMandatory', true)
          /*
           * 误触闸门：闸门已在 onSessionUser（重建前）预置成锁死态，
           * 主框架第一帧就不可点；这里再置一次是兜底 —— 万一标记到达
           * 时序异常（onSessionUser 没赶上），至少 push 之前也是关的。
           * 解除由资料页上屏信号 profileSetupShown 驱动（见 onProfileSetupShown）。
           */
          this.setProfileGate(true)
          this.pathStack.pushPathByName(RouteName.PROFILE, null)
        }
      })
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
      /*
       * 显式声明透明：一级页根底改为半透明 bg() 后，
       * Navigation → Tabs → TabContent 全链路任何一层都不许带默认底色，
       * 页面 62% 半透明底 + 光晕必须一路透到根层实色上（不再落白）。
       */
      .backgroundColor(Color.Transparent)
      /*
       * 启动页退场时，主体内容（Navigation）同步淡入 + 轻微推近，
       * 与启动页的消失形成交叉过渡，避免"启动页突然没了、内容突然出现"。
       * 启动页显示期间这里 opacity=0，被 SplashPage 全屏覆盖，看不到。
       */
      .opacity(this.splashContentOpacity)
      .scale({ x: this.splashContentScale, y: this.splashContentScale })
      .animation({ duration: 420, curve: Curve.EaseInOut })

      /*
       * ② 液态玻璃底部导航（参考鸿蒙 7 / 大疆 DJI MIMO 的胶囊+圆钮布局）
       * ------------------------------------------------------------
       * 布局：左侧「4 格胶囊」+ 右侧「独立圆形 + 按钮」，二者并列、间距 10。
       * 形态：主 Tab 页两者都在；子页面时左侧胶囊整体隐藏（含药丸/图标/文字/
       *      玻璃），只留右侧那颗圆按钮，点它照样弹出行为录入面板。
       *
       * 玻璃要点：backdropBlur 每层都会创建离屏渲染，**同一区域只保留一层**。
       * 胶囊和圆钮是两块不相交的区域，各自一层模糊互不干扰，性能可控。
       *
       * ⚠️ 容器绝不能做全屏：全屏 + 命中测试会吞掉 Navigation 的所有触摸。
       * 这里宽度 100%、高度随内容自适应，且用 Transparent 让下层可穿透。
       */
      Row({ space: 10 }) {
        /*
         * ⚠️ 这里**不允许有任何接位元素**（Blank 等）：
         *   胶囊退场后走 Visibility.Hidden —— 占位原封保留（见下方 visibility 注释），
         *   槽位永远由胶囊自己占着。若再放 Blank().layoutWeight(1)，
         *   两个 weight(1) 瓜分剩余宽度，胶囊被挤成半宽（历史实测教训）。
         *
         * 删除条不塞进 Row（那会打乱权重分配），
         * 而是作为 Row 的**兄弟覆盖层**用 position 绝对定位覆盖胶囊槽位 ——
         * 既保持胶囊完整，又实现「删除条占导航条位置」。
         */

        /* 左侧胶囊：4 格 Tab（子页面整体隐藏） */
        Stack({ alignContent: Alignment.Start }) {
          /*
           * 光照层用 **PILL 档**，不是 PANEL 档。
           *
           * ⚠️ 取证结论（截图底部像素扫描）：
           *   页面底色 (241,250,247)，而导航胶囊实测 (215,219,218)
           *   —— 胶囊比它所在的页面**更暗、更灰**，正是用户看到的
           *   「底部有底色、不透明不透透」。
           *
           * 根因：这里原本挂 PANEL 档，而 PANEL 的全套光照层里含
           * 「文字暗纱 textScrim」（顶 0.16 → 底 0.30 的定向暗渐变，
           * 是为大面板的文字对比度设计的）。56vp 高的导航胶囊上
           * 压这么一层暗纱，小面积高浓度直接把它糊成脏灰。
           *
           * 口径：**面板级光照层（PANEL）只给内容面板用**；
           * 导航胶囊这类悬浮控件走 PILL 档 —— 无文字暗纱、
           * 接触纱不压、菲涅尔更轻，才是通透的悬浮玻璃观感。
           * 截图里更下方 y=795~827 的区域本来就是纯主题底色，
           * 没有白条；用户看到的「底色」就是这个被压灰的胶囊。
           */
          /*
           * ⚠️ 这里**不再**叠 GlassLightLayers —— 胶囊自身已走
           * `GlassLight.surface()`（见下方 `.linearGradient(...)`）。
           *
           * 取证（记录页深色模拟器截图 449×194 逐像素）：
           *   页面底色 (241,250,247)，胶囊区域实测左上 (250,255,254)
           *   → 右下 (211,220,217)。此前是「平涂胶囊 + 底下垫光照层」，
           *   平涂不透明把光照层整个盖住，两层打架后只剩平涂观感 ——
           *   这就是用户反复说的「底部白条，不通透」。
           *   单层合成后必须留空，否则高光与内阴影叠成两倍、发脏。
           */

          // 滑动药丸：选中态白色高亮块，随currentTab 平移
          this.SlidingPill()

          Row() {
            this.TabCell('home', '看板', 0)
            this.TabCell('record', '记录', 1)
            this.TabCell('article', '科普', 2)
            this.TabCell('mine', '我的', 3)
          }
          .width('100%')
          .height(46)
          .onAreaChange((old: Area, area: Area): void => {
            this.onBarArea(area.width as number | string)
          })
        }
        /*
         * ⚠️ 这里实测的是**胶囊自身**宽度（退场位移的基准）；
         *   内层 4 格文字 Row 的 barW 只用于药丸分格，两者不可混用。
         *
         * ⚠️ `capsuleW` 的关键用途：**删除条按它定宽**（用户诉求
         *   「让删除记录的宽度和底部导航胶囊宽度一样，长度也一样」）。
         *   删除条是 Row 的兄弟覆盖层、不能用百分比占满 Row，
         *   只能取一个具体宽度 —— 用胶囊实测值，两者永远等宽，
         *   且换机型/字号缩放时自动同步，无需改任何常量。
         */
        .onAreaChange((old: Area, area: Area): void => {
          this.onCapsuleArea(area.width as number | string)
        })
        // 全局光照口径：底面走 135° 合成渐变（底色 + 左上白光 + 右下内阴影），
        // 与全库 CfCard / 顶栏 / 药丸同一条对角轴。
        // 这行原本是 `.backgroundColor(Glass.BOTTOM_BAR_BG)` 平涂，
        // 是不透明底色 → 底部那条「白条」的真正来源。
        .linearGradient(this.tw(GlassLight.surface(Glass.BOTTOM_BAR_BG, GlassTier.PILL,
          EcoTheme.bg(this.ecoLevel), 1)))
        .backdropBlur(GlassLight.blurScaled(Glass.LIVE_BLUR))
        .borderRadius(Radius.PILL)
        /*
         * 四边异色描边**一次写完**，四边**等宽 1vp**。
         * ⚠️ 两个坑：① 拆成两次 `.border()` 后者会整体覆盖前者，
         *    把四边异色冲掉；② 顶部不能加宽到 1.5vp —— 非整数描边宽度
         *    配合 borderRadius 会在描边内侧留下一条未填充暗缝，横贯顶边，
         *    实测比上下暗 12~15，视觉上就是一条黑线（Components.ets 有
         *    逐像素取证记录）。厚度感靠 alpha 亮度差表达。
         */
        .border({
          width: { top: 1, left: 1, right: 1, bottom: 1 },
          color: {
            /*
             * ⚠️ 深色顶边改为走 GlassLight.borderColors（PILL 档）。
             *
             * 取证（深色记录页截图）：胶囊 1px 上边 L=104，而胶囊内部只有
             * L=48 —— 一根 2.2 倍亮的白线包在玻璃上，截图里就是底部
             * 那道刺眼的亮横条。原本这里硬编码 'rgba(236,244,246,0.26)'
             * （圆钮更硬编码到 0.42），绕过了光照模型、也没跟着本轮
             * 收敛走。现统一交给 borderColors：与全库玻璃同一套参数、
             * 同一档位策略，改一处即全应用生效。
             */
            top: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).top,
            left: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).left,
            right: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).right,
            bottom: this.tw(GlassLight.borderColors(GlassTier.PILL, EcoTheme.bg(this.ecoLevel), 1)).bottom
          }
        })
        // 投影跟随主光源方向（右下），替换原 raised 的正下投影。
        // 同样走 PILL 档：PANEL 的 18px / 0.12 投影落在 56vp 胶囊上
        // 会糊掉一圈脏边，悬浮控件用小投影才干净。
        .shadow(this.tw(GlassLight.shadowOf(GlassTier.PILL)))
        .clip(true)
        // 退场动画三件套：滑向＋钮 + 缩小 + 淡出（animateCapsule 驱动）。
        // translate/scale/opacity 都不影响布局；胶囊始终占满外层槽位，
        // 「＋」钮位置由 Row 右端锚定，任何时刻都不偏移。
        .translate({ x: this.capsuleShift })
        .scale({ x: this.capsuleScale, y: this.capsuleScale })
        .opacity(this.capsuleAlpha)
        // 子页面：等退场动画播完（capsuleGone）再**隐藏但保留占位**。
        // ⚠️ 必须 Hidden 不能 None：
        //   None 会把胶囊**摘出布局** —— 它虽然不占宽，却仍参与 Row 的
        //   space:10 间隙计数，子页面状态下 [Blank, (胶囊), 圆钮] 多出
        //   一个 10vp 间隙 → 加号左移 10vp；退出时反向右移。这就是
        //   「＋ 钮在动画结束后向左/向右挪一下」的根因。
        //   Hidden = 不可见、不可点，但布局占位原封不动，圆钮永不动。
        .visibility(this.capsuleGone ? Visibility.Hidden : Visibility.Visible)
        /*
         * 胶囊恒占 layoutWeight(1)。
         * ⚠️ 布局恒定原则：胶囊任何状态下都独占这个权重（退场后 Hidden 占位），
         *   Row 内不允许出现第二个 weight 元素 —— 否则瓜分宽度、胶囊被挤半宽
         *   （历史实测教训），加号也会随权重再分配而横移。
         */
        .layoutWeight(1)
        .height(56)

        /* 右侧独立圆形「＋」按钮：两种形态都保留 */
        this.OrbButton()
      }
      .width('100%')
      /*
       * ⚠️ 底部呼吸 Space.LG(16) → Space.XS(4)：用户定位的问题是
       * 「胶囊下方到屏幕底边那一段是白的」。
       * 这段空白 = 本 padding + 底部安全区，而它后面是页面底色，
       * 玻璃采样不到任何内容 → 视觉上是一条孤零零的浅色带。
       * 收到 4vp 后胶囊几乎贴住屏幕底，空白带窄到只剩安全区那一圈，
       * 页面内容/底色与胶囊在视觉上连成一片。
       * 胶囊自身的垂直位置由 Stack alignContent.Bottom 决定，
       * 改小 padding 只是让它更贴近下沿，不会与内容重叠。
       */
      .padding({ left: Space.PAGE, right: Space.PAGE, bottom: Space.XS })
      // Transparent = 自身与子节点响应命中，但下层兄弟节点同样响应，
      // 因此不会挡住页面内容的触摸
      .hitTestBehavior(HitTestMode.Transparent)
      // 注册引导误触闸门：资料页空窗期连同底栏一起禁用
      // （＋钮本就由 ProfilePage 的 hideFab 提前收起，这里兜住胶囊四格）
      // ⚠️ profileGate 是普通字段（真值零帧延迟），靠 profileGateTick
      // （@State）触发重渲染 —— 此处恒读 tick 建立依赖，保证 .enabled
      // 的更新一定落地（ArkUI 局部更新只刷新依赖了响应式变量的节点）。
      .opacity(this.profileGateTick >= 0 ? 1 : 0)
      .enabled(!this.profileGate)

      /*
       * ③ 删除条：导航条位置的「替代物」（用户诉求「导航条消失后，
       *   让同尺寸的删除按键代替导航条的位置」）。
       *
       * ⚠️ 为什么是 Row 的**兄弟覆盖层**而不是塞进 Row 里：
       *   Row 内元素的权重分配一旦随状态变化，圆钮就会被推着偏移
       *   （「＋ 钮进入二级页会往左一点」的真正原因）。
       *   所以**不碰 Row 的内部结构** —— 删除条与整个底栏 Row 平级，
       *   用绝对定位精确覆盖「胶囊槽位」那块区域：
       *     · 水平：**直接用胶囊的实测宽度 `capsuleW`**，左缘同样对齐
       *       Space.PAGE（两者左边界都锚在同一个 Padding 上）——
       *       不写死任何数字，胶囊多宽删除条就多宽，**永远等宽等长**；
       *       未就绪时退回估算值（屏宽 - PAGE*2 - 66），首帧也不会错位；
       *     · 垂直：与胶囊同为 56vp 高、贴底（bottom 与 Row 的 padding 一致）
       *   于是删除条与胶囊**几何完全重合**，真正是"同一位置的接班人"。
       *
       * 仅在「胶囊已完全退场 + 二级页要求删除条」时显示，二者互斥不重叠。
       *
       * ⚠️ 入场动画（用户反馈「弹出太快了，改成和导航栏一样的」）：
       *   搬成覆盖层后**丢失了入场动画** —— 删除条是条件渲染的，
       *   出现即最终态，观感是「啪一下蹦出来」。
       *   现补上与导航胶囊**同一组参数**：
       *     · 时长 = CAPSULE_ANIM_MS(360)，与胶囊退场/返场同步；
       *     · 位移从右侧（贴着胶囊原来的退场方向，等于「被＋钮吐出来」）；
       *     · 缩放 CAPSULE_EXIT_SCALE → 1，与胶囊的缩小态互为逆过程；
       *     · 曲线 EaseOut —— 与胶囊返场同款，两者是镜像动作。
       *   用 `slotDeleteIn` 而非原来的 `barEntered`（那状态在详情页，
       *   删除条搬到 Index 后已与它无关，是"动画失效"的真凶）。
       */
      if (this.capsuleGone && this.barSlotDelete) {
        Row() {
          this.DeleteBarInSlot()
        }
        .position({ left: Space.PAGE, bottom: Space.XS })
        // ⚠️ 宽度 = 胶囊实测宽（用户诉求「宽度和底部导航胶囊一样，长度也一样」）
        .width(this.capsuleW > 0 ? this.capsuleW : 300)
        .height(56)
        // 从右侧 ＋ 钮方向滑入 + 由小放大 + 淡入（与胶囊返场互为逆过程）
        .translate({ x: this.slotDeleteIn ? 0 : 56 })
        .scale({ x: this.slotDeleteIn ? 1 : CAPSULE_EXIT_SCALE, y: this.slotDeleteIn ? 1 : CAPSULE_EXIT_SCALE })
        .opacity(this.slotDeleteIn ? 1 : 0)
        .animation({ duration: CAPSULE_ANIM_MS, curve: Curve.EaseOut })
        .onAppear((): void => {
          // ⚠️ 必须延后一帧：同帧内改变量不会触发补间（ArkUI 限制）
          setTimeout((): void => {
            this.slotDeleteIn = true
          }, 16)
        })
      }

      /* 启动页 / 首启引导：条件渲染覆盖，不占路由 */
      if (this.showSplash) {
        SplashPage({
          onSkip: (): void => {
            // 点击跳过同样走淡出，与定时器路径保持一致的观感
            this.fadeOutSplash()
          }
        })
      }
      if (this.showOnboarding) {
        OnboardingPage({
          onFinish: (): void => {
            this.showOnboarding = false
          }
        })
      }
      /* —— 登录闸门「已登录」分支到此结束：以上全部子节点仅在 sessionUser 非空时挂载 —— */
      }
    }
    .width('100%')
    .height('100%')
    /*
     * 安全区延伸：让根底色铺满状态栏与底部手势区。
     *
     * ⚠️ 不加这句，根容器的 100% 高度**不包含系统安全区**，
     * 上下两条安全区会露出窗口默认底色（浅色模式下是纯白）——
     * 表现为底部玻璃导航下方一条白带、深色模式下顶部也有一条灰带。
     * 只声明 SYSTEM 一类（不额外声明 CUTOUT）避免与系统栏图标反色打架，
     * 顶部状态栏一并纳入，页面底色上下贯通。
     */
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
    /*
     * 页面根底：不透明实色（EcoTheme.bgSolid），不是半透明 bg()。
     *
     * ⚠️ 这里是整条「底部发白」的根因：@Entry 根容器默认是系统纯白，
     * 而所有页面的 mood 底色都是 62% 半透明（EcoMood.*_BG）——
     * 半透明色叠在白底上会褪成近白（62% 薄荷 + 白 ≈ #F7FDFA），
     * 于是：① 四个一级页的底色发白；② 底部 76px 占位区 +
     * 胶囊四周留白发白；③ 胶囊的 backdropBlur 采样到这层白，
     * 整条玻璃导航栏跟着发白，液态玻璃感全无。
     *
     * 根底必须先钉一层实色，上层的半透明底色 / 玻璃 / 模糊才有东西可透。
     * 实色与各档 *_BG 的 RGB 完全一致（仅 alpha 0.62→1.0），
     * 所以与一级页面底色观感连续，不会出现色阶跳变。
     * 子页面在自己的根上还有一层半透明底，透出来的仍是这层实色，同色系。
     */
    .backgroundColor(this.tc(EcoTheme.bgSolid(this.ecoLevel)))
    /*
     * themeTick 恒读钩子：深色模式换的是 static 色值令牌，
     * 而本根 Stack 的底色正来自 EcoTheme.bgSolid(ecoLevel)。
     * 不订阅 themeTick 就不会重建 → 根底永远是浅色实色，
     * 上层 62% 半透明的深色底透出来被冲淡，表现为「只有设置页变深、
     * 首页不变」。值恒为 1，无视觉影响。
     */
    .opacity(this.themeTick >= 0 ? 1 : 0)
    .animation({ duration: AppleMotion.THEME_MS, curve: AppleMotion.EASE })
    .bindSheet(this.showAddSheet, this.AddSheetContent(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // 下滑关闭时系统不回写开关，必须在消失时复位，
      // 否则再次点击无法触发 false→true 跃迁，行为录入面板再也弹不出
      onDisappear: (): void => {
        this.showAddSheet = false
      }
    })
  }
}
