shader_type spatial;
// Bestie spettrali (tigri dei mostri): corpo traslucido che sfuma, velature che scorrono, strisce e contorno luminosi.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley;

#include "res://shader/bestia.gdshaderinc"

uniform vec3 luce : source_color = vec3(0.6, 0.85, 1.0);       // colore dello spirito (contorno e strisce)
uniform float opacita = 0.55;

void fragment() {
	vec3 alb, emi;
	float rough, metal;
	float segno = mantello(UV, UV2, alb, emi, rough, metal);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float vel = fbm3(pl * 3.5 + vec3(0.0, TIME * 0.6, TIME * 0.3));
	ALBEDO = mix(alb, luce * 0.4, 0.35);
	EMISSION = luce * (fr * 1.6 + vel * 0.25) + luce * segno * 2.2 + emi;
	ALPHA = clamp(opacita * (0.55 + 0.6 * vel) + fr * 0.6 + segno * 0.6, 0.0, 1.0);
	ROUGHNESS = 0.4;
	SPECULAR = 0.3;
}
