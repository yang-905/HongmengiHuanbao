import { iconOf } from '../common/icons/IconMap';
import { IconTone, Neutral } from './Theme';

/**
 * 统一图标组件（Tabler line 图标）
 * ==================================================================
 * 为什么单独包一层，而不是到处写 Image(...)：
 * 1. 染色只在一个地方做，规则不会散落到 20 个页面里。
 * 2. 主题切换只在一个地方订阅：色值经 tc() 取值即建立 themeTick 依赖，
 *    深色换血后强制重取 —— 与 CfCloseIcon / CfChevron 同一套写法。
 * 3. 尺寸语义从 fontSize 改成 iconSize：emoji 时代图标跟着字号走，换成矢量图
 *    后必须显式给边长，否则 Image 默认按原始 24×24 像素铺。
 *
 * 染色方案：颜色矩阵（colorFilter），不是 fillColor
 * ------------------------------------------------------------------
 * 实测（模拟器 API 23 + Tabler outline 描边 SVG）：
 *   .renderMode(ImageRenderMode.Template) + .fillColor('#FF0000')
 *   → 图标仍然渲染成黑色，染色无效。
 * 原因：Tabler 是 stroke-based 图（stroke="currentColor"，fill="none"），
 *   ArkUI 的 fillColor 只改 SVG 的 fill，改动落在 "none" 上等于没改；
 *   而 currentColor 是 CSS 变量，ArkUI 不解析，描边回落到默认黑色。
 *   Template 虽声称「只保留 alpha 通道」，但对这类描边图并不生效。
 *
 * 改用 4×5 颜色矩阵：整幅图逐像素做线性变换。
 *   为了让同一份矩阵对任意源色都能得出「目标色」，同步脚本里已把
 *   stroke/fill 的 currentColor 统一烘焙成 #FFFFFF（纯白），
 *   矩阵就退化成「按通道相乘」：
 *     R' = r/255 × R   （白色 R=255 → R' = r，正好是目标色）
 *     G' = g/255 × G
 *     B' = b/255 × B
 *     A' = A           （alpha 保持，透明区域不会被染色）
 * 系数取 0~1（Android ColorMatrix 约定），不涉及偏移列，跨版本最稳。
 *
 * ⚠️ 因此 resources/base/media/ic_*.svg 里的颜色是白色，
 *    直接 Image($r(...)) 引用在浅色底上会看不见 —— 一律走 CfIcon。
 *
 * 视觉分工（2026-10 定稿）：矢量图标 + 卡通图标混用，不是二选一
 * ------------------------------------------------------------------
 *   · 线稿（Tabler / 本组件）：承担「结构与操作」语义 ——
 *     底部导航、宫格、列表行、按钮、统计卡、表单、筛选 chip、元信息。
 *     这类图标要跟随主题变色、要克制，线稿最稳。
 *   · 卡通（emoji 头像 / 徽章原画 / 庆祝插画）：承担「情绪与身份」语义 ——
 *     用户头像、徽章墙的成就原画、答题满分的庆祝。它们本来就是彩色的，
 *     硬画成线稿会丢掉「收集感」和亲切感。
 *   判断口径：这个图标是否需要跟主题同色？是 → 线稿；否（它自己就是内容）→ 卡通。
 *
 * ⚠️ 不用 SymbolGlyph：
 *   CfCloseIcon 注释里记录过预览器残影（同名字形节点复用旧渲染层），
 *   且系统符号库没有「步行/塑料瓶/光盘」这类业务语义图标。
 *
 * 用法：
 *   CfIcon({ kind: 'factor', code: f.itemCode, iconSize: 22 })
 *   CfIcon({ kind: 'badge', code: b.badgeCode, iconSize: 26, color: '#FFFFFF' })
 */
@Component
export struct CfIcon {
  /** 映射分组：factor / category / task / badge / benefit / article / level / tip / ui */
  @Prop kind: string = 'ui'
  /** 语义 code，见 IconMap.ets 中各表 */
  @Prop code: string = ''
  /**
   * 边长（vp）。Tabler 视口 24×24，24 的整数倍视觉最干净。
   * ⚠️ 不能叫 size：与 CustomComponent 内置的 size() 通用属性同名，
   *    编译器报「Property 'size' is not assignable to the same property
   *    in base type 'CustomComponent'」。同理避开 width/height/padding。
   */
  @Prop iconSize: number = 22
  /** 颜色；留空时看 tone，再留空则跟随主题主文字色（深色自动反白） */
  @Prop color: string = ''
  /**
   * 语义色名（见 Theme.IconTone）：travel / energy / recycle / food /
   * gold / violet / data / neutral。
   * 与 color 的关系：color 优先，其次是 tone，最后是默认文字色。
   */
  @Prop tone: string = ''

  /** 主题重建钩子（深色换血的驱动源），与 CfCloseIcon 保持一致 */
  @StorageProp('themeTick') private themeTick: number = 0

  private tc(c: string): string {
    return this.themeTick >= 0 ? c : c
  }

  /** 取色优先级：color > tone > 默认文字色；tc() 建立主题重建依赖 */
  private colorValue(): string {
    if (this.color.length > 0) return this.tc(this.color)
    if (this.tone.length > 0) return this.tc(IconTone.color(this.tone))
    return this.tc(Neutral.TEXT)
  }

  /**
   * 把 "#RRGGBB" 转成 4×5 颜色矩阵。
   * 白色源图 × 该矩阵 = 目标色，alpha 原样透传。
   */
  private tint(hex: string): ColorFilter {
    let h: string = hex;
    if (h.startsWith('#')) {
      h = h.substring(1);
    }
    // 3 位缩写（#ABC）展开成 6 位，避免颜色 token 里出现简写时算出错误色
    if (h.length === 3) {
      h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2);
    }
    const r: number = parseInt(h.substring(0, 2), 16) / 255;
    const g: number = parseInt(h.substring(2, 4), 16) / 255;
    const b: number = parseInt(h.substring(4, 6), 16) / 255;
    return new ColorFilter([
      r, 0, 0, 0, 0,
      0, g, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0
    ]);
  }

  build() {
    Image(iconOf(this.kind, this.code))
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      // 颜色矩阵染色（设置 colorFilter 后 renderMode 自动失效，故不再声明）
      .colorFilter(this.tint(this.colorValue()))
      // 图标不可拖拽：避免长按列表时图标被拖出「幽灵图」
      .draggable(false)
  }
}
