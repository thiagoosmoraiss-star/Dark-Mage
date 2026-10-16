#!/usr/bin/env bash
# Verificação do projeto (roteiro, seções 11 e 13.1).
# Uso: tools/check.sh [import|smoke|licenses|test|all]   (padrão: all)
# GODOT_BIN aponta para o executável; senão usa ../tools/godot/ ao lado do projeto.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-../tools/godot/Godot_v4.7.2-stable_win64.exe}"
LOG_DIR="build/logs"
mkdir -p "$LOG_DIR"
STEP="${1:-all}"
FAIL=0

# Reprova se o log tiver erro ou warning de script ou do motor.
scan() {
	if grep -nE '(SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error|USER ERROR|USER WARNING)' "$1"; then
		echo "REPROVADO: erros/warnings em $1"
		FAIL=1
	fi
}

if [[ $STEP == import || $STEP == all ]]; then
	echo "== import"
	"$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1 || FAIL=1
	scan "$LOG_DIR/import.log"
fi

if [[ $STEP == smoke || $STEP == all ]]; then
	echo "== smoke (--quit-after 120)"
	"$GODOT" --headless --path . --quit-after 120 >"$LOG_DIR/smoke.log" 2>&1 || FAIL=1
	scan "$LOG_DIR/smoke.log"
fi

if [[ $STEP == licenses || $STEP == all ]]; then
	echo "== licenças"
	"$GODOT" --headless --path . -s res://tools/check_licenses.gd >"$LOG_DIR/licenses.log" 2>&1 || FAIL=1
	grep -aE 'check_licenses' "$LOG_DIR/licenses.log"
	scan "$LOG_DIR/licenses.log"
fi

if [[ $STEP == test || $STEP == all ]]; then
	echo "== GdUnit4"
	"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
		res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests \
		>"$LOG_DIR/tests.log" 2>&1
	rc=$?
	grep -aE 'Overall Summary|Executed test' "$LOG_DIR/tests.log" | tail -4
	if [[ $rc -ne 0 ]]; then
		echo "REPROVADO: GdUnit4 rc=$rc (detalhes em $LOG_DIR/tests.log)"
		FAIL=1
	fi
fi

if [[ $FAIL -eq 0 ]]; then echo "APROVADO"; else echo "REPROVADO"; fi
exit $FAIL
