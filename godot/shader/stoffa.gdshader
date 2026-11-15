shader_type spatial;
// Stoffa dei vestiti: trama fine del tessuto, chiazze di tinta stesa a mano.
// cuoio = 1: cuoio conciato (grana, macchie scure, un filo di lucentezza sulle parti consumate, cuciture lungo gli orli).
// piume = 1: penne scure (barbe lungo la penna, nella UV dei pezzi costruiti).
// I completi (usa_orlo) leggono la seconda UV «Orlo» (x lungo l'orlo, y distanza, in metri) e l'occlusione dipinta (rosso
// del colore dei vertici): orlo ribattuto, fascia ricamata col motivo della classe nel colore «ricamo», cuciture.
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"
#include "res://shader/ornati.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.4, 0.25, 0.2);
uniform vec3 ricamo : source_color = vec3(0.75, 0.6, 0.3);
uniform float trama = 150.0;
uniform float cuoio = 0.0;
uniform float piume = 0.0;
uniform float ritorto = 0.0;
uniform float frange = 0.0;          // nappe: fili fitti verticali (UV.x attorno)        // cordoni: passo (m) della torsione dei fili (UV: x attorno, y lungo)
uniform bool usa_orlo = false;
uniform int motivo_classe = -1;
uniform float fascia = 0.0;          // larghezza (m) della fascia ricamata; 0 = nessuna
varying vec3 pl;
varying vec3 nl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

void fragment() {
	float d = usa_orlo ? 1.0 - UV2.y : 1.0;     // il glTF capovolge la v: 1 - v = metri dall'orlo
	float s = UV2.x;
	float ao = usa_orlo ? clamp(COLOR.r, 0.0, 1.0) : 1.0;
	// trama a tre piani (niente righe dove cambia il piano: la trama è fine e si sfuma con la distanza)
	vec2 uv = abs(nl.x) > abs(nl.z) ? pl.zy : pl.xy;
	float sfuma = clamp(1.0 - length(fwidth(uv)) * trama * 0.35, 0.0, 1.0);
	float filo = ((sin(uv.x * trama) * 0.5 + 0.5) * (sin(uv.y * trama) * 0.5 + 0.5) - 0.25) * sfuma;
	float tinta = rum3(pl * 3.2) * 0.6 + rum3(pl * 7.3 + 1.7) * 0.4;
	float h = filo * 0.3 + tinta * 0.2;
	vec3 col = colore * (0.82 + 0.28 * tinta) * (1.0 + 0.06 * filo);
	if (cuoio > 0.5) {
		float macchie = rum3(pl * 9.0) * 0.6 + tinta * 0.4;
		float grana = rum3(pl * 85.0);
		col = colore * (0.7 + 0.45 * macchie) * (0.9 + 0.14 * grana);
		h = grana * 0.5 + macchie * 0.3;
	}
	if (piume > 0.5) {
		// barbe della penna: righe oblique dalla costola (UV.x attraverso la penna, UV.y lungo)
		float barbe = sin((abs(UV.x - 0.02) * 2.0 + UV.y) * 900.0) * 0.5 + 0.5;
		col *= 0.75 + 0.4 * barbe;
		h = barbe;
	}
	if (ritorto > 0.0) {
		// due capi ritorti: righe oblique attorno al cordone, lucide come la seta
		float tor = sin((UV.x / 0.02 + UV.y / ritorto) * 6.2832) * 0.5 + 0.5;
		col *= 0.78 + 0.32 * tor;
		h = tor;
	}
	if (frange > 0.0) {
		float filo2 = sin(UV.x * 1800.0) * 0.5 + 0.5;
		col *= 0.75 + 0.35 * filo2;
		h = filo2;
	}
	float orn = 0.0;
	if (usa_orlo) {
		// orlo ribattuto (risvolto più scuro) e, sul cuoio, cucitura a punti
		float risvolto = 1.0 - smoothstep(0.004, 0.0065, d);
		col *= 1.0 - risvolto * 0.25;
		h += risvolto * 0.6;
		if (cuoio > 0.5) {
			float punto = step(0.45, fract(s / 0.0075));
			float cuc = linea(d - 0.0085, 0.0011) * punto;
			col = mix(col, vec3(0.42, 0.34, 0.22), cuc * 0.85);
			h += cuc;
		} else {
			orn = fascia_ornata(motivo_classe, s, d, 0.009, fascia);
			col = mix(col, ricamo * (0.9 + 0.2 * filo), orn * 0.9);
			h += orn * 0.8;
		}
	}
	col *= mix(0.5, 1.0, ao);
	ALBEDO = col;
	float lucido = cuoio > 0.5 ? 1.0 : 0.0;
	ROUGHNESS = mix(mix(0.92, 0.6, orn * 0.6), 0.55 + 0.2 * tinta, lucido);
	SPECULAR = mix(0.12 + orn * 0.25, 0.35, lucido);
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL = rilievo(NORMAL, VERTEX, h, 0.003);
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
