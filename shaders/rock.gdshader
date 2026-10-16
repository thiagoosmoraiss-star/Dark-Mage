shader_type spatial;
// Rocha estilizada: triplanar procedural (ruído), estratos, musgo no topo e
// cavidade da cor de vértice. Coordenadas de mundo para continuidade entre rochas.
#include "res://shaders/include/triplanar.gdshaderinc"

uniform vec3 stone_light : source_color = vec3(0.79, 0.75, 0.66);  // #C9BFA8
uniform vec3 stone_dark : source_color = vec3(0.33, 0.31, 0.32);
uniform vec3 moss_color : source_color = vec3(0.31, 0.48, 0.23);   // #4F7A3A
uniform float moss_amount : hint_range(0.0, 1.0) = 0.45;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float detail_scale = 0.35;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = triplanar_weights(world_nrm, 4.0);
	float n1 = triplanar(detail_noise, world_pos, w, detail_scale).r;
	float n2 = triplanar(detail_noise, world_pos, w, detail_scale * 4.3).r;
	float strata = sin(world_pos.y * 5.0 + n1 * 6.0) * 0.5 + 0.5;
	float cav = COLOR.r;
	vec3 col = mix(stone_dark, stone_light, clamp(n1 * 0.9 + n2 * 0.35 + strata * 0.15 - 0.15, 0.0, 1.0));
	col *= mix(0.55, 1.05, cav);
	float top = smoothstep(0.45, 0.85, world_nrm.y + (n2 - 0.5) * 0.6);
	float moss = top * smoothstep(0.35, 0.6, n1 + moss_amount - 0.45) * moss_amount * 2.0;
	vec3 moss_col = mix(moss_color * 0.7, moss_color * 1.15, n2);
	moss_col = mix(moss_col, vec3(0.16, 0.08, 0.22), corruption);
	col = mix(col, moss_col, clamp(moss, 0.0, 1.0));
	col = mix(col, col * vec3(0.7, 0.6, 0.85), corruption * 0.6);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.75, moss) - n2 * 0.08;
	vec3 nm = triplanar(detail_normal, world_pos, w, detail_scale * 2.0).rgb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.2;
	AO = mix(0.4, 1.0, cav);
	AO_LIGHT_AFFECT = 0.35;
}
