#!/usr/bin/env bash
#
# 在 Linux 命令行编译 HAP（不需要 DevEco Studio 6.x）
#
# 背景：
#   项目原本按 DevEco Studio 6.1 配置（modelVersion 6.1.1 / compileSdkVersion 26.0.0），
#   而本机只有 OpenHarmony command-line-tools 5.1.0（hvigor 5.18.5）与 API 23 SDK。
#   hvigor 5.x 的 schema 只认整数 compileSdkVersion，直接构建会报 00303038。
#
# 做法：
#   临时把 modelVersion 降到 5.1.0、SDK 版本降到 23，构建完成后用 trap 原样还原，
#   仓库里的配置文件不会被永久改动。
#
# 用法：
#   ./build-local.sh              # 默认 assembleHap
#   ./build-local.sh clean        # 清理产物
#
set -euo pipefail

cd "$(dirname "$0")"

CLT="${CLT_HOME:-/home/admin/command-line-tools}"
SDK_ROOT="${OHOS_SDK_HOME:-/home/admin/setup-ohos-sdk/linux}"
SDK_API="${OHOS_SDK_API:-23}"
HVIGORW="$CLT/bin/hvigorw"

# ---------- 环境检查 ----------
[ -x "$HVIGORW" ] || { echo "✗ 找不到 hvigorw：$HVIGORW"; echo "  用 CLT_HOME=<command-line-tools 路径> 指定"; exit 1; }
[ -d "$SDK_ROOT/$SDK_API/ets" ] || { echo "✗ 找不到 API $SDK_API SDK：$SDK_ROOT/$SDK_API/ets"; echo "  用 OHOS_SDK_HOME / OHOS_SDK_API 指定"; exit 1; }

# ---------- 备份将要改写的配置 ----------
BACKUP="$(mktemp -d)"
FILES=(build-profile.json5 hvigor/hvigor-config.json5 oh-package.json5 local.properties)
restore() {
  for f in "${FILES[@]}"; do
    [ -f "$BACKUP/$f" ] && cp "$BACKUP/$f" "$f"
  done
  rm -rf "$BACKUP"
}
trap restore EXIT

for f in "${FILES[@]}"; do
  mkdir -p "$BACKUP/$(dirname "$f")"
  [ -f "$f" ] && cp "$f" "$BACKUP/$f"
done

# ---------- 临时降级 ----------
python3 - "$SDK_API" <<'PY'
import io, sys
api = sys.argv[1]

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8').write(s)

patch('build-profile.json5', [
    ("'26.0.0'", api),
    ('"compatibleSdkVersion": 24', f'"compatibleSdkVersion": {api}'),
])
patch('hvigor/hvigor-config.json5', [('"modelVersion": "6.1.1"', '"modelVersion": "5.1.0"')])
patch('oh-package.json5', [('"modelVersion": "6.1.1"', '"modelVersion": "5.1.0"')])
PY

printf 'sdk.dir=%s\n' "$SDK_ROOT" > local.properties

# ---------- 构建 ----------
echo "▸ SDK      : $SDK_ROOT/$SDK_API"
echo "▸ hvigor   : $("$CLT/tool/node/bin/node" -p "require('$CLT/hvigor/hvigor/package.json').version" 2>/dev/null || echo unknown)"
echo "▸ 任务     : ${1:-assembleHap}"
echo

"$HVIGORW" "${1:-assembleHap}" --no-daemon

# ---------- 结果 ----------
OUT="entry/build/default/outputs/default"
if [ -f "$OUT/entry-default-signed.hap" ]; then
  echo
  echo "✓ 产物：$(pwd)/$OUT/entry-default-signed.hap"
  echo "  大小：$(du -h "$OUT/entry-default-signed.hap" | cut -f1)"
  echo "  时间：$(date -r "$OUT/entry-default-signed.hap" '+%Y-%m-%d %H:%M:%S')"
fi
echo "（构建期间临时降级的配置已自动还原）"
