# Dark Mage — The Isle of Fear

Aventura de mundo aberto em fantasia sombria, feita em **Godot 4.7.2** (GDScript tipado, Forward+, Jolt).
O design está em `DESIGN.md` e a especificação completa em `docs/ROTEIRO.md`.

## Requisitos
- Godot **4.7.2-stable** padrão (sem .NET). Neste computador ele está em `../tools/godot/`; em outro,
  defina `GODOT_BIN` com o caminho do executável.
- Git com Git LFS.
- Bash (Git Bash no Windows) para `tools/check.sh`.

## Abrir no editor
Abra o Godot, clique em **Importar** e escolha `project.godot`. A cena principal é `levels/test_scene.tscn`.

## Rodar
```bash
GODOT=../tools/godot/Godot_v4.7.2-stable_win64.exe
"$GODOT" --path .                 # jogo
"$GODOT" --path . -- --overlay    # com o overlay de desenvolvedor visível (F3 alterna)
"$GODOT" --path . -- --seed=123   # outra seed de mundo (só para testes)
```
O overlay existe em builds de debug ou com `-- --dev`.

## Testar
```bash
tools/check.sh          # tudo: importação, smoke (--quit-after 120), licenças e GdUnit4
tools/check.sh test     # só GdUnit4
```
Logs em `build/logs/`; relatórios HTML do GdUnit4 em `reports/`.

Captura de uma cena (precisa de GPU, sem `--headless`):
```bash
"$GODOT" --path . -s res://tools/capture.gd -- --scene=res://levels/test_scene.tscn --out=res://build/captures/x.png
```

Depois de mudar `data/input_defaults.gd`, regrave o InputMap:
```bash
"$GODOT" --headless --path . -s res://tools/setup_input_map.gd
```

## Exportar
A partir do M11 (`export_presets.cfg` e templates 4.7.2 instalados):
`"$GODOT" --headless --path . --export-release "Windows Desktop" build/DarkMage.exe`

## Estrutura
```
addons/     terrain_3d (1.0.2), gdUnit4 (6.2.2)
autoload/   events, rng, game, settings, save_system
core/       utilidades puras (hash estável, save codec, estatística de frame)
data/       tabelas de dados (controles, presets gráficos)
levels/     cenas de nível
ui/         interface (debug/dev_overlay)
tools/      scripts de linha de comando (check, capture, licenças, input map)
tests/      unit/, scene/, e2e/, fixtures/, golden/
world/ player/ combat/ ai/ shaders/ vfx/ assets/   (a partir do M1)
docs/       roteiro completo
```

## Documentos
`PROGRESS.md` (onde paramos) · `DECISIONS.md` · `TODO.md` · `ASSETS_LICENSES.md` · `CREDITS.md` ·
`QA_CHECKLIST.md` · `PERFORMANCE.md`
