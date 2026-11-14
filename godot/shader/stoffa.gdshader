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
	// filo di ricamo molto rado nel colore della classe: piccoli punti sparsi, non fasce (sui capi aderenti le fasce
	// orizzontali diventavano anelli attorno a gambe e busto)
	vec2 gp = uv * 9.0;
	float punto = (1.0 - smoothstep(0.05, 0.09, length(fract(gp) - 0.5))) * step(0.8, h21(floor(gp)));
	col = mix(col, ricamo, punto * 0.55);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	NORMAL = rilievo(NORMAL, VERTEX, filo * 0.5 + piega * 0.5, 0.004);
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
