shader_type spatial;
// Piastre e bordi di armature ed elmi: metallo o lacca con graffi, martellatura leggera, usura chiara sugli spigoli e
// sugli orli, patina negli incavi.
// I completi (usa_orlo) portano due informazioni in più da Blender: la seconda UV «Orlo» (x lungo l'orlo, y distanza
// dall'orlo, in metri) e l'occlusione dipinta nel rosso del colore dei vertici. Con queste si disegnano: orlo consumato,
// doppio filetto, fila di ribattini, fascia col motivo della classe e, sulle lamelle laccate, giunture e allacciature.
// lamelle > 0: larghezza (m) delle lamelle lungo l'orlo (lacca su ferro). oro > 0: riflesso caldo (oro, bronzo).
// grani > 0: grani di una collana (UV della sfera): due solchi incisi e un segno sul davanti.
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"
#include "res://shader/ornati.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.5, 0.5, 0.55);
uniform float metallico = 0.6;
uniform float ruvido = 0.4;
uniform float lamelle = 0.0;
uniform bool usa_orlo = false;
uniform int motivo_classe = -1;
uniform float fascia = 0.0;          // larghezza (m) della fascia col motivo; 0 = nessuna
uniform float ribattini = 0.0;       // passo (m) dei ribattini lungo l'orlo; 0 = nessuno
uniform vec3 laccio : source_color = vec3(0.7, 0.55, 0.25);
uniform float oro = 0.0;
uniform float grani = 0.0;
varying vec3 pl;

void vertex() { pl = VERTEX; }

void fragment() {
	float d = usa_orlo ? 1.0 - UV2.y : 1.0;     // il glTF capovolge la v: 1 - v = metri dall'orlo
	float s = UV2.x;
	float ao = usa_orlo ? clamp(COLOR.r, 0.0, 1.0) : 1.0;
	// superficie: graffi sottili, patina a chiazze, martellatura (poche chiamate di rumore)
	float graffi = rum3(pl * vec3(160.0, 14.0, 160.0)) * 0.5 + rum3(pl * vec3(20.0, 190.0, 20.0)) * 0.5;
	float patina = rum3(pl * 6.0) * 0.65 + rum3(pl * 15.0 + 3.1) * 0.35;
	float lacca = lamelle > 0.0 ? 1.0 : 0.0;
	float martello = rum3(pl * 70.0) * (1.0 - lacca * 0.7);
	float spigolo = clamp(length(fwidth(NORMAL)) * 4.0, 0.0, 1.0);
	vec3 base = colore;
	float h = martello * 0.25 + graffi * 0.15;      // altezza per il rilievo
	float scuro = 0.0;      // solchi e giunture
	float chiaro = 0.0;     // orli consumati, teste dei ribattini
	float laccio_m = 0.0;
	if (usa_orlo) {
		// orlo consumato e doppio filetto parallelo all'orlo
		float orlo = 1.0 - smoothstep(0.002, 0.007, d);
		chiaro += orlo * 0.8;
		float fil = linea(d - 0.010, 0.0009) + linea(d - 0.0145, 0.0007) * 0.8;
		scuro += fil * 0.7;
		h += orlo * 0.6 - fil * 0.5;
		// fila di ribattini a cupola
		if (ribattini > 0.0) {
			float vis_r = 1.0 - smoothstep(0.2, 0.45, fwidth(s / ribattini));
			vec2 q = vec2((fract(s / ribattini) - 0.5) * ribattini, d - 0.022);
			float r = length(q) / 0.0042;
			float cupola = sqrt(max(0.0, 1.0 - r * r)) * vis_r;
			chiaro += smoothstep(0.0, 0.3, cupola) * 0.9;
			scuro += (1.0 - smoothstep(0.9, 1.25, r)) * smoothstep(0.75, 1.0, r) * 0.6 * vis_r;
			h += cupola * 1.5;
		}
		// fascia ornata col motivo della classe (in rilievo, più chiara)
		float orn = fascia_ornata(motivo_classe, s, d, 0.028, fascia);
		scuro += orn * 0.5;          // inciso: solchi scuri, il fondo resta lucido
		h -= orn * 0.7;
		// lamelle: giunture fra le piastrine e allacciature colorate che le tengono insieme
		if (lamelle > 0.0) {
			float x = fract(s / lamelle);
			float vis = 1.0 - smoothstep(0.12, 0.35, fwidth(s / lamelle));     // da lontano le righe fitte si sfumano
			float giu = linea(min(x, 1.0 - x) * lamelle, 0.0009) * vis;
			scuro += giu * 0.5 * step(0.004, d);
			// ogni piastrina: tinta sua e bordi smussati (più scuri verso la giuntura)
			float bev = smoothstep(0.0, 0.3, min(x, 1.0 - x));
			base *= (0.86 + 0.22 * h21(vec2(floor(s / lamelle), floor(pl.y * 15.0)))) * (0.88 + 0.12 * bev);
			h += bev * 0.5 - giu * 0.6;
			float ql = abs(x - 0.5) * lamelle;
			laccio_m = (1.0 - smoothstep(0.002, 0.003, ql)) * step(0.011, d) * (1.0 - step(0.019, d));
			// fori del laccio
			laccio_m = max(laccio_m, 1.0 - smoothstep(0.0025, 0.0035, length(vec2(ql, d - 0.022)))) * vis;
		}
	} else if (lamelle > 0.0) {
		float k = atan(pl.x, pl.z) * 0.2 / lamelle;
		float x = fract(k);
		scuro += (1.0 - smoothstep(0.0, 0.035, min(x, 1.0 - x))) * 0.6;
	}
	if (grani > 0.0) {
		// grano di collana: due solchi attorno e un segno inciso sul davanti
		float v = UV.y;
		scuro += (linea(v - 0.35, 0.025) + linea(v - 0.65, 0.025)) * 0.8;
		float u2 = fract(UV.x * 2.0);
		scuro += linea(length(vec2((u2 - 0.5) * 2.5, v - 0.5)) - 0.12, 0.03) * 0.7;
		h -= scuro * 0.5;
	}
	vec3 col = base * (0.78 + 0.32 * patina) * (0.93 + 0.12 * graffi);
	col = mix(col, base * 1.75 + 0.06 + oro * vec3(0.12, 0.07, 0.0), clamp(spigolo * 0.5 + chiaro, 0.0, 1.0));
	// patina e sporco negli incavi (occlusione dipinta) e a chiazze
	col = mix(col, base * 0.4, smoothstep(0.65, 0.92, patina) * 0.35 + (1.0 - ao) * 0.35);
	col = mix(col, base * 0.22, clamp(scuro, 0.0, 1.0));
	col = mix(col, laccio * (0.4 + 0.2 * patina), laccio_m * 0.8);
	col *= mix(0.45, 1.0, ao);
	ALBEDO = col;
	// lacca: poco metallica e lucida; dove l'orlo è consumato affiora il ferro
	float ferro = lacca * clamp(chiaro, 0.0, 1.0);
	METALLIC = mix(mix(metallico, 0.9, clamp(chiaro, 0.0, 1.0) * (1.0 - lacca)), 0.75, ferro) * (1.0 - laccio_m);
	ROUGHNESS = clamp(ruvido + (graffi - 0.5) * 0.25 + smoothstep(0.6, 0.9, patina) * 0.25 + lacca * 0.06 + laccio_m * 0.4 + (1.0 - ao) * 0.2, 0.06, 1.0);
	SPECULAR = 0.5 - lacca * 0.12 + oro * 0.1;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL = rilievo(NORMAL, VERTEX, h, 0.0035 * (1.0 - lacca * 0.5));
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
