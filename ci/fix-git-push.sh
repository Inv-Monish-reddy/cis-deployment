#!/usr/bin/env bash
# Fix git push - remove JAR binaries from history and push clean repo to GitHub
set -euo pipefail

cd /opt/deployment/CIS-Deployment

echo "=== Creating clean branch without JAR files ==="

# Save current branch name
CURRENT=$(git branch --show-current)

# Create orphan branch (no history = no large JAR files)
git checkout --orphan clean-main
git reset

# Stage all files (gitignore excludes *.jar)
git add -A

echo ""
echo "=== Files to be committed (should have NO .jar files) ==="
git status --short | head -30
JAR_COUNT=$(git status --short | grep -c '\.jar' || true)
if [ "$JAR_COUNT" -gt 0 ]; then
    echo "ERROR: JAR files still staged! Check .gitignore"
    exit 1
fi
echo "No JAR files staged - OK"

git commit -m "CIS deployment with CI/CD pipeline (binaries excluded)"

# Replace main branch
git branch -D main 2>/dev/null || true
git branch -m main

echo ""
echo "=== Pushing to GitHub ==="
git push -u origin main --force

echo ""
echo "=== Done! ==="
echo "JAR files remain on disk at /opt/deployment/CIS-Deployment but are NOT in Git."
echo "Jenkins pipeline will copy JARs from local path during build."
