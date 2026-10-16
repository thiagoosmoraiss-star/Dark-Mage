# Progresso

## Estado atual (para retomar)
- **Marcos concluídos:** M0–M7 (tags `m0`…`m7`). **Próximo:** M8 — santuários, covis, chefes e chefe final.
- **Godot:** `../tools/godot/Godot_v4.7.2-stable_win64.exe` (ou `GODOT_BIN`).
- **Verificação:** `bash tools/check.sh` (APROVADO, 82 testes) · capturas `bash tools/capture.sh tests/golden/<m>/shots.json`
  · benchmark `godot --path . -- --bench --preset=high`.
- **Geradores de dados:** `make_spells.gd`, `make_enemies.gd`, `place_pois.gd` (via `tools/run.sh`) · ilha: `generate_island.gd` (~3,5 min).
- **Próximos 3 passos:**
  1. M8: entrada de santuário/covil no mundo + cena interna instanciada (KayKit Dungeon) com retorno ao ponto de entrada.
  2. M8: 12 santuários (quebra-cabeça com feitiço, combate, plataforma) com recompensa (fragmento de vida/mana).
  3. M8: 4 Guardiões (2 fases) + chefe final (3 fases) com god mode de teste; purificação da região ao vencer.

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

### 2026-10-16 · M6 — Combate e magia (fatia vertical)

**Feito:** núcleo de combate (`DamageInfo`, `StatusEffects`, `Cooldowns`, `HitStop`); 8 `SpellData.tres` com
nomes/descrições em `data/i18n/strings.csv` (pt_BR/en); `SpellCaster` (ataque básico em combo de 3, slots Q/E/R/F,
carga, mira de ombro com retícula, auto-alvo suave, lock-on com câmera, ultimate carregada pelo dano); os 4
feitiços da fatia (Lança Arcana carregável, Pulso Umbral, Corrente Etérea, Égide Violeta) + Passo Umbral (blink);
os outros 3 (Queda Astral, Grilhões de Gelo, Ira do Farol) já funcionam e serão destravados na progressão;
esquiva com i-frames e esquiva perfeita (câmera lenta + mana); hit-stop, tremor, flash branco, números de dano,
VFX em pool e áudio em camadas; inimigos Rastejante da Névoa e Arqueiro Esqueleto com FSM completa,
percepção (visão + som), telegrafia (pose, olhos acendendo, anel no chão), diretor de combate e navegação
assada em tempo de execução; HUD (vida, mana, slots com recarga e ícones próprios, carga, ultimate, mira, alvo
travado, barras de inimigos); ruínas esculpidas e torre do farol no Vale; acampamentos de inimigos; autoload `Audio`.

**Testes (75/75 APROVADO):** combo acerta; carga causa mais dano (toque 18,6 vs. carregada 55); pulso atinge e
empurra só quem está perto; corrente salta entre 3 inimigos; égide absorve; gelo congela; inimigo persegue,
telegrafa e acerta; esquiva perfeita evita dano; máximo de 2 atacantes; 200 conjurações sem vazamento
(+8 objetos / +8 recursos após aquecimento); lógica de status/recarga/feitiços/hit-stop.

**Autocrítica (M6):** o loop de combate funciona e lê bem (telegrafia clara, números, flash, sons). Bonito:
ruínas ao entardecer, a Égide dourada à noite, o cristal do cajado iluminando inimigos. Feio/limitado: os efeitos
de impacto são pequenos e rápidos demais para "peso" (aumentar no M10); o arco da ruína ainda parece montado
por blocos soltos; a torre do farol é um cilindro de blocos repetidos sem detalhe no topo (M7); inimigos e
mago no estilo KayKit (fofo) contrastam com o tom sombrio pretendido. "Fatia vertical de 10 minutos com aparência
de produto final": jogável no Vale (explorar, ruínas, dois grupos de inimigos, farol para escalar), mas **ainda
sem menu inicial, música e polimento de UI** (M9/M10) — aprovado como fatia jogável, não como produto final.

### 2026-10-16 · M7 — Conteúdo do mundo

**Feito:** 85 POIs por regras (4 faróis com torre e braseiro no topo, 8 fogueiras, 15 acampamentos, 4 covis,
12 santuários, 30 baús, 5 mirantes, 5 histórias + ruína do Vale e Cidadela); `Interactable`/`Interactor` e
prompt na HUD; Baú (KayKit, tampa animada, saque determinístico por região), Farol (acende, revela mapa,
purifica, feixe de luz), Fogueira (chamas, descanso, save, renascimento, ressurreição, espera e viagem rápida),
Mirantes e Histórias (KayKit Halloween, textos de lore pt_BR/en); `GameState` (flags, almas, cristais,
materiais, XP/nível, fogueiras, purificação) salvo junto com névoa de guerra, feitiços e atributos;
`RegionAmbience` (corrupção, LUT, FogVolume no Pântano, neve/cinzas/fogos-fátuos/vagalumes, frio nos Picos,
anúncio de região); 4 inimigos novos (morcego, golem, bruxa, serpente) e acampamentos com composição por região;
inimigos dormentes a distância; fontes Cinzel/Alegreya Sans e tema de UI.

