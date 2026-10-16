# Dark Mage — The Isle of Fear
## Roteiro completo para criar o jogo do ZERO em **Godot 4** (para o Claude Code executar de forma autônoma)

> **Para o Claude Code:** este documento é a sua especificação e o seu plano de trabalho. Leia tudo
> antes de criar qualquer arquivo. Você tem liberdade criativa total dentro da visão, dos padrões de
> qualidade e das regras aqui definidos. Trabalhe em ciclos até que todos os marcos estejam concluídos
> e o checklist final (seção 16) esteja todo verde.

---

## 0. Regras de ouro (leia primeiro)

1. **Projeto 100% novo.** Não abra, não leia, não copie e não adapte nenhum código, arquivo ou estrutura
   de versões anteriores do jogo (versões em HTML, JavaScript, Three.js ou Electron). Só a **visão** abaixo
   é herdada.
2. **Onde trabalhar.** Crie o projeto numa pasta nova e vazia, `dark-mage-godot/`, com repositório git
   próprio (`git init`), `.gitignore` para Godot (ignore `.godot/`, `*.import` não; veja 7.4) e `.gitattributes`
   com Git LFS para binários grandes (`*.glb`, `*.png`, `*.exr`, `*.hdr`, `*.wav`, `*.ogg`) se o LFS estiver
   disponível. **Nunca** faça push, merge ou PR sem autorização explícita do dono do projeto. Commits locais
   são obrigatórios (um por tarefa concluída).
3. **Qualidade antes de quantidade.** É proibido entregar mundo feito de `BoxMesh`, `SphereMesh`,
   `CylinderMesh` ou `CapsuleMesh` crus como resultado final. Primitivas só servem de placeholder temporário,
   registrado em `TODO.md`, e precisam ser substituídas antes de o marco ser concluído.
4. **Nada de fingir.** Não declare algo pronto sem executar a verificação do marco. Não invente números de
   desempenho. Teste que não puder ser executado é registrado como "NÃO EXECUTADO", com o motivo.
5. **Licenças.** Todo asset de terceiros precisa permitir uso comercial e redistribuição dentro do jogo
   (de preferência CC0). Registre cada um em `ASSETS_LICENSES.md` (nome, autor, URL, licença, data).
   O mesmo vale para plugins e addons (licença MIT ou compatível). Na dúvida, não use.
6. **Versões.** Engine: **Godot 4.7.2 stable** (padrão, sem .NET), a estável mais recente verificada em
   16/10/2026. Antes de começar, rode `godot --version`. Se houver uma 4.7.x mais nova, use-a e registre em
   `DECISIONS.md`. **Não** use builds beta, RC ou dev. Fixe as versões dos addons (seção 7.2).
7. **Autonomia com rastreabilidade.** Não pare para pedir confirmação de decisões técnicas ou criativas que
   este documento já delega a você: decida, registre em `DECISIONS.md` e siga em frente. Pare e pergunte
   **apenas** nos casos da seção 13.4.

---

## 1. Visão do jogo

### 1.1 Pitch
Um mago sombrio desperta numa ilha amaldiçoada, coberta por uma névoa que se alimenta do medo. Para
quebrar a maldição, ele explora livremente a ilha, escala qualquer superfície, plana sobre vales, reacende
antigos faróis arcanos, enfrenta criaturas corrompidas e derrota os quatro Guardiões do Medo que mantêm a
névoa viva. A magia é ao mesmo tempo arma, ferramenta de exploração e expressão do personagem.

### 1.2 Pilares (toda decisão deve servir a pelo menos um)
1. **Exploração livre e curiosa:** "se você vê, pode ir até lá". Mundo aberto, horizonte legível, pontos de
   interesse visíveis de longe, recompensa por curiosidade.
2. **Magia expressiva e satisfatória:** feitiços com peso, antecipação, impacto, som e partículas de
   qualidade. Combate de leitura e esquiva.
3. **Beleza sombria:** a ilha é bonita e ameaçadora ao mesmo tempo. Luz quente e dourada contra sombra fria
   e violeta. Contraste entre áreas seguras (luz) e áreas corrompidas (névoa, roxo, preto).
4. **Clareza:** silhuetas legíveis, UI mínima, o jogador sempre entende o que está acontecendo.

### 1.3 Referências (inspiração, nunca cópia)
- **Exploração:** The Legend of Zelda: Breath of the Wild / Tears of the Kingdom (estrutura aberta, escalada,
  planador, torres que revelam o mapa, santuários curtos).
- **Tom sombrio:** Elden Ring, Hollow Knight, Death's Door.
- **Estilo visual:** estilizado e pintado, com formas simplificadas mas ricas em detalhe de superfície, cor e
  luz (acabamento de Genshin Impact / Tunic / Sea of Stars, com a paleta sombria). **Não** é low-poly
  facetado de "blocos e bolas".

### 1.4 Público e plataforma
- Jogadores de PC que gostam de aventura e exploração. Sessões de 20 a 90 minutos.
- **Plataforma:** executável nativo para Windows (exportação do Godot). Teclado e mouse primeiro; gamepad
  (XInput) completo a partir do M9.
- **Hardware de referência:** notebook Acer Nitro V15 com RTX 4050 Laptop, telas 1920×1080 e 2560×1440.
  Precisa rodar em máquinas mais fracas via presets (seção 10).

### 1.5 Escopo da versão 1.0
- Uma ilha de cerca de 2 km × 2 km com 6 regiões.
- 1 personagem jogável, 8 feitiços, 6 tipos de inimigos comuns e 4 chefes, mais o chefe final.
- 4 faróis, 12 santuários curtos e cerca de 40 baús e segredos.
- Ciclo de dia e noite e clima simples (limpo, névoa, chuva leve).
- Campanha principal de 3 a 5 horas.

---

## 2. Direção de arte

