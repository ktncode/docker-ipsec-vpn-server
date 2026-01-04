#!/bin/bash
#
# RTX1200 Compatible IKEv2 Setup Script
# For use with libreswan and RTX1200 router
#
# This script configures IPsec IKEv2 with legacy ciphers:
# - AES-CBC (no AES-GCM)
# - HMAC-SHA1 (no SHA2)
# - MODP1024 (no MODP2048)
#

set -e

# Parse arguments (support --auto for compatibility with run.sh)
AUTO_MODE=0
if [ "$1" = "--auto" ]; then
  AUTO_MODE=1
fi

# Use PSK from run.sh or vpn-gen.env
if [ -z "$VPN_IPSEC_PSK" ]; then
  # Try to load from vpn-gen.env (created by run.sh)
  if [ -f /etc/ipsec.d/vpn-gen.env ]; then
    echo "Loading PSK from vpn-gen.env..."
    . /etc/ipsec.d/vpn-gen.env
  fi
  
  # Still empty? Error
  if [ -z "$VPN_IPSEC_PSK" ]; then
    echo "ERROR: VPN_IPSEC_PSK not available"
    exit 1
  fi
fi

echo "Using PSK: ${VPN_IPSEC_PSK}"

# Configuration parameters
SERVER_ID="dam-server"
CLIENT_ID="dam-client"
VPN_SUBNET="10.117.142.0/24"

# Get public IP if provided
PUBLIC_IP="${VPN_PUBLIC_IP}"
if [ -z "$PUBLIC_IP" ]; then
  PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com 2>/dev/null || \
              curl -m 15 -fsS http://ipv4.icanhazip.com 2>/dev/null || \
              echo "YOUR_SERVER_IP")
fi

if [ "$AUTO_MODE" = 1 ]; then
  echo "=========================================="
  echo "RTX1200 Compatible IKEv2 Auto Setup"
  echo "=========================================="
else
  echo "=========================================="
  echo "RTX1200 Compatible IKEv2 Setup"
  echo "=========================================="
fi
echo "Server ID: @${SERVER_ID}"
echo "Client ID: @${CLIENT_ID}"
echo "VPN Subnet: ${VPN_SUBNET}"
echo "Public IP: ${PUBLIC_IP}"
echo "=========================================="

# Create ipsec.conf for RTX1200 compatibility
cat > /etc/ipsec.conf << EOF
# /etc/ipsec.conf - RTX1200 Compatible Configuration

version 2.0

config setup
  uniqueids=no
  logfile=/var/log/pluto.log
  logappend=yes
  logtime=yes
  plutodebug=none
  protostack=netkey
  virtual-private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12

conn ikev2-rtx1200
  auto=add
  ikev2=insist
  authby=secret
  rekey=yes
  
  # Left (Server) configuration
  left=%any
  leftid=@${SERVER_ID}
  leftsubnet=${VPN_SUBNET}
  leftsendcert=never
  
  # Right (Client - RTX1200) configuration
  # RTX1200 はアドレスで識別し、名前として dam-client を送信
  right=%any
  rightid=@${CLIENT_ID}
  rightsubnet=0.0.0.0/0
  
  # Legacy crypto for RTX1200 compatibility
  # NO AES-GCM, NO MODP2048
  # SHA-1 を優先、SHA-2 も対応（RTX1200 が対応していれば使用可能）
  ike=aes256-sha2_256-modp1024,aes128-sha2_256-modp1024,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024
  esp=aes256-sha2_256,aes128-sha2_256,aes256-sha1,aes128-sha1,3des-sha1
  
  # Phase 2 algorithm
  phase2alg=aes256-sha2_256,aes128-sha2_256,aes256-sha1,aes128-sha1,3des-sha1
  
  # NAT-T
  encapsulation=yes
  nat-ikev2-lanman=yes
  
  # DPD (Dead Peer Detection)
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
  
  # Lifetime
  ikelifetime=8h
  salifetime=3h
  
  # Misc
  type=tunnel
  compress=no

# Include additional IPsec configurations
include /etc/ipsec.d/*.conf
EOF

# Create ipsec.secrets
cat > /etc/ipsec.secrets << EOF
# /etc/ipsec.secrets - RTX1200 Compatible PSK

# PSK for RTX1200 connection
# RTX1200 はアドレスベースで識別するため、複数のパターンに対応
@${SERVER_ID} @${CLIENT_ID} : PSK "${VPN_IPSEC_PSK}"
@${SERVER_ID} %any : PSK "${VPN_IPSEC_PSK}"
%any @${CLIENT_ID} : PSK "${VPN_IPSEC_PSK}"
%any %any : PSK "${VPN_IPSEC_PSK}"

# Include additional secrets
include /etc/ipsec.d/*.secrets
EOF

# Set proper permissions
chmod 600 /etc/ipsec.secrets
chmod 644 /etc/ipsec.conf

# Create ikev2.conf marker file for run.sh
cat > /etc/ipsec.d/ikev2.conf << EOF
# IKEv2 configuration marker
# This file indicates that IKEv2 has been configured
# RTX1200 Compatible Mode
# Generated: $(date)
EOF

echo ""
echo "=========================================="
echo "Configuration files created successfully"
echo "=========================================="

if [ "$AUTO_MODE" = 1 ]; then
  # Output format expected by run.sh
  cat <<EOF

================================================
RTX1200 IKEv2 VPN Configuration
================================================

VPN server address: ${PUBLIC_IP}
VPN IPsec PSK: ${VPN_IPSEC_PSK}
Server identifier: @${SERVER_ID}
Client identifier: @${CLIENT_ID}

================================================
RTX1200 Configuration Guide:
================================================

1. IKE Version: IKEv2
2. Peer Address: ${PUBLIC_IP}
3. Local Identifier: ${CLIENT_ID}
4. Remote Identifier: ${SERVER_ID}
5. Pre-Shared Key: ${VPN_IPSEC_PSK}
6. Encryption: AES-CBC (128/256-bit) - GCM は使用不可
7. Authentication: HMAC-SHA256 (推奨) または HMAC-SHA1
8. DH Group: MODP1024 (Group 2)
9. NAT Traversal: Enabled
10. VPN Subnet: ${VPN_SUBNET}

Note: SHA-2 (SHA256) 対応。RTX1200 が SHA-2 に対応していない場合は自動的に SHA-1 にフォールバック

================================================
IMPORTANT: Save the PSK above!
You need it to configure your RTX1200 router.
================================================

Next steps: Configure your RTX1200 router with the above settings.

EOF
else
  echo ""
  echo "/etc/ipsec.conf:"
  cat /etc/ipsec.conf
  echo ""
  echo "=========================================="
  echo ""
  echo "/etc/ipsec.secrets: [hidden for security]"
  echo ""
  echo "=========================================="
  echo "Setup complete!"
  echo "=========================================="
  echo ""
  echo "RTX1200 Configuration checklist:"
  echo "  1. IKE: IKEv2"
  echo "  2. Peer: ${PUBLIC_IP}"
  echo "  3. Local ID: ${CLIENT_ID}"
  echo "  4. Remote ID: ${SERVER_ID}"
  echo "  5. Encryption: AES-CBC (128-bit)"
  echo "  6. Authentication: SHA-HMAC (SHA1)"
  echo "  7. DH Group: MODP1024 (Group 2)"
  echo "  8. NAT-T: ON"
  echo "  9. PSK: [Same as VPN_IPSEC_PSK]"
  echo "=========================================="
fi

