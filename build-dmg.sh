#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'ERRO: compilação SwiftUI e geração de DMG requerem macOS.' >&2
  exit 1
fi
for tool in xcrun swiftc hdiutil codesign ditto; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERRO: $tool indisponível. Instale Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
  fi
done

APP_NAME='CNX Installer'
APP_PATH="$(pwd)/dist/$APP_NAME.app"
DMG_PATH="$(pwd)/dist/CNX-Installer-macOS-universal-v0.2.dmg"
STAGING="$(pwd)/dist/dmg-staging"
BUILD="$(pwd)/dist/build"
mkdir -p "$(pwd)/dist" "$BUILD"
rm -rf "$APP_PATH" "$STAGING"
rm -f "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$STAGING"

# Build nativo para os dois processadores; lipo junta o binário universal.
SDK="$(xcrun --sdk macosx --show-sdk-path)"
DEPLOY='13.0'
for ARCH in arm64 x86_64; do
  echo "Compilando para $ARCH..."
  xcrun swiftc -O -parse-as-library -target "${ARCH}-apple-macosx${DEPLOY}" \
    -sdk "$SDK" -framework SwiftUI -framework AppKit -framework CryptoKit \
    Sources/main.swift -o "$BUILD/CNXInstaller-$ARCH"
done
xcrun lipo -create "$BUILD/CNXInstaller-arm64" "$BUILD/CNXInstaller-x86_64" \
  -output "$APP_PATH/Contents/MacOS/CNXInstaller"
chmod +x "$APP_PATH/Contents/MacOS/CNXInstaller"
cp Info.plist "$APP_PATH/Contents/Info.plist"

# Se informado APPLE_SIGN_IDENTITY, assina com certificado Developer ID;
# caso contrário, assinatura ad hoc apenas para teste local.
IDENTITY="${APPLE_SIGN_IDENTITY:--}"
if [[ "$IDENTITY" == '-' ]]; then
  codesign --force --sign - "$APP_PATH"
  echo 'AVISO: assinatura ad hoc. O macOS pode bloquear a abertura em outros Macs.'
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP_PATH"
fi
codesign --verify --verbose=2 "$APP_PATH"
xcrun lipo -info "$APP_PATH/Contents/MacOS/CNXInstaller"

ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname 'CNX Installer' -srcfolder "$STAGING" -format UDZO \
  -imagekey zlib-level=9 -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"

# Notarização Apple opcional (Developer ID e perfil previamente configurados).
if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
  if [[ "$IDENTITY" == '-' ]]; then
    echo 'ERRO: notarização exige assinatura Developer ID.' >&2
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo ''
echo "DMG criado: $DMG_PATH"
echo "SHA-256: $(cat "$DMG_PATH.sha256")"
echo 'Para instalar: abrir DMG e arrastar CNX Installer para Applications.'
