#!/usr/bin/env bash
# One-time host setup for Docker-based Jenkins + Nexus pipeline
set -euo pipefail

echo "=== CIS CI/CD Host Setup ==="

DOCKER_GID=$(getent group docker | cut -d: -f3)
echo "Docker group GID: $DOCKER_GID"

# 1. Allow Docker push to Nexus (insecure registry on HOST)
DAEMON_JSON="/etc/docker/daemon.json"
INSECURE='"192.168.0.125:8003"'

if [ -f "$DAEMON_JSON" ]; then
  if ! grep -q "192.168.0.125:8003" "$DAEMON_JSON"; then
    echo "Add 192.168.0.125:8003 to insecure-registries in $DAEMON_JSON manually"
  else
    echo "insecure-registries already configured"
  fi
else
  echo "Creating $DAEMON_JSON"
  sudo tee "$DAEMON_JSON" > /dev/null <<EOF
{
  "insecure-registries": ["192.168.0.125:8003"]
}
EOF
  sudo systemctl restart docker
fi

# 2. Rebuild Jenkins with Docker CLI + sonar-scanner
JENKINS_DIR="/opt/dependencies/jenkins"
if [ -d "$JENKINS_DIR" ]; then
  echo "Updating Jenkins at $JENKINS_DIR"
  sudo cp -r "$(dirname "$0")/jenkins/"* "$JENKINS_DIR/"
  cd "$JENKINS_DIR"
  export DOCKER_GID
  sudo -E docker compose up -d --build
else
  echo "Jenkins dir not found at $JENKINS_DIR - copy ci/jenkins/* there first"
fi

echo ""
echo "=== Correct URLs (verified on this server) ==="
echo "Jenkins UI:        http://192.168.0.125:8012"
echo "SonarQube UI:      http://192.168.0.125:8032"
echo "Nexus UI:          http://192.168.0.125:8002"
echo "Nexus Docker push: 192.168.0.125:8003"
echo ""
echo "Do NOT use ports 9002 or 8082 - those are wrong for this setup."
