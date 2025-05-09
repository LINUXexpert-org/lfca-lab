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
  apt-get -y install docker.io docker-compose
  git clone https://github.com/localstack/localstack.git /opt/localstack
  cd /opt/localstack && make infra
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
