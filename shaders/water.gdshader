shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
// Mar e lagos: ondas Gerstner (3), cor por profundidade (DEPTH_TEXTURE),
// refração (SCREEN_TEXTURE), espuma na costa e nas cristas, fresnel.
// Reflexos vêm do céu e do SSR (Alto ou acima).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
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
	// Ondulação fina por duas camadas de normal em movimento.
	vec2 uv1 = world_pos.xz * 0.045 + vec2(TIME * 0.012, TIME * 0.007);
	vec2 uv2 = world_pos.xz * 0.11 - vec2(TIME * 0.009, -TIME * 0.015);
	vec3 n1 = texture(normal_noise, uv1).rgb;
	vec3 n2 = texture(normal_noise, uv2).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.55;

	// Espessura da água até o fundo.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -upos.z / upos.w;
	float water_z = -VERTEX.z;
	float thickness = max(scene_z - water_z, 0.0);

	// Refração: desloca a amostra da tela, sem puxar objetos à frente da água.
	vec2 distort = (n1.xy - 0.5) * refraction_strength * clamp(thickness * 0.3, 0.0, 1.0);
	vec2 ruv = SCREEN_UV + distort;
	float rdepth = texture(depth_tex, ruv).r;
	vec4 rpos = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, rdepth, 1.0);
	if (-rpos.z / rpos.w < water_z) {
		ruv = SCREEN_UV;
	}
	vec3 refr = textureLod(screen_tex, ruv, 0.0).rgb;

	float trans = exp(-thickness * absorption);
	vec3 water_col = mix(deep_color, shallow_color, exp(-thickness * absorption * 0.35));
	water_col = mix(water_col, water_col * vec3(0.7, 0.45, 1.1), corruption);

	// Espuma: na costa (água rasa) e nas cristas das ondas.
	float fn = texture(foam_noise, world_pos.xz * 0.12 + vec2(TIME * 0.02, 0.0)).r;
	float fn2 = texture(foam_noise, world_pos.xz * 0.31 - vec2(0.0, TIME * 0.03)).r;
	float shore = 1.0 - smoothstep(0.0, 1.6, thickness);
	float shore_band = smoothstep(0.35, 0.75, fn * 0.6 + fn2 * 0.5 + shore * 0.5) * shore;
	float crest_foam = smoothstep(0.9, 1.6, crest + fn2 * 0.8) * 0.6;
	float foam = clamp(shore_band + crest_foam, 0.0, 1.0);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = mix(water_col * 0.35, foam_color, foam);
	EMISSION = refr * trans * (1.0 - fresnel) * (1.0 - foam) * mix(vec3(1.0), shallow_color * 1.6, 0.35);
	ROUGHNESS = mix(0.04, 0.6, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
	ALPHA = 1.0;
	// Lagos do pântano: água turva e violeta, quase opaca.
	float swamp = swamp_amount(world_pos.xz);
	if (swamp > 0.001) {
		ALBEDO = mix(ALBEDO, vec3(0.07, 0.035, 0.09), swamp);
		EMISSION = mix(EMISSION, vec3(0.03, 0.01, 0.05), swamp * 0.85);
		ROUGHNESS = mix(ROUGHNESS, 0.35, swamp);
	}
	float lava = lava_amount(world_pos.xz);
	if (lava > 0.001) {
		ALBEDO = mix(ALBEDO, vec3(0.05, 0.025, 0.02), lava);
		EMISSION = mix(EMISSION, lava_emission(world_pos.xz, TIME, foam_noise), lava);
		ROUGHNESS = mix(ROUGHNESS, 0.9, lava);
		SPECULAR = mix(SPECULAR, 0.1, lava);
	}
}
