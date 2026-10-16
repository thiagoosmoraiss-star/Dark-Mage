# Contexto para continuar o projeto Dark Mage no Claude Code

Você vai continuar um trabalho que comecei em outra sessão. Leia tudo antes de agir. Responda em português, de forma direta.

## 1. Projeto

- **Jogo:** "Dark Mage - The Isle of Fear" (nome definitivo, igual ao da minha pasta). Nome antigo dentro do código: "Aethelgard 3D v2.0 - Elden & Arcane Realms".
- **Repositório:** `thiagoosmoraiss-star/Dark-Mage` (GitHub).
- **Estrutura do jogo:** um único `index.html` (~4.700 linhas: CSS, HUD em HTML, script principal e um "Patch v2.4" no final). Usa **Three.js r128 via CDN** (`https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js`), que é a única dependência externa. Não há bundler nem assets: toda a geometria é procedural.
- **Personagem:** Mago Sombrio. O mundo tem ilha de raio 2800, biomas, castelo em (-750,-750), cavernas, chefes, inventário, hotbar, save no `localStorage` e ciclo de dia/noite.
- **Objetivo geral:** elevar a qualidade visual (referência: Zelda BotW/TotK com fantasia sombria em preto, roxo e dourado) **sem reescrever o jogo, sem remover sistemas e sem mudar mecânicas, controles ou balanceamento**. Em paralelo, transformar o jogo em app desktop Windows com Electron.

## 2. Regras de trabalho (obrigatórias)

1. Uma etapa por vez. Antes de alterar arquivos, apresente as ações exatas, os arquivos e trechos afetados e as dependências novas, e **espere minha aprovação**.
2. **Nunca** faça commit, push, merge ou PR sem minha autorização específica para aquela ação. **Nunca** altere a branch `main`.
3. Preserve mecânicas, controles, combate, progressão, inventário, saves e a ordem dos objetos (o save guarda santuários, torres, portais, ninhos e baús **por índice**). Não altere a lógica de `world.nightFactor`: ela afeta dano, XP e ninhos.
4. Não corrija o vazamento de memória (T18) até eu pedir.
5. Em cada etapa, informe: alterações feitas, arquivos afetados, testes executados, resultados classificados como APROVADO, REPROVADO, INCONCLUSIVO ou NÃO EXECUTADO, limitações e como reverter. Não trate teste simulado como teste real. Não invente números. Diferencie fato confirmado de hipótese.
6. Se um teste não puder rodar no ambiente, diga isso e o que eu preciso validar na minha máquina.
7. Não adicione dependências sem justificar.

## 3. Estado do Git

| Item | Valor |
|---|---|
| `main` (local e remoto) | `b43de033772c6a7bba757a234d7db11ac1205cc5`, o jogo original, intocado |
| Branch remota de trabalho | `claude/modest-darwin-lboo7s`, em `ae18bb46254598bf26deb8ed48e022459ed06d79` |
| Commits nela | `167f55c` C1 (testes), `1520d2a` C2 (overlay), `ae18bb4` (PERFORMANCE.md) |
| Minha cópia local | `C:\Dev\Dark-Mage-dev`, branch **local** `feature/electron-proto` criada a partir de `ae18bb4`. Ela ainda não existe no GitHub. |
| Projeto original no OneDrive | Pasta separada que deve permanecer intocada |
| SHA-256 do `index.html` | original (`main`) `32d9854d…fd1b0`; com o overlay C2 `5f74313d…fda93` |

## 4. O que já foi feito: Etapa 0

### C1: testes de regressão (`tests/`, ferramenta só de desenvolvimento)
- Arquivos: `tests/run.mjs`, `tests/harness-page.js`, `tests/package.json` (devDeps: `playwright@1.56.1`, `three@0.128.0`), `tests/baseline/` (JSON e 16 imagens, gerados a partir do jogo original), `tests/README.md`.
- Como rodar: `cd tests && npm install && npx playwright install chromium && npm test`. `npm run baseline` regrava a referência e **só deve ser usado após aprovação**.
- Opções: `--gpu` (usa a GPU em vez do SwiftShader), `--cdn` (Three.js do CDN em vez da cópia local), `--game <arquivo>` (testa outra cópia do jogo).
- O harness, injetado **só** no navegador de teste, fixa a seed do `Math.random` (20261015, mulberry32) e usa relógio virtual de 16,67 ms por frame. Resolução 1280×720, escala 1.
- Testes:
  - **T01–T18:** erros de JavaScript; hash da altura do terreno; pontos de interesse; `nightFactor`; SKY_KEYS; caminhada; corrida; escalada de torre e de pedra; bloqueio de água; mira; projétil; meteoro; inimigos; save ida e volta; save antigo; memória; vazamento.
  - **V01–V08:** capturas em poses fixas.
  - **D01–D05:** testes do overlay.
