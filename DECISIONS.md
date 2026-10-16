# Decisões

Formato: data · decisão · motivo · impacto / como reverter.

## 2026-10-16 (M0)

**D01 · Roteiro seguido: Godot 4 (`ROTEIRO-DARK-MAGE-GODOT.md`).**
O dono pediu inicialmente o roteiro Three.js/Electron ("DO-ZERO"), depois removeu esse arquivo da pasta e
deixou só o roteiro Godot. Seguimos o roteiro Godot. Nenhum código das versões antigas foi lido ou usado.

**D02 · Godot 4.7.2-stable (padrão, sem .NET), portátil, fora do repositório.**
Era a estável mais recente no GitHub (`4.7.2-stable`, 18/08/2026). Baixada com autorização do dono para
`../tools/godot/` (ao lado do projeto), com SHA-512 conferido contra `SHA512-SUMS.txt` oficial. Não está no
PATH: os scripts usam `GODOT_BIN` ou esse caminho. O `Godot_v4.7.2-stable_win64_console.exe` falha com
`CreateProcess error 193` quando o caminho tem espaços; usamos o executável principal, que imprime normalmente.

**D03 · Addons fixados.**
- Terrain3D **v1.0.2-stable** (MIT), release oficial do GitHub (`Terrain3D_v1.0.2-stable.zip`,
  sha256 `a0718502…84a2`). Oficialmente suporta Godot 4.4–4.6+; carrega e instancia no 4.7.2 (teste
  `test_terrain3d_extension_loaded`). Mantidos só os binários Windows e Linux x86_64 (alvo é Windows; Linux
  para eventual CI).
- GdUnit4 **v6.2.2** (MIT), repositório atual `godot-gdunit-labs/gdUnit4` (sha256 do zip `1a2653bd…040d`).

**D04 · Plugin de editor do Terrain3D desativado por padrão.**
Com ele ativo, `godot --headless --import` termina com vazamentos (`EditorDock` e ícone `terrain3d.svg`)
gerados pelo próprio plugin ao fechar o editor no 4.7. A GDExtension (classes `Terrain3D*`) continua ativa,
e o terreno será gerado por script (roteiro 3.1), então o dock de pintura não é necessário. Para esculpir à
mão no editor: Projeto → Configurações → Plugins → ativar Terrain3D (o aviso ao fechar é inofensivo).
Reavaliar quando sair versão do Terrain3D com suporte oficial ao 4.7.

**D05 · Física Jolt, 60 Hz, interpolação de física ligada.** Conforme roteiro 4.2 e 7.5.

**D06 · Renderer Forward+ com Vulkan (padrão do Windows nesta versão).**
Confirmado na execução: `Vulkan 1.4.323 - Forward+`. D3D12 fica como alternativa a testar no Nitro V15 (M1).

**D07 · Warnings de tipagem são erros.**
`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` e `unsafe_call_argument` = erro;
`unsafe_cast` = aviso. Os addons são excluídos pelo padrão do Godot. O `tools/check.sh` reprova qualquer
`WARNING`/`ERROR` nos logs.

**D08 · Interagir = G.** E é o Feitiço 2; tecla única evita ambiguidade. Gamepad: X.

**D09 · Sprint no gamepad = L3; esquiva = B.** O roteiro lista B para os dois; B fica só com a esquiva
para não haver ação dupla no mesmo botão. Feitiços no gamepad (LB + face / roda com RB) serão feitos no M9.

**D10 · InputMap gerado a partir de `data/input_defaults.gd`.**
Uma só fonte para o `project.godot` (via `tools/setup_input_map.gd`), para restaurar padrões e para
remapear. O teste `test_project_input_section_matches_defaults` detecta divergência.

**D11 · Saves em JSON versionado (`SaveCodec`) com escrita atômica e backup.**
Grava `.tmp` → renomeia; o save anterior válido vira `.bak`. Nada de `Resource`/`.tres` (roteiro 4.7).

**D12 · Configurações em `ConfigFile` (`user://settings.cfg`).** Só dados; remapeamentos guardados no
formato da tabela de padrões.

