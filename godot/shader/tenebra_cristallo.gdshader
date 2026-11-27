shader_type spatial;
// Cristalli luminosi dello stile «tenebra»: luce propria nel colore dell'istanza, venature che scorrono, spigoli accesi.
render_mode unshaded, shadows_disabled;
#include "res://shader/comune.gdshaderinc"
varying vec3 pm;
varying vec3 tinta;

void vertex() {
	pm = VERTEX;
	tinta = COLOR.rgb;
}

void fragment() {
	float spigolo = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float vena = fbm(vec2(pm.x * 3.0 + pm.z * 2.0, pm.y * 1.4 - TIME * 0.25));
	float l = 0.35 + 0.9 * smoothstep(0.35, 0.75, vena) + spigolo * 1.4;
	l *= 0.85 + 0.15 * sin(TIME * 1.3 + pm.x * 2.0);
	ALBEDO = tinta * l + vec3(1.0) * spigolo * spigolo * 0.5;
}
