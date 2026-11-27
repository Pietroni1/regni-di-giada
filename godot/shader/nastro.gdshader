shader_type spatial;
// Nastri, stendardi e lembi mossi dal vento: la striscia è appesa per il bordo alto (UV.y = 0) e ondeggia di più verso
// il fondo. La fase dipende dalla posizione nel mondo, così due nastri vicini non si muovono uguali. Niente parametri
// per istanza: un solo materiale per colore.
render_mode diffuse_burley, cull_disabled;

#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.7, 0.12, 0.1);
uniform vec3 orlo : source_color = vec3(0.9, 0.75, 0.35);
uniform float ampiezza = 0.12;
uniform float velocita = 2.2;
uniform float luce = 0.0;          // nastri spiritati che brillano
uniform float stemma = 0.0;        // disco d'oro al centro (stendardi)
uniform float frange = 0.0;        // fondo sfilacciato

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = w.x * 1.7 + w.z * 2.3;
	float t = UV.y;
	VERTEX.z += sin(TIME * velocita + ph + t * 4.0) * ampiezza * t * t * 2.0;
	VERTEX.x += sin(TIME * velocita * 0.7 + ph * 1.3 + t * 3.0) * ampiezza * 0.5 * t * t;
}

void fragment() {
	if (frange > 0.0 && UV.y > 0.9 - 0.06 * rum(vec2(UV.x * 30.0, 0.0)) * frange) {
		discard;
	}
	float bordo = max(step(UV.x, 0.08), step(0.92, UV.x));
	float trama = 0.9 + 0.1 * rum(vec2(UV.x * 40.0, UV.y * 80.0));
	vec3 c = mix(colore, orlo, bordo) * trama;
	float d = length((UV - vec2(0.5, 0.35)) * vec2(1.0, 1.6));
	float disco = stemma * (smoothstep(0.24, 0.22, d) - smoothstep(0.16, 0.14, d) * 0.6);
	c = mix(c, orlo, disco);
	ALBEDO = c;
	EMISSION = c * luce;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
}