**Testes (82/82 APROVADO):** quantidades de POIs e cobertura das 6 regiões; nenhum POI submerso, flutuando ou
em encosta inviável (raycast na colisão); todos alcançáveis a partir do início (grade de 6 m, andar/nadar +
escalada ≤ 30 m); saque determinístico; GameState ida e volta; os 6 inimigos nascem e recebem dano; ponto
fraco do golem; serpente submersa imune.

**Autocrítica (M7):** cada região tem cor própria nas capturas (vale dourado, floresta violeta e densa, picos
rochosos com pinheiros, terras calcinadas avermelhadas com golem, pântano roxo de árvores mortas, costa ao pôr
do sol). Feio/limitado: as poças das Terras Calcinadas são água escura em vez de lava; o topo da torre do farol
é pequeno visto de baixo; a fogueira apagada some à noite (precisa de brasas mais visíveis); faltam fauna e
som ambiente por região (M10); o mapa ainda não mostra ícones dos POIs descobertos (M9).

### 2026-10-16 · M8 — Santuários, Guardiões e chefe final

**Feito:** interiores em "dimensão de bolso" (`InteriorManager`, fade, ambiente próprio, sol/lua/mar desligados,
respawn na entrada da sala) montados com o KayKit Dungeon (`InteriorBuilder`); 12 santuários em 4 arquétipos
(Braseiros — só a Lança Arcana acende; Provação — 2 ondas; Abismo — plataformas, queda volta ao início; Runas —
Corrente revela, disparo acende) com altar que dá Sigilo de Vida ou Mana (+10); 4 covis com corredor de inimigos
e arena 9×9; `Boss` (fases, 7 ataques, guarda quebrada pelo feitiço certo: Escudo→Pulso, Armadura→Lança,
Superaquecimento→Grilhões, Submersão→Corrente); Guardiões da Floresta, Picos, Terras Calcinadas e Pântano
(cada um purifica a região e ensina um feitiço: Passo Umbral, Grilhões de Gelo, Queda Astral, Ira do Farol);
Cidadela com cúpula que abre após os 4 Guardiões, chefe final "O Medo" em 3 fases (as mecânicas se alternam) e
epílogo (ilha toda purificada, amanhecer dourado, texto final, save). HUD com barra do chefe, marcas de fase e
legendas; XP/almas por inimigo, nível com aviso; `Player.apply_progression()` (atributos + sigilos).

**Testes (91/91 APROVADO):** braseiros e runas resolvem só com o feitiço certo; abismo devolve ao início; provação
completa após 2 ondas; sigilo aumenta o máximo; cada Guardião morre com god mode, troca de fase, tem a mecânica
quebrada ao menos uma vez, grava a flag, zera a corrupção e concede o feitiço; o chefe final passa pelas 3 fases
e usa 3 mecânicas diferentes.

**Autocrítica (M8):** os interiores do KayKit ficam coesos e bem iluminados; a barra do chefe e as legendas leem
bem. Feio/limitado: os Guardiões reaproveitam esqueleto/golem/serpente com escala e tinta (falta silhueta única);
a arena é uma sala quadrada grande; a cúpula da Cidadela é uma esfera translúcida simples; o epílogo é texto
sobre o amanhecer, sem cinemática nem créditos rolando (M10). Campanha completa de ponta a ponta **não foi
jogada manualmente** — está no QA_CHECKLIST para o dono.

### 2026-10-16 · M9 — Progressão, UI completa e gamepad

**Feito:** menu inicial (fundo capturado do próprio jogo, Continuar/Novo/Carregar/Opções/Créditos/Sair) como cena
principal; tela de carregamento em segundo plano com dicas; pausa (continuar, inventário, diário, mapa, salvar e
carregar em 3 espaços com confirmação, opções, menu inicial, sair); Grimório com abas — inventário em grade 9×4
(arrastar e soltar, "mover" pelo teclado/gamepad, equipar/usar, comparação com o equipado), personagem (nível,
XP, pontos de atributo), feitiços (montar os 4 espaços) e diário (missões principais e descobertas derivadas do
progresso); 17 itens (6 cajados que mudam o ataque básico, 4 mantos, 4 amuletos, 3 consumíveis) e Mercador
Misterioso no Vale com estoque que cresce a cada Guardião; opções completas (qualidade, janela/sem bordas/tela
cheia, V-Sync, limite de FPS, FOV, 6 volumes, sensibilidades, inverter Y, remapeamento de teclado e gamepad com
troca de conflitos, idioma, legendas e tamanho, escala da UI, filtro de daltonismo por daltonização, tremor,
clarões, números de dano, assistência de mira, HUD oculto fora de combate); feitiços no gamepad com LB + A/B/X/Y;
poções rápidas (H/J, D-pad ↓/→); HUD com objetivo atual, poções e rótulos do dispositivo em uso; mapa com ícones
por forma e estado, cursor por mouse/analógico, viagem rápida pelas fogueiras e até 12 marcadores; save v2
(inventário + marcadores) com migração do v1; ícones SVG próprios.