### 2.1 Paleta de identidade
| Papel | Cor | Uso |
|---|---|---|
| Preto profundo | `#0B0910` | Sombras da UI, vestes do mago, corrupção |
| Violeta arcano | `#6B2FD6` | Magia do jogador, névoa corrompida, cristais |
| Violeta brilho | `#B67CFF` | Emissivo, glow, runas |
| Dourado antigo | `#E8B44C` | Luz segura, faróis, recompensas, bordas da UI |
| Âmbar quente | `#FFB765` | Pôr do sol, fogueiras, interiores |
| Verde musgo | `#4F7A3A` | Vegetação saudável |
| Azul crepúsculo | `#2E4A7A` | Céu noturno, água profunda, sombras frias |
| Osso / pedra | `#C9BFA8` | Ruínas, rochas claras |

Regras:
- O **dourado** marca segurança e recompensa; o **violeta** marca magia e perigo.
- Áreas corrompidas: menos saturação, névoa volumétrica violeta, vegetação escurecida.
- Áreas purificadas (depois de vencer um chefe ou acender um farol) ganham cor e luz quente de forma
  visível, como recompensa.

### 2.2 Iluminação e atmosfera (recursos nativos do Godot)
- **Renderer Forward+** (Vulkan no Windows, com D3D12 como alternativa se for mais estável; teste e registre).
- **WorldEnvironment:**
  - tonemap **AgX** ou **ACES** (escolha pelo resultado e documente);
  - glow com threshold calibrado para os emissivos;
  - SSAO e SSIL (Alto ou acima);
  - SSR para água e superfícies molhadas (Alto ou acima);
  - névoa de profundidade e de altura, mais **névoa volumétrica** (`volumetric_fog`) com densidade por região
    via `FogVolume`;
  - ajustes de cor por região e por horário.
- **Céu:** `Sky` com `ProceduralSkyMaterial` ou `PhysicalSkyMaterial` como base, de preferência um **shader de
  céu próprio** (`shader_type sky`), com gradiente artístico, sol, lua, estrelas e nuvens em camadas de ruído
  que se movem. Fonte de luz ambiente e reflexos: `sky`.
- **Iluminação global:** dia e noite dinâmicos impedem lightmap global. Use SDFGI **ou** SSIL mais luz ambiente
  do céu (decida pelo desempenho no preset Alto e registre). Interiores de santuários e covis podem usar
  **LightmapGI** ou **VoxelGI** por cena.
- **Sol e lua:** `DirectionalLight3D` com sombras PSSM de 4 splits, blend entre splits e distância de sombra
  ajustada por preset. A lua usa luz violeta-azulada à noite, e o sol se põe de verdade.
- **Luzes pontuais:** cajado, fogueiras e cristais com `OmniLight3D` / `SpotLight3D`, com sombra só onde
  importa e limite por preset. `AreaLight3D` (novidade do 4.7) para janelas e vitrais, se for estável e
  barato; teste antes.

### 2.3 Materiais e superfícies
- **Terreno:** Terrain3D com 6 a 10 texturas PBR (grama, terra, rocha, areia, neve, solo corrompido, pedra de
  ruína…), mistura por altura, projeção para encostas, variação de macro escala e pintura procedural por regras
  (inclinação, altura, região) gerada por script.
- **Rochas e penhascos:** malhas esculpidas (glTF) com normal map, e nunca formas primitivas.
- **Vegetação:**
  - grama em `MultiMesh` com shader de vento, interação com o jogador e cor por região;
  - árvores com tronco modelado e copa em cards de folhas, com subsurface e backlight leves;
  - flores, arbustos, samambaias e cogumelos bioluminescentes.
- **Água:** shader próprio com ondas (Gerstner leve), fresnel, cor por profundidade (lendo
  `DEPTH_TEXTURE`), refração via `SCREEN_TEXTURE`, espuma na costa e nos obstáculos e cáusticas no raso.
- **Cristais arcanos:** shader com fresnel, emissão violeta, refração falsa e `GPUParticles3D` orbitando.
- **Padrão:** `StandardMaterial3D` / `ORMMaterial3D` para PBR e `ShaderMaterial` para casos especiais.
  Shaders compartilhados em `shaders/` com includes (`.gdshaderinc`).

### 2.4 Personagem: o Mago Sombrio
- Modelo 3D riggado e animado (glTF), com silhueta forte: chapéu alto e pontudo levemente torto, capa longa
  com movimento secundário (ossos com `SpringBoneSimulator3D` ou `PhysicalBoneSimulator3D`, conforme o
  disponível na versão), manto preto com acabamentos dourados, olhos com brilho violeta e um cajado com
  cristal que emite luz real.
- **Animações mínimas:** idle (2 variações), andar, correr, sprint, pular (subida, queda, aterrissagem),
  escalar (4 direções e transição para o topo), planar, nadar, esquivar, conjurar (rápido, carregado, em
  área), dano, morte e interação.
- `AnimationTree` com `AnimationNodeStateMachine` e `BlendSpace2D` para a locomoção, inclinação nas curvas e
  IK de pés no terreno via modificadores de esqueleto (`SkeletonModifier3D` e derivados disponíveis no 4.7)
  no preset Alto ou acima.

### 2.5 Proibições visuais
- Nada de malhas primitivas cruas como objeto final.
- Nada de superfícies grandes com cor chapada sem variação.
- Nada de luz plana nem céu de cor única.
- Nada de bordas duras entre biomas.
- Nada flutuando ou enterrado: tudo assentado no terreno (teste automático, seção 11).

---

## 3. O mundo: a Ilha do Medo

