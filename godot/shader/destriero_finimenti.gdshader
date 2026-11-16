shader_type spatial;
// Finimenti dei destrieri (sella, bardatura, drappi): come destriero.gdshader ma visibili dai due lati,
// perché coperte e gualdrappe sono fogli sottili. Vedi destriero.gdshaderinc.
render_mode diffuse_burley, cull_disabled;

#include "res://shader/destriero.gdshaderinc"

uniform vec3 bordo_col : source_color = vec3(0.0);   // (solo per avere gli stessi parametri del corpo)

void fragment() {
	vec3 alb, emi;
	float rough, metal;
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	destriero(UV, UV2, n, VIEW, alb, emi, rough, metal);
	NORMAL = n;
	ALBEDO = alb * (FRONT_FACING ? 1.0 : 0.6);
	EMISSION = emi;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
