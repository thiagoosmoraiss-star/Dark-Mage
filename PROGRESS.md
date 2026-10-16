# Progresso

## Estado atual (para retomar)
- **Marcos concluídos:** M0, M1, M2, M3, M4, M5 (tags `m0`…`m5`). **Próximo:** M6 — combate e magia (fatia vertical).
- **Godot:** `../tools/godot/Godot_v4.7.2-stable_win64.exe` (ou `GODOT_BIN`).
- **Verificação:** `bash tools/check.sh` (APROVADO, 59 testes) · capturas `bash tools/capture.sh tests/golden/<m>/shots.json`
  · benchmark `godot --path . -- --bench --preset=high`.
- **Regerar a ilha** (só se mudar o gerador): `QUIT_AFTER=100000 bash tools/run.sh res://tools/generate_island.gd` (~3,5 min).
- **Próximos 3 passos:**
  1. M6: sistema de dano/status (`combat/`), `SpellData` (Resource) e pool de projéteis/efeitos.
  2. M6: ataque básico (combo de 3), 4 feitiços (projétil carregável, área, raio em cadeia, barreira), mira e lock-on, hit-stop e tremor.
  3. M6: 2 inimigos com FSM + NavigationAgent3D, VFX e áudio de impacto, teste de vazamento com 200 conjurações.

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

### 2026-10-16 · M2 — Terreno da ilha

**Feito:** `IslandGenerator`/`IslandLayout` (regiões com pesos gaussianos perturbados, platô da Cidadela,
vulcão com cratera, pântano no nível do mar, costa com praias, falésias e ilhotas, suavização 1-2-1);
`tools/generate_island.gd` grava 64 regiões do Terrain3D + `region_map.png` + `preview.png` + `meta.json`;
8 texturas PBR CC0 (ambientCG) empacotadas; material com projeção em encostas e macro variação; mapa de
controle por regras (região, altura, inclinação, costa) e mapa de cor por região; mar com malha polar que
segue a câmera, ondas Gerstner, cor por profundidade, refração, espuma e fresnel.

**Testes:** mesma seed → mesmo hash (APROVADO); seeds diferentes diferem (APROVADO); composição (APROVADO);
colisão × visual — vértices 0,0007 m em 10 mil pontos (APROVADO), entre vértices P99 0,021 m e 0,14% > 5 cm
(APROVADO com o critério de D27); dados gravados = gerador (APROVADO); regiões no mapa (APROVADO).

**Autocrítica:** relevo legível com regiões distintas (vale dourado, picos rochosos, vulcão avermelhado,
pântano com poças, floresta). Na primeira captura o terreno saiu quadriculado: os assets do Terrain3D eram
descartados (D29). Feio ainda: vista aérea com névoa pesada a 1,4 km; pântano e terras calcinadas pouco
característicos (M7); rios não existem (M7).

### 2026-10-16 · M3 — Personagem jogável

**Feito:** `Player` (estados chão/ar/escalada/planador/natação/esquiva, coyote time, buffer de pulo, input
roteirizado), `CameraRig` (SpringArm3D, suavização, zoom, ombro, tremor com acessibilidade), `PlayerStats`,
`PlayerModel` (AnimationTree: máquina de estados + BlendSpace1D, inclinação nas curvas, balanço da capa),
`MageLook` (recolor do atlas, cajado com cristal e luz, olhos violeta), roda de stamina contextual.

**Testes:** andar 2 s determinístico (~10,4 m, posições idênticas) (APROVADO); não atravessa o chão
(APROVADO); pulo ~1,05 m e aterrissagem (APROVADO); sprint consome stamina (APROVADO); stats (APROVADO).

**Autocrítica:** silhueta legível (chapéu alto com faixa dourada, cajado com cristal violeta acima da cabeça,
olhos brilhando), muito boa à noite com a luz do cristal. Limitações: proporções "chibi" do KayKit, menos
sombrias do que o ideal (D30); escalada/planador/natação usam clipes aproximados (o pacote não os tem).

### 2026-10-16 · M4 — Vegetação e composição

**Feito:** grama em chunks de MultiMesh (vento, abre passagem ao redor do jogador, cor por material, fade
sem pop); flores, samambaias, arbustos e cogumelos bioluminescentes; árvores procedurais (carvalho, gigante,
pinheiro, morta) com LOD0/LOD1/impostor e fade; rochas procedurais; distribuição por regras com clareiras;
colisão só perto do jogador; benchmark fixo e otimizações por preset (D33, D34).

**Testes:** contagens, tudo assentado, nada de árvore na água, clareiras, determinismo, grama por regras
(APROVADO). Benchmark: Baixo/720p 31,5 FPS nesta Intel UHD; **Alto no Nitro V15: NÃO EXECUTADO (dono)**.

**Autocrítica:** campo do vale e chão da floresta ficaram vivos. Pinheiros pareciam postes e foram
refeitos. Feio ainda: "gigantes" não parecem gigantes; lâminas de grama largas de perto; pântano e terras
calcinadas sem identidade (M7).

### 2026-10-16 · M5 — Travessia avançada

**Feito:** escalada (parede, stamina, salto, borda, chuva), planador, natação (afunda e volta à margem),
esquiva com i-frames; `WaterBody` para lagos; névoa de guerra (`FogOfWar`, serializável) e tela de mapa.
O blink entra com os feitiços no M6.

**Testes:** percurso roteirizado escala parede de 8 m, plana sobre o vale e nada até o marcador
(APROVADO); esquiva com i-frames (APROVADO); nadador exausto volta à margem (APROVADO); névoa de guerra
revela e salva (APROVADO).

**Autocrítica:** mecânicas funcionam e são testadas; o mapa ainda é simples (cores de prévia, sem ícones)
e será refeito com a UI completa no M9.
