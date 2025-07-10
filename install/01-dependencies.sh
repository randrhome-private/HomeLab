#!/bin/bash

set -e 

echo "[*] Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "[*] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "[*] Installing K3s (single-node cluster)..."
curl -sfL https://get.k3s.io | sh -

echo "[*] Exporting kubeconfig for kubectl..."
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "[*] Verifying K3s cluster status..."
kubectl get nodes


echo "[*] Installing Helm..."
./get_helm.sh

SOPS_VERSION="v3.8.1"

echo "[*] Installing age..."
# Fix missing GPG key for HashiCorp if present
if grep -q "apt.releases.hashicorp.com" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
  echo "[*] Re-adding HashiCorp GPG key..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
fi

apt-get update -qq
apt-get install -y --no-install-recommends curl tar gzip ca-certificates age

echo "[*] Installing sops..."
curl -sL -H "User-Agent: curl" \
  "https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64" \
  -o /usr/local/bin/sops
chmod +x /usr/local/bin/sops

echo "[+] Installation complete."
echo "[!] To generate your age key, run: age-keygen -o ~/.config/sops/age/keys.txt"


echo "[*] Installing AWS CLI v2 on Debian..."

# Install dependencies
apt-get update -qq
apt-get install -y unzip curl groff less

# Download AWS CLI v2 (latest stable)
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

cd -
rm -rf "$TMP_DIR"

echo "[+] AWS CLI installed as: $(command -v aws)"

# Prompt for AWS credentials and profile name
read -rp "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -rsp "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo
read -rp "Enter AWS CLI profile name to configure (e.g. default, sops-profile): " AWS_PROFILE

# Optionally prompt for session token (useful for assumed roles or MFA)
read -rp "Do you have a session token? [y/N]: " has_token
if [[ "$has_token" =~ ^[Yy]$ ]]; then
  read -rsp "Enter AWS Session Token: " AWS_SESSION_TOKEN
  echo
else
  AWS_SESSION_TOKEN=""
fi

# Setup profile
echo "[*] Configuring AWS CLI profile '$AWS_PROFILE'..."
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile "$AWS_PROFILE"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$AWS_PROFILE"
if [ -n "$AWS_SESSION_TOKEN" ]; then
  aws configure set aws_session_token "$AWS_SESSION_TOKEN" --profile "$AWS_PROFILE"
fi

echo "[+] AWS CLI profile '$AWS_PROFILE' is now configured."

# Verify identity
echo "[*] Testing AWS identity with profile '$AWS_PROFILE'..."
aws sts get-caller-identity --profile "$AWS_PROFILE"

echo "[+] Setting up Environment Variables for Authorized Access..."

# Set secret names
TAILSCALE_SECRET_NAME="Tailscale_Access"
SOPS_SECRET_NAME="HomeLabSOPKey"

# Fetch and parse Tailscale secrets
echo "[*] Fetching Tailscale secrets from AWS Secrets Manager..."
TS_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$TAILSCALE_SECRET_NAME" \
    --query SecretString \
    --output text \
    --profile default)

export TAILNET=$(echo "$TS_JSON" | jq -r '.TAILNET')
export AUTH_KEY=$(echo "$TS_JSON" | jq -r '.AUTH_KEY')
export API_KEY=$(echo "$TS_JSON" | jq -r '.API_KEY')

echo "[+] Tailscale secrets exported to environment."

# Fetch SOPS age key and write to file
echo "[*] Fetching SOPS age key..."
SOPS_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "$SOPS_SECRET_NAME" \
    --query SecretString \
    --output text \
    --profile default)

SOPS_KEY_FILE="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname "$SOPS_KEY_FILE")"
echo "$SOPS_KEY" > "$SOPS_KEY_FILE"
chmod 600 "$SOPS_KEY_FILE"

echo "[+] SOPS age key written to $SOPS_KEY_FILE"

