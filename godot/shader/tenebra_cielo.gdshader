shader_type spatial;
// Cielo dello stile «tenebra»: una cupola che segue la visuale. Fasce di nubi che scorrono, un astro (eclissi con la
// corona frastagliata, oppure una luna) e all'orizzonte la sagoma nera di guglie e torri lontane.
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 alto : source_color = vec3(0.10, 0.03, 0.30);
uniform vec3 basso : source_color = vec3(0.85, 0.08, 0.12);
uniform vec3 nubi : source_color = vec3(0.45, 0.18, 0.95);
uniform vec3 astro : source_color = vec3(1.0, 0.2, 0.12);
uniform vec3 astro_dir = vec3(0.5, 0.42, 0.6);
uniform float tipo = 0.0;                  // 0 eclissi, 1 luna
uniform float stelle = 0.35;
varying vec3 dir;

void vertex() { dir = VERTEX; }

float guglie(float az, float fitte, float seme) {
	float n = az * fitte;
	float id = floor(n);
	float f = fract(n) - 0.5;
	float chi = h21(vec2(id, seme));
	float alta = chi * chi;
	// una torre ogni tanto, il resto è un profilo basso e rotto
	float torre = step(0.72, chi) * max(0.0, 1.0 - abs(f) * (5.0 + 6.0 * h21(vec2(id, seme + 3.0)))) * (0.4 + 0.6 * alta);
	float merli = step(0.5, fract(n * 6.0)) * 0.012 * step(abs(f), 0.14) * step(0.72, chi);
	return 0.012 + 0.02 * rum(vec2(n * 1.7, seme)) + torre * 0.13 + merli;
}

void fragment() {
	vec3 d = normalize(dir);
	float y = d.y;
	vec3 col = mix(basso, alto, smoothstep(-0.02, 0.55, y));
	// nubi a fasce: più strette verso l'orizzonte
	vec2 uv = d.xz / (max(y, 0.0) + 0.22);
	float n = fbm(uv * vec2(0.8, 2.4) + vec2(TIME * 0.012, TIME * 0.004));
	float n2 = fbm(uv * 3.3 - vec2(TIME * 0.02, 0.0));
	float c = smoothstep(0.4, 0.74, n * 0.7 + n2 * 0.3);
	col = mix(col, nubi, c * smoothstep(0.0, 0.22, y) * 0.85);
	col *= 1.0 - 0.45 * smoothstep(0.55, 0.85, n2) * smoothstep(0.05, 0.3, y);
	// stelle rade in alto
	vec2 sg = d.xz / (abs(y) + 0.4) * 60.0;
	float st = step(0.985, h21(floor(sg))) * smoothstep(0.35, 0.0, length(fract(sg) - 0.5)) * smoothstep(0.25, 0.7, y) * (1.0 - c);
	col += vec3(st) * stelle;
	// l'astro
	vec3 a = normalize(astro_dir);
	float ang = acos(clamp(dot(d, a), -1.0, 1.0));
	vec3 t1 = normalize(cross(a, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(a, t1);
	vec2 giro = normalize(vec2(dot(d, t1), dot(d, t2)) + 1e-5);
	float R = 0.135;
	if (tipo < 0.5) {
		float raggi = 0.65 + 0.7 * rum(giro * 3.0 + TIME * 0.08) + 0.3 * rum(giro * 11.0 - TIME * 0.2);
		float corona = exp(-max(ang - R, 0.0) * 7.0 / raggi);
		col = mix(col, astro * 1.6 + vec3(0.5, 0.3, 0.2) * corona, clamp(corona * 1.3, 0.0, 1.0));
		float orlo = R * (0.97 + 0.06 * rum(giro * 7.0 + 4.0));
		col = mix(col, vec3(0.03, 0.0, 0.01) + astro * 0.04 * fbm(giro * 4.0 + ang * 30.0), smoothstep(orlo, orlo * 0.93, ang));
	} else {
		float Rl = R * 0.5;
		col += astro * exp(-max(ang - Rl, 0.0) * 13.0) * 0.55;
		vec3 luna = astro * (0.62 + 0.45 * fbm(giro * 2.3 * ang / Rl + 3.0));
		col = mix(col, luna, smoothstep(Rl, Rl * 0.95, ang));
	}
	// guglie nere all'orizzonte, su due piani
	float az = atan(d.z, d.x);
	float g2 = guglie(az, 34.0, 7.0) * 0.7;
	col = mix(col, mix(basso, vec3(0.0), 0.72), step(y, g2));
	float g1 = guglie(az + 0.37, 21.0, 2.0);
	col = mix(col, vec3(0.012, 0.0, 0.02), step(y, g1));
	ALBEDO = col;
}
