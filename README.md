# Hysteria 2 + Traefik: 极致智能与轻量的全自动部署方案 (Pro Max 版)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/Prodigalgal/hysteria2-simple-container?style=social)](https://github.com/Prodigalgal/hysteria2-simple-container/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/Prodigalgal/hysteria2-simple-container?style=social)](https://github.com/Prodigalgal/hysteria2-simple-container/network/members)

本项目提供了一个极致智能、安全可靠且完全自动化的方法，用以一键部署一个基于 Docker 的 Hysteria 2 代理服务器。它利用 Traefik 作为反向代理，**自动处理 TLS 证书**，并具备**自动生成密码**、**智能优化带宽**和**站点伪装**等高级功能，实现真正的“零配置”和“开箱即用”。

## ✨ 核心特性

*   **全自动智能配置:**
    *   **自动生成密码:** 无需手动设置，启动时自动生成高强度随机密码，杜绝弱密码风险。
    *   **自动优化带宽:** 启动时自动检测服务器的公网带宽，并智能配置 Hysteria 的性能参数，最大化利用服务器资源。
*   **增强抗封锁:**
    *   **无缝网站伪装:** 内置反向代理伪装，当服务器被直接访问时，会显示为一个真实的网站（默认 Bing），有效对抗主动探测。
    *   **最新协议支持:** 默认使用最新的 Hysteria 核心，利用其底层协议特性更好地规避审查。
*   **一键部署，零干预:** 只需提供域名和邮箱，即可完成从证书申请、配置生成到服务启动的全过程。Traefik 会自动处理证书续签，一劳永逸。
*   **广泛平台兼容:** 同时支持 `amd64` 和 `arm64` 架构，并为 `amd64` 用户提供可选的 **AVX 高性能版本**。
*   **极致轻量:** 仅包含 `Traefik` 和 `Hysteria` 两个核心容器。所有逻辑在容器内部完成，无任何额外的边车容器。

## 📋 先决条件

1.  一台拥有公网 IP 地址的服务器。
2.  在服务器上安装好 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。
3.  一个域名，并且已经设置了 **A 记录** 指向您服务器的公网 IP。

## 🚀 快速开始

### 1. 克隆本仓库并配置

```bash
git clone https://github.com/Prodigalgal/hysteria2-simple-container.git
cd hysteria2-simple-container

# 从模板复制 .env 文件
cp .env.example .env
```

### 2. 编辑 `.env` 文件

使用你喜欢的编辑器（如 `nano`）打开 `.env` 文件，**至少填入你的域名和邮箱**。

```bash
nano .env
```
```dotenv
# .env
# --- 必填项 ---
LE_EMAIL="your-email@example.com"
DOMAIN="your-domain.com"

# --- 可选项 (其他配置可按需修改) ---
PASSWORD="changeme" # 留空将自动生成
...
```

### 3. 启动服务

```bash
docker-compose up -d --build
```
> **提示:** 首次启动时，脚本会进行网络测速（如果开启），可能需要等待一分钟左右。

### 4. 获取分享链接和查看配置

服务成功启动后，运行以下命令查看 Hysteria 容器的日志。其中包含了自动生成的密码（如果未手动设置）、最终的带宽配置以及可直接导入客户端的 `hy2://` 分享链接。

```bash
docker-compose logs hysteria-server
```

## ⚙️ 进阶配置

您可以通过编辑 `.env` 文件来控制项目的所有行为。

| 变量名 | 作用 | 默认值 | 备注 |
| :--- | :--- | :--- | :--- |
| `LE_EMAIL` | 用于申请 Let's Encrypt 证书的邮箱。 | **无 (必须提供)** | - |
| `DOMAIN` | 已解析到本服务器的域名。 | **无 (必须提供)** | - |
| `PASSWORD` | Hysteria 的连接密码。 | **自动生成** | 若留空或设为 "changeme"，将自动生成16位强随机密码。 |
| `MASQUERADE_URL` | 伪装站点的 URL。| `https://bing.com` | 当服务器被直接访问时，将反向代理到此 URL。 |
| `HYSTERIA_VERSION`| 要使用的 Hysteria 版本。 | `2.6.2` | 修改此项可部署指定版本的 Hysteria。 |
| `HYSTERIA_ARCH_SUFFIX` | Hysteria 架构后缀 (仅 amd64)。| `-avx` | 设为 `-avx` 使用 AVX 版，留空使用通用版。 |
| `AUTO_SPEEDTEST` | 是否开启自动测速功能。 | `true` | 设为 `false` 可禁用测速，使用下面的手动设置。 |
| `SPEED_DISCOUNT` | 测速结果的折扣率。 | `0.8` | 将测速结果乘以该值作为最终配置，以保证网络稳定性。 |
| `UP_MBPS` | 手动设置上传速度 (Mbps)。 | `100` | 仅在 `AUTO_SPEEDTEST=false` 时生效。 |
| `DOWN_MBPS` | 手动设置下载速度 (Mbps)。 | `100` | 仅在 `AUTO_SPEEDTEST=false` 时生效。 |
| `OBFS_TYPE` | 混淆类型。 | `salamander` | - |
| `OBFS_PASSWORD` | 混淆密码。 | 与 `PASSWORD` 相同 | 可以为混淆设置一个独立的密码。 |


## 🔄 更新

要更新到最新的 Hysteria 版本或本项目的最新脚本，请执行以下命令：

```bash
# 进入项目目录
cd hysteria2-simple-container

# 1. 拉取最新的项目文件
git pull

# 2. (可选) 修改 .env 文件中的 HYSTERIA_VERSION
# nano .env

# 3. 彻底重置并重新构建
docker-compose down --volumes
docker-compose up -d --build
```
> **注意:** 使用 `down --volumes` 是最可靠的更新方式，它能确保所有旧的、可能冲突的容器和缓存被彻底清除。

## 🔍 故障排除 (Troubleshooting)

1.  **检查防火墙**: 确保您服务器的防火墙（或云服务商的安全组）已开放 **TCP 端口 443** 和 **UDP 端口 443**。**(注意：不再需要 80 端口)**
2.  **检查域名解析**: 在启动前，请务必运行 `ping your-domain.com`，确认域名已正确解析到您的服务器 IP。
3.  **查看 Traefik 日志**: 如果长时间无法获取证书，请查看 Traefik 的日志寻找原因。
    ```bash
    docker-compose logs traefik
    ```
4.  **客户端连接错误 `operation not permitted`**: 这是最常见的问题。通常是由于客户端（如 V2rayN）的路由规则错误地**阻止了 UDP 443 端口的流量**。请检查您客户端的路由设置，找到并禁用任何名为 "Block QUIC" 或类似的规则。
5.  **彻底重置**: 如果您需要修改域名或遇到无法解决的问题，最干净的方法是彻底重置。
    ```bash
    docker-compose down --volumes
    sudo rm -rf ./letsencrypt
    # 然后用新的配置重新运行启动命令
    docker-compose up -d --build
    ```

## 🤝 贡献

欢迎提交 Pull Request 或创建 Issue 来改进这个项目。

## 许可证

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 授权。