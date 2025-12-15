#!/usr/bin/env bash

set -e

echo "--- 正在初始化配置 (Performance Edition) ---"
DOMAIN=${DOMAIN:?错误: 必须设置 DOMAIN 环境变量}
LE_EMAIL=${LE_EMAIL:?错误: 必须设置 LE_EMAIL 环境变量}
PASSWORD_RAW=${PASSWORD:-}
LISTEN_PORT=443
UP_MBPS_USER=${UP_MBPS:-}
DOWN_MBPS_USER=${DOWN_MBPS:-}
AUTO_SPEEDTEST=${AUTO_SPEEDTEST:-true}
SPEED_DISCOUNT=${SPEED_DISCOUNT:-0.8}
OBFS_TYPE=${OBFS_TYPE:-salamander}
OBFS_PASSWORD_RAW=${OBFS_PASSWORD:-}
ACME_JSON_PATH="/etc/hysteria/certs/acme.json"
CERT_DIR="/tmp"
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"

if [ -z "$PASSWORD_RAW" ] || [ "$PASSWORD_RAW" = "changeme" ]; then
  PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
  echo "############################################################" >&2
  echo "# 警告: 未提供密码，已自动生成随机密码。" >&2
  echo "# 您的新密码是: ${PASSWORD}" >&2
  echo "############################################################" >&2
else
  PASSWORD="$PASSWORD_RAW"
fi
OBFS_PASSWORD_VAL=${OBFS_PASSWORD_RAW:-$PASSWORD}

echo "--- 正在配置带宽 ---"
if [ "$AUTO_SPEEDTEST" = "true" ]; then
  echo "自动测速已开启。使用 Ookla 原生客户端测速..."
  SPEED_JSON=$(timeout 60s speedtest --accept-license --accept-gdpr -f json 2>/dev/null || echo "")

  if [ -n "$SPEED_JSON" ] && [ "$(echo "$SPEED_JSON" | jq 'has("download")')" = "true" ]; then
    DOWN_BYTES=$(echo "$SPEED_JSON" | jq -r '.download.bandwidth')
    UP_BYTES=$(echo "$SPEED_JSON" | jq -r '.upload.bandwidth')

    if [ "$DOWN_BYTES" != "null" ] && [ "$UP_BYTES" != "null" ] && [ "$DOWN_BYTES" -gt 0 ]; then
        DOWN_MBPS=$(awk "BEGIN {printf \"%.0f\", $DOWN_BYTES * 8 / 1000000 * $SPEED_DISCOUNT}")
        UP_MBPS=$(awk "BEGIN {printf \"%.0f\", $UP_BYTES * 8 / 1000000 * $SPEED_DISCOUNT}")
        echo "测速完成! 应用折扣 ($SPEED_DISCOUNT) 后 -> 下载: ${DOWN_MBPS} Mbps, 上传: ${UP_MBPS} Mbps"
    else
        echo "警告: 测速结果无效，将使用默认带宽 (100 Mbps)。"
        UP_MBPS=100
        DOWN_MBPS=100
    fi
  else
    echo "警告: 自动测速失败或超时。将使用默认带宽 (100 Mbps)。"
    UP_MBPS=100
    DOWN_MBPS=100
  fi
elif [ -n "$UP_MBPS_USER" ] && [ -n "$DOWN_MBPS_USER" ]; then
  UP_MBPS=$UP_MBPS_USER
  DOWN_MBPS=$DOWN_MBPS_USER
else
  UP_MBPS=100
  DOWN_MBPS=100
fi

extract_cert() {
    jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .certificate' "$ACME_JSON_PATH" 2>/dev/null || echo ""
}
extract_key() {
    jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .key' "$ACME_JSON_PATH" 2>/dev/null || echo ""
}

echo "--- 正在处理证书 ---"
timeout=300
CURRENT_CERT=""
while [ $timeout -gt 0 ]; do
    if [ -s "$ACME_JSON_PATH" ]; then
        CURRENT_CERT=$(extract_cert)
        CURRENT_KEY=$(extract_key)
        if [ -n "$CURRENT_CERT" ] && [ "$CURRENT_CERT" != "null" ]; then
            break
        fi
    fi
    echo "等待 acme.json 中出现域名 [${DOMAIN}] 的证书... (${timeout}s)"
    sleep 5
    timeout=$((timeout - 5))
done

if [ -z "$CURRENT_CERT" ] || [ "$CURRENT_CERT" = "null" ]; then
    echo "错误：获取证书超时！请检查 Traefik 日志和域名解析。" >&2
    exit 1
fi

echo "$CURRENT_CERT" | base64 -d > "$CERT_FILE"
echo "$CURRENT_KEY" | base64 -d > "$KEY_FILE"
echo "证书提取成功。"

JSON_CONFIG=$(jq -n \
  --arg listen ":${LISTEN_PORT}" \
  --arg cert_file "$CERT_FILE" \
  --arg key_file "$KEY_FILE" \
  --arg password "$PASSWORD" \
  --arg obfs_type "$OBFS_TYPE" \
  --arg obfs_password "$OBFS_PASSWORD_VAL" \
  --argjson up_mbps "$UP_MBPS" \
  --argjson down_mbps "$DOWN_MBPS" \
  --arg masquerade_url "https://www.mcdonalds.com" \
  '{
    listen: $listen,
    tls: { cert: $cert_file, key: $key_file },
    auth: { type: "password", password: $password },
    obfs: { type: $obfs_type, salamander: { password: $obfs_password } },
    up_mbps: $up_mbps,
    down_mbps: $down_mbps,
    disable_mtu_discovery: false
  }')

echo "$JSON_CONFIG" > /etc/hysteria/config.json
echo "配置文件已生成。"

url_encode() {
    gawk 'BEGIN{FS="";OFS=""} {for(i=1;i<=NF;i++) {if($i~/[a-zA-Z0-9_.-]/) printf "%s", $i; else printf "%%%02X", ord($i)}}'
}
ENCODED_PASSWORD=$(echo -n "$PASSWORD" | url_encode)
ENCODED_OBFS_PASSWORD=$(echo -n "$OBFS_PASSWORD_VAL" | url_encode)
HY2_LINK="hy2://${ENCODED_PASSWORD}@${DOMAIN}:443?sni=${DOMAIN}&obfs=${OBFS_TYPE}&obfs-password=${ENCODED_OBFS_PASSWORD}"

echo "────────────────────────────────────────────────────────"
echo "  🚀 Hysteria2 (高性能版) 服务启动中..."
echo "  链接: ${HY2_LINK}"
echo "────────────────────────────────────────────────────────"

(
    INITIAL_HASH=$(echo "$CURRENT_CERT" | sha256sum)
    echo "🔍 证书监控已启动 (检测间隔: 10分钟)"

    while true; do
        sleep 600

        NEW_CERT=$(extract_cert)

        if [ -n "$NEW_CERT" ] && [ "$NEW_CERT" != "null" ]; then
            NEW_HASH=$(echo "$NEW_CERT" | sha256sum)
            if [ "$NEW_HASH" != "$INITIAL_HASH" ]; then
                echo "♻️ 检测到 acme.json 证书更新！正在退出容器以重启服务..."
                kill 1
                exit
            fi
        fi
    done
) &

exec hysteria server -c /etc/hysteria/config.json