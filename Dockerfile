# hy2/Dockerfile (轻量化最终版)
FROM alpine:3.18

# 安装必需工具，并增加 jq 用于解析 JSON
RUN apk add --no-cache \
      ca-certificates \
      wget \
      jq

# 支持通过 build-arg 覆盖版本
ARG HYSTERIA_VERSION=2.6.0
ENV TAG=app/v${HYSTERIA_VERSION}

# 下载 Hysteria 二进制文件
RUN wget -qO /usr/local/bin/hysteria \
      https://github.com/apernet/hysteria/releases/download/${TAG}/hysteria-linux-amd64 \
    && chmod +x /usr/local/bin/hysteria

WORKDIR /etc/hysteria

# 拷贝并授权 entrypoint 脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443/tcp 443/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
