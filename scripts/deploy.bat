@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ========================================
echo   nginx-app 部署脚本
echo ========================================
echo.

:: 获取最新 tag
for /f "tokens=*" %%i in ('git describe --tags --abbrev^=0 2^>nul') do set LATEST_TAG=%%i

if "%LATEST_TAG%"=="" (
    set LATEST_TAG=v0.0.0
    echo 当前没有 tag，将从 v0.0.1 开始
) else (
    echo 当前最新 tag: %LATEST_TAG%
)

:: 解析版本号
for /f "tokens=1,2,3 delims=." %%a in ("%LATEST_TAG:~1%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set /a PATCH=%%c+1
)

set SUGGESTED_TAG=v%MAJOR%.%MINOR%.%PATCH%

echo.
set /p NEW_TAG="输入新 tag (回车使用 %SUGGESTED_TAG%): "
if "%NEW_TAG%"=="" set NEW_TAG=%SUGGESTED_TAG%

echo.
echo 即将创建并推送 tag: %NEW_TAG%
set /p CONFIRM="确认部署? (Y/n): "

if /i "%CONFIRM%"=="n" (
    echo 已取消
    exit /b 0
)

echo.
echo 创建 tag: %NEW_TAG%
git tag %NEW_TAG%

echo 推送 tag...
git push origin %NEW_TAG%

echo.
echo ✅ 完成! GitHub Actions 将自动开始部署
echo 查看进度: https://github.com/220529/nginx-app/actions
