#!/bin/bash
set -euo pipefail

echo "=== ADS-B Monitoring Scripts Installation ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run as root (sudo ./install.sh)"
  exit 1
fi

# Configuration
read -p "Enter your Telegram Bot Token: " BOT_TOKEN
read -p "Enter your Telegram Chat ID: " CHAT_ID

# Create config file
cat > /etc/telegram-bot.conf << EOF
TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
TELEGRAM_CHAT_ID="$CHAT_ID"
EOF

chmod 600 /etc/telegram-bot.conf
chown root:root /etc/telegram-bot.conf
echo "✓ Config file created: /etc/telegram-bot.conf"

# Copy scripts
echo
echo "Installing scripts to /usr/local/sbin/..."
for script in feeder-watchdog wartungs-watchdog claude-respond-to-reports \
              telegram-bot-daemon telegram-secretary do-queue-worker \
              sd-health-check telegram-notify telegram-ask; do
  if [ -f "$script" ]; then
    # Replace placeholders with actual values
    sed "s/YOUR_BOT_TOKEN_HERE/$BOT_TOKEN/g; s/YOUR_CHAT_ID_HERE/$CHAT_ID/g" \
      "$script" > "/usr/local/sbin/$script"
    chmod +x "/usr/local/sbin/$script"
    echo "  ✓ $script"
  fi
done

# Create log directories
mkdir -p /var/log/claude-maintenance
chown pi:pi /var/log/claude-maintenance
mkdir -p /var/lib/claude-pending
chown pi:pi /var/lib/claude-pending
echo "✓ Log directories created"

# Install systemd units (optional)
echo
read -p "Install systemd timers? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  cp systemd/*.timer systemd/*.service /etc/systemd/system/
  systemctl daemon-reload
  echo "✓ Systemd units installed"
  
  read -p "Enable and start timers now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl enable --now feeder-watchdog.timer
    systemctl enable --now wartungs-watchdog.timer
    systemctl enable --now claude-daily-maintenance.timer
    echo "✓ Timers enabled and started"
  fi
fi

echo
echo "=== Installation Complete ==="
echo
echo "Next steps:"
echo "1. Customize FEEDERS variable in /usr/local/sbin/feeder-watchdog"
echo "2. Check logs: tail -f /var/log/feeder-watchdog.log"
echo "3. Test: sudo systemctl start feeder-watchdog.service"
echo
echo "Systemd status:"
echo "  systemctl status feeder-watchdog.timer"
echo "  systemctl status wartungs-watchdog.timer"
