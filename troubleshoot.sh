#!/bin/bash
#
# RTX1200 接続失敗時のチェックリスト
#

echo "================================================"
echo "RTX1200 接続トラブルシューティング"
echo "================================================"
echo ""

PSK=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN IPsec PSK:" | tail -1 | sed 's/.*VPN IPsec PSK: //')
SERVER_IP=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN server address:" | tail -1 | sed 's/.*VPN server address: //')

echo "📋 チェック項目"
echo ""

echo "1️⃣  RTX1200 の接続先 IP アドレス"
echo "   期待値: ${SERVER_IP}"
echo "   確認: RTX1200 の設定で接続先が ${SERVER_IP} になっているか"
echo ""

echo "2️⃣  RTX1200 の PSK（事前共有鍵）"
echo "   期待値: ${PSK}"
echo "   確認: RTX1200 の PSK が完全に一致しているか（大文字小文字含む）"
echo ""

echo "3️⃣  RTX1200 の ID 設定"
echo "   ローカル ID: dam-client"
echo "   リモート ID: dam-server"
echo "   確認: RTX1200 の ID 設定が一致しているか"
echo ""

echo "4️⃣  RTX1200 の暗号化設定"
echo "   IKE 暗号化: AES-CBC (AES-GCM ではない!)"
echo "   IKE 認証: HMAC-SHA1 (SHA2 ではない!)"
echo "   DH グループ: MODP1024 (Group 2)"
echo "   ESP 暗号化: AES-CBC"
echo "   ESP 認証: HMAC-SHA1"
echo ""

echo "5️⃣  RTX1200 の NAT-T 設定"
echo "   NAT トラバーサル: ON (有効)"
echo ""

echo "6️⃣  サーバー側のファイアウォール"
echo "   UDP 500: "
if timeout 2 bash -c "nc -zvu ${SERVER_IP} 500 2>&1" | grep -q "succeeded\|open"; then
  echo "   ✅ 開放されています"
else
  echo "   ⚠️  確認できません（ホスト側で確認: sudo ufw status）"
fi

echo "   UDP 4500: "
if timeout 2 bash -c "nc -zvu ${SERVER_IP} 4500 2>&1" | grep -q "succeeded\|open"; then
  echo "   ✅ 開放されています"
else
  echo "   ⚠️  確認できません（ホスト側で確認: sudo ufw status）"
fi
echo ""

echo "================================================"
echo "📊 サーバー側の直近のログ（エラーのみ）"
echo "================================================"
docker exec ipsec-vpn-rtx1200 tail -50 /var/log/pluto.log | grep -i "error\|failed\|reject\|invalid" || echo "エラーログなし"
echo ""

echo "================================================"
echo "🔍 接続試行の検出"
echo "================================================"
echo "RTX1200 から接続を試みた形跡があるか確認..."
echo ""
if docker exec ipsec-vpn-rtx1200 grep -i "received.*IKE_SA_INIT" /var/log/pluto.log 2>&1 | tail -5 | grep -q "received"; then
  echo "✅ RTX1200 からの IKE パケットを受信しています"
  echo ""
  echo "最新の受信ログ:"
  docker exec ipsec-vpn-rtx1200 grep -i "received.*IKE_SA_INIT\|received.*ikev2" /var/log/pluto.log 2>&1 | tail -5
  echo ""
  echo "⚠️  パケットは届いているが接続が完了していません"
  echo "   → PSK または暗号化設定の不一致の可能性"
else
  echo "❌ RTX1200 からのパケットが届いていません"
  echo ""
  echo "考えられる原因:"
  echo "  1. RTX1200 の接続先 IP が間違っている"
  echo "  2. ホスト側のファイアウォールで UDP 500/4500 がブロックされている"
  echo "  3. ネットワーク経路上でブロックされている"
  echo ""
  echo "ホスト側のファイアウォール確認:"
  echo "  sudo iptables -L -n -v | grep -E '(500|4500)'"
  echo "  sudo ufw status"
fi
echo ""

echo "================================================"
echo "💡 次のステップ"
echo "================================================"
echo ""
echo "1. リアルタイムログ監視:"
echo "   ./watch-connection.sh"
echo "   (このコマンド実行後、RTX1200 から接続を試みる)"
echo ""
echo "2. RTX1200 側のログ確認:"
echo "   show log | grep ipsec"
echo ""
echo "3. RTX1200 側の接続状態:"
echo "   show ipsec sa"
echo ""
echo "================================================"
