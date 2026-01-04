#!/bin/bash
#
# IPsec VPN デバッグスクリプト
# コンテナの状態と接続状況を詳細に確認
#

echo "=========================================="
echo "IPsec VPN デバッグ情報"
echo "=========================================="
echo ""

# 1. コンテナの状態
echo "[1] コンテナ状態"
docker ps -a | grep ipsec-vpn-rtx1200
echo ""

# 2. pluto プロセスの確認
echo "[2] pluto (IKEv2 デーモン) プロセス"
docker exec ipsec-vpn-rtx1200 ps aux | grep pluto | grep -v grep || echo "! pluto が起動していません"
echo ""

# 3. ipsec ステータス
echo "[3] IPsec ステータス"
docker exec ipsec-vpn-rtx1200 ipsec status 2>&1 || echo "! ipsec コマンドが失敗しました"
echo ""

# 4. ipsec.conf の確認
echo "[4] ipsec.conf 設定確認"
docker exec ipsec-vpn-rtx1200 cat /etc/ipsec.conf 2>&1 | grep -A 30 "conn ikev2-rtx1200" || echo "! 設定ファイルが読めません"
echo ""

# 5. ipsec.secrets の確認 (PSK は隠す)
echo "[5] ipsec.secrets 確認 (PSK は非表示)"
docker exec ipsec-vpn-rtx1200 ls -la /etc/ipsec.secrets 2>&1
docker exec ipsec-vpn-rtx1200 grep -c PSK /etc/ipsec.secrets 2>&1 && echo "PSK エントリが存在します"
echo ""

# 6. pluto ログの確認
echo "[6] pluto ログ (最新 30 行)"
docker exec ipsec-vpn-rtx1200 tail -30 /var/log/pluto.log 2>&1 || echo "! ログファイルが見つかりません"
echo ""

# 7. ポート確認
echo "[7] ポート待受状態"
echo "UDP 500 (IKE):"
docker exec ipsec-vpn-rtx1200 netstat -uln 2>&1 | grep ":500 " || echo "! UDP 500 が待受していません"
echo "UDP 4500 (NAT-T):"
docker exec ipsec-vpn-rtx1200 netstat -uln 2>&1 | grep ":4500 " || echo "! UDP 4500 が待受していません"
echo ""

# 8. ホスト側のファイアウォール確認
echo "[8] ホスト側のポート開放状態"
if command -v ufw &> /dev/null; then
  echo "UFW ステータス:"
  sudo ufw status | grep -E "(500|4500)" || echo "UDP 500/4500 が見つかりません"
elif command -v firewall-cmd &> /dev/null; then
  echo "firewalld ステータス:"
  sudo firewall-cmd --list-all | grep -E "(500|4500)" || echo "UDP 500/4500 が見つかりません"
else
  echo "iptables ルール:"
  sudo iptables -L -n | grep -E "(500|4500)" || echo "特定のルールなし"
fi
echo ""

# 9. RTX1200 からの接続試行ログ
echo "[9] RTX1200 からの接続試行 (pluto ログから検索)"
docker exec ipsec-vpn-rtx1200 grep -i "received " /var/log/pluto.log 2>&1 | tail -10 || echo "接続試行が見つかりません"
echo ""

echo "=========================================="
echo "トラブルシューティングのヒント"
echo "=========================================="
echo ""
echo "✓ pluto が起動していない場合:"
echo "  → docker logs ipsec-vpn-rtx1200 で起動エラーを確認"
echo ""
echo "✓ ポートが待受していない場合:"
echo "  → コンテナを再起動: docker compose restart"
echo ""
echo "✓ RTX1200 からのパケットが届いていない場合:"
echo "  → ホストのファイアウォールを確認"
echo "  → RTX1200 の接続先 IP が正しいか確認"
echo ""
echo "✓ 接続試行はあるが認証失敗する場合:"
echo "  → PSK が一致しているか確認: ./show-psk.sh"
echo "  → ID (dam-server/dam-client) が一致しているか確認"
echo ""
echo "=========================================="
