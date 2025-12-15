FROM alpine:3.19 AS downloader

ARG HYSTERIA_VERSION=2.6.2
ARG TARGETARCH
ARG HYSTERIA_ARCH_SUFFIX

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

FROM alpine:3.19

RUN apk add --no-cache \
      ca-certificates \
      jq \
      python3 \
      py3-pip \
      gawk

RUN pip3 install --no-cache-dir speedtest-cli --break-system-packages

WORKDIR /etc/hysteria

COPY --from=downloader /hysteria /usr/local/bin/hysteria

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443/tcp 443/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]