**Testes (111/111 APROVADO):** inventário (pilhas, capacidade, mover, equipar, bônus, validação de lixo),
mercador (estoque, compra, venda), pontos de atributo, diário segue as flags, remapeamento com troca e contexto
LB separado, migração da fixture v1 → v2 sem perder progresso, `slot_info`/`latest_slot`; **toda tela de menu
abre com foco e todo controle é alcançável pelas setas** (opções ×4 abas, Grimório ×4, loja ×2, pausa, slots,
menu inicial); usar poção/equipar/gastar ponto pela UI; cajado de espinheiro dispara 3 projéteis; LB + B vira o
feitiço 2 e bloqueia o pulo; **salvar e carregar na ilha completa restaura posição, hora, progresso, inventário,
equipamento, feitiços, marcadores e névoa**. Fumaça do menu e da ilha sem erros.

**Autocrítica (M9):** a UI tem identidade (preto translúcido, dourado, Cinzel) e é toda navegável. O mercador
(esqueleto encapuzado com lanterna) ficou carismático. Feio/limitado: o mapa usa a prévia colorida por região,
então as áreas reveladas viram manchas de cor chapadas (precisa de um mapa pintado com relevo, M10); as telas
são densas em texto pequeno a 720p; o gamepad não foi testado com um controle físico (só eventos simulados) — está
no QA_CHECKLIST para o dono.

### 2026-10-16 · M10 — Áudio e polimento

**Feito:** autoload `Music`: música adaptativa com crossfade entre dois players (exploração de dia e de noite,
trilha sombria em regiões corrompidas e interiores, combate com folga de 5 s, chefe a até 70 m; menu e epílogo
forçam faixas) e ambiente em camadas no barramento Ambient (vento suave, floresta, vento dos picos, ondas perto do
mar, pântano, terras calcinadas, caverna nos interiores, zumbido proporcional à corrupção, grilos à noite) e fogo
3D na fogueira acesa mais próxima; reverb de salão no barramento de efeitos dentro de santuários e covis; 5
faixas CC0 (OpenGameArt) e 9 ambientes sintetizados por `tools/synth_ambience.py` (obra própria) + grilos CC0;
mapa pintado em estilo carta antiga (`tools/make_map.gd`: relevo, curvas de nível, costa a tinta, ondas);
lago de lava na cratera do vulcão (shader, luz, fagulhas, dano só na altura da lava); fogueira apagada mais
visível; braseiro do farol 1,6× maior; tremor de câmera nos golpes fortes; dificuldade Fácil/Normal/Difícil.

**Testes (112/112 APROVADO):** escolha da trilha por estado na ilha completa (dia → noite → combate → folga →
chefe → faixa forçada). Fumaças e licenças aprovadas (342 assets registrados).

**Recusado:** pacote "JC Sounds Nature Ambient Pack" (CC-BY 4.0): o autor diz ter misturado sons de bibliotecas
compradas, sem confirmar a redistribuição — licença duvidosa (seção 13.4), substituído por síntese própria.

**Autocrítica visual (M10):** o mapa agora parece um mapa (antes eram manchas chapadas); a lava dá um ponto focal
noturno às Terras Calcinadas; o farol lê melhor de baixo. Feio/limitado: o padrão da lava é uniforme de perto;
as "poças escuras" das Terras Calcinadas são o material de cinza do terreno (não água), ficam como campos de
cinza.
**Autocrítica sonora (M10):** NÃO EXECUTADO por ouvido — esta sessão não tem como ouvir áudio. Validado só
tecnicamente (arquivos decodificam, loops ligados, níveis normalizados, troca de faixa testada). Os ambientes
sintetizados tendem a soar artificiais perto das gravações; o loop MP3 pode ter um pequeno respiro na emenda.
Ouvir e ajustar a mixagem está no QA_CHECKLIST do dono.

### 2026-10-16 · M11 — Exportação Windows

**Feito:** `export_presets.cfg` (Windows Desktop x86_64, PCK embutido, sem console no release, ícone próprio, nome
"Dark Mage - The Isle of Fear", versão 0.10.0, exclui testes/ferramentas/GdUnit4); templates 4.7.2 oficiais
baixados do GitHub e conferidos pelo SHA-512 publicado (só os do Windows extraídos); `tools/export.sh` exporta e
roda o teste de fumaça no próprio .exe (`--export-smoke`). Corrigidos 4 pontos que só quebrariam no export: 3
imagens lidas como PNG bruto (agora pela textura importada) e `data/world_pois.json` incluído no pacote.

**Testes:** export sem erros; **executável exportado: menu → novo jogo → salvar → menu → continuar → estado
conferido = APROVADO**; 112/112 GdUnit4. Offline: o jogo não faz nenhuma chamada de rede (não há HTTPRequest no
código). SmartScreen vai alertar (sem assinatura de código — fora do escopo).

**Tamanho:** `DarkMage.exe` 190 MB + `libterrain.windows.release.x86_64.dll` 3,5 MB.
