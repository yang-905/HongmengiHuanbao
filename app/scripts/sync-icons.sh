#!/usr/bin/env bash
#
# 从 Tabler Icons 抽取本项目用到的图标到鸿蒙资源目录
# ------------------------------------------------------------------
# 源：tabler-icons-main/icons/outline/*.svg（24×24 视口，2px 描边，line 风格）
# 目标：app/entry/src/main/resources/base/media/ic_<name>.svg
#
# 命名规则（鸿蒙资源系统强制）：
#   只允许小写字母、数字、下划线；不能以数字开头；不能有 '-'。
#   所以 tools-kitchen-2 → ic_tools_kitchen_2。
#
# 为什么 1:1 拷贝源图标、而不是按语义命名：
#   route 同时被「出行分类」「绿色出行任务」「环保足迹徽章」使用，
#   按语义命名会退化成重复文件。语义映射统一收在 IconMap.ets 里，
#   资源层保持与 Tabler 一一对应，换图标只要改映射。
#
# 用法：
#   ./scripts/sync-icons.sh            # 同步缺失的
#   ./scripts/sync-icons.sh --force    # 全部覆盖重写
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/../tabler-icons-main/icons/outline"
DST="$ROOT/entry/src/main/resources/base/media"
FORCE="${1:-}"

[ -d "$SRC" ] || { echo "✗ 找不到图标库：$SRC"; echo "  请确认 tabler-icons-main/ 在仓库根目录"; exit 1; }
mkdir -p "$DST"

# 本项目用到的 Tabler 图标（62 个，去重后）
ICONS=(
  # —— 27 个碳因子 ——
  walk bike bus train charging-pile car
  bolt droplet flame file-text air-conditioning plug-off
  file-stack bottle tools glass-full shirt device-mobile gift arrows-exchange
  bowl salad tools-kitchen-2 shopping-bag cup forbid trash
  # —— 分类 / 任务 / 徽章 / 权益 ——
  route bulb recycle tools-kitchen check
  seedling plant-2 leaf award trophy trees
  ticket shopping-cart
  # —— 科普文章 ——
  building-bank footsteps refresh building school
  # —— 界面通用 ——
  home clipboard-list book user
  chart-bar chart-pie chart-line target
  books certificate plus camera search star heart eye clock
  # 列表行 / 设置页 / 关于页（CfListRow 的 icon 槽）
  coin ticket shopping-bag settings info-circle edit cloud
  upload receipt flask ruler calculator device-mobile
  # 正文/提示类（2026-10 扫尾：把页面内联 emoji 也换成矢量图）
  leaf world inbox lock photo brain thumb-up alert-triangle
  note pin trending-up calendar wifi download
  # 组件槽位（按钮/统计卡/空态）扫尾
  arrow-up-right robot folder lock-open mail cash moon sun x
  trending-down bike bus
)

# 规范化为「白色描边图 + 无色信息」：
#   1. 剥掉头部的 <!-- tags: ... --> 元数据注释（Tabler 官网用，渲染无用）。
#      注意：整块注释以单独一行的 --> 结束，跳过它之后原样输出。
#   2. currentColor → #FFFFFF。
#      Tabler 用 CSS 变量 currentColor 表示「跟随文字色」，ArkUI 不解析，
#      描边会回落到默认黑色。统一烘焙成纯白后，CfIcon 用颜色矩阵
#      按通道相乘即可精确染成任意目标色（白色 × 目标色 = 目标色）。
#      ⚠️ 副作用：资源本身是白色，浅色底上直接 Image() 会看不见，一律走 CfIcon。
normalize() {
  awk 'BEGIN { inmeta = 0 }
       inmeta == 0 && /^<!--/ { inmeta = 1; next }
       inmeta == 1 && /^-->$/ { inmeta = 2; next }
       inmeta == 2 { print }' "$1" \
    | sed 's/currentColor/#FFFFFF/g'
}

added=0; skipped=0
for name in "${ICONS[@]}"; do
  src="$SRC/$name.svg"
  dst="$DST/ic_${name//-/_}.svg"

  if [ ! -f "$src" ]; then
    echo "✗ 源图标不存在：$name.svg"; exit 1
  fi
  if [ -f "$dst" ] && [ "$FORCE" != "--force" ]; then
    skipped=$((skipped+1)); continue
  fi
  normalize "$src" > "$dst"
  added=$((added+1))
done

echo "✓ 图标同步完成：新增/更新 $added 个，跳过 $skipped 个"
echo "  目标目录：$DST"
echo "  资源引用：\$r('app.media.ic_<name>')   // 横杠已转下划线"