### 3.1 Estrutura geral
- Ilha de cerca de 2 km × 2 km com **Terrain3D** (regiões de terreno com LOD, colisão e instanciador de
  foliage), gerada por **script de ferramenta** (`@tool` / `EditorScript` ou script de linha de comando):
  - heightmap por ruído (`FastNoiseLite`: fBm, ridged, domain warp) com máscaras e ajustes autorais para
    vales, cristas, mirantes e rios;
  - resultado salvo nos dados do Terrain3D (versionados).
- **Mundo determinístico:** seed fixa documentada. Regerar com a mesma seed produz os mesmos dados (teste).
- **Composição:** de qualquer ponto alto, o jogador vê 2 ou 3 pontos de interesse atraentes (regra do
  triângulo: colinas escondem e revelam).
- **Limite natural:** mar aberto com correntes ou névoa densa.

### 3.2 Regiões (nomes e detalhes livres; proposta inicial)
1. **Vale do Despertar (centro):** campos dourados, ruínas com musgo e o primeiro farol. Tutorial natural.
2. **Floresta Sussurrante (sul):** árvores gigantes, cogumelos bioluminescentes, neblina baixa e rios.
3. **Picos Gélidos (norte):** neve, gelo, vento e cavernas de cristal. Mecânica simples de frio.
4. **Terras Calcinadas (leste):** rocha vulcânica, rios de lava e céu avermelhado.
5. **Pântano Violeta (oeste):** água rasa, árvores mortas e névoa roxa espessa. Centro da corrupção.
6. **Costa dos Naufrágios (litoral):** praias, falésias, navios encalhados e grutas.
- **Cidadela do Medo (centro-norte):** castelo em ruínas sobre um platô, visível de toda a ilha. É o
  confronto final.

### 3.3 Pontos de interesse
- **4 Faróis Arcanos:** torres escaláveis que revelam a região no mapa e purificam a área ao redor.
- **12 Santuários:** desafios de 2 a 5 minutos em cenas internas instanciadas (quebra-cabeça com magia,
  combate ou plataforma). Recompensa: fragmento de vida ou de mana.
- **4 Covis dos Guardiões:** masmorras curtas que terminam no chefe.
- **Fogueiras de Repouso:** save, cura e viagem rápida.
- **Segredos:** baús, elites, mirantes e histórias ambientais.
- **Regra:** nenhum ponto de interesse dentro de rocha, flutuando ou submerso por engano. Todos alcançáveis
  (teste automático).

### 3.4 Streaming e escala
- O Terrain3D cuida do LOD do terreno.
- Conteúdo por **células** (por exemplo, 128 m), carregadas e descarregadas por distância com
  `ResourceLoader.load_threaded_request` e orçamento por frame.
- Use **visibility ranges** (HLOD) e fade nos objetos, **occlusion culling** (`OccluderInstance3D`) em ruínas
  e cidadela, e LOD automático das malhas importadas.
- Sem "pop-in" brusco: fade por dither nas visibility ranges.

---

## 4. Jogabilidade

### 4.1 Controles (`InputMap`, todos remapeáveis e salvos; gamepad equivalente)
| Ação | Teclado e mouse | Gamepad |
|---|---|---|
| Mover | W A S D | Analógico esquerdo |
| Câmera | Mouse (captura), sensibilidade e Y invertível | Analógico direito |
| Pular / planar | Espaço | A |
| Sprint | Shift (segurar) | Pressionar o analógico esquerdo ou B (segurar) |
| Esquiva | Ctrl ou C | B |
| Ataque básico | Botão esquerdo | RT |
| Mirar | Botão direito (segurar) | LT |
| Feitiços 1–4 | Q, E, R, F | LB/RB + face, ou roda rápida |
| Interagir | G (ou E contextual; escolha e documente) | X |
| Travar alvo | Botão do meio ou Tab | Pressionar o analógico direito |
| Inventário / Mapa / Pausa | I / M / Esc | Select / D-pad / Start |

- **Não use Alt** como ação.

### 4.2 Movimento e travessia
- `CharacterBody3D` com `move_and_slide`, `floor_max_angle`, degraus (`floor_snap_length` e teste de degrau),
  coyote time e buffer de pulo.
- **Física:** Jolt Physics, nativo desde o 4.4. Confirme em Project Settings → Physics → 3D → Physics Engine
  e registre.
- **Escalada** livre em superfícies íngremes (raycasts/shapecasts para detectar parede, normal e topo), com
  custo de stamina; a chuva deixa escorregadio.
- **Planador mágico** (asas de energia violeta) com stamina.
- **Natação** com stamina e afundamento lento ao esgotar, reaparecendo na margem.
- **Stamina:** roda contextual perto do personagem.
- **Câmera:** `SpringArm3D` com colisão, suavização, zoom, ombro na mira e enquadramento em combate.

### 4.3 Combate mágico
- **Ataque básico:** projétil do cajado com combo de 3 golpes.
- **8 feitiços** (nomes, visual e números livres), cobrindo:
  1. projétil carregável;
  2. área ao redor (empurra);
  3. raio em cadeia;
  4. barreira;
  5. impacto no ponto mirado (com decal indicador);
  6. blink (também usado na exploração);
  7. controle (congelar ou enraizar);
  8. ultimate, que carrega com dano causado.
- **Exploração:** pelo menos 2 feitiços interagem com o mundo (queimar espinhos, congelar água, acender
  braseiros, revelar runas).
- **Telegrafia:** inimigos mostram pose de preparação, brilho e decal no chão. A esquiva tem frames de
  invencibilidade, e a esquiva perfeita dá bônus.
- **Impacto:** hit-stop (40 a 80 ms via `Engine.time_scale` local ou pausa seletiva), tremor de câmera
  proporcional, números de dano (desligáveis), `GPUParticles3D`, som em camadas e flash no inimigo.
- **Recursos:** vida, mana e stamina.
- **Arquitetura:** dados de feitiços em `Resource` próprios (`SpellData.tres`), efeitos como cenas
  instanciadas com **pool**.

