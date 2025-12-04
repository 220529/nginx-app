# ERP 数据库隧道连接工具
# PowerShell 版本

$SERVER = "47.93.17.251"
$LOCAL_PORT = 3307
$REMOTE_PORT = 3306
$CONTAINER = "erp-mysql"

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "   ERP 数据库隧道连接工具" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[信息] 正在建立 SSH 隧道..." -ForegroundColor Green
Write-Host "[信息] 本地端口: $LOCAL_PORT" -ForegroundColor Yellow
Write-Host "[信息] 远程服务器: $SERVER" -ForegroundColor Yellow
Write-Host ""

Write-Host "连接成功后，使用以下信息:" -ForegroundColor Cyan
Write-Host "  主机: localhost" -ForegroundColor White
Write-Host "  端口: $LOCAL_PORT" -ForegroundColor White
Write-Host "  用户: erp_user" -ForegroundColor White
Write-Host "  数据库: erp_core" -ForegroundColor White
Write-Host ""

Write-Host "[提示] 按 Ctrl+C 可断开隧道" -ForegroundColor Yellow
Write-Host ""

# 建立 SSH 隧道
ssh -L "${LOCAL_PORT}:${CONTAINER}:${REMOTE_PORT}" "root@$SERVER"

Write-Host ""
Write-Host "[信息] 隧道已断开" -ForegroundColor Red
Read-Host "按 Enter 退出"
