#!/bin/bash
# Xray VLESS+Reality 个人独享节点一键安装
# 用法: SSH 登录服务器后, 把本脚本内容一次性粘贴进去回车即可
set -e

echo "=== 1/5 安装 Xray ==="
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "=== 2/5 生成密钥 ==="
UUID=$(/usr/local/bin/xray uuid)
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private/{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/Public/{print $3}')
SHORT_ID=$(openssl rand -hex 8)
PORT=443
SNI="www.microsoft.com"

echo "=== 3/5 写配置 ==="
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID", "flow": "xtls-rprx-vision" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": [ "$SNI" ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [ "$SHORT_ID" ]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

echo "=== 4/5 放行防火墙并启动 ==="
ufw allow $PORT/tcp >/dev/null 2>&1 || true
systemctl enable xray >/dev/null 2>&1
systemctl restart xray
sleep 2

echo "=== 5/5 生成客户端链接 ==="
IP=$(curl -s --max-time 10 ipv4.icanhazip.com || hostname -I | awk '{print $1}')
LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#US-Node"
echo "$LINK" > /root/vless-link.txt
systemctl is-active --quiet xray && echo "Xray 运行中 ✓" || echo "Xray 启动失败, 请检查 journalctl -u xray"
echo ""
echo "================ 客户端导入链接 ================"
echo "$LINK"
echo "================================================="
echo "链接已保存到服务器 /root/vless-link.txt"