### 4.4 Inimigos (6 comuns, com variantes de elite)
1. **Rastejante da névoa:** corpo a corpo, em grupo.
2. **Arqueiro esqueleto:** distância, procura cobertura.
3. **Morcego espectral:** voador e errático.
4. **Golem de pedra corrompida:** lento, golpes em área, ponto fraco brilhante.
5. **Bruxa do pântano:** cura e protege aliados.
6. **Serpente do lago:** emerge da água.
- **IA:** máquina de estados ou behavior tree (implementação própria simples, ou addon MIT verificado),
  `NavigationAgent3D` sobre `NavigationRegion3D` assado por célula, percepção por visão e som e limite de
  2 atacantes simultâneos.
- Mais fortes e numerosos à noite e nas áreas corrompidas.

### 4.5 Chefes: os 4 Guardiões do Medo, mais o chefe final
- Arena própria, 2 fases (mudança visual e novos ataques), padrões aprendíveis, telegrafia clara e uma
  mecânica que exige um feitiço específico.
- Chefe final na Cidadela do Medo com 3 fases.
- A vitória purifica a região (transição de ambiente, névoa e cor) e concede um feitiço ou habilidade.

### 4.6 Progressão e economia
- Nível por experiência e pontos de atributo (vida, mana, stamina, poder arcano).
- Equipamento: cajados (alteram o ataque básico), mantos e amuletos.
- Moeda (fragmentos de alma), cristais e materiais de região. Um mercador misterioso.
- Terminável sem grind; o opcional recompensa a exploração.

### 4.7 Sistemas de suporte
- **Inventário** em grade, com categorias, comparação e arrastar e soltar.
- **Mapa** com névoa de guerra (textura revelada), marcadores e viagem rápida.
- **Diário** de missões (principal e opcionais).
- **Save:** automático e manual, 3 slots, em `user://saves/`.
  - Formato **JSON ou `ConfigFile` versionado**, com migração.
  - **Não** salve com `ResourceSaver` em `.tres` carregável: recursos podem conter scripts e abrir brecha.
  - Valide ao carregar e mantenha backup do último save válido.
- **Dia e noite:** ciclo de cerca de 24 minutos reais, afetando inimigos, fauna, luz e santuários noturnos.
- **Clima** com transições suaves (névoa, chuva com `GPUParticles3D` e superfícies molhadas via shader).

### 4.8 Narrativa
- Narrativa ambiental: introdução curta, textos em altares e diários, falas breves dos chefes e epílogo
  visual com a ilha purificada.
- **Localização:** `TranslationServer` com CSV ou PO (`pt_BR` padrão, estrutura pronta para `en`).

---

## 5. Áudio
- **Barramentos** (`AudioServer`): Master, Música, Efeitos, Ambiente, UI e Voz, com efeitos de reverb em
  cavernas e interiores via `Area3D` com reverb bus.
- **Música** adaptativa por região e estado (exploração, combate, chefe) com crossfade. Considere
  `AudioStreamInteractive` / `AudioStreamSynchronized`, nativos do Godot 4.3+.
- **Efeitos:** passos por tipo de chão, vento, água, fogo, magia em camadas (carga, disparo, impacto), UI e
  ambiente por região.
- **Posicional:** `AudioStreamPlayer3D` com atenuação e limite de vozes simultâneas.
- Faixas e sons CC0, ou com licença compatível registrada.

---

## 6. Interface (UI/UX)
- **HUD mínimo** (nós `Control` com `Theme` próprio): vida e mana discretas, stamina contextual, feitiços com
  cooldown, bússola opcional, indicador de lock-on. Some fora de combate (opção).
- **Menus:** inicial, pausa, inventário, mapa, diário e opções, com navegação por mouse, teclado e gamepad
  (foco configurado em todos os controles).
- **Estilo:** preto translúcido com filetes dourados, fonte serifada elegante nos títulos e sem serifa legível
  no corpo (fontes com licença OFL), ícones próprios em SVG e animações com `Tween`.
- **Opções:** presets e ajustes individuais de gráficos, áudio, remapeamento, sensibilidade, inverter Y,
  legendas, daltonismo, FOV, escala de UI, redução de tremor e flashes e modo janela, borderless ou tela cheia.
- **Overlay de desenvolvedor** (F3, só em build de debug ou com o argumento `--dev`): FPS, tempo de frame
  (médio, P95, P99), draw calls, primitivas, memória de vídeo e de objetos (`Performance.get_monitor`),
  posição, célula e região.

---

## 7. Arquitetura técnica

### 7.1 Base
| Item | Escolha | Motivo |
|---|---|---|
| Engine | **Godot 4.7.2 stable** (padrão, sem .NET) | Estável atual, open source, exporta nativo para Windows |
| Linguagem | **GDScript com tipagem estática** em tudo (`var x: int`, retornos tipados, `class_name`) | Iteração rápida, sem dependência de .NET, bom desempenho com tipagem. Use GDExtension/C++ só se um gargalo medido exigir |
| Renderer | Forward+ | Recursos completos (SDFGI, névoa volumétrica, SSR…) |
| Física | Jolt (nativo) | Estável e rápido para personagem e mundo |
| Terreno | Terrain3D (addon MIT, TokisanGames) | Terreno grande com LOD, colisão, texturas e foliage |
| Testes | GdUnit4 (addon MIT) | Testes unitários e de cena via linha de comando |

### 7.2 Addons (verifique a versão e a compatibilidade com 4.7.2 antes de instalar; fixe e registre)
- **Terrain3D:** versão estável mais recente compatível com 4.7 (1.0.x em 16/10/2026). Instale em
  `addons/terrain_3d/` a partir da release oficial do GitHub ou da Asset Store.
- **GdUnit4:** versão 6.x compatível com 4.7. Confirme o comando de execução no README da versão instalada.
- Outros addons só com justificativa em `DECISIONS.md` (licença, manutenção ativa, compatível com 4.7).
  Não instale addons abandonados.
