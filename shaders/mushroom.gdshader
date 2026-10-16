shader_type spatial;
render_mode cull_disabled;
// Cogumelos bioluminescentes: o chapéu (cor de vértice saturada) emite luz;
// a haste clara não. O brilho pulsa devagar, um pouco mais forte à noite.

uniform float glow = 2.4;

void fragment() {
	vec3 c = COLOR.rgb;
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	ALBEDO = c * 0.6;
	ROUGHNESS = 0.6;
	float pulse = 0.8 + 0.2 * sin(TIME * 1.3 + NODE_POSITION_WORLD.x * 0.7);
	EMISSION = c * glow * smoothstep(0.15, 0.4, sat) * pulse;
}
