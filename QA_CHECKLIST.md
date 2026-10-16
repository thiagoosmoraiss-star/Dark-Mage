# Checklist de QA

Roteiro manual. Preencher a cada marco; o checklist de polimento (M10) e a campanha completa (M8) entram aqui.

## M0 — Fundação
- [x] `tools/check.sh all` aprovado (importação, smoke, licenças, GdUnit4).
- [x] Projeto abre com renderização (Vulkan, Forward+) e mostra a cena de teste.
- [x] Overlay mostra FPS, P95/P99, draw calls, memória, GPU, preset e posição (verificado por captura com `-- --overlay`).
- [ ] (Dono) Apertar F3 com o jogo aberto alterna o overlay (não automatizado ainda).
- [ ] (Dono) Abrir o projeto no editor Godot 4.7.2 no Nitro V15 e confirmar que não há erros no painel Saída.

## M2–M5 (dono, no Nitro V15)
- [ ] Rodar `godot --path . -- --bench --preset=high` e colar o JSON em PERFORMANCE.md.
- [ ] Jogar 10 min no Vale: câmera, escalar uma encosta, planar de um morro, nadar no mar, abrir o mapa (M).
- [ ] Conferir se o mouse fica preso na janela (clique) e se Esc libera.

## M6 — Fatia vertical (dono)
- [ ] Jogar 10 min no Vale: lutar com o grupo ao norte (Q/E/R/F, botão esquerdo, direito para mirar, Tab/meio para travar).
- [ ] Esquivar (Ctrl/C) no momento do golpe e ver a câmera lenta da esquiva perfeita.
- [ ] Morrer de propósito e renascer no início.
- [ ] Escalar a torre do farol e as colunas das ruínas.

## M8 — Campanha completa (dono)
- [ ] Entrar num santuário de cada arquétipo (Braseiros, Provação, Abismo, Runas), resolver e pegar o sigilo no altar.
- [ ] Morrer dentro de um santuário: renascer na entrada da sala.
- [ ] Vencer os 4 Guardiões nos covis; conferir que a região perde a névoa violeta e que o feitiço novo aparece na barra.
- [ ] Ver a cúpula da Cidadela sumir depois do 4º Guardião; entrar e vencer O Medo (3 fases).
- [ ] Ver o epílogo (amanhecer dourado e texto final) e conferir o save automático no slot 1.
- [ ] Carregar o save depois de cada Guardião: flag, purificação e feitiços mantidos.

## M9 — UI e gamepad (dono)
- [ ] Abrir o jogo: menu inicial aparece em tela cheia; Novo jogo → escolher espaço → introdução.
- [ ] Com um **gamepad físico**: navegar menu inicial, pausa (Start), Grimório (Back), abas (LB/RB), opções e loja só com o controle.
- [ ] LB + A/B/X/Y lança os feitiços; D-pad ↓ usa poção de vida; D-pad ↑ abre o mapa e o cursor anda com o analógico.
- [ ] Remapear o pulo para outra tecla e um feitiço do gamepad; fechar e reabrir o jogo — o remapeamento continua.
- [ ] Comprar um cajado no mercador (fogueira do Vale), equipar e ver o ataque básico mudar.
- [ ] Salvar no espaço 2 pela pausa, sair para o menu, Continuar — tudo volta (inventário, marcadores, hora, posição).
- [ ] Trocar janela/sem bordas/tela cheia, idioma (en) e filtro de daltonismo; conferir a escala da UI em 0,75 e 1,5.

## M10 — Checklist de polimento
- [x] Música adaptativa (dia, noite, sombria, combate, chefe) com crossfade — teste automatizado.
- [x] Ambiente por região, hora, corrupção, mar e interiores; fogo 3D nas fogueiras acesas.
- [x] Barramentos Master/Música/Efeitos/Ambiente/UI/Voz com volume nas opções; reverb nos interiores.
- [x] Juice: clarão de luz nos impactos, hit-stop, tremor nos golpes fortes (respeita a opção de tremor), números de dano.
- [x] Dificuldade Fácil/Normal/Difícil nas opções.
- [x] Mapa pintado com relevo; ícones por forma e estado.
- [x] Lava na cratera; fogueira apagada visível à noite; braseiro do farol legível de baixo.
- [x] Autocrítica visual e sonora registrada em PROGRESS.md (a sonora como NÃO EXECUTADA por ouvido).
- [ ] (Dono) Ouvir 10 min: transição dia → noite, entrar em combate e sair, entrar num covil; ajustar volumes se algo estourar.

## M11 — Executável (dono)
- [x] `tools/export.sh` exporta e o teste de fumaça no .exe passa (automatizado).
- [ ] Copiar `build/export/windows/` para outra pasta (ou outro PC), desligar a internet e jogar 5 min.
- [ ] Confirmar o alerta do SmartScreen ("Mais informações" → "Executar assim mesmo").
