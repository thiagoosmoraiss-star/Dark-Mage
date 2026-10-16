shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// Anel de onda de choque num quad horizontal. `progress` 0..1 expande e apaga.

uniform vec4 color : source_color = vec4(0.71, 0.49, 1.0, 1.0);
uniform float progress = 0.0;
uniform float thickness = 0.12;
uniform float energy = 3.5;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ring_r = mix(0.05, 0.98, progress);
	float n = texture(noise_tex, vec2(atan(c.y, c.x) * 0.3, progress * 0.5)).r;
	float ring = 1.0 - smoothstep(0.0, thickness * (1.0 - progress * 0.5), abs(r - ring_r) + (n - 0.5) * 0.04);
	float inner = smoothstep(ring_r, 0.0, r) * 0.25 * (1.0 - progress);
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	float a = (ring + inner) * fade;
	ALBEDO = color.rgb * energy * a;
	ALPHA = a;
}
