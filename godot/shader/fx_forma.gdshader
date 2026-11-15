shader_type spatial;
// Segni luminosi a terra o in aria, uno per tema: mirino, fiore di loto, costellazione, sigillo di giada, impronta di palmo,
// spirale di vento, stella a otto punte. Si accendono, restano un momento e svaniscono (fase 0 → 1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(1.0);
uniform vec4 colore2 : source_color = vec4(1.0);
uniform float fase = 0.0;
uniform int forma = 0;
uniform float seme = 0.0;

float h11(float p) { return fract(sin(p * 127.1 + 31.7) * 43758.5453); }
float tratto(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}
float anello(float d, float r, float w) { return smoothstep(w, 0.0, abs(d - r)); }
vec2 ruota(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(p.x * c - p.y * s, p.x * s + p.y * c); }

// una corona di otto petali
float fiore(vec2 p, float R, float rot) {
	float d = length(p);
	float a = atan(p.y, p.x) + rot;
	float lobo = pow(abs(cos(4.0 * a)), 0.8);
	float Rl = R * lobo;
	float riempi = 1.0 - smoothstep(Rl - 0.03, Rl, d);
	float contorno = smoothstep(Rl - 0.13, Rl - 0.02, d) * riempi;
	return riempi * 0.22 + contorno * 0.95;
}

