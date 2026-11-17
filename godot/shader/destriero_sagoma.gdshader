shader_type spatial;
// Sagoma d'ombra che resta dietro al corsiero dell'Ombra al galoppo (copia della pelle, in ritardo): scura al centro,
// bordo viola, semitrasparente. Nessuna luce.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec3 colore : source_color = vec3(0.6, 0.28, 0.95);
uniform float forza = 0.4;

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(0.02, 0.012, 0.04), colore, fr);
	ALPHA = forza * (0.5 + 0.5 * fr);
}
