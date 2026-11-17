shader_type spatial;
// Pavimento dell'Arena del Loto Cremisi: anelli di lastre di pietra attorno a un grande loto intarsiato,
// fascia vermiglia al bordo e quattro viali verso le porte. Tutto in coordinate polari attorno a `centro`.
render_mode diffuse_burley;

uniform vec2 centro = vec2(0.0);
uniform float raggio = 58.0;
uniform float porte = 4.0;

varying vec3 pm;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 l = pm.xz - centro;
	float r = length(l);
	float a = atan(l.x, l.y);                       // stessa convenzione delle porte: direzione (sin a, cos a)
	float macchie = rum(l * 0.6 + 5.0) * 0.6 + rum(l * 2.7 + 9.0) * 0.4;
	// lastre: anelli di 2,6 m, ogni anello diviso in conci lunghi circa 3 m
	float anello = floor(r / 2.6);
	float conci = max(6.0, floor(6.283 * (anello + 0.5) * 2.6 / 3.0));
	float u = (a / 6.283 + 0.5) * conci + mod(anello, 2.0) * 0.5;
	float id = h21(vec2(anello, floor(u)));
	float fr = fract(r / 2.6), fu = fract(u);
	float fuga = smoothstep(0.0, 0.03, min(fr, 1.0 - fr)) * smoothstep(0.0, 0.025, min(fu, 1.0 - fu));
	vec3 pietra = mix(vec3(0.46, 0.43, 0.39), vec3(0.62, 0.58, 0.52), id) * (0.82 + 0.3 * macchie);
	vec3 col = mix(vec3(0.16, 0.15, 0.14), pietra, fuga);
	// viali verso le porte: lastre più scure e regolari
	float settore = 6.283 / porte;
	float scarto = abs(mod(a + settore * 0.5, settore) - settore * 0.5) * r;
	float viale = (1.0 - smoothstep(2.4, 3.0, scarto)) * smoothstep(14.0, 16.0, r);
	col = mix(col, mix(vec3(0.30, 0.27, 0.25), vec3(0.40, 0.36, 0.33), id) * fuga, viale * 0.8);
	// loto intarsiato al centro: otto petali vermigli e oro su fondo scuro
	float petali = cos(a * 8.0);
	float bordo_loto = 9.0 + 3.5 * pow(max(petali, 0.0), 0.6);
	float loto = 1.0 - smoothstep(bordo_loto - 0.15, bordo_loto + 0.15, r);
	float dentro = 1.0 - smoothstep(bordo_loto - 1.1, bordo_loto - 0.8, r);
	vec3 rosso = vec3(0.55, 0.08, 0.06) * (0.85 + 0.25 * macchie);
	vec3 oro = vec3(0.85, 0.62, 0.22);
	vec3 col_loto = mix(oro, rosso, dentro);
	col_loto = mix(col_loto, oro * 1.1, 1.0 - smoothstep(2.0, 2.3, r));        // cuore dorato
	col_loto = mix(col_loto, vec3(0.12, 0.08, 0.06), (1.0 - smoothstep(2.5, 2.8, r)) * smoothstep(2.2, 2.5, r));
	col = mix(col, col_loto, loto);
	col = mix(col, vec3(0.20, 0.12, 0.08), (1.0 - smoothstep(0.0, 0.25, abs(r - 14.0))));   // anello di bronzo
	// fascia vermiglia al bordo: dice dove finisce il pavimento
	float fascia = smoothstep(raggio - 3.2, raggio - 3.0, r) * (1.0 - smoothstep(raggio - 1.4, raggio - 1.2, r));
	col = mix(col, vec3(0.50, 0.10, 0.07) * (0.85 + 0.3 * macchie), fascia);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.55, loto * dentro);
	SPECULAR = 0.3;
}
