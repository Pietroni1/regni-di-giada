shader_type spatial;
// Segno a terra di élite e capi: un anello sottile con tacche che girano piano e un alone morbido.
// capo = 1: doppio anello con punte (generali, custodi). Additivo, senza ombre né luci.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 colore : source_color = vec3(1.0, 0.75, 0.3);
uniform float forza = 0.9;
uniform float capo = 0.0;

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	float a = atan(q.y, q.x);
	float anello = smoothstep(0.035, 0.0, abs(d - 0.86));
	float tacche = smoothstep(0.03, 0.0, abs(d - 0.76)) * step(0.55, fract(a * 3.8197 + TIME * 0.15));
	float alone = smoothstep(1.0, 0.55, d) * smoothstep(0.2, 0.85, d) * 0.22;
	float punte = 0.0;
	if (capo > 0.5) {
		float s = abs(fract(a * 1.9099 - TIME * 0.08) - 0.5) * 2.0;
		punte = smoothstep(0.02, 0.0, abs(d - (0.62 + 0.14 * (1.0 - s)))) * step(d, 0.8);
		anello += smoothstep(0.02, 0.0, abs(d - 0.6));
	}
	float pulso = 0.85 + 0.15 * sin(TIME * 2.4);
	float v = (anello + tacche * 0.8 + alone + punte * 0.9) * pulso * forza;
	ALBEDO = colore * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
