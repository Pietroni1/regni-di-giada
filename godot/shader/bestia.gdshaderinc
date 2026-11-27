// Mantello dipinto delle bestie dei mostri (tools/blender/mostri.py): ogni parte ha il suo colore (casella in UV.x),
// occlusione dipinta (UV2.y) e curvatura (UV.y, 0,5 = piatto) scuriscono gli incavi e schiariscono gli spigoli;
// sopra, il disegno del mantello calcolato nello spazio del modello: dorso scuro, ventre chiaro, ciuffi, strisce, sella.
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.45, 0.43, 0.42);     // pelo
uniform vec3 ventre : source_color = vec3(0.0);                   // nero = ricavato dal pelo
uniform vec3 criniera : source_color = vec3(0.0);                 // nero = pelo più scuro
uniform vec3 scuro : source_color = vec3(0.08, 0.06, 0.06);       // naso, zoccoli, arcata della scimmia
uniform vec3 occhi : source_color = vec3(0.95, 0.65, 0.15);
uniform float occhi_luce = 1.6;                                   // gli occhi dei mostri brillano
uniform vec3 zanne : source_color = vec3(0.86, 0.8, 0.66);
uniform vec3 interno : source_color = vec3(0.45, 0.2, 0.2);
uniform vec3 faccia : source_color = vec3(0.78, 0.45, 0.4);
uniform vec3 cristallo : source_color = vec3(0.3, 0.9, 0.6);
uniform vec3 metallo : source_color = vec3(0.32, 0.33, 0.36);
uniform vec3 artigli : source_color = vec3(0.12, 0.1, 0.09);
uniform float strisce = 0.0;       // mantello tigrato
uniform float sella = 0.0;         // sella scura sul dorso (lupi del branco, sciacalli)
uniform float mezzaluna = 0.0;     // mezzaluna chiara sul petto (orso)
uniform vec3 segni : source_color = vec3(0.05, 0.04, 0.04);      // colore di strisce e sella
uniform float segni_luce = 0.0;    // le strisce brillano (tigri spettrali, élite)
uniform float ventre_luce = 0.0;   // il ventre brilla (orso dal ventre di giada)
uniform float usa_ombre = 1.0;     // 0 per i modelli senza occlusione dipinta

varying vec3 pl;
varying vec3 nl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

// colore della parte; pelo = quanto è mantello (0 per denti, occhi, metallo...); em = luce propria
vec3 colore_parte(float slot, out float pelo, out vec3 em, out float rough, out float metal) {
	pelo = 0.0;
	em = vec3(0.0);
	rough = 0.9;
	metal = 0.0;
	vec3 v = ventre.r + ventre.g + ventre.b > 0.0 ? ventre : colore * 1.45 + 0.06;
	vec3 cr = criniera.r + criniera.g + criniera.b > 0.0 ? criniera : colore * 0.6;
	if (slot < 0.5) { pelo = 1.0; return colore; }
	if (slot < 1.5) { pelo = 0.6; em = v * ventre_luce; return v; }
	if (slot < 2.5) { rough = 0.6; return scuro; }
	if (slot < 3.5) { em = occhi * occhi_luce; rough = 0.2; return occhi; }
	if (slot < 4.5) { rough = 0.4; return zanne; }
	if (slot < 5.5) { pelo = 1.3; return cr; }
	if (slot < 6.5) { rough = 0.5; return interno; }
	if (slot < 7.5) { pelo = 0.15; rough = 0.7; return faccia; }
	if (slot < 8.5) { em = cristallo * 1.4; rough = 0.15; return cristallo; }
	if (slot < 9.5) { rough = 0.35; metal = 0.8; return metallo; }
	rough = 0.45;
	return artigli;
}

// colore, luce propria, ruvidità e metallo del mantello; restituisce quanto è «segno» (strisce o sella)
float mantello(vec2 uv, vec2 uv2, out vec3 alb, out vec3 emi, out float rough, out float metal) {
	float slot = floor(uv.x * 16.0);
	float pelo;
	vec3 c = colore_parte(slot, pelo, emi, rough, metal);
	float sopra = smoothstep(-0.5, 0.7, nl.y);
	float ciuffi = rum(vec2(pl.x * 26.0 + pl.y * 9.0, pl.z * 5.0)) * 0.6 + rum(pl.xz * 60.0) * 0.4;
	float segno = 0.0;
	if (pelo > 0.0) {
		float p1 = min(pelo, 1.0);
		// dorso più scuro, ventre più chiaro, ciuffi a pennellate
		c = mix(c, c * mix(1.18, 0.78, sopra), p1);
		c *= 1.0 - pelo * 0.28 + pelo * 0.36 * ciuffi;
		// strisce a bande trasversali che si piegano sui fianchi e si spezzano, più fitte sulle zampe
		float onda = sin(pl.z * 24.0 + abs(pl.x) * 9.0 + fbm(pl.zy * 4.0) * 5.0 + pl.y * 3.0);
		float tig = smoothstep(0.55, 0.85, onda) * step(0.32, rum(vec2(pl.z * 6.0, pl.y * 9.0 + abs(pl.x) * 4.0))) * smoothstep(-0.6, 0.2, nl.y) * strisce;
		float sel = smoothstep(0.25, 0.75, nl.y + 0.25 * rum(pl.xz * 9.0)) * smoothstep(-0.55, -0.1, pl.z) * smoothstep(0.75, 0.2, pl.z) * sella;
		segno = clamp(tig + sel, 0.0, 1.0) * p1;
		c = mix(c, segni, segno * 0.88);
		// mezzaluna chiara sul petto dell'orso (il muso guarda verso +z)
		float ml = mezzaluna * smoothstep(0.05, 0.0, abs(length(vec2(pl.x * 1.2, pl.y - 0.98)) - 0.2)) * step(0.45, pl.z) * step(pl.y, 0.94) * smoothstep(0.1, 0.5, nl.z);
		c = mix(c, vec3(0.86, 0.82, 0.7), ml * p1);
		emi += segni * segni_luce * segno;
	}
	// occlusione dipinta e curvatura: incavi più scuri, spigoli più chiari
	float ao = mix(1.0, uv2.y, usa_ombre);
	float cv = (uv.y - 0.5) * 2.0 * usa_ombre;
	c *= (0.45 + 0.55 * ao) * (1.0 + 0.16 * cv);
	alb = c;
	return segno;
}
