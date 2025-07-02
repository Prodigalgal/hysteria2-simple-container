# Hysteria 2 + Traefik: 极致智能与轻量的全自动部署方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/Prodigalgal/hysteria2-simple-container?style=social)](https://github.com/Prodigalgal/hysteria2-simple-container/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/Prodigalgal/hysteria2-simple-container?style=social)](https://github.com/Prodigalgal/hysteria2-simple-container/network/members)

本项目提供了一个极致智能、安全可靠且完全自动化的方法，用以一键部署一个基于 Docker 的 Hysteria 2 代理服务器。它利用 Traefik 作为反向代理，自动从 Let's Encrypt 申请和续签 TLS 证书，并能**自动生成密码**和**智能优化服务器带宽**，实现真正的“零配置”和“开箱即用”。

## ✨ 核心特性

*   **全自动智能配置 (Fully Automatic & Intelligent Configuration):**
    *   **自动生成密码:** 无需手动设置，启动时自动生成高强度随机密码，杜绝弱密码风险。
    *   **自动优化带宽:** 启动时自动检测服务器的公网带宽，并智能配置 Hysteria 的性能参数，最大化利用服务器资源。
*   **一键部署，零干预 (One-Command Deploy, Zero Intervention):** 只需提供域名和邮箱，即可完成从证书申请、配置生成到服务启动的全过程。Traefik 会自动处理证书续签，一劳永逸。
*   **广泛平台兼容 (Broad Platform Compatibility):** 采用多阶段构建，同时支持 `amd64` 和 `arm64` 架构，无论您使用的是标准云服务器、还是树莓派或 Oracle ARM 服务器，都能完美运行。
*   **高度可定制化 (Highly Customizable):** 虽然提供全自动模式，但所有智能配置（如自动测速）均可关闭，并允许通过环境变量对带宽、混淆方式等高级参数进行精细的手动设置。
*   **极致轻量 (Ultra-Lightweight):** 仅包含 `Traefik` 和 `Hysteria` 两个核心容器。证书提取在 Hysteria 容器内部通过微小的 `jq` 工具完成，无任何额外的边车容器。
*   **安全可靠 (Secure & Reliable):** 所有流量均通过由 Let's Encrypt 签发的标准 TLS 证书加密，确保通信安全。

## 🚀 架构简介

1.  **Traefik** 作为流量入口，监听服务器的 `80` 和 `443` 端口（TCP/UDP）。
2.  当服务首次启动时，`Traefik` 通过其 **TCP 路由** 感知到您的域名，并利用 `80` 端口向 Let's Encrypt 发起 `HTTP-01` 挑战，为您的域名申请 TLS 证书。
3.  证书被保存在一个共享的 volume 目录下的 `acme.json` 文件中。
4.  **Hysteria 容器**启动后，其智能入口脚本 (`entrypoint.sh`) 会执行以下操作：
    a. **智能配置:** 自动生成密码（如果未提供），并运行网络测速以确定最佳带宽。
    b. **等待证书:** 等待 `acme.json` 文件生成。
    c. **提取证书:** 使用内置的 `jq` 工具，从 `acme.json` 中提取出证书和私钥。
    d. **生成配置:** 将所有配置（证书路径、密码、带宽等）写入 Hysteria 的 `config.json` 文件。
    e. **启动服务:** 加载配置，并正式启动 Hysteria 服务。
5.  所有来自 `443/udp` 端口的 QUIC 流量，由 Traefik 直接转发给 Hysteria 服务。

## 📋 先决条件

1.  一台拥有公网 IP 地址的服务器。
2.  在服务器上安装好 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。
3.  一个域名，并且已经设置了 **A 记录** 指向您服务器的公网 IP。

## 部署步骤

### 1. 克隆本仓库并进入目录

```bash
git clone https://github.com/Prodigalgal/hysteria2-simple-container.git
cd hysteria2-simple-container
```

### 2. (仅首次) 赋予脚本执行权限

```bash
chmod +x entrypoint.sh
```

### 3. 启动服务

我们提供两种启动模式，您可以根据需求选择。

#### 方式一：智能模式 (推荐)

