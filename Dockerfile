# hy2/Dockerfile (已优化：多阶段构建 & ARM/AMD64 支持)

# --- 第一阶段: Builder ---
# 负责下载与目标架构匹配的 Hysteria 二进制文件
FROM alpine:3.18 AS builder

# build-arg 会由 docker-compose 自动从 .env 或命令行传入
ARG HYSTERIA_VERSION=2.6.0
# TARGETARCH 是 Docker buildx 自动提供的变量 (amd64, arm64 等)
ARG TARGETARCH

ENV TAG=app/v${HYSTERIA_VERSION}

# 安装 wget 用于下载
RUN apk add --no-cache wget

# 根据目标架构选择对应的二进制文件名
RUN case ${TARGETARCH} in \
      "amd64") ARCH_TAG="amd64" ;; \
      "arm64") ARCH_TAG="arm64" ;; \
      *) echo "错误: 不支持的架构: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    wget -qO /tmp/hysteria \
      https://github.com/apernet/hysteria/releases/download/${TAG}/hysteria-linux-${ARCH_TAG} && \
    chmod +x /tmp/hysteria

# --- 第二阶段: Final Image ---
# 构建最终的轻量化运行镜像
FROM alpine:3.18

# 安装运行所必需的工具 (ca-certificates 用于 TLS, jq 用于解析 JSON)
RUN apk add --no-cache \
      ca-certificates \
      jq

WORKDIR /etc/hysteria

# 从 builder 阶段拷贝已经下载好的 Hysteria 二进制文件
COPY --from=builder /tmp/hysteria /usr/local/bin/hysteria

# 拷贝入口脚本并赋予执行权限
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 暴露端口，供 Traefik 转发流量
EXPOSE 443/tcp 443/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]