#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

BUILD_UNIVERSAL=false
if [ "$1" == "--universal" ]; then
    BUILD_UNIVERSAL=true
fi

echo "🔨 Building jbar..."
if [ "$BUILD_UNIVERSAL" = true ]; then
    echo "🌐 Building Universal Binary (arm64 + x86_64)..."
    swift build -c release --arch arm64 --arch x86_64
    BIN_PATH=".build/apple/Products/Release/jbar"
else
    swift build -c release
    BIN_PATH=".build/release/jbar"
fi

APP_NAME="jbar.app"
APP_DIR="$DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating $APP_NAME bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/jbar"
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

echo "✍️ Signing application bundle..."
codesign --force --deep --sign - --identifier com.jbar.taskbar "$APP_DIR"

echo "✅ Successfully created & signed: $APP_DIR"
echo "👉 Run with: open $APP_DIR"
