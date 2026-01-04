#!/bin/bash
#
# RTX1200 接続デバッグ - リアルタイムログ監視
#

echo "================================================"
echo "RTX1200 接続デバッグ - ログ監視開始"
echo "================================================"
echo ""
echo "RTX1200 から接続を試みてください..."
echo "Ctrl+C で終了"
echo ""
echo "================================================"
echo ""

# pluto ログをリアルタイム監視
docker exec ipsec-vpn-rtx1200 tail -f /var/log/pluto.log | while read line; do
  # 重要なキーワードをハイライト
  if echo "$line" | grep -qi "received\|sending\|authenticated\|established\|failed\|error\|dam-client\|dam-server"; then
    echo "[$(date '+%H:%M:%S')] $line"
  fi
done
