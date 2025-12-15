FROM alpine:3.19 AS downloader

ARG HYSTERIA_VERSION=2.6.2
ARG TARGETARCH
ARG HYSTERIA_ARCH_SUFFIX

# 下载 Hysteria 核心
ENV TAG=app/v${HYSTERIA_VERSION}
ENV DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${TAG}/hysteria-linux-"

RUN apk add --no-cache wget

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

# 下载官方 Ookla Speedtest CLI (C++版本，静态编译，轻量且高性能)
FROM alpine:3.19 AS speedtest-downloader
ARG TARGETARCH
RUN apk add --no-cache curl tar
RUN case ${TARGETARCH} in \
      "amd64") ST_ARCH="x86_64" ;; \
      "arm64") ST_ARCH="aarch64" ;; \
      *) echo "不支持的架构用于 Speedtest"; exit 1 ;; \
    esac && \
    curl -L "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${ST_ARCH}.tgz" -o speedtest.tgz && \
    tar -xvf speedtest.tgz -C /usr/local/bin speedtest && \
    chmod +x /usr/local/bin/speedtest

# --- 最终镜像 ---
FROM alpine:3.19

# 仅安装必要的基础工具，移除 Python 及其依赖
RUN apk add --no-cache \
      ca-certificates \
      jq \
      bash \
      gawk \
      curl

WORKDIR /etc/hysteria

# 从构建阶段复制二进制文件
COPY --from=downloader /hysteria /usr/local/bin/hysteria
COPY --from=speedtest-downloader /usr/local/bin/speedtest /usr/local/bin/speedtest

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Hysteria 直接占用 UDP 443
EXPOSE 443/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]