shader_type spatial;
// Pelle: tono caldo con lieve variazione, più rosata dove la superficie guarda in basso.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.86, 0.66, 0.52);
varying vec3 pl;
varying vec3 nl;
varying vec2 viso;      // seconda UV dei corpi base: x = labbra, y = sopracciglia (0 sui modelli che non la hanno)
uniform vec3 capelli : source_color = vec3(0.1, 0.08, 0.07);

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
	viso = UV2;
}

void fragment() {
	float v = fbm3(pl * 9.0);
	vec3 base = colore * vec3(0.9, 0.84, 0.8);          // incarnato più caldo e abbronzato
	vec3 col = base * (0.93 + 0.12 * v);
	col = mix(col, base * vec3(1.0, 0.86, 0.82), smoothstep(0.2, -0.8, nl.y) * 0.35);
	float labbra = smoothstep(0.55, 0.95, viso.x);
	col = mix(col, col * vec3(0.92, 0.6, 0.56), labbra * 0.75);
	float sopra = smoothstep(0.58, 0.8, viso.y + (fbm3(pl * 60.0) - 0.5) * 0.1);
	col = mix(col, capelli, sopra * 0.9);
	ALBEDO = col;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
