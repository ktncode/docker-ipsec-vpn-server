#!/bin/bash
#
# ホスト側のネットワーク設定スクリプト
# RTX1200 から 10.117.142.0/24 へのアクセスを可能にする
#

echo "=========================================="
echo "ホストネットワーク設定確認"
echo "=========================================="

# 1. IP フォワーディングの確認と有効化
echo ""
echo "[1] IP フォワーディング設定"
current=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$current" = "1" ]; then
  echo "✓ IP フォワーディングは既に有効です"
else
  echo "! IP フォワーディングが無効です。有効化します..."
  sudo sysctl -w net.ipv4.ip_forward=1
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
  echo "✓ IP フォワーディングを有効化しました"
fi

# 2. 10.117.142.0/24 インターフェースの確認
echo ""
echo "[2] 10.117.142.0/24 ネットワークインターフェース確認"
if ip addr show | grep -q "10.117.142"; then
  echo "✓ 10.117.142.0/24 が見つかりました:"
  ip addr show | grep -A 2 "10.117.142"
else
  echo "✗ 警告: 10.117.142.0/24 が見つかりません"
  echo "  以下のインターフェースが存在します:"
  ip addr show | grep "inet " | grep -v "127.0.0.1"
fi

# 3. ルーティングテーブルの確認
echo ""
echo "[3] ルーティングテーブル"
echo "10.117.142.0/24 関連のルート:"
ip route | grep "10.117.142" || echo "  (該当なし)"

# 4. DAM ROUTER (172.27.11.x) へのルート確認
echo ""
echo "[4] 172.27.11.0/24 ネットワーク確認"
if ip route | grep -q "172.27.11"; then
  echo "✓ 172.27.11.0/24 へのルートが見つかりました:"
  ip route | grep "172.27.11"
else
  echo "! 172.27.11.0/24 へのルートが見つかりません"
  echo "  DAM ROUTER へのルートが必要な場合は追加してください"
fi

# 5. iptables NAT 設定の確認
echo ""
echo "[5] iptables NAT 設定"
if sudo iptables -t nat -L POSTROUTING -n -v | grep -q "10.117.142"; then
  echo "✓ 10.117.142.0/24 用の NAT ルールが存在します"
else
  echo "! 10.117.142.0/24 用の NAT ルールが見つかりません"
  echo "  必要に応じて以下のコマンドで追加:"
  echo "  sudo iptables -t nat -A POSTROUTING -s 10.117.142.0/24 -j MASQUERADE"
fi

echo ""
echo "=========================================="
echo "設定確認完了"
echo "=========================================="
