# Testes de regressão — Dark Wizard - Island of Fear

Ferramenta **só de desenvolvimento**. O jogo (`../index.html`) não carrega nada desta pasta.

## Como rodar

```bash
cd tests
npm install                 # playwright 1.56.1 + three@0.128.0 (cópia local do r128)
npx playwright install chromium   # só na primeira vez, na sua máquina
npm test                    # compara o jogo atual com a referência -> tests/output/<data>/report.md
```

- `npm run baseline` regrava a referência (`tests/baseline/`). **Só use quando uma mudança visual
  ou de mundo tiver sido aprovada**; caso contrário a referência deixa de proteger o original.
- `node run.mjs --gpu` usa a GPU da máquina em vez do SwiftShader (render por CPU).
- `node run.mjs --cdn` carrega o Three.js do cdnjs em vez da cópia local.
- `node run.mjs --game <arquivo>` testa outra cópia do jogo.

A referência atual foi gerada com **SwiftShader** (Chromium 141, Three.js r128 do npm). Em outra GPU
as capturas saem diferentes por natureza; nesse caso os testes visuais aparecem como
**INCONCLUSIVO** (os testes numéricos continuam valendo). Para comparar capturas na sua máquina,
gere uma referência própria com `node run.mjs --update --gpu` a partir do original (`main`).

## Condições controladas

| Item | Valor |
|---|---|
| Resolução | 1280×720, deviceScaleFactor 1 (pixelRatio do jogo = 1) |
| Carregamento | contexto novo (localStorage vazio), recursos externos bloqueados exceto Three.js |
| Aleatoriedade | `Math.random` com seed 20261015 (mulberry32), só na página de teste |
| Tempo | relógio virtual: cada frame = 16,67 ms; `requestAnimationFrame` e `performance.now` controlados |
| Capturas | 59 frames de lógica + 1 frame renderizado; imagem lida do canvas WebGL (sem HUD) |
| Registro por captura | posição/direção da câmera, camYaw/camPitch, hora final, nightFactor, posição do jogador, estatísticas do renderer |

## O que é simulado (e o que não é)

Tudo aqui é **simulado**: roda num navegador automatizado, sem pessoa jogando.

- `harness-page.js` (injetado só no teste) troca `Math.random` e o relógio. Não altera lógica do jogo.
- As sondas **posicionam** o jogador e a câmera diretamente (teleporte) e chamam funções reais do jogo
  (`update3D`, `useActiveWeapon`, `triggerSpellById`, `spawnEnemy3D`, `saveGame`/`loadGame`).
- Movimento e escalada usam eventos de teclado reais do navegador (W, Shift), mas sem mouse/pointer lock.
- `tick()` roda o loop do jogo sem desenhar (troca `renderFrame` por uma função vazia e restaura).

**Não coberto**: desempenho real (FPS), mouse/pointer lock, sensação de controle, áudio, save real do seu navegador.
Isso precisa ser validado jogando.

## Testes

| ID | O que verifica |
|---|---|
| T01 | Nenhum erro de JavaScript |
| T02 | Altura do terreno (hash de 40.003 amostras de `getTerrainHeight`) |
| T03 | Pontos de interesse: quantidade, ordem e posição (ordem importa para o save) |
| T04 | `nightFactor` de 0h a 24h (afeta dano, XP e ninhos) |
| T05 | `SKY_KEYS` e constantes do mundo |
| T06–T07 | Caminhada e corrida (posição a cada 30 frames). T06 é no platô plano do spawn; T07 cobre encosta |
| T08–T09 | Escalada de torre e da maior pedra |
| T10 | Bloqueio de água sem a Túnica Zora |
| T11 | Ponto de mira (raycast do centro da tela) em 3 poses |
| T12 | Origem e direção do projétil do cajado |
| T13 | Ponto de impacto do Meteoro |
| T14 | Altura de inimigo terrestre e voador |
| T15 | Salvar e recarregar |
| T16 | Save gerado pela versão de referência carrega igual |
| T17 | Memória após 20 disparos igual à referência |
| T18 | Saúde: geometria vazada por disparo (defeito pré-existente) |
| V01–V08 | Capturas: vale, pôr do sol, noite, castelo, floresta, costa, caverna, Limbo |
| D01 | Sem `?debug=1`: overlay ausente, `renderFrame` original, `renderer.info` intacto |
| D02 | Com `?debug=1`: painel ativo; FPS/frame batem com o relógio virtual; draw calls e triângulos batem com medição independente |
| D03 | Wrapper de `renderFrame`: preserva `this`, argumentos, retorno, relança exceção e restaura `renderer.info.autoReset` |
| D04 | Com `?debug=1` a imagem 3D é idêntica à referência (instrumentação não muda o render) |
| D05 | Custo do wrapper por frame < 5 µs |

Os testes D só rodam no modo comparação (`npm test`).

Tolerância das capturas: um pixel conta como diferente se algum canal variar mais que 8/255;
o teste reprova se mais de 0,1% dos pixels mudar ou se a câmera mudar.

`baseline.json` também guarda, de forma informativa, a diferença entre a malha visível e a altura
analítica (`world.meshVsAnalytic`) e a altura da malha em cada ponto de interesse (`meshY`), que serão
usadas para validar a Fase 1.
