shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Partícula suave com mistura normal (neve, cinzas): disco com borda difusa.

uniform float energy = 1.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float a = clamp(1.0 - dot(c, c), 0.0, 1.0);
	ALBEDO = COLOR.rgb * energy;
	ALPHA = a * COLOR.a;
}
