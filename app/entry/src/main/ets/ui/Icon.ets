import { iconOf } from '../common/icons/IconMap';
import { IconTone, Neutral } from './Theme';

/**
 * 统一图标组件（Tabler line 图标）。
 * 染色方案：4×5 颜色矩阵（colorFilter），而非 fillColor ——
 * Tabler 是 stroke-based 图，fillColor 改动对 stroke="currentColor" 无效。
 * 资源 ic_*.svg 颜色为白色，直接引用在浅色底上看不见，一律走 CfIcon。
 * 矢量图标承担结构与操作语义；emoji/卡通图标承担情绪与身份语义。
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
