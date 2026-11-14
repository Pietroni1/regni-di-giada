shader_type spatial;
// Tronchi: l'atlante ha 4 colonne (pino, ciliegio, acero/cespuglio, bambù).
render_mode diffuse_burley;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	int c = int(floor(clamp(UV.x, 0.0, 0.999) * 4.0));
	vec3 base = c == 0 ? vec3(0.29, 0.20, 0.16) : c == 1 ? vec3(0.37, 0.18, 0.15) : c == 2 ? vec3(0.37, 0.32, 0.27) : vec3(0.37, 0.56, 0.21);
	float righe = rum(vec2(UV.x * 90.0, UV.y * 5.0));
	float nodi = c == 3 ? smoothstep(0.92, 1.0, fract(UV.y * 6.0)) : 0.0;
	ALBEDO = base * (0.7 + 0.6 * righe) * (1.0 - nodi * 0.5);
	ROUGHNESS = c == 3 ? 0.55 : 0.95;
}
