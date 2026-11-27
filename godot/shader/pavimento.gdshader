shader_type spatial;
// Pavimento della cripta: grandi lastre di pietra scura con fughe e macchie, calcolate nello spazio del mondo.
render_mode diffuse_burley;

varying vec3 pm;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 g = pm.xz / 2.5;
	float riga = floor(g.y);
	g.x += mod(riga, 2.0) * 0.5;                 // lastre sfalsate
	vec2 f = fract(g);
	float id = h21(floor(g));
	float fuga = smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float macchie = rum(pm.xz * 0.7) * 0.6 + rum(pm.xz * 3.1) * 0.4;
	vec3 c = mix(vec3(0.20, 0.18, 0.19), vec3(0.34, 0.31, 0.30), id) * (0.75 + 0.5 * macchie);
	ALBEDO = mix(vec3(0.03, 0.03, 0.035), c, fuga);
	ROUGHNESS = mix(0.95, 0.6, id * fuga);
	SPECULAR = 0.35;
}