**D13 · Nomes de arquivo em snake_case** (`autoload/game.gd`), conforme o guia de estilo do Godot; os nomes
dos autoloads seguem o roteiro (`Game`, `Events`, `Settings`, `SaveSystem`, `Rng`).

**D14 · Hash estável próprio (FNV-1a 32 bits) em vez de `String.hash()`.**
Garante as mesmas seeds e os mesmos hashes de dados de altura em qualquer versão ou plataforma.

**D15 · Git LFS para binários** (`.png`, `.glb`, `.exr`, `.wav`, `.ogg`, `.dll`, `.so`...). `.import` são
versionados; `.godot/`, `build/` e `reports/` não.

**D16 · Máquina de desenvolvimento ≠ hardware de referência.**
O agente roda num Lenovo 83NS (i5-13420H, Intel UHD Graphics). Capturas aqui são funcionais; FPS e
qualidade final do preset Alto são medidos pelo dono no Nitro V15 (RTX 4050).

## 2026-10-16 (M1)

**D17 · Tonemap AgX.** Mantém cor nos altos (pôr do sol, magia violeta) sem o amarelado do ACES em
saturação alta; exposição por horário na paleta (`data/day_night_palette.gd`).

**D18 · Céu em shader próprio sem `TIME`.** O relógio das nuvens (`cloud_time`) é enviado pelo script no
ritmo do preset (`sky_radiance_update_s`: a cada frame no Alto/Ultra, 0,5 s no Médio, 2 s no Baixo). Usar
`TIME` forçaria recalcular a radiância do céu todo frame. `Sky.PROCESS_MODE_INCREMENTAL`, radiância 256
(128 no Baixo).

**D19 · Iluminação global: SSIL + luz ambiente do céu (sem SDFGI).** O dia e a noite são dinâmicos; o SDFGI
custa caro em GPU de notebook e em mundo aberto grande. SSIL no Alto/Ultra; interiores (santuários e covis)
poderão usar VoxelGI/LightmapGI por cena. Reavaliar no Nitro V15 com o benchmark.

**D20 · Uma luz direcional com sombra por vez.** O sol projeta sombra de dia e a lua à noite (troca quando a
energia do sol cai abaixo de 0,05).

**D21 · Capturas sempre no preset Alto** (`--preset=high` padrão em `tools/capture.gd`), para o golden não
depender da GPU detectada.

**D22 · Scripts de linha de comando (`-s`) não referenciam estaticamente classes que usam autoloads.**
Eles compilam antes dos autoloads existirem; o acesso é dinâmico (`get`/`set`/`call`).

**D23 · Teste que compila todos os scripts e shaders** (`tests/unit/test_scripts_compile.gd`), com controle
negativo verificado (script não tipado reprova).

## 2026-10-16 (M2–M3)

**D24 · Ilha gerada offline por `tools/generate_island.gd` e gravada no formato do Terrain3D**
(`world/island/data`, 64 regiões de 256 m, ~25 MB em LFS). Leva ~3,5 min em 2048² nesta máquina. A
geração é determinística (seed 20261016); `meta.json` guarda seed, resolução e hash. Regenerar sempre que
`IslandGenerator`/`IslandLayout` mudar.

