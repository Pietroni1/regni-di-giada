shader_type spatial;
// Ciò che riempie i vuoti delle Prove. tipo 0 = lava (lago, canali, cascate): croste scure che scorrono su vene
// incandescenti; tipo 1 = abisso: buio con veli di nebbia che passano lenti. Senza luce: si illumina da sé.
render_mode unshaded, cull_disabled;
#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(1.0, 0.36, 0.06);
uniform int tipo = 0;
uniform vec3 origine = vec3(0.0);
uniform vec2 scorre = vec2(0.0, 0.05);      // verso e velocità della corrente (metri al secondo, già in scala)
uniform float forza = 1.0;
uniform vec2 scala = vec2(0.16, 0.16);    // grandezza delle croste (più alto = più fitte); nelle cascate è stirata in verticale
varying vec3 pm;
varying vec3 nm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - origine;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = piano(pm, nm);
	if (tipo == 1) {
		float velo = fbm(uv * 0.07 + vec2(TIME * 0.012, -TIME * 0.008)) * fbm(uv * 0.19 - vec2(TIME * 0.02, 0.0));
		ALBEDO = colore * (0.02 + 0.5 * smoothstep(0.12, 0.5, velo));
	} else {
		vec2 q = uv * scala + scorre * TIME;
		q += vec2(fbm(q * 1.7 + TIME * 0.03), fbm(q * 1.7 + 4.0 - TIME * 0.025)) * 0.55;
		vec2 c = celle(q * 2.2);
		float crosta = smoothstep(0.03, 0.3, c.x) * (0.75 + 0.25 * c.y);
		float caldo = fbm(q * 3.1 - scorre * TIME * 2.0);
		vec3 vena = mix(colore, vec3(1.0, 0.86, 0.45), smoothstep(0.45, 0.9, caldo) * (1.0 - crosta));
		vec3 scuro = colore * vec3(0.16, 0.07, 0.05) * (0.6 + 0.8 * caldo);
		ALBEDO = mix(vena * (1.5 + 0.5 * sin(TIME * 0.8 + c.y * 12.0)), scuro, crosta) * forza;
	}
}
