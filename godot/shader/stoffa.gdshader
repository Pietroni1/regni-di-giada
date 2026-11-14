shader_type spatial;
// Stoffa dei vestiti: trama del tessuto, chiazze di tinta stesa a mano, pieghe accennate e orlo ricamato.
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.4, 0.25, 0.2);
uniform vec3 ricamo : source_color = vec3(0.75, 0.6, 0.3);
uniform float trama = 150.0;
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
	vec3 col = colore * (0.78 + 0.32 * tinta) * (0.9 + 0.14 * piega) * (0.93 + 0.1 * filo);
	// motivo a onde ricamato su fasce orizzontali (orli di vesti e maniche)
	float quota = fract(pl.y * 1.6 + 0.12);
	float fascia = smoothstep(0.0, 0.01, quota) * (1.0 - smoothstep(0.045, 0.055, quota));
	float onda = smoothstep(0.012, 0.0, abs(quota - 0.027 - sin(uv.x * 34.0) * 0.012));
	float riga = smoothstep(0.004, 0.0, abs(quota - 0.004)) + smoothstep(0.004, 0.0, abs(quota - 0.05));
	col = mix(col, ricamo, clamp(fascia * onda + riga, 0.0, 1.0) * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	NORMAL = rilievo(NORMAL, VERTEX, filo * 0.5 + piega * 0.5, 0.004);
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
