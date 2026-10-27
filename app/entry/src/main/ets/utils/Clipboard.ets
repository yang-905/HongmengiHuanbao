import { pasteboard } from '@kit.BasicServicesKit'

export class Clipboard {
  static copy(text: string): boolean {
    if (text.length === 0) return false
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      board.setDataSync(data)
      return true
    } catch (err) {
      return false
    }
  }
}
