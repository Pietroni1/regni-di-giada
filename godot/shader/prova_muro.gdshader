shader_type spatial;
// Muri delle Prove del Sigillo. stile 0 = tomba (Cripta): grandi conci consumati, zoccolo umido, fregio a greca
// scolpito che trattiene un filo di luce; stile 1 = fucina (Forgia): basalto a blocchi, fasce di ferro ribattute,
// fessure incandescenti in basso. In alto il muro si perde nel buio (niente soffitto da disegnare).
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.38, 0.36, 0.45);
uniform vec3 fregio : source_color = vec3(0.35, 0.85, 0.7);
uniform float fregio_luce = 0.16;
uniform vec3 brace : source_color = vec3(1.0, 0.36, 0.08);
uniform vec3 origine = vec3(0.0);     // origine dell'istanza: il rumore resta preciso lontano dallo zero
uniform float altezza = 7.0;
uniform int stile = 0;
varying vec3 pm;
varying vec3 nm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - origine;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = piano(pm, nm);
	float y = pm.y;
	bool sopra = abs(nm.y) > 0.7;                    // facce orizzontali (cornici, sommità): niente corsi
	float corso = stile == 0 ? 0.85 : 1.15;
	vec2 g = vec2(uv.x / (corso * 2.1), (sopra ? uv.y : y) / corso);
	float riga = floor(g.y);
	g.x += h21(vec2(riga, 5.0));
	vec2 f = fract(g);
	float id = h21(vec2(floor(g.x), riga));
	float fuga = smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x) * 2.1, min(f.y, 1.0 - f.y)));
	float lontano = length(VERTEX);
	float vicino = smoothstep(45.0, 12.0, lontano);
	float grana = 0.5 + (rum(uv * 1.1) - 0.5) * 0.8 * smoothstep(70.0, 25.0, lontano) + (rum(uv * 3.6) - 0.5) * 0.5 * smoothstep(26.0, 8.0, lontano);
	vec3 col = colore * (0.68 + 0.5 * id) * (0.72 + 0.56 * grana);
	col = mix(colore * 0.2, col, fuga);
	float h = fuga + grana * 0.3 + id * 0.25;
	vec3 luce = vec3(0.0);
	if (!sopra) {
		// zoccolo più scuro e colature dall'alto
		col *= mix(1.0, 0.55, smoothstep(1.2, 0.0, y));
		col *= 1.0 - 0.35 * smoothstep(0.55, 0.9, fbm(vec2(uv.x * 1.3, y * 0.12)));
		if (stile == 0) {
			// fregio a greca fra 2,7 e 3,3 m
			vec2 q = vec2(fract(uv.x / 1.1), (y - 2.7) / 0.6);
			if (q.y > 0.0 && q.y < 1.0) {
				float bordo = step(q.y, 0.1) + step(0.9, q.y);
				float a = step(0.1, q.x) * step(q.x, 0.9) * step(0.24, q.y) * step(q.y, 0.35);
				float b = step(0.79, q.x) * step(q.x, 0.9) * step(0.24, q.y) * step(q.y, 0.76);
				float c = step(0.3, q.x) * step(q.x, 0.9) * step(0.65, q.y) * step(q.y, 0.76);
				float d = step(0.3, q.x) * step(q.x, 0.41) * step(0.45, q.y) * step(q.y, 0.76);
				float e = step(0.3, q.x) * step(q.x, 0.62) * step(0.45, q.y) * step(q.y, 0.55);
				float m = clamp(bordo + a + b + c + d + e, 0.0, 1.0);
				col = mix(mix(colore, fregio, 0.22) * 0.34 * (0.8 + 0.4 * grana), colore * 1.2 * (0.8 + 0.4 * grana), m);
				h = m * 1.4 + grana * 0.2;
				luce = fregio * (1.0 - m) * (1.0 - bordo) * fregio_luce * (0.55 + 0.45 * rum(vec2(uv.x * 0.35 + TIME * 0.15, 3.0)));
			}
		} else {
			// due fasce di ferro con i ribattini
			for (int k = 0; k < 2; k++) {
				float yb = k == 0 ? 1.7 : 5.1;
				float dentro = step(abs(y - yb), 0.16);
				if (dentro > 0.5) {
					float rib = smoothstep(0.075, 0.04, length(vec2((fract(uv.x / 0.55) - 0.5) * 0.55, y - yb)));
					col = vec3(0.075, 0.068, 0.065) * (0.8 + 0.5 * grana) + vec3(0.09, 0.08, 0.07) * rib;
					h = 1.3 + rib * 0.9;
				}
			}
			// fessure incandescenti in basso
			vec2 cr = celle(uv * 0.55 + 3.0);
			float vena = smoothstep(0.035, 0.0, cr.x) * smoothstep(3.2, 0.3, y) * smoothstep(0.42, 0.7, fbm(uv * 0.22 + 11.0));
			luce = brace * vena * (2.2 + 1.2 * sin(TIME * 1.3 + cr.y * 20.0));
			col *= 1.0 - 0.6 * vena;
		}
	}
	// il buio in alto
	col *= 1.0 - 0.85 * smoothstep(altezza * 0.42, altezza, y);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	EMISSION = luce;
	NORMAL = rilievo(NORMAL, VERTEX, h, 0.035 * vicino);
}
