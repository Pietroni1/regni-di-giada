shader_type spatial;
// Pavimenti delle Prove del Sigillo, uno per stanza. La mesh porta: UV = metri dal centro della stanza,
// UV2 = mezza larghezza e mezza profondità, COLOR.r = tipo (0 corridoio, 0.2 sala, 0.4 bivio, 0.6 boss, 0.8 ponte o
// passerella, 1.0 tesoro), COLOR.gba = colore del segno della stanza.
// stile 0 = tomba: lastre consumate, fascia intarsiata lungo i muri, medaglione al centro delle sale (nella sala del
// boss un grande sigillo che pulsa); stile 1 = fucina: piastre di basalto incorniciate di ferro, vene di brace.
// `motivo` è il tema dell'ala (Cripta.ALI_TEMI): 0 = quello della Prova; 1 lastre irregolari su terra battuta (ossario),
// 2 scacchi diagonali lucidi (bronzo e giada, tesoro), 3 assito laccato, 4 lamiera rigata con ribattini, 5 crosta di
// scoria piena di crepe accese, 6 ossidiana a faccette. `emblema` è il disegno al centro delle sale: 0 stella a petali,
// 1 ruota dentata, 2 luna, 3 sigillo (due quadrati intrecciati), 4 sole a raggi.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.30, 0.28, 0.33);
uniform vec3 brace : source_color = vec3(1.0, 0.36, 0.08);
uniform int stile = 0;
uniform int motivo = 0;
uniform int emblema = 0;
varying vec3 pm;

void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float anello(float r, float R, float w) { return smoothstep(w, w * 0.35, abs(r - R)); }

