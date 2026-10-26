# 鸿蒙端构建校验（无需打开 DevEco 图形界面）
# 依赖 DevEco Studio 自带的 node 与 JBR。
# 用法：PowerShell 执行  powershell -File build-check.ps1
$ErrorActionPreference = 'Continue'

$deveco = 'D:\anzhi\DevEco Studio'
$env:JAVA_HOME = "$deveco\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$deveco\tools\node;$env:PATH"

Set-Location $PSScriptRoot

Write-Host "node: $(node --version)"
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