shader_type spatial;
// Occhio: sclera, iride e pupilla disegnate dalle coordinate sul bulbo (seconda UV scritta da corpo_base.py).
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.2, 0.12, 0.07);   // iride
varying vec2 bulbo;

void vertex() {
	bulbo = UV2;
}

void fragment() {
	float d = length(bulbo);
	vec3 sclera = vec3(0.93, 0.9, 0.86) * (1.0 - 0.25 * smoothstep(0.55, 1.0, d));
	float raggi = 0.75 + 0.25 * sin(atan(bulbo.y, bulbo.x) * 14.0);
	vec3 iride = mix(colore * 1.7, colore * 0.6, smoothstep(0.1, 0.42, d)) * raggi;
	vec3 col = mix(iride, sclera, smoothstep(0.4, 0.46, d));
	col = mix(vec3(0.02), col, smoothstep(0.14, 0.18, d));
	// riflesso
	col += vec3(0.9) * smoothstep(0.07, 0.03, length(bulbo - vec2(-0.14, 0.16)));
	ALBEDO = col;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
