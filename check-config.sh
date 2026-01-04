#!/bin/bash
#
# IPsec 設定確認スクリプト
#

echo "=========================================="
echo "IPsec 設定ファイル確認"
echo "=========================================="
echo ""

echo "[1] /etc/ipsec.conf の内容"
docker exec ipsec-vpn-rtx1200 cat /etc/ipsec.conf
echo ""
echo "=========================================="
echo ""

echo "[2] /etc/ipsec.d/ikev2.conf の有無"
docker exec ipsec-vpn-rtx1200 ls -la /etc/ipsec.d/ikev2.conf 2>&1
echo ""

echo "[3] /etc/ipsec.d/ の内容"
docker exec ipsec-vpn-rtx1200 ls -la /etc/ipsec.d/
echo ""

echo "[4] ikev2-rtx1200 設定の検索"
docker exec ipsec-vpn-rtx1200 grep -r "ikev2-rtx1200" /etc/ipsec.* 2>&1
echo ""

echo "[5] 設定の再読み込み"
docker exec ipsec-vpn-rtx1200 ipsec auto --add ikev2-rtx1200 2>&1
echo ""

echo "=========================================="
