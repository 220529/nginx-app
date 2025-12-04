# SSH 数据库隧道使用指南

## 📋 概述

本目录包含用于建立 SSH 隧道连接到 ERP 数据库的脚本工具。

## 🔑 免密登录配置（已完成）

SSH 密钥认证已配置完成，现在可以无需密码直接连接。

### 密钥位置
- **私钥**: `C:\Users\EDY\.ssh\id_rsa`
- **公钥**: `C:\Users\EDY\.ssh\id_rsa.pub`
- **服务器**: `root@47.93.17.251:~/.ssh/authorized_keys`

## 🚀 使用方法

### 1. 建立数据库隧道

双击运行或在命令行执行：

```powershell
.\nginx-app\scripts\db-tunnel.bat
```

**特点**：
- ✅ 自动使用 SSH 密钥认证（免密登录）
- ✅ 本地端口：`3307`
- ✅ 远程端口：`3306`
- ✅ 保持窗口打开即可维持隧道连接

### 2. 连接数据库

隧道建立后，使用以下信息连接数据库：

| 参数 | 值 |
|------|-----|
| **主机** | `localhost` 或 `127.0.0.1` |
| **端口** | `3307` |
| **用户名** | `erp_user` |
| **密码** | （数据库密码） |
| **数据库** | `erp_core` |

### 3. 断开隧道

关闭 `db-tunnel.bat` 窗口即可断开隧道连接。

## 🛠️ 辅助脚本

### `upload-ssh-key.bat`
重新上传 SSH 公钥到服务器（如果免密登录失效时使用）

```powershell
.\nginx-app\scripts\upload-ssh-key.bat
```

### `fix-ssh-permissions.bat`
修复服务器端 SSH 权限问题

```powershell
.\nginx-app\scripts\fix-ssh-permissions.bat
```

### `setup-ssh-key.bat`
测试和验证 SSH 配置

```powershell
.\nginx-app\scripts\setup-ssh-key.bat
```

## 📝 常见问题

### Q: 仍然提示输入密码？

**解决方案**：

1. 运行 `upload-ssh-key.bat` 重新上传公钥
2. 运行 `fix-ssh-permissions.bat` 修复权限
3. 测试免密登录：
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_rsa" root@47.93.17.251 "echo 'test'"
   ```

### Q: 连接失败？

**检查清单**：

1. ✅ 服务器 SSH 服务正常运行
2. ✅ 服务器防火墙允许 SSH 连接（端口 22）
3. ✅ 服务器上 MySQL 容器正在运行
4. ✅ MySQL 容器端口映射正确：`127.0.0.1:3306:3306`

验证 MySQL 容器配置：

```bash
ssh root@47.93.17.251
cd /root/db-app
docker-compose -f docker-compose.prod.yml ps
cat docker-compose.prod.yml | grep -A 2 "ports:"
```

### Q: 本地端口 3307 被占用？

**解决方案**：

1. 检查占用端口的进程：
   ```powershell
   netstat -ano | findstr :3307
   ```

2. 修改 `db-tunnel.bat` 中的 `LOCAL_PORT` 为其他端口（如 3308）

## 🔒 安全提示

1. **私钥保护**：`C:\Users\EDY\.ssh\id_rsa` 是你的私钥，请妥善保管，不要分享
2. **公钥共享**：`id_rsa.pub` 是公钥，可以安全地上传到服务器
3. **定期更新**：建议定期更换 SSH 密钥（如每年一次）

## 📊 服务器配置要求

### MySQL 容器配置

确保 `db-app/docker-compose.prod.yml` 包含以下配置：

```yaml
services:
  erp-mysql:
    ports:
      - "127.0.0.1:3306:3306"  # 只监听本地回环地址
```

### SSH 服务配置

确保 `/etc/ssh/sshd_config` 包含：

```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

## 🎯 快速测试

测试完整流程：

```powershell
# 1. 测试 SSH 免密登录
ssh -i "$env:USERPROFILE\.ssh\id_rsa" root@47.93.17.251 "echo 'SSH OK'"

# 2. 测试 MySQL 服务
ssh root@47.93.17.251 "docker exec erp-mysql mysql -uerp_user -p -e 'SELECT 1'"

# 3. 建立隧道
.\nginx-app\scripts\db-tunnel.bat

# 4. 在另一个窗口测试连接
mysql -h 127.0.0.1 -P 3307 -uerp_user -p erp_core
```

## 📞 支持

如遇问题，请检查：
1. 本文档的常见问题部分
2. 运行辅助脚本进行诊断
3. 查看服务器日志：`ssh root@47.93.17.251 "tail -f /var/log/auth.log"`
