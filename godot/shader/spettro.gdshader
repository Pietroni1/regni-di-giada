shader_type spatial;
// Veste delle ombre: stoffa scura e traslucida che verso l'orlo si sfrangia in fumo (UV.y = 0 in alto, 1 all'orlo),
// con un contorno di luce fredda. L'orlo ondeggia; i brandelli sono ritagliati dal rumore e salgono piano.
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley;

#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.12, 0.1, 0.16);
uniform vec3 contorno : source_color = vec3(0.45, 0.3, 0.9);
uniform float opacita = 0.85;
uniform float ondeggia = 0.08;

varying float giu;

void vertex() {
	giu = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = w.x * 1.3 + w.z * 1.7;
	float a = UV.y * UV.y;
	VERTEX.x += sin(TIME * 2.1 + VERTEX.y * 5.0 + ph + UV.x * 12.0) * ondeggia * a;
	VERTEX.z += cos(TIME * 1.7 + VERTEX.y * 4.0 + ph + UV.x * 9.0) * ondeggia * a;
}

void fragment() {
	float n = fbm(vec2(UV.x * 9.0, UV.y * 3.0 - TIME * 0.35));
	float sfrangia = smoothstep(0.55, 1.0, giu);
	if (n < sfrangia * 1.1 - 0.05) {
		discard;
	}
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 c = colore * (0.75 + 0.5 * n);
	ALBEDO = c;
	EMISSION = contorno * (fr * 1.4 + sfrangia * n * 0.5);
	ALPHA = clamp(opacita * (1.0 - sfrangia * 0.6) + fr * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}
