shader_type spatial;
// Fusto dell'obelisco: pietra dipinta a pennellate, fasce di rune incise che brillano e pulsano verso l'alto,
// vene di luce sugli spigoli smussati e crepe che si accendono man mano che il monolite si danneggia.
// Le coordinate arrivano dalla malla: UV.x = posizione sulla faccia (0-1), UV.y = quota in metri;
// COLOR.r = 1 faccia larga / 0 spigolo smussato, COLOR.g = numero della faccia (seme dei glifi).
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 pietra : source_color = vec3(0.30, 0.28, 0.33);
uniform vec3 energia : source_color = vec3(0.7, 0.3, 1.0);
uniform float luce = 1.0;        // forza delle rune (include il lampeggio)
uniform float danno = 0.0;       // 0 integro → 1 sul punto di cedere
uniform float pulso = 0.0;       // impulso dell'ondata: 1 → 0, l'onda di luce sale lungo il fusto
uniform float colpo = 0.0;       // lampo del colpo ricevuto: 1 → 0
uniform float fascia_max = 4.2;  // quota oltre cui non ci sono più fasce di rune (inizio cuspide)

varying vec3 vc;
varying vec2 uv0;

float h11(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
	return smoothstep(w, w * 0.35, length(pa - ba * h));
}
// Glifo calligrafico: qualche tratto fra i punti di una griglia 3x3, più un'asta e un punto.
float glifo(vec2 p, float s) {
	float v = 0.0;
	float xa = (floor(h11(s) * 3.0) - 1.0) * 0.22;
	v += seg(p, vec2(xa, -0.42), vec2(xa, 0.42), 0.085) * step(0.35, h11(s + 0.5));
	for (int i = 0; i < 3; i++) {
		float q = s * 3.1 + float(i) * 7.7;
		vec2 a = (vec2(floor(h11(q) * 3.0), floor(h11(q + 1.0) * 3.0)) - 1.0) * vec2(0.22, 0.21);
		vec2 b = (vec2(floor(h11(q + 2.0) * 3.0), floor(h11(q + 3.0) * 3.0)) - 1.0) * vec2(0.22, 0.21);
		v += seg(p, a, b, 0.08) * step(0.2, distance(a, b));
	}
	vec2 pt = (vec2(h11(s + 9.0), h11(s + 11.0)) - 0.5) * 0.7;
	v += smoothstep(0.075, 0.03, length(p - pt)) * step(0.5, h11(s + 13.0));
	return clamp(v, 0.0, 1.0);
}

void vertex() {
	vc = COLOR.rgb;
	uv0 = UV;
}

void fragment() {
	float y = uv0.y;
	float u = uv0.x;
	float largo = step(0.5, vc.r);
	float sem = vc.g;

	// pietra dipinta: toni a macchie, pennellate chiare, spigoli consumati, tinta d'energia in basso
	float gr = fbm(vec2(u * 2.5 + sem * 9.0, y * 4.0));
	float vene = fbm(vec2(u * 7.0 + sem * 3.0, y * 0.8));
	vec3 col = pietra * (0.62 + 0.6 * gr) * (0.85 + 0.3 * vene);
	col += pietra * 0.25 * smoothstep(0.62, 0.8, fbm(vec2(u * 1.5 + sem * 5.0, y * 11.0)));
	float bordo = min(u, 1.0 - u);
	col += pietra * 0.55 * smoothstep(0.09, 0.0, bordo) * (0.5 + gr);
	col *= mix(1.18, 1.0, largo);
	float piede = smoothstep(1.7, 0.5, y) * smoothstep(0.35, 0.75, fbm(vec2(u * 3.0 + sem * 4.0, y * 2.5)));
	col = mix(col, energia * 0.22 + pietra * 0.3, piede * 0.55);

	// fasce di rune: ogni fascia ha due glifi per faccia larga, incorniciati da due linee
	float k = (y - 0.95) / 1.05;
	float bi = floor(k);
	float bf = fract(k);
	float dentro = step(0.0, k) * step(y, fascia_max);
	float cinta = smoothstep(0.0, 0.04, bf) * (1.0 - smoothstep(0.66, 0.70, bf)) * dentro;
	float cu = u * 2.0;
	float ci = floor(cu);
	vec2 pc = vec2((fract(cu) - 0.5) * 0.9, bf / 0.68 - 0.5);
	float g = glifo(pc * 1.15, bi * 13.0 + ci * 5.0 + sem * 37.0) * cinta * largo;
	float cornice = (smoothstep(0.03, 0.0, abs(bf - 0.015)) + smoothstep(0.03, 0.0, abs(bf - 0.685))) * dentro * 0.7;
	float vena = (1.0 - largo) * smoothstep(0.07, 0.02, abs(u - 0.5)) * step(0.4, fract(y * 2.2 - TIME * 0.5 + sem * 3.0)) * step(0.5, y) * step(y, fascia_max + 0.2);
	float cuspide = step(fascia_max + 0.3, y) * smoothstep(0.05, 0.0, abs(u - 0.5)) * largo;
	float rune = clamp(g + cornice + vena * 0.6 + cuspide * 0.8, 0.0, 1.0);

	// pulsazione che sale e onda dell'ondata
	float onda = 0.5 + 0.5 * sin(y * 2.4 - TIME * 1.8 + sem * 6.0);
	float fronte = (1.0 - pulso) * (fascia_max + 1.5);
	float dist = (y - fronte) * 1.6;
	float scia = exp(-dist * dist) * step(0.001, pulso) * 3.0;
	float inten = luce * (0.5 + 0.9 * onda * onda) + scia;

	// crepe: celle di Voronoi che si aprono una dopo l'altra al crescere del danno
	vec2 cc = vec2(u * 1.4 + sem * 7.3, y * 1.15) * 1.7;
	cc += (vec2(fbm(cc * 2.1), fbm(cc * 2.1 + 9.0)) - 0.5) * 0.55;
	vec2 ce = celle(cc);
	float linea = smoothstep(0.075, 0.0, ce.x);
	float visto = smoothstep(ce.y - 0.03, ce.y + 0.03, danno * 1.05);
	float crepa = linea * visto * step(0.3, y);

	col *= 1.0 - g * 0.65;
	col *= 1.0 - smoothstep(0.16, 0.0, ce.x) * visto * 0.5;
	col = mix(col, vec3(0.02), crepa * 0.8);

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 calda = mix(energia, vec3(1.0, 0.9, 0.7), 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	EMISSION = energia * rune * inten * 1.7
		+ calda * crepa * (1.2 + 2.2 * danno) * (0.7 + 0.3 * onda) * luce
		+ energia * rim * 0.25 * luce
		+ energia * colpo * (0.12 + 0.5 * rune);
	NORMAL = rilievo(NORMAL, VERTEX, gr * 0.4 + vene * 0.2 - g * 0.9 - crepa * 0.9 - cornice * 0.4, 0.07);
}
