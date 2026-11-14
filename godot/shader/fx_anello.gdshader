shader_type spatial;
// Onda d'urto a terra: un anello che si allarga e svanisce (fase 0 → 1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform float fase = 0.0;
uniform float spessore = 0.16;
uniform float pieno = 0.0;      // 1 = disco pieno che sfuma (cerchi di cura, aree)
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = 1.0 - pow(1.0 - fase, 2.2);
	float banda = smoothstep(r - spessore, r - spessore * 0.25, d) * (1.0 - smoothstep(r - spessore * 0.1, r, d));
	float disco = (1.0 - smoothstep(r * 0.2, r, d)) * 0.18 * pieno;
	float raggi = 0.75 + 0.25 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 24.0 + fase * 9.0);
	float a = (banda * raggi + disco) * (1.0 - fase * fase);
	ALBEDO = colore.rgb * (1.0 + banda * 0.8);
	ALPHA = clamp(a, 0.0, 1.0) * colore.a;
}
