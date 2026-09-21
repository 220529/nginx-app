@echo off
chcp 65001 >nul
setlocal

echo.
echo ========================================
echo   nginx-app HTTPS 配置部署
echo ========================================
echo.

for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd/HH-mm-ss'"`) do set STAMP=%%i
set TAG=master/nginx-app/%STAMP%

echo 即将创建并推送 Tag:
echo %TAG%
set /p CONFIRM="确认部署? (Y/n): "

if /i "%CONFIRM%"=="n" (
    echo 已取消
    exit /b 0
)

git tag "%TAG%"
if errorlevel 1 exit /b 1

git push origin "%TAG%"
if errorlevel 1 exit /b 1

echo.
echo Tag 已推送，GitHub Actions 将开始部署 HTTPS 配置。
echo 查看进度: https://github.com/220529/nginx-app/actions
