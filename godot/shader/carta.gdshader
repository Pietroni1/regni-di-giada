shader_type spatial;
// Talismani di carta dei completi: carta di riso ingiallita con segni d'inchiostro inventati (non sono caratteri veri)
// e un sigillo rosso in fondo. UV dei pezzi costruiti in Blender: x attraverso il foglio, y lungo, in metri.
render_mode diffuse_burley, cull_disabled;
#include "res://shader/comune.gdshaderinc"
#include "res://shader/ornati.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.8, 0.7, 0.45);
uniform vec3 inchiostro : source_color = vec3(0.04, 0.03, 0.03);
uniform vec3 sigillo : source_color = vec3(0.6, 0.06, 0.04);
varying vec3 pl;

void vertex() { pl = VERTEX; }

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);          // il glTF capovolge la v
	vec2 p = uv / 0.012;                       // celle di 1,2 cm: un segno per cella
	vec2 c = floor(p);
	vec2 f = fract(p) - 0.5;
	float a = h21(c), b = h21(c + 7.3);
	// ogni segno: un tratto verticale e uno orizzontale spostati a caso, a volte un punto
	float seg = linea(f.x - (a - 0.5) * 0.5, 0.07) * step(abs(f.y), 0.38);
	seg = max(seg, linea(f.y - (b - 0.5) * 0.6, 0.07) * step(abs(f.x), 0.32 + 0.1 * a));
	seg = max(seg, (1.0 - smoothstep(0.08, 0.12, length(f - vec2(0.25, -0.25)))) * step(0.6, b));
	// colonna di segni al centro del foglio, lasciando il margine
	float colonna = step(abs(c.x - floor(0.03 / 0.012)), 0.5) * step(1.0, c.y) * step(c.y, 8.0);
	float ink = seg * colonna;
	float fibre = rum3(pl * 140.0);
	vec3 col = colore * (0.88 + 0.16 * fibre);
	col = mix(col, inchiostro, ink * 0.9);
	// sigillo rosso: quadrato con cornice in basso
	vec2 q = uv - vec2(0.03, 0.115);
	float quad = max(abs(q.x), abs(q.y));
	float sig = (1.0 - smoothstep(0.009, 0.010, quad)) * (1.0 - linea(quad - 0.007, 0.0008));
	col = mix(col, sigillo, sig * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
