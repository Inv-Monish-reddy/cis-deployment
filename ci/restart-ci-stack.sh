#!/usr/bin/env bash
# Restart CI stack and verify Nexus Docker registry is ready
set -euo pipefail

echo "=== 1. Start all CI containers ==="
cd /opt/dependencies/nexus && docker compose up -d
cd /opt/dependencies/sonarqube && docker compose up -d
cd /opt/dependencies/jenkins && docker compose up -d

echo ""
echo "=== 2. Wait for Nexus Docker registry (port 8003) ==="
for i in $(seq 1 60); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8003/v2/ 2>/dev/null || echo "000")
  if [ "$CODE" = "401" ] || [ "$CODE" = "200" ]; then
    echo "Nexus Docker registry is ready (HTTP $CODE)"
    break
  fi
  echo "  waiting... ($i/60) got HTTP $CODE"
  sleep 5
done

echo ""
echo "=== 3. Docker insecure registries ==="
docker info 2>/dev/null | grep -A3 'Insecure Registries' || echo "Run: sudo docker info | grep -A3 Insecure"

echo ""
echo "=== 4. Container status ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "=== 5. Test docker login ==="
echo "Run manually:"
echo "  docker login 192.168.0.125:8003 -u admin"
echo ""
echo "Expected: Login Succeeded"
echo "If you see HTTPS error, run: sudo systemctl restart docker && wait 30s && retry"
