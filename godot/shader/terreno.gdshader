shader_type spatial;
// Terreno dipinto: i pesi dei materiali arrivano da due texture esportate dal server (dati/terreno.bin), i colori da
// texture dipinte ripetibili (texture/terreno.png, generate da tools/godot/texture_terreno.py): costa pochi campionamenti
// al posto del rumore calcolato punto per punto. L'altezza (alfa) fa incastrare i materiali ai confini e dà il rilievo.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D pesi_a : filter_linear, repeat_disable;   // secco, bosco, sabbia, terra
uniform sampler2D pesi_b : filter_linear, repeat_disable;   // roccia, neve, lastricato
uniform sampler2DArray strati : source_color, filter_linear_mipmap_anisotropic, repeat_enable;   // 0 prato … 7 lastricato
uniform sampler2D variazione : filter_linear_mipmap, repeat_enable;
uniform float meta = 300.0;
uniform float passo = 5.0;          // metri coperti da un riquadro di texture

varying vec3 pm;   // posizione nel mondo

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
}

void fragment() {
	vec2 uvm = (pm.xz + meta) / (2.0 * meta);
	vec4 a = texture(pesi_a, uvm);
	vec4 b = texture(pesi_b, uvm);
	vec3 var = texture(variazione, pm.xz / 97.0).rgb;
	vec2 uv = pm.xz / passo;
	vec2 dx = dFdx(uv), dy = dFdy(uv);
	float tot = a.r + a.g + a.b + a.a + b.r + b.g + b.b;
	float pesi[8] = float[8](max(0.0, 1.0 - tot), a.r, a.g, a.b, a.a, b.r, b.g, b.b);
	// si campionano solo i materiali presenti in quel punto (di solito uno o due)
	vec3 col = vec3(0.0);
	float somma = 0.0, alt = 0.0;
	for (int i = 0; i < 8; i++) {
		if (pesi[i] > 0.02) {
			vec4 t = textureGrad(strati, vec3(uv, float(i)), dx, dy);
			// incastro: dove due materiali si incontrano vince quello più «alto» (ciuffi d'erba sopra la terra, lastre sopra l'erba)
			float w = pesi[i] * (0.35 + t.a) * pesi[i];
			col += t.rgb * w;
			alt += t.a * w;
			somma += w;
		}
	}
	col /= max(somma, 1e-4);
	alt /= max(somma, 1e-4);
	// toni che cambiano lentamente su decine di metri: rompono la ripetizione dei riquadri
	col *= 0.78 + 0.44 * var.r;
	col = mix(col, col * vec3(1.12, 1.04, 0.82), (var.g - 0.5) * 0.7 * pesi[0]);
	ALBEDO = col;
	float lontano = smoothstep(30.0, 110.0, length(VERTEX));
	NORMAL = rilievo(NORMAL, VERTEX, alt, 0.05 * (1.0 - lontano));
	ROUGHNESS = mix(0.95, 0.75, b.b);
	SPECULAR = 0.22;
}
