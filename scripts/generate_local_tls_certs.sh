#!/usr/bin/env bash
# Generates self-signed TLS 1.3 SAN certificate for local LAN / city-pilot staging (fixes empty ./certs)
set -euo pipefail
DOMAIN="${1:-mizan.local}"
LAN_IP="${2:-127.0.0.1}"
mkdir -p ./certs
openssl req -x509 -nodes -days 365 -newkey rsa:4096   -keyout ./certs/privkey.pem   -out ./certs/fullchain.pem   -subj "/CN=${DOMAIN}/O=Mizan Local Pilot"   -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:${LAN_IP},IP:127.0.0.1"
chmod 600 ./certs/privkey.pem
echo "Generated local TLS certificate for ${DOMAIN} (${LAN_IP}) in ./certs/"
