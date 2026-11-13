shader_type spatial;
// Scia di uno scatto o di un colpo che attraversa: una striscia che sfuma in coda.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform float fase = 0.0;
void fragment() {
	float lato = 1.0 - abs(UV.x - 0.5) * 2.0;
	float a = pow(lato, 2.0) * smoothstep(fase - 0.1, fase + 0.5, UV.y) * (1.0 - fase);
	ALBEDO = mix(colore.rgb, vec3(1.0), pow(lato, 6.0)) * 1.8;
	ALPHA = clamp(a, 0.0, 1.0) * colore.a;
}
