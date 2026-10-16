# TODO

Prioridade: P1 (bloqueia marco) · P2 (antes do RC) · P3 (desejável).

## Placeholders abertos (máximo 10)
| # | Placeholder | Onde | Substituir em |
|---|---|---|---|
| 1 | Chão provisório (malha + shader de ruído) da cena de atmosfera | `levels/sandbox/` | M2 (Terrain3D com texturas PBR) |

## Pendências
- [ ] P2 · M12: microbenchmark de 3 s na primeira execução para ajustar o preset detectado pelo nome da GPU.
- [ ] P1 · M1: testar D3D12 vs Vulkan no Nitro V15 (dono) e registrar.
- [ ] P2 · M9: aplicar `window_mode` (janela, borderless, tela cheia) a partir das configurações.
- [ ] P2 · M9: feitiços no gamepad (LB + botões frontais / roda rápida com RB).
- [ ] P2 · M9: UI de remapeamento (o backend `Settings.remap_action` já existe e tem teste).
- [ ] P3 · Reativar o plugin de editor do Terrain3D quando houver versão com suporte oficial ao Godot 4.7 (D04).
- [ ] P2 · M7: graduação de cor (LUT) e corrupção por região, com transição suave ao cruzar fronteiras.
- [ ] P3 · Lua: fases e textura própria; estrelas um pouco maiores em 1440p.
