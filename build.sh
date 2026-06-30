#!/bin/bash
set -e

APP_NAME="MoYuPlayer"
APP_DIR="${APP_NAME}.app"
SRC_DIR="Sources"
BUILD_DIR="build"

echo "🔨 Compiling MoYuPlayer..."

mkdir -p "${BUILD_DIR}"

swiftc -o "${BUILD_DIR}/${APP_NAME}" \
  -framework AppKit \
  -framework AVKit \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework QuartzCore \
  "${SRC_DIR}/main.swift" \
  "${SRC_DIR}/Views.swift" \


echo "📦 Packaging into .app bundle..."

rm -rf "${BUILD_DIR}/${APP_DIR}"
mkdir -p "${BUILD_DIR}/${APP_DIR}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${BUILD_DIR}/${APP_DIR}/Contents/MacOS/"
cp Info.plist "${BUILD_DIR}/${APP_DIR}/Contents/"
cp Resources/AppIcon.icns "${BUILD_DIR}/${APP_DIR}/Contents/Resources/"

# Create PkgInfo
echo "APPL????" > "${BUILD_DIR}/${APP_DIR}/Contents/PkgInfo"

echo ""
echo "✅ Build complete!"
echo ""
echo "📁 App location: ${BUILD_DIR}/${APP_DIR}"
echo ""
echo "🚀 To launch:"
echo "   open ${BUILD_DIR}/${APP_DIR}"
echo ""
echo "💡 Or copy to Applications:"
echo "   cp -r ${BUILD_DIR}/${APP_DIR} /Applications/"
echo ""
echo "⌨️  Shortcuts:"
echo "   Cmd+O      Open Folder (load playlist)"
echo "   Cmd+T      Toggle Always on Top"
echo "   Cmd+]      More transparent"
echo "   Cmd+[      Less transparent"
echo "   Cmd+0      Reset transparency"
echo "   Space      Play/Pause"
echo "   Cmd+→      Next video"
echo "   Cmd+←      Previous video"
