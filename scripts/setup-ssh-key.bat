@echo off
echo ====================================
echo SSH 免密登录配置脚本
echo ====================================
echo.

REM 配置
set SERVER=47.93.17.251
set SSH_USER=root
set SSH_KEY=%USERPROFILE%\.ssh\id_rsa

echo [步骤 1/3] 检查本地 SSH 密钥...
if exist "%SSH_KEY%" (
    echo [OK] SSH 密钥已存在: %SSH_KEY%
) else (
    echo [错误] SSH 密钥不存在，请先运行密钥生成命令
    pause
    exit /b 1
)

echo.
echo [步骤 2/3] 测试 SSH 连接...
echo [提示] 如果提示输入密码，说明免密登录尚未生效
echo.

ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no %SSH_USER%@%SERVER% "echo '[OK] SSH 连接成功' && ls -la ~/.ssh/authorized_keys"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [步骤 3/3] 验证免密登录...
    ssh -i "%SSH_KEY%" -o BatchMode=yes -o ConnectTimeout=5 %SSH_USER%@%SERVER% "echo '✅ 免密登录配置成功！'"
    
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo ====================================
        echo ✅ SSH 免密登录已成功配置！
        echo ====================================
        echo.
        echo 现在你可以运行 db-tunnel.bat 无需输入密码
    ) else (
        echo.
        echo [警告] 免密登录可能未完全生效
        echo [建议] 请检查服务器 SSH 配置:
        echo         1. 确保 /etc/ssh/sshd_config 中 PubkeyAuthentication 为 yes
        echo         2. 确保 ~/.ssh/authorized_keys 权限为 600
        echo         3. 确保 ~/.ssh 目录权限为 700
    )
) else (
    echo.
    echo [错误] SSH 连接失败
    echo [建议] 请检查网络连接和服务器状态
)

echo.
pause
