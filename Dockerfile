# hy2/Dockerfile (v6 - 最终正确版)

# --- 第一阶段: Downloader ---
# 这一阶段只做一件事：下载二进制文件。
FROM alpine:3.19 AS downloader

ARG HYSTERIA_VERSION=2.6.2
ARG TARGETARCH
ARG HYSTERIA_ARCH_SUFFIX

ENV TAG=app/v${HYSTERIA_VERSION}
ENV DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${TAG}/hysteria-linux-"

# 安装 wget
RUN apk add --no-cache wget

# 下载 Hysteria 二进制文件，并加入重试逻辑
RUN case ${TARGETARCH} in \
      "amd64") ARCH_TAG="amd64${HYSTERIA_ARCH_SUFFIX}" ;; \
      "arm64") ARCH_TAG="arm64" ;; \
      *) echo "错误: 不支持的架构: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    echo "正在下载: ${DOWNLOAD_URL}${ARCH_TAG}" && \
    tries=0; until [ "$tries" -ge 3 ]; do \
      wget -T 30 -qO /hysteria "${DOWNLOAD_URL}${ARCH_TAG}" && break; \
      tries=$((tries+1)); \
      echo "下载失败，10秒后重试... (尝试次数: $tries/3)"; \
      sleep 10; \
    done && \
    if [ ! -s "/hysteria" ]; then \
        echo "错误: 下载 Hysteria 二进制文件失败!"; \
        exit 1; \
    fi && \
    chmod +x /hysteria

# --- 第二阶段: Final Image ---
# 构建最终的轻量化运行镜像
FROM alpine:3.19

# 安装运行所必需的工具，包括 python 和 pip
RUN apk add --no-cache \
      ca-certificates \
      jq \
      python3 \
      py3-pip \
      gawk

# 【重要修正】使用 pip 安装，并添加 --break-system-packages 参数来解决 PEP 668 问题
RUN pip3 install --no-cache-dir speedtest-cli --break-system-packages

WORKDIR /etc/hysteria

# 从 downloader 阶段拷贝已经下载好的 Hysteria 二进制文件
COPY --from=downloader /hysteria /usr/local/bin/hysteria

# 拷贝入口脚本并赋予执行权限
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 暴露端口，供 Traefik 转发流量
EXPOSE 443/tcp 443/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]