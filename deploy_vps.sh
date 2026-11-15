#!/usr/bin/env bash
# ==============================================================================
# REGA (ڕێگا) — 1-Click Automated VPS Deployment Script
# Supports: Ubuntu 20.04 / 22.04 / 24.04 & Debian 11 / 12
# Repository: https://github.com/sarbastsoft1-coder/rega.git
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    REGA (ڕێگا) — VPS Full Ecosystem Deployment     ${NC}"
echo -e "${GREEN}====================================================${NC}"

# Detect Public IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "YOUR_SERVER_IP")

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo -e "${BLUE}[1/5] Detecting Environment...${NC}"
echo "Project Directory: $PROJECT_DIR"
echo "Public IP: $SERVER_IP"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo: sudo ./deploy_vps.sh${NC}"
  exit 1
fi

# Ask user for deployment method
echo ""
echo -e "${YELLOW}Select Deployment Mode:${NC}"
echo "1) Docker Compose (Recommended: Automated, Isolated & Zero host dependencies)"
echo "2) Native Host Setup (Installs PHP 8.2, PostgreSQL, Python3 & Systemd Services)"
read -p "Enter choice [1 or 2, default 1]: " DEPLOY_CHOICE
DEPLOY_CHOICE=${DEPLOY_CHOICE:-1}

# Open Firewall Ports
echo -e "${BLUE}[2/5] Configuring Firewall (UFW)...${NC}"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  ufw allow 8001/tcp || true # Backend API
  ufw allow 8080/tcp || true # Admin Web
  ufw allow 8081/tcp || true # Vendor Web
  ufw allow 8082/tcp || true # Customer Web
  ufw allow 8083/tcp || true # Delivery Web
  echo -e "${GREEN}Firewall ports opened successfully!${NC}"
fi

# ==============================================================================
# MODE 1: DOCKER COMPOSE
# ==============================================================================
if [ "$DEPLOY_CHOICE" = "1" ]; then
  echo -e "${BLUE}[3/5] Checking Docker & Docker Compose...${NC}"
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Installing Docker Compose plugin..."
    apt-get update && apt-get install -y docker-compose-plugin
  fi

  echo -e "${BLUE}[4/5] Building & Launching Docker Services...${NC}"
  docker compose down --remove-orphans || true
  docker compose up -d --build

  echo -e "${GREEN}Docker containers started successfully!${NC}"

# ==============================================================================
# MODE 2: NATIVE HOST SETUP
# ==============================================================================
else
  echo -e "${BLUE}[3/5] Installing Native Dependencies (PHP, PostgreSQL, Python)...${NC}"
  apt-get update
  apt-get install -y software-properties-common curl git unzip python3 python3-pip

  # Add Ondrej PHP PPA for Ubuntu
  if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    add-apt-repository -y ppa:ondrej/php
    apt-get update
  fi

  # Install PHP 8.2 and extensions
  apt-get install -y php8.2 php8.2-cli php8.2-fpm php8.2-pgsql php8.2-mbstring \
    php8.2-xml php8.2-curl php8.2-zip php8.2-bcmath php8.2-intl php8.2-gd

  # Install Composer
  if ! command -v composer >/dev/null 2>&1; then
    echo "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi

  # Install & Configure PostgreSQL
  apt-get install -y postgresql postgresql-contrib
  systemctl start postgresql
  systemctl enable postgresql

  echo "Configuring PostgreSQL database 'rega_db'..."
  sudo -u postgres psql -c "CREATE USER postgres WITH PASSWORD 'password123' SUPERUSER;" 2>/dev/null || true
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'password123';" 2>/dev/null || true
  sudo -u postgres psql -c "CREATE DATABASE rega_db OWNER postgres;" 2>/dev/null || true

  echo -e "${BLUE}[4/5] Setting up Laravel Backend...${NC}"
  cd "$PROJECT_DIR/rega_backend"

  if [ ! -f .env ]; then
    cp .env.example .env
  fi

  sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
  sed -i "s/DB_PORT=.*/DB_PORT=5432/" .env
  sed -i "s/DB_DATABASE=.*/DB_DATABASE=rega_db/" .env
  sed -i "s/DB_USERNAME=.*/DB_USERNAME=postgres/" .env
  sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=password123/" .env
  sed -i "s|APP_URL=.*|APP_URL=http://$SERVER_IP:8001|" .env

  composer install --no-dev --optimize-autoloader --no-interaction
  php artisan key:generate --force
  php artisan migrate --force
  php artisan db:seed --force
  php artisan storage:link || true
  chmod -R 777 storage bootstrap/cache

  cd "$PROJECT_DIR"

  # Setup systemd service for serve_all.py
  echo "Installing systemd service for REGA ecosystem..."
  cat <<EOF > /etc/systemd/system/rega.service
[Unit]
Description=REGA Unified Delivery Ecosystem
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 $PROJECT_DIR/serve_all.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable rega.service
  systemctl restart rega.service
  echo -e "${GREEN}REGA systemd service is active and running!${NC}"
fi

# ==============================================================================
# SUMMARY & ACCESS URLS
# ==============================================================================
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   🎉 REGA Ecosystem is LIVE on your VPS!           ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo ""
echo -e "🔹 ${YELLOW}Backend API Health:${NC}     http://$SERVER_IP:8001/api/health"
echo -e "🔹 ${YELLOW}Admin Control Center:${NC}   http://$SERVER_IP:8080"
echo -e "🔹 ${YELLOW}Vendor App (Froshyar):${NC}  http://$SERVER_IP:8081/?bypass=true"
echo -e "🔹 ${YELLOW}Customer Marketplace:${NC}   http://$SERVER_IP:8082/?bypass=true"
echo -e "🔹 ${YELLOW}Delivery Captain App:${NC}   http://$SERVER_IP:8083/?bypass=true"
if [ "$DEPLOY_CHOICE" = "1" ]; then
echo -e "🔹 ${YELLOW}Port 80 Unified Hub:${NC}    http://$SERVER_IP/"
fi
echo ""
echo -e "${GREEN}Default Seeded Credentials (Password: password123):${NC}"
echo "- Super Admin: 07700000001 (or admin@rega.iq)"
echo "- Vendor:      07701112233"
echo "- Delivery:    07501234567"
echo "- Customer:    07703331122"
echo ""
echo -e "${BLUE}Check Service Status:${NC}"
if [ "$DEPLOY_CHOICE" = "1" ]; then
  echo "  docker compose ps"
  echo "  docker compose logs -f"
else
  echo "  systemctl status rega.service"
  echo "  journalctl -u rega.service -f"
fi
echo -e "${GREEN}====================================================${NC}"
