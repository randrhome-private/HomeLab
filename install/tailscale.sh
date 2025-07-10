#!/bin/bash
set -euo pipefail

sudo apt update && sudo apt upgrade -y
sudo apt update && sudo apt install -y jq

curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname=homelab-1

AUTHKEY=$(curl -s -X POST "https://api.tailscale.com/api/v2/tailnet/$TAILNET/ke>
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":true,">
  | jq -r .key)

 sudo tailscale up --authkey "$AUTHKEY" --hostname=homelab-1 --ssh

sudo systemctl status tailscaled

