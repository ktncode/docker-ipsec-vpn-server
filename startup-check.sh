#!/bin/bash
#
# VPN サーバー起動確認スクリプト
# コンテナ起動後に自動的に各種チェックを実行
#

set -e

echo ""
echo "================================================"
echo "VPN サーバー起動確認中..."
echo "================================================"
echo ""

# コンテナが起動するまで待機
echo "⏳ コンテナの起動を待機中..."
for i in {1..30}; do
  if docker ps | grep -q ipsec-vpn-rtx1200; then
    echo "✅ コンテナが起動しました"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ タイムアウト: コンテナが起動しません"
    exit 1
  fi
  sleep 1
done

# pluto の起動を待機
echo ""
echo "⏳ pluto (IKE デーモン) の起動を待機中..."
for i in {1..30}; do
  if docker exec ipsec-vpn-rtx1200 pgrep pluto >/dev/null 2>&1; then
    echo "✅ pluto が起動しました"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ タイムアウト: pluto が起動しません"
    exit 1
  fi
  sleep 1
done

# PSK が統一されているか確認
echo ""
echo "🔑 PSK の統一確認..."
L2TP_PSK=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "IPsec PSK:" | head -1 | sed 's/.*IPsec PSK: //')
IKEV2_PSK=$(docker logs ipsec-vpn-rtx1200 2>&1 | grep "VPN IPsec PSK:" | tail -1 | sed 's/.*VPN IPsec PSK: //')

if [ "$L2TP_PSK" = "$IKEV2_PSK" ]; then
  echo "✅ PSK が統一されています: ${L2TP_PSK}"
else
  echo "⚠️  警告: PSK が異なります"
  echo "   L2TP/IPsec PSK: ${L2TP_PSK}"
  echo "   IKEv2 PSK: ${IKEV2_PSK}"
fi

# ポートチェック
echo ""
echo "📡 ポート待受状態確認..."
ERRORS=0

if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":500 "; then
  echo "✅ UDP 500 (IKE) - 待受中"
else
  echo "❌ UDP 500 (IKE) - 待受していません"
  ERRORS=$((ERRORS + 1))
fi

if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":4500 "; then
  echo "✅ UDP 4500 (NAT-T) - 待受中"
else
  echo "❌ UDP 4500 (NAT-T) - 待受していません"
  ERRORS=$((ERRORS + 1))
fi

if docker exec ipsec-vpn-rtx1200 netstat -uln 2>/dev/null | grep -q ":1701 "; then
  echo "✅ UDP 1701 (L2TP) - 待受中"
else
  echo "❌ UDP 1701 (L2TP) - 待受していません"
  ERRORS=$((ERRORS + 1))
fi

# IPsec 設定の読み込み確認
echo ""
echo "🔐 IPsec 設定確認..."
LOADED=$(docker exec ipsec-vpn-rtx1200 ipsec status 2>/dev/null | grep "Total IPsec connections" | grep -oP 'loaded \K\d+')

if [ "${LOADED:-0}" -gt 0 ]; then
  echo "✅ IPsec 設定が読み込まれています (${LOADED} 個)"
else
  echo "❌ IPsec 設定が読み込まれていません"
  ERRORS=$((ERRORS + 1))
fi

# 設定ファイルの文法チェック
echo ""
echo "📝 設定ファイルの文法確認..."
if docker exec ipsec-vpn-rtx1200 ipsec addconn --checkconfig 2>&1 | grep -qi "fatal\|error"; then
  echo "❌ 設定ファイルにエラーがあります"
  docker exec ipsec-vpn-rtx1200 ipsec addconn --checkconfig 2>&1 | grep -i "fatal\|error"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ 設定ファイルは正常です"
fi

# 結果サマリー
echo ""
echo "================================================"
if [ $ERRORS -eq 0 ]; then
  echo "✅ すべてのチェックが成功しました!"
  echo "================================================"
  echo ""
  ./status.sh
  exit 0
else
  echo "❌ ${ERRORS} 個のエラーが見つかりました"
  echo "================================================"
  echo ""
  echo "トラブルシューティング:"
  echo "  docker logs ipsec-vpn-rtx1200"
  echo "  ./debug-vpn.sh"
  exit 1
fi
