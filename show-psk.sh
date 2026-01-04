#!/bin/bash
#
# PSK 確認スクリプト
# 自動生成または設定された PSK を表示します
#

echo "=========================================="
echo "RTX1200 VPN - PSK 確認"
echo "=========================================="
echo ""

if docker ps | grep -q ipsec-vpn-rtx1200; then
  echo "コンテナは起動中です。"
  echo ""
  echo "自動生成された PSK を確認中..."
  echo ""
  
  # コンテナログから PSK を抽出
  PSK=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN IPsec PSK:" | tail -1 | sed 's/.*VPN IPsec PSK: //')
  
  if [ -n "$PSK" ]; then
    echo "================================================"
    echo "VPN IPsec PSK: ${PSK}"
    echo "================================================"
    echo ""
    echo "この PSK を RTX1200 の事前共有鍵として設定してください。"
  else
    echo "PSK が見つかりませんでした。"
    echo ""
    echo "完全なログを確認してください:"
    echo "  docker logs ipsec-vpn-rtx1200"
  fi
  
  echo ""
  echo "詳細な設定情報を表示:"
  docker logs ipsec-vpn-rtx1200 2>&1 | grep -A 20 "RTX1200 Configuration Guide"
  
else
  echo "エラー: コンテナ 'ipsec-vpn-rtx1200' が起動していません。"
  echo ""
  echo "以下のコマンドでコンテナを起動してください:"
  echo "  docker compose up -d"
fi

echo ""
echo "=========================================="
