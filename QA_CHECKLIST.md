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
