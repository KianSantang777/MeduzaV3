@echo off
REM Cross-Platform Build for protected_card
REM This script is for Windows. For Linux/macOS, use build_all.py
REM Requires: Python 3.8+, Cython, setuptools

echo ======================================
echo Windows Build Script
echo ======================================

REM Check Python version
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found in PATH
    exit /b 1
)

REM Install dependencies if missing
python -c "import Cython, setuptools" 2>nul
if errorlevel 1 (
    echo [INFO] Installing dependencies...
    pip install cython setuptools
)

REM Run the build
python build_all.py

echo ======================================
echo Build complete!
echo ======================================
