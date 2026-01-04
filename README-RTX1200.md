# RTX1200 × Docker(libreswan) IKEv2 VPN サーバー

RTX1200 ルーター専用の IKEv2 IPsec VPN サーバーです。RTX1200 が対応している古い暗号方式（AES-CBC + HMAC-SHA1 + MODP1024）に完全対応しています。

## 特徴

- **RTX1200 完全互換**: AES-GCM、SHA2、MODP2048 を使用せず、RTX1200 が対応する暗号のみを使用
- **IKEv2 / PSK**: モダンな IKEv2 プロトコルを事前共有鍵で使用
- **NAT-T 対応**: UDP 4500 による NAT トラバーサル対応
- **固定 ID**: サーバー側 `dam-server`、クライアント側 `dam-client` で識別

## 暗号仕様

| 項目 | 設定値 |
|-----|-------|
| IKE バージョン | IKEv2 |
| 暗号化 | AES-CBC (128-bit) / 3DES |
| 認証 | HMAC-SHA1 |
| DH グループ | MODP1024 (Group 2) |
| ESP | AES-128-SHA1 / 3DES-SHA1 |
| NAT-T | 有効 (UDP 4500) |

## クイックスタート

### 1. コンテナのビルドと起動

PSK は初回起動時に**自動生成**されます:

```bash
# イメージをビルド
docker compose build

# コンテナを起動
docker compose up -d

# 自動生成された PSK を確認
./show-psk.sh
```

または、ログで直接確認:

```bash
docker logs ipsec-vpn-rtx1200 | grep "VPN IPsec PSK"
```

**重要**: 表示された PSK は必ず保存してください! RTX1200 の設定に必要です。

#### カスタム PSK を使用する場合

`docker-compose.yml` を編集:

```yaml
environment:
  VPN_IPSEC_PSK: "your-custom-strong-psk-here"
```

### 2. PSK の確認

```bash
# 簡単確認
./show-psk.sh

# または詳細ログ
docker logs ipsec-vpn-rtx1200
```

### 3. RTX1200 の設定

RTX1200 側で以下の設定を行います:

#### GUI 設定項目

| 項目 | 設定値 |
|-----|-------|
| IKE バージョン | IKEv2 |
| 接続先アドレス | サーバーのグローバル IP |
| ローカル識別子 | `dam-client` |
| リモート識別子 | `dam-server` |
| 事前共有鍵 | `.env` で設定した PSK |
| 暗号化アルゴリズム | AES-CBC (128-bit) |
| 認証アルゴリズム | HMAC-SHA1 |
| DH グループ | MODP1024 (グループ 2) |
| NAT トラバーサル | 有効 |

#### CLI 設定例 (参考)

```
# IKEv2 設定
ipsec ike payload type 1 ikev2
ipsec ike pre-shared-key 1 text [PSK]
ipsec ike local id 1 dam-client
ipsec ike remote id 1 dam-server
ipsec ike encryption 1 aes-cbc
ipsec ike hash 1 sha
ipsec ike group 1 modp1024
ipsec ike nat-traversal 1 on

# IPsec トンネル設定
ipsec sa policy 101 1 esp aes-cbc sha-hmac
tunnel select 1
 ipsec tunnel 101
 ipsec sa policy 101 1 out
 ipsec ike keepalive use 1 on heartbeat 1 30
 tunnel enable 1
```

### 4. 接続確認

#### Docker 側

```bash
# IPsec ステータス確認
docker exec ipsec-vpn-rtx1200 ipsec status

# IPsec SA 確認
docker exec ipsec-vpn-rtx1200 ipsec trafficstatus

# ログ確認
docker exec ipsec-vpn-rtx1200 tail -f /var/log/pluto.log
```

#### RTX1200 側

```
# ISAKMP SA 確認
show ipsec sa

# 接続状態確認
show status ipsec
```

成功すると以下のように表示されます:

```
ISAKMP SA の情報:
  送信元IPアドレス: xxx.xxx.xxx.xxx
  宛先IPアドレス: yyy.yyy.yyy.yyy
  状態: established
```

## トラブルシューティング

### 接続できない場合のチェックリスト

#### 1. ID の一致確認

