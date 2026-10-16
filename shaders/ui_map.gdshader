shader_type canvas_item;
// Mapa da ilha em estilo pergaminho, com névoa de guerra animada nas áreas
// ainda não exploradas.

uniform sampler2D fog_mask : filter_linear;
uniform sampler2D paper_noise : repeat_enable, filter_linear;
uniform vec3 paper : source_color = vec3(0.86, 0.79, 0.64);
uniform vec3 ink : source_color = vec3(0.16, 0.11, 0.1);
uniform vec3 fog_color : source_color = vec3(0.09, 0.07, 0.12);

void fragment() {
	vec4 map = texture(TEXTURE, UV);
	float n = texture(paper_noise, UV * 3.0).r;
	// Mapa "pintado": mistura a cor do mapa com o papel.
	// O mapa já vem pintado (tools/make_map.gd): só a textura do papel por cima.
	vec3 col = map.rgb * (0.9 + n * 0.16);
	float reveal = texture(fog_mask, UV).r;
	float swirl = texture(paper_noise, UV * 6.0 + vec2(TIME * 0.01, TIME * 0.006)).r;
	float fog = 1.0 - smoothstep(0.25, 0.75, reveal + (swirl - 0.5) * 0.25);
	// Áreas não exploradas: névoa que ainda deixa ver o contorno da ilha.
	col = mix(col, mix(fog_color * (0.8 + swirl * 0.4), col * 0.35, 0.3), fog * 0.85);
	// Vinheta de borda.
	vec2 d = abs(UV - 0.5) * 2.0;
	col *= 1.0 - smoothstep(0.85, 1.0, max(d.x, d.y)) * 0.5;
	COLOR = vec4(col, 1.0);
}
