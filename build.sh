#!/bin/bash
# Builds "PDF Compare.app" with only the Command Line Tools (no Xcode needed).
#   bash build.sh                 -> build/PDF Compare.app
#   MIN_OS=26.0 bash build.sh     -> use if your SDK does not know macOS 27 yet
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="PDF Compare"
EXEC_NAME="PDFCompare"
BUNDLE_ID="com.example.pdfcompare"
VERSION="1.0"
MIN_OS="${MIN_OS:-27.0}"
ARCH="$(uname -m)"

OUT="build/${APP_NAME}.app"
rm -rf build
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" build/tmp

echo "==> Compiling (${ARCH}, macOS ${MIN_OS})"
swiftc -O -parse-as-library -swift-version 5 \
  -target "${ARCH}-apple-macos${MIN_OS}" \
  PDFCompareApp.swift CompareModel.swift ContentView.swift DiffEngine.swift \
  -o "$OUT/Contents/MacOS/${EXEC_NAME}"

echo "==> Generating icon"
swiftc -O make_icon.swift -o build/tmp/make_icon
build/tmp/make_icon build/tmp/AppIcon.iconset
iconutil -c icns build/tmp/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"

echo "==> Writing Info.plist"
cat > "$OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${EXEC_NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_OS}</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$OUT"

rm -rf build/tmp
echo "Done: $OUT"
echo "Run it with:  open \"$OUT\""
