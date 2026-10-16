class_name IslandLayout
extends RefCounted
## Composição autoral da Ilha do Medo (roteiro 3.1 e 3.2). Coordenadas em metros,
## origem no centro; +X = leste, -Z = norte. A ilha ocupa ~2 × 2 km.

const WORLD_SIZE: float = 2048.0
const HALF: float = WORLD_SIZE * 0.5
const SEA_LEVEL: float = 0.0
const ISLAND_RADIUS: float = 860.0

enum Region { SEA, COAST, VALLEY, FOREST, PEAKS, BURNT, SWAMP, CITADEL }

const REGION_NAMES: Dictionary = {
	Region.SEA: &"sea", Region.COAST: &"coast", Region.VALLEY: &"valley", Region.FOREST: &"forest",
	Region.PEAKS: &"peaks", Region.BURNT: &"burnt", Region.SWAMP: &"swamp", Region.CITADEL: &"citadel",
}

## Centros das regiões (influência suave, perturbada por ruído).
const REGION_CENTERS: Dictionary = {
	Region.VALLEY: Vector2(0, 40),
	Region.FOREST: Vector2(40, 560),
	Region.PEAKS: Vector2(-60, -640),
	Region.BURNT: Vector2(600, -20),
	Region.SWAMP: Vector2(-600, 120),
}
const REGION_SIGMA: float = 360.0

## Cidadela do Medo: platô no centro-norte, visível de toda a ilha.
const CITADEL_CENTER: Vector2 = Vector2(0, -360)
const CITADEL_TOP: float = 108.0
const CITADEL_RADIUS: float = 85.0
const CITADEL_SKIRT: float = 55.0

## Vulcão das Terras Calcinadas.
const VOLCANO_CENTER: Vector2 = Vector2(690, -110)
const VOLCANO_RADIUS: float = 270.0
const VOLCANO_HEIGHT: float = 165.0
const CRATER_RADIUS: float = 52.0

## Materiais do terreno (índices no Terrain3DAssets).
enum Mat { GRASS, MOSS, DIRT, ROCK, SAND, SNOW, CORRUPT, VOLCANIC }
const MATERIALS: Array[String] = [
	"grass004", "ground037", "ground071", "rock051", "ground054", "snow014", "ground110", "rock035",
]
## uv_scale por material (menor = textura maior no mundo).
const UV_SCALES: Array[float] = [0.16, 0.12, 0.14, 0.07, 0.12, 0.1, 0.12, 0.08]
