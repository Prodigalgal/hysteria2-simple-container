#!/usr/bin/env sh
# hy2/entrypoint.sh (最终稳定版：增加网络初始化延迟)

# 脚本安全设置
set -eu

# --- 1. 初始化所有环境变量 ---
DOMAIN=${DOMAIN:-fallback.example.com}
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

# --- 2. 智能密码处理 (最先执行) ---
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

# --- 3. 带宽优先级逻辑处理 ---
echo "--- 带宽配置 ---"
# 优先级 1: 用户手动设置
if [ -n "$UP_MBPS_USER" ] && [ -n "$DOWN_MBPS_USER" ]; then
  echo "检测到用户手动设置带宽，将使用此配置。"
  UP_MBPS=$UP_MBPS_USER
  DOWN_MBPS=$DOWN_MBPS_USER
# 优先级 2: 自动测速
elif [ "$AUTO_SPEEDTEST" = "true" ]; then
  echo "等待 5 秒，以确保容器网络初始化完成..."
  sleep 5

  echo "正在自动测速以设定带宽，此过程可能需要一分钟，请稍候..."
  # 在前台运行测速，确保日志顺序正确
  SPEED_JSON=$(timeout 60s speedtest-cli --json 2>/dev/null || echo "")

  if [ -n "$SPEED_JSON" ] && [ "$(echo "$SPEED_JSON" | jq 'has("download") and has("upload")')" = "true" ]; then
    DOWN_BPS=$(echo "$SPEED_JSON" | jq -r '.download')
    UP_BPS=$(echo "$SPEED_JSON" | jq -r '.upload')

    if [ "$DOWN_BPS" != "null" ] && [ "$UP_BPS" != "null" ]; then
        DOWN_MBPS_RAW=$(gawk "BEGIN {print $DOWN_BPS / 1000000 * $SPEED_DISCOUNT}")
        UP_MBPS_RAW=$(gawk "BEGIN {print $UP_BPS / 1000000 * $SPEED_DISCOUNT}")

        DOWN_MBPS=$(printf "%.0f" "$DOWN_MBPS_RAW")
        UP_MBPS=$(printf "%.0f" "$UP_MBPS_RAW")

        echo "测速完成! 自动设定带宽 -> 下载: ${DOWN_MBPS} Mbps, 上传: ${UP_MBPS} Mbps (已应用 ${SPEED_DISCOUNT} 折扣)"
    else
        echo "警告: 测速结果无效，将使用默认带宽 (100 Mbps)。"
        UP_MBPS=100
        DOWN_MBPS=100
    fi
  else
    echo "警告: 自动测速失败或超时。这通常是由于容器网络初始化延迟或服务器无法连接到 Speedtest 服务器所致。将使用默认带宽 (100 Mbps)。"
    UP_MBPS=100
    DOWN_MBPS=100
  fi
# 优先级 3: 默认值
else
  echo "自动测速已禁用，且用户未手动设置，使用默认带宽 (100 Mbps)。"
  UP_MBPS=100
  DOWN_MBPS=100
fi
echo "最终带宽设定: 上传 ${UP_MBPS} Mbps, 下载 ${DOWN_MBPS} Mbps"
echo "----------------"

# --- 4. 证书提取与验证 ---
echo "正在等待 Traefik 生成证书文件: ${ACME_JSON_PATH}"
timeout=300
while [ ! -s "$ACME_JSON_PATH" ]; do
  sleep 2
  timeout=$((timeout - 2))
  if [ $timeout -le 0 ]; then
    echo "错误：等待证书文件超时！请检查 Traefik 日志以确定问题，并确认域名解析正确。" >&2
    exit 1
  fi
done
echo "acme.json 已找到。"

echo "正在从 acme.json 中为域名 [${DOMAIN}] 提取证书..."
CERT_DATA=$(jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .certificate' "$ACME_JSON_PATH")
KEY_DATA=$(jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .key' "$ACME_JSON_PATH")

if [ -z "$CERT_DATA" ] || [ "$CERT_DATA" = "null" ]; then
  echo "错误：无法在 acme.json 中找到域名 [${DOMAIN}] 的证书数据！" >&2
  echo "请确认您的 DOMAIN 环境变量与 Traefik 申请的域名完全一致。" >&2
  exit 1
fi
echo "$CERT_DATA" | base64 -d > "$CERT_FILE"
echo "$KEY_DATA" | base64 -d > "$KEY_FILE"

if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
  echo "错误：证书或私钥文件生成失败，文件为空。" >&2
  exit 1
fi
echo "证书和私钥已成功提取到 ${CERT_DIR}"


# --- 5. 生成 Hysteria 配置文件 ---
cat > /etc/hysteria/config.json <<EOF
{
  "listen": ":${LISTEN_PORT}",
  "tls": {
    "cert": "${CERT_FILE}",
    "key": "${KEY_FILE}"
  },
  "auth": {
    "type": "password",
    "password": "${PASSWORD}"
  },
  "obfs": {
    "type": "${OBFS_TYPE}",
    "salamander": {
      "password": "${OBFS_PASSWORD_VAL}"
    }
  },
  "upMbps": ${UP_MBPS},
  "downMbps": ${DOWN_MBPS},
  "disableMTUDiscovery": false
}
EOF

# --- 6. 启动 Hysteria 并生成分享链接 ---
echo "正在启动 Hysteria 服务..."
hysteria server --config /etc/hysteria/config.json &

# URL 编码函数
url_encode() {
    gawk 'BEGIN{FS="";OFS=""} {for(i=1;i<=NF;i++) {if($i~/[a-zA-Z0-9_.-]/) printf "%s", $i; else printf "%%%02X", ord($i)}}'
}

ENCODED_PASSWORD=$(echo -n "$PASSWORD" | url_encode)
ENCODED_OBFS_PASSWORD=$(echo -n "$OBFS_PASSWORD_VAL" | url_encode)
PUBLIC_PORT=443
HY2_LINK="hy2://${ENCODED_PASSWORD}@${DOMAIN}:${PUBLIC_PORT}?sni=${DOMAIN}&obfs=${OBFS_TYPE}&obfs-password=${ENCODED_OBFS_PASSWORD}"

echo "────────────────────────────────────────────────────────"
echo "  🎉 Hysteria2 通用分享链接 (智能配置版) 🎉"
echo
echo "  ${HY2_LINK}"
echo
echo "  服务器已成功启动！"
echo "────────────────────────────────────────────────────────"

wait