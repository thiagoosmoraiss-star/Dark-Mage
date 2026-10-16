shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
// Criaturas espectrais: corpo escuro translúcido com borda violeta luminosa
// (fresnel) e veios que pulsam.

uniform vec4 core : source_color = vec4(0.08, 0.04, 0.12, 0.85);
uniform vec4 rim : source_color = vec4(0.71, 0.49, 1.0, 1.0);
uniform float rim_power = 2.2;
uniform float flash = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float veins = smoothstep(0.55, 0.7, texture(noise_tex, UV * 3.0 + vec2(TIME * 0.05)).r);
	float pulse = 0.7 + 0.3 * sin(TIME * 3.0);
	ALBEDO = core.rgb;
	EMISSION = rim.rgb * (fres * 2.2 + veins * 0.6 * pulse) + vec3(flash * 2.0);
	ALPHA = clamp(core.a + fres * 0.4, 0.0, 1.0);
	ROUGHNESS = 0.4;
}
