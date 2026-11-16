shader_type spatial;
// Carta della lanterna spiritata: accesa da dentro (più luce al centro), costole di bambù, cuciture, macchie del tempo,
// un volto arrabbiato ritagliato sul davanti (UV.x = giro attorno alla lanterna, 0,25 = davanti; UV.y = dal basso in alto).
// crepe: strappi accesi (lanterne instabili e della cripta); canne: gabbia di canne intrecciate (spiriti del canneto).
render_mode diffuse_burley, cull_disabled;

#include "res://shader/comune.gdshaderinc"

uniform vec3 carta : source_color = vec3(0.95, 0.62, 0.28);
uniform vec3 fiamma : source_color = vec3(1.0, 0.55, 0.15);
uniform float accesa = 1.6;        // forza della luce che passa la carta (0 = spenta)
uniform float crepe = 0.0;
uniform float canne = 0.0;
uniform float tremolio = 0.0;      // luce che vacilla (lanterne instabili)

void fragment() {
	vec2 uv = UV;
	float costole = smoothstep(0.035, 0.0, abs(fract(uv.y * 7.0) - 0.5) - 0.44);
	float cuciture = smoothstep(0.012, 0.0, abs(fract(uv.x * 8.0) - 0.5) - 0.48);
	float cuore = sin(uv.y * 3.14159);                 // più luce a metà altezza
	float macchie = fbm(uv * vec2(9.0, 5.0));
	// volto: due fessure inclinate e una bocca a zig-zag sul davanti
	vec2 f = vec2((fract(uv.x - 0.25 + 0.5) - 0.5) * 6.2832 * 0.34, uv.y - 0.5);
	float occhi = 0.0;
	for (int s = -1; s <= 1; s += 2) {
		vec2 q = f - vec2(float(s) * 0.11, 0.08);
		q.y += float(s) * q.x * 0.55;                  // sopracciglia aggrottate verso il centro
		occhi += smoothstep(0.012, 0.0, abs(q.y) - 0.022 + q.x * q.x * 1.8) * step(abs(q.x), 0.075);
	}
	float zig = abs(fract(f.x * 14.0) - 0.5) * 0.05;
	float bocca = smoothstep(0.012, 0.0, abs(f.y + 0.12 + zig) - 0.018) * step(abs(f.x), 0.15);
	float volto = clamp(occhi + bocca, 0.0, 1.0);
	float strappi = 0.0;
	if (crepe > 0.0) {
		vec2 c = celle(uv * vec2(10.0, 6.0));
		strappi = smoothstep(0.06, 0.0, c.x) * step(0.45, c.y) * crepe;
	}
	float gabbia = 0.0;
	if (canne > 0.0) {
		float a = abs(fract(uv.x * 14.0 + uv.y * 2.0) - 0.5);
		float b = abs(fract(uv.x * 14.0 - uv.y * 2.0) - 0.5);
		gabbia = max(smoothstep(0.1, 0.03, a), smoothstep(0.1, 0.03, b)) * canne;
	}
	float vacilla = 1.0 + tremolio * (rum(vec2(TIME * 13.0, 0.0)) - 0.5) * 0.9;
	float luce = accesa * vacilla * (0.35 + 0.65 * cuore) * (1.0 - 0.45 * costole) * (1.0 - 0.3 * cuciture) * (0.85 + 0.25 * macchie);
	vec3 c = carta * (0.55 + 0.25 * macchie);
	c = mix(c, vec3(0.08, 0.05, 0.04), max(costole * 0.7, gabbia * 0.85));
	c = mix(c, vec3(0.05, 0.02, 0.02), volto * 0.9 * step(0.05, accesa));
	ALBEDO = c;
	vec3 em = carta * fiamma * luce * (1.0 - gabbia * 0.7);
	em += fiamma * (volto * 3.0 + strappi * 2.5) * accesa * vacilla;
	EMISSION = em;
	ROUGHNESS = 0.8;
	SPECULAR = 0.1;
}
