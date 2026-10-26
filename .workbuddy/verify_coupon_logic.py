#!/usr/bin/env python3
"""碳惠券包链路逻辑自检（与 LocalStore.ets / GlassDialog.ets 同口径复算）"""
import math, json

DAY = 24 * 60 * 60 * 1000
TTL = 7 * DAY
FAIL = []

def check(name, cond, detail=""):
    print(("PASS" if cond else "FAIL"), "-", name, detail)
    if not cond:
        FAIL.append(name)

# ---------- 1. couponStatus 状态推导 ----------
def coupon_status(c, now):
    if c["status"] == "used":
        return "used"
    return "expired" if now >= c["expireAt"] else "unused"

now = 1_700_000_000_000
base = {"status": "unused", "usedAt": 0, "qrContent": ""}
c7   = {**base, "expireAt": now + TTL}
c6d  = {**base, "expireAt": now + 6 * DAY + 3600_000}
c0   = {**base, "expireAt": now + 1000}
cEnd = {**base, "expireAt": now}                    # 恰好到期这一刻
cPast= {**base, "expireAt": now - 1}
cUsed= {**base, "status": "used", "expireAt": now - 10 * DAY, "qrContent": "x"}

check("刚领取 = unused",            coupon_status(c7, now) == "unused")
check("第 6 天 = unused",           coupon_status(c6d, now) == "unused")
check("最后 1 秒 = unused",         coupon_status(c0, now) == "unused")
check("恰好到期 = expired(>= 边界)",coupon_status(cEnd, now) == "expired")
check("过期后 = expired",           coupon_status(cPast, now) == "expired")
check("已使用优先于过期",           coupon_status(cUsed, now) == "used")
check("已使用未过期 = used",        coupon_status({**base, "status": "used"}, now) == "used")

# ---------- 2. daysLeft（券面「N 天后失效」） ----------
def days_left(expire_at, now):
    ms = expire_at - now
    return 0 if ms <= 0 else math.ceil(ms / DAY)

check("刚领取显示 7 天后失效",  days_left(now + TTL, now) == 7)
check("过 1 秒仍显示 7（向上取整）", days_left(now + TTL - 1000, now) == 7)
check("剩 1 秒显示 1",          days_left(now + 1000, now) == 1)
check("到期 = 0",               days_left(now, now) == 0)
check("过期 = 0",               days_left(now - 5 * DAY, now) == 0)

# 边界一致性：恰好到期时 daysLeft=0 与 status=expired 必须同时成立
# （否则出现「0 天后失效却仍可使用」的矛盾态）
check("边界一致：到期时剩余0天且状态expired",
      days_left(cEnd["expireAt"], now) == 0 and coupon_status(cEnd, now) == "expired")
# ceil 口径：剩余 6 天 4 小时 → 显示 7（向上取整，保证领取当天全天稳定显示 7）
check("剩余 6 天 4 小时 = 显示 7（ceil 稳定首日）", days_left(now + 6 * DAY + 4 * 3600_000, now) == 7)
check("剩余 5 天 12 小时 = 显示 6", days_left(now + 5 * DAY + 12 * 3600_000, now) == 6)

# ---------- 3. 积分守恒：available = earned - exchanged ----------
def stats(coupons, earned):
    exchanged = sum(c["points"] for c in coupons)
    tree_exchanged = sum(c["points"] for c in coupons if c["kind"] == "tree")
    return {
        "availablePoints": earned - exchanged,
        "exchangedPoints": exchanged,
        "treeExchangedPoints": tree_exchanged,
        "treeCount": tree_exchanged // 3000,   # Biz.POINTS_PER_TREE = 3000
    }

