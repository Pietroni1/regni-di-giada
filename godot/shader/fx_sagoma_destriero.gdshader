shader_type spatial;
// Sagoma d'ombra di un destriero nelle tecniche a cavallo dell'Ombra (tecniche_destriero.gd): corpo scuro e pieno con
// l'orlo viola acceso, così si legge anche da lontano; `forza` la fa svanire. Nessuna luce.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 colore : source_color = vec3(0.6, 0.28, 0.95);
uniform float forza = 1.0;

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	ALBEDO = mix(vec3(0.03, 0.015, 0.06), colore * 1.6, fr);
	ALPHA = clamp(forza * (0.8 + 0.3 * fr), 0.0, 1.0);
}
