shader_type spatial;
render_mode cull_back;
// Lago de lava da cratera: crosta escura com veios que se movem e pulsam.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
#include "res://shaders/lava_inc.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, world_pos.xz * 0.02 + vec2(TIME * 0.01, 0.0)).r;
	VERTEX.y += (n - 0.5) * 0.6;
}

void fragment() {
	vec3 e = lava_emission(world_pos.xz, TIME, noise_tex);
	ALBEDO = vec3(0.05, 0.025, 0.02);
	EMISSION = e * 0.55;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
