// Funzioni comuni delle texture dipinte da codice: rumore, pennellate e rilievo dalla sola altezza.

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return rum(p) * 0.5 + rum(p * 2.03 + 7.1) * 0.3 + rum(p * 4.1 + 3.7) * 0.2; }
float h31(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float rum3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm3(vec3 p) { return rum3(p) * 0.5 + rum3(p * 2.03 + 7.1) * 0.3 + rum3(p * 4.1 + 3.7) * 0.2; }

// Celle di Voronoi: x = distanza dal bordo più vicino, y = numero casuale della cella.
vec2 celle(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(h21(i + g), h21(i + g + 17.0)) * 0.8 + 0.1;
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = h21(i + g + 3.0); } else if (d < d2) d2 = d;
	}
	return vec2(d2 - d1, id);
}

// Normale inclinata secondo un'altezza calcolata nel frammento (derivate sullo schermo): dà rilievo senza mappe.
// n: normale e pos: posizione, entrambe nello spazio della visuale; h: altezza; forza: quanto sporge.
vec3 rilievo(vec3 n, vec3 pos, float h, float forza) {
	vec3 dpx = dFdx(pos), dpy = dFdy(pos);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - forza * grad);
}

// Coordinate «a tre piani»: sceglie le due coordinate del mondo più adatte alla faccia (muri, pavimenti).
vec2 piano(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) return p.xz;
	if (a.x > a.z) return p.zy;
	return p.xy;
}
