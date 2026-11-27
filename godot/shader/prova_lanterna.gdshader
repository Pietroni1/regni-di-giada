shader_type spatial;
// Le mille lanterne della Cripta (e i lumi appesi delle altre Prove): carta accesa da dentro, senza luce dinamica.
// In MultiMesh: il colore dell'istanza è quello del lume, l'alfa quanto è acceso.
render_mode unshaded, cull_disabled;

uniform float forza = 1.7;
varying float seme;
varying float quota;

void vertex() {
	seme = float(INSTANCE_ID) * 1.37;
	quota = VERTEX.y + 0.5;
	// pancia della lanterna: più larga a metà, stretta alle due bocche
	VERTEX.xz *= 1.0 - 0.42 * pow(abs(VERTEX.y) * 2.0, 2.2);
}

void fragment() {
	float y = 1.0 - quota;                                 // 0 in cima, 1 in fondo
	float corpo = smoothstep(0.03, 0.14, y) * smoothstep(0.97, 0.86, y);
	float costole = 0.82 + 0.18 * smoothstep(0.35, 0.5, abs(fract(UV.x * 6.0) - 0.5));
	float cuore = 0.55 + 0.45 * smoothstep(0.9, 0.2, abs(y - 0.6) * 2.0);
	float tremolio = 0.88 + 0.12 * sin(TIME * (2.0 + fract(seme) * 2.5) + seme * 9.0);
	vec3 c = COLOR.rgb * corpo * costole * cuore * tremolio * forza * COLOR.a;
	ALBEDO = c + vec3(0.05, 0.03, 0.02) * (1.0 - corpo);
}
