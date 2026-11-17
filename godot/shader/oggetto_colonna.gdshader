shader_type spatial;
// Colonna di luce sopra un oggetto caduto: sottile, sfuma verso l'alto, bordi morbidi, pulsa piano.
// Il colore è quello della rarità; `forza` è bassa per i comuni.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform float forza = 1.0;
uniform float fase = 0.0;
void fragment() {
	float su = 1.0 - UV.y;                                   // 0 alla base, 1 in cima
	float bordo = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = pow(1.0 - su, 1.4) * (0.35 + 0.65 * bordo);
	float pulsa = 0.88 + 0.12 * sin(TIME * 2.2 + fase);
	ALBEDO = colore.rgb;
	ALPHA = clamp(a * forza * pulsa, 0.0, 1.0);
}
