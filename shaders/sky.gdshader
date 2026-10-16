shader_type sky;
// Céu artístico da Ilha do Medo: gradiente por horário, sol com halo, lua,
// estrelas cintilantes e duas camadas de nuvens em movimento.
// Os parâmetros dependentes do horário vêm de world/day_night.gd.
// Não usa TIME: o relógio das nuvens (cloud_time) é enviado pelo script, para
// que o mapa de radiância só seja recalculado no ritmo definido pelo preset.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);   // direção PARA o sol
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0); // direção PARA a lua
uniform vec3 zenith_color : source_color = vec3(0.18, 0.29, 0.48);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.62, 0.55);
uniform vec3 ground_color : source_color = vec3(0.043, 0.035, 0.063);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.68);
uniform vec3 moon_color : source_color = vec3(0.72, 0.68, 1.0);
uniform vec3 cloud_lit_color : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 cloud_shadow_color : source_color = vec3(0.35, 0.33, 0.45);
uniform float sky_energy = 1.0;
uniform float sun_size = 0.9995;      // cosseno do raio do disco
uniform float sun_halo = 0.35;
uniform float moon_size = 0.9993;
uniform float star_intensity = 0.0;
uniform float cloud_coverage = 0.45;  // 0 = limpo, 1 = encoberto
uniform float cloud_time = 0.0;
uniform vec2 wind = vec2(0.006, 0.002);
uniform float corruption = 0.0;       // 0..1, tinge de violeta
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float stars(vec3 dir) {
	vec3 p = dir * 260.0;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h < 0.9965) {
		return 0.0;
	}
	vec3 center = cell + vec3(hash13(cell + 7.1), hash13(cell + 13.7), hash13(cell + 29.3));
	float d = length(p - center);
	float twinkle = 0.65 + 0.35 * sin(cloud_time * 3.0 * (0.5 + h) + h * 600.0);
	return smoothstep(0.45, 0.0, d) * (h - 0.9965) / 0.0035 * twinkle;
}

float cloud_layer(vec3 dir, float scale, vec2 speed, float coverage) {
	vec2 uv = dir.xz / (dir.y + 0.12) * scale + speed * cloud_time;
	float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7 + 0.37).r * 0.35;
	return smoothstep(1.0 - coverage, 1.0 - coverage + 0.32, n);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// Gradiente: horizonte -> zênite, com o horizonte mais quente do lado do sol.
	float t = pow(clamp(up, 0.0, 1.0), 0.45);
	float sun_side = pow(max(dot(normalize(vec3(dir.x, 0.0, dir.z) + 1e-4), normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 1e-4)), 0.0), 3.0);
	vec3 horizon = mix(horizon_color, horizon_color * vec3(1.15, 0.95, 0.8), sun_side * smoothstep(0.35, -0.05, sun_dir.y));
	vec3 col = mix(horizon, zenith_color, t);

	// Abaixo do horizonte: escurece para o "chão" (fica sob o mar e a névoa).
	col = mix(col, ground_color, smoothstep(0.0, -0.25, up));

	// Sol: disco + halo (dispersão de Mie aproximada).
	float cs = dot(dir, sun_dir);
	float sun_vis = smoothstep(-0.12, 0.02, sun_dir.y);
	float disc = smoothstep(sun_size, sun_size + 0.0003, cs);
	float halo = pow(max(cs, 0.0), 12.0) * sun_halo + pow(max(cs, 0.0), 200.0) * 0.8;
	col += sun_color * (halo * sun_vis);

	// Estrelas e lua (somem com o dia).
	float night = clamp(star_intensity, 0.0, 1.0);
	if (!AT_CUBEMAP_PASS && night > 0.0 && up > 0.0) {
		col += vec3(0.85, 0.82, 1.0) * stars(dir) * night * smoothstep(0.0, 0.15, up) * 2.2;
	}
	float cm = dot(dir, moon_dir);
	float moon_disc = smoothstep(moon_size, moon_size + 0.0002, cm);
	vec3 moon_n = dir - moon_dir;  // falsas crateras
	float craters = 0.75 + 0.25 * texture(cloud_noise, moon_n.xy * 9.0 + 0.5).r;
	float moon_glow = pow(max(cm, 0.0), 60.0) * 0.25;
	float moon_vis = smoothstep(-0.05, 0.08, moon_dir.y) * max(night, 0.15);
	col += moon_color * moon_glow * moon_vis;

	// Nuvens (duas camadas), iluminadas pelo sol ou pela lua.
	float cover = 0.0;
	vec3 cloud_col = vec3(0.0);
	if (up > -0.02) {
		float fade = smoothstep(-0.02, 0.22, up);
		float c1 = cloud_layer(dir, 0.35, wind, cloud_coverage) * fade;
		float c2 = cloud_layer(dir, 0.9, wind * 1.7, cloud_coverage * 0.8) * fade * 0.7;
		cover = clamp(c1 + c2 * (1.0 - c1), 0.0, 1.0);
		float light_amt = mix(0.35, 1.0, sun_vis);
		float silver = pow(max(cs, 0.0), 6.0) * sun_vis * 1.6 + pow(max(cm, 0.0), 10.0) * moon_vis * 0.5;
		cloud_col = mix(cloud_shadow_color, cloud_lit_color, light_amt * (1.0 - c2 * 0.4)) + sun_color * silver;
		cloud_col = mix(cloud_col, horizon, smoothstep(0.25, 0.0, up) * 0.6); // perspectiva aérea
	}
	col = mix(col, cloud_col, cover * 0.92);

	// Disco do sol e da lua por cima das nuvens finas, por baixo das grossas.
	col += sun_color * disc * sun_vis * 25.0 * (1.0 - cover);
	col = mix(col, moon_color * craters * 1.6, moon_disc * moon_vis * (1.0 - cover * 0.8));

	// Corrupção: dessatura e puxa para violeta.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(lum), vec3(0.42, 0.18, 0.84) * lum * 1.6, 0.55), corruption);

	COLOR = col * sky_energy;
}