vec2 stella(int i) {
	float fi = float(i);
	float a = fi * 0.95 + seme + h11(fi + seme) * 0.9;
	float r = 0.32 + 0.52 * h11(fi * 3.7 + seme);
	return vec2(cos(a), sin(a)) * r;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float vita = smoothstep(0.0, 0.12, fase) * (1.0 - smoothstep(0.65, 1.0, fase));
	float v = 0.0;      // intensità
	float chiaro = 0.0; // quanto tirare verso il secondo colore
	if (forma == 0) {
		// mirino: l'anello si stringe sul bersaglio, quattro tacche, rombo al centro
		float rr = mix(1.0, 0.8, smoothstep(0.0, 0.35, fase));
		vec2 q = ruota(p, fase * 1.4);
		v = anello(d, rr * 0.92, 0.04) + anello(d, rr * 0.5, 0.02) * 0.7;
		float t = step(abs(q.x), 0.03) * step(0.55, abs(q.y)) * step(abs(q.y), 0.98) + step(abs(q.y), 0.03) * step(0.55, abs(q.x)) * step(abs(q.x), 0.98);
		v += t;
		v += step(abs(q.x) + abs(q.y), 0.09) * 1.2;
		chiaro = step(abs(q.x) + abs(q.y), 0.09) + t * 0.5;
	} else if (forma == 1) {
		// loto che sboccia: tre corone di petali, la più interna chiara
		float b = mix(0.2, 1.0, smoothstep(0.0, 0.45, fase));
		v = fiore(p, 0.97 * b, 0.0) + fiore(p, 0.66 * b, 0.3927) * 0.9 + fiore(p, 0.36 * b, 0.0) * 0.9;
		v += (1.0 - smoothstep(0.0, 0.12 * b, d)) * 0.8;
		chiaro = (1.0 - smoothstep(0.0, 0.62, d)) * 0.8;
	} else if (forma == 2) {
		// costellazione: sette stelle unite una dopo l'altra da linee che si tracciano
		float rev = clamp(fase * 8.0, 0.0, 7.0);
		for (int i = 0; i < 6; i++) {
			vec2 a = stella(i), b = stella(i + 1);
			float t = clamp(rev - float(i), 0.0, 1.0);
			v += tratto(p, a, mix(a, b, t), 0.024) * 1.1;
		}
		v += tratto(p, stella(2), mix(stella(2), stella(5), clamp(rev - 6.0, 0.0, 1.0)), 0.02) * 0.8;
		for (int i = 0; i < 7; i++) {
			vec2 s = stella(i);
			float acceso = step(float(i) - 0.5, rev);
			float tw = 0.75 + 0.25 * sin(TIME * 7.0 + float(i) * 2.1);
			float dd = length(p - s);
			float nucleo = smoothstep(0.09, 0.0, dd);
			float croce = tratto(p, s - vec2(0.16, 0.0), s + vec2(0.16, 0.0), 0.016) + tratto(p, s - vec2(0.0, 0.16), s + vec2(0.0, 0.16), 0.016);
			v += (nucleo * 1.4 + croce * 0.9 + 0.012 / (dd * dd + 0.012) * 0.12) * acceso * tw;
			chiaro += nucleo * acceso;
		}
		v += anello(d, 0.95, 0.03) * 0.9 + anello(d, 0.9, 0.012) * 0.5;
	} else if (forma == 3) {
		// sigillo di giada: due cerchi, un rombo, otto monete attorno, il cerchio centrale
		vec2 q = ruota(p, TIME * 0.35);
		v = anello(d, 0.94, 0.022) + anello(d, 0.8, 0.012);
		v += smoothstep(0.02, 0.0, abs(abs(q.x) + abs(q.y) - 0.62)) * 0.9;
		float ang = atan(q.y, q.x);
		float sett = floor((ang + 3.14159) / 6.2832 * 8.0);
		float ac = (sett + 0.5) / 8.0 * 6.2832 - 3.14159;
		vec2 c = vec2(cos(ac), sin(ac)) * 0.7;
		float moneta = anello(length(q - c), 0.085, 0.014) + (1.0 - smoothstep(0.0, 0.03, length(q - c))) * 0.6;
		v += moneta * step(0.6, d) * step(d, 0.8);
		v += anello(d, 0.2, 0.015) + (1.0 - smoothstep(0.0, 0.08, d));
		chiaro = anello(d, 0.2, 0.05) + moneta;
	} else if (forma == 4) {
		// impronta di palmo: la mano che ha colpito, con le dita aperte
		float pop = mix(0.78, 1.0, smoothstep(0.0, 0.2, fase));
		vec2 q = p / pop;
		float sd = (length((q - vec2(0.0, -0.22)) / vec2(0.36, 0.42)) - 1.0) * 0.38;
		float lun[4] = float[4](0.3, 0.42, 0.38, 0.27);
		for (int i = 0; i < 4; i++) {
			float x = -0.255 + float(i) * 0.17;
			vec2 a = vec2(x, 0.04), b = vec2(x * 1.12, 0.04 + lun[i]);
			vec2 pa = q - a, ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			sd = min(sd, length(pa - ba * h) - 0.066);
		}
		{
			vec2 a = vec2(-0.3, -0.2), b = vec2(-0.62, 0.02);
			vec2 pa = q - a, ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			sd = min(sd, length(pa - ba * h) - 0.078);
		}
		float riempi = 1.0 - smoothstep(-0.005, 0.012, sd);
		float bordo = smoothstep(0.045, 0.0, abs(sd + 0.02));
		v = riempi * 0.3 + bordo * 0.9;
		chiaro = bordo * 0.8;
	} else if (forma == 5) {
		// spirale di vento: tre bracci che girano e si allargano, trattini d'aria
		float a = atan(p.y, p.x);
		float sp = fract(a / 6.2832 * 3.0 + d * 1.7 - fase * 1.4);
		float braccio = smoothstep(0.2, 0.0, abs(sp - 0.5) - 0.05);
		float trat = 0.55 + 0.45 * step(0.5, fract(d * 15.0 - fase * 4.0 + a));
		float busta = smoothstep(0.08, 0.3, d) * (1.0 - smoothstep(0.72, 1.0, d));
		v = braccio * trat * busta * 1.1 + anello(d, 0.96, 0.02) * 0.5;
		chiaro = braccio * 0.5;
	} else {
		// stella a otto punte dentro a un cerchio
		float a = atan(p.y, p.x) + TIME * 0.25;
		float rs = 0.38 + 0.52 * pow(abs(cos(4.0 * a)), 5.0);
		v = smoothstep(0.03, 0.0, abs(d - rs)) + anello(d, 0.96, 0.02) * 0.8 + anello(d, 0.3, 0.012);
		v += (1.0 - smoothstep(0.0, 0.1, d)) * 0.9;
		chiaro = (1.0 - smoothstep(0.0, 0.5, d));
	}
	ALBEDO = mix(colore.rgb, colore2.rgb, clamp(chiaro, 0.0, 1.0)) * 1.5;
	ALPHA = clamp(v, 0.0, 1.0) * vita * colore.a;
}
