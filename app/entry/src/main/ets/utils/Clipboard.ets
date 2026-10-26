/**
 * 系统剪贴板：全应用「真复制」唯一出口
 * ------------------------------------------------------------------
 * 背景（用户反馈「分享复制之后，并没有真的复制」）：
 *   全工程原有 5 处「复制」交互（文章分享 / 智慧服务文案 / 低碳成绩单 /
 *   证书编号 / 家庭邀请）都只弹了 toast，从未调用系统粘贴板 ——
 *   toast 说「已复制」，剪贴板里什么都没有。
 *   本类把「复制」收敛到一个出口：所有调用方复制后按返回值 toast
 *   成功 / 失败，杜绝「假复制」。
 *
 * API 口径（以本机 SDK API 24 的 @ohos.pasteboard 声明为准）：
 *   · pasteboard.getSystemPasteboard() 无参即可取系统剪贴板；
 *   · 文本经 pasteboard.createData(MIMETYPE_TEXT_PLAIN, text) 打包；
 *   · SystemPasteboard.setDataSync(data) 同步写入，返回值为 void ——
 *     因此成败判定只能靠 try/catch（抛异常 = 失败），不能靠返回值。
 *
 * 预览器口径：预览器可能不提供剪贴板能力，调用抛异常时返回 false，
 * 调用方应给出「复制失败」toast 兜底，不能假装成功。
 */
import { pasteboard } from '@kit.BasicServicesKit'

export class Clipboard {
  /**
   * 复制纯文本到系统剪贴板。
   * @param text 待复制文本（空串视为失败，调用方无需再判空）
   * @return true = 已写入系统剪贴板；false = 写入失败（预览器无能力等）
   */
  static copy(text: string): boolean {
    if (text.length === 0) return false
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      board.setDataSync(data)
      return true
    } catch (err) {
      // 预览器 / 系统能力不可用：如实返回失败，由调用方兜底提示
      return false
    }
  }
}
