shader_type spatial;
// Stendardi delle Prove: stoffa pesante nel colore dell'ala, bordo scuro, coda di rondine in fondo e un emblema
// (cerchio con un rombo) che trattiene un po' di luce. Su un quadrato a due facce: il colore arriva dall'istanza
// o dal parametro.
render_mode cull_disabled, diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.6, 0.3, 0.9);
uniform float luce = 0.8;
uniform float spento = 0.0;        // 1 = stendardo di un'ala chiusa: stinto e strappato

void fragment() {
	vec2 q = UV;                                       // (0,0) in alto a sinistra
	float coda = 1.0 - 0.14 * (1.0 - abs(q.x - 0.5) * 2.0);
	float strappo = spento * (0.28 + 0.2 * fbm(vec2(q.x * 7.0, 3.0)));
	if (q.y > coda - strappo) discard;
	float bordo = min(min(q.x, 1.0 - q.x), q.y * 0.4);
	float orlo = smoothstep(0.1, 0.07, bordo);
	float trama = 0.85 + 0.15 * rum(q * vec2(60.0, 140.0));
	float pieghe = 0.82 + 0.18 * sin(q.x * 14.0 + sin(q.y * 5.0));
	vec3 c = colore * 0.42 * trama * pieghe;
	c = mix(c, colore * 0.12, orlo);
	c = mix(c, vec3(0.75, 0.6, 0.25) * trama, smoothstep(0.012, 0.0, abs(bordo - 0.1)) * 0.9);
	// emblema: anello e rombo
	vec2 e = (q - vec2(0.5, 0.38)) * vec2(1.0, 2.4);
	float r = length(e);
	float anello = smoothstep(0.035, 0.015, abs(r - 0.3));
	float rombo = smoothstep(0.02, 0.0, abs(e.x) + abs(e.y) - 0.17);
	float segno = clamp(anello + rombo, 0.0, 1.0) * (1.0 - spento);
	c = mix(c, colore, segno);
	c = mix(c, vec3(dot(c, vec3(0.33))) * 1.3 + vec3(0.03), spento * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = colore * segno * luce + colore * 0.05 * (1.0 - spento);
}
