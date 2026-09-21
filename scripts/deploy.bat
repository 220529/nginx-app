@echo off
chcp 65001 >nul
setlocal

pushd "%~dp0.."

echo.
echo ========================================
echo   nginx-app 共享网关 Tag 发布
echo ========================================
echo.

for /f "tokens=1,* delims==" %%A in (config\gateway.env) do (
    if "%%A"=="GATEWAY_TAG_PREFIX" set "TAG_PREFIX=%%B"
)
if not defined TAG_PREFIX (
    echo config\gateway.env 中缺少 GATEWAY_TAG_PREFIX
    popd
    exit /b 1
)

for /f "tokens=*" %%i in ('git branch --show-current') do set "BRANCH_NAME=%%i"
for /f "tokens=1 delims=/" %%i in ("%TAG_PREFIX%") do set "TAG_BRANCH=%%i"
if /i not "%BRANCH_NAME%"=="%TAG_BRANCH%" (
    echo 当前分支 %BRANCH_NAME% 不能创建生产 Tag，要求分支为 %TAG_BRANCH%
    popd
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd/HH-mm-ss'"`) do set STAMP=%%i
set TAG=%TAG_PREFIX%/%STAMP%

echo 即将创建并推送 Tag:
echo %TAG%
set /p CONFIRM="确认部署? (Y/n): "

if /i "%CONFIRM%"=="n" (
    echo 已取消
    popd
    exit /b 0
)

git tag "%TAG%"
if errorlevel 1 (
    popd
    exit /b 1
)

git push origin "%TAG%"
if errorlevel 1 (
    popd
    exit /b 1
)

echo.
echo Tag 已推送，GitHub Actions 将开始部署共享网关配置。
echo 查看进度: https://github.com/220529/nginx-app/actions
popd
