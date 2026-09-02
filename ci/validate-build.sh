#!/usr/bin/env bash
# Run locally before pushing to Jenkins to verify artifacts and Docker builds
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Validating JAR artifacts ==="
JARS=(
  "CIS-Deployment/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar"
  "CIS-Deployment/connectEngine/device-connect-engine-0.0.1-SNAPSHOT.jar"
  "CIS-Deployment/visualizationEngine/device-visualization-engine-0.0.1-SNAPSHOT.jar"
  "CIS-Deployment/deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar"
)
for jar in "${JARS[@]}"; do
  if [[ -f "$jar" ]]; then
    echo "  OK  $jar"
  else
    echo "  MISSING  $jar"
    exit 1
  fi
done

echo ""
echo "=== Building Docker images (local test) ==="
cd CIS-Deployment
docker build -t cis-backend:test ./cisBackend
docker build -t cis-connect-engine:test ./connectEngine
docker build -t cis-visualization-engine:test ./visualizationEngine
docker build -t cis-device-simulation:test ./deviceSimulation
docker build -t cis-nginx:test -f nginx/Dockerfile.ci ./nginx

echo ""
echo "=== All validations passed ==="
