import { promptAction, PromptAction, UIContext } from '@kit.ArkUI'

export class Toast {
  private static ctx: UIContext | null = null

  static bind(ctx: UIContext): void {
    Toast.ctx = ctx;
  }

  private static action(): PromptAction | null {
    if (Toast.ctx !== null) {
      try {
        return Toast.ctx.getPromptAction();
      } catch (err) {
        // 上下文失效，回退
      }
    }
    return null;
  }

  static show(message: string): void {
    try {
      const pa: PromptAction | null = Toast.action();
      if (pa !== null) {
        pa.showToast({ message: message });
      }
    } catch (err) {
      // 静默忽略
    }
  }

  static success(message: string): void {
    Toast.show(message);
  }

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
      return false;
    } catch (err) {
      return false;
    }
  }
}

export function toast(message: string): void {
  Toast.show(message);
}
