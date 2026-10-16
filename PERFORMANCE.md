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
| 2026-10-16 | M0 | — | — | — | NÃO EXECUTADO | — | — | — | Ainda não há benchmark; a máquina do agente (Intel UHD) não é a de referência |
