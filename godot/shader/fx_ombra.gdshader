shader_type spatial;
// Taglio d'ombra: una mezzaluna scura (colore2) con il bordo sottile e acceso (colore). Fusione normale, non additiva:
// il nero resta nero anche sopra gli sfondi chiari.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(0.5, 1.0, 0.2, 1.0);
uniform vec4 colore2 : source_color = vec4(0.2, 0.05, 0.3, 1.0);
uniform float fase = 0.0;
uniform float arco = 2.4;
uniform float interno = 0.7;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float ang = atan(p.x, -p.y);
	float testa = -arco * 0.5 + arco * smoothstep(0.0, 0.6, fase);
	float coda = -arco * 0.5 + arco * smoothstep(0.2, 1.0, fase);
	float dentro = step(coda, ang) * step(ang, testa);
	float lungo = clamp((ang - coda) / max(0.001, testa - coda), 0.0, 1.0);
	float corpo = smoothstep(interno, interno + 0.2, d) * (1.0 - smoothstep(0.9, 0.99, d));
	float filo = smoothstep(0.9, 0.975, d) * (1.0 - smoothstep(0.975, 1.0, d));
	float sfumo = 1.0 - smoothstep(0.7, 1.0, fase);
	float a_corpo = dentro * corpo * pow(lungo, 1.2) * 0.92;
	float a_filo = dentro * filo * lungo * 1.6;
	ALBEDO = mix(colore2.rgb, colore.rgb * 1.4, clamp(a_filo, 0.0, 1.0));
	ALPHA = clamp(max(a_corpo, a_filo), 0.0, 1.0) * sfumo * colore.a;
}
