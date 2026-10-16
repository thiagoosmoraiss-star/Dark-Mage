# Desempenho

Fonte de verdade: o benchmark fixo (`godot --path . -- --bench`, a partir do M1/M4), que grava JSON em
`user://bench/`. O dono roda no **Acer Nitro V15 (RTX 4050 Laptop)** e cola o JSON aqui.

## Orçamento do preset Alto (roteiro, seção 10)
- ≥ 100 FPS em 1920×1080 (frame ≤ 10 ms).
- ≤ 2.000 draw calls (meta ≤ 1.000).
- Sem crescimento de objetos, recursos e memória de vídeo após 10 minutos.

## Medições

| Data | Marco | Máquina | Preset | Resolução | FPS médio | P95 | P99 | Draw calls | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 2026-10-16 | M0 | — | — | — | NÃO EXECUTADO | — | — | — | Ainda não havia benchmark |
| 2026-10-16 | M4 | Lenovo 83NS, Intel UHD (agente) | Baixo | 1280×720 | 31,5 | 55,2 ms | 68,6 ms | 254 | `--bench` 30 s (2 execuções: 31,6 / 31,4) |
| 2026-10-16 | M4 | Lenovo 83NS, Intel UHD (agente) | Baixo | 1920×1080 | 17,7 | 92,4 ms | 130,8 ms | 252 | `--bench` 20 s (antes do ajuste de grama/glow) |
| 2026-10-16 | M4 | Lenovo 83NS, Intel UHD (agente) | Alto | 1920×1080 | 7,5 | 144,3 ms | 146,4 ms | 919 | `--bench` 20 s — GPU muito abaixo do alvo do Alto |
| — | M4 | **Nitro V15, RTX 4050** | Alto | 1920×1080 | NÃO EXECUTADO | — | — | — | **Dono:** `godot --path . -- --bench --preset=high` e colar o JSON aqui |

### Atribuição de custo (Baixo, 720p, Intel UHD, antes das otimizações)
FSR2 ~30 ms (trocado por FSR1) · vegetação ~18 ms · grama ~13 ms · água ~11 ms · sombras ~11 ms.

### Como medir
```bash
godot --path . -- --bench --preset=high              # 60 s, grava user://bench/bench_<data>.json
godot --path . -- --bench --preset=low --bench-seconds=20 --no-grass   # perfis rápidos
```
