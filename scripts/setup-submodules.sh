#!/bin/bash
set -e

# Navigate to project root (parent of scripts folder)
cd "$(dirname "$0")/.."

echo "===================================="
echo "Git Submodules Setup Script"
echo "===================================="
echo

echo "[1/3] Initializing and updating submodules..."
git submodule update --init --recursive
echo

echo "[2/3] Installing dependencies for each submodule..."
echo

echo "--- Installing dependencies for apps/web ---"
if [ -f "apps/web/package.json" ]; then
    cd apps/web
    npm install
    cd ../..
else
    echo "Skipping apps/web - package.json not found"
fi
echo

echo "--- Installing dependencies for apps/mobile ---"
if [ -f "apps/mobile/package.json" ]; then
    cd apps/mobile
    npm install
    cd ../..
else
    echo "Skipping apps/mobile - package.json not found"
fi
echo

echo "--- Installing dependencies for services/auth ---"
if [ -f "services/auth/package.json" ]; then
    cd services/auth
    npm install
    cd ../..
else
    echo "Skipping services/auth - package.json not found"
fi
echo

echo "--- Installing dependencies for gateway ---"
if [ -f "gateway/api-gateway/package.json" ]; then
    cd gateway/api-gateway
    npm install
    cd ../..
elif [ -f "gateway/package.json" ]; then
    cd gateway
    npm install
    cd ..
else
    echo "Skipping gateway - package.json not found"
fi
echo

echo "[3/3] Setup complete!"
echo
echo "===================================="
echo "All submodules are ready!"
echo "===================================="
