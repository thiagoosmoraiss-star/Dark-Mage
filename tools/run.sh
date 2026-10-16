#!/usr/bin/env bash
# Roda um script de ferramenta (-s) em modo headless sem travar no depurador
# interativo em caso de erro. Uso: tools/run.sh res://tools/x.gd [-- args...]
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-../tools/godot/Godot_v4.7.2-stable_win64.exe}"
SCRIPT="$1"; shift
# --quit-after: se o script falhar antes de chamar quit(), o processo não fica rodando para sempre.
exec "$GODOT" --headless --path . --quit-after "${QUIT_AFTER:-10}" -s "$SCRIPT" "$@"
