# Progresso

## Estado atual (para retomar)
- **Marco atual:** M1 concluído (tag `m1`). **Próximo:** M2 — terreno da ilha (Terrain3D).
- **Godot:** `../tools/godot/Godot_v4.7.2-stable_win64.exe` (ou `GODOT_BIN`).
- **Verificação:** `bash tools/check.sh` (APROVADO, 33 testes) e `bash tools/capture.sh tests/golden/<m>/shots.json`.
- **Próximos 3 passos:**
  1. M2: baixar texturas PBR CC0 (ambientCG/Poly Haven) e montar o `Terrain3DAssets`.
  2. M2: `world/island/island_generator.gd` (heightmap autoral por seed + máscaras de região) e `tools/generate_island.gd` gravando os dados do Terrain3D.
  3. M2: teste de hash por seed, teste de colisão × altura em 10 mil pontos, capturas de relevo.

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

### 2026-10-16 · M1 — Render base e atmosfera

**Mini-plano:** shader de céu próprio; nó `Atmosphere` com ciclo de 24 min, sol/lua, PSSM, névoa de altura e
volumétrica, glow, AgX, LUT; presets aplicados ao ambiente; ferramenta de captura por poses; autocrítica.

**Feito:**
- `shaders/sky.gdshader`: gradiente por horário com horizonte quente do lado do sol, halo de Mie, disco solar,
  lua com crateras falsas, estrelas cintilantes, duas camadas de nuvens com borda prateada e tinta de corrupção.
- `world/atmosphere.gd` (`Atmosphere`): constrói WorldEnvironment, Sol e Lua; ciclo de 24 min; só uma luz
  com sombra por vez; névoa exponencial + altura + volumétrica (violeta com corrupção); glow; AgX; contraste;
  saturação por horário; LUT 3D (`core/color_grading.gd`: default, corrupted, purified); presets (PSSM 2/4,
  distância, SSAO/SSIL/SSR, volumétrica e qualidade de sombra suave).
- `data/day_night_palette.gd`: 9 chaves de cor/energia por hora, interpolação cíclica suave, trajetórias do sol e da lua.
- `world/props/rock_mesh.gd` + `shaders/rock.gdshader`: rochas esculpidas por código (icosfera + fBm/ridged +
  cortes de fratura), triplanar com musgo no topo e AO de cavidade — asset definitivo, não primitiva.
- Cena `levels/sandbox/atmosphere_sandbox.tscn`; `tools/capture.gd` por poses (JSON), `tools/capture.sh`
  (reprova com erro no log) e `tools/contact_sheet.gd`.

**Testes:**
| Teste | Resultado |
|---|---|
| `tools/check.sh all` (import, smoke, licenças, GdUnit4 33/33) | APROVADO |
| Ciclo: sol ao meio-dia/meia-noite, leste→oeste, lua à noite, paleta contínua e cíclica, nó troca sombra sol↔lua, 1 min real = 1 h | APROVADO |
| Controle negativo do teste de compilação | APROVADO (reprovou como esperado) |
| Capturas `tests/golden/m1/` (8 poses, preset Alto, Intel UHD) | APROVADO (funcional) |
| Qualidade no hardware de referência | NÃO EXECUTADO (dono) |

**Autocrítica visual (M1):** o amanhecer e o pôr do sol estão bonitos: céu âmbar e laranja, sol com halo, nuvens
com borda iluminada e silhueta dos morros. O crepúsculo violeta passa bem a "beleza sombria". A noite é
legível (azul-crepúsculo, estrelas, rochas com luz lunar), mas a lua quase não aparece nos enquadramentos
atuais. O meio-dia ficou correto, mas um pouco claro e pouco dramático; as sombras curtas do meio-dia não
ajudam. O estado corrompido ainda é tímido (lavanda em vez de violeta ameaçador) e vai ser calibrado por
região no M7. **Feio:** o chão provisório tem manchas grandes e repetitivas e listras do normal map. Vai sair
no M2. Na primeira rodada a névoa de altura lavava todas as cenas de dia; reduzi a densidade em 45%, a
altura da névoa e o efeito no céu.
