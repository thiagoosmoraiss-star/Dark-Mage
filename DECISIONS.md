# Decisões

Formato: data · decisão · motivo · impacto / como reverter.

## 2026-10-16 (M0)

**D01 · Roteiro seguido: Godot 4 (`ROTEIRO-DARK-MAGE-GODOT.md`).**
O dono pediu inicialmente o roteiro Three.js/Electron ("DO-ZERO"), depois removeu esse arquivo da pasta e
deixou só o roteiro Godot. Seguimos o roteiro Godot. Nenhum código das versões antigas foi lido ou usado.

**D02 · Godot 4.7.2-stable (padrão, sem .NET), portátil, fora do repositório.**
Era a estável mais recente no GitHub (`4.7.2-stable`, 18/08/2026). Baixada com autorização do dono para
`../tools/godot/` (ao lado do projeto), com SHA-512 conferido contra `SHA512-SUMS.txt` oficial. Não está no
PATH: os scripts usam `GODOT_BIN` ou esse caminho. O `Godot_v4.7.2-stable_win64_console.exe` falha com
`CreateProcess error 193` quando o caminho tem espaços; usamos o executável principal, que imprime normalmente.

**D03 · Addons fixados.**
- Terrain3D **v1.0.2-stable** (MIT), release oficial do GitHub (`Terrain3D_v1.0.2-stable.zip`,
  sha256 `a0718502…84a2`). Oficialmente suporta Godot 4.4–4.6+; carrega e instancia no 4.7.2 (teste
  `test_terrain3d_extension_loaded`). Mantidos só os binários Windows e Linux x86_64 (alvo é Windows; Linux
  para eventual CI).
- GdUnit4 **v6.2.2** (MIT), repositório atual `godot-gdunit-labs/gdUnit4` (sha256 do zip `1a2653bd…040d`).

**D04 · Plugin de editor do Terrain3D desativado por padrão.**
Com ele ativo, `godot --headless --import` termina com vazamentos (`EditorDock` e ícone `terrain3d.svg`)
gerados pelo próprio plugin ao fechar o editor no 4.7. A GDExtension (classes `Terrain3D*`) continua ativa,
e o terreno será gerado por script (roteiro 3.1), então o dock de pintura não é necessário. Para esculpir à
mão no editor: Projeto → Configurações → Plugins → ativar Terrain3D (o aviso ao fechar é inofensivo).
Reavaliar quando sair versão do Terrain3D com suporte oficial ao 4.7.

**D05 · Física Jolt, 60 Hz, interpolação de física ligada.** Conforme roteiro 4.2 e 7.5.

**D06 · Renderer Forward+ com Vulkan (padrão do Windows nesta versão).**
Confirmado na execução: `Vulkan 1.4.323 - Forward+`. D3D12 fica como alternativa a testar no Nitro V15 (M1).

**D07 · Warnings de tipagem são erros.**
`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` e `unsafe_call_argument` = erro;
`unsafe_cast` = aviso. Os addons são excluídos pelo padrão do Godot. O `tools/check.sh` reprova qualquer
`WARNING`/`ERROR` nos logs.

**D08 · Interagir = G.** E é o Feitiço 2; tecla única evita ambiguidade. Gamepad: X.

**D09 · Sprint no gamepad = L3; esquiva = B.** O roteiro lista B para os dois; B fica só com a esquiva
para não haver ação dupla no mesmo botão. Feitiços no gamepad (LB + face / roda com RB) serão feitos no M9.

**D10 · InputMap gerado a partir de `data/input_defaults.gd`.**
Uma só fonte para o `project.godot` (via `tools/setup_input_map.gd`), para restaurar padrões e para
remapear. O teste `test_project_input_section_matches_defaults` detecta divergência.

**D11 · Saves em JSON versionado (`SaveCodec`) com escrita atômica e backup.**
Grava `.tmp` → renomeia; o save anterior válido vira `.bak`. Nada de `Resource`/`.tres` (roteiro 4.7).

**D12 · Configurações em `ConfigFile` (`user://settings.cfg`).** Só dados; remapeamentos guardados no
formato da tabela de padrões.

**D13 · Nomes de arquivo em snake_case** (`autoload/game.gd`), conforme o guia de estilo do Godot; os nomes
dos autoloads seguem o roteiro (`Game`, `Events`, `Settings`, `SaveSystem`, `Rng`).

**D14 · Hash estável próprio (FNV-1a 32 bits) em vez de `String.hash()`.**
Garante as mesmas seeds e os mesmos hashes de dados de altura em qualquer versão ou plataforma.

**D15 · Git LFS para binários** (`.png`, `.glb`, `.exr`, `.wav`, `.ogg`, `.dll`, `.so`...). `.import` são
versionados; `.godot/`, `build/` e `reports/` não.

**D16 · Máquina de desenvolvimento ≠ hardware de referência.**
O agente roda num Lenovo 83NS (i5-13420H, Intel UHD Graphics). Capturas aqui são funcionais; FPS e
qualidade final do preset Alto são medidos pelo dono no Nitro V15 (RTX 4050).
