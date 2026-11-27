shader_type spatial;
// Acqua: onde leggere sulla normale, più trasparente a riva.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 colore : source_color = vec3(0.10, 0.33, 0.42);

varying vec3 pm;

float onda(vec2 p, float t) { return sin(p.x * 0.9 + t) * 0.5 + sin(p.y * 1.3 - t * 0.8) * 0.3 + sin((p.x + p.y) * 2.1 + t * 1.7) * 0.2; }

void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float e = 0.15;
	float h = onda(pm.xz, TIME), hx = onda(pm.xz + vec2(e, 0.0), TIME), hz = onda(pm.xz + vec2(0.0, e), TIME);
	vec3 n = normalize(vec3((h - hx) * 0.5, 1.0, (h - hz) * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = colore;
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.6;
	ALPHA = 0.86;
}
