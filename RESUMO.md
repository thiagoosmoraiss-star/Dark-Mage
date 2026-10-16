# Dark Mage — A Ilha do Medo · Resumo da versão 1.0.0-rc1

Data: 16/10/2026. Todos os 13 marcos do roteiro (M0 a M12) foram concluídos. Cada marco tem um commit e uma tag local
(`m0` … `m12`) neste repositório. Não houve push, merge, PR nem gasto.

---

## 1. Como abrir e jogar

| O quê | Onde / comando |
|---|---|
| **Jogo pronto (Windows)** | `build\export\windows\DarkMage.exe`, gerado por `tools/export.sh` (fora do Git) (a DLL que está ao lado precisa ficar junto) |
| Projeto no editor | Godot 4.7.2 stable (godotengine.org) → abrir esta pasta (após clonar: `git lfs pull`) |
| Gerar o .exe | `bash tools/export.sh` (precisa dos export templates 4.7.2; ver README) |
| Rodar todos os testes | `bash tools/check.sh all` |
| Benchmark | `godot --path . -- --bench --preset=high` (o resultado sai em `user://bench/`) |
| Saves e configurações | `%APPDATA%\Godot\app_userdata\Dark Mage - The Isle of Fear\` |

Na primeira execução o Windows SmartScreen vai alertar, porque o executável não tem assinatura digital. Clique em
**"Mais informações" → "Executar assim mesmo"**.

### Controles padrão
| Ação | Teclado e mouse | Gamepad |
|---|---|---|
| Andar / câmera | WASD / mouse | analógico esquerdo / direito |
| Pular, planar (no ar) | Espaço | A |
| Correr / esquivar | Shift / Ctrl ou C | LS / B |
| Ataque básico / mirar | botão esquerdo / botão direito | RT / LT |
| Feitiços 1–4 | Q, E, R, F | LB + A, B, X, Y |
| Ultimate (Ira do Farol) | Q + F juntos | LB + A + Y |
| Interagir | G | X |
| Travar alvo | Tab / botão do meio | RS |
| Poção de vida / mana | H / J | D-pad ↓ / → |
| Inventário / Diário / Mapa | I / L / M | Back / D-pad ← / D-pad ↑ |
| Pausa | Esc | Start |
| Trocar aba nos menus | Q / E | LB / RB |

Todos os controles podem ser remapeados em Opções → Controles.

---

## 2. O que foi feito, marco a marco

| Marco | Conteúdo |
|---|---|
| **M0** Fundação | Projeto Godot 4.7.2 (Vulkan), Jolt Physics, save em JSON com backup, configurações, controles, overlay de desempenho (F3), testes automáticos |
| **M1** Atmosfera | Céu próprio, ciclo de dia e noite de 24 min, sol e lua, névoa e graduação de cor |
| **M2** Ilha | Ilha de 2 km gerada por seed, com 6 regiões (Vale, Floresta, Picos, Terras Calcinadas, Pântano, Costa) e a Cidadela, mais mar com ondas |
| **M3** Personagem | Mago com câmera em terceira pessoa, animações e cajado com cristal |
| **M4** Vegetação | Árvores, rochas, grama, flores, samambaias e cogumelos, com 4 presets gráficos (Baixo, Médio, Alto, Ultra) |
| **M5** Travessia | Escalada, planador, natação, esquiva, mapa com névoa de guerra |
| **M6** Combate | 8 feitiços, ataque básico em combo, lock-on, inimigos, ruínas e farol |
| **M7** Mundo | 85 locais: 4 faróis, 8 fogueiras (descanso, save e viagem), 30 baús, 15 acampamentos, mirantes, histórias e 6 tipos de inimigo |
| **M8** Campanha | 12 santuários em 4 tipos de desafio, 4 covis com Guardiões, Cidadela com o chefe final "O Medo" em 3 fases e epílogo |
| **M9** Progressão e UI | Menu inicial, pausa, 3 espaços de save, Grimório (inventário, personagem, feitiços, diário), mercador, 17 itens, opções completas e acessibilidade, gamepad em tudo |
| **M10** Áudio e polimento | Música adaptativa (dia, noite, combate, chefe, regiões sombrias), sons de ambiente por região, mapa pintado, lava na cratera do vulcão, dificuldade |
| **M11** Exportação | `DarkMage.exe` para Windows, com teste automático rodando no próprio executável |
| **M12** Otimização e RC | Menos draw calls, teste de vazamento de 10 min aprovado, ajuste automático de qualidade na primeira execução, epílogo com câmera e créditos |

### A campanha em uma frase
Acender o farol do Vale, depois os outros faróis; vencer os 4 Guardiões (Floresta, Picos, Terras Calcinadas e
Pântano), cada um ensinando um feitiço novo; com isso a cúpula da Cidadela se abre e o chefe final pode ser enfrentado.

---

## 3. O que foi verificado automaticamente (APROVADO)
- **Testes:** os 113 testes passam, sem erros nem avisos do Godot. As únicas exceções são 3 mensagens conhecidas do Terrain3D.
- **Chefes:** cada Guardião e o chefe final morrem em teste. As fases mudam, a mecânica de cada um é quebrada pelo feitiço certo, a região é purificada e o feitiço novo é concedido.
- **Santuários:** os 4 tipos de desafio se resolvem, e o altar aumenta a vida ou a mana.
- **Save:** salvar e carregar na ilha restaura tudo (posição, hora, progresso, inventário, feitiços, marcadores e mapa). Saves antigos são convertidos para o formato novo sem perder nada.
- **Menus:** todos abrem com um item selecionado, e todo controle é alcançável pelas setas.
- **Executável:** o .exe abre no menu, cria um jogo novo, salva, volta ao menu e carrega o jogo de novo.
- **Vazamento:** 10 minutos de jogo simulado com 973 feitiços, sem crescimento de memória.
- **Licenças:** todos os 344 assets estão registrados em `ASSETS_LICENSES.md` e `CREDITS.md`.

---

## 4. O que VOCÊ precisa testar
Nada disto pude fazer por conta própria. A lista completa, com caixas de marcar, está em `QA_CHECKLIST.md`.

### Essencial
1. **Jogar a campanha inteira**: novo jogo → farol do Vale → faróis → 4 Guardiões → Cidadela → chefe final → epílogo e créditos.
2. **Benchmark no Nitro V15** com o preset Alto, em 1080p (meta: 100 FPS ou mais). Rode
   `godot --path . -- --bench --preset=high` e cole o resultado em `PERFORMANCE.md`.
3. **Gamepad físico**: navegar por todos os menus só com o controle e usar LB + botões para os feitiços.
4. **Ouvir o áudio** por uns 10 minutos: dia → noite, entrar e sair de combate, entrar num covil e ouvir a música do chefe. Ajuste os volumes se algo estourar.

### Também vale conferir
5. Morrer dentro de um santuário e renascer na entrada da sala.
6. Comprar um cajado no mercador (perto da fogueira do Vale), equipar e ver o ataque básico mudar.
7. Salvar no espaço 2 pela pausa, voltar ao menu, escolher Continuar e conferir se tudo voltou.
8. Opções: janela, sem bordas e tela cheia; idioma em inglês; filtro de daltonismo; escala da interface.
9. Viagem rápida pelo mapa (cursor sobre uma fogueira já descoberta).
10. Copiar a pasta `build\export\windows\` para outro lugar, desligar a internet e jogar.
11. Abrir o projeto no editor e conferir se o painel Saída não mostra erros.

---

## 5. Limitações conhecidas (em `TODO.md`)
- Os Guardiões reaproveitam esqueleto, golem e serpente, só com outro tamanho e outra cor; ainda não têm silhueta própria.
- A cúpula da Cidadela é uma esfera translúcida simples.
- O mago é o modelo KayKit recolorido, com um visual mais fofo que sombrio.
- Os sons de ambiente (vento, ondas, pântano, fogo) foram gerados por programa e podem soar artificiais. Não pude ouvi-los.
- As arenas dos covis são salas quadradas.
- Todo o desempenho foi medido num notebook com Intel UHD, não no Nitro V15.

---

## 6. Documentos do projeto 
| Arquivo | Para quê |
|---|---|
| `PROGRESS.md` | Diário de cada marco: o que foi feito, testes e autocrítica |
| `QA_CHECKLIST.md` | Roteiro de testes manuais |
| `TODO.md` | Pendências por prioridade |
| `DECISIONS.md` | 70 decisões técnicas registradas (D01–D70) |
| `PERFORMANCE.md` | Medições de FPS e o teste de vazamento |
| `ASSETS_LICENSES.md` / `CREDITS.md` | Origem e licença de cada asset |
| `README.md` | Como abrir, testar, exportar e a estrutura do projeto |
| `tests/golden/m1…m12/` | Capturas de tela de cada marco |

Quando testar, é só me dizer o que mudar.