earned = 5000
coupons = [
    {"points": 500,  "kind": "coupon", "status": "unused"},   # b1 公交
    {"points": 800,  "kind": "coupon", "status": "used"},     # b2 公园（已用仍占消耗）
    {"points": 1200, "kind": "coupon", "status": "unused"},   # b3 骑行（过期态也占消耗）
    {"points": 3000, "kind": "tree",   "status": "unused"},   # b7 植树
]
# API 不变式：exchange() 每次按当前 available 门槛放行 → exchanged 永不超过 earned。
# 模拟连续兑换：500+800+1200=2500 后剩 2500；3000 被拒（不够），2000 恰够放行，余 500。
seq = [500, 800, 1200, 3000, 2000]
acc = []
for cost in seq:
    if earned - sum(c["points"] for c in acc) >= cost:
        acc.append({"points": cost, "kind": "coupon"})
check("连续兑换受门槛保护：available 不为负", earned - sum(c["points"] for c in acc) >= 0)
check("3000 被拒、2000 恰够放行（进 4 笔余 500）",
      len(acc) == 4 and earned - sum(c["points"] for c in acc) == 500)
s2 = stats(coupons, 6000)
check("可用积分 = 6000-5500 = 500", s2["availablePoints"] == 500)
check("总消耗 = 5500", s2["exchangedPoints"] == 5500)
check("证书口径只认植树 3000", s2["treeExchangedPoints"] == 3000)
check("植树证书 = 1 棵", s2["treeCount"] == 1)
# 兑换公交券不产证书
s3 = stats([{"points": 500, "kind": "coupon"}], 5000)
check("兑换公交券不产植树证书", s3["treeExchangedPoints"] == 0 and s3["treeCount"] == 0)
# 无券账号行为零变化
s0 = stats([], 5000)
check("无券账号：available=earned，口径零变化", s0["availablePoints"] == 5000 and s0["exchangedPoints"] == 0)

# ---------- 4. exchange 幂等/防重 ----------
def exchange(coupons, benefit, available):
    if available < benefit["points"]:
        return None
    coupons.insert(0, {**benefit, "status": "unused", "qrContent": ""})
    return coupons[0]

b = {"points": 2000, "kind": "coupon"}
check("积分不足拒绝兑换", exchange([], b, 1999) is None)
cp = exchange([], b, 2000)
check("积分刚好够可兑换", cp is not None)

# ---------- 5. useCoupon 幂等回看 ----------
def use_coupon(coupons, cid, now):
    for c in coupons:
        if c["id"] != cid:
            continue
        if coupon_status(c, now) == "expired":
            return None
        if c["status"] == "used":
            return c["qrContent"] if c["qrContent"] else None
        c["status"] = "used"
        c["qrContent"] = "感谢您的欣赏｜券号 " + c["id"] + "｜核销码 123456"
        return c["qrContent"]
    return None

cs = [{"id": "CP-1", "status": "unused", "expireAt": now + TTL, "qrContent": ""}]
q1 = use_coupon(cs, "CP-1", now)
q2 = use_coupon(cs, "CP-1", now)
check("首次使用生成核销码", q1 is not None and "感谢您的欣赏" in q1)
check("重复使用返回同一核销码（幂等）", q1 == q2)
check("过期券拒绝使用", use_coupon([{"id": "CP-2", "status": "unused", "expireAt": now - 1, "qrContent": ""}], "CP-2", now) is None)
check("不存在的券返回 null", use_coupon([], "CP-X", now) is None)

# ---------- 6. GlassDialog.panelNotch 遮罩合成（over() 复算） ----------
def rgba_of(color):
    if color.startswith("#") and len(color) == 7:
        return [int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16), 1.0]
    if color.startswith("rgba("):
        p = [x.strip() for x in color[5:-1].split(",")]
        return [float(p[0]), float(p[1]), float(p[2]), float(p[3])]
    raise ValueError(color)

def over(base, top, scale=1.0):
    ba = min(1, max(0, base[3]))
    ta = min(1, max(0, top[3] * scale))
    out_a = ta + ba * (1 - ta)
    if out_a <= 0.001:
        return "rgba(0,0,0,0)"
    k = ba * (1 - ta)
    return "rgba(%d,%d,%d,%.3f)" % (
        (top[0]*ta + base[0]*k)/out_a, (top[1]*ta + base[1]*k)/out_a,
        (top[2]*ta + base[2]*k)/out_a, out_a)

