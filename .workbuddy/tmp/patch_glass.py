"""Batch patch: unify remaining flat glass surfaces onto the 135-degree light
model (liquid glass) and remove dark-mode-incompatible hardcoded colors.

Run with --apply to write, without it to dry-run.
Every edit asserts its expected substring is present, so a mismatch aborts
instead of silently corrupting code.
"""
import sys
import os

ROOT = r'D:\11\carbon-master\app\entry\src\main\ets'
APPLY = '--apply' in sys.argv

EDGE_OLD = ".border({ width: 1, color: Glass.EDGE })"


def edge_new(tier, ambient):
    # ambient is passed as an already-formatted ArkTS expression: "''" or "this.moodBg()"
    return ".border({ width: 1, color: GlassLight.borderColors(GlassTier.%s, %s, 1) })" % (
        tier, ambient)


def panel_new(ambient):
    return ".linearGradient(GlassLight.panelSurface(%s))" % ambient


# (relative file, 1-based line, old substring, new substring)
EDITS = [
    # ---- A. flat PANEL_LIVE_BG panels -> 135-degree composited gradient ----
    ('pages/OnboardingPage.ets', 213, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/SplashPage.ets', 101, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/dashboard/DashboardPage.ets', 644, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new('this.moodBg()')),
    ('pages/settings/EcoDebugSheet.ets', 121, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/settings/EcoDebugSheet.ets', 182, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/settings/EcoDebugSheet.ets', 243, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/settings/EcoDebugSheet.ets', 273, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),
    ('pages/settings/EcoDebugSheet.ets', 354, '.backgroundColor(Glass.PANEL_LIVE_BG)', panel_new("''")),

    # ---- B. uniform white 1px border -> four-side directional border ----
    ('pages/OnboardingPage.ets', 215, EDGE_OLD, edge_new('PANEL', "''")),
    ('pages/SplashPage.ets', 104, EDGE_OLD, edge_new('PANEL', "''")),
    ('pages/article/ArticleListPage.ets', 155, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/behavior/BehaviorAddSheet.ets', 256, EDGE_OLD, edge_new('PILL', "''")),
    ('pages/behavior/BehaviorAddSheet.ets', 294, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/chart/CategoryAnalysisPage.ets', 256, EDGE_OLD, edge_new('PILL', "''")),
    ('pages/chart/CategoryAnalysisPage.ets', 317, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/chart/TrendChartPage.ets', 321, EDGE_OLD, edge_new('PILL', "''")),
    ('pages/chart/TrendChartPage.ets', 371, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/chart/TrendChartPage.ets', 510, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/dashboard/DashboardPage.ets', 461, EDGE_OLD, edge_new('CARD', 'this.moodBg()')),
    ('pages/dashboard/DashboardPage.ets', 647, EDGE_OLD, edge_new('PANEL', 'this.moodBg()')),
    ('pages/mine/LevelTreePage.ets', 304, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/points/BadgeDetailSheet.ets', 401, EDGE_OLD, edge_new('PANEL', "''")),
    ('pages/points/BadgeWallPage.ets', 459, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/points/BadgeWallPage.ets', 506, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/points/PointsHomePage.ets', 376, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/points/PointsMallPage.ets', 395, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/record/RecordListPage.ets', 513, EDGE_OLD, edge_new('PANEL', "''")),
    ('pages/record/RecordListPage.ets', 644, EDGE_OLD, edge_new('CARD', "''")),
    ('pages/terminal/SuperTerminalPage.ets', 298, EDGE_OLD, edge_new('CARD', "''")),
    ('ui/Components.ets', 370, EDGE_OLD, edge_new('CARD', "''")),
    ('ui/Components.ets', 660, EDGE_OLD, edge_new('PILL', "''")),
    ('ui/Components.ets', 728, EDGE_OLD, edge_new('PILL', "''")),

    # ---- C. flat white segment track (bright slab in dark mode) ----
    ('pages/chart/CategoryAnalysisPage.ets', 255,
     ".backgroundColor('rgba(255,255,255,0.42)')",
     ".linearGradient(GlassLight.surface(Glass.SEGMENT_TRACK_BG, GlassTier.PILL, '', 1))"),

    # ---- D. hardcoded dark-ink borders that vanish in dark mode ----
    ('pages/settings/EcoDebugSheet.ets', 275, "'rgba(46,58,54,0.06)'", 'Neutral.BORDER'),
    ('pages/settings/EcoDebugSheet.ets', 292, "'rgba(46,58,54,0.08)'", 'Neutral.BORDER'),
    ('pages/settings/EcoDebugSheet.ets', 356, "'rgba(46,58,54,0.06)'", 'Neutral.BORDER'),
]

# (relative file, insert-after 1-based line, text)
IMPORTS = [
    ('pages/OnboardingPage.ets', 0, None),  # handled as replace below
]
IMPORT_REPLACES = [
    ('pages/OnboardingPage.ets', "import { GlassLight } from '../ui/GlassLight'",
     "import { GlassLight, GlassTier } from '../ui/GlassLight'"),
    ('pages/SplashPage.ets', "import { GlassLight } from '../ui/GlassLight';",
     "import { GlassLight, GlassTier } from '../ui/GlassLight';"),
]
IMPORT_INSERTS = [
    ('pages/points/PointsHomePage.ets', 19, "import { GlassLight, GlassTier } from '../../ui/GlassLight'"),
    ('pages/points/PointsMallPage.ets', 7, "import { GlassLight, GlassTier } from '../../ui/GlassLight'"),
    ('pages/settings/EcoDebugSheet.ets', 15, "import { GlassLight, GlassTier } from '../../ui/GlassLight'"),
]


def load(rel):
    path = os.path.join(ROOT, rel)
    raw = open(path, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    text = raw.decode('utf-8-sig')
    crlf = '\r\n' in text
    lines = text.split('\r\n') if crlf else text.split('\n')
    return path, lines, crlf, bom


def save(path, lines, crlf, bom):
    text = ('\r\n' if crlf else '\n').join(lines)
    data = text.encode('utf-8')
    if bom:
        data = b'\xef\xbb\xbf' + data
    open(path, 'wb').write(data)


cache = {}
errors = []
for rel, ln, old, new in EDITS:
    if rel not in cache:
        cache[rel] = load(rel)
    path, lines, crlf, bom = cache[rel]
    if ln - 1 >= len(lines):
        errors.append('%s:%d line out of range' % (rel, ln))
        continue
    src = lines[ln - 1]
    if old not in src:
        errors.append('%s:%d expected %r not found in %r' % (rel, ln, old, src.strip()[:120]))
        continue
    lines[ln - 1] = src.replace(old, new, 1)
    print('OK   %s:%d\n     - %s\n     + %s' % (rel, ln, src.strip()[:110], lines[ln - 1].strip()[:110]))

for rel, old, new in IMPORT_REPLACES:
    if rel not in cache:
        cache[rel] = load(rel)
    path, lines, crlf, bom = cache[rel]
    hit = 0
    for i, src in enumerate(lines):
        if old in src:
            lines[i] = src.replace(old, new, 1)
            hit += 1
            print('OK   %s import -> %s' % (rel, new))
            break
    if hit == 0:
        errors.append('%s import %r not found' % (rel, old))

for rel, after, text in IMPORT_INSERTS:
    if rel not in cache:
        cache[rel] = load(rel)
    path, lines, crlf, bom = cache[rel]
    if any(text in l for l in lines):
        print('SKIP %s import already present' % rel)
        continue
    lines.insert(after, text)
    print('OK   %s insert import after L%d' % (rel, after))

if errors:
    print('\n!! %d ERROR(S), nothing written:' % len(errors))
    for e in errors:
        print('  ', e)
    sys.exit(1)

if APPLY:
    for rel, (path, lines, crlf, bom) in cache.items():
        save(path, lines, crlf, bom)
    print('\nAPPLIED %d files.' % len(cache))
else:
    print('\nDRY RUN ok (%d files would change). Re-run with --apply.' % len(cache))
