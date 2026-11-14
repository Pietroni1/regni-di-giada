shader_type spatial;
// Piastre e bordi di armature ed elmi: metallo o lacca con graffi, usura chiara sugli spigoli e patina negli incavi.
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.5, 0.5, 0.55);
uniform float metallico = 0.6;
uniform float ruvido = 0.4;
varying vec3 pl;

void vertex() { pl = VERTEX; }

void fragment() {
	float graffi = rum3(pl * vec3(160.0, 14.0, 160.0)) * 0.5 + rum3(pl * vec3(20.0, 190.0, 20.0)) * 0.5;
	float patina = fbm3(pl * 6.0);
	float spigolo = clamp(length(fwidth(NORMAL)) * 4.0, 0.0, 1.0);        // dove la normale cambia in fretta
	vec3 col = colore * (0.75 + 0.35 * patina) * (0.92 + 0.14 * graffi);
	col = mix(col, colore * 1.7 + 0.08, spigolo * 0.55);
	col = mix(col, colore * 0.45, smoothstep(0.62, 0.9, patina) * 0.45);
	ALBEDO = col;
	METALLIC = metallico;
	ROUGHNESS = clamp(ruvido + (graffi - 0.5) * 0.25 + smoothstep(0.6, 0.9, patina) * 0.3, 0.08, 1.0);
	SPECULAR = 0.5;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
