# -*- coding: utf-8 -*-
"""生成《一触青绿》作品设计文档配图（PIL 绘制，2x 分辨率）"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "assets")
os.makedirs(OUT, exist_ok=True)

S = 2  # 2x scale
FONT = r"C:\Windows\Fonts\msyh.ttc"

C = {
    "blue_fill": "#E6F1FB", "blue_box": "#B5D4F4", "blue_stroke": "#185FA5",
    "blue_title": "#0C447C", "blue_sub": "#185FA5",
    "teal_fill": "#E1F5EE", "teal_box": "#9FE1CB", "teal_stroke": "#0F6E56",
    "teal_title": "#085041", "teal_sub": "#0F6E56",
    "gray_fill": "#F1EFE8", "gray_stroke": "#5F5E5A",
    "gray_title": "#444441", "gray_sub": "#5F5E5A",
    "arrow": "#5F5E5A",
}

f_title = ImageFont.truetype(FONT, 14 * S)
f_sub = ImageFont.truetype(FONT, 12 * S)
f_label = ImageFont.truetype(FONT, 12 * S)
f_mono = ImageFont.truetype(FONT, 12 * S)


def new_canvas(w, h):
    img = Image.new("RGB", (w * S, h * S), "#FFFFFF")
    return img, ImageDraw.Draw(img)


def box(d, x, y, w, h, fill, stroke, title, sub, tc, sc, r=8):
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S],
                        radius=r * S, fill=fill, outline=stroke, width=max(1, int(0.5 * S)))
    cx = (x + w / 2) * S
    if sub:
        d.text((cx, (y + h / 2 - 10) * S), title, font=f_title, fill=tc, anchor="mm")
        d.text((cx, (y + h / 2 + 12) * S), sub, font=f_sub, fill=sc, anchor="mm")
    else:
        d.text((cx, (y + h / 2) * S), title, font=f_title, fill=tc, anchor="mm")


def container(d, x, y, w, h, fill, stroke, label, lc):
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S],
                        radius=16 * S, fill=fill, outline=stroke, width=max(1, int(0.5 * S)))
    d.text(((x + 16) * S, (y + 22) * S), label, font=f_label, fill=lc, anchor="lm")


def varrow(d, x, y1, y2):
    d.line([x * S, y1 * S, x * S, y2 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))
    d.line([(x - 6) * S, (y2 - 9) * S, x * S, y2 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))
    d.line([(x + 6) * S, (y2 - 9) * S, x * S, y2 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, dpi=(192, 192))
    print("saved", path)


# ---------- 图 1 总体架构 ----------
def fig1():
    W, H = 680, 526
    img, d = new_canvas(W, H)
    rows = [
        (40, C["blue_fill"], C["blue_stroke"], "表现层 · ArkUI 声明式页面", C["blue_title"], [
            ("首页 Dashboard", "统计·情绪·趋势"), ("行为录入", "弹窗 + 因子库"),
            ("记录与权益", "列表·券包·任务"), ("图表与文章", "趋势·分类·问答")]),
        (162, C["blue_fill"], C["blue_stroke"], "交互与组件层 · 设计体系", C["blue_title"], [
            ("液态玻璃", "Surface·Light·Dialog"), ("懒加载列表", "LazyForEach"),
            ("主题深色", "跟随系统 + 手动"), ("全局路由", "Navigation")]),
        (284, C["teal_fill"], C["teal_stroke"], "数据层 · LocalStore 单一数据源", C["teal_title"], [
            ("按需查询", "RDB SQL 聚合/分页"), ("派生统计", "stats 唯一出口"),
            ("变更信号", "ecoTick 自增广播"), ("账号隔离", "user_key 列")]),
    ]
    for y, fill, stroke, label, lc, items in rows:
        container(d, 40, y, 600, 100, fill, stroke, label, lc)
        xs = [56, 202, 348, 494]
        for (t, s), x in zip(items, xs):
            box(d, x, y + 34, 130, 56, fill if fill != C["blue_fill"] else C["blue_box"],
                stroke, t, s, lc, C["blue_sub"] if fill == C["blue_fill"] else C["teal_sub"])
    varrow(d, 340, 142, 158)
    varrow(d, 340, 264, 280)
    varrow(d, 340, 386, 402)
    container(d, 40, 406, 600, 100, C["teal_fill"], C["teal_stroke"], "持久层与系统能力", C["teal_title"])
    box(d, 56, 440, 136, 52, C["teal_box"], C["teal_stroke"], "RDB 关系库", "carbon.db", C["teal_title"], C["teal_sub"])
    box(d, 206, 440, 136, 52, C["teal_box"], C["teal_stroke"], "备份槽", "backup_slot", C["teal_title"], C["teal_sub"])
    box(d, 356, 440, 136, 52, C["teal_box"], C["teal_stroke"], "轻量键值", "Preferences", C["teal_title"], C["teal_sub"])
    box(d, 506, 440, 122, 52, C["gray_fill"], C["gray_stroke"], "系统能力", "时钟 · 选图", C["gray_title"], C["gray_sub"])
    save(img, "fig1_architecture.png")


# ---------- 图 2 记录一笔行为 数据流 ----------
def fig2():
    W, H = 680, 484
    img, d = new_canvas(W, H)
    steps = [
        (40, C["blue_box"], C["blue_stroke"], "① 录入弹窗确认", "选择因子 · 输入数量", C["blue_title"], C["blue_sub"]),
        (132, C["blue_box"], C["blue_stroke"], "② 端侧核算", "减排量与积分，口径唯一", C["blue_title"], C["blue_sub"]),
        (224, C["teal_box"], C["teal_stroke"], "③ 写入 RDB 并广播", "INSERT 成功后 ecoTick 自增", C["teal_title"], C["teal_sub"]),
        (316, C["teal_box"], C["teal_stroke"], "④ 失败即上报", "落库失败提示保存失败", C["teal_title"], C["teal_sub"]),
        (408, C["blue_box"], C["blue_stroke"], "⑤ 页面重拉刷新", "派生统计 stats 重算", C["blue_title"], C["blue_sub"]),
    ]
    for y, fill, stroke, t, s, tc, sc in steps:
        box(d, 180, y, 320, 56, fill, stroke, t, s, tc, sc)
    for y1, y2 in [(98, 128), (190, 220), (282, 312), (374, 404)]:
        varrow(d, 340, y1, y2)
    save(img, "fig2_record_flow.png")


# ---------- 图 3 AI 识别链路 ----------
def fig3():
    W, H = 680, 504
    img, d = new_canvas(W, H)
    steps = [
        (40, C["blue_box"], C["blue_stroke"], "① 选图与预处理", "解码限长边 640 → 居中裁剪 224 → 归一化", C["blue_title"], C["blue_sub"]),
        (136, C["teal_box"], C["teal_stroke"], "② MindSpore Lite 推理", "mobilenetv2，主线程零等待", C["teal_title"], C["teal_sub"]),
        (232, C["teal_box"], C["teal_stroke"], "③ 类别聚合映射", "ImageNet 类别 → 碳因子，输出 Top3 依据", C["teal_title"], C["teal_sub"]),
        (328, C["blue_box"], C["blue_stroke"], "④ 用户确认数量", "低置信度引导手动录入，不夸大能力", C["blue_title"], C["blue_sub"]),
        (424, C["teal_box"], C["teal_stroke"], "⑤ 事务化写入本地库", "核算入账，信号广播刷新页面", C["teal_title"], C["teal_sub"]),
    ]
    for y, fill, stroke, t, s, tc, sc in steps:
        box(d, 170, y, 340, 60, fill, stroke, t, s, tc, sc)
    for y1, y2 in [(100, 132), (196, 228), (292, 324), (388, 420)]:
        varrow(d, 340, y1, y2)
    save(img, "fig3_ai_flow.png")


# ---------- 图 4 功能模块图 ----------
def fig4():
    W, H = 680, 374
    img, d = new_canvas(W, H)
    mods = [
        ("碳足迹记录", "27 项因子 · 手动 + AI", C["teal_box"], C["teal_stroke"], C["teal_title"], C["teal_sub"]),
        ("碳核算引擎", "1 kgCO₂e = 10 积分", C["blue_box"], C["blue_stroke"], C["blue_title"], C["blue_sub"]),
        ("积分激励", "任务 · 商城 · 兑换", C["blue_box"], C["blue_stroke"], C["blue_title"], C["blue_sub"]),
        ("权益凭证", "碳惠券 · 徽章 · 证书", C["teal_box"], C["teal_stroke"], C["teal_title"], C["teal_sub"]),
        ("数据统计", "趋势 · 分类 · 月账单", C["teal_box"], C["teal_stroke"], C["teal_title"], C["teal_sub"]),
        ("本地管理", "备份 · 导出 · 深色模式", C["gray_fill"], C["gray_stroke"], C["gray_title"], C["gray_sub"]),
    ]
    xs = [20, 240, 460]
    ys = [40, 170]
    for i, (t, s, fill, stroke, tc, sc) in enumerate(mods):
        x, y = xs[i % 3], ys[i // 3]
        box(d, x, y, 200, 110, fill, stroke, t, s, tc, sc)
    d.rounded_rectangle([20 * S, 310 * S, 660 * S, 354 * S], radius=8 * S,
                        fill=C["teal_fill"], outline=C["teal_stroke"], width=max(1, int(0.5 * S)))
    d.text((340 * S, 332 * S), "统一本地数据底座 · LocalStore（RDB 按需查询 + Preferences 轻量键值）",
           font=f_label, fill=C["teal_title"], anchor="mm")
    for x in [120, 340, 560]:
        d.line([x * S, 280 * S, x * S, 306 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))
        d.line([(x - 6) * S, 297 * S, x * S, 306 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))
        d.line([(x + 6) * S, 297 * S, x * S, 306 * S], fill=C["arrow"], width=max(1, int(1.5 * S)))
    save(img, "fig4_modules.png")


if __name__ == "__main__":
    fig1()
    fig2()
    fig3()
    fig4()
