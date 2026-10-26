#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成《一触青绿设计方案》所需的 6 张图（PNG, 200dpi）
  图1 系统架构   图2 整体功能架构   图3 软件架构
  图4 业务流程   图5 接口对接       图6 硬件架构
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib import font_manager as fm

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'diagrams')
os.makedirs(OUT, exist_ok=True)

for fp in ['C:/Windows/Fonts/simhei.ttf', 'C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simsun.ttc']:
    if os.path.exists(fp):
        try:
            fm.fontManager.addfont(fp)
        except Exception:
            pass
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['axes.unicode_minus'] = False

INK = '#22333B'; GRAY = '#6B7A80'; LINE = '#9FB0B5'
GREEN = '#2E9E7B'; GREEN_D = '#1F7A5F'; GREEN_L = '#E3F4EE'
TEAL = '#3FA7B8'; TEAL_L = '#E4F3F6'
ORANGE = '#DE9A4E'; ORANGE_L = '#FBF0DE'
RED = '#D96A5F'; RED_L = '#FBE9E6'
BLUE = '#5B8DEF'; BLUE_L = '#EAF0FD'
PURPLE = '#8B7BD8'; PURPLE_L = '#F0EDFB'


def new_ax(title):
    fig, ax = plt.subplots(figsize=(10, 6.4))
    ax.set_xlim(0, 100); ax.set_ylim(0, 100); ax.axis('off')
    ax.text(50, 98.2, title, ha='center', va='center', fontsize=14,
            fontweight='bold', color=INK)
    return fig, ax


def zone(ax, x, y, w, h, title, fc='#FAFCFC', ec=LINE, fs=10.5):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.6,rounding_size=1.4',
                                fc=fc, ec=ec, lw=1.1, ls=(0, (5, 3)), zorder=1))
    ax.text(x + w / 2, y + h - 2.0, title, ha='center', va='top', fontsize=fs,
            fontweight='bold', color=INK, zorder=3)


def box(ax, x, y, w, h, text, fc, ec, fs=9.5, tc=INK, bold=False, ls='-', lw=1.3, z=3):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.35,rounding_size=0.9',
                                fc=fc, ec=ec, lw=lw, ls=ls, zorder=z))
    ax.text(x + w / 2, y + h / 2, text, ha='center', va='center', fontsize=fs,
            color=tc, fontweight='bold' if bold else 'normal', zorder=z + 1,
            linespacing=1.55)


def arrow(ax, p1, p2, text='', color=GRAY, fs=8.2, ls='-', rad=0.0, lw=1.5, dx=0, dy=1.4):
    ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle='-|>', mutation_scale=13,
                                 color=color, lw=lw, ls=ls,
                                 connectionstyle='arc3,rad=%.2f' % rad, zorder=2))
    if text:
        ax.text((p1[0] + p2[0]) / 2 + dx, (p1[1] + p2[1]) / 2 + dy, text, ha='center',
                va='center', fontsize=fs, color=color, zorder=5,
                bbox=dict(fc='white', ec='none', pad=1.1))


def note_bar(ax, x, y, w, h, text, fc='#F4F8F9', ec=LINE, fs=8.8):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.4,rounding_size=1.0',
                                fc=fc, ec=ec, lw=1.0, ls=(0, (4, 3)), zorder=1))
    ax.text(x + w / 2, y + h / 2, text, ha='center', va='center', fontsize=fs,
            color=INK, zorder=3, linespacing=1.6)


