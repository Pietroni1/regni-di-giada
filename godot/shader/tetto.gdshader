shader_type spatial;
// Tetti a coppi: file di tegole lungo la falda (UV.y scende verso la gronda), colore dipinto.
render_mode cull_disabled, diffuse_burley;

uniform vec3 colore : source_color = vec3(0.3, 0.12, 0.1);
uniform float file = 2.4;   // coppi per metro (le UV sono in metri)

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void fragment() {
	vec2 g = vec2(UV.x * file, UV.y * file * 0.55);
	float colonna = abs(fract(g.x) - 0.5) * 2.0;            // 0 al colmo del coppo, 1 nel canale
	float riga = fract(g.y);
	float id = h21(floor(g));
	vec3 c = colore * (0.75 + 0.5 * id);
	c *= mix(1.15, 0.55, smoothstep(0.35, 1.0, colonna));    // canale in ombra
	c *= mix(0.6, 1.0, smoothstep(0.0, 0.18, riga));         // bordo di ogni tegola
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
