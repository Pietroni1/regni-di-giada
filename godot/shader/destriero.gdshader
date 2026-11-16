shader_type spatial;
// Corpo, crini e zoccoli dei destrieri: vedi destriero.gdshaderinc.
render_mode diffuse_burley;

#include "res://shader/destriero.gdshaderinc"

uniform float bordo_luce = 0.22;        // luce di contorno dipinta (stile illustrato)
uniform vec3 bordo_col : source_color = vec3(0.0);   // contorno colorato che non dipende dal mantello (cavalli neri)

void fragment() {
	vec3 alb, emi;
	float rough, metal;
	destriero(UV, UV2, NORMAL, VIEW, alb, emi, rough, metal);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = alb;
	EMISSION = emi + alb * fr * bordo_luce + bordo_col * fr;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
