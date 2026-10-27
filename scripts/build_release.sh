#!/bin/bash
# Compila a app em Release, assina ad-hoc (incluindo os componentes do Sparkle) e cria o DMG.
#
# Uso: scripts/build_release.sh <versão> <build>
#   ex.: scripts/build_release.sh 0.1.0 42
# Resultado: build/release/Afina-<versão>.dmg
set -euo pipefail

VERSION="$1"
BUILD="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
DERIVED="$OUT/DerivedData"
APP="$DERIVED/Build/Products/Release/Afina.app"
DMG="$OUT/Afina-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild \
  -project "$ROOT/Afina.xcodeproj" \
  -scheme Afina \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=macOS' \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  build > "$OUT/xcodebuild.log" || { tail -50 "$OUT/xcodebuild.log"; exit 1; }
test -d "$APP"

# Assinatura ad-hoc pela ordem recomendada pelo Sparkle (de dentro para fora).
# Sem Developer ID, "-" é a única identidade; o Sparkle valida as atualizações pela assinatura EdDSA.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign -f -s - -o runtime "$SPARKLE/XPCServices/Installer.xpc"
codesign -f -s - -o runtime --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
codesign -f -s - -o runtime "$SPARKLE/Autoupdate"
codesign -f -s - -o runtime "$SPARKLE/Updater.app"
codesign -f -s - -o runtime "$APP/Contents/Frameworks/Sparkle.framework"

# Entitlements com as variáveis do Xcode já resolvidas, tal como ficaram na build
ENTITLEMENTS="$OUT/Afina.entitlements"
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS"
codesign -f -s - -o runtime --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict "$APP"

# DMG com atalho para Aplicações
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Afina" -srcfolder "$STAGING" -ov -format UDZO "$DMG" > /dev/null
rm -rf "$STAGING"

echo "$DMG"
