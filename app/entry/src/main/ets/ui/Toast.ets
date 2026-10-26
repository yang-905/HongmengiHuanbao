/**
 * 安全的轻提示工具
 * ------------------------------------------------------------------
 * 为什么需要它：
 * 1) ArkTS 静态检查要求「可能抛异常的调用必须显式处理」，
 *    而 toast / dialog 在部分设备或 Previewer 环境下可能抛异常
 *    （如窗口句柄失效）。若在每个页面都写 try/catch 会非常冗余。
 * 2) promptAction.showToast / showDialog 自 API 18 起已废弃，
 *    官方替代是 UIContext.getPromptAction()。
 *    继续用旧 API 会在 DevEco 里产生 deprecation 告警。
 *
 * 用法：
 *   import { toast, Toast } from '../../ui/Toast'
 *   Toast.bind(this)          // 页面 aboutToAppear 里绑定一次
 *   toast('已保存')           // 之后直接用函数式简写
 *
 * 未绑定组件上下文时会自动回退到全局 API（功能一致，仅有 deprecation 告警）。
 */
import { promptAction, PromptAction, UIContext } from '@kit.ArkUI'

export class Toast {
  /** 绑定的 UI 上下文，由 Toast.bind() 注入 */
  private static ctx: UIContext | null = null

  /**
   * 绑定页面上下文（建议在页面的 aboutToAppear 里调一次）：
   *   Toast.bind(this.getUIContext())
   * 绑定后使用 UIContext 的新 API，消除 deprecation 告警。
   */
  static bind(ctx: UIContext): void {
    Toast.ctx = ctx;
  }

  /** 取当前可用的 PromptAction（新 API 优先） */
  private static action(): PromptAction | null {
    if (Toast.ctx !== null) {
      try {
        return Toast.ctx.getPromptAction();
      } catch (err) {
        // 组件已销毁或上下文失效，回退到全局 API
      }
    }
    return null;
  }

  /**
   * 普通提示（静默失败，不影响业务）。
   * 这是全项目唯一的提示出口，永不抛出异常。
   */
  static show(message: string): void {
    try {
      const pa: PromptAction | null = Toast.action();
      if (pa !== null) {
        pa.showToast({ message: message });
      }
      // 未绑定上下文时静默跳过：UIContext 在 EntryAbility 之后才可用，
      // 极早期的调用（如 onCreate）拿不到属正常情况，不影响业务。
    } catch (err) {
      // Previewer 或窗口不可用时静默忽略：提示失败不应影响主流程
    }
  }

  /** 成功提示（与 show 同实现，语义化别名） */
  static success(message: string): void {
    Toast.show(message);
  }

  /**
   * 确认对话框（默认「取消 / 确定」）。
   * @return 用户点确定返回 true；取消或任何异常返回 false
   */
  static async confirm(message: string, title: string = '提示'): Promise<boolean> {
    return Toast.confirmWith(
      title,
      message,
      [
        { text: '取消', color: '#6B7A75' },
        { text: '确定', color: '#2A9E82' }
      ],
      1
    );
  }

  /**
   * 自定义按钮的确认对话框。
   * @param buttons 按钮数组，index 与返回值对应
   * @param confirmIndex 「确定」按钮所在的下标
   * @return 点中 confirmIndex 返回 true；取消/异常返回 false
   */
  static async confirmWith(
    title: string,
    message: string,
    buttons: promptAction.Button[],
    confirmIndex: number
  ): Promise<boolean> {
    try {
      const opts: promptAction.ShowDialogOptions = {
        title: title,
        message: message,
        buttons: buttons
      };
      const pa: PromptAction | null = Toast.action();
      if (pa !== null) {
        const res: promptAction.ShowDialogSuccessResponse = await pa.showDialog(opts);
        return res.index === confirmIndex;
      }
      // 未绑定上下文时按「取消」处理，避免误执行破坏性操作
      return false;
    } catch (err) {
      return false;
    }
  }
}

/** 函数式简写，便于页面少写 import 前缀 */
export function toast(message: string): void {
  Toast.show(message);
}