**D25 · Composição autoral por regiões com pesos gaussianos perturbados por ruído** (Vale, Floresta, Picos,
Terras Calcinadas com vulcão, Pântano) + platô da Cidadela + costa com praias e falésias. O pântano domina o
próprio miolo (abaixo do nível do mar em poças). Rios ficaram para o M7 (corpos d'água próprios).

**D26 · Texturas de terreno: 8 materiais CC0 do ambientCG em 1K**, empacotados por
`tools/pack_terrain_textures.gd` (albedo+altura, normal GL+rugosidade), VRAM BPTC com mipmaps. 1K porque
o terreno repete a cada 6–14 m e há variação de macro escala; 2K ficaria para o Ultra no M12.

**D27 · Critério colisão × visual.** O LOD0 do Terrain3D usa diagonais alternadas (malha simétrica) e a
colisão do Jolt uma diagonal fixa: nos vértices são idênticos (≤ 0,001 m medidos), entre vértices divergem
em dobras agudas. Mitigação na origem: duas passadas de suavização 1-2-1 no heightmap. O teste aplica o
critério do roteiro (≤ 0,05 m) em 10 mil vértices e, entre vértices, exige P99 ≤ 0,05 m e < 0,5% acima
(medido: P99 0,021 m, 0,14% acima, máximo 0,25 m em dobras pontuais). **Desvio registrado para o dono.**

**D28 · Mensagens conhecidas do Terrain3D 1.0.2 no Godot 4.7** (`tools/known_log_messages.txt`): um
`load("")` interno e um aviso de API depreciada, emitidos pelo binário do addon até para um `Terrain3D.new()`
vazio. São as únicas exceções do `check.sh`. Remover quando houver Terrain3D com suporte oficial ao 4.7.

**D29 · Ordem de configuração do Terrain3D:** `material`, `collision` e `assets` só existem depois de o nó
entrar na árvore; assets atribuídos antes são descartados (causa do terreno quadriculado na 1ª captura).

**D30 · Personagem: KayKit Adventurers "Mage" (CC0) adaptado.** Recolorido por faixas do atlas (manto
preto-violeta, acabamentos dourados, pele pálida acinzentada, forro violeta), olhos com brilho violeta
posicionados pela malha da cabeça, cajado próprio (haste, garras douradas, cristal emissivo com
OmniLight) alinhado à vertical na pose de idle, capa do próprio modelo com balanço secundário. Proporções
estilizadas (cabeça grande) — legível e coerente com o visual "pintado", mas menos sombrio que o ideal;
trocar por modelo próprio é melhoria futura (TODO).

**D31 · Input roteirizado no Player** (`use_scripted_input`, sinal `stepped`): testes e percursos contam
os passos do próprio jogador, o que tornou o movimento exatamente determinístico entre execuções.

**D32 · Interpolação de física desligada em quem se move em `_process`** (câmera, mar, grama,
vegetação estática); o jogador continua interpolado.

## 2026-10-16 (M4–M5)

**D33 · FSR1 (espacial) nos presets Baixo e Médio.** Medido nesta Intel UHD em 720p: o FSR2 custava ~30 ms
por frame (base a 22 FPS); com FSR1 a mesma cena foi a 85 FPS. FSR2 fica disponível só como opção futura
para Alto/Ultra com escala < 100%.

**D34 · Presets controlam distâncias de vegetação, alcance da grama, sombras do LOD1 e qualidade da água**
(`data/graphics_presets.gd`). No Baixo a água usa `water_simple.gdshader` (sem SCREEN/DEPTH_TEXTURE), a
grama usa tufos de 8 lâminas e o glow só os níveis largos. Resultado no Baixo/720p: de 9 para 31,5 FPS.

**D35 · Vegetação determinística gerada na carga** (cerca de 6 mil instâncias, menos de 1 s) em vez de
gravada em disco: nada de dados extras, e a mesma seed sempre gera a mesma ilha. Árvores e detalhes são
procedurais (`TreeMesh`, `DetailMeshes`, `RockMesh`); três níveis + impostor com fade por dither.

**D36 · Benchmark fixo implementado** (`-- --bench [--preset=X] [--bench-seconds=N]`) com flags de perfil
de desenvolvimento (`--no-veg`, `--no-grass`, `--no-water`, `--no-shadows`, `--no-fsr`, `--fsr1`, `--no-glow`,
`--no-fog`, `--no-sky`, `--no-terrain`).

## 2026-10-16 (M6)

**D37 · Inimigos: KayKit Skeletons 1.0 (CC0)** — Minion = Rastejante da Névoa (corpo a corpo), Rogue com besta =
Arqueiro Esqueleto, Mage = Bruxa do Pântano (M7), Warrior = base de chefes (M8). Mesmo autor do mago, então o
estilo combina. Recolor por tipo com materiais compartilhados (cache) e olhos emissivos.

**D38 · Sons: Kenney (CC0)** — Impact, Sci-Fi, RPG e Interface Sounds; 169 arquivos escolhidos, mapeados em
`data/sound_bank.gd` (ids lógicos, variação de tom, barramento). Magia em camadas = vários ids juntos.

**D39 · Combate sem nós criados por golpe:** projéteis (48), faíscas, anéis, raios, números, luzes e decals em
pools (`ProjectilePool`, `Vfx`). Teste de 200 conjurações: +8 objetos/+8 recursos após aquecimento (estável).

**D40 · Projéteis por raycast entre posições** (sem Area3D), com máscaras por lado (jogador: mundo+inimigos;
inimigo: mundo+jogador). Dano em área por consulta de esfera.

**D41 · Diretor de combate:** no máximo 2 inimigos atacando ao mesmo tempo; os outros rodeiam. Teste com 5
inimigos ao redor do jogador por 8 s: máximo medido = 2.

**D42 · Navegação:** `NavBaker` assa uma NavigationRegion3D de 140 m ao redor do jogador em thread
(Terrain3D + colisores estáticos próximos), re-assando a cada 45 m. Sem rota válida, o inimigo segue direto
com desvio por raycast (o que também cobre o primeiro frame antes do bake).

**D43 · Camadas visuais:** 1 = mundo, 2 = personagens. Decals de telegrafia só projetam na camada 1 (antes
pintavam o mago de rosa nas capturas).

**D44 · Controles de feitiço:** tocar Q/E/R/F conjura; segurar carrega (Lança Arcana); Q+F juntos = ultimate;
esquiva no ar ou mirando = Passo Umbral (blink). Égide absorve dano (a reflexão de projéteis ficou para o M10).

**D45 · `god_mode` de depuração no Player** (testes de chefe e capturas).

## 2026-10-16 (M7)

**D46 · POIs gerados por regras** (`tools/place_pois.gd` → `data/world_pois.json`, versionado): faróis no ponto mais
alto da região, covis perto do centro das regiões corrompidas, demais tipos em terreno pouco inclinado, com
distância mínima, fora da Cidadela e **conectados ao início** (mesma regra de alcance do teste). 85 POIs.

**D47 · Faróis:** Vale, Floresta, Picos e Terras Calcinadas. O Pântano (centro da corrupção) é revelado e purificado
pelo seu Guardião (M8). Acender um farol revela 420 m no mapa e purifica 35% da região.

**D48 · Interação na tecla G** (`Interactor` escolhe o objeto mais próximo à frente; prompt na HUD). Painéis do
mundo pausam o jogo e são navegáveis por mouse/teclado/gamepad.

**D49 · Fogueiras:** descansar cura, salva (slot 0), define o renascimento, ressuscita os inimigos, permite esperar
até o amanhecer/anoitecer e viajar entre fogueiras descobertas. Autosave a cada 5 min fora de combate.

**D50 · Save v1 estendido sem quebrar o formato:** `progress` (GameState), `world.fog`, `player.stats/equipped/
unlocked`. A migração formal para v2 entra no M9 junto com o inventário.

**D51 · Corrupção por região** (`GameState.BASE_CORRUPTION` × (1 − purificação)) controla névoa violeta, céu e LUT;
`FogVolume` elipsoidal no Pântano; partículas de clima por região; frio nos Picos acima de 125 m (stamina mais
lenta e dano leve após ~18 s, aquecido perto de fogueira acesa ou com a proteção `ward:frost`).

**D52 · Inimigos 3–6:** Morcego Espectral (voador, mergulho telegrafado), Golem (golpe em área com marcador; cristal
nas costas = 3× dano), Bruxa do Pântano (KayKit Skeleton Mage; cura aliados), Serpente do Lago (imune submersa,
emerge, cospe veneno em arco, mergulha). Morcego, golem e serpente são esculpidos e animados por código.

**D53 · Inimigos dormentes a mais de 110 m** do jogador (sem física, sem render) para caber ~70 inimigos na ilha.

**D54 · Interiores em "dimensão de bolso"** (6000, 400, 6000), construídos sob demanda e mantidos em memória; entrar
= fade + teleporte + ambiente fechado. Evita trocar de cena (o mundo aberto e o save continuam iguais).

**D55 · Chefes = `Boss extends Enemy`** com dados em `data/bosses/*.tres` (gerados por `tools/make_bosses.gd`).
A guarda de cada Guardião só cai com o feitiço da sua mecânica; o chefe final alterna as mecânicas a cada fase.

**D56 · Progressão de feitiços:** começam 4 (Lança, Pulso, Corrente, Égide); os outros 4 vêm dos Guardiões.
Vida/mana máximas = 100 + 10·(atributo + sigilos) + equipamento (M9); poder = 1 + 0,08·atributo.

**D57 · Fluxo de cenas:** `levels/main_menu.tscn` é a cena principal; `Game.start_new_game/continue_game` preparam
GameState e Inventory **antes** de montar a ilha (baús e faróis já nascem no estado certo) e trocam de cena pela
`LoadingScreen` (carga em thread). A ilha aplica o resto do save (`apply_save`) no `_ready`.

**D58 · Save v2:** acrescenta `inventory` e `map_markers`; a migração v1 → v2 dá o inventário inicial e lista vazia.
Missões do diário são derivadas das flags (sem estado próprio para migrar).

**D59 · Itens em `data/item_db.gd` (constantes, não .tres):** são poucos, versionáveis e fáceis de validar ao
carregar o save (id desconhecido é descartado). Cajados descrevem o ataque básico (elemento, dano, velocidade,
leque, cadência, status).

**D60 · Gamepad:** feitiços com LB segurado + A/B/X/Y (ações `pad_spell_N`), que não conflitam com pulo/esquiva/
interagir; o remapeamento trata esse contexto à parte. Abas dos menus em Q/E e LB/RB (ações `ui_*`, contexto de
menu, o teste de teclas duplicadas separa os contextos).

**D61 · Daltonismo por daltonização** (Fidaner) num CanvasLayer de tela cheia, além de ícones do mapa distintos por
forma. Janela/tela cheia só é aplicada pelo menu e pelas opções (capturas, benchmark e testes não mexem na janela).

**D62 · Música por estado, não por stems:** cinco faixas CC0 completas com crossfade (AudioStreamInteractive exigiria
faixas compostas em camadas, que não existem em CC0 com qualidade). Prioridade: chefe > combate (folga 5 s) >
interior/corrupção > noite/dia.

**D63 · Ambiente sintetizado:** loops de 24 s gerados em Python (ruído filtrado, chilreios, coaxar, bolhas, fogo,
gotas) e codificados em MP3 com lameenc — obra própria CC0, sem depender de gravações de licença incerta.

**D64 · Dificuldade** como multiplicadores: dano recebido (0,6 / 1 / 1,4) e vida dos inimigos (0,8 / 1 / 1,25).

**D65 · PCK embutido no .exe:** um arquivo só para o jogador (mais a DLL do Terrain3D, que precisa ficar ao lado).
190 MB está longe de qualquer limite. Console desligado no release; o build de debug continua com console.

**D66 · Teste de fumaça do executável** (`-- --export-smoke`): roda o fluxo real de menu, novo jogo, salvar e
carregar dentro do .exe e grava o resultado em `user://export_smoke.txt`, para o aceite do M11 não depender do
editor.

**D67 · MeshMerge:** blocos de pedra gerados por código (faróis, ruínas, Cidadela) viram uma malha por material
depois de montados. Colisões continuam separadas. Props importados e malhas animadas ficam de fora.

**D68 · Alcance de desenho de 150 m** para fogueiras, baús, entradas, histórias e o mercador (luzes somem a partir
de ~70 m). Faróis, ruínas e Cidadela são marcos e continuam visíveis de longe.

**D69 · AutoTune** só desce o preset (nunca sobe) e só uma vez, na primeira execução; o jogador pode voltar pelas
opções. O epílogo congela o jogador e não troca a câmera do Terrain3D (a colisão dinâmica segue essa câmera).

**D70 · 1.0.0-rc1:** todos os itens da seção 16 que dependem só do agente estão verdes; os que dependem do dono
(jogada completa, benchmark no Nitro V15, gamepad físico, ouvir o áudio) estão marcados como NÃO EXECUTADOS.
