# Dark Mage — The Isle of Fear: resumo de design

Resumo do roteiro completo (`docs/ROTEIRO.md`, cópia de `../ROTEIRO-DARK-MAGE-GODOT.md`). Em caso de
divergência, o roteiro vale.

## Pitch
Um mago sombrio desperta numa ilha amaldiçoada por uma névoa que se alimenta do medo. Ele explora
livremente, escala, plana, reacende faróis arcanos e derrota os quatro Guardiões do Medo e o chefe final na
Cidadela do Medo.

## Pilares
1. Exploração livre e curiosa ("se você vê, pode ir até lá").
2. Magia expressiva e satisfatória (peso, antecipação, impacto; combate de leitura e esquiva).
3. Beleza sombria (dourado = segurança/recompensa; violeta = magia/perigo).
4. Clareza (silhuetas legíveis, UI mínima).

## Escopo 1.0
Ilha de ~2 × 2 km com 6 regiões e a Cidadela; 1 personagem, 8 feitiços, 6 inimigos, 4 chefes + 1 final;
4 faróis, 12 santuários, ~40 baús/segredos; dia e noite de ~24 min; clima simples; 3 a 5 horas.

## Paleta
| Papel | Cor |
|---|---|
| Preto profundo | `#0B0910` |
| Violeta arcano | `#6B2FD6` |
| Violeta brilho | `#B67CFF` |
| Dourado antigo | `#E8B44C` |
| Âmbar quente | `#FFB765` |
| Verde musgo | `#4F7A3A` |
| Azul crepúsculo | `#2E4A7A` |
| Osso / pedra | `#C9BFA8` |

## Regiões
Vale do Despertar (centro), Floresta Sussurrante (sul), Picos Gélidos (norte), Terras Calcinadas (leste),
Pântano Violeta (oeste), Costa dos Naufrágios (litoral) e Cidadela do Medo (centro-norte).

## Mundo determinístico
- Seed oficial: **`20261016`** (`Rng.WORLD_SEED`). Override só para testes: `-- --seed=<n>`.
- Cada sistema usa o próprio fluxo: `Rng.stream("world")`, `Rng.stream("loot")`... A seed do fluxo é
  `FNV-1a(nome do fluxo, base = FNV-1a(seed))`, estável entre plataformas.

## Controles (padrão; todos remapeáveis)
Fonte única: `data/input_defaults.gd`.

| Ação | Teclado/mouse | Gamepad |
|---|---|---|
| Mover | WASD | Analógico esquerdo |
| Câmera | Mouse | Analógico direito |
| Pular / planar | Espaço | A |
| Sprint | Shift | L3 |
| Esquiva | Ctrl ou C | B |
| Ataque | Botão esquerdo | RT |
| Mirar | Botão direito | LT |
| Feitiços 1–4 | Q E R F | LB + face / RB = roda (M9) |
| Interagir | **G** | X |
| Travar alvo | Botão do meio ou Tab | R3 |
| Inventário / Mapa / Pausa | I / M / Esc | Select / D-pad ↑ / Start |
| Overlay dev | F3 | — |

Alt nunca é usado.

## Marcos
M0 Fundação · M1 Render e atmosfera · M2 Terreno · M3 Personagem · M4 Vegetação · M5 Travessia ·
M6 Combate (fatia vertical) · M7 Conteúdo do mundo · M8 Santuários, covis e chefes · M9 Progressão, UI e
gamepad · M10 Áudio e polimento · M11 Exportação Windows · M12 Otimização e RC.