- **Ferramentas externas opcionais:** Blender (para ajustes de modelos e importação `.blend`) e
  gltf-transform (otimização). Se não estiverem disponíveis, registre e siga sem elas.

### 7.3 Estrutura do projeto
```
dark-mage-godot/
  project.godot  export_presets.cfg  .gitignore  .gitattributes
  README.md DESIGN.md DECISIONS.md PROGRESS.md TODO.md ASSETS_LICENSES.md CREDITS.md QA_CHECKLIST.md PERFORMANCE.md
  addons/                 # terrain_3d, gdUnit4 (versões fixas)
  autoload/               # Game.gd, Events.gd (barramento de sinais), Settings.gd, SaveSystem.gd, Audio.gd, Rng.gd
  core/                   # utilidades, pools, máquina de estados, constantes
  world/                  # gerador da ilha (tool), células, POIs, ciclo dia/noite, clima, água
  player/                 # Player.tscn, controlador, câmera, animação, habilidades
  combat/                 # dano, status, projéteis, feitiços (SpellData), hit-stop
  ai/                     # inimigos, FSM/BT, percepção, chefes
  ui/                     # HUD, menus, inventário, mapa, opções, Theme
  data/                   # .tres de itens, feitiços, inimigos, loot; tabelas CSV de tradução
  shaders/                # .gdshader e .gdshaderinc (água, céu, vegetação, cristal, terreno extra)
  vfx/                    # cenas de partículas e decals
  assets/                 # models (.glb), textures, hdri, audio, fonts (com licenças)
  levels/                 # ilha principal, santuários, covis, arenas
  tools/                  # scripts CLI: gerar ilha, capturas, benchmark, checagem de licenças
  tests/                  # unit/, scene/, e2e/ (GdUnit4), golden/ (capturas de referência)
  build/                  # saída de exportação (ignorada no git)
```

### 7.4 Git e Godot
- `.gitignore`: `.godot/`, `build/`, `*.translation` gerado, `export_credentials.cfg`.
- **Versione** os arquivos `.import` (o Godot 4 mantém os metadados de importação neles).
- Cenas e recursos em formato texto (`.tscn` / `.tres`), para diffs legíveis.

### 7.5 Princípios de código
- **Composição por cenas e nós.** Comunicação por **sinais** e um autoload `Events` para eventos globais.
  Evite referências rígidas entre sistemas.
- **Física e jogo** em `_physics_process` (60 Hz fixo); visual em `_process`, com interpolação de física
  (`physics/common/physics_interpolation`) para movimento suave em telas de alta taxa de atualização.
- **Dados de jogo** em `Resource` tipados (`class_name SpellData extends Resource`), ajustáveis no inspetor.
- **Desempenho:**
  - **pool** para projéteis, partículas e números de dano, sem `instantiate()` e `queue_free()` em massa por frame;
  - `MultiMeshInstance3D` para repetição;
  - liberar recursos ao descarregar células.
- **Determinismo:** `RandomNumberGenerator` com seed por sistema (mundo, loot); aleatório comum para efeitos.
- **Carregamento:** `load_threaded_request` para células e cenas grandes, com tela de loading estilizada.
- **Avisos:** zero warnings do GDScript (trate warnings de tipagem como erros nas configurações do projeto).

---

## 8. Renderização: especificação detalhada
1. **Projeto:** Forward+; MSAA 3D desligado (custo alto com vegetação); antialiasing por **TAA ou FSR 2**
   (`scaling_3d_mode`) mais FXAA no Baixo. Escala de render por preset. VSync configurável e limite de FPS
   opcional.
2. **Sombras:** `DirectionalLight3D` com PSSM de 4 splits (Alto e Ultra) ou 2 (Médio/Baixo), tamanho do atlas
   por preset, bias calibrado (sem acne nem peter-panning), soft shadows (filtro por preset) e sombra de
   contato ou AO nos pés.
3. **Terreno (Terrain3D):** texturas PBR empacotadas como o addon exige (albedo+altura, normal+rugosidade),
   mistura por altura, detalhe de perto, macro variação de longe, pintura procedural por regras e colisão do
   próprio addon (**a mesma fonte para visual e física**).
4. **Vegetação:**
   - grama por `MultiMesh` em chunks perto da câmera (ou o instanciador do Terrain3D), shader com vento por
     ruído, interação com o jogador (posição passada como uniform global) e fade por distância;
   - árvores e arbustos com LOD da importação mais visibility ranges e impostor de longe;
   - distribuição por Poisson disk e regras de bioma, com clareiras em POIs e trilhas.
5. **Céu e atmosfera:** shader de céu próprio, ciclo completo, nuvens em camadas, névoa de altura e volumétrica
   (`FogVolume` por região corrompida) e radiance do céu atualizada em ritmo controlado (não a cada frame no
   preset Baixo).
6. **Água:** shader com Gerstner, fresnel, profundidade (`DEPTH_TEXTURE`), refração (`SCREEN_TEXTURE`),
   espuma, cáusticas e SSR no Alto ou acima.
7. **Pós-processamento** (WorldEnvironment e efeitos de câmera): glow, SSAO, SSIL, ajustes de cor/LUT por
   região e horário, DOF só em menus e cutscenes, vinheta e tremor de tela via shader de pós
   (`CompositorEffect` ou quad de tela, desligável).
8. **VFX:**
   - `GPUParticles3D` com flipbooks, trails e attractors/collision quando fizer sentido;
   - `Decal` para impactos e indicadores no chão;
   - `MeshInstance3D` com shader para ondas de choque e anéis;
   - shader de distorção para calor (Alto ou acima).
