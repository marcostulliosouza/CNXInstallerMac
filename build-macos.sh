#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v swiftc >/dev/null 2>&1; then
  echo "Instale as ferramentas Apple: xcode-select --install" >&2
  exit 1
fi
mkdir -p dist/CNX\ Installer.app/Contents/MacOS
swiftc -O -parse-as-library -framework SwiftUI -framework AppKit -framework CryptoKit \
  Sources/main.swift -o "dist/CNX Installer.app/Contents/MacOS/CNXInstaller"
cp Info.plist "dist/CNX Installer.app/Contents/Info.plist"
chmod +x "dist/CNX Installer.app/Contents/MacOS/CNXInstaller"
/usr/bin/codesign --force --sign - "dist/CNX Installer.app"
echo "Aplicativo gerado em: $(pwd)/dist/CNX Installer.app"
echo "Esta assinatura local (ad hoc) não equivale à assinatura/notarização Apple para distribuição pública."
