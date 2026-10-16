# TODO

Prioridade: P1 (bloqueia marco) · P2 (antes do RC) · P3 (desejável).

## Placeholders abertos (máximo 10)
| # | Placeholder | Onde | Substituir em |
|---|---|---|---|
| 1 | Cena sandbox de atmosfera (chão de ruído) — só para testes de céu; o jogo usa a ilha | `levels/sandbox/` | remover no M12 |

## Pendências
- [ ] P2 · M12: microbenchmark de 3 s na primeira execução para ajustar o preset detectado pelo nome da GPU.
- [ ] P1 · M1: testar D3D12 vs Vulkan no Nitro V15 (dono) e registrar.
- [ ] P2 · M9: aplicar `window_mode` (janela, borderless, tela cheia) a partir das configurações.
- [ ] P2 · M9: feitiços no gamepad (LB + botões frontais / roda rápida com RB).
- [ ] P2 · M9: UI de remapeamento (o backend `Settings.remap_action` já existe e tem teste).
- [ ] P3 · Reativar o plugin de editor do Terrain3D quando houver versão com suporte oficial ao Godot 4.7 (D04).
- [ ] P2 · M7: graduação de cor (LUT) e corrupção por região, com transição suave ao cruzar fronteiras.
- [ ] P3 · Lua: fases e textura própria; estrelas um pouco maiores em 1440p.
- [ ] P2 · Personagem: modelo próprio com proporções mais adultas/sombrias (hoje KayKit Mage recolorido, D30).
- [ ] P2 · M7: rios e lagos com WaterBody próprio; água do pântano turva e violeta.
- [ ] P3 · Atualizar o Terrain3D quando sair versão para o Godot 4.7 e remover `tools/known_log_messages.txt` (D28).
- [ ] P3 · Névoa de longe ainda pesada na vista aérea (1,4 km); calibrar com o benchmark no Nitro.
- [ ] P2 · Lava nas Terras Calcinadas (material de água emissivo nas poças da região) e cratera do vulcão.
- [ ] P2 · Brasas da fogueira apagada mais visíveis à noite; topo do farol mais imponente.
- [ ] P2 · M9: ícones de POIs descobertos no mapa, marcadores personalizados e viagem pelo mapa.
- [ ] P3 · Fauna ambiente (pássaros, corvos, peixes) e sons por região (M10).
