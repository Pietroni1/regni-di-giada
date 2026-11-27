shader_type spatial;
// Luci finte delle Prove, tutte additive e senza luci dinamiche; si usano in MultiMesh (colore per istanza).
//  tipo 0 fiamma: lingua di fuoco su un quadrato rivolto alla visuale (torce, bracieri);
//  tipo 1 alone: chiazza di luce tonda (stesa sul pavimento sotto un lume, o in piedi rivolta alla visuale);
//  tipo 2 fascio: lama di luce polverosa che scende dall'alto (quadrato in piedi rivolto alla visuale);
//  tipo 3 nebbia: velo basso che scorre (quadrato steso).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shader/comune.gdshaderinc"

uniform int tipo = 0;
uniform bool verso_visuale = true;
uniform float forza = 1.0;
varying float seme;

void vertex() {
	seme = float(INSTANCE_ID) * 0.731;
	if (verso_visuale) {
		// attorno all'asse verticale dell'istanza, con la sua scala
		float sx = length(MODEL_MATRIX[0].xyz), sz = length(MODEL_MATRIX[2].xyz);
		vec3 lato = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(lato * sx, 0.0), MODEL_MATRIX[1], vec4(cross(lato, vec3(0.0, 1.0, 0.0)) * sz, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec3 colore = COLOR.rgb;
	float v = 0.0;
	if (tipo == 0) {
		vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y);
		float n = fbm(vec2(q.x * 4.0 + seme, q.y * 3.0 - TIME * 2.5 - seme));
		float larg = 0.32 * (1.0 - q.y) * (0.7 + 0.5 * n) + 0.02;
		float corpo = smoothstep(larg, larg * 0.4, abs(q.x + sin(q.y * 5.0 + TIME * 4.0 + seme) * 0.05 * q.y));
		float cuore = smoothstep(larg * 0.5, 0.0, abs(q.x)) * smoothstep(0.7, 0.1, q.y);
		v = corpo * smoothstep(0.0, 0.08, q.y) * smoothstep(1.0, 0.55, q.y + n * 0.25);
		colore = mix(colore, mix(colore, vec3(1.0, 0.95, 0.8), 0.6), cuore * 0.5);
		v *= 1.25;
	} else if (tipo == 1) {
		float r = length(UV - 0.5) * 2.0;
		v = pow(max(0.0, 1.0 - r), 2.2) * (0.85 + 0.15 * sin(TIME * 5.0 + seme * 7.0) * sin(TIME * 3.1 + seme));
	} else if (tipo == 2) {
		float x = abs(UV.x - 0.5) * 2.0;
		float polvere = fbm(vec2(UV.x * 5.0 + seme, UV.y * 2.0 + TIME * 0.05)) * 0.7 + rum(vec2(UV.x * 40.0 + seme, UV.y * 30.0 - TIME * 0.2)) * 0.5;
		v = pow(max(0.0, 1.0 - x), 1.6) * smoothstep(1.0, 0.75, UV.y) * smoothstep(0.0, 0.25, UV.y) * (0.35 + 0.65 * polvere);
		v *= 0.45 + 0.55 * (1.0 - UV.y);          // più forte in alto, dove entra
	} else {
		vec2 q = UV * 3.0 + vec2(seme, seme * 0.37);
		float n = fbm(q + vec2(TIME * 0.035, -TIME * 0.02)) * fbm(q * 2.3 - vec2(TIME * 0.05, seme));
		vec2 e = min(UV, 1.0 - UV);
		v = smoothstep(0.08, 0.45, n) * smoothstep(0.0, 0.22, e.x) * smoothstep(0.0, 0.22, e.y) * 0.55;
	}
	v *= forza * COLOR.a;
	ALBEDO = colore * v;
}
