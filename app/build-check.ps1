# 鸿蒙端构建校验（无需打开 DevEco 图形界面）
# 依赖 DevEco Studio 自带的 node 与 JBR。
# 用法：PowerShell 执行  powershell -ExecutionPolicy Bypass -File build-check.ps1
#   （本机执行策略默认禁止运行 .ps1，故需加 -ExecutionPolicy Bypass）
$ErrorActionPreference = 'Continue'

# 自动探测 DevEco Studio 安装目录
# 注意：管道结果只有一项时会退化为字符串，必须用 @() 强制为数组再取 [0]
$devecoCandidates = @(
    @(
        $env:DEVECO_HOME,
        'C:\Program Files\Huawei\DevEco Studio',
        'D:\anzhi\DevEco Studio',
        'C:\Program Files\Huawei\DevEco Studio 5.0'
    ) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'tools\hvigor\bin\hvigorw.js')) }
)

if (-not $devecoCandidates) {
    Write-Host "❌ 找不到 DevEco Studio（需包含 tools\hvigor\bin\hvigorw.js）"
    Write-Host "   可设置环境变量 DEVECO_HOME 指向安装目录后重试。"
    exit 1
}
$deveco = $devecoCandidates[0]

$env:JAVA_HOME = "$deveco\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$deveco\tools\node;$env:PATH"

Set-Location $PSScriptRoot

# OpenHarmony SDK 路径：优先沿用 local.properties，其次取环境变量，最后用历史构建机的默认路径
if (-not (Test-Path 'local.properties')) {
    $sdkDir = if ($env:OHOS_BASE_SDK_HOME) { $env:OHOS_BASE_SDK_HOME } else { 'D:/openhongm' }
    if (Test-Path $sdkDir) {
        "sdk.dir=$sdkDir" | Set-Content -Path 'local.properties' -Encoding utf8
        Write-Host "已生成 local.properties：sdk.dir=$sdkDir"
    }
}

Write-Host "deveco : $deveco"
Write-Host "node   : $(node --version)"
Write-Host "构建中 …"

$out = & node "$deveco\tools\hvigor\bin\hvigorw.js" `
    --mode module `
    -p product=default `
    -p module=entry@default `
    -p buildMode=debug `
    assembleHap --no-daemon 2>&1

$out | Select-String -Pattern 'ArkTS:ERROR|ArkTS:WARN File|BUILD SUCCESSFUL|BUILD FAILED|ERROR:' |
    ForEach-Object { $_.Line }

if ($out -match 'BUILD SUCCESSFUL') {
    Write-Host ''
    Write-Host '✅ 构建成功'
    Get-ChildItem -Recurse -Filter '*.hap' entry\build -ErrorAction SilentlyContinue |
        Select-Object -First 3 FullName, Length
} else {
    Write-Host ''
    Write-Host '❌ 构建失败，请查看上方 ArkTS:ERROR 明细'
    exit 1
}
