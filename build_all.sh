#!/bin/bash
# Cross-Platform Build for protected_card
# For Linux/macOS. For Windows, use build_all.bat

set -e

echo "======================================"
echo "Linux/macOS Build Script"
echo "======================================"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python3 not found"
    exit 1
fi

# Install dependencies
echo "[INFO] Checking dependencies..."
python3 -c "import Cython, setuptools" 2>/dev/null || {
    echo "[INFO] Installing dependencies..."
    pip3 install cython setuptools
}

# Run build
python3 build_all.py

echo "======================================"
echo "Build complete!"
echo "======================================"