这是最简单的方式，您只需提供域名和邮箱，其他所有配置（密码、带宽）都将自动完成。

```bash
LE_EMAIL="your-email@example.com" \
DOMAIN="your-domain.com" \
docker-compose up -d --build
```
> **提示:** 首次启动时，脚本会进行网络测速，可能需要等待一分钟左右。

#### 方式二：自定义模式 (高级)

如果您想手动控制所有参数，可以传入更多环境变量。

```bash
LE_EMAIL="your-email@example.com" \
DOMAIN="your-domain.com" \
PASSWORD="your-strong-password" \
AUTO_SPEEDTEST="false" \
UP_MBPS="200" \
DOWN_MBPS="500" \
OBFS_TYPE="salamander" \
docker-compose up -d --build
```

### 4. 获取分享链接和查看配置

服务成功启动后，运行以下命令查看 Hysteria 容器的日志。其中包含了自动生成的密码（如果未手动设置）、最终的带宽配置以及可直接导入客户端的 `hy2://` 分享链接。

```bash
docker-compose logs hysteria-server
```

## ⚙️ 配置变量详解

您可以通过环境变量来控制项目的所有行为。

| 变量名 | 作用 | 默认值 | 备注 |
| :--- | :--- | :--- | :--- |
| `LE_EMAIL` | 用于申请 Let's Encrypt 证书的邮箱。 | **无 (必须提供)** | - |
| `DOMAIN` | 已解析到本服务器的域名。 | **无 (必须提供)** | - |
| `PASSWORD` | Hysteria 的连接密码。 | **自动生成** | 若留空，将自动生成16位强随机密码并打印在日志中。 |
| `HYSTERIA_VERSION`| 要使用的 Hysteria 版本。 | `2.6.0` | 修改此项可部署指定版本的 Hysteria。 |
| `AUTO_SPEEDTEST` | 是否开启自动测速功能。 | `true` | 设为 `false` 可禁用测速，使用 `UP_MBPS` 和 `DOWN_MBPS` 的值。 |
| `SPEED_DISCOUNT` | 测速结果的折扣率。 | `0.8` | 将测速结果乘以该值作为最终配置，以保证网络稳定性。 |
| `UP_MBPS` | 手动设置上传速度 (Mbps)。 | `100` | **优先级最高。** 若设置此项，将覆盖自动测速结果。 |
| `DOWN_MBPS` | 手动设置下载速度 (Mbps)。 | `100` | **优先级最高。** 若设置此项，将覆盖自动测速结果。 |
| `OBFS_TYPE` | 混淆类型。 | `salamander` | Hysteria 支持的其他混淆类型，如 `wechat-video`。 |
| `OBFS_PASSWORD` | 混淆密码。 | 与 `PASSWORD` 相同 | 可以为混淆设置一个独立的密码。 |

## 🔍 故障排除 (Troubleshooting)

如果部署失败，请按以下步骤检查：

1.  **检查防火墙**: 确保您服务器的防火墙（或云服务商的安全组）已开放 **TCP 端口 80、443** 和 **UDP 端口 443**。
2.  **检查域名解析**: 运行 `ping your-domain.com`，确认域名已正确解析到您的服务器 IP。
3.  **查看 Traefik 日志**: 如果长时间无法获取证书，请查看 Traefik 的日志寻找原因。
    ```bash
    docker-compose logs traefik
    ```
    常见的错误包括域名解析不正确、Let's Encrypt 速率限制等。
4.  **检查自动测速**: 如果测速失败，可能是服务器无法连接 Speedtest.net。请在服务器上运行 `curl -s https://www.speedtest.net/speedtest-config.php` 检查网络连通性。
5.  **完全重置**: 如果您需要修改域名或遇到无法解决的问题，最干净的方法是彻底重置。
    ```bash
    # 停止并删除所有容器和网络
    docker-compose down

    # 删除旧的证书目录，以便重新开始
    sudo rm -rf ./letsencrypt

    # 然后用新的配置重新运行启动命令
    LE_EMAIL="..." DOMAIN="..." docker-compose up -d --build
    ```

## 🤝 贡献

欢迎提交 Pull Request 或创建 Issue 来改进这个项目。

## 许可证

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 授权。