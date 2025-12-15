# Hysteria 2 + Traefik: 极致性能全自动部署方案 (Performance Edition)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](https://www.docker.com/)

本项目是 Hysteria 2 的**高性能 (Performance Edition)** 容器化部署方案。

与传统的容器方案不同，我们采用了**UDP 直通架构**，配合**内核级参数调优**，在保持 Traefik 自动管理证书的便利性的同时，彻底消除了用户态代理带来的性能损耗，实现了真正的“零损耗”传输。

## ⚡️ 核心架构变革 (v2.1)

为了追求极致的能效比与隐蔽性，本项目采用了全新的 **TCP/UDP 分离架构**：

1.  **UDP 直通内核 (Direct Passthrough):** Hysteria 容器直接接管宿主机的 **UDP 443** 端口。流量不再经过 Traefik 代理转发，消除了上下文切换和内存拷贝，显著降低延迟和 CPU 占用。
2.  **智能伪装与零报错 (Smart Masquerade):** Traefik 监听 **TCP 443**，不仅负责自动申请/续签证书，还配置了**智能伪装**。当浏览器或主动探测器通过 HTTPS 访问你的域名时，流量会被自动重定向至大厂官网（默认 McDonald's），看起来就像一个正常的 Web 服务，同时彻底消除了旧版本中的 "Connection Refused" 错误日志。
3.  **证书自动热载:** 后台守护进程每 10 分钟监控一次证书变化。一旦 Traefik 完成续签，Hysteria 容器会自动重启重载，确保证书永不过期。
4.  **内核参数调优 (Sysctl Tuning):** 容器自动注入优化的内核网络参数（`rmem`/`wmem`），大幅增加 UDP 缓冲区大小，完美解决 QUIC 协议在高带宽下的丢包和吞吐瓶颈。

## ✨ 主要特性

*   **开箱即用:** 只需填写域名和邮箱，自动完成证书申请、配置生成、服务启动。
*   **智能带宽管理:** 启动时使用 Ookla 原生客户端自动测速，并根据结果智能计算 Hysteria 的最佳发送/接收速率。
*   **高隐蔽性:**
    *   **TCP 伪装:** 浏览器访问域名 (HTTPS) 时，Traefik 会将其重定向至正常网站（如麦当劳官网），完美隐藏代理特征。
    *   **UDP 伪装:** Hysteria 内部集成了伪装机制，对抗主动探测。
*   **多架构支持:** 完美支持 `amd64` (自动启用 AVX 指令集优化) 和 `arm64`。

## 📋 先决条件

1.  一台拥有公网 IP 的服务器。
2.  安装好 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。
3.  **域名解析:** 域名 A 记录已指向服务器 IP。
4.  **端口开放:** 防火墙需开放 **TCP 443** (给 Traefik 申请证书) 和 **UDP 443** (给 Hysteria 传输数据)。

## 🚀 快速开始

### 1. 克隆与配置

```bash
git clone https://github.com/Prodigalgal/hysteria2-simple-container.git
cd hysteria2-simple-container

# 复制配置文件模板
cp .env.example .env
```

### 2. 编辑 `.env` 文件

使用编辑器（如 `nano`）填入你的域名和邮箱：

```bash
nano .env
```

```dotenv
# .env 必填项
LE_EMAIL="your-email@example.com"  # 用于申请证书的邮箱
DOMAIN="your-domain.com"           # 你的域名

# 可选项
PASSWORD=""                        # 留空则自动生成强密码
AUTO_SPEEDTEST=true                # 是否开启启动时自动测速
```

### 3. 启动服务

```bash
docker-compose up -d --build
```

### 4. 获取配置链接

服务启动后（首次启动需等待约 30 秒进行测速和申请证书），查看日志获取连接信息：

```bash
docker-compose logs hysteria-server
```

你将看到类似下面的输出，包含自动生成的密码和 `hy2://` 分享链接：

```text
────────────────────────────────────────────────────────
  🚀 Hysteria2 (高性能版) 服务启动中...
  链接: hy2://PASSWORD@your-domain.com:443?sni=...
────────────────────────────────────────────────────────
```

## ⚙️ 进阶配置 (.env)

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `LE_EMAIL` | - | **(必填)** Let's Encrypt 注册邮箱 |
| `DOMAIN` | - | **(必填)** 服务器域名 |
| `PASSWORD` | (自动生成) | 连接密码。留空自动生成 16 位随机密码 |
| `AUTO_SPEEDTEST` | `true` | 是否在启动时自动测速以设定带宽 |
| `SPEED_DISCOUNT` | `0.8` | 测速结果折扣率 (0.8 表示使用测速值的 80% 作为配置) |
| `UP_MBPS` / `DOWN_MBPS`| `100` | 手动指定带宽 (仅当 `AUTO_SPEEDTEST=false` 时生效) |
| `OBFS_PASSWORD` | (同密码) | 混淆密码，默认与连接密码相同 |
| `TRAEFIK_LOG_LEVEL` | `INFO` | Traefik 日志级别 (`DEBUG`, `INFO`, `ERROR`)。调试证书问题时建议设为 `DEBUG` |
| `HYSTERIA_VERSION`| `2.6.2` | 指定 Hysteria 核心版本 |

## 🔄 如何更新

由于本项目不断优化架构，建议使用以下标准流程更新：

```bash
cd hysteria2-simple-container

# 1. 拉取最新代码
git pull

# 2. 停止并移除旧容器 (重要：清除旧的网络占用)
docker-compose down

# 3. 重新构建并启动
docker-compose up -d --build --remove-orphans
```

## 🔍 常见问题 (FAQ)

**Q: 为什么我访问 `https://我的域名` 跳转到了麦当劳？**
A: 这是正常的伪装行为。为了防止主动探测并消除错误日志，Traefik 配置了中间件，将所有非 Hysteria 的 TCP 流量（即浏览器访问）重定向到合法的第三方网站。

**Q: Traefik 和 Hysteria 是如何共存的？**
A: 这是本项目的核心优势。
*   **TCP 443 (Traefik):** 负责申请 ACME 证书，并作为“门面”处理所有 HTTPS 请求（伪装）。
*   **UDP 443 (Hysteria):** 直接由 Hysteria 内核接管，处理真正的代理流量。
    两者共享同一个域名和端口号（不同协议），互不干扰，且 Traefik 申请的证书会自动同步给 Hysteria 使用。

**Q: 为什么日志显示 "Bind address already in use"?**
A: 因为 Hysteria 直接占用宿主机 **UDP 443** 端口。请确保没有其他服务（如 Nginx 的 HTTP/3 功能）占用了该端口。

**Q: 测速结果不准确怎么办？**
A: 自动测速受网络波动影响。如果结果不理想，建议在 `.env` 中设置 `AUTO_SPEEDTEST=false`，然后手动填写 `UP_MBPS` 和 `DOWN_MBPS`（单位 Mbps）。

## 🤝 贡献

欢迎提交 Issue 或 Pull Request。本项目的目标是保持最精简、最高效的 Hysteria 2 容器化体验。

## 许可证

MIT License