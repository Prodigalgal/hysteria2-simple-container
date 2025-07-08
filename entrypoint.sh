#!/usr/bin/env sh
# hy2/entrypoint.sh (v6 - TLS 卸载 & 健康检查)

# --- 1. 初始化所有环境变量 ---
echo "--- 正在初始化配置 ---"
DOMAIN=${DOMAIN:?错误: 必须设置 DOMAIN 环境变量}
LE_EMAIL=${LE_EMAIL:?错误: 必须设置 LE_EMAIL 环境变量}
PASSWORD_RAW=${PASSWORD:-}
LISTEN_PORT=443 # Hysteria 核心 UDP 端口
UP_MBPS_USER=${UP_MBPS:-}
DOWN_MBPS_USER=${DOWN_MBPS:-}
AUTO_SPEEDTEST=${AUTO_SPEEDTEST:-true}
SPEED_DISCOUNT=${SPEED_DISCOUNT:-0.8}
OBFS_TYPE=${OBFS_TYPE:-salamander}
OBFS_PASSWORD_RAW=${OBFS_PASSWORD:-}
MASQUERADE_URL=${MASQUERADE_URL:-https://bing.com}
ACME_JSON_PATH="/etc/hysteria/certs/acme.json"
CERT_DIR="/tmp"
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"

# --- 2. 智能密码处理 ---
if [ -z "$PASSWORD_RAW" ] || [ "$PASSWORD_RAW" = "changeme" ]; then
  PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
  echo "############################################################" >&2
  echo "# 警告: 未提供密码，已自动生成随机密码。" >&2
  echo "# 您的新密码是: ${PASSWORD}" >&2
  echo "# 请务必妥善保存此密码！" >&2
  echo "############################################################" >&2
else
  PASSWORD="$PASSWORD_RAW"
fi
OBFS_PASSWORD_VAL=${OBFS_PASSWORD_RAW:-$PASSWORD}

# --- 3. 带宽优先级逻辑处理 (保持不变) ---
echo "--- 正在配置带宽 ---"
if [ -n "$UP_MBPS_USER" ] && [ -n "$DOWN_MBPS_USER" ]; then
  echo "检测到用户手动设置带宽，将使用此配置。"
  UP_MBPS=$UP_MBPS_USER
  DOWN_MBPS=$DOWN_MBPS_USER
elif [ "$AUTO_SPEEDTEST" = "true" ]; then
  echo "等待 5 秒，以确保容器网络初始化完成..."
  sleep 5

  echo "正在自动测速以设定带宽，此过程可能需要一分钟..."
  SPEED_JSON=$(timeout 90s speedtest-cli --json 2>/dev/null || echo "")

  if [ -n "$SPEED_JSON" ] && [ "$(echo "$SPEED_JSON" | jq 'has("download") and has("upload")')" = "true" ]; then
    DOWN_BPS=$(echo "$SPEED_JSON" | jq -r '.download')
    UP_BPS=$(echo "$SPEED_JSON" | jq -r '.upload')

    if [ "$DOWN_BPS" != "null" ] && [ "$UP_BPS" != "null" ] && [ "$(printf "%.0f" "$DOWN_BPS")" != "0" ]; then
        DOWN_MBPS_RAW=$(gawk "BEGIN {print $DOWN_BPS / 1000000 * $SPEED_DISCOUNT}")
        UP_MBPS_RAW=$(gawk "BEGIN {print $UP_BPS / 1000000 * $SPEED_DISCOUNT}")

        DOWN_MBPS=$(printf "%.0f" "$DOWN_MBPS_RAW")
        UP_MBPS=$(printf "%.0f" "$UP_MBPS_RAW")

        echo "测速完成! 自动设定带宽 -> 下载: ${DOWN_MBPS} Mbps, 上传: ${UP_MBPS} Mbps (已应用 ${SPEED_DISCOUNT} 折扣)"
    else
        echo "警告: 测速结果无效 (可能是 0)，将使用默认带宽 (100 Mbps)。"
        UP_MBPS=100
        DOWN_MBPS=100
    fi
  else
    echo "警告: 自动测速失败或超时。将使用默认带宽 (100 Mbps)。"
    UP_MBPS=100
    DOWN_MBPS=100
  fi
else
  echo "自动测速已禁用，使用默认带宽 (100 Mbps)。"
  UP_MBPS=100
  DOWN_MBPS=100
fi
echo "最终带宽设定: 上传 ${UP_MBPS} Mbps, 下载 ${DOWN_MBPS} Mbps"


# --- 4. 证书提取与验证 (保持不变) ---
echo "--- 正在处理证书 ---"
echo "正在等待 Traefik 生成证书文件: ${ACME_JSON_PATH}"
timeout=300
cert_found=false
while [ $timeout -gt 0 ]; do
    if [ -s "$ACME_JSON_PATH" ]; then
        echo "acme.json 已找到。"
        CERT_DATA=$(jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .certificate' "$ACME_JSON_PATH" 2>/dev/null || echo "")
        KEY_DATA=$(jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .key' "$ACME_JSON_PATH" 2>/dev/null || echo "")
        if [ -n "$CERT_DATA" ] && [ "$CERT_DATA" != "null" ]; then
            cert_found=true
            break
        fi
    fi
    echo "尚未在 acme.json 中找到域名 [${DOMAIN}] 的证书，等待 10 秒后重试... (剩余时间: ${timeout}s)"
    sleep 10
    timeout=$((timeout - 10))
done

if [ "$cert_found" = "false" ]; then
    echo "错误：等待证书超时！请检查 Traefik 日志以确定问题，并确认域名解析正确。" >&2
    exit 1
fi

echo "正在从 acme.json 中为域名 [${DOMAIN}] 提取证书..."
echo "$CERT_DATA" | base64 -d > "$CERT_FILE"
echo "$KEY_DATA" | base64 -d > "$KEY_FILE"

if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
  echo "错误：证书或私钥文件生成失败，文件为空。" >&2
  exit 1
fi
echo "证书和私钥已成功提取到 ${CERT_DIR}"

# --- 5. 生成 Hysteria 配置文件 (核心变更) ---
echo "--- 正在生成 Hysteria 配置文件 ---"
# 【修复】为 masquerade 添加 listenHTTP 和 listenHTTPS，以支持 Traefik 的 TLS 卸载
JSON_CONFIG=$(jq -n \
  --arg listen ":${LISTEN_PORT}" \
  --arg cert_file "$CERT_FILE" \
  --arg key_file "$KEY_FILE" \
  --arg password "$PASSWORD" \
  --arg obfs_type "$OBFS_TYPE" \
  --arg obfs_password "$OBFS_PASSWORD_VAL" \
  --argjson up_mbps "$UP_MBPS" \
  --argjson down_mbps "$DOWN_MBPS" \
  --arg masquerade_url "$MASQUERADE_URL" \
  '{
    listen: $listen,
    tls: { cert: $cert_file, key: $key_file },
    auth: { type: "password", password: $password },
    obfs: { type: $obfs_type, salamander: { password: $obfs_password } },
    masquerade: {
        type: "proxy",
        proxy: { url: $masquerade_url, rewriteHost: true },
        listenHTTPS: ":4433",
        listenHTTP: ":8088"
    },
    up_mbps: $up_mbps,
    down_mbps: $down_mbps,
    disable_mtu_discovery: false,
    acl: {
      inline: [
        "direct(all)"
      ]
    }
  }')

echo "$JSON_CONFIG" > /etc/hysteria/config.json
echo "配置文件已生成。"
echo "伪装目标: ${MASQUERADE_URL}"


# --- 6. 启动 Hysteria 并生成分享链接 (保持不变) ---
echo "--- 正在启动服务 ---"
hysteria server -c /etc/hysteria/config.json &

url_encode() {
    gawk 'BEGIN{FS="";OFS=""} {for(i=1;i<=NF;i++) {if($i~/[a-zA-Z0-9_.-]/) printf "%s", $i; else printf "%%%02X", ord($i)}}'
}

ENCODED_PASSWORD=$(echo -n "$PASSWORD" | url_encode)
ENCODED_OBFS_PASSWORD=$(echo -n "$OBFS_PASSWORD_VAL" | url_encode)
PUBLIC_PORT=443
HY2_LINK="hy2://${ENCODED_PASSWORD}@${DOMAIN}:${PUBLIC_PORT}?sni=${DOMAIN}&obfs=${OBFS_TYPE}&obfs-password=${ENCODED_OBFS_PASSWORD}"

echo "────────────────────────────────────────────────────────"
echo "  🎉 Hysteria2 服务已启动，配置如下 🎉"
echo
echo "  分享链接 (可直接导入客户端):"
echo "  ${HY2_LINK}"
echo
echo "  手动配置详情:"
echo "  - 服务器地址: ${DOMAIN}:${PUBLIC_PORT}"
echo "  - 密码: ${PASSWORD}"
echo "  - SNI: ${DOMAIN}"
echo "  - 混淆 (${OBFS_TYPE}): ${OBFS_PASSWORD_VAL}"
echo "  - 带宽: ${UP_MBPS} Mbps (上传) / ${DOWN_MBPS} Mbps (下载)"
echo "────────────────────────────────────────────────────────"

wait