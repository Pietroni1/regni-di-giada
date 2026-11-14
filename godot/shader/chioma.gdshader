shader_type spatial;
// Chiome di alberi e cespugli: le UV dei modelli puntano a un atlante 2×2 (ciliegio, pino / acero, foglie);
// qui l'atlante è disegnato dallo shader. Ondeggiano col vento.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform float soglia = 0.42;

varying vec3 tinta;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void vertex() {
	tinta = COLOR.rgb;
	vec3 pi = MODEL_MATRIX[3].xyz;
	float hh = max(0.0, VERTEX.y) / 6.0;
	float sw = sin(TIME * 1.2 + pi.x * 0.21 + pi.z * 0.17) * 0.16 + sin(TIME * 3.3 + VERTEX.x * 1.7 + VERTEX.z * 1.3) * 0.05;
	VERTEX.x += sw * hh;
	VERTEX.z += sw * 0.6 * hh;
}

void fragment() {
	vec2 q = floor(clamp(UV, 0.0, 0.999) * 2.0);
	vec2 l = fract(UV * 2.0);
	int specie = int(q.x) + int(q.y) * 2;   // 0 ciliegio, 1 pino, 2 acero, 3 foglie
	// foglie: celle sparse dentro un disco
	float fitte = specie == 1 ? 13.0 : 9.0;
	vec2 g = l * fitte, i = floor(g), f = fract(g);
	float d = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 c = vec2(h21(i + o), h21(i + o + 9.0));
		vec2 r = o + c - f;
		if (specie == 1) r.x *= 2.4;          // aghi: macchie strette
		float dd = length(r);
		if (dd < d) { d = dd; id = h21(i + o + 5.0); }
	}
	float disco = 1.0 - smoothstep(0.36, 0.47, length((l - 0.5) * vec2(1.0, 1.08)));
	float alfa = (1.0 - smoothstep(0.30, 0.52, d)) * disco;
	float luce = 1.08 - l.y * 0.5;
	vec3 col;
	if (specie == 0) col = mix(vec3(0.88, 0.45, 0.60), vec3(1.0, 0.86, 0.91), id);
	else if (specie == 1) col = mix(vec3(0.10, 0.24, 0.13), vec3(0.34, 0.54, 0.26), id);
	else if (specie == 2) col = mix(vec3(0.66, 0.16, 0.09), vec3(0.94, 0.60, 0.18), id);
	else col = mix(vec3(0.22, 0.42, 0.14), vec3(0.42, 0.62, 0.22), id);
	ALBEDO = col * luce * tinta * (1.0 - smoothstep(0.1, 0.5, d) * 0.35);
	ALPHA = alfa;
	ALPHA_SCISSOR_THRESHOLD = soglia;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = col * 0.35;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
