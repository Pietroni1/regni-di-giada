shader_type spatial;
// Terreno dipinto: i pesi dei materiali arrivano da due texture esportate dal server (dati/terreno.bin),
// i colori sono pennellate procedurali (nessuna immagine esterna).
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D pesi_a : filter_linear, repeat_disable;   // secco, bosco, sabbia, terra
uniform sampler2D pesi_b : filter_linear, repeat_disable;   // roccia, neve, lastricato
uniform float meta = 300.0;

varying vec3 pm;   // posizione nel mondo
varying vec3 nm;   // normale nel mondo

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return rum(p) * 0.5 + rum(p * 2.03 + 7.1) * 0.3 + rum(p * 4.1 + 3.7) * 0.2; }
// pennellate: rumore stirato lungo una direzione che cambia piano
float pennello(vec2 p, float scala) {
	float a = rum(p * 0.03) * 6.283;
	vec2 d = vec2(cos(a), sin(a));
	vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
	return rum(q * vec2(0.8, 1.5) * scala) * 0.6 + rum(q * vec2(2.1, 3.3) * scala + 5.0) * 0.4;
}
// ciottoli: celle di Voronoi con fuga scura
vec2 ciottoli(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(h21(i + g), h21(i + g + 17.0)) * 0.8 + 0.1;
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = h21(i + g + 3.0); } else if (d < d2) d2 = d;
	}
	return vec2(d2 - d1, id);
}

vec3 rilievo(vec3 n, vec3 pos, float h, float forza) {
	vec3 dpx = dFdx(pos), dpy = dFdy(pos);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - forza * grad);
}

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = (pm.xz + meta) / (2.0 * meta);
	vec4 a = texture(pesi_a, uv);
	vec4 b = texture(pesi_b, uv);
	vec2 p = pm.xz;
	float grande = fbm(p * 0.045), medio = fbm(p * 0.21), fine = pennello(p, 1.0), finissimo = pennello(p + 31.0, 2.6);
	// da lontano le pennellate fini sfarfallano: si spengono verso un valore medio
	float lontano = smoothstep(35.0, 140.0, length(VERTEX));
	fine = mix(fine, 0.5, lontano);
	finissimo = mix(finissimo, 0.5, lontano);
	float tratto = smoothstep(0.25, 0.75, fine) * 0.6 + finissimo * 0.4;

	// erba: tre toni a chiazze + pennellate
	vec3 erba = mix(vec3(0.13, 0.23, 0.08), vec3(0.22, 0.31, 0.11), smoothstep(0.3, 0.7, grande));
	erba = mix(erba, vec3(0.31, 0.36, 0.14), smoothstep(0.55, 0.85, medio) * 0.5);
	erba *= 0.88 + 0.24 * (fbm(p * 0.9) * 0.6 + tratto * 0.4);
	vec3 secco = mix(vec3(0.50, 0.46, 0.20), vec3(0.66, 0.58, 0.28), tratto) * (0.85 + 0.3 * medio);
	vec3 bosco = mix(vec3(0.10, 0.20, 0.08), vec3(0.20, 0.30, 0.11), tratto) * (0.8 + 0.4 * medio);
	vec3 sabbia = mix(vec3(0.66, 0.58, 0.38), vec3(0.82, 0.74, 0.52), medio) * (0.9 + 0.2 * finissimo);
	vec3 terra = mix(vec3(0.33, 0.25, 0.16), vec3(0.50, 0.39, 0.25), tratto) * (0.85 + 0.3 * medio);
	float venatura = fbm(vec2(pm.x + pm.z, pm.y * 3.0) * 0.35);
	vec3 roccia = mix(vec3(0.24, 0.23, 0.22), vec3(0.46, 0.44, 0.40), venatura) * (0.8 + 0.4 * finissimo);
	vec3 neve = vec3(0.90, 0.92, 0.95) * (0.92 + 0.08 * medio);
	vec2 c = ciottoli(p * 1.7);
	vec3 lastrico = mix(vec3(0.40, 0.37, 0.32), vec3(0.56, 0.52, 0.44), c.y) * (0.92 + 0.16 * medio);
	lastrico = mix(vec3(0.26, 0.24, 0.21), lastrico, smoothstep(0.02, 0.09, c.x));

	float tot = a.r + a.g + a.b + a.a + b.r + b.g + b.b;
	vec3 col = erba * max(0.0, 1.0 - tot);
	col += secco * a.r + bosco * a.g + sabbia * a.b + terra * a.a + roccia * b.r + neve * b.g + lastrico * b.b;

	// fiorellini e trifogli sparsi nell'erba (solo da vicino)
	vec2 gf = p * 2.2, cf = floor(gf);
	float seme = h21(cf);
	float fiore = (1.0 - smoothstep(0.05, 0.11, length(fract(gf) - 0.5 - (vec2(h21(cf + 3.0), h21(cf + 8.0)) - 0.5) * 0.6))) * step(0.86, seme) * (1.0 - lontano);
	vec3 petalo = seme > 0.95 ? vec3(0.95, 0.92, 0.85) : (seme > 0.91 ? vec3(0.95, 0.80, 0.30) : vec3(0.80, 0.55, 0.75));
	col = mix(col, petalo, fiore * max(0.0, 1.0 - tot) * 0.9);
	// muschio nelle fughe del lastricato
	col = mix(col, vec3(0.16, 0.24, 0.10), (1.0 - smoothstep(0.02, 0.07, c.x)) * b.b * smoothstep(0.45, 0.7, grande) * 0.6);

	ALBEDO = col;
	// rilievo: ciottoli bombati, zolle d'erba, venature della roccia (svanisce in lontananza)
	float alt = b.b * smoothstep(0.0, 0.14, c.x) * (0.8 + 0.2 * c.y) + (1.0 - b.b) * (tratto * 0.35 + medio * 0.25) + b.r * venatura * 0.8 + a.a * finissimo * 0.5;
	NORMAL = rilievo(NORMAL, VERTEX, alt, 0.035 * (1.0 - lontano));
	ROUGHNESS = mix(0.95, 0.75, b.b);
	SPECULAR = 0.25;
	// rilievo dei ciottoli: scurisce le fughe e inclina appena la normale
	
}
