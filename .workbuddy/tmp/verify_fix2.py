"""复算新 surface()：检查所有玻璃底色在浅/深色下是否还会压出暗角。"""
from PIL import Image, ImageDraw

CARD, PILL, PANEL = 'card', 'pill', 'panel'


class P:
    dark = False


def adapt(l):
    if l > 0.78:
        return 0.92
    if l < 0.40:
        return 1.22
    return 1.0


def dark_adapt(l):
    if l < 0.12:
        return 1.18
    if l < 0.25:
        return 1.08
    return 1.0


def tint_alpha(tier, l):
    if P.dark:
        a = 0.09
        if tier == PILL:
            a = 0.13
        elif tier == PANEL:
            a = 0.11
        if l < 0.12:
            a += 0.02
        elif l > 0.25:
            a -= 0.02
        return min(0.20, max(0.05, a))
    f = adapt(l)
    if tier == PILL:
        a = 0.42 * f
    elif tier == PANEL:
        a = 0.50 * f
    else:
        a = 0.72 + (f - 1) * 0.1
    return min(0.92, max(0.26, a))


def wash_alpha(tier, l):
    f = adapt(l)
    base = 0.11
    if tier == PILL:
        base = 0.10
    elif tier == PANEL:
        base = 0.13
    return base * f


def inner_alpha(tier, l):
    f = adapt(l)
    base = 0.02
    if tier == PILL:
        base = 0.02
    elif tier == PANEL:
        base = 0.03
    return base * f


def wash_alpha_dark(tier, l):
    f = dark_adapt(l)
    base = 0.05
    if tier == PILL:
        base = 0.04
    elif tier == PANEL:
        base = 0.05
    return base * f


def inner_alpha_dark(tier, l):
    f = dark_adapt(l)
    base = 0.04
    if tier == PILL:
        base = 0.05
    elif tier == PANEL:
        base = 0.045
    return base * f


def wash_colors(tier, l, gloss=1.0):
    if P.dark:
        wa = wash_alpha_dark(tier, l) * gloss
        ia = inner_alpha_dark(tier, l) * gloss
        return [((236, 244, 246, wa), 0.0),
                ((236, 244, 246, wa * 0.45), 0.14),
                ((236, 244, 246, wa * 0.12), 0.34),
                ((236, 244, 246, 0.0), 0.52),
                ((8, 14, 16, ia * 0.6), 0.86),
                ((8, 14, 16, ia), 1.0)]
    wa = wash_alpha(tier, l) * gloss
    ia = inner_alpha(tier, l) * gloss
    return [((255, 255, 255, wa), 0.0),
            ((255, 255, 255, wa * 0.62), 0.12),
            ((255, 255, 255, wa * 0.16), 0.38),
            ((255, 255, 255, 0.0), 0.55),
            ((10, 16, 14, ia * 0.30), 0.90),
            ((10, 16, 14, ia), 1.0)]


def over(base, top):
    ba, ta = base[3], max(0.0, min(1.0, top[3]))
    oa = ta + ba * (1 - ta)
    if oa <= 0.001:
        return (0, 0, 0, 0)
    k = ba * (1 - ta)
    return ((top[0] * ta + base[0] * k) / oa,
            (top[1] * ta + base[1] * k) / oa,
            (top[2] * ta + base[2] * k) / oa, oa)


def surface(base, tier, l, gloss=1.0):
    return [(over(base, c), p) for c, p in wash_colors(tier, l, gloss)]


def sample(stops, t):
    if t <= stops[0][1]:
        return stops[0][0]
    for i in range(len(stops) - 1):
        c1, p1 = stops[i]
        c2, p2 = stops[i + 1]
        if p1 <= t <= p2:
            k = 0.0 if p2 == p1 else (t - p1) / (p2 - p1)
            return tuple(c1[j] + (c2[j] - c1[j]) * k for j in range(4))
    return stops[-1][0]


def comp(c, bg):
    r, g, b, a = c
    return (r * a + bg[0] * (1 - a), g * a + bg[1] * (1 - a), b * a + bg[2] * (1 - a))


LIGHT_BG = (241, 250, 247)
DARK_BG = (17, 25, 23)

