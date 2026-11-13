shader_type spatial;
// Colonna di luce: un cilindro che sfuma verso l'alto con striature che salgono.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform float fase = 0.0;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void fragment() {
	float su = 1.0 - UV.y;                                   // 0 alla base, 1 in cima
	float strisce = 0.55 + 0.45 * step(0.55, h21(vec2(floor(UV.x * 36.0), floor((su - TIME * 1.6) * 5.0))));
	float a = pow(1.0 - su, 1.6) * strisce;
	float vita = smoothstep(0.0, 0.15, fase) * (1.0 - smoothstep(0.55, 1.0, fase));
	ALBEDO = colore.rgb * 1.6;
	ALPHA = clamp(a * vita, 0.0, 1.0) * colore.a;
}
