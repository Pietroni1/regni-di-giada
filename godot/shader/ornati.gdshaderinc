// Ornamenti dei completi (tools/blender/completi.py): motivi lungo gli orli, letti dalla seconda UV «Orlo»
// (x = metri lungo l'orlo, y = metri dall'orlo) e occlusione dipinta nel colore dei vertici (rosso).
// Tutto aritmetica semplice: niente rumore, niente cicli.

// Linea sottile attorno a v = 0 (larghezza w nelle stesse unità), sfumata sui pixel.
float linea(float v, float w) {
	float f = fwidth(v) + 1e-5;
	return 1.0 - smoothstep(w, w + f, abs(v));
}

// Motivo della classe in una fascia: p.x lungo l'orlo (in periodi), p.y attraverso la fascia 0..1. Ritorna 0..1.
// 0 Lama: onde che si arricciano in nuvole; 1 Ombra: denti di sega; 2 Monaco: grani tondi infilati;
// 3 Mistico: rombi intrecciati con un punto (ricamo); altro: niente.
float motivo(int m, vec2 p) {
	float x = fract(p.x);
	float y = p.y;
	if (m == 0) {
		float onda = linea(y - 0.5 - 0.28 * sin(6.2832 * p.x), 0.07);
		float ric = linea(length(vec2(x - 0.25, (y - 0.62) * 1.2)) - 0.16, 0.05) * step(0.5, y);
		return max(onda, ric);
	}
	if (m == 1) {
		float dente = abs(x * 2.0 - 1.0);
		return max(linea(y - dente * 0.8 - 0.1, 0.06), step(y, dente * 0.8 + 0.1) * 0.35);
	}
	if (m == 2) {
		float r = length(vec2((x - 0.5) * 1.6, y - 0.5));
		return max(max(linea(r - 0.3, 0.06), 1.0 - smoothstep(0.08, 0.12, r)), linea(y - 0.5, 0.03) * step(0.38, r));
	}
	if (m == 3) {
		float rombo = abs(x - 0.5) * 2.0 + abs(y - 0.5) * 2.0;
		float rombo2 = abs(fract(p.x + 0.5) - 0.5) * 2.0 + abs(y - 0.5) * 2.0;
		return max(max(linea(rombo - 0.7, 0.07), linea(rombo2 - 0.7, 0.07) * 0.8), 1.0 - smoothstep(0.1, 0.16, rombo));
	}
	return 0.0;
}

// Fascia ornata vicino all'orlo: da d0 a d0 + largo, con due filetti ai margini. d = distanza dall'orlo, s = lungo l'orlo.
float fascia_ornata(int m, float s, float d, float d0, float largo) {
	if (largo <= 0.0) return 0.0;
	float t = (d - d0) / largo;
	float dentro = step(0.0, t) * step(t, 1.0);
	float fil = linea(t, 0.06) + linea(t - 1.0, 0.06);
	float vis = 1.0 - smoothstep(0.25, 0.6, fwidth(t));        // da lontano il disegno si sfuma
	return clamp(motivo(m, vec2(s / (largo * 1.6), t)) * dentro + fil, 0.0, 1.0) * vis;
}
