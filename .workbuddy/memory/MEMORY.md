# 弘梦·碳环保 —— 工程长期笔记

## 工程结构
- DevEco 工程根目录是 `app/`（不是仓库根 `D:/11/HongmengiHuanbao`）；含 `AppScope/`、`entry/`、`hvigor/`、`signature/`
- 参照工程：`D:/11/carbon-master/app`（同源、构建正常，可用于对比配置）

## 构建环境（固定事实）
- DevEco Studio **6.1.1.418** → `C:\Program Files\Huawei\DevEco Studio`
  - 自带 node v18、JBR jdk 21
- OpenHarmony SDK → **`D:\openhongm`**（版本化布局 `<sdk.dir>/<api>/{ets,js,native,previewer,toolchains}`）
  - 只有 `24` 是完整可用的（ets/js/native/previewer/toolchains 齐全，apiVersion 24）
  - `12/` 组件不全，`23/`、`26.0.0/` 是空目录
  - ⚠️ DevEco 自带的 `sdk/default/openharmony` 是 HarmonyOS 布局，OpenHarmony 模式下**不能用**
- 签名材料：`app/signature/`（OpenHarmony 类型，keystore 密码硬编码在 build-profile.json5）

## 构建命令
```bash
# CLI（Git Bash）
export JAVA_HOME="C:/Program Files/Huawei/DevEco Studio/jbr"
export PATH="$JAVA_HOME/bin:C:/Program Files/Huawei/DevEco Studio/tools/node:$PATH"
cd D:/11/HongmengiHuanbao/app
node "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
  --mode module -p product=default -p module=entry@default -p buildMode=debug \
  assembleHap --no-daemon
```
```powershell
# 脚本（推荐）
powershell -ExecutionPolicy Bypass -File D:\11\HongmengiHuanbao\app\build-check.ps1
```
产物：`app/entry/build/default/outputs/default/entry-default-signed.hap`

## 关键约定与坑
1. `runtimeOS: "OpenHarmony"` 时 `compileSdkVersion`/`targetSdkVersion` **必须是数字**（API>=10），
   写成 `'26.0.0'` 会让 product 校验失败 → 报 "The target can not be empty ... applyToProducts"（**提示具有误导性**）
2. `app/local.properties` 必须有 `sdk.dir=D:/openhongm`；该文件被 .gitignore，克隆后需重建
3. PowerShell 5.1 读 .ps1：文件必须带 **UTF-8 BOM**，否则中文注释被按 GBK 解析直接语法报错
4. PowerShell：`Where-Object` 只返回一项时结果退化成字符串，`[0]` 取到的是**首字符**，必须用 `@()` 包一层
5. `app/build-local.sh` 是给 Linux 构建机（command-line-tools 5.1.0 + API 23）用的临时降级脚本，本机不适用