- RTX1200 側: ローカル ID = `dam-client`、リモート ID = `dam-server`
- Docker 側: `/etc/ipsec.conf` で `leftid=@dam-server`, `rightid=@dam-client`

#### 2. PSK の一致確認

```bash
# Docker 側の PSK を確認 (セキュリティに注意)
docker exec ipsec-vpn-rtx1200 grep PSK /etc/ipsec.secrets
```

RTX1200 側と完全に一致していることを確認してください。

#### 3. 暗号方式の確認

```bash
# Docker 側の暗号設定を確認
docker exec ipsec-vpn-rtx1200 grep -A 5 "ike=" /etc/ipsec.conf
```

以下が表示されることを確認:
```
ike=aes128-sha1-modp1024,3des-sha1-modp1024
esp=aes128-sha1,3des-sha1
```

#### 4. ポートの開放確認

サーバー側で以下のポートが開放されていることを確認:

- **UDP 500**: IKE (鍵交換)
- **UDP 4500**: IPsec NAT-T (暗号化通信)

```bash
# ファイアウォール確認 (例: ufw)
sudo ufw status

# 必要に応じて開放
sudo ufw allow 500/udp
sudo ufw allow 4500/udp
```

#### 5. NAT-T の有効化確認

RTX1200 側:
```
show ipsec ike nat-traversal
```

Docker 側:
```bash
docker exec ipsec-vpn-rtx1200 grep encapsulation /etc/ipsec.conf
```

### よくあるエラー

#### "NO_PROPOSAL_CHOSEN"

**原因**: 暗号方式の不一致

**解決方法**:
1. RTX1200 側で AES-GCM や SHA2 を使用していないか確認
2. DH グループが MODP1024 (グループ 2) になっているか確認

#### "INVALID_ID_INFORMATION"

**原因**: ID の不一致

**解決方法**:
1. RTX1200: ローカル ID = `dam-client`
2. RTX1200: リモート ID = `dam-server`
3. ID の前に `@` をつけない (libreswan 側で自動付与)

#### "AUTHENTICATION_FAILED"

**原因**: PSK の不一致

**解決方法**:
1. RTX1200 と Docker の PSK が完全一致しているか確認
2. 特殊文字が正しくエスケープされているか確認

## ログの確認

### Docker ログ

```bash
# コンテナログ
docker logs -f ipsec-vpn-rtx1200

# Pluto (IKE デーモン) ログ
docker exec ipsec-vpn-rtx1200 tail -f /var/log/pluto.log

# デバッグモード (詳細ログ)
docker exec ipsec-vpn-rtx1200 ipsec auto --status
```

### RTX1200 ログ

```
# ログ表示
show log

# IPsec 関連のみ
show log | grep ipsec
```

## 設定のカスタマイズ

### VPN サブネットの変更

`ikev2-rtx1200.sh` の以下の行を編集:

```bash
VPN_SUBNET="10.117.142.0/24"  # 任意のサブネットに変更
```

### ID の変更

同じく `ikev2-rtx1200.sh`:

```bash
SERVER_ID="dam-server"  # サーバー側 ID
CLIENT_ID="dam-client"  # クライアント側 ID
```

変更後は再ビルドが必要です:

```bash
docker compose down
docker compose build
docker compose up -d
```

## セキュリティに関する注意

### MODP1024 の使用について

**警告**: MODP1024 (DH Group 2) は現代の基準では脆弱とされています。RTX1200 がこれしか対応していないため使用していますが、以下の対策を推奨します:

1. **強力な PSK を使用**: 最低 32 文字以上のランダム文字列
2. **定期的な PSK 変更**: 3〜6 ヶ月ごとに変更
3. **アクセス制限**: 必要な IP アドレスのみ許可
4. **ログ監視**: 不正アクセスの試行を監視

可能であれば、より新しいルーターへの移行を検討してください。

## ライセンス

このプロジェクトは元の [docker-ipsec-vpn-server](https://github.com/hwdsl2/docker-ipsec-vpn-server) をベースにしており、同じライセンス (Creative Commons Attribution-ShareAlike 3.0) が適用されます。

## 謝辞

- [Lin Song](https://github.com/hwdsl2) - オリジナルの docker-ipsec-vpn-server プロジェクト
- [Libreswan Project](https://libreswan.org/) - IPsec 実装