def panel_notch(bg_solid, mask, panel_bg):
    masked = rgba_of(over(rgba_of(bg_solid), rgba_of(mask)))
    return over(masked, rgba_of(panel_bg))

light = panel_notch("#FBF8F3", "rgba(20,26,24,0.45)", "rgba(255,255,255,0.50)")
dark  = panel_notch("#141A18", "rgba(0,0,0,0.56)", "rgba(255,255,255,0.06)")
print("  浅色面板缺口色:", light)
print("  深色面板缺口色:", dark)

def parse_rgba(s):
    p = [float(x.strip()) for x in s[s.index("(")+1:-1].split(",")]
    return p

def luma_of(p):
    return (0.2126*p[0] + 0.7152*p[1] + 0.0722*p[2])/255

# 真正的 invariant：缺口色 == 卡片后方有效底色（遮罩页底 → 玻璃平涂）的逐层合成。
# 浅色：遮罩压暗页面底；深色：遮罩后再被白染玻璃提亮 —— 两种模式都必须
# 与「实际叠在卡片后面的东西」同色，缺口才融进表面而不是一块异色斑。
masked_dark = parse_rgba(over(rgba_of("#141A18"), rgba_of("rgba(0,0,0,0.56)")))
check("深色缺口 = 遮罩页底 + 白染玻璃（链路精确）",
      dark == over(list(masked_dark) + [1.0], rgba_of("rgba(255,255,255,0.06)")))
check("深色缺口比遮罩页底亮（白染提亮生效）", luma_of(parse_rgba(dark)) > luma_of(masked_dark))
check("深色缺口不糊成近白", luma_of(parse_rgba(dark)) < 0.35, f"L={luma_of(parse_rgba(dark)):.3f}")
check("浅色缺口比页面底暗（遮罩压暗）", luma_of(parse_rgba(light)) < luma_of([251,248,243]))
check("浅色缺口不接近纯黑（保留玻璃感）", luma_of(parse_rgba(light)) > 0.45, f"L={luma_of(parse_rgba(light)):.3f}")

# ---------- 7. 备份 v1/v2 判别 ----------
def parse_backup(text):
    parsed = json.loads(text)
    if isinstance(parsed, list):
        return {"records": parsed, "coupons": []}      # v1 纯 records
    return {"records": parsed.get("records", []), "coupons": parsed.get("coupons", [])}  # v2
v1 = parse_backup('[{"id":1}]')
v2 = parse_backup('{"records":[{"id":1}],"coupons":[{"couponId":"CP-1"}]}')
check("v1 备份兼容（券列表为空）", v1["records"] and v1["coupons"] == [])
check("v2 备份双读", v2["records"] and len(v2["coupons"]) == 1)

# ---------- 8. 券号格式（rand4/rand6 补零与位数） ----------
def rand4(n):
    return ("0" if n < 1000 else "") + ("0" if n < 100 else "") + ("0" if n < 10 else "") + str(n)

def rand6(n):
    s = str(n)
    return s.zfill(6)

import random
random.seed(7)
ok_fmt = all(len(rand4(random.randrange(10000))) == 4 for _ in range(5000))
check("rand4 恒为 4 位", ok_fmt)
check("rand4 补零：5 → 0005", rand4(5) == "0005")
check("rand4 补零：42 → 0042", rand4(42) == "0042")
check("rand4 补零：999 → 0999", rand4(999) == "0999")
check("rand4 上限：9999 → 9999", rand4(9999) == "9999")
check("rand6 补零：5 → 000005", rand6(5) == "000005")
check("rand6 上限：999999 → 999999", rand6(999999) == "999999")
# 券号整体格式：CP-YYYYMMDDHHmmss-XXXX
cid = "CP-20261020143012-" + rand4(1234)
check("券号格式 CP-14位时间戳-4位随机", cid.startswith("CP-") and len(cid) == 3 + 14 + 1 + 4, cid)

print()
if FAIL:
    print("FAILED:", len(FAIL), FAIL)
    raise SystemExit(1)
print("ALL CHECKS PASSED")
