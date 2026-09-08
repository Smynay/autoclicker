#!/bin/bash
# Сборка меню-бар автокликера в .app бандл
set -euo pipefail

APP_NAME="AutoClicker"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

# Компиляция
swiftc -O "$ROOT/src/AutoclickerApp.swift" \
  -o "$CONTENTS_DIR/MacOS/$APP_NAME" \
  -framework Cocoa -framework Carbon

# Иконки: статусбар (template-чёрный) + набор для icns
swiftc -O "$ROOT/src/IconGen.swift" -o "$BUILD_DIR/icongen" -framework AppKit
"$BUILD_DIR/icongen" 32 "$CONTENTS_DIR/Resources/statusbar.png" status
"$BUILD_DIR/icongen" 64 "$CONTENTS_DIR/Resources/statusbar@2x.png" status
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  "$BUILD_DIR/icongen" "$s" "$ICONSET/icon_${s}x${s}.png" app
  d=$((s * 2))
  [ "$d" -le 512 ] && "$BUILD_DIR/icongen" "$d" "$ICONSET/icon_${s}x${s}@2x.png" app
done
iconutil -c icns "$ICONSET" -o "$CONTENTS_DIR/Resources/AutoClicker.icns"
xattr -c "$CONTENTS_DIR/MacOS/$APP_NAME" 2>/dev/null

# Info.plist: LSUIElement = приложение живёт только в строке меню
cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>AutoClicker</string>
    <key>CFBundleDisplayName</key>
    <string>AutoClicker</string>
    <key>CFBundleIdentifier</key>
    <string>local.autoclicker.app</string>
    <key>CFBundleExecutable</key>
    <string>AutoClicker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AutoClicker</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ад-хок подпись (нужна для запуска) — без неё Accessibility молча отваливается.
# iCloud-синхронизируемая папка налепляет xattr'ы, ломающие codesign — подписываем в tmp
STAGE=$(mktemp -d /var/folders/79/jcd45b5x7jj82bf0fl2ltx9h0000gn/T/opencode/acbuild.XXXX)
cp -Rp "$APP_DIR" "$STAGE/"
find "$STAGE" -exec xattr -c {} \; 2>/dev/null
codesign --force --sign - --identifier local.autoclicker.app "$STAGE/$APP_NAME.app" || exit 1
codesign --verify --strict "$STAGE/$APP_NAME.app" || exit 1
codesign -dv "$STAGE/$APP_NAME.app" 2>&1 | grep -q "Info.plist=not bound" && { echo "SIGN BROKEN"; exit 1; }
cp -Rp "$STAGE/$APP_NAME.app" "$BUILD_DIR/"
find "$APP_DIR" -exec xattr -c {} \; 2>/dev/null
codesign --verify --strict "$APP_DIR" || exit 1
rm -rf "$STAGE"

echo "✅ Собрано: $APP_DIR"
echo "Запуск: open '$APP_DIR'"
