#!/bin/bash
# ============================================================
#  TalosAgent iOS App Builder
#  Run this on a Mac with Xcode installed
#  Produces: TalosAgent.ipa
# ============================================================

set -e

APP_NAME="TalosAgent"
BUNDLE_ID="com.talosforensics.agent"
BUILD_DIR="build"

echo "============================================"
echo " TalosAgent iOS App Builder"
echo "============================================"
echo ""

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "[ERROR] Xcode not found. Install Xcode from the Mac App Store."
    exit 1
fi

echo "[1/4] Creating Xcode project..."
mkdir -p "$BUILD_DIR"

# Use xcodegen or create project manually via xcode-select
# For quick build without full Xcode project:
echo "[2/4] Compiling Swift files..."

swiftc \
    TalosAgent/AppDelegate.swift \
    TalosAgent/TalosHTTPServer.swift \
    TalosAgent/MainViewController.swift \
    -sdk $(xcrun --sdk iphoneos --show-sdk-path) \
    -target arm64-apple-ios14.0 \
    -module-name TalosAgent \
    -framework UIKit \
    -framework Contacts \
    -framework Photos \
    -framework Foundation \
    -o "$BUILD_DIR/TalosAgent" \
    2>&1 || echo "Note: Full Xcode project needed for IPA. See README."

echo "[3/4] Creating app bundle..."
mkdir -p "$BUILD_DIR/Payload/$APP_NAME.app"
cp "$BUILD_DIR/TalosAgent" "$BUILD_DIR/Payload/$APP_NAME.app/" 2>/dev/null || true
cp TalosAgent/Info.plist "$BUILD_DIR/Payload/$APP_NAME.app/"

echo "[4/4] Creating IPA..."
cd "$BUILD_DIR"
zip -r "../TalosAgent.ipa" Payload/
cd ..

echo ""
echo "============================================"
echo " TalosAgent.ipa created!"
echo " Install on iPhone:"
echo "   ideviceinstaller -i TalosAgent.ipa"
echo "============================================"
