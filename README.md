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
1. Instale os export templates **4.7.2 stable** (no editor: Editor → Manage Export Templates → Download; ou extraia
   `Godot_v4.7.2-stable_export_templates.tpz` do release oficial em `%APPDATA%/Godot/export_templates/4.7.2.stable/`).
2. Rode `bash tools/export.sh`: exporta `build/export/windows/DarkMage.exe` (PCK embutido) +
   `libterrain.windows.release.x86_64.dll` (precisa ficar ao lado do .exe) e roda o teste de fumaça no executável
   (menu → novo jogo → salvar → menu → carregar).
3. Distribua a pasta `build/export/windows/` inteira. Saves e configurações ficam em
   `%APPDATA%/Godot/app_userdata/Dark Mage - The Isle of Fear/`.

O Windows SmartScreen vai alertar na primeira execução, porque o executável não tem assinatura de código (fora do
escopo da 1.0): clique em "Mais informações" → "Executar assim mesmo".

## Estrutura
```
addons/     terrain_3d (1.0.2), gdUnit4 (6.2.2, só para testes; fora do export)
autoload/   events, rng, game (fluxo de cenas), settings, save_system, audio, music, game_state, inventory
core/       utilidades puras (hash estável, save codec, diário, estatística de frame)
data/       tabelas de dados (controles, presets, itens, feitiços, inimigos, chefes, textos pt_BR/en)
levels/     cenas (menu inicial, ilha)
world/      ilha (Terrain3D), água, vegetação, estruturas, interativos, interiores, cidadela
player/ combat/ ai/   jogador, feitiços e inimigos/chefes
ui/         HUD, mapa, menus (inicial, pausa, Grimório, opções, loja), tema
shaders/ vfx/ assets/
tools/      check, capture, export, geradores (ilha, mapa, feitiços, inimigos, chefes, áudio ambiente)
tests/      unit/, scene/, fixtures/, golden/ (capturas por marco)
docs/       roteiro completo
```

## Documentos
`PROGRESS.md` (onde paramos) · `DECISIONS.md` · `TODO.md` · `ASSETS_LICENSES.md` · `CREDITS.md` ·
`QA_CHECKLIST.md` · `PERFORMANCE.md`
