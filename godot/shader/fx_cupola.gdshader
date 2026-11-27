shader_type spatial;
// Cupola di protezione: una semisfera con il bordo che brilla e una trama a celle che scorre piano.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(0.3, 1.0, 0.6, 1.0);
uniform vec4 colore2 : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float fase = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec2 g = vec2(UV.x * 18.0, UV.y * 7.0 + TIME * 0.4);
	vec2 c = abs(fract(g) - 0.5);
	float celle = smoothstep(0.46, 0.5, max(c.x, c.y)) * 0.5;
	float vita = smoothstep(0.0, 0.18, fase) * (1.0 - smoothstep(0.7, 1.0, fase));
	float a = (f * 0.9 + celle * (0.25 + f) + 0.05) * vita;
	ALBEDO = mix(colore.rgb, colore2.rgb, f * 0.6 + celle * 0.4) * 1.4;
	ALPHA = clamp(a, 0.0, 1.0) * colore.a;
}
