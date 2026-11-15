shader_type spatial;
// Stoffa dei vestiti: trama fine del tessuto, chiazze di tinta stesa a mano e pieghe accennate.
// cuoio = 1: cuoio conciato (niente trama, macchie scure, un filo di lucentezza sulle parti consumate).
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.4, 0.25, 0.2);
uniform vec3 ricamo : source_color = vec3(0.75, 0.6, 0.3);   // non più usato: resta per i materiali già creati
uniform float trama = 150.0;
uniform float cuoio = 0.0;
varying vec3 pl;
varying vec3 nl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

void fragment() {
	vec2 uv = abs(nl.x) > abs(nl.z) ? pl.zy : pl.xy;
	float filo = (sin(uv.x * trama) * 0.5 + 0.5) * (sin(uv.y * trama) * 0.5 + 0.5);
	float tinta = fbm3(pl * 3.2);
	float piega = sin(uv.x * 26.0 + fbm3(pl * 2.0) * 7.0) * 0.5 + 0.5;
	vec3 col_stoffa = colore * (0.8 + 0.3 * tinta) * (0.92 + 0.12 * piega) * (0.98 + 0.03 * filo);
	float macchie = fbm3(pl * 9.0);
	float pori = rum3(pl * 70.0);
	vec3 col_cuoio = colore * (0.7 + 0.45 * macchie) * (0.94 + 0.08 * pori);
	ALBEDO = mix(col_stoffa, col_cuoio, cuoio);
	ROUGHNESS = mix(0.92, 0.55 + 0.25 * macchie, cuoio);
	SPECULAR = mix(0.12, 0.35, cuoio);
	NORMAL = rilievo(NORMAL, VERTEX, mix(piega, macchie * 0.6 + pori * 0.4, cuoio), 0.004);
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