// Il disegno al centro della sala: p in metri dal centro, R il raggio. Restituisce quanto il punto è «segno» (0-1).
float disegno(vec2 p, float R) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	float m;
	if (emblema == 1) {
		// ruota dentata: dodici denti, sei razze, mozzo
		float denti = step(0.5, fract(ang / 6.2832 * 12.0)) * step(R * 0.84, r) * step(r, R);
		float razze = step(abs(sin(ang * 3.0)), 0.13) * step(R * 0.24, r) * step(r, R * 0.78);
		m = denti + razze + anello(r, R * 0.8, 0.09) + anello(r, R * 0.24, 0.07) + step(r, R * 0.09);
	} else if (emblema == 2) {
		// luna: una falce dentro un cerchio, tre stelle
		float falce = step(r, R * 0.7) * step(R * 0.6, length(p - vec2(R * 0.3, -R * 0.08)));
		float stelle = 0.0;
		for (int i = 0; i < 3; i++) {
			vec2 q = p - R * vec2(0.36 + 0.14 * float(i), -0.3 + 0.3 * float(i));
			stelle += step(abs(q.x) + abs(q.y), R * (0.07 - 0.012 * float(i)));
		}
		m = falce + stelle + anello(r, R, 0.07) + anello(r, R * 0.9, 0.03);
	} else if (emblema == 3) {
		// sigillo: due quadrati intrecciati, cerchio e punto
		float q1 = max(abs(p.x), abs(p.y));
		float q2 = (abs(p.x) + abs(p.y)) * 0.7071;
		m = anello(q1, R * 0.66, 0.07) + anello(q2, R * 0.66, 0.07) + anello(r, R * 0.36, 0.05) + step(r, R * 0.1) + anello(r, R, 0.07);
	} else if (emblema == 4) {
		// sole: dodici raggi, lunghi e corti alternati
		float k = fract(ang / 6.2832 * 12.0);
		float punta = 1.0 - abs(k - 0.5) * 2.0;
		float lungo = mod(floor(ang / 6.2832 * 12.0), 2.0);
		float raggio = step(r, R * (0.42 + (0.5 - 0.16 * lungo) * punta * punta)) * step(R * 0.34, r);
		m = raggio + anello(r, R * 0.3, 0.06) + step(r, R * 0.14) + anello(r, R, 0.05);
	} else {
		float petali = smoothstep(0.02, 0.0, abs(cos(ang * 4.0)) * 0.5 + 0.55 - r / R) * step(r, R * 0.92);
		float cerchi = anello(r, R, 0.07) + anello(r, R * 0.92, 0.04) + anello(r, R * 0.42, 0.05);
		float tacche = step(0.82, fract(ang / 6.2832 * 24.0)) * step(abs(r - R * 0.96), R * 0.04);
		m = cerchi + petali + tacche;
	}
	return clamp(m, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV;
	vec2 hs = floor(UV2 * 2.0 + 0.5) * 0.5;       // arrotondato: l'interpolazione lo sporca di un niente, e dentro h21 quel niente diventa righe
	float tipo = COLOR.r;
	vec3 segno = COLOR.gba;
	float bordo = min(hs.x - abs(p.x), hs.y - abs(p.y));          // metri dal muro più vicino
	bool lungo_z = hs.y > hs.x;
	vec3 col;
	float h = 0.0;
	vec3 luce = vec3(0.0);
	float ruv = 0.9;
	// il rumore fine si spegne con la distanza; il rilievo delle fughe si calcola dalle coordinate (inclina, più sotto)
	float lontano = length(VERTEX);
	float grana = 0.5 + (rum(p * 0.8 + hs) - 0.5) * 0.85 * smoothstep(60.0, 18.0, lontano) + (rum(p * 2.7) - 0.5) * 0.45 * smoothstep(22.0, 6.0, lontano);
	vec2 inclina = vec2(0.0);
	if (tipo > 0.7 && tipo < 0.9) {
		// ponte o passerella: tavoloni di pietra (tomba) o grata di ferro sopra la lava (fucina)
		float lungo = lungo_z ? p.y : p.x, trav = lungo_z ? p.x : p.y, mezza = lungo_z ? hs.x : hs.y;
		float asse = fract(lungo / 1.25);
		float fuga = smoothstep(0.0, 0.05, min(asse, 1.0 - asse));
		float smusso = smoothstep(0.1, 0.0, min(asse, 1.0 - asse)) * (asse < 0.5 ? 1.0 : -1.0);
		inclina = lungo_z ? vec2(0.0, smusso) : vec2(smusso, 0.0);
		float id = h21(vec2(floor(lungo / 1.25), 2.0));
		if (stile == 1) {
			float barra = smoothstep(0.0, 0.08, abs(fract(trav / 0.5) - 0.5) - 0.2);
			col = vec3(0.085, 0.075, 0.07) * (0.7 + 0.6 * grana) * (0.8 + 0.4 * id);
			luce = brace * (1.0 - fuga) * 1.6 + brace * (1.0 - barra) * 0.5 * smoothstep(0.3, 1.2, mezza - abs(trav));
			col *= mix(0.4, 1.0, barra);
			h = fuga + barra * 0.6;
			ruv = 0.55;
		} else {
			col = colore * (0.7 + 0.5 * id) * (0.7 + 0.6 * grana);
			col = mix(colore * 0.15, col, fuga);
			h = fuga + grana * 0.4;
		}
		float cordolo = smoothstep(0.5, 0.35, mezza - abs(trav));
		col = mix(col, (stile == 1 ? vec3(0.06, 0.055, 0.05) : colore * 0.55), cordolo);
	} else {
		// lastre: nei corridoi corrono per il lungo, nelle sale sono quadrate
		vec2 passo = tipo < 0.1 ? (lungo_z ? vec2(1.5, 3.0) : vec2(3.0, 1.5)) : vec2(2.4, 2.4);
		vec2 g = p / passo;
		if (tipo < 0.1) { if (lungo_z) g.y += mod(floor(g.x), 2.0) * 0.5; else g.x += mod(floor(g.y), 2.0) * 0.5; }
		vec2 f = fract(g);
		float id = h21(floor(g) + hs);
		float fuga = smoothstep(0.0, 0.03, min(min(f.x, 1.0 - f.x) * passo.x, min(f.y, 1.0 - f.y) * passo.y) / 2.4);
		vec2 dm = min(f, 1.0 - f) * passo;                       // metri dalla fuga più vicina, per asse
		inclina = vec2(smoothstep(0.12, 0.0, dm.x) * (f.x < 0.5 ? 1.0 : -1.0), smoothstep(0.12, 0.0, dm.y) * (f.y < 0.5 ? 1.0 : -1.0));
		col = colore * (0.72 + 0.45 * id) * (0.68 + 0.64 * grana);
		bool fascia = true;                                     // la fascia intarsiata lungo i muri
		if (motivo == 1) {
			// ossario: lastre irregolari affondate nella terra, schegge d'osso
			vec2 cr = celle(p * 0.6 + hs);
			fuga = smoothstep(0.02, 0.09, cr.x);
			col = colore * (0.6 + 0.6 * fract(cr.y * 9.7)) * (0.6 + 0.8 * grana);
			float osso = step(0.965, h21(floor(p * 3.5) + hs)) * smoothstep(0.3, 0.1, length(fract(p * 3.5) - 0.5));
			col = mix(col, vec3(0.6, 0.55, 0.43), osso * fuga);
			inclina = vec2(0.0);
			h = fuga + grana * 0.6;
			ruv = 0.97;
			fascia = false;
			col = mix(vec3(0.05, 0.04, 0.03) * (0.6 + 0.8 * grana), col, fuga);
			fuga = 1.0;
		} else if (motivo == 2) {
			// scacchi diagonali lucidi, filetti di bronzo
			vec2 q = vec2(p.x + p.y, p.x - p.y) / 2.26;
			vec2 fq = fract(q);
			float scuro = mod(floor(q.x) + floor(q.y), 2.0);
			float filetto = smoothstep(0.0, 0.03, min(min(fq.x, 1.0 - fq.x), min(fq.y, 1.0 - fq.y)) * 1.6);
			col = mix(colore * 1.25, colore * 0.42, scuro) * (0.85 + 0.3 * grana);
			col = mix(vec3(0.42, 0.29, 0.12), col, filetto);
			inclina = vec2(0.0);
			h = filetto;
			ruv = 0.28;
			fuga = 1.0;
		} else if (motivo == 3) {
			// assito laccato: tavole per il lungo, giunte sfalsate, chiodi
			float lungo = lungo_z ? p.y : p.x, trav = lungo_z ? p.x : p.y;
			float n = floor(trav / 0.44);
			float ft = fract(trav / 0.44);
			float fl = fract(lungo / 3.6 + h21(vec2(n, 3.0)));
			float giunta = smoothstep(0.0, 0.035, min(ft, 1.0 - ft) * 0.44) * smoothstep(0.0, 0.006, min(fl, 1.0 - fl));
			float vena = rum(vec2(lungo * 0.7 + n * 3.1, trav * 7.0));
			col = colore * (0.75 + 0.5 * h21(vec2(n, floor(lungo / 3.6 + h21(vec2(n, 3.0)))))) * (0.75 + 0.5 * vena);
			float chiodo = smoothstep(0.03, 0.018, length(vec2((abs(fl - 0.5) - 0.47) * 3.6, (ft - 0.5) * 0.44)));
			col = mix(col, vec3(0.55, 0.4, 0.15), chiodo);
			float sm = smoothstep(0.05, 0.0, min(ft, 1.0 - ft) * 0.44) * (ft < 0.5 ? 1.0 : -1.0);
			inclina = lungo_z ? vec2(sm, 0.0) : vec2(0.0, sm);
			h = giunta;
			ruv = 0.42;
			fuga = giunta;
		} else if (motivo == 4) {
			// lamiera: piastre con ribattini e rigatura a spina
			float rib = smoothstep(0.07, 0.04, length(dm - 0.16));
			float riga = smoothstep(0.035, 0.02, abs(fract((p.x + (mod(floor(p.y / 0.3), 2.0) < 0.5 ? p.y : -p.y)) / 0.3) - 0.5) * 0.3 - 0.02) * step(0.3, min(dm.x, dm.y));
			col = colore * (0.8 + 0.3 * id) * (0.8 + 0.4 * grana) * (1.0 + 0.35 * riga) + vec3(0.12, 0.13, 0.14) * rib;
			h = riga * 0.6 + rib;
			ruv = 0.42;
		} else if (motivo == 5) {
			// scoria: crosta nera, crepe accese fitte
			vec2 cr = celle(p * 0.7 + hs * 3.0);
			float vena = smoothstep(0.05, 0.0, cr.x) * smoothstep(0.35, 0.65, fbm(p * 0.13 + hs));
			col = colore * (0.5 + 0.7 * fract(cr.y * 5.3)) * (0.7 + 0.6 * grana);
			luce = brace * vena * (2.0 + 1.2 * sin(TIME * 1.2 + cr.y * 17.0));
			col *= 1.0 - 0.6 * vena;
			inclina = vec2(0.0);
			h = fract(cr.y * 5.3);
			ruv = 0.8;
			fuga = 1.0;
			fascia = false;
		} else if (motivo == 6) {
			// ossidiana: faccette lucide, vene di brace rade
			vec2 cr = celle(p * 0.5 + hs);
			col = colore * (0.5 + 1.2 * fract(cr.y * 7.3));
			float vena = smoothstep(0.025, 0.0, cr.x) * smoothstep(0.5, 0.75, fbm(p * 0.2 + hs));
			luce = brace * vena * 1.4;
			inclina = vec2(0.0);
			ruv = 0.2;
			fuga = 1.0;
		} else if (stile == 1) {
			// cornice di ferro attorno a ogni piastra e vene di brace rade
			float cornice = smoothstep(0.06, 0.1, min(min(f.x, 1.0 - f.x) * passo.x, min(f.y, 1.0 - f.y) * passo.y));
			col = mix(vec3(0.07, 0.062, 0.058), col, cornice);
			vec2 cr = celle(p * 0.45 + hs * 3.0);
			float vena = smoothstep(0.03, 0.0, cr.x) * smoothstep(0.55, 0.78, fbm(p * 0.16 + hs));
			luce = brace * vena * (1.6 + 0.9 * sin(TIME * 1.1 + cr.y * 17.0));
			col *= 1.0 - 0.5 * vena;
			h = cornice * 0.6 + grana * 0.4;
			ruv = mix(0.5, 0.9, cornice);
		} else {
			h = fuga + grana * 0.35 + id * 0.2;
			// crepe e polvere
			float crepa = smoothstep(0.02, 0.0, celle(p * 0.3 + hs).x) * smoothstep(0.5, 0.75, fbm(p * 0.21 + 5.0));
			col *= 1.0 - 0.6 * crepa;
		}
		col = mix(colore * 0.14, col, fuga);
		if (tipo > 0.1) {
			// fascia intarsiata a 0,8-1,5 m dai muri
			float fb = smoothstep(0.0, 0.05, bordo - 0.8) * smoothstep(0.0, 0.05, 1.5 - bordo) * (fascia ? 1.0 : 0.0);
			float filo = anello(bordo, 0.86, 0.05) + anello(bordo, 1.44, 0.05);
			float lungo = abs(hs.x - abs(p.x) - bordo) < 0.001 ? p.y : p.x;
			float dente = step(0.5, fract(lungo / 0.7)) * step(abs(bordo - 1.15), 0.14);
			col = mix(col, colore * 0.5, fb * 0.7);
			col = mix(col, segno * 0.5 + colore * 0.5, clamp(filo + dente, 0.0, 1.0) * fb);
			luce += segno * clamp(filo, 0.0, 1.0) * fb * 0.12;
			h += (filo + dente) * fb * 0.7;
			// medaglione al centro
			float r = length(p);
			float R = min(hs.x, hs.y) * (tipo > 0.5 && tipo < 0.7 ? 0.62 : 0.4);
			if (r < R * 1.15) {
				float m = disegno(p, R);
				col = mix(col * 0.85, segno * 0.3 + colore * 0.75, m);
				h += m * 0.8;
				float forza = tipo > 0.5 && tipo < 0.7 ? 0.34 + 0.16 * sin(TIME * 1.4 - r * 0.6) : 0.1;
				luce += segno * m * forza;
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = ruv;
	SPECULAR = ruv < 0.5 ? 0.6 : 0.3;
	EMISSION = luce;
	// le lastre hanno gli spigoli smussati: la normale si piega verso la fuga (h serve solo a chi vuole più rilievo)
	vec3 nw = normalize(vec3(-inclina.x * 0.8, 1.0, -inclina.y * 0.8) + vec3(0.0, h * 0.0, 0.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
