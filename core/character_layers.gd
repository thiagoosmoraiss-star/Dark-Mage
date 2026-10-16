class_name CharacterLayers
extends RefCounted
## Camadas visuais: 1 = mundo (terreno, estruturas, vegetação), 2 = personagens.
## Decals (indicadores no chão) só projetam na camada 1.

const WORLD: int = 1
const CHARACTERS: int = 2


static func apply(root: Node) -> void:
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = CHARACTERS
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = CHARACTERS
