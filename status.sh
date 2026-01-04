#!/bin/bash
#
# VPN サーバー起動確認スクリプト
# ポート情報と接続方法を表示
#

echo ""
echo "================================================"
echo "RTX1200 VPN サーバー 起動確認"
echo "================================================"
echo ""

# コンテナの状態確認
if ! docker ps | grep -q ipsec-vpn-rtx1200; then
  echo "❌ コンテナが起動していません"
  echo ""
  echo "起動コマンド: docker compose up -d"
  exit 1
fi

echo "✅ コンテナは起動中です"
echo ""

# PSK 取得
PSK=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN IPsec PSK:" | tail -1 | sed 's/.*VPN IPsec PSK: //')
SERVER_IP=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN server address:" | tail -1 | sed 's/.*VPN server address: //')

echo "================================================"
echo "🔑 認証情報"
echo "================================================"
echo "サーバーアドレス: ${SERVER_IP}"
echo "事前共有鍵 (PSK): ${PSK}"
echo ""

echo "================================================"
echo "🌐 リッスンポート情報"
echo "================================================"
echo ""

# ポート確認
echo "📡 UDP 500 (IKE - 鍵交換)"
if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":500 "; then
  echo "   ✅ 待受中 - IKEv1/IKEv2 初期交渉用"
else
  echo "   ❌ 待受していません"
fi
echo ""

echo "📡 UDP 4500 (NAT-T - IPsec over NAT)"
if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":4500 "; then
  echo "   ✅ 待受中 - NAT越えの暗号化通信用"
else
  echo "   ❌ 待受していません"
fi
echo ""

echo "📡 UDP 1701 (L2TP)"
if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":1701 "; then
  echo "   ✅ 待受中 - L2TP/IPsec モード用"
else
  echo "   ❌ 待受していません"
fi
echo ""

# IPsec 接続状態
LOADED=$(docker exec ipsec-vpn-rtx1200 ipsec status 2>/dev/null | grep "Total IPsec connections" | grep -oP 'loaded \K\d+')
echo "================================================"
echo "🔐 IPsec 接続設定"
echo "================================================"
echo "設定ロード数: ${LOADED:-0} 個"
if [ "${LOADED:-0}" -gt 0 ]; then
  echo "   ✅ RTX1200 用設定が読み込まれています"
else
  echo "   ❌ 設定が読み込まれていません"
  echo "   → 設定を確認: ./check-config.sh"
fi
echo ""

echo "================================================"
echo "📱 RTX1200 接続モード"
echo "================================================"
echo ""
echo "🔹 モード 1: IKEv2 (推奨)"
echo "   使用ポート: UDP 500 + 4500"
echo "   暗号方式: AES-CBC + HMAC-SHA1 + MODP1024"
echo "   設定:"
echo "     - ローカル ID: dam-client"
echo "     - リモート ID: dam-server"
echo "     - PSK: ${PSK}"
echo ""
echo "🔹 モード 2: L2TP/IPsec"
echo "   使用ポート: UDP 500 + 4500 + 1701"
echo "   PSK: ${PSK}"
echo ""

echo "================================================"
echo "🔧 トラブルシューティング"
echo "================================================"
echo ""
echo "📋 ログ確認:"
echo "   docker logs -f ipsec-vpn-rtx1200"
echo ""
echo "🔍 詳細デバッグ:"
echo "   ./debug-vpn.sh"
echo ""
echo "🔑 PSK 再確認:"
echo "   ./show-psk.sh"
echo ""
echo "⚙️  設定確認:"
echo "   ./check-config.sh"
echo ""
echo "================================================"