9. **Personagens:** materiais PBR com rim light sutil (shader ou `rim` do StandardMaterial3D), olhos e cristal
   emissivos e outline opcional fino (inverted hull ou pós), decidido pelo resultado.

---

## 9. Assets: estratégia
- **Fontes preferidas (verifique a licença na página no momento do download):**
  - Poly Haven (HDRIs, texturas, modelos, CC0);
  - ambientCG (texturas PBR, CC0);
  - Quaternius (personagens, inimigos e natureza estilizada com animações, CC0);
  - Kenney (UI, áudio, modelos, CC0);
  - KayKit / Kay Lousberg (pacotes estilizados, CC0);
  - Freesound (só CC0, ou CC-BY com crédito);
  - Google Fonts / fontes OFL.
- **Importação no Godot:** glTF/GLB com geração de LOD automática, compressão VRAM (BPTC/S3TC para desktop),
  mipmaps, normal maps marcados corretamente e materiais extraídos para `.tres` quando precisar de ajuste.
- **Sem internet ou com download falhando:** gere assets procedurais **de qualidade**:
  - malhas com `SurfaceTool` / `ArrayMesh` (deformação por ruído, subdivisão, perfis girados e extrudados);
  - texturas por shader ou `Image` gerada por script;
  - árvores por L-system e rochas por ruído 3D.
  - Registre em `TODO.md` o que deve ser substituído.
- **Personagem e inimigos:**
  - prioridade 1: modelo animado CC0 adaptado (recolorir, acrescentar chapéu, capa e cajado como malhas
    presas a `BoneAttachment3D`);
  - prioridade 2: modelo próprio.
  - Nunca bonecos de primitivas como resultado final.
- **Checagem:** `tools/check_licenses.gd` (executado na verificação de cada marco) falha se algum arquivo de
  `assets/` não estiver listado em `ASSETS_LICENSES.md`.
- **Orçamento:**
  - herói até cerca de 30 mil triângulos;
  - inimigo comum até cerca de 15 mil;
  - chefe até cerca de 60 mil;
  - texturas de 2048 no máximo (1024 no Médio, 512 no Baixo, via `rendering/textures` e mipmap bias por preset).

---

## 10. Desempenho e presets

| Preset | Alvo | Escala de render | Sombras | Vegetação | Efeitos |
|---|---|---|---|---|---|
| **Ultra** | RTX 4050: ≥ 60 FPS em 2560×1440 | 100% (ou FSR Qualidade) | PSSM 4, atlas 4096 | 100%, raio grande | SDFGI ou SSIL, SSR, volumétrica alta |
| **Alto** (padrão na RTX 4050) | ≥ 100 FPS em 1920×1080 (frame ≤ 10 ms) | 100% | PSSM 4, 2048 | 80% | SSAO, SSIL, SSR, volumétrica média |
| **Médio** | GPU integrada moderna (Iris Xe / Radeon 680M): ≥ 60 FPS em 1080p (**estimado**, validar) | 75% + FSR | PSSM 2, 2048 | 50% | SSAO baixo, volumétrica baixa |
| **Baixo** | GPU integrada antiga: ≥ 30 FPS em 720p (**estimado**) | 60% + FSR | PSSM 2, 1024 | 25% | sem SSAO/SSR/volumétrica |

- **Detecção inicial:** pelo nome do adaptador (`RenderingServer.get_video_adapter_name()`) e por um
  microbenchmark de 3 segundos. O jogador pode trocar a qualquer momento.
- **Orçamentos no Alto, cena típica:** ≤ 2.000 draw calls (meta ≤ 1.000), memória de vídeo estável e
  **sem crescimento** de objetos e recursos após 10 minutos (monitores `OBJECT_COUNT`, `RESOURCE_COUNT`,
  `RENDER_VIDEO_MEM_USED`).
- **Benchmark fixo** (`godot --path . -- --bench`): voo de câmera de 60 s por 3 regiões que grava JSON em
  `user://bench/` com FPS médio, P95 e P99, draw calls e memória. É a fonte de verdade para comparar marcos.
- **Limitação a registrar:** se o ambiente do agente não tiver GPU, os números de FPS são "NÃO EXECUTADO". O
  dono do projeto roda o benchmark no Nitro V15 e cola o JSON em `PERFORMANCE.md`.

---

## 11. Testes e garantia de qualidade (tudo executável pela linha de comando)
- **Importar e validar o projeto:** `godot --headless --path . --import`, sem erros. Depois
  `godot --headless --path . --quit-after 120`, que carrega a cena principal e sai, sem erros no log.
- **Unitários e de cena (GdUnit4, em `--headless`):**
  - RNG com seed;
  - gerador da ilha (mesma seed gera o mesmo hash dos dados de altura);
  - dano, status, cooldowns, inventário, loot e migração de save;
  - controlador do jogador com input simulado (`Input.action_press` / `parse_input_event`): andar N frames
    leva à posição esperada (determinismo);
  - POIs: nenhum dentro de rocha, flutuando ou submerso por engano (raycast contra a colisão do terreno);
    todos alcançáveis (consulta ao `NavigationServer3D` ou checagem de inclinação);
  - save: salvar, recarregar e conferir; carregar a fixture da versão anterior;
  - vazamento: 200 conjurações seguidas com `OBJECT_COUNT` e `RESOURCE_COUNT` estáveis (tolerância definida);
  - chefes: com god mode de debug, cada chefe morre e a transição de purificação acontece.
- **Golden visual:** `tools/capture.gd` (rodado **com renderização**, sem `--headless`) posiciona a câmera em
  8 a 12 poses fixas por marco, com hora do dia e clima fixos, e salva PNGs em `tests/golden/<marco>/`.
  - Compare com a referência com tolerância.
  - A referência só é atualizada conscientemente, com o motivo em `PROGRESS.md`.
  - **Se o ambiente não tiver GPU:** tente o renderer de compatibilidade ou um driver de software (Mesa
    llvmpipe/lavapipe) só para capturas funcionais, e registre que não representam a qualidade final.
