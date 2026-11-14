shader_type spatial;
// Cerchio di rune a terra: anelli, tacche, un doppio triangolo e dodici «glifi» fatti di tratti; ruota e pulsa.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float fase = 0.0;          // 0 → 1 per gli effetti a tempo; resta a 0.5 per quelli fissi
uniform float fisso = 0.0;         // 1 = sempre acceso (aure dell'equipaggiamento)
uniform float giro = 0.35;

float h11(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float anello(float d, float r, float w) { return smoothstep(w, 0.0, abs(d - r)); }
float segmento(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float t = TIME * giro;
	float ca = cos(t), sa = sin(t);
	vec2 q = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
	float d = length(q);
	float ang = atan(q.y, q.x);
	float v = anello(d, 0.94, 0.02) + anello(d, 0.84, 0.012) + anello(d, 0.56, 0.016) + anello(d, 0.48, 0.008);
	// tacche fra i due anelli esterni
	v += smoothstep(0.35, 0.0, abs(fract(ang / 6.2832 * 48.0) - 0.5)) * step(0.85, d) * step(d, 0.93) * 0.6;
	// dodici glifi: ognuno 3 tratti scelti a caso in una celletta
	float settore = floor((ang + 3.14159) / 6.2832 * 12.0);
	float ac = (settore + 0.5) / 12.0 * 6.2832 - 3.14159;
	vec2 c = vec2(cos(ac), sin(ac)) * 0.70;
	vec2 l = q - c;
	l = vec2(l.x * cos(-ac) - l.y * sin(-ac), l.x * sin(-ac) + l.y * cos(-ac)) / 0.075;
	for (int i = 0; i < 3; i++) {
		float s = settore * 7.0 + float(i) * 3.0;
		vec2 a = vec2(h11(s) - 0.5, h11(s + 1.0) - 0.5) * 1.6;
		vec2 b = vec2(h11(s + 2.0) - 0.5, h11(s + 3.0) - 0.5) * 1.6;
		v += segmento(l, a, b, 0.22) * 0.9;
	}
	// doppio triangolo interno, che ruota al contrario
	float cb = cos(-2.0 * t), sb = sin(-2.0 * t);
	vec2 r = vec2(q.x * cb - q.y * sb, q.x * sb + q.y * cb);
	for (int k = 0; k < 2; k++) {
		for (int i = 0; i < 3; i++) {
			float a0 = float(i) / 3.0 * 6.2832 + float(k) * 1.0472;
			float a1 = float(i + 1) / 3.0 * 6.2832 + float(k) * 1.0472;
			v += segmento(r, vec2(cos(a0), sin(a0)) * 0.48, vec2(cos(a1), sin(a1)) * 0.48, 0.012) * 0.8;
		}
	}
	float vita = mix(smoothstep(0.0, 0.15, fase) * (1.0 - smoothstep(0.6, 1.0, fase)), 0.75 + 0.25 * sin(TIME * 2.4), fisso);
	float alone = (1.0 - smoothstep(0.0, 1.0, d)) * 0.12;
	ALBEDO = colore.rgb * 1.7;
	ALPHA = clamp((v + alone) * vita, 0.0, 1.0) * colore.a * step(d, 1.0);
}
