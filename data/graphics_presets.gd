class_name GraphicsPresets
extends RefCounted
## Presets gráficos (roteiro, seção 10). Valores lidos por Settings e pelos
## sistemas de mundo (ambiente, vegetação, sombras) quando o preset muda.

const LOW: StringName = &"low"
const MEDIUM: StringName = &"medium"
const HIGH: StringName = &"high"
const ULTRA: StringName = &"ultra"
const ORDER: Array[StringName] = [LOW, MEDIUM, HIGH, ULTRA]

const PRESETS: Dictionary = {
	LOW: {
		"render_scale": 0.6, "fsr": true, "taa": false, "fxaa": true,
		"shadow_splits": 2, "shadow_atlas": 1024, "shadow_distance": 80.0,
		"vegetation_density": 0.25, "ssao": false, "ssil": false, "ssr": false,
		"volumetric_fog": false, "volumetric_quality": 0, "max_texture_size": 512,
		"sky_radiance_update_s": 2.0,
		"veg_lod0_end": 55.0, "veg_lod1_end": 200.0, "veg_impostor_end": 1100.0, "rock_far_end": 260.0,
		"grass_radius_scale": 0.62, "water_quality": 0, "tree_shadows_lod1": false,
	},
	MEDIUM: {
		"render_scale": 0.75, "fsr": true, "taa": false, "fxaa": false,
		"shadow_splits": 2, "shadow_atlas": 2048, "shadow_distance": 180.0,
		"vegetation_density": 0.5, "ssao": true, "ssil": false, "ssr": false,
		"volumetric_fog": true, "volumetric_quality": 1, "max_texture_size": 1024,
		"sky_radiance_update_s": 0.5,
		"veg_lod0_end": 75.0, "veg_lod1_end": 280.0, "veg_impostor_end": 1400.0, "rock_far_end": 450.0,
		"grass_radius_scale": 0.8, "water_quality": 1, "tree_shadows_lod1": false,
	},
	HIGH: {
		"render_scale": 1.0, "fsr": false, "taa": true, "fxaa": false,
		"shadow_splits": 4, "shadow_atlas": 2048, "shadow_distance": 250.0,
		"vegetation_density": 0.8, "ssao": true, "ssil": true, "ssr": true,
		"volumetric_fog": true, "volumetric_quality": 2, "max_texture_size": 2048,
		"sky_radiance_update_s": 0.0,
		"veg_lod0_end": 95.0, "veg_lod1_end": 340.0, "veg_impostor_end": 1700.0, "rock_far_end": 650.0,
		"grass_radius_scale": 1.0, "water_quality": 1, "tree_shadows_lod1": true,
	},
	ULTRA: {
		"render_scale": 1.0, "fsr": false, "taa": true, "fxaa": false,
		"shadow_splits": 4, "shadow_atlas": 4096, "shadow_distance": 400.0,
		"vegetation_density": 1.0, "ssao": true, "ssil": true, "ssr": true,
		"volumetric_fog": true, "volumetric_quality": 3, "max_texture_size": 2048,
		"sky_radiance_update_s": 0.0,
		"veg_lod0_end": 130.0, "veg_lod1_end": 450.0, "veg_impostor_end": 2200.0, "rock_far_end": 900.0,
		"grass_radius_scale": 1.3, "water_quality": 1, "tree_shadows_lod1": true,
	},
}


static func get_preset(preset: StringName) -> Dictionary:
	return PRESETS.get(preset, PRESETS[HIGH])


## Primeira escolha pelo nome do adaptador. O microbenchmark (M1) pode
## rebaixar ou subir um nível a partir daqui.
static func guess_from_adapter(adapter_name: String) -> StringName:
	var n: String = adapter_name.to_lower()
	if n.contains("rtx 40") or n.contains("rtx 50") or n.contains("rx 7") or n.contains("rx 9"):
		return HIGH
	if n.contains("rtx") or n.contains("gtx 16") or n.contains("rx 6") or n.contains("arc"):
		return HIGH
	if n.contains("iris xe") or n.contains("680m") or n.contains("780m") or n.contains("890m"):
		return MEDIUM
	if n.contains("uhd") or n.contains("hd graphics") or n.contains("vega"):
		return LOW
	return MEDIUM
