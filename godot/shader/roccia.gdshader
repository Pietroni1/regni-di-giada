shader_type spatial;
// Rocce: venature e muschio sulla parte alta, calcolati nello spazio del mondo.
render_mode diffuse_burley;

uniform float muschio_forza = 1.0;     // 0 per i muri della cripta
uniform vec3 tinta : source_color = vec3(1.0);

varying vec3 pm;
varying vec3 nm;

float rh(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float rn(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(rh(i), rh(i + vec3(1, 0, 0)), f.x), mix(rh(i + vec3(0, 1, 0)), rh(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(rh(i + vec3(0, 0, 1)), rh(i + vec3(1, 0, 1)), f.x), mix(rh(i + vec3(0, 1, 1)), rh(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = rn(pm * 1.4) * 0.55 + rn(pm * 4.1) * 0.3 + rn(pm * 11.0) * 0.15;
	vec3 c = mix(vec3(0.20, 0.19, 0.18), vec3(0.50, 0.48, 0.44), n);
	c *= 0.8 + 0.35 * clamp(nm.y, 0.0, 1.0);
	float muschio = smoothstep(0.45, 0.85, nm.y) * smoothstep(0.35, 0.65, rn(pm * 0.9));
	ALBEDO = mix(c * tinta, vec3(0.16, 0.29, 0.08), muschio * 0.85 * muschio_forza);
	ROUGHNESS = 0.92;
}
