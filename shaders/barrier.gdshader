shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// Bolha da Égide Violeta: borda de fresnel, padrão hexagonal e pulso.

uniform vec4 color : source_color = vec4(0.91, 0.71, 0.3, 1.0);
uniform float strength = 1.0;
uniform float hit_flash = 0.0;

float hex(vec2 p) {
	p = abs(fract(p) - 0.5);
	return max(p.x * 1.5 + p.y * 0.866, p.y * 1.732);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	vec2 uv = UV * vec2(24.0, 12.0);
	float h = smoothstep(0.42, 0.48, hex(uv + vec2(0.0, TIME * 0.2)));
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	float a = (fres * 0.9 + h * 0.18 * fres + hit_flash * 0.5) * strength * pulse;
	ALBEDO = color.rgb * 2.5 * a;
	ALPHA = a;
}