- **Revisão visual pelo próprio agente:** ao fim de cada marco, gere as capturas, **abra e olhe as imagens**
  e escreva uma autocrítica honesta em `PROGRESS.md`, comparando com a seção 2 e as proibições de 2.5.
- **Exportação:** `godot --headless --path . --export-release "Windows Desktop" build/DarkMage.exe` precisa
  funcionar a partir do M11 (export templates 4.7.2 instalados), e o executável roda sem o editor.

---

## 12. Plano de marcos
> Cada marco só termina quando **todos** os critérios de aceite passam. Faça commit ao fim de cada tarefa e
> crie a tag local `m<N>` no fim do marco. Atualize `PROGRESS.md` sempre.

### M0. Fundação
- Projeto Godot 4.7.2, estrutura de pastas, autoloads (`Game`, `Events`, `Settings`, `SaveSystem`, `Rng`),
  `InputMap` completo, GdUnit4 e Terrain3D instalados e fixados, documentos criados, warnings tratados como
  erros, overlay F3 e cena de teste vazia com WorldEnvironment básico.
- **Aceite:** `--import` e `--quit-after` sem erros; GdUnit4 roda um teste de exemplo pela linha de comando.

### M1. Render base e atmosfera
- Shader de céu, ciclo dia e noite, sol e lua, sombras PSSM, névoa de altura e volumétrica, glow, tonemap,
  ajustes de cor e presets iniciais.
- **Aceite:** capturas ao amanhecer, meio-dia, pôr do sol e noite com céu, luz e sombra coerentes; nada chapado.

### M2. Terreno da ilha
- Gerador CLI/tool da ilha com Terrain3D, regiões e máscaras, texturas PBR, pintura procedural, mar e costa,
  colisão.
- **Aceite:**
  - mesma seed gera o mesmo hash (teste);
  - a colisão coincide com o visual (raycast em 10 mil pontos contra a altura do Terrain3D, diferença ≤ 0,05 m);
  - transições de bioma suaves nas capturas.

### M3. Personagem jogável
- Mago importado e adaptado, `AnimationTree` com blend, controlador (andar, correr, pular, cair, aterrissar),
  câmera `SpringArm3D` e stamina.
- **Aceite:** não atravessa o terreno, câmera estável, transições sem pulo, teste de movimento determinístico.

### M4. Vegetação e composição
- Grama, árvores e arbustos com LOD e visibility ranges, vento, interação, distribuição por regras, rochas e
  penhascos de qualidade.
- **Aceite:**
  - capturas de floresta, campo e montanha aprovadas na autocrítica (nenhuma primitiva crua);
  - benchmark dentro do orçamento do Alto, ou NÃO EXECUTADO se não houver GPU.

### M5. Travessia avançada
- Escalada, planador, natação, blink e mapa com névoa de guerra.
- **Aceite:** percurso de teste com input simulado cobre escalar, planar e nadar até um marcador.

### M6. Combate e magia (fatia vertical)
- Ataque básico, 4 feitiços, mira, lock-on, esquiva com frames de invencibilidade, hit-stop, VFX e áudio de
  impacto, 2 inimigos com IA e navegação.
- **Aceite:** **fatia vertical** de 10 minutos no Vale do Despertar com aparência de produto final; teste de
  vazamento estável.

### M7. Conteúdo do mundo
- As 6 regiões, faróis, fogueiras com viagem rápida, baús, segredos e os 6 inimigos.
- **Aceite:** testes de POIs (posição e alcance) passam; cada região tem identidade própria nas capturas.

### M8. Santuários, Covis e Chefes
- 12 santuários, 4 covis com chefes de 2 fases, chefe final de 3 fases e purificação.
- **Aceite:** jogo completável do início ao fim (`QA_CHECKLIST.md`); testes de chefe com god mode passam.

### M9. Progressão, UI completa e gamepad
- Níveis, atributos, equipamentos, mercador, inventário, mapa, diário, menus, opções, acessibilidade,
  remapeamento e gamepad em toda a UI.
- **Aceite:** tudo navegável por mouse, teclado e gamepad; o save guarda e restaura tudo; migração testada.

### M10. Áudio e polimento
- Música adaptativa, ambiente por região, barramentos e reverb, juice e ajuste de dificuldade.
- **Aceite:** checklist de polimento 100% e autocrítica visual e sonora registrada.

### M11. Exportação Windows
- `export_presets.cfg` para Windows Desktop (64 bits): ícone, nome "Dark Mage - The Isle of Fear", versão,
  PCK embutido ou separado (decida e documente), sem console em release e saves em `user://` (AppData).
- Build de release pela linha de comando.
- **Aceite:** o `.exe` exportado abre, chega ao menu, carrega e salva um jogo e roda offline. Registre que o
  Windows SmartScreen vai alertar sem assinatura de código (fora do escopo).

### M12. Otimização e release candidate
- Perfilar (profiler e monitores do Godot), cortar draw calls, ajustar LOD e visibility ranges, validar
  presets, eliminar vazamentos e corrigir bugs.
- **Aceite:** todos os itens da seção 16 verdes.

---

## 13. Protocolo de trabalho autônomo

### 13.1 Ciclo de cada tarefa
1. Leia `PROGRESS.md` e `TODO.md`.
2. Escreva o mini-plano da próxima tarefa (3 a 6 linhas) em `PROGRESS.md`.
3. Implemente em passos pequenos. **Edite cenas e recursos como texto** (`.tscn`/`.tres`) com cuidado, ou crie
   e modifique cenas por script `@tool`/CLI. Depois de editar `.tscn` manualmente, sempre rode `--import` e
   `--quit-after` para validar.