- Resultado atual: tudo APROVADO, exceto **T18 REPROVADO**, um defeito pré-existente: **3,1 geometrias não liberadas por disparo** (projéteis, flashRing e slashRing nunca recebem `dispose()`). Confirmado no jogo real: o número sobe de 3 em 3.
- A referência visual foi gerada com SwiftShader. Em outra GPU, os testes V aparecem como INCONCLUSIVO. Os controles negativos (mutantes de terreno e de cor da grama) provaram que os testes detectam mudanças.

### C2: overlay de diagnóstico
- Bloco `<script>` no fim do `index.html`, ativo **só com `?debug=1`**. Envolve `window.renderFrame`, preservando this, argumentos, retorno, exceção e `renderer.info.autoReset`.
- Mostra FPS, tempo de frame (média e pior), CPU gasta no render, draw calls, triângulos, geometrias, texturas, programas, heap JS, canvas e GPU.

### Referência de desempenho (`tests/PERFORMANCE.md`)
- Máquina: Acer Nitro V15, RTX 4050 Laptop. O navegador usou a RTX via D3D11.
- Monitor externo 2560×1305, sem limite de FPS: ~478–505 FPS, frame de ~2,0 ms, pior frame ~10 ms, ~170–205 draw calls, ~588 mil triângulos.
- Tela de 1920 px a 125%: 547–630 FPS, frame de 1,6–1,8 ms, pior frame de 5,7–14,2 ms.
- Com vsync: 143,9 FPS (limite do monitor de 144 Hz).
- **Não há** dados de P95/P99.
- Hardware-alvo: o Nitro V15 é a referência; o jogo deve escalar para máquinas mais fracas com presets Baixo/Médio/Alto/Ultra.
- Critério proposto, ainda não aprovado: preset Alto com frame médio ≤ 6,9 ms e pior frame no máximo 20% acima da referência.

## 5. Diagnóstico técnico (resumo)

- **Terreno:**
  - `getTerrainHeight(x,z)` é analítica (soma de senos) e é a fonte da verdade para player, câmera, inimigos, posicionamento de todos os pontos de interesse, minimapa e grama.
  - A malha é uma `PlaneGeometry` 6000×6000 com 260 segmentos (células de ~23 m) e flatShading forçado pelo patch.
  - Diferença entre malha e altura analítica: p50 0,14 m, p99 2,7 m, máximo ~40–52 m nas bordas dos platôs (castelo e centro).
  - A altura está duplicada em GLSL no shader da grama.
- **Biomas:** a lógica está copiada em 4 lugares (`terrainColorHex`, `buildForestAndRocks3D`, shader da grama, `getBiomeName`).
- **Mira e Meteoro:** fazem raycast no `terrainMesh`.
- **Render:**
  - Luz: `HemisphereLight` e sol com sombra PCFSoft 2048² (±750); `FogExp2`; céu em shader; 1.200 estrelas.
  - Dia/noite: `updateDayNight`. O sol nunca desce abaixo de y=0,28.
  - Pós-processamento: render target MSAA, bloom e composite.
  - O ACES vale só para materiais embutidos; céu, grama e água são ShaderMaterial e ficam sem ACES.
  - A água ignora o ciclo de dia/noite.
  - `outputEncoding` está linear.
  - Mago em MeshStandard sem envMap. A PointLight do cristal provavelmente estoura o chão perto do mago (hipótese).
- **Desempenho:** no r128, o `InstancedMesh` tem `frustumCulled = false`, então ~3.560 instâncias (árvores, pedras e nuvens) são desenhadas sempre, inclusive no passe de sombra. Há o vazamento de projéteis e um Mesh novo por rastro de projétil.
- **Patch v2.4:** substitui `window.update3D`, `useActiveWeapon` e `selectHotbarSlot`, recalcula a câmera e troca o modelo do mago.
- **Achado em aberto (não corrigido):** vários pontos de interesse têm a base abaixo do nível da água (-6): 2 torres (Hebra e Altus), 4 santuários, 6 baús não subaquáticos, 2 entradas de caverna (Raya -34, Gelmir -56) e o Templo de Zora. Podem ficar inacessíveis sem a Túnica Zora. Precisa de verificação jogando.

## 6. Plano da reforma visual (aprovado como direção; cada etapa exige aprovação própria)

- **Etapa 0:**
  - C1 ✅, C2 ✅
  - **C3:** seed fixa da decoração (proposta pronta, aguardando aprovação)
  - **C4:** nome do jogo (aguardando)
- **Fase 1 (terreno):**
  - centralizar a lógica de bioma;
  - suavizar platôs;
  - aumentar a densidade da malha e usar normais suaves;
  - material via `onBeforeCompile`.
  - Antes de mudar altura, validar movimento, escalada, mira, projéteis, inimigos e pontos de interesse com as sondas e um relatório numérico.
- **Fase 2:** vegetação e composição.
- **Fase 3:** materiais e paleta, com envMap via `PMREMGenerator`.
- **Fase 4:** iluminação e atmosfera (pipeline de cor único, sol e lua, sombras, névoa por altura, água).
- **Fase 5:** estruturas (castelo, torres, santuários, cavernas, Erdtree).
- **Fase 6:** cristais e magia (inclui a correção do vazamento, quando autorizada).
- **Fase 7:** desempenho (chunks com descarte por frustum) e presets.
- Ficar no **Three.js r128** durante a reforma: atualizar quebraria `WebGLMultisampleRenderTarget`, `RGBFormat` e o gerenciamento de cor.

