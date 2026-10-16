#!/usr/bin/env bash
# Exporta o build de release do Windows e roda o teste de fumaça no executável.
# Uso: tools/export.sh [--no-smoke]
# Requer os export templates 4.7.2 em %APPDATA%/Godot/export_templates/4.7.2.stable.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-../tools/godot/Godot_v4.7.2-stable_win64.exe}"
OUT="build/export/windows"
mkdir -p "$OUT" build/logs
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/DarkMage.exe" >build/logs/export.log 2>&1 || { echo "REPROVADO: exportação"; exit 1; }
if grep -aE '(SCRIPT ERROR|^ERROR:)' build/logs/export.log; then echo "REPROVADO: erros na exportação"; exit 1; fi
ls -la "$OUT"
[[ "${1:-}" == "--no-smoke" ]] && exit 0
RESULT="$APPDATA/Godot/app_userdata/Dark Mage - The Isle of Fear/export_smoke.txt"
rm -f "$RESULT"
(cd "$OUT" && timeout 300 ./DarkMage.exe --windowed --resolution 1280x720 -- --export-smoke >/dev/null 2>&1)
cat "$RESULT" 2>/dev/null || { echo "REPROVADO: o executável não gravou o resultado"; exit 1; }
grep -q "RESULTADO: APROVADO" "$RESULT"