def save(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print('saved', path)


# ================= 图1 系统架构 =================
def fig1():
    fig, ax = new_ax('图1  一触青绿系统架构（四端一体）')
    zone(ax, 2, 12, 18, 80, '用户设备层')
    zone(ax, 24, 12, 34, 80, '鸿蒙端应用（HAP）')
    zone(ax, 62, 12, 36, 80, '云服务端')
    # 设备
    box(ax, 4, 66, 14, 18, 'HarmonyOS\n手机 / 平板\n（API 24）', GREEN_L, GREEN, bold=True)
    box(ax, 4, 46, 14, 14, '可扩展终端\n手表 / 车机 / TV', '#FFFFFF', GRAY, ls=(0, (4, 3)))
    box(ax, 4, 28, 14, 12, '软总线\n近场互联', TEAL_L, TEAL)
    note_bar(ax, 4, 15, 14, 9, '多账号\n本地隔离')
    # 端侧分层
    box(ax, 26, 72, 30, 11, '页面层\nIndex 主框架 + 30 余个 NavDestination', BLUE_L, BLUE, fs=8.8)
    box(ax, 26, 59, 30, 11, 'UI 组件层\nGlassLight 液态玻璃 · AppleMotion 动效', PURPLE_L, PURPLE, fs=8.8)
    box(ax, 26, 46, 30, 11, '业务数据层\nAccountStore · LocalStore · MockStore', GREEN_L, GREEN, fs=8.8)
    box(ax, 26, 33, 30, 11, '网络层\nHttpClient · ApiService · 离线同步队列', ORANGE_L, ORANGE, fs=8.8)
    note_bar(ax, 26, 16, 30, 12, '系统时钟 AppClock 本地校准\nPreferences 持久化 · 主题换血')
    # 服务端
    box(ax, 64, 74, 32, 9, 'Nginx 网关（80 / 443）', TEAL_L, TEAL)
    box(ax, 64, 60, 32, 12, 'RuoYi-Vue 3.8.7\nSpring Boot · JDK 11（:8089）', GREEN_L, GREEN, bold=True, fs=9)
    box(ax, 64, 46, 15, 11, 'MySQL 8\n（:3306）', ORANGE_L, ORANGE, fs=8.8)
    box(ax, 81, 46, 15, 11, 'Redis\n（:6379）', ORANGE_L, ORANGE, fs=8.8)
    box(ax, 64, 32, 32, 10, '管理端 admin/（Vue）· 运营后台', BLUE_L, BLUE, fs=8.8)
    box(ax, 64, 18, 32, 10, '数据库脚本 db/（建库 + 种子）', '#FFFFFF', GRAY, fs=8.8, ls=(0, (4, 3)))
    # 箭头
    arrow(ax, (18, 75), (26, 77), '本地渲染', color=GREEN_D)
    arrow(ax, (41, 33), (64, 79), 'HTTPS + App-Token\n（离线时批量补传）', color=ORANGE, rad=-0.12, dy=0)
    arrow(ax, (80, 74), (80, 72), '', color=TEAL)
    arrow(ax, (72, 60), (72, 57), '', color=GREEN_D)
    arrow(ax, (88, 60), (88, 57), '', color=GREEN_D)
    arrow(ax, (80, 60), (80, 42), '运维管理', color=BLUE, rad=0.0, dx=4.5, dy=0)
    arrow(ax, (80, 18), (72, 46), '初始化', color=GRAY, ls=(0, (4, 3)), rad=0.15, dx=3.5)
    note_bar(ax, 2, 2, 96, 8, '开发构建链：DevEco Studio（API 24 SDK）· hvigor assembleHap · 四端仓库 app / server / admin / db / docs')
    save(fig, 'fig1_system.png')


# ================= 图2 整体功能架构 =================
def fig2():
    fig, ax = new_ax('图2  整体功能架构（十大模块）')
    box(ax, 33, 86, 34, 9, '一触青绿 · 碳普惠应用', GREEN, GREEN_D, fs=12, tc='white', bold=True)
    mods = [
        ('① 碳足迹记录', '27 项行为因子库\n手动录入 · AI 拍照识别'),
        ('② 数据看板', '仪表盘 · 趋势图\n分类分析'),
        ('③ 积分与任务', '任务中心 · 积分明细\n月度账单'),
        ('④ 积分商城', '权益兑换 · 确认弹窗\n兑换记录'),
        ('⑤ 碳惠券包', '我的券 · 7 天有效期\n核销二维码'),
        ('⑥ 证书与徽章', '植树证书 · 徽章墙\n结构化判定'),
        ('⑦ 科普资讯', '文章列表 / 详情\n问答 · 点赞收藏'),
        ('⑧ 家庭与设置', '家庭账户 · 深浅主题\n备份恢复 · 导出报告'),
        ('⑨ AI 视觉识别', '票据识别\n智能填报'),
        ('⑩ 超级终端', '跨设备同步（LWW）\n智慧服务提醒'),
    ]
    cols = [GREEN_L, TEAL_L, ORANGE_L, BLUE_L, PURPLE_L, GREEN_L, TEAL_L, ORANGE_L, BLUE_L, PURPLE_L]
    ecs = [GREEN, TEAL, ORANGE, BLUE, PURPLE, GREEN, TEAL, ORANGE, BLUE, PURPLE]
    xs = [2 + i * 20 for i in range(5)]
    for i, (t, s) in enumerate(mods):
        r, c = divmod(i, 5)
        x, y = xs[c], 58 - r * 24
        box(ax, x, y, 18, 20, t + '\n' + s, cols[i], ecs[i], fs=8.6, bold=False)
        ax.text(x + 9, y + 17.2, t, ha='center', va='center', fontsize=9.2,
                fontweight='bold', color=ecs[i], zorder=5)
        arrow(ax, (50, 86), (x + 9, y + 20), '', color=LINE, rad=0.08, lw=1.0)
    # 支撑体系
    zone(ax, 2, 6, 96, 20, '底层支撑体系（被全部模块复用）', fc='#F7FAFA')
    box(ax, 5, 8.5, 21, 11, '账号系统\nAccountStore', GREEN_L, GREEN, fs=8.8)
    box(ax, 29, 8.5, 21, 11, '本地数据仓库\nLocalStore / MockStore', TEAL_L, TEAL, fs=8.8)
    box(ax, 53, 8.5, 21, 11, '主题 · 液态玻璃 · 动效\nTheme / GlassLight / AppleMotion', PURPLE_L, PURPLE, fs=8.4)
    box(ax, 77, 8.5, 18, 11, '系统时钟 · 路由\nAppClock / AppRouter', ORANGE_L, ORANGE, fs=8.8)
    arrow(ax, (50, 6), (50, 58), '', color=LINE, ls=(0, (4, 3)), lw=1.0)
    save(fig, 'fig2_features.png')


# ================= 图3 软件架构 =================
def fig3():
    fig, ax = new_ax('图3  端侧软件架构（分层视图）')
    layers = [
        ('L1 应用表现层', 'SplashPage · OnboardingPage · LoginGate · Index（Tabs 主框架）\n30 余个 NavDestination 二级页面', BLUE_L, BLUE),
        ('L2 UI 组件层', 'Theme（主题与 Biz 业务常量）· GlassLight（液态玻璃）· AppleMotion（动效语言）\nGlassDialog · Components · GlassSurface · Toast · LazyList', PURPLE_L, PURPLE),
        ('L3 业务数据层', 'AccountStore（账号/会话/资料）· LocalStore（记录/券/统计）\nMockStore（因子库/种子）· EcoMoodState（碳情绪）· SyncStore（跨设备合并）', GREEN_L, GREEN),
        ('L4 网络层', 'HttpClient · ApiService · DataSource\nApp-Token 鉴权 · 离线同步队列 · 幂等上送', ORANGE_L, ORANGE),
        ('L5 基础设施层', 'AppClock（系统时钟校准）· AppConfig · AppRouter + PageMap（全局路由）\nPreferences 持久化（内存权威态 + best-effort 落盘）', TEAL_L, TEAL),
    ]
    y = 80
    for name, detail, fc, ec in layers:
        box(ax, 8, y, 70, 13, name, ec, ec, fs=10, tc='white', bold=True)
        box(ax, 8, y - 11.5, 70, 11, detail, fc, ec, fs=8.4)
        y -= 26.5
    # 平台能力侧栏
    ax.add_patch(FancyBboxPatch((80.5, 22), 15, 71, boxstyle='round,pad=0.5,rounding_size=1.2',
                                fc='#22333B', ec='#22333B', zorder=2))
    ax.text(88, 57.5, '平台能力\nArkUI · ArkTS（API 24）\nPreferences 首选项\n分布式软总线\nStage 模型',
            ha='center', va='center', fontsize=9, color='white', rotation=90, zorder=4, linespacing=2.0)
    for yy in (86.5, 60, 33.5):
        arrow(ax, (78, yy), (80.5, yy), '', color=GRAY, lw=1.0)
    note_bar(ax, 2, 4, 96, 10, '分层原则：单向依赖（表现 → 组件 → 数据 → 网络 → 设施）· 内存权威态 + 失败不阻塞主流程\n多账号数据隔离：存储键 = 业务键 @ 账号名（命名空间切换）')
    save(fig, 'fig3_software.png')


# ================= 图4 业务流程 =================
def fig4():
    fig, ax = new_ax('图4  核心业务流程')
    box(ax, 2, 88, 20, 8, '启动应用\nSplashPage', BLUE_L, BLUE, fs=9)
    box(ax, 27, 88, 20, 8, '新手引导\nOnboardingPage', BLUE_L, BLUE, fs=9)
    box(ax, 52, 88, 22, 8, '登录 / 注册\nLoginGate', BLUE_L, BLUE, fs=9)
    box(ax, 79, 88, 19, 8, '注册闸门\n强制完善资料', ORANGE_L, ORANGE, fs=8.8, bold=True)
    box(ax, 30, 74, 40, 8, '主框架 Tabs：首页 · 积分 · 碳惠券包 · 我的', GREEN, GREEN_D, fs=10, tc='white', bold=True)
    box(ax, 2, 56, 22, 11, '记录低碳行为\n27 项因子 · 手动录入\nAI 拍照识别', TEAL_L, TEAL, fs=8.8)
    box(ax, 28, 56, 22, 11, '减排核算\nkg = 因子值 × 数量\n（保留 3 位小数）', GREEN_L, GREEN, fs=8.8, bold=True)
    box(ax, 54, 56, 22, 11, '积分折算\npts = kg × 10\n（减排 > 0 保底 1 分）', GREEN_L, GREEN, fs=8.8, bold=True)
    box(ax, 80, 56, 18, 11, '本地存储\n命名空间 @账号\nPreferences 落盘', ORANGE_L, ORANGE, fs=8.4)
    box(ax, 2, 32, 30, 18, '积分商城\n兑换权益 → 生成碳惠券（7 天有效）\n使用 → 核销二维码（ASCII 单行）\n→ 凭证可回看', BLUE_L, BLUE, fs=8.8)
    box(ax, 35, 32, 30, 18, '植树认养\n200 积分 = 1 棵树\n→ 发放植树证书\n（口径：仅认养进证书）', GREEN_L, GREEN, fs=8.8)
    box(ax, 68, 32, 30, 18, '数据看板\n累计 / 今日 / 本月 → 等级 5 档\n徽章结构化判定 · 趋势图\n月账单 · 导出报告', TEAL_L, TEAL, fs=8.8)
    note_bar(ax, 2, 16, 96, 12, '账号体系：注册成功即零帧锁死主框架（闸门）→ 资料真实上屏后才解锁；注销 / 切换账号整树重建\n→ LocalStore.switchUser 切换数据命名空间 → 多账号数据隔离，预览器与真机双口径兜底')
    note_bar(ax, 2, 3, 96, 10, '碳情绪 EcoMoodState：记录变化即重算档位，全应用配色（登录页 / 背景 / 图表）随低碳表现联动换色')
    # 箭头
    arrow(ax, (22, 92), (27, 92), '', color=BLUE)
    arrow(ax, (47, 92), (52, 92), '', color=BLUE)
    arrow(ax, (74, 92), (79, 92), '新用户', color=ORANGE, dy=1.6)
    arrow(ax, (63, 88), (50, 82), '登录成功', color=GREEN_D, rad=0.1, dx=-4, dy=0)
    arrow(ax, (88, 88), (66, 82), '', color=ORANGE, rad=-0.1)
    arrow(ax, (40, 74), (13, 67), '', color=TEAL, rad=0.12)
    arrow(ax, (24, 61.5), (28, 61.5), '', color=GREEN_D)
    arrow(ax, (50, 61.5), (54, 61.5), '', color=GREEN_D)
    arrow(ax, (76, 61.5), (80, 61.5), '', color=ORANGE)
    arrow(ax, (89, 56), (24, 50), '', color=GRAY, rad=0.08)
    arrow(ax, (89, 56), (50, 50), '', color=GRAY, rad=0.05)
    arrow(ax, (89, 56), (83, 50), '', color=GRAY)
    save(fig, 'fig4_flow.png')


# ================= 图5 接口对接 =================
def fig5():
    fig, ax = new_ax('图5  接口对接（端侧与若依服务端）')
    lanes = [(18, '鸿蒙端 App', BLUE), (50, '服务端 RuoYi :8089', GREEN), (82, '数据层 MySQL / Redis', ORANGE)]
    for x, name, c in lanes:
        box(ax, x - 9, 88, 18, 7, name, c, c, fs=9.5, tc='white', bold=True)
        ax.plot([x, x], [30, 88], color=LINE, lw=1.1, ls=(0, (4, 3)), zorder=1)
    msgs = [
        (84, 18, 50, 'POST /appLogin {deviceId} —— 匿名登录', BLUE),
        (78, 50, 18, '返回 {token, userId, level} —— App-Token', GREEN),
        (72, 18, 50, 'GET /behavior/factorList [App-Token] —— 拉取 27 项因子', BLUE),
        (66, 18, 50, 'POST /record/add {clientRecordId, itemId, amount}', BLUE),
        (60, 50, 82, 'INSERT（按 clientRecordId 幂等去重）', GREEN),
        (54, 18, 50, '离线补传 POST /record/syncBatch（批量队列）', BLUE),
        (48, 50, 18, '返回 {inserted, total}；401 则重新匿名登录', GREEN),
        (42, 18, 50, 'GET /record/list · /coupon/list · /certificate/list', BLUE),
    ]
    for y, x1, x2, t, c in msgs:
        arrow(ax, (x1, y), (x2, y), t, color=c, fs=8.0, dy=1.5)
    note_bar(ax, 2, 6, 96, 22,
             '鉴权口径：App-Token（匿名设备登录，userId 由服务端按 Token 注入，端侧不可伪造归属）\n'
             '幂等口径：clientRecordId = 端侧 UUID，服务端按「用户 + 该 ID」去重，断网重传不产生重复记录\n'
             '同步口径：离线本地队列 → 联网批量上送，跨设备合并按 clientRecordId + updateTime（LWW）\n'
             '部署口径：端侧当前为单机演示口径（Preferences 本地持久化），网络层完整保留，四端可联调',
             fs=8.6)
    save(fig, 'fig5_api.png')


# ================= 图6 硬件架构 =================
def fig6():
    fig, ax = new_ax('图6  硬件架构与部署')
    zone(ax, 2, 14, 26, 78, '用户终端')
    zone(ax, 34, 14, 16, 78, '网络')
    zone(ax, 56, 14, 42, 78, '云服务端（Linux）')
    box(ax, 4, 66, 22, 16, '手机 / 平板\nHarmonyOS · API 24\n（应用主载体）', GREEN_L, GREEN, bold=True, fs=9)
    box(ax, 4, 48, 22, 12, '手表 / 车机 / TV\n（扩展终端）', '#FFFFFF', GRAY, ls=(0, (4, 3)), fs=9)
    box(ax, 4, 30, 22, 12, '开发机（Windows）\nDevEco Studio · hvigor', BLUE_L, BLUE, fs=9)
    note_bar(ax, 4, 17, 22, 9, '软总线近场互联\n（超级终端）')
    box(ax, 36, 62, 12, 10, 'WiFi', TEAL_L, TEAL, fs=9.5)
    box(ax, 36, 48, 12, 10, '4G/5G', TEAL_L, TEAL, fs=9)
    box(ax, 36, 34, 12, 10, '以太网', TEAL_L, TEAL, fs=9)
    box(ax, 58, 72, 38, 10, 'Nginx（80 / 443）反向代理 · 静态资源', TEAL_L, TEAL, fs=9)
    box(ax, 58, 57, 38, 12, 'RuoYi-Admin :8089\nJDK 11 · Spring Boot · carbon 业务模块', GREEN_L, GREEN, bold=True, fs=9)
    box(ax, 58, 42, 18, 11, 'MySQL 8\n:3306 业务库', ORANGE_L, ORANGE, fs=8.8)
    box(ax, 78, 42, 18, 11, 'Redis\n:6379 缓存', ORANGE_L, ORANGE, fs=8.8)
    box(ax, 58, 26, 38, 11, 'db/ 初始化脚本\nry-base.sql → carbon.sql → quartz.sql', '#FFFFFF', GRAY, fs=8.6, ls=(0, (4, 3)))
    box(ax, 58, 16, 38, 8, '管理端 admin/（Vue）· 运营人员', BLUE_L, BLUE, fs=8.8)
    arrow(ax, (15, 66), (15, 60), '', color=GRAY, ls=(0, (4, 3)))
    arrow(ax, (26, 70), (36, 67), 'WiFi / 移动网络', color=TEAL, dy=1.6)
    arrow(ax, (48, 67), (58, 77), '', color=TEAL, rad=-0.1)
    arrow(ax, (48, 53), (58, 63), '', color=TEAL, rad=-0.08)
    arrow(ax, (77, 72), (77, 69), '', color=GREEN_D)
    arrow(ax, (67, 57), (67, 53), '', color=ORANGE)
    arrow(ax, (87, 57), (87, 53), '', color=ORANGE)
    arrow(ax, (70, 26), (67, 42), '建库', color=GRAY, ls=(0, (4, 3)), rad=0.12, dx=3)
    arrow(ax, (67, 57), (67, 24), '接口', color=BLUE, rad=0.0, dx=3.2, dy=0)
    note_bar(ax, 2, 2, 96, 10, '两种部署形态：① 演示形态 = 单机端侧（数据仅存本机 Preferences，零依赖开箱即用）\n'
                              '② 完整形态 = 四端联调（鸿蒙端 + Nginx + 若依后端 + MySQL/Redis），支持云端同步与运营后台')
    save(fig, 'fig6_hardware.png')


if __name__ == '__main__':
    fig1(); fig2(); fig3(); fig4(); fig5(); fig6()
    print('ALL DIAGRAMS DONE')
