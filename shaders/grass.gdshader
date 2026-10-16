shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Tufos de grama em MultiMesh: vento por ruído, abre passagem ao redor do
// jogador (uniform global), cor por instância (região) e fade por distância.

global uniform vec3 player_position;
global uniform float wind_strength;
global uniform vec2 wind_direction;

uniform vec3 tip_color : source_color = vec3(0.66, 0.7, 0.36);
uniform vec3 base_color : source_color = vec3(0.16, 0.24, 0.1);
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform float fade_start = 40.0;
uniform float fade_end = 60.0;
uniform float translucency = 0.35;

varying float tip;
varying vec3 inst_color;
varying float dither_fade;

void vertex() {
	tip = UV.y;  // 0 na base, 1 na ponta
	inst_color = INSTANCE_CUSTOM.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Vento: rajadas por ruído que corre na direção do vento.
	vec2 wuv = root.xz * 0.02 - wind_direction * TIME * 0.06;
	float gust = texture(wind_noise, wuv).r;
	float sway = sin(TIME * 2.2 + root.x * 0.7 + root.z * 0.5) * 0.25 + gust * 1.2;
	vec2 bend = wind_direction * sway * wind_strength * 0.35;
	// Interação: empurra para longe do jogador.
	vec3 away = root - player_position;
	float d = length(away.xz);
	float push = smoothstep(1.4, 0.2, d) * step(abs(away.y), 2.0);
	bend += normalize(away.xz + vec2(0.001)) * push * 0.75;
	float k = tip * tip;
	wp.xz += bend * k;
	wp.y -= length(bend) * k * 0.35;
	// Encolhe na borda do alcance (sem "pop").
	float cam_d = length(root - CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, cam_d);
	wp.y = mix(root.y, wp.y, shrink);
	dither_fade = shrink;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	vec3 col = mix(base_color, tip_color, tip) * inst_color * 1.45;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(translucency) * tip * inst_color;
	AO = mix(0.4, 1.0, tip);
	AO_LIGHT_AFFECT = 0.4;
	if (dither_fade < 0.98) {
		float dith = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (dith > dither_fade) {
			discard;
		}
	}
}
