shader_type spatial;
// Bestie dei mostri (mostri.glb): vedi bestia.gdshaderinc.
render_mode diffuse_burley;

#include "res://shader/bestia.gdshaderinc"

uniform float bordo = 0.25;        // luce di contorno dipinta (stile illustrato)
uniform vec3 bordo_col : source_color = vec3(1.0, 0.92, 0.8);

void fragment() {
	vec3 alb, emi;
	float rough, metal;
	mantello(UV, UV2, alb, emi, rough, metal);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = alb;
	EMISSION = emi + bordo_col * alb * fr * bordo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.2;
}
