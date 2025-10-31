#!/usr/bin/env bash
# =========================================================
# install_goad_light.sh
# Automated installer for GOAD-Light (VirtualBox + Vagrant)
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

# --- Install core dependencies ---
log "Installing dependencies (curl, wget, git, python3.11, pip, etc.)..."
apt install -y curl wget git gpg software-properties-common || err "Core dependency install failed"

# --- Install Python 3.11 and tools ---
if ! command -v python3.11 &>/dev/null; then
  log "Installing Python 3.11..."
  add-apt-repository -y ppa:deadsnakes/ppa
  apt update
  apt install -y python3.11 python3.11-venv python3.11-distutils || err "Python 3.11 installation failed"
else
  ok "Python 3.11 already installed."
fi

# Ensure pip for Python 3.11
if ! python3.11 -m pip --version &>/dev/null; then
  log "Installing pip for Python 3.11..."
  curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 || err "Pip installation for Python 3.11 failed"
fi
ok "Python 3.11 and pip ready."

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

# --- Set up Python 3.11 virtual environment ---
log "Creating Python 3.11 virtual environment..."
python3.11 -m venv "$GOAD_DIR/.venv" || err "Virtualenv creation failed"
source "$GOAD_DIR/.venv/bin/activate"

# --- Install Python requirements ---
log "Installing Python dependencies..."
python3.11 -m pip install --upgrade pip setuptools wheel || err "Pip upgrade failed"

REQ_FILE="$GOAD_DIR/requirements.txt"
if [[ ! -f "$REQ_FILE" ]]; then
  # fallback if repo uses requirements.yml
  REQ_FILE="$GOAD_DIR/requirements.yml"
fi

python3.11 -m pip install -r "$REQ_FILE" || err "Python dependencies failed"

# --- Install GOAD-Light lab ---
log "Starting GOAD-Light deployment..."
cd "$GOAD_DIR"
yes | python3.11 goad.py -t install -l "GOAD-Light" -p virtualbox -m local || err "GOAD-Light installation failed"

# --- Done ---
ok "GOAD-Light lab successfully deployed!"
ok "To start your lab later: cd $GOAD_DIR && source .venv/bin/activate && python3.11 goad.py -t start -l GOAD-Light"
ok "Installation complete. Log saved at: $LOGFILE"
