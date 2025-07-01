# Hysteria 2 + Traefik: 轻量化全自动部署方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

本项目提供了一个极致轻量、安全可靠且完全自动化的方法，用以部署一个基于 Docker 的 Hysteria 2 代理服务器。它利用 Traefik 作为反向代理，自动从 Let's Encrypt 申请和续签 TLS 证书，无需手动干预。

## 核心特性

*   **极致轻量 (Ultra-Lightweight):** 仅包含 `Traefik` 和 `Hysteria` 两个核心容器。证书提取在 Hysteria 容器内部通过微小的 `jq` 工具完成，无任何额外的边车容器。
*   **完全自动化 (Fully Automated):** 从域名证书申请、配置生成到服务启动，全程自动化。证书到期前 Traefik 会自动续签，实现一劳永逸。
*   **安全可靠 (Secure & Reliable):** 所有流量均通过由 Let's Encrypt 签发的标准 TLS 证书加密，确保通信安全。
*   **配置简单 (Simple Configuration):** 无需修改任何配置文件，所有参数（域名、密码、邮箱）均通过命令行变量传入，安全且便捷。
*   **智能启动 (Intelligent Startup):** Hysteria 服务会智能等待证书就位后才启动，完美处理了容器启动时序问题。

## 架构简介

1.  **Traefik** 作为流量入口，监听服务器的 `80` 和 `443` 端口（TCP/UDP）。
2.  当服务首次启动时，`Traefik` 通过其 **TCP 路由** 感知到您的域名，并利用 `80` 端口向 Let's Encrypt 发起 `HTTP-01` 挑战，从而为您的域名申请 TLS 证书。
3.  证书被保存在一个共享的 volume 目录下的 `acme.json` 文件中。
4.  **Hysteria 容器**启动后，其入口脚本 (`entrypoint.sh`) 会：
    a. 等待 `acme.json` 文件生成。
    b. 使用内置的 `jq` 工具，从 `acme.json` 中提取出证书和私钥。
    c. 将提取的内容写入到 Hysteria 可读的 `.pem` 文件中。
    d. 加载配置，并正式启动 Hysteria 服务。
5.  所有来自 `443/udp` 端口的 QUIC 流量，由 Traefik 直接转发给 Hysteria 服务。

## 先决条件

1.  一台拥有公网 IP 地址的服务器。
2.  在服务器上安装好 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。
3.  一个域名，并且已经设置了 **A 记录** 指向您服务器的公网 IP。

## 部署步骤

### 1. 克隆本仓库并进入目录

```bash
git clone [你的仓库HTTPS地址]
cd [你的仓库目录名]
```

### 2. (仅首次) 赋予脚本执行权限

由于不同系统的 Git 环境差异，请先运行以下命令为入口脚本赋予执行权限，确保后续步骤顺利进行：

```bash
chmod +x entrypoint.sh
```

### 3. 启动服务

**无需修改任何文件**。直接在命令行中运行以下命令，并将占位符替换为您的真实信息。

```bash
LE_EMAIL="your-email@example.com" \
DOMAIN="your-domain.com" \
PASSWORD="your-strong-password" \
docker-compose up -d --build
```

**参数说明:**

*   `LE_EMAIL`: 您用于申请 Let's Encrypt 证书的邮箱。
*   `DOMAIN`: 您已解析到本服务器的域名。
*   `PASSWORD`: 您为 Hysteria 服务设置的连接密码。

> **提示:** 首次启动时，Traefik 需要几十秒到一分钟的时间来完成证书申请，请耐心等待。

### 3. 获取分享链接

服务成功启动后，运行以下命令查看 Hysteria 容器的日志，其中包含了可直接导入客户端的 `hy2://` 分享链接。

```bash
docker-compose logs hysteria-server
```

您将看到类似以下的输出：

```
───────────────────────────────────────────────
  🎉 Hysteria2 通用分享链接 (轻量化最终版) 🎉

  hy2://your-encoded-password@your-domain.com:443?sni=your-domain.com&obfs=salamander&obfs-password=your-encoded-password

  服务器已成功启动！
───────────────────────────────────────────────
```

## 文件结构

*   `docker-compose.yml`: 定义 `traefik` 和 `hysteria-server` 两个服务及其网络和卷。
*   `Dockerfile`: 用于构建 Hysteria 镜像。它在官方 Alpine 镜像的基础上，安装了 `hysteria` 和 `jq`。
*   `entrypoint.sh`: Hysteria 容器的入口脚本，整个自动化部署的“大脑”。
*   `README.md`: 本说明文件。

## 故障排除 (Troubleshooting)

如果部署失败，请按以下步骤检查：

1.  **检查防火墙**: 确保您服务器的防火墙（或云服务商的安全组）已开放 **TCP 端口 80、443** 和 **UDP 端口 443**。
2.  **检查域名解析**: 运行 `ping your-domain.com`，确认域名已正确解析到您的服务器 IP。
3.  **查看 Traefik 日志**: 如果长时间无法获取证书，请查看 Traefik 的日志寻找原因。
    ```bash
    docker-compose logs traefik
    ```
    常见的错误包括域名解析不正确、Let's Encrypt 速率限制等。
4.  **完全重置**: 如果您需要修改域名或遇到无法解决的问题，最干净的方法是彻底重置。
    ```bash
    # 停止并删除所有容器和网络
    docker-compose down

    # 删除旧的证书目录，以便重新开始
    sudo rm -rf ./letsencrypt

    # 然后用新的配置重新运行启动命令
    LE_EMAIL="..." DOMAIN="..." PASSWORD="..." docker-compose up -d --build
    ```

## 贡献

欢迎提交 Pull Request 或创建 Issue 来改进这个项目。

## 许可证

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 授权。
