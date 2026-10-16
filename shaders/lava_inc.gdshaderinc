// Lava nas poças das Terras Calcinadas: a água vira crosta escura com veios
// incandescentes onde a máscara (região BURNT, borrada) é positiva.
uniform sampler2D lava_mask : hint_default_black, filter_linear;
uniform float lava_world_size = 2048.0;

float lava_amount(vec2 xz) {
	vec2 uv = (xz + lava_world_size * 0.5) / lava_world_size;
	return smoothstep(0.25, 0.6, textureLod(lava_mask, uv, 0.0).r);
}

vec3 lava_emission(vec2 xz, float t, sampler2D ntex) {
	float n1 = texture(ntex, xz * 0.05 + vec2(t * 0.01, t * 0.004)).r;
	float n2 = texture(ntex, xz * 0.13 - vec2(t * 0.006, -t * 0.012)).r;
	float cracks = smoothstep(0.55, 0.72, n1 * 0.6 + n2 * 0.55);
	float pulse = 0.85 + 0.15 * sin(t * 1.3 + n1 * 6.0);
	vec3 glow = mix(vec3(0.9, 0.12, 0.02), vec3(1.0, 0.62, 0.12), cracks);
	return glow * (0.18 + 2.4 * cracks) * pulse;
}
