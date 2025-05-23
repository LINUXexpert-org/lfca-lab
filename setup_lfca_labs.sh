#!/usr/bin/env bash
# setup_lfca_labs.sh – provision practice labs for every LFCA domain
# Tested on Ubuntu 22.04 (run with sudo)

set -euo pipefail

LOG=/var/log/lfca_lab_setup.log
exec > >(tee -a "$LOG") 2>&1

linux_fundamentals() {
  echo "[*] Linux Fundamentals lab"
  useradd -m student
  mkdir -p /lab/linux/{files,processes}
  touch /lab/linux/files/{alpha,beta,gamma}.txt
  dd if=/dev/zero of=/lab/linux/files/dummy.img bs=1M count=5
}

sysadmin_fundamentals() {
  echo "[*] System Admin lab"
  apt-get update && apt-get -y install htop net-tools
  useradd -m backup && echo "backup ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/backup
  systemctl enable --now ssh
}

cloud_fundamentals() {
  echo "[*] Cloud Fundamentals lab"

  # 1. Make sure basic Docker engine is present
  apt-get update
  apt-get -y install docker.io curl gnupg lsb-release

  # 2. Try to install the v2 compose plugin from Ubuntu (requires 'universe')
  add-apt-repository -y universe          # no‑op if already enabled
  apt-get update
  if ! apt-get -y install docker-compose-plugin; then
      echo "[*] Ubuntu package not found; switching to Docker’s official repo"

      # 3. Add Docker’s official APT repository
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
           | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get -y install docker-ce-plugin docker-compose-plugin || true
  fi

  # 4. Final fallback: standalone docker‑compose binary
  if ! command -v docker compose &>/dev/null; then
      echo "[*] Installing standalone docker‑compose"
      COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
                         | grep -m1 '"tag_name":' | cut -d '"' -f 4)
      curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
           -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  fi

  # 5. Enable & start Docker
  systemctl enable --now docker

  # 6. Build a minimal LocalStack lab
  mkdir -p /opt/localstack-lab && cd /opt/localstack-lab

  cat <<'EOF' > docker-compose.yml
version: "3.3"
services:
  localstack:
    image: localstack/localstack:latest
    container_name: localstack
    ports:
      - "4566:4566"
      - "4571:4571"
    environment:
      - SERVICES=s3,lambda,cloudwatch,iam,dynamodb
      - DEBUG=1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
EOF

  # Use whichever Compose command is available
  if command -v docker compose &>/dev/null; then
      docker compose up -d
  else
      docker-compose up -d
  fi

  echo "✅  LocalStack is coming up on ports 4566/4571"
}

security_fundamentals() {
  echo "[*] Security Fundamentals lab"
  apt-get -y install fail2ban ufw
  ufw allow OpenSSH
  ufw enable
  echo "AllowUsers student" >> /etc/ssh/sshd_config && systemctl restart ssh
}

devops_fundamentals() {
  echo "[*] DevOps Fundamentals lab"
  apt-get -y install git
  su - student -c "git clone https://github.com/docker/getting-started.git ~/demo && cd ~/demo"
  docker run -d -p 8080:80 docker/getting-started
}

supporting_apps() {
  echo "[*] Supporting Applications lab"
  apt-get -y install build-essential jq
  mkdir -p /lab/apps && cd /lab/apps
  cat <<'EOF' > hello.py
print("Hello from LFCA lab")
EOF
}

main() {
  linux_fundamentals
  sysadmin_fundamentals
  cloud_fundamentals
  security_fundamentals
  devops_fundamentals
  supporting_apps
  echo "✅  All labs provisioned. Check /lab and ports 8080/4566."
}

main "$@"
