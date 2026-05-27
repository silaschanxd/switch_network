# 网络配置切换 - 打包安装脚本
# 使用前请先安装 Inno Setup: winget install "Inno Setup" 或 https://jrsoftware.org/isdl.php

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$releaseDir = "$root\build\windows\x64\runner\Release"
$manifestFile = "$PSScriptRoot\admin.manifest"
$issFile = "$PSScriptRoot\setup.iss"
$mt = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\mt.exe"

Write-Host "=== 1. 构建 Release 版本 ===" -ForegroundColor Cyan
Set-Location $root
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "构建失败" }

Write-Host "=== 2. 嵌入管理员权限清单 ===" -ForegroundColor Cyan
& $mt -manifest $manifestFile -outputresource:"$releaseDir\switch_network.exe"
if ($LASTEXITCODE -ne 0) { throw "嵌入清单失败" }
Write-Host "  管理员权限清单已嵌入" -ForegroundColor Green

Write-Host "=== 3. 查找 Inno Setup ===" -ForegroundColor Cyan
$iscc = Get-ChildItem "C:\Program Files*\Inno Setup*\ISCC.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $iscc) {
    Write-Warning "未找到 Inno Setup，请先安装:"
    Write-Warning "  winget install "Inno Setup""
    Write-Warning "  或 https://jrsoftware.org/isdl.php"
    Write-Host ""
    Write-Host "安装完成后，手动编译安装脚本:" -ForegroundColor Yellow
    Write-Host "  ISCC.exe $issFile" -ForegroundColor White
    exit 1
}

Write-Host "  找到: $iscc" -ForegroundColor Green

Write-Host "=== 4. 编译安装包 ===" -ForegroundColor Cyan
& $iscc $issFile
if ($LASTEXITCODE -ne 0) { throw "编译安装包失败" }

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Cyan
$outputDir = "$PSScriptRoot\output"
if (Test-Path $outputDir) {
    $installer = Get-ChildItem "$outputDir\*.exe" | Select-Object -First 1
    if ($installer) {
        Write-Host "安装包已生成: $($installer.FullName)" -ForegroundColor Green
        Write-Host "大小: $('{0:N1} MB' -f ($installer.Length / 1MB))" -ForegroundColor Green
    }
}
