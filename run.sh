#!/usr/bin/env bash
# =========================================================
# install_goad_light.sh
# Automated installer for GOAD-Light (VirtualBox + Vagrant)
# Author: Jaideep (customized by ChatGPT)
# =========================================================

set -euo pipefail
LOGFILE="/var/log/goad-install.log"
: > "$LOGFILE"

log() { echo -e "[+] $*" | tee -a "$LOGFILE"; }
ok()  { echo -e "[✔] $*" | tee -a "$LOGFILE"; }
err() { echo -e "[✘] $*" | tee -a "$LOGFILE"; exit 1; }

GOAD_DIR="/home/mahe/GOAD"

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (sudo bash install_goad_light.sh)"
  exit 1
fi

# --- Update system ---
log "Updating package lists..."
apt update -y && apt upgrade -y

# --- Install dependencies ---
log "Installing dependencies (curl, wget, git, python3, pip, etc.)..."
apt install -y curl wget git python3 python3-venv python3-pip gpg software-properties-common || err "Dependency install failed"

# --- Install VirtualBox ---
if ! command -v VBoxManage &> /dev/null; then
  log "Installing VirtualBox..."
  apt install -y virtualbox || err "VirtualBox install failed"
else
  ok "VirtualBox already installed."
fi

# --- Install Vagrant (from HashiCorp repo) ---
if ! command -v vagrant &> /dev/null; then
  log "Installing Vagrant from HashiCorp repo..."
  wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list
  apt update && apt install -y vagrant || err "Vagrant install failed"
else
  ok "Vagrant already installed."
fi

# --- Install Vagrant plugins ---
log "Installing Vagrant plugins..."
vagrant plugin install vagrant-reload vagrant-vbguest winrm winrm-fs winrm-elevated || err "Vagrant plugin installation failed"
ok "All Vagrant plugins installed."

# --- Clone GOAD repository ---
if [[ -d "$GOAD_DIR" ]]; then
  log "Existing GOAD directory found. Renaming to GOAD_OLD..."
  mv "$GOAD_DIR" "${GOAD_DIR}_OLD_$(date +%s)"
fi
log "Cloning GOAD repository..."
git clone https://github.com/Jaideep02/GOAD.git "$GOAD_DIR" || err "Git clone failed"

# --- Set up Python virtual environment ---
log "Creating Python virtual environment..."
python3 -m venv "$GOAD_DIR/.venv" || err "Virtualenv creation failed"
source "$GOAD_DIR/.venv/bin/activate"

# --- Install Python requirements ---
log "Installing Python dependencies..."
python3 -m pip install --upgrade pip setuptools wheel || err "Pip upgrade failed"
python3 -m pip install -r "$GOAD_DIR/requirements.txt" || err "Python dependencies failed"

# --- Install GOAD-Light lab ---
log "Starting GOAD-Light deployment..."
cd "$GOAD_DIR"
yes | python3 goad.py install --lab "GOAD-Light" --provider virtualbox --noninteractive || err "GOAD-Light installation failed"

# --- Done ---
ok "GOAD-Light lab successfully deployed!"
ok "To start your lab later: cd $GOAD_DIR && ./goad.sh start"
ok "Installation complete. Log saved at: $LOGFILE"
