shader_type spatial;
// Legno scuro con venature lungo l'asse più lungo del pezzo, nodi e spigoli consumati.
render_mode diffuse_burley;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.20, 0.12, 0.08);
varying vec3 pl;
varying vec3 nl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

void fragment() {
	// le travi sono scatole: la fibra corre lungo il lato più esteso della faccia sullo schermo
	vec3 a = abs(nl);
	vec2 uv = a.y > 0.7 ? pl.xz : (a.x > a.z ? pl.zy : pl.xy);
	vec2 d = fwidth(uv);
	if (d.x < d.y) uv = uv.yx;
	float vena = rum(vec2(uv.x * 38.0 + rum(uv * vec2(3.0, 0.6)) * 9.0, uv.y * 1.6));
	float fibra = rum(vec2(uv.x * 150.0, uv.y * 4.0));
	float nodo = smoothstep(0.82, 0.95, rum(uv * vec2(1.3, 0.5) + 4.0));
	float h = vena * 0.6 + fibra * 0.4;
	vec3 col = colore * (0.62 + 0.75 * h) * (1.0 - nodo * 0.5);
	col += colore * 0.5 * smoothstep(0.75, 1.0, vena);        // filo chiaro delle venature
	ALBEDO = col;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	NORMAL = rilievo(NORMAL, VERTEX, h - nodo, 0.015);
}
