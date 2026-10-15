# Referência de desempenho — Dark Mage - The Isle of Fear

Medições manuais feitas pelo autor no hardware de referência, com o overlay `?debug=1`
(Etapa 0 / C2), sobre o jogo **sem nenhuma mudança visual** (commit `1520d2a`, que só
acrescenta o overlay ao original `b43de03`). Data: 15/10/2026.

> Nome do jogo: "Dark Mage - The Isle of Fear" (definido pelo autor). A troca do nome
> dentro do jogo (C4) ainda não foi feita; o título da aba ainda é "Aethelgard 3D v2.0".

## Hardware e condições

| Item | Valor |
|---|---|
| Máquina | Acer Nitro V15 |
| GPU usada pelo navegador | `ANGLE (NVIDIA, NVIDIA GeForce RTX 4050 Laptop GPU (0x000028A1) Direct3D11 vs_5_0 ps_5_0, D3D11)`, lida pelo overlay |
| Navegador | Chrome no Windows (versão não registrada) |
| Forma de abrir | `index.html?debug=1` aberto direto do disco (`file://`) |
| Configuração do jogo | padrão: sombras ligadas, pós-processamento ligado, grama 18.000 |
| WebGL | WebGL2 |
| Limite de FPS | Medições "sem limite" foram feitas com o Chrome aberto com `--disable-gpu-vsync --disable-frame-rate-limit`, conforme a instrução enviada. Que a flag estava ativa é inferência: o FPS ficou muito acima de qualquer taxa de atualização de tela. |
| Energia | não registrada (orientação: notebook na tomada) |

## Resultados

### 1. Monitor externo (provável QHD), sem limite de FPS: horário diurno

Canvas 2560×1305, pixelRatio 1,00. A tela foi identificada pelo autor apenas como "a outra
tela"; que seja um monitor externo QHD é inferência pela largura.

| Local (pelo rótulo do HUD em cada captura) | FPS | Frame médio | Pior frame | CPU render | Draw calls | Triângulos | Geometrias | Heap JS |
|---|---|---|---|---|---|---|---|---|
| Vale Central, perto do spawn (portal do Limbo visível), 08:10 | 477,6 | 2,1 ms | 10,1 ms | 1,45 ms | 205 | 589.140 | 181 | 65 MB |
| Castelo Stormveil, 11:40 | 505,4 | 2,0 ms | 9,9 ms | 1,23 ms | 170 | 587.988 | 352 | 65 MB |
| Vale Central, área com árvores, 12:30 | 498,4 | 2,0 ms | 10,4 ms | 1,26 ms | 185 | 587.170 | 353 | 65 MB |

### 2. Tela de 1920 px a 125% (provável tela do notebook), sem limite de FPS: horário noturno nas medições B e C

Canvas 1920×912, pixelRatio 1,25. Os locais **não foram informados**; a coluna "local provável"
é inferência pela quantidade de draw calls e pelo fundo das capturas, e precisa de confirmação.

| Medição | Local provável (a confirmar) | FPS | Frame médio | Pior frame | CPU render | Draw calls | Triângulos | Geometrias | Heap JS |
|---|---|---|---|---|---|---|---|---|---|
| A | spawn | 602,0 | 1,7 ms | 13,3 ms | 1,15 ms | 196 | 594.060 | 187 | 23 MB |
| B | castelo, à noite | 630,0 | 1,6 ms | 14,2 ms | 1,06 ms | 167 | 593.060 | 228 | 23 MB |
| C | floresta, à noite | 547,6 | 1,8 ms | 5,7 ms | 1,27 ms | 232 | 596.006 | 323 | 23 MB |

### 3. Medição com o limite padrão do navegador (vsync), monitor externo

| Local | FPS | Frame médio | Pior frame | CPU render | Draw calls | Triângulos | Geometrias | Heap JS | Canvas |
|---|---|---|---|---|---|---|---|---|---|
| Vale Central, perto do spawn, 09:10 | 143,9 | 6,9 ms | 8,3 ms | 0,63 ms | 199 | 584.288 | 330 | 48 MB | 2560×1271 @1,00 |

O FPS ficou preso em ~144, o que indica o limite da taxa de atualização da tela (provavelmente
144 Hz; taxa não confirmada). Esta linha **não** mede a capacidade da GPU.

### 4. Vazamento de memória (defeito pré-existente, não corrigido)

Observação do autor no jogo real: o contador "geometrias" sobe **3 a cada disparo** do cajado.
Confirma o teste automático T18 (3,1 geometrias por disparo, em `tests/run.mjs`). As geometrias
diferentes entre as linhas acima refletem disparos e inimigos durante a sessão, não o local.

## Leitura

- Folga no hardware de referência: frame médio de 1,6–2,1 ms contra 6,9 ms (144 Hz) e 16,7 ms (60 FPS).
- Picos ("pior") de 5,7 a 14,2 ms já existem no original. Causa ainda não investigada
  (hipótese: coleta de lixo do JavaScript ou trabalho periódico do jogo).
- O custo quase não muda entre os locais: os ~590 mil triângulos são desenhados em qualquer
  lugar, porque as árvores e pedras instanciadas não são descartadas fora da tela (r128).

## Critério proposto para as próximas etapas (ainda não aprovado)

No Nitro V15, preset Alto, nos mesmos locais e na mesma tela: frame médio ≤ 6,9 ms e pior frame
no máximo 20% acima desta referência.

## Limitações das métricas

- **P95/P99 não disponíveis.** O overlay mostra só a média e o pior frame de cada janela de ~1 s.
  Não há percentis registrados e nenhum valor foi estimado.
- Cada número é **uma leitura de uma janela de ~1 s** (foto da tela), não uma média de várias
  janelas. Sem repetição, não há medida de variação entre leituras.
- "Frame" é o intervalo entre chamadas de `renderFrame` medido pelo relógio do navegador, não o
  tempo de GPU. "CPU render" é o tempo do JavaScript dentro de `renderFrame`, não o tempo de GPU.
- Draw calls e triângulos somam todos os passes do frame: cena, sombras e ~6 passes do
  pós-processamento (12 triângulos).
- "Heap JS" vem de `performance.memory` (só Chrome/Edge, aproximado).
- Horário do jogo, posição exata da câmera e direção do olhar não são controlados nas medições
  manuais. As medições das seções 1 e 2 têm horários diferentes (dia contra noite), resolução e
  escala diferentes, então **não são diretamente comparáveis entre si**.
- Versão do Chrome, taxa de atualização das telas e estado de energia não foram registrados.
