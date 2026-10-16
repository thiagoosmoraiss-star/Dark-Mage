// Amostragem triplanar (projeção em X, Y e Z misturada pela normal).
vec3 triplanar_weights(vec3 n, float sharpness) {
	vec3 w = pow(abs(n), vec3(sharpness));
	return w / (w.x + w.y + w.z + 1e-5);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w, float scale) {
	return texture(tex, p.zy * scale) * w.x + texture(tex, p.xz * scale) * w.y + texture(tex, p.xy * scale) * w.z;
}
