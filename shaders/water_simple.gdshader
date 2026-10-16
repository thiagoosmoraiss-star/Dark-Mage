shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Água do preset Baixo: mesmas ondas Gerstner, sem leitura da tela nem da
// profundidade (evita a cópia do buffer em GPU integrada). Opaca, com fresnel
// e espuma de crista por ruído.

uniform sampler2D normal_noise : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;

uniform vec3 shallow_color : source_color = vec3(0.16, 0.42, 0.44);
uniform vec3 deep_color : source_color = vec3(0.03, 0.08, 0.16);
uniform vec3 foam_color : source_color = vec3(0.92, 0.94, 0.96);
uniform float absorption = 0.28;
uniform float refraction_strength = 0.035;
uniform float wave_scale = 1.0;
uniform vec4 wave_a = vec4(1.0, 0.3, 0.18, 46.0);   // dir.xy, steepness, comprimento
uniform vec4 wave_b = vec4(-0.4, 1.0, 0.14, 23.0);
uniform vec4 wave_c = vec4(0.7, -0.8, 0.1, 11.0);
uniform float wave_fade_distance = 650.0;
uniform float corruption = 0.0;
#include "res://shaders/lava_inc.gdshaderinc"

varying vec3 world_pos;
varying float crest;

vec3 gerstner(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
	float steepness = wave.z * wave_scale;
	float k = 2.0 * PI / wave.w;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(wave.xy);
	float f = k * (dot(d, p.xz) - c * TIME);
	float a = steepness / k;
	tangent += vec3(-d.x * d.x * steepness * sin(f), d.x * steepness * cos(f), -d.x * d.y * steepness * sin(f));
	binormal += vec3(-d.x * d.y * steepness * sin(f), d.y * steepness * cos(f), -d.y * d.y * steepness * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = 1.0 - smoothstep(wave_fade_distance * 0.5, wave_fade_distance, length(wp.xz - CAMERA_POSITION_WORLD.xz));
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 offs = gerstner(wave_a, wp, tangent, binormal);
	offs += gerstner(wave_b, wp, tangent, binormal);
	offs += gerstner(wave_c, wp, tangent, binormal);
	fade *= 1.0 - lava_amount(wp.xz);  // lava não ondula
	wp += offs * fade;
	crest = offs.y * fade;
	vec3 n = normalize(cross(binormal, tangent));
	n = normalize(mix(vec3(0.0, 1.0, 0.0), n, fade));
	world_pos = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(n, 0.0)).xyz;
}

void fragment() {
	vec2 uv1 = world_pos.xz * 0.045 + vec2(TIME * 0.012, TIME * 0.007);
	vec2 uv2 = world_pos.xz * 0.11 - vec2(TIME * 0.009, -TIME * 0.015);
	vec3 n1 = texture(normal_noise, uv1).rgb;
	vec3 n2 = texture(normal_noise, uv2).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.55;
	float fn = texture(foam_noise, world_pos.xz * 0.31 - vec2(0.0, TIME * 0.03)).r;
	float foam = smoothstep(0.9, 1.6, crest + fn * 0.8) * 0.6;
	vec3 water_col = mix(deep_color, shallow_color, 0.35 + 0.25 * fn);
	water_col = mix(water_col, water_col * vec3(0.7, 0.45, 1.1), corruption);
	ALBEDO = mix(water_col, foam_color, foam);
	ROUGHNESS = mix(0.05, 0.6, foam);
	SPECULAR = 0.55;
	float lava = lava_amount(world_pos.xz);
	if (lava > 0.001) {
		ALBEDO = mix(ALBEDO, vec3(0.05, 0.025, 0.02), lava);
		EMISSION = mix(EMISSION, lava_emission(world_pos.xz, TIME, foam_noise), lava);
		ROUGHNESS = mix(ROUGHNESS, 0.9, lava);
		SPECULAR = mix(SPECULAR, 0.1, lava);
	}
}
