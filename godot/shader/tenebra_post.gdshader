shader_type canvas_item;
// Stile «tenebra» (prova dark fantasy): passata finale su tutto il 3D, sotto l'interfaccia.
// Pixel un po' grossi, contrasto schiacciato verso il nero, retinatura a scacchi e pochi livelli di colore come nei
// giochi 3D di una volta, bordi scuri. I colori restano quelli del gioco: la tavolozza della zona (ombra → mezzo →
// luce) li vela soltanto (`forza`, circa un quarto). Seconda stesura: la prima ricolorava tutto in due toni e
// all'autore non è piaciuta («tieni i colori come li avevamo prima»), ed era troppo a bassa definizione.
uniform sampler2D schermo : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel = 3.0;                 // lato di un «pixel» in pixel veri
uniform vec3 ombra : source_color = vec3(0.03, 0.0, 0.06);
uniform vec3 mezzo : source_color = vec3(0.36, 0.12, 0.75);
uniform vec3 luce : source_color = vec3(1.0, 0.25, 0.18);
uniform float forza = 0.26;                // quanto la tavolozza sostituisce i colori veri
uniform float contrasto = 1.38;
uniform float soglia = 0.47;               // sotto questa luminanza si va verso il nero (più bassa nei luoghi bui)
uniform float livelli = 22.0;
uniform float bordi = 0.55;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * pixel;
	vec2 cella = floor(SCREEN_UV / px);
	vec2 uv = (cella + 0.5) * px;
	vec3 c = texture(schermo, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float lc = clamp((l - soglia) * contrasto + 0.33, 0.0, 1.0);
	lc = lc * lc * (3.0 - 2.0 * lc);
	// ombra → mezzo per quasi tutta la scala; il tono di luce solo sulle parti più chiare
	vec3 tav = lc < 0.68 ? mix(ombra, mezzo, lc / 0.68) : mix(mezzo, luce, (lc - 0.68) / 0.32);
	// il colore vero, col suo contrasto, per quel che ne resta
	vec3 vero = clamp((c - soglia) * contrasto + 0.33, 0.0, 1.0);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float vivo = smoothstep(0.5, 0.88, sat) * smoothstep(0.55, 0.95, mx);
	vivo *= 1.0 - smoothstep(0.0, 0.12, c.g - max(c.r, c.b));      // il verde dell'erba non è un effetto: segue la tavolozza
	vec3 col = mix(vero, tav, forza * (1.0 - 0.65 * vivo));
	col += c * vivo * 0.08;
	// bordi scuri
	vec2 q = SCREEN_UV - 0.5;
	col = mix(col, ombra * 0.5, bordi * smoothstep(0.35, 0.95, dot(q, q) * 2.2));
	// pochi livelli, con la retinatura a scacchi fra uno e l'altro
	float b = BAYER[int(mod(cella.x, 4.0)) + int(mod(cella.y, 4.0)) * 4] / 16.0;
	col = floor(col * livelli + b) / livelli;
	COLOR = vec4(col, 1.0);
}
