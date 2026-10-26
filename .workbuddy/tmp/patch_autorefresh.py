"""Wire ecoTick / activeTab changes to the existing page handlers via @Watch.

Root cause: every page wrote `onStorageChange(key)` believing it was a
framework lifecycle, but ArkUI has no such callback (verified against SDK
d.ts). @StorageLink only marks the component dirty; the handler never runs,
so `load()` never re-fetches -> "must refresh manually after recording".

Fix: attach @Watch to the existing @StorageLink and bridge it into the
handler that is already written in every page.

Run with --apply to write; default is a dry run.
"""
import sys
import os
import re

ROOT = r'D:\11\carbon-master\app\entry\src\main\ets'
APPLY = '--apply' in sys.argv

ECO_DECL_OLD = "@StorageLink('ecoTick') ecoTick: number = 0"
ECO_DECL_NEW = "@StorageLink('ecoTick') @Watch('onEcoTick') ecoTick: number = 0"

BRIDGE = """  /**
   * ecoTick 变化的**真正**回调入口（@Watch 驱动）。
   * ------------------------------------------------------------------
   * ⚠️ 这里必须走 @Watch：ArkUI **没有** `onStorageChange` 这个生命周期
   *    （SDK d.ts 里不存在），框架永远不会调用它。只订阅 @StorageLink
   *    的结果是「组件重建了、但没有重新拉数据」——
   *    这正是「记完一笔还要手动刷新」的根因：全库 30+ 个页面都写了
   *    一个没人调用的方法。
   *
   * `@Watch` 才是官方支持的「响应式变量变化回调」：
   *   记录写入 → DataSource.addRecord → EcoMoodState.broadcastDataChange()
   *   → AppStorage('ecoTick') +1 → 本方法 → onStorageChange('ecoTick')
   *   → 重算碳档位 + load() 重拉数据。
   */
  onEcoTick(): void {
    this.onStorageChange('ecoTick')
  }

"""

TAB_BRIDGE = """  /**
   * 切回「记录」Tab 的刷新入口（@Watch 驱动，理由同 onEcoTick）。
   * activeTab 由 Index.switchTab 写入，这里只在本页被选中时重拉，
   * 兜住「页面常驻、切回来时数据已变」的场景。
   */
  onActiveTab(): void {
    this.onStorageChange('activeTab')
  }

"""

TARGET_RE = re.compile(r'^(\s*)onStorageChange\(key: string\): void \{')

eco_files = []
tab_files = []
cache = {}


def load(rel):
    path = os.path.join(ROOT, rel)
    raw = open(path, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    text = raw.decode('utf-8-sig')
    crlf = '\r\n' in text
    return path, (text.split('\r\n') if crlf else text.split('\n')), crlf, bom


def save(path, lines, crlf, bom):
    text = ('\r\n' if crlf else '\n').join(lines)
    data = text.encode('utf-8')
    if bom:
        data = b'\xef\xbb\xbf' + data
    open(path, 'wb').write(data)


for dirpath, _dirs, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.ets'):
            continue
        path = os.path.join(dirpath, fn)
        rel = os.path.relpath(path, ROOT)
        text = open(path, encoding='utf-8-sig').read()
        if ECO_DECL_OLD in text:
            eco_files.append(rel)
        if "@StorageLink('activeTab') activeTab: number = 0" in text:
            tab_files.append(rel)

print('ecoTick pages:', len(eco_files))
print('activeTab pages:', len(tab_files), tab_files)

errors = []
changed = []


def patch_token(rel, old, new, tag):
    global cache
    if rel not in cache:
        cache[rel] = load(rel)
    path, lines, crlf, bom = cache[rel]
    hit = False
    for i, src in enumerate(lines):
        if old in src:
            lines[i] = src.replace(old, new, 1)
            hit = True
            break
    if not hit:
        errors.append('%s: %r not found' % (rel, old))
        return False
    print('OK   %-46s %s' % (rel, tag))
    if rel not in changed:
        changed.append(rel)
    return True


DONE = set()


def insert_bridge(rel, bridge, tag):
    global cache
    if (rel, tag) in DONE:
        print('SKIP %-46s already has %s' % (rel, tag))
        return True
    if rel not in cache:
        cache[rel] = load(rel)
    path, lines, crlf, bom = cache[rel]
    for i, src in enumerate(lines):
        m = TARGET_RE.match(src)
        if m:
            body = bridge
            lines[i:i] = body.split('\n')
            # split('\n') leaves a trailing '' because bridge ends with \n
            if lines[i + len(body.split('\n')) - 1] == '':
                del lines[i + len(body.split('\n')) - 1]
            DONE.add((rel, tag))
            print('OK   %-46s insert %s before L%d' % (rel, tag, i + 1))
            if rel not in changed:
                changed.append(rel)
            return True
    errors.append('%s: onStorageChange(...) signature not found' % rel)
    return False


for rel in eco_files:
    patch_token(rel, ECO_DECL_OLD, ECO_DECL_NEW, "@Watch('onEcoTick')")
    insert_bridge(rel, BRIDGE, 'onEcoTick')

for rel in tab_files:
    patch_token(rel, "@StorageLink('activeTab') activeTab: number = 0",
                "@StorageLink('activeTab') @Watch('onActiveTab') activeTab: number = 0",
                "@Watch('onActiveTab')")
    insert_bridge(rel, TAB_BRIDGE, 'onActiveTab')

if errors:
    print('\n!! %d ERROR(S), nothing written:' % len(errors))
    for e in errors:
        print('  ', e)
    sys.exit(1)

print('\nfiles changed: %d' % len(changed))
if APPLY:
    for rel in changed:
        path, lines, crlf, bom = cache[rel]
        save(path, lines, crlf, bom)
    print('APPLIED.')
else:
    print('DRY RUN ok. Re-run with --apply.')
