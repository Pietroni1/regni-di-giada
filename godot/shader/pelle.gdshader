shader_type spatial;
// Pelle: tono caldo con lieve variazione, più rosata dove la superficie guarda in basso.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.86, 0.66, 0.52);
varying vec3 pl;
varying vec3 nl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

void fragment() {
	float v = fbm3(pl * 9.0);
	vec3 col = colore * (0.93 + 0.12 * v);
	col = mix(col, colore * vec3(1.0, 0.86, 0.82), smoothstep(0.2, -0.8, nl.y) * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
