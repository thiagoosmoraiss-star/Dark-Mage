# Progresso

## Estado atual (para retomar)
- **Marco atual:** M0 concluído (tag local `m0`). **Próximo:** M1 — render base e atmosfera.
- **Godot:** `../tools/godot/Godot_v4.7.2-stable_win64.exe` (ou `GODOT_BIN`).
- **Verificação:** `bash tools/check.sh` → APROVADO em 2026-10-16.
- **Próximos 3 passos:**
  1. M1: shader de céu próprio (`shaders/sky.gdshader`) com gradiente, sol, lua, estrelas e nuvens em camadas.
  2. M1: `world/day_night.gd` (ciclo de ~24 min) controlando sol/lua (`DirectionalLight3D`, PSSM 4), névoa de altura e volumétrica, glow e tonemap; presets aplicados ao `WorldEnvironment`.
  3. M1: `tools/capture.gd` com poses e horários fixos (amanhecer, meio-dia, pôr do sol, noite) → `tests/golden/m1/` e autocrítica.

## Ao iniciar uma sessão
Ler `docs/ROTEIRO.md`, este arquivo, `DECISIONS.md` e `TODO.md`; rodar `bash tools/check.sh`; só então continuar.

---

## Histórico

### 2026-10-16 · M0 — Fundação

**Mini-plano:** criar o projeto Godot 4.7.2 e o repositório; instalar e fixar Terrain3D e GdUnit4; autoloads
(`Events`, `Rng`, `Game`, `Settings`, `SaveSystem`) e overlay F3; InputMap completo a partir de uma tabela;
warnings como erros; cena de teste com WorldEnvironment; testes e script de verificação; documentos.

**Feito:**
- Godot 4.7.2 portátil baixado (SHA-512 conferido). Terrain3D 1.0.2 e GdUnit4 6.2.2 em `addons/`.
- `project.godot`: Forward+, Jolt, 60 Hz, interpolação de física, MSAA 3D desligado, warnings de tipagem = erro.
- Autoloads: barramento de sinais; RNG por fluxo com seed 20261016 e hash FNV-1a estável; settings em
  ConfigFile com presets e remapeamento; save JSON versionado (3 slots, escrita atômica, backup, migração,
  validação); estado do jogo e modo `--dev`.
- InputMap de 25 ações gerado de `data/input_defaults.gd` (sem Alt; teclado, mouse e gamepad).
- Overlay de desenvolvedor (F3): FPS, frame médio/P95/P99, draw calls, primitivas, VRAM, RAM, nós, recursos,
  GPU/driver, preset, posição e célula.
- `levels/test_scene.tscn` com céu procedural, sol com sombra PSSM e névoa.
- Ferramentas: `tools/check.sh`, `tools/capture.gd`, `tools/check_licenses.gd`, `tools/setup_input_map.gd`.
- Documentos: README, DESIGN, DECISIONS, PROGRESS, TODO, ASSETS_LICENSES, CREDITS, QA_CHECKLIST, PERFORMANCE.

**Testes:**
| Teste | Resultado |
|---|---|
| `--headless --import` sem erros/warnings | APROVADO (após desativar o plugin de editor do Terrain3D, D04) |
| `--headless --quit-after 120` sem erros | APROVADO |
| GdUnit4 pela linha de comando: 24 casos em 4 suítes (RNG, save, estatística de frame, fundação) | APROVADO (24/24) |
| `check_licenses` + controle negativo (arquivo sem registro reprova) | APROVADO |
| Execução com renderização (Vulkan 1.4.323, Forward+, Intel UHD) + captura `tests/golden/m0/test_scene.png` | APROVADO (funcional) |
| F3 alternando o overlay com teclado físico | NÃO EXECUTADO (sem interação manual; ficou no QA_CHECKLIST para o dono) |
| FPS no hardware de referência | NÃO EXECUTADO (máquina do agente tem Intel UHD; benchmark só a partir do M1) |

**Autocrítica visual (M0):** a cena de teste é só céu, horizonte e névoa: gradiente azul-crepúsculo → âmbar no
horizonte, chão escuro violeta. Não há nada chapado de cor única, mas também não há conteúdo, como o M0 pede.
O céu procedural padrão é placeholder (TODO #1). Na primeira tentativa a névoa de altura cobria a tela toda
de roxo; foi corrigido (altura da névoa abaixo da câmera e pouco efeito no céu). A captura com overlay mostrou
~48 FPS na Intel UHD numa cena vazia em 1280×720, o que acende um alerta para o preset Baixo nesta classe de
GPU. Precisa ser medido de verdade com o benchmark do M1.
