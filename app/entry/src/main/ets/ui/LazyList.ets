/**
 * 通用懒加载数据源（LazyForEach 的 IDataSource 实现）。
 * 用法：页面持有 source，数据就绪后 reload(items)，UI 用 LazyForEach 渲染。
 * IDataSource / DataChangeListener 是 ArkUI 全局接口，无需 import。
 */

/** 数据变化监听器集合 */
export class LazySource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  /** 条目总数 */
  totalCount(): number {
    return this.items.length;
  }

  /** 取指定下标的数据（LazyForEach 只对可见下标调用） */
  getData(index: number): Object {
    return this.items[index] as Object;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  /**
   * 整体重载：筛选切换 / 数据刷新走这里。
   * 内部走 onDataReloaded —— 与「数组整体替换」语义一致，
   * LazyForEach 会重建可见条目，不可见条目延迟到滚到位再建。
   */
  reload(items: T[]): void {
    this.items = items;
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }

  /** 当前数据快照（供页面侧合计计算等使用，不触发渲染） */
  snapshot(): T[] {
    return this.items;
  }
}
