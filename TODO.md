# TODO

Prioridade: P1 (bloqueia marco) · P2 (antes do RC) · P3 (desejável).

## Placeholders abertos (máximo 10)
| # | Placeholder | Onde | Substituir em |
|---|---|---|---|
| 1 | Cena sandbox de atmosfera (chão de ruído) — só para testes de céu; o jogo usa a ilha | `levels/sandbox/` | remover no M12 |

## Pendências
- [ ] P2 · M12: microbenchmark de 3 s na primeira execução para ajustar o preset detectado pelo nome da GPU.
- [ ] P1 · M1: testar D3D12 vs Vulkan no Nitro V15 (dono) e registrar.
- [ ] P3 · Reativar o plugin de editor do Terrain3D quando houver versão com suporte oficial ao Godot 4.7 (D04).
- [ ] P2 · M7: graduação de cor (LUT) e corrupção por região, com transição suave ao cruzar fronteiras.
- [ ] P3 · Lua: fases e textura própria; estrelas um pouco maiores em 1440p.
- [ ] P2 · Personagem: modelo próprio com proporções mais adultas/sombrias (hoje KayKit Mage recolorido, D30).
- [ ] P2 · M7: rios e lagos com WaterBody próprio; água do pântano turva e violeta.
- [ ] P3 · Atualizar o Terrain3D quando sair versão para o Godot 4.7 e remover `tools/known_log_messages.txt` (D28).
- [ ] P3 · Névoa de longe ainda pesada na vista aérea (1,4 km); calibrar com o benchmark no Nitro.
- [ ] P3 · Fauna ambiente (pássaros, corvos, peixes) e sons por região (M10).
- [ ] P2 · M10: silhuetas próprias para os Guardiões (hoje esqueleto/golem/serpente escalados e tingidos).
- [ ] P2 · M10: epílogo com câmera cinematográfica e créditos rolando; arena dos covis menos quadrada.
- [ ] P3 · M10: roda rápida de feitiços no RB (hoje RB está livre no jogo; LB + face já cobre os 4 espaços).
- [ ] P2 · Dono: testar toda a UI com um gamepad físico (testes usam eventos simulados).
- [ ] P3 · Ambientes gravados (CC0) no lugar dos sintetizados, se aparecerem com licença clara.
- [ ] P3 · Lava com variação de padrão de perto (fluxos direcionais).
