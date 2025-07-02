#!/usr/bin/env sh
# hy2/entrypoint.sh (已优化：支持自定义配置)
set -e

# --- 配置定义 (从环境变量获取，提供默认值) ---
DOMAIN=${DOMAIN:-fallback.example.com}
PASSWORD=${PASSWORD:-changeme}
LISTEN_PORT=443
UP_MBPS=${UP_MBPS:-100}
DOWN_MBPS=${DOWN_MBPS:-100}
OBFS_TYPE=${OBFS_TYPE:-salamander}
# 如果 OBFS_PASSWORD 未设置，则默认使用主 PASSWORD
OBFS_PASSWORD_VAL=${OBFS_PASSWORD:-$PASSWORD}

ACME_JSON_PATH="/etc/hysteria/certs/acme.json"
CERT_DIR="/tmp" # 在容器内的临时目录生成证书，不污染挂载卷
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"

# --- 1. 等待并验证 Traefik 的 acme.json 文件 ---
echo "正在等待 Traefik 生成证书文件: ${ACME_JSON_PATH}"
timeout=300
while [ ! -s "$ACME_JSON_PATH" ]; do
  sleep 2
  timeout=$((timeout - 2))
  if [ $timeout -le 0 ]; then
    echo "错误：等待证书超时！请检查 Traefik 日志以确定问题。"
    exit 1
  fi
done
echo "acme.json 已找到。"

# --- 2. 使用 jq 和 base64 从 acme.json 提取证书和私钥 ---
echo "正在从 acme.json 中为域名 [${DOMAIN}] 提取证书..."
# 提取证书 (先用jq找到匹配域名的证书对象,然后提取certificate字段,最后用base64解码)
jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .certificate' "$ACME_JSON_PATH" | base64 -d > "$CERT_FILE"
# 提取私钥 (同上,但提取key字段)
jq -r '.le.Certificates[] | select(.domain.main == "'$DOMAIN'") | .key' "$ACME_JSON_PATH" | base64 -d > "$KEY_FILE"

# 验证文件是否成功生成且不为空
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
  echo "错误：从 acme.json 提取证书失败！"
  echo "请确认您的域名 [${DOMAIN}] 是否正确，以及 Traefik 是否已成功为其申请到证书。"
  exit 1
fi
echo "证书和私钥已成功提取到 ${CERT_DIR}"

# --- 3. 生成 Hysteria 配置文件 ---
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

# --- 4. 启动 Hysteria 并生成分享链接 ---
hysteria server --config /etc/hysteria/config.json &

url_encode() {
    echo -n "$1" | sed -e 's|@|%40|g' -e 's|:|%3A|g' -e 's|/|%2F|g' -e 's|?|%3F|g' -e 's|#|%23|g' -e 's|&|%26|g' -e 's|=|%3D|g'
}
ENCODED_PASSWORD=$(url_encode "$PASSWORD")
ENCODED_OBFS_PASSWORD=$(url_encode "$OBFS_PASSWORD_VAL")
PUBLIC_PORT=443
HY2_LINK="hy2://${ENCODED_PASSWORD}@${DOMAIN}:${PUBLIC_PORT}?sni=${DOMAIN}&obfs=${OBFS_TYPE}&obfs-password=${ENCODED_OBFS_PASSWORD}"

echo "────────────────────────────────────────────────────────"
echo "  🎉 Hysteria2 通用分享链接 (已优化) 🎉"
echo
echo "  ${HY2_LINK}"
echo
echo "  服务器已成功启动！"
echo "────────────────────────────────────────────────────────"

wait