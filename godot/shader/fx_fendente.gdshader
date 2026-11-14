shader_type spatial;
// Scia di un fendente: una mezzaluna che spazza un arco (fase 0 → 1). Con giro = 1 fa tutto il cerchio.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform float fase = 0.0;
uniform float arco = 2.6;       // ampiezza in radianti
uniform float interno = 0.55;   // raggio interno della lama (0..1)
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float ang = atan(p.x, -p.y);                         // 0 davanti, cresce in senso orario
	float testa = -arco * 0.5 + arco * smoothstep(0.0, 0.7, fase);
	float coda = -arco * 0.5 + arco * smoothstep(0.25, 1.0, fase);
	float dentro = step(coda, ang) * step(ang, testa);
	float lungo = clamp((ang - coda) / max(0.001, testa - coda), 0.0, 1.0);   // 0 in coda, 1 sul filo
	float radiale = smoothstep(interno, interno + 0.25, d) * (1.0 - smoothstep(0.86, 1.0, d));
	float filo = smoothstep(0.80, 0.97, d) * (1.0 - smoothstep(0.97, 1.0, d));
	// striature lungo l'arco, come pennellate d'inchiostro trascinate dalla lama
	float fibra = 0.55 + 0.45 * sin(d * 46.0 + sin(ang * 5.0) * 2.0) * sin(d * 17.0 + 1.3);
	float sfrangia = smoothstep(0.0, 0.25, lungo + (sin(d * 60.0) * 0.5 + 0.5) * 0.25 - 0.12);
	float a = dentro * (radiale * pow(lungo, 1.5) * fibra * sfrangia + filo * lungo * 1.8);
	ALBEDO = mix(colore.rgb, vec3(1.0), filo * 0.7 + pow(lungo, 6.0) * 0.5) * 1.8;
	ALPHA = clamp(a, 0.0, 1.0) * colore.a * (1.0 - smoothstep(0.75, 1.0, fase));
}
