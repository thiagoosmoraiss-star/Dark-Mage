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
| 2026-10-16 | M12 (antes) | Lenovo 83NS, Intel UHD (agente) | Baixo | 1920×1080 | 24,6 | 69,4 ms | 94,3 ms | 347 | `--bench` 20 s, com o conteúdo do M7–M10 |
| 2026-10-16 | M12 (depois) | Lenovo 83NS, Intel UHD (agente) | Baixo | 1920×1080 | 27,1 | 60,6 ms | 73,5 ms | 278 | `--bench` 20 s, após juntar malhas e alcance de desenho |
| — | M12 | Acer Nitro V15 (dono) | Alto | 1920×1080 | NÃO EXECUTADO | — | — | — | medir com `-- --bench --preset=high` |

## Vazamento (seção 16)
`tools/run.sh res://tools/soak.gd -- --seconds=600` (headless): 600 s, 973 conjurações, jogador andando, pulando e
esquivando. Nós 8004 → 8404 (estáveis a partir de 270 s; +1,1% após o aquecimento, inimigos ativados na região),
memória estática 308 → 312 MB (+0,1% após o aquecimento), 0 nós órfãos. **APROVADO.** Memória de vídeo no
benchmark: 248,9 → 248,8 MB.

### Como medir
```bash
godot --path . -- --bench --preset=high              # 60 s, grava user://bench/bench_<data>.json
godot --path . -- --bench --preset=low --bench-seconds=20 --no-grass   # perfis rápidos
```