### Proposta C3 (ainda NÃO autorizada)
- Das 49 chamadas a `Math.random`: **32 são de decoração** e passariam a usar `makeWorldRng(stream)`:
  - estrelas (597, 599); grama (813); cristais da caverna (982);
  - árvores (1498–1517, 11 chamadas); pedras (1528–1541, 6 chamadas);
  - rotação das instâncias (1558, via 3º parâmetro de `addInstancedMeshFast`); nuvens (3681–3686, 8 chamadas).
- **17 são de runtime** e continuam com `Math.random`: spawn e IA dos inimigos, partículas, ouro dos baús (2288), tremor de câmera, telégrafos de chefe e rastros.
- `WORLD_SEED` fixo, com override só para testes via `window.__DM_WORLD_SEED__`. Uma sequência separada por sistema (stars, grass, caveCrystals, trees, rocks, rot.*, clouds).
- Divisão em commits:
  - **C3a:** só testes. O harness ganha `reseed()` por sonda; T03 se divide em T03a (pontos fixos) e T03b (pedras); testes novos W1–W7.
  - **C3b:** o jogo.
  - **C3c:** nova referência, após aprovação.
- Mudanças esperadas: T03b, T09, V01–V08, D04. Todo o resto deve continuar idêntico.
- Escolher uma seed sem pedra escalável perto dos pontos de interesse.

### C4 (ainda NÃO autorizada)
- Trocar só os textos visíveis para "Dark Mage - The Isle of Fear": `<title>` (linha 5) e log de boas-vindas (~3699).
- **Manter** a chave do save `aethelgard_3d_v20` e as chaves antigas.
- Os nomes de lugares "…de Aethelgard" ficam até eu decidir.
- O overlay e o README dos testes ainda dizem "Dark Wizard"; ajustar quando a C4 for autorizada.

## 7. Protótipo Electron (feito, NÃO versionado)

- Os arquivos estão no ZIP `dark-mage-electron-proto.zip`, que devo extrair na raiz de `C:\Dev\Dark-Mage-dev\`:
  `electron-proto/{main.js, package.json, package-lock.json, README.md, .gitignore, test/smoke.mjs}`.
- `electron@44.7.2` e `playwright@1.56.1`, ambos como devDependencies.
- `main.js` abre `../index.html` **sem copiar nem modificar**:
  - `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`, `webSecurity: true`, sem preload;
  - rede limitada ao arquivo do jogo e ao Three.js r128 do cdnjs;
  - permissões: só `pointerLock`;
  - janelas novas e navegação externa negadas;
  - **sem menu** (a tecla Alt, usada na esquiva, abriria o menu no Windows);
  - a comparação do caminho do jogo é feita pelo caminho no disco, não pelo texto da URL (letra do drive e acentos);
  - `DM_ELECTRON_USER_DATA` define uma pasta de dados alternativa, usada só pelos testes.
- Comandos: `npm start`, `npm run start:debug` (usa a flag **`--dm-debug`**, porque o Electron reserva `--debug` para o Node), `npm test`. Para ambiente sem GPU ou sem CDN: `npm test -- --swiftshader --local-three`.
- Testes E01–E11: todos APROVADOS num contêiner Linux (Xvfb, SwiftShader, Three.js local, sandbox real ativo).
- **Ainda não validado no Windows:**
  - abrir com a RTX 4050;
  - Three.js carregando do CDN real;
  - Alt com teclado físico (esquiva funciona e nenhum menu aparece);
  - mouse e pointer lock reais;
  - FPS dentro da faixa do `PERFORMANCE.md`.
- O save do Electron fica em `%APPDATA%\dark-mage-electron-proto`, separado do save do navegador.
- O Electron mostra um aviso de CSP no DevTools; resolver exigiria mexer no `index.html`.
- Não gerar executável ainda. Fora de escopo por enquanto: gamepad, modo offline, C3, C4 e o vazamento.

## 8. Próximos passos pendentes (aguardando minha decisão)

1. Eu validar o protótipo Electron no Windows e decidir se ele é versionado e em qual branch remota.
2. Autorizar (ou não) C3a, C3b e C4.
3. Confirmar os locais das medições feitas na tela de 1920 px.
4. Decidir sobre os pontos de interesse abaixo do nível da água.

## 9. Primeira ação nesta nova sessão

Antes de qualquer coisa:
1. Confirme a pasta atual, a branch, `git status`, `git log --oneline -5`, e que `main` = `b43de03`.
2. Verifique se `electron-proto/` existe localmente. Se não existir, avise.
3. Leia `tests/README.md` e `tests/PERFORMANCE.md`.

Depois me apresente o estado encontrado e **espere minhas instruções**. Não altere nenhum arquivo nesta primeira resposta.
