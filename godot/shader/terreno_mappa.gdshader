shader_type spatial;
// Terreno dipinto delle mappe lontane (Selva, Distesa, Arena): i colori arrivano dal tema della mappa
// (shared/mappe.js), i pesi dei materiali si calcolano qui da pendenza, quota e rumore (nessuna texture esterna).
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 suolo_a : source_color = vec3(0.12, 0.2, 0.08);   // tono scuro del suolo
uniform vec3 suolo_b : source_color = vec3(0.2, 0.3, 0.12);    // tono chiaro del suolo
uniform vec3 macchie : source_color = vec3(0.4, 0.4, 0.2);     // chiazze (foglie secche, sabbia chiara)
uniform vec3 terra : source_color = vec3(0.3, 0.22, 0.14);     // terra battuta e sentiero
uniform vec3 roccia : source_color = vec3(0.3, 0.3, 0.28);
uniform vec3 lastrico : source_color = vec3(0.45, 0.42, 0.38); // spiazzo dell'arrivo
uniform vec2 centro = vec2(0.0);       // centro della mappa (mondo)
uniform vec2 arrivo = vec2(0.0);       // spiazzo dell'arrivo (mondo)
uniform float raggio_arrivo = 0.0;     // 0 = nessuno spiazzo
uniform float sentiero = 0.0;          // 1 = sentiero dall'arrivo verso il centro
uniform float dune = 0.0;              // 1 = increspature del vento sulla sabbia
uniform float quota_roccia = 30.0;     // sopra questa quota il suolo diventa roccia

varying vec3 pm;
varying vec3 nm;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float rum(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return rum(p) * 0.5 + rum(p * 2.03 + 7.1) * 0.3 + rum(p * 4.1 + 3.7) * 0.2; }
float pennello(vec2 p, float scala) {
	float a = rum(p * 0.03) * 6.283;
	vec2 d = vec2(cos(a), sin(a));
	vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
	return rum(q * vec2(0.8, 1.5) * scala) * 0.6 + rum(q * vec2(2.1, 3.3) * scala + 5.0) * 0.4;
}
vec2 ciottoli(vec2 p) {
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
vec3 rilievo(vec3 n, vec3 pos, float h, float forza) {
	vec3 dpx = dFdx(pos), dpy = dFdy(pos);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - forza * grad);
}

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 l = pm.xz - centro;
	vec2 p = l + vec2(37.0, 11.0);   // rumore in coordinate locali: a x = 6000 i numeri del mondo sono troppo grandi
	float grande = fbm(p * 0.04), medio = fbm(p * 0.19), fine = pennello(p, 1.0), finissimo = pennello(p + 31.0, 2.6);
	float lontano = smoothstep(35.0, 140.0, length(VERTEX));
	fine = mix(fine, 0.5, lontano);
	finissimo = mix(finissimo, 0.5, lontano);
	float tratto = smoothstep(0.25, 0.75, fine) * 0.6 + finissimo * 0.4;

	// suolo base: due toni a chiazze larghe, pennellate sopra
	vec3 col = mix(suolo_a, suolo_b, smoothstep(0.3, 0.72, grande));
	col *= 0.86 + 0.26 * (medio * 0.5 + tratto * 0.5);
	// increspature del vento (sabbia): strisce sottili che seguono le dune
	if (dune > 0.5) {
		float onda = sin(dot(p, vec2(0.75, 0.35)) * 1.7 + fbm(p * 0.05) * 9.0);
		col *= 0.93 + 0.09 * smoothstep(-0.2, 0.9, onda) * (1.0 - lontano * 0.7);
	}
	// chiazze (foglie secche nella selva, sabbia chiara nella distesa)
	float wm = smoothstep(0.52, 0.68, fbm(p * 0.03 + 11.0)) * 0.85;
	col = mix(col, macchie * (0.85 + 0.3 * tratto), wm);
	// terra battuta a chiazze e sentiero serpeggiante dall'arrivo verso il centro
	float wt = smoothstep(0.62, 0.74, fbm(p * 0.06 - 4.0)) * 0.7;
	if (sentiero > 0.5) {
		float scarto = abs(l.x - sin(l.y * 0.03) * 10.0);
		float lungo = step(arrivo.y - centro.y, l.y) * step(l.y, 30.0);
		wt = max(wt, (1.0 - smoothstep(1.6, 3.2 + medio * 1.2, scarto)) * lungo * 0.9);
	}
	col = mix(col, terra * (0.85 + 0.3 * tratto), wt);
	// roccia sui pendii ripidi e in quota
	float pend = 1.0 - clamp(nm.y, 0.0, 1.0);
	float venatura = fbm(vec2(p.x + p.y, pm.y * 3.0) * 0.35);
	float wr = clamp(smoothstep(0.18, 0.38, pend + (medio - 0.5) * 0.1) + smoothstep(quota_roccia, quota_roccia + 8.0, pm.y), 0.0, 1.0);
	vec3 pietra = roccia * (0.75 + 0.5 * venatura) * (0.85 + 0.3 * finissimo);
	col = mix(col, pietra, wr);
	// spiazzo lastricato all'arrivo
	float wl = 0.0;
	vec2 c = ciottoli(p * 1.4);
	if (raggio_arrivo > 0.0) {
		float da = length(pm.xz - arrivo);
		wl = 1.0 - smoothstep(raggio_arrivo - 3.0 + medio * 2.0, raggio_arrivo + 1.0 + medio * 2.0, da);
		vec3 lastre = lastrico * mix(0.8, 1.15, c.y) * (0.92 + 0.16 * medio);
		lastre = mix(lastrico * 0.55, lastre, smoothstep(0.02, 0.09, c.x));
		col = mix(col, lastre, wl);
	}

	ALBEDO = col;
	float alt = (1.0 - wl) * (tratto * 0.35 + medio * 0.25) + wr * venatura * 0.8 + wl * smoothstep(0.0, 0.14, c.x) * 0.9;
	NORMAL = rilievo(NORMAL, VERTEX, alt, 0.035 * (1.0 - lontano));
	ROUGHNESS = mix(0.95, 0.8, wl);
	SPECULAR = dune > 0.5 ? 0.18 : 0.25;
}
