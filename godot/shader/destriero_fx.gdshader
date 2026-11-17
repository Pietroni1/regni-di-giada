shader_type spatial;
// Effetti dei destrieri al livello massimo, su quadrati sempre rivolti alla visuale (additivi, senza luci):
// forma 0 = lingua di fuoco a due colori che sale, 1 = stella a quattro punte che palpita, 2 = ciuffo di saette.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shader/comune.gdshaderinc"

uniform int forma = 0;
uniform vec3 colore : source_color = vec3(1.0, 0.4, 0.07);
uniform vec3 colore2 : source_color = vec3(1.0, 0.8, 0.3);
uniform float forza = 1.2;
uniform float fase = 0.0;
uniform float piega = 0.0;       // la cima della fiamma resta indietro (0..1) quando si corre: verso −x dello schermo no, in alto meno

void vertex() {
	// di fronte alla visuale, in piedi lungo la verticale del mondo (le ossa a cui è appeso girano)
	vec3 su = vec3(0.0, length(MODEL_MATRIX[1].xyz), 0.0);
	vec3 lato = normalize(cross(su, INV_VIEW_MATRIX[2].xyz)) * length(MODEL_MATRIX[0].xyz);
	if (forma == 1) {
		su = INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz);
		lato = INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz);
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(lato, 0.0), vec4(su, 0.0), vec4(normalize(cross(lato, su)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y);          // q.y = 0 alla base, 1 in cima
	float t = TIME + fase * 7.3;
	float v = 0.0;
	vec3 c = colore;
	if (forma == 0) {
		float n = fbm(vec2(q.x * 4.0 + fase * 3.0, q.y * 3.0 - t * 2.6));
		float n2 = fbm(vec2(q.x * 9.0 - fase, q.y * 6.0 - t * 4.0));
		float larg = 0.36 * pow(1.0 - q.y, 0.8) * (0.55 + 0.7 * n) + 0.015;
		float x = q.x + sin(q.y * 5.0 + t * 4.0) * 0.07 * q.y + (n2 - 0.5) * 0.12 * q.y;
		float corpo = smoothstep(larg, larg * 0.25, abs(x));
		float cuore = smoothstep(larg * 0.55, 0.0, abs(x)) * smoothstep(0.75, 0.05, q.y);
		v = corpo * smoothstep(0.0, 0.06, q.y) * smoothstep(1.0, 0.45, q.y + n * 0.35);
		c = mix(colore, colore2, cuore);
		c = mix(c, colore * vec3(1.0, 0.45, 0.3), smoothstep(0.45, 0.95, q.y));      // le punte virano al rosso
	} else if (forma == 1) {
		vec2 p = q - vec2(0.0, 0.5);
		float r = length(p);
		float palpito = 0.75 + 0.25 * sin(t * 5.0);
		float raggi = max(smoothstep(0.035 * palpito, 0.0, abs(p.x)) * smoothstep(0.5, 0.0, abs(p.y)), smoothstep(0.035 * palpito, 0.0, abs(p.y)) * smoothstep(0.5, 0.0, abs(p.x)));
		vec2 d = vec2(p.x + p.y, p.x - p.y) * 0.707;
		float diag = max(smoothstep(0.02, 0.0, abs(d.x)) * smoothstep(0.22, 0.0, abs(d.y)), smoothstep(0.02, 0.0, abs(d.y)) * smoothstep(0.22, 0.0, abs(d.x)));
		float nucleo = smoothstep(0.16, 0.0, r);
		v = (raggi + diag * 0.6 + nucleo * 1.3) * palpito;
		c = mix(colore, colore2, nucleo);
	} else {
		// ciuffo di saette: tre rami spezzati che cambiano a scatti
		float scatto = floor(t * 12.0);
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float sx = (h21(vec2(scatto, fi + fase * 9.0)) - 0.5) * 0.5;
			float x = q.x - sx * q.y - (rum(vec2(q.y * 9.0 + scatto * 3.1, fi * 7.0 + fase)) - 0.5) * 0.3 * sin(q.y * 3.14);
			float acceso = step(0.35, h21(vec2(scatto + fi * 3.0, fase + 1.0)));
			v += smoothstep(0.05, 0.0, abs(x)) * acceso * smoothstep(1.0, 0.7, q.y) * smoothstep(0.0, 0.05, q.y);
			v += smoothstep(0.012, 0.0, abs(x)) * acceso * 1.5 * smoothstep(1.0, 0.7, q.y);
		}
		c = mix(colore, colore2, clamp(v - 0.9, 0.0, 1.0));
	}
	ALBEDO = c * v * forza;
	ALPHA = clamp(v, 0.0, 1.0);
}
