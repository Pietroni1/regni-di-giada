shader_type spatial;
// Muri delle Prove del Sigillo. stile 0 = tomba (Cripta): grandi conci consumati, zoccolo umido, fregio a greca
// scolpito che trattiene un filo di luce; stile 1 = fucina (Forgia): basalto a blocchi, fasce di ferro ribattute,
// fessure incandescenti in basso. In alto il muro si perde nel buio (niente soffitto da disegnare).
// `variante` è il tema dell'ala (Cripta.ALI_TEMI): 0 = quello della Prova; 1 ossario (loculi coi teschi), 2 bronzo e
// giada (pannelli lisci, lesene borchiate, filo di giada acceso), 3 lacca rossa (tavole e grata di carta illuminata),
// 4 lamiera (piastre d'acciaio ribattute, tubi di bronzo), 5 scoria (crosta nera piena di crepe accese), 6 camera del
// tesoro (fascia di dischi d'oro), 7 ossidiana (nera, lucida, a faccette).
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.38, 0.36, 0.45);
uniform vec3 fregio : source_color = vec3(0.35, 0.85, 0.7);
uniform float fregio_luce = 0.16;
uniform vec3 brace : source_color = vec3(1.0, 0.36, 0.08);
uniform vec3 origine = vec3(0.0);     // origine dell'istanza: il rumore resta preciso lontano dallo zero
uniform float altezza = 7.0;
uniform int stile = 0;
uniform int variante = 0;
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
	float largo = 2.1;                               // larghezza di un concio in corsi
	bool sfalsa = true;
	if (variante == 1) { corso = 0.6; largo = 1.7; }
	else if (variante == 2) { corso = 1.7; largo = 1.3; sfalsa = false; }
	else if (variante == 3) { corso = 3.4; largo = 0.14; sfalsa = false; }       // tavole verticali
	else if (variante == 4) { corso = 1.6; largo = 1.0; sfalsa = false; }        // piastre quadrate
	vec2 g = vec2(uv.x / (corso * largo), (sopra ? uv.y : y) / corso);
	float riga = floor(g.y);
	if (sfalsa) g.x += h21(vec2(riga, 5.0));
	vec2 f = fract(g);
	float id = h21(vec2(floor(g.x), riga));
	vec2 dm = vec2(min(f.x, 1.0 - f.x) * corso * largo, min(f.y, 1.0 - f.y) * corso);   // metri dalla fuga
	float fuga = smoothstep(0.0, 0.045, min(dm.x, dm.y));
	float lontano = length(VERTEX);
	float vicino = smoothstep(45.0, 12.0, lontano);
	float grana = 0.5 + (rum(uv * 1.1) - 0.5) * 0.8 * smoothstep(70.0, 25.0, lontano) + (rum(uv * 3.6) - 0.5) * 0.5 * smoothstep(26.0, 8.0, lontano);
	vec3 col = colore * (0.68 + 0.5 * id) * (0.72 + 0.56 * grana);
	col = mix(colore * 0.2, col, fuga);
	float h = fuga + grana * 0.3 + id * 0.25;
	vec3 luce = vec3(0.0);
	float ruv = 0.92;
	float spec = 0.2;
	if (variante == 2) { col = colore * (0.86 + 0.2 * id) * (0.86 + 0.28 * grana); col = mix(colore * 0.3, col, fuga); ruv = 0.42; spec = 0.5; }
	else if (variante == 3) { col = colore * (0.7 + 0.55 * id) * (0.8 + 0.4 * rum(vec2(uv.x * 9.0, y * 0.7))); col = mix(colore * 0.25, col, fuga); ruv = 0.45; spec = 0.5; }
	else if (variante == 4) { col = colore * (0.8 + 0.3 * id) * (0.8 + 0.4 * grana); col = mix(colore * 0.3, col, fuga); ruv = 0.5; spec = 0.6; }
	else if (variante == 5) { col *= 0.55; }
	else if (variante == 7) {
		vec2 fc = celle(uv * 0.7 + 7.0);
		col = colore * (0.5 + 1.1 * fract(fc.y * 7.3)) * (0.9 + 0.2 * grana);
		h = fract(fc.y * 7.3) * 0.9;
		ruv = 0.22; spec = 0.8;
	}
	if (!sopra) {
		// zoccolo più scuro e colature dall'alto
		col *= mix(1.0, 0.55, smoothstep(1.2, 0.0, y));
		col *= 1.0 - 0.35 * smoothstep(0.55, 0.9, fbm(vec2(uv.x * 1.3, y * 0.12)));
		if (variante == 1) {
			// ossario: loculi tondi fra 1 e 3,8 m, in molti un teschio; a qualcuno brillano le orbite
			vec2 c = vec2(uv.x / 0.62, (y - 1.0) / 0.62);
			if (c.y > 0.0 && c.y < 4.5) {
				float chi = h21(floor(c) + 31.0);
				vec2 q = (fract(c) - 0.5) * 0.62;
				float d = length(q);
				if (chi > 0.3) {
					float bordo = smoothstep(0.245, 0.23, d) - smoothstep(0.2, 0.185, d);
					float buco = smoothstep(0.2, 0.185, d);
					col = mix(col, colore * 1.35, bordo);
					col = mix(col, vec3(0.018, 0.015, 0.012), buco);
					h = mix(h, 1.5, bordo) - buco * 0.8;
					if (chi > 0.5) {
						float cranio = smoothstep(0.13, 0.115, length(q * vec2(1.0, 0.9) - vec2(0.0, 0.01))) + smoothstep(0.075, 0.06, length(q - vec2(0.0, -0.09)));
						float orbite = smoothstep(0.036, 0.026, length(vec2(abs(q.x) - 0.045, q.y - 0.02)));
						vec3 osso = vec3(0.62, 0.57, 0.45) * (0.75 + 0.4 * grana);
						col = mix(col, osso, clamp(cranio, 0.0, 1.0) * buco);
						col = mix(col, vec3(0.02), orbite * buco);
						if (chi > 0.86) luce = fregio * orbite * buco * (1.2 + 0.6 * sin(TIME * 1.7 + chi * 40.0));
					}
				}
			}
		} else if (variante == 2) {
			// lesene di bronzo borchiate ogni 2,6 m e due fili di giada accesi
			float lx = (fract(uv.x / 2.6) - 0.5) * 2.6;
			if (abs(lx) < 0.17) {
				float rib = smoothstep(0.06, 0.035, length(vec2(lx, (fract(y / 0.5) - 0.5) * 0.5)));
				col = vec3(0.34, 0.23, 0.1) * (0.75 + 0.5 * grana) * (0.7 + 0.6 * smoothstep(0.17, 0.0, abs(lx))) + vec3(0.3, 0.22, 0.1) * rib;
				h = 1.2 + rib;
				ruv = 0.38; spec = 0.7;
			}
			float filo = smoothstep(0.05, 0.03, abs(y - 2.95)) + smoothstep(0.035, 0.02, abs(y - 0.95));
			float rombo = smoothstep(0.02, 0.0, abs(abs(fract(uv.x / 0.65) - 0.5) * 0.65 + abs(y - 2.95) - 0.16) - 0.022);
			float giada = clamp(filo + rombo * step(abs(y - 2.95), 0.2), 0.0, 1.0) * step(0.17, abs(lx));
			col = mix(col, fregio * 0.55, giada);
			luce = fregio * giada * fregio_luce * 3.0 * (0.7 + 0.3 * sin(TIME * 0.9 + uv.x * 0.5));
			h += giada * 0.6;
		} else if (variante == 3) {
			// grata a rombi fra 1,9 e 3,5 m con la carta illuminata dietro, incorniciata d'oro
			float qy = (y - 1.9) / 1.6;
			if (qy > 0.0 && qy < 1.0) {
				float a = abs(fract((uv.x + y) / 0.42) - 0.5) * 0.42;
				float b = abs(fract((uv.x - y) / 0.42) - 0.5) * 0.42;
				float barra = smoothstep(0.03, 0.045, min(a, b));
				float cornice = step(qy, 0.045) + step(0.955, qy);
				float montante = step(abs(fract(uv.x / 2.94) - 0.5) * 2.94, 0.09);
				float carta = barra * (1.0 - cornice) * (1.0 - montante);
				col = mix(colore * 0.35, vec3(0.86, 0.66, 0.4), carta);
				col = mix(col, vec3(0.75, 0.55, 0.18), clamp(cornice, 0.0, 1.0));
				h = (1.0 - carta) * 1.2;
				luce = brace * carta * (0.42 + 0.14 * rum(vec2(uv.x * 0.6 + TIME * 0.25, y * 0.8 + floor(uv.x / 2.94))));
				ruv = mix(0.45, 0.9, carta);
			}
		} else if (variante == 4) {
			// ribattini agli angoli delle piastre, tubi di bronzo ogni 3,2 m, un filo freddo acceso in basso
			float rib = smoothstep(0.06, 0.035, length(dm - 0.13));
			col += vec3(0.1, 0.11, 0.12) * rib;
			h += rib * 1.2;
			float tx = (fract(uv.x / 3.2) - 0.5) * 3.2;
			if (abs(tx) < 0.16 && y < 5.6) {
				float tondo = sqrt(max(0.0, 1.0 - (tx / 0.16) * (tx / 0.16)));
				float fascia = step(abs(fract(y / 1.4) - 0.5) * 1.4, 0.07);
				col = mix(vec3(0.4, 0.26, 0.11), vec3(0.16, 0.13, 0.1), fascia) * (0.35 + 0.9 * tondo) * (0.8 + 0.4 * grana);
				h = tondo * 2.0 + fascia;
				ruv = 0.35; spec = 0.8;
			}
			float neon = smoothstep(0.03, 0.012, abs(y - 0.42)) * step(0.16, abs(tx));
			col = mix(col, fregio * 0.5, neon);
			luce = fregio * neon * (0.9 + 0.3 * sin(TIME * 2.3 + uv.x * 0.8));
			// aloni di vapore: macchie chiare che salgono dai tubi
			col *= 1.0 + 0.25 * smoothstep(0.5, 0.85, fbm(vec2(uv.x * 0.5, y * 0.25 - TIME * 0.03)));
		} else if (variante == 5) {
			// scoria: crepe accese fitte fino a mezza altezza, fuliggine sopra
			vec2 cr = celle(uv * 0.8 + 3.0);
			float vena = smoothstep(0.045, 0.0, cr.x) * smoothstep(5.2, 0.2, y) * smoothstep(0.3, 0.6, fbm(uv * 0.2 + 11.0));
			luce = brace * vena * (2.6 + 1.4 * sin(TIME * 1.5 + cr.y * 20.0));
			col *= 1.0 - 0.7 * vena;
			col *= 1.0 - 0.5 * smoothstep(0.4, 0.8, fbm(uv * 0.35 + 2.0));
			h += fract(cr.y * 5.0) * 0.8;
		} else if (variante == 6) {
			// fascia di dischi d'oro fra 2,6 e 3,3 m
			float qy = y - 2.95;
			if (abs(qy) < 0.36) {
				float d = length(vec2((fract(uv.x / 0.6) - 0.5) * 0.6, qy));
				float disco = smoothstep(0.24, 0.225, d);
				float foro = smoothstep(0.06, 0.07, max(abs((fract(uv.x / 0.6) - 0.5) * 0.6), abs(qy)));
				float bordo = step(0.31, abs(qy));
				col = mix(colore * 0.3, vec3(0.85, 0.62, 0.2) * (0.7 + 0.5 * grana), clamp(disco * foro + bordo, 0.0, 1.0));
				luce = fregio * disco * foro * 0.1;
				h = disco * foro * 1.4 + bordo;
				ruv = 0.4; spec = 0.8;
			}
		} else if (variante == 7) {
			// vene sottili accese dentro il vetro nero
			vec2 cr = celle(uv * 0.35 + 9.0);
			float vena = smoothstep(0.02, 0.0, cr.x) * smoothstep(0.5, 0.75, fbm(uv * 0.15 + 4.0));
			luce = fregio * vena * (0.8 + 0.5 * sin(TIME * 0.8 + cr.y * 12.0));
		} else if (stile == 0) {
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
	ROUGHNESS = ruv;
	SPECULAR = spec;
	EMISSION = luce;
	NORMAL = rilievo(NORMAL, VERTEX, h, 0.035 * vicino);
}
