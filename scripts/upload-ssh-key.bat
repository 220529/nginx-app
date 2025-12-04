@echo off
echo ====================================
echo 上传 SSH 公钥到服务器
echo ====================================
echo.
echo 此脚本将上传你的 SSH 公钥到服务器
echo 需要输入一次服务器密码
echo.

set SERVER=47.93.17.251
set SSH_USER=root
set SSH_KEY=%USERPROFILE%\.ssh\id_rsa.pub

if not exist "%SSH_KEY%" (
    echo [错误] 未找到 SSH 公钥: %SSH_KEY%
    echo [提示] 请先运行 ssh-keygen 生成密钥
    pause
    exit /b 1
)

echo [信息] 读取本地公钥...
type "%SSH_KEY%"
echo.
echo.

echo [步骤 1/3] 备份服务器上现有的 authorized_keys...
ssh %SSH_USER%@%SERVER% "mkdir -p ~/.ssh && [ -f ~/.ssh/authorized_keys ] && cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup.$(date +%%s) || echo 'No existing file'"

echo.
echo [步骤 2/3] 上传公钥到服务器...
type "%SSH_KEY%" | ssh %SSH_USER%@%SERVER% "cat > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo '[OK] 公钥已上传'"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [错误] 公钥上传失败
    pause
    exit /b 1
)

echo.
echo [步骤 3/3] 验证公钥内容...
ssh %SSH_USER%@%SERVER% "echo '服务器上的公钥:' && cat ~/.ssh/authorized_keys"

echo.
echo ====================================
echo ✅ 公钥上传完成
echo ====================================
echo.
echo 现在测试免密登录...
echo.

ssh -i "%USERPROFILE%\.ssh\id_rsa" -o BatchMode=yes -o ConnectTimeout=5 %SSH_USER%@%SERVER% "echo '[OK] 免密登录成功！'"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ====================================
    echo ✅ 免密登录配置成功！
    echo ====================================
    echo.
    echo 现在可以运行 db-tunnel.bat 无需密码
) else (
    echo.
    echo [警告] 免密登录测试失败
    echo [建议] 请检查服务器 SSH 配置
)

echo.
pause
