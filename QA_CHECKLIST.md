# Checklist de QA

Roteiro manual. Preencher a cada marco; o checklist de polimento (M10) e a campanha completa (M8) entram aqui.

## M0 — Fundação
- [x] `tools/check.sh all` aprovado (importação, smoke, licenças, GdUnit4).
- [x] Projeto abre com renderização (Vulkan, Forward+) e mostra a cena de teste.
- [x] Overlay mostra FPS, P95/P99, draw calls, memória, GPU, preset e posição (verificado por captura com `-- --overlay`).
- [ ] (Dono) Apertar F3 com o jogo aberto alterna o overlay (não automatizado ainda).
- [ ] (Dono) Abrir o projeto no editor Godot 4.7.2 no Nitro V15 e confirmar que não há erros no painel Saída.
