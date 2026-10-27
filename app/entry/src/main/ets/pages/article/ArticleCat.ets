/**
 * 文章分类元信息与阅读数格式化（三页共用）
 */
import { Accent, Brand } from '../../ui/Theme'

export class ArticleCat {
  static readonly ALL: string = 'all';
  static readonly POLICY: string = 'policy';
  static readonly CONCEPT: string = 'concept';
  static readonly TIPS: string = 'tips';

  static label(key: string): string {
    if (key === ArticleCat.POLICY) return '双碳政策';
    if (key === ArticleCat.CONCEPT) return '基础概念';
    if (key === ArticleCat.TIPS) return '减碳技巧';
    return '全部';
  }

  /** 分类图标 code（IconMap 的 ui 表），原先是 emoji */
  static icon(key: string): string {
    if (key === ArticleCat.POLICY) return 'certificate';
    if (key === ArticleCat.CONCEPT) return 'ruler';
    if (key === ArticleCat.TIPS) return 'bulb';
    return 'book';
  }

  /** 浅底色 */
  static bg(key: string): string {
    if (key === ArticleCat.POLICY) return Accent.INFO_BG;
    if (key === ArticleCat.CONCEPT) return Accent.TRAVEL_BG;
    if (key === ArticleCat.TIPS) return Accent.SUCCESS_BG;
    // 兜底是「文章分类」的语义配色，不随碳档位变化
    return Brand.PRIMARY_PALE;
  }

  /** 主色 */
  static fg(key: string): string {
    if (key === ArticleCat.POLICY) return Accent.INFO;
    if (key === ArticleCat.CONCEPT) return Accent.TRAVEL;
    if (key === ArticleCat.TIPS) return Accent.SUCCESS;
    return Brand.PRIMARY_DEEP;
  }
}

/** 阅读数：过万折算为「x.xw」，千位折算为「x.xk」（模块级，三页共用） */
export function fmtRead(n: number): string {
  if (n >= 10000) return (n / 10000).toFixed(1) + 'w'
  if (n >= 1000) return (n / 1000).toFixed(1) + 'k'
  return '' + n
}