bases = [('Glass.CARD_BG', (255, 255, 255, 0.72), CARD),
         ('Glass.PANEL_LIVE_BG', (255, 255, 255, 0.50), CARD),
         ('Glass.SEGMENT_TRACK_BG', (255, 255, 255, 0.38), PILL),
         ('Glass.PILL_BG', (255, 255, 255, 0.42), PILL),
         ('Glass.BOTTOM_BAR_BG', (255, 255, 255, 0.12), PILL),
         ('Glass.DISC_BG', (255, 255, 255, 0.52), PILL),
         ('Glass.TOPBAR_BG', (255, 255, 255, 0.50), PILL)]

ok = True
for dark in (False, True):
    P.dark = dark
    bg = DARK_BG if dark else LIGHT_BG
    l = (0.2126 * bg[0] + 0.7152 * bg[1] + 0.0722 * bg[2]) / 255
    print('\n===== %s =====' % ('DARK' if dark else 'LIGHT'))
    for name, base, tier in bases:
        if dark:
            base = (236, 244, 246, tint_alpha(tier, l))
        stops = surface(base, tier, l)
        ds = []
        for i in range(11):
            c = comp(sample(stops, i / 10.0), bg)
            ds.append(round(c[0] - bg[0], 1))
        worst = min(ds)
        flag = 'OK ' if worst >= -6 else 'BAD'
        if worst < -6:
            ok = False
        print('%s %-24s t=0..1 %s  min=%+.1f' % (flag, name, ds, worst))
print('\nRESULT:', 'PASS - no dark corner on any glass surface' if ok else 'FAIL')

W, H, R = 320, 224, 18


def draw_card(draw, x, y, w, h, stops, bg, radius, rows):
    for yy in range(h):
        for xx in range(w):
            inside = True
            if xx < radius and yy < radius:
                inside = (xx - radius) ** 2 + (yy - radius) ** 2 <= radius ** 2
            elif xx > w - 1 - radius and yy < radius:
                inside = (xx - (w - 1 - radius)) ** 2 + (yy - radius) ** 2 <= radius ** 2
            elif xx < radius and yy > h - 1 - radius:
                inside = (xx - radius) ** 2 + (yy - (h - 1 - radius)) ** 2 <= radius ** 2
            elif xx > w - 1 - radius and yy > h - 1 - radius:
                inside = (xx - (w - 1 - radius)) ** 2 + (yy - (h - 1 - radius)) ** 2 <= radius ** 2
            if not inside:
                continue
            t = (xx + yy) / float(w + h)
            c = comp(sample(stops, t), bg)
            draw.point((x + xx, y + yy), (int(c[0]), int(c[1]), int(c[2])))
    for i in range(1, rows):
        yy = int(h * i / float(rows))
        draw.line([(x + 18, y + yy), (x + w - 18, y + yy)], fill=(233, 239, 235))


wa = 0.11 * 0.92
ia = 0.02 * 0.92
old_stops = [((255, 255, 255, 0.72), 0.0),
             ((255, 255, 255, wa), 0.02), ((255, 255, 255, wa * 0.62), 0.126),
             ((255, 255, 255, wa * 0.16), 0.354), ((255, 255, 255, 0.0), 0.504),
             ((10, 16, 14, ia * 0.30), 0.812), ((10, 16, 14, ia), 0.90),
             ((255, 255, 255, 0.72), 1.0)]
new_stops = surface((255, 255, 255, 0.72), CARD, 1.0)

img = Image.new('RGB', (2 * W + 100, H + 80), LIGHT_BG)
d = ImageDraw.Draw(img)
draw_card(d, 30, 48, W, H, old_stops, LIGHT_BG, R, 4)
draw_card(d, W + 70, 48, W, H, new_stops, LIGHT_BG, R, 4)
d.rectangle([30, 48, 30 + W, 48 + H], outline=(206, 218, 213))
d.rectangle([W + 70, 48, W + 70 + W, 48 + H], outline=(206, 218, 213))
d.text((34, 20), 'BEFORE  liquid glass: dark corner -39 levels', fill=(176, 58, 58))
d.text((W + 74, 20), 'AFTER  pre-composited: no corner, glass +10', fill=(24, 118, 88))
img = img.resize((img.width * 2, img.height * 2), Image.LANCZOS)
img.save(r'D:\11\carbon-master\.workbuddy\tmp\glass_fix_compare.png')
print('saved', img.size)
