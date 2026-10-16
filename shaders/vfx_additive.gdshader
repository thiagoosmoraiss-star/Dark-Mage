shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// Material aditivo genérico de efeitos (faíscas, núcleos, anéis). A cor vem da
// instância/partícula (COLOR) × tint; `soft` suaviza a borda radial do quad.

uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform float soft = 1.0;
uniform bool radial = true;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float a = radial ? clamp(1.0 - length(c), 0.0, 1.0) : 1.0;
	a = pow(a, mix(0.6, 2.2, soft));
	vec4 col = COLOR * tint;
	ALBEDO = col.rgb * energy * a * col.a;
	ALPHA = a * col.a;
}
