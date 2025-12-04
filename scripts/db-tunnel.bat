@echo off
echo ====================================
echo ERP 数据库隧道连接工具
echo ====================================
echo.

REM 配置
set SERVER=47.93.17.251
set SSH_USER=root
set LOCAL_PORT=3307
set REMOTE_PORT=3306
set SSH_KEY=%USERPROFILE%\.ssh\id_rsa

echo [信息] 正在建立 SSH 隧道...
echo [信息] 本地端口: %LOCAL_PORT%
echo [信息] 远程服务器: %SERVER%
echo [信息] SSH 用户: %SSH_USER%
echo.

REM 检查 SSH 密钥是否存在
if exist "%SSH_KEY%" (
    echo [OK] 使用 SSH 密钥认证（免密登录）
    echo.
) else (
    echo [警告] 未找到 SSH 密钥，将使用密码认证
    echo [提示] 运行 setup-ssh-key.bat 配置免密登录
    echo.
)

echo [提示] 如果连接失败，请确保服务器上 erp-mysql 服务的 docker-compose.prod.yml 文件中
echo         包含以下端口映射，并且服务已重启:
echo         ports:
echo           - "127.0.0.1:3306:3306"
echo.
echo [提示] 隧道建立成功后，请使用以下信息连接数据库:
echo         主机: localhost
echo         端口: %LOCAL_PORT%
echo         用户: erp_user
echo         数据库: erp_core
echo.
echo [提示] 保持此窗口打开以维持隧道连接，关闭窗口将断开隧道
echo.

REM 使用 SSH 密钥建立隧道（如果密钥存在）
REM -N 参数：不执行远程命令，只做端口转发
if exist "%SSH_KEY%" (
    echo ====================================
    echo 正在连接服务器...
    echo ====================================
    echo.
    ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no -N -L %LOCAL_PORT%:localhost:%REMOTE_PORT% %SSH_USER%@%SERVER%
) else (
    echo ====================================
    echo 正在连接服务器（需要密码）...
    echo ====================================
    echo.
    ssh -N -L %LOCAL_PORT%:localhost:%REMOTE_PORT% %SSH_USER%@%SERVER%
)

echo.
echo [信息] 隧道已断开
pause
