set -e

BINARY_NAME="s1paneld"
BUILD_PATH=".build/release/$BINARY_NAME"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

SERVICE_NAME="s1paneld.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

SERVICE_USER="$(id -un)"

echo "Building..."
swift build -c release

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping service..."
    sudo systemctl stop "$SERVICE_NAME"
fi

echo "Installing..."
mkdir -p "$INSTALL_DIR"
cp "$BUILD_PATH" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

if [ ! -f "$SERVICE_PATH" ]; then
    echo "Creating systemd service..."

    sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=ACEMAGIC S1 Panel Daemon

[Service]
Type=simple
User=$SERVICE_USER
ExecStart=$INSTALL_PATH
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
fi

echo "Starting service..."
sudo systemctl start "$SERVICE_NAME"

sudo systemctl status "$SERVICE_NAME" --no-pager