4. Verifique: importação sem erros, zero warnings, GdUnit4 verde, capturas quando houver mudança visual.
   **Olhe as capturas.**
5. Se falhar, corrija e repita. Nunca avance com teste vermelho.
6. Faça commit local com mensagem clara (`M4: vento hierárquico nas árvores`).
7. Atualize `PROGRESS.md` com o que foi feito, os testes (APROVADO, REPROVADO, INCONCLUSIVO ou NÃO EXECUTADO),
   as decisões e o próximo passo.

### 13.2 Continuidade entre sessões
- `PROGRESS.md` precisa permitir que uma sessão nova continue de onde parou: marco atual, tarefa atual,
  últimos resultados e próximos 3 passos.
- **Ao iniciar qualquer sessão:** leia este roteiro, `PROGRESS.md`, `DECISIONS.md` e `TODO.md`, rode
  `--import` e os testes, e só então continue.

### 13.3 Qualidade contínua
- Revisão adversarial ao fim de cada marco: o que um jogador acharia feio, confuso ou chato? Corrija o que for
  barato e mande o resto para `TODO.md` com prioridade.
- Máximo de 10 placeholders abertos ao mesmo tempo.

### 13.4 Quando parar e perguntar ao dono do projeto (somente nestes casos)
- Licença que não seja claramente permissiva.
- Qualquer gasto de dinheiro (assets pagos, serviços).
- Decisão que mude a visão do jogo (seção 1) ou reduza o escopo da 1.0.
- Push, merge, PR ou publicação.
- Bloqueio na mesma falha após 3 tentativas com abordagens diferentes. Antes de perguntar, documente o
  bloqueio em `PROGRESS.md` e adiante outra tarefa independente, se houver.
- Instalação de software no sistema (Godot, export templates, Blender) quando não estiver disponível e exigir
  privilégios ou download grande: explique o que falta e como instalar.

### 13.5 O que nunca fazer
- Reaproveitar código ou arquivos de versões antigas do jogo.
- Pular ou desativar testes para "ficar verde".
- Ignorar erros ou warnings do Godot.
- Usar versões beta, RC ou dev do Godot ou de addons.
- Marcar um marco como concluído sem cumprir os critérios.
- Salvar o progresso do jogador em formato que execute código ao carregar.

---

## 14. Ambiente necessário (preparo da máquina, feito pelo dono uma vez)
1. Baixar o **Godot 4.7.2 stable (padrão, não .NET)** do site oficial e colocar o executável no PATH como
   `godot`. Ou informar o caminho ao Claude Code; ele deve usar `godot --version` para confirmar.
2. No editor: Editor → Manage Export Templates → baixar os templates da **mesma versão** (necessário a partir
   do M11).
3. Git instalado; Git LFS recomendado.
4. **Opcional:** Blender (versão estável atual) no PATH.
5. Internet liberada para baixar addons e assets CC0.
6. **Executar na máquina com a RTX 4050**, para que as capturas e o benchmark sejam reais.

---

## 15. Riscos e mitigação
| Risco | Mitigação |
|---|---|
| Escopo grande demais | Fatia vertical no M6 antes de expandir; cortar conteúdo, nunca qualidade |
| Agente editando `.tscn` à mão e corrompendo cenas | Preferir cenas geradas por script; validar com `--import`/`--quit-after` após cada edição; commits pequenos |
| Addon incompatível com a versão | Fixar versões; testar a instalação no M0; ter plano B registrado (por exemplo, terreno por `HeightMapShape3D` + malha própria em chunks) |
| Assets CC0 com estilos inconsistentes | Unificar por material, paleta, ajustes de cor e pós; preferir poucos pacotes do mesmo autor |
| Desempenho com vegetação e efeitos | Visibility ranges, MultiMesh, occlusion culling, presets e benchmark a cada marco |
| Sem GPU no ambiente do agente | Testes headless para a lógica; capturas e FPS medidos pelo dono |
| Contexto do agente acaba | `PROGRESS.md` sempre atualizado, tarefas pequenas e commits frequentes |
| Problemas de licença | `ASSETS_LICENSES.md` obrigatório e checagem automática |

---

## 16. Definição de "pronto" (checklist final da versão 1.0)
- [ ] Jogo completável do início ao fim (4 Guardiões e chefe final), validado em `QA_CHECKLIST.md`.
- [ ] Nenhuma primitiva crua como objeto final; autocrítica visual aprovada em todas as regiões.
- [ ] Direção de arte respeitada: paleta, luz, névoa, transições suaves e purificação visível.
- [ ] Os 8 feitiços, 6 inimigos e 4 chefes + 1 final, com VFX e áudio.
- [ ] Escalada, planador, natação, blink, mapa, viagem rápida e save com 3 slots.
- [ ] Teclado, mouse e gamepad, com remapeamento.
- [ ] Presets Baixo/Médio/Alto/Ultra; benchmark do Alto dentro do orçamento no Nitro V15 (medido pelo dono).
- [ ] Sem vazamento em 10 minutos de jogo e 200 conjurações.
- [ ] GdUnit4 verde, golden visual aprovado, zero erros e warnings.
- [ ] `ASSETS_LICENSES.md` e `CREDITS.md` completos.
- [ ] Executável Windows exportado e rodando offline sem o editor.
- [ ] `README.md` com como abrir no editor, rodar os testes, exportar e a estrutura do projeto.

---

## 17. Primeira mensagem esperada do Claude Code
1. Confirmar que leu este roteiro e que **não** usará código antigo.
2. Rodar `godot --version` e `git --version`; informar se há GPU (nome do adaptador) e acesso à internet.
3. Confirmar a pasta e o repositório de trabalho (seção 0, item 2).
4. Verificar as versões estáveis atuais de Terrain3D e GdUnit4 compatíveis com o Godot instalado.
5. Iniciar o M0 imediatamente, seguindo o protocolo da seção 13.
