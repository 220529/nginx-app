@echo off
echo ====================================
echo SSH 权限修复脚本
echo ====================================
echo.
echo 此脚本将修复服务器端的 SSH 密钥权限
echo 需要输入一次服务器密码
echo.
pause

set SERVER=47.93.17.251
set SSH_USER=root

echo.
echo [步骤 1/2] 修复 .ssh 目录和文件权限...
ssh %SSH_USER%@%SERVER% "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo '[OK] 权限已修复'"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [步骤 2/2] 测试免密登录...
    ssh -i "%USERPROFILE%\.ssh\id_rsa" -o BatchMode=yes -o ConnectTimeout=5 %SSH_USER%@%SERVER% "echo '[OK] 免密登录测试成功！'"
    
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo ====================================
        echo ✅ 免密登录配置成功！
        echo ====================================
        echo.
        echo 现在可以运行 db-tunnel.bat 无需密码
    ) else (
        echo.
        echo [提示] 免密登录可能还需要额外配置
        echo [建议] 请检查服务器 /etc/ssh/sshd_config 配置:
        echo         PubkeyAuthentication yes
        echo         AuthorizedKeysFile .ssh/authorized_keys
        echo.
        echo 如需修改配置，请运行:
        echo         ssh %SSH_USER%@%SERVER%
        echo         sudo vi /etc/ssh/sshd_config
        echo         sudo systemctl restart sshd
    )
) else (
    echo.
    echo [错误] 权限修复失败
)

echo.
pause
