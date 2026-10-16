shader_type spatial;
// Chão provisório da cena de testes de atmosfera (M1). Será substituído pelo
// Terrain3D com texturas PBR no M2 (placeholder registrado em TODO.md).
#include "res://shaders/include/triplanar.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.31, 0.48, 0.23);
uniform vec3 grass_b : source_color = vec3(0.62, 0.55, 0.26);
uniform vec3 dirt : source_color = vec3(0.36, 0.28, 0.2);
uniform vec3 rock : source_color = vec3(0.45, 0.42, 0.4);
uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float macro = texture(detail_noise, world_pos.xz * 0.004).r;
	float mid = texture(detail_noise, world_pos.xz * 0.03).r;
	float fine = texture(detail_noise, world_pos.xz * 0.35).r;
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.35, 0.7, macro + (mid - 0.5) * 0.4));
	grass *= 0.8 + fine * 0.35;
	float slope = 1.0 - world_nrm.y;
	float dirt_w = smoothstep(0.55, 0.75, mid + fine * 0.2) * 0.7;
	vec3 col = mix(grass, dirt * (0.8 + fine * 0.4), dirt_w);
	vec3 w = triplanar_weights(world_nrm, 4.0);
	float rn = triplanar(detail_noise, world_pos, w, 0.2).r;
	col = mix(col, rock * (0.7 + rn * 0.5), smoothstep(0.18, 0.32, slope + (fine - 0.5) * 0.1));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	NORMAL_MAP = texture(detail_normal, world_pos.xz * 0.25).rgb;
	NORMAL_MAP_DEPTH = 0.6;
}
