#!/usr/bin/env bash
# Sobe o servidor do jogo numa máquina Linux (VPS).
# Uso: ./server/rodar_servidor.sh [quantidade_de_bots]
# Libere a porta 7777 UDP no firewall da VPS.
set -e
BOTS="${1:-4}"
VER="4.3"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

ARCH="$(uname -m)"
if [ "$ARCH" = "aarch64" ]; then
  FILE="Godot_v${VER}-stable_linux.arm64"
else
  FILE="Godot_v${VER}-stable_linux.x86_64"
fi

if [ ! -f "server/$FILE" ]; then
  echo "Baixando Godot ${VER} ($ARCH)..."
  wget -q "https://github.com/godotengine/godot/releases/download/${VER}-stable/${FILE}.zip" -O /tmp/godot.zip
  unzip -o -q /tmp/godot.zip -d server/
  chmod +x "server/$FILE"
fi

# primeira vez: importa o projeto
if [ ! -d ".godot" ]; then
  "server/$FILE" --headless --import || true
fi

exec "server/$FILE" --headless --path "$DIR" -- --server --bots="$BOTS"
