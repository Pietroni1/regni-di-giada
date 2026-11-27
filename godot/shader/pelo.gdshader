shader_type spatial;
// Pelo degli animali: dorso più scuro, ventre più chiaro e striature lungo il corpo, calcolati nello spazio del modello.
render_mode diffuse_burley;

uniform vec3 colore : source_color = vec3(0.45, 0.43, 0.42);
uniform float strisce = 0.0;       // 1 = mantello tigrato

varying vec3 pl;
varying vec3 nl;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
}

void fragment() {
	float sopra = smoothstep(-0.5, 0.7, nl.y);                       // 0 ventre, 1 dorso
	float ciuffi = rum(vec2(pl.x * 26.0 + pl.y * 9.0, pl.z * 5.0)) * 0.6 + rum(pl.xz * 60.0) * 0.4;
	vec3 c = mix(colore * 1.45 + 0.06, colore * 0.72, sopra);
	c *= 0.82 + 0.36 * ciuffi;
	float tigre = smoothstep(0.55, 0.7, rum(vec2(pl.z * 7.0 + sin(pl.y * 6.0) * 0.6, pl.y * 1.5))) * sopra * strisce;
	c = mix(c, vec3(0.05, 0.04, 0.04), tigre * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
