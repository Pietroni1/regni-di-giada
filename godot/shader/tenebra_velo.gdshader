shader_type spatial;
// Stile «tenebra» sui personaggi: un velo sopra il modello (material_overlay). Scurisce con una grana grossa, come una
// texture dipinta a bassa definizione, e accende il contorno nel colore di chi è (classe, nemico, PNG): figure scure
// con il profilo che brilla contro la nebbia.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://shader/comune.gdshaderinc"
uniform vec3 accento : source_color = vec3(1.0, 0.2, 0.15);
uniform float velo = 0.4;
uniform float bordo = 1.0;
varying vec3 pm;

void vertex() { pm = VERTEX; }

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = clamp(pow(f, 2.3) * bordo, 0.0, 1.0);
	float grana = 0.55 + 0.9 * rum(floor(pm.xy * 34.0) * 0.37 + floor(pm.z * 34.0) * 0.61);
	float a_velo = velo * grana * (1.0 - rim);
	ALBEDO = mix(accento * 0.06, accento * 1.7 + vec3(0.25), rim / (rim + a_velo + 0.001));
	ALPHA = clamp(rim * 0.85 + a_velo, 0.0, 0.92);
}
