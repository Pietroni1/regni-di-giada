shader_type spatial;
// Fiammella degli spiriti: lingua di fuoco su un quadrato sempre rivolto alla visuale, additiva, senza luce dinamica.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(1.0, 0.55, 0.15);
uniform float forza = 1.4;

void vertex() {
	// sempre di fronte alla visuale (attorno all'asse verticale del nodo)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y);          // q.y = 0 alla base, 1 in cima
	float n = fbm(vec2(q.x * 4.0, q.y * 3.0 - TIME * 2.5));
	float larg = 0.32 * (1.0 - q.y) * (0.7 + 0.5 * n) + 0.02;
	float corpo = smoothstep(larg, larg * 0.4, abs(q.x + sin(q.y * 5.0 + TIME * 4.0) * 0.05 * q.y));
	float cuore = smoothstep(larg * 0.5, 0.0, abs(q.x)) * smoothstep(0.7, 0.1, q.y);
	float v = corpo * smoothstep(0.0, 0.08, q.y) * smoothstep(1.0, 0.55, q.y + n * 0.25);
	vec3 c = mix(colore, vec3(1.0, 0.95, 0.8), cuore * 0.7);
	ALBEDO = c * v * forza;
	ALPHA = clamp(v, 0.0, 1.0);
}
