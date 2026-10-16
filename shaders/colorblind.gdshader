shader_type canvas_item;
// Daltonização (Fidaner et al.): simula a deficiência, mede o erro e o redistribui
// para os canais que a pessoa percebe. mode: 1 protanopia, 2 deuteranopia, 3 tritanopia.

uniform int mode = 0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

const mat3 RGB2LMS = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS2RGB = mat3(vec3(0.0809444479, -0.0102485335, -0.000365296938), vec3(-0.130504409, 0.0540193266, -0.00412161469), vec3(0.116721066, -0.113614708, 0.693511405));

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 lms = RGB2LMS * c;
	vec3 sim;
	if (mode == 1) {
		sim = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);
	} else if (mode == 2) {
		sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
	} else {
		sim = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
	}
	vec3 err = c - LMS2RGB * sim;
	vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
	COLOR = vec4(clamp(c + shift, 0.0, 1.0), 1.0);
}
