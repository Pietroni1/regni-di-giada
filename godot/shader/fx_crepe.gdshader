shader_type spatial;
// Crepe incandescenti nel terreno dopo un colpo: celle di Voronoi i cui bordi brillano dal centro verso fuori e poi si spengono.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float fase = 0.0;
uniform float seme = 0.0;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	vec2 g = p * 4.5 + seme;
	vec2 i = floor(g), f = fract(g);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 c = o + vec2(h21(i + o), h21(i + o + 7.0)) - f;
		float dd = dot(c, c);
		if (dd < d1) { d2 = d1; d1 = dd; } else if (dd < d2) d2 = dd;
	}
	float bordo = sqrt(d2) - sqrt(d1);
	float crepa = 1.0 - smoothstep(0.0, 0.07 + 0.1 * (1.0 - d), bordo);
	float fronte = smoothstep(0.0, 0.18, fase) ;                       // le crepe corrono verso l'esterno
	float raggiunto = 1.0 - smoothstep(fronte * 1.2 - 0.25, fronte * 1.2, d);
	float vita = 1.0 - smoothstep(0.35, 1.0, fase);
	float centro = (1.0 - smoothstep(0.0, 0.45, d)) * 0.2 * (1.0 - smoothstep(0.0, 0.4, fase));
	float a = (crepa * raggiunto * (1.0 - smoothstep(0.75, 1.0, d)) + centro) * vita;
	ALBEDO = mix(colore.rgb, vec3(1.0), crepa * (1.0 - d) * 0.35 * vita) * 1.4;
	ALPHA = clamp(a, 0.0, 1.0) * colore.a;
}
