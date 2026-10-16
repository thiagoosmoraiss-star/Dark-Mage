#!/usr/bin/env bash
# Captura poses (golden visual) e reprova se houver erro de script no log.
# Uso: tools/capture.sh tests/golden/m1/shots.json [--overlay]
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-../tools/godot/Godot_v4.7.2-stable_win64.exe}"
SHOTS="$1"; shift
mkdir -p build/logs
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --path . --windowed --resolution 1280x720 -s res://tools/capture.gd -- --shots="res://$SHOTS" "$@" \
	>build/logs/capture.log 2>&1
rc=$?
grep -a 'capture:' build/logs/capture.log
if grep -aE '(SCRIPT ERROR|^ERROR:|^WARNING:)' build/logs/capture.log | grep -v -x -F -f tools/known_log_messages.txt | grep .; then
	echo "REPROVADO: erros na captura"; exit 1
fi
exit $rc
