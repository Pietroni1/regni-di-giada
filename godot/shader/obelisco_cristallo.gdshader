shader_type spatial;
// Scheggia di cristallo dell'obelisco: faccette lucide, luce interna che pulsa, bordo acceso.
render_mode diffuse_burley;

uniform vec3 energia : source_color = vec3(0.7, 0.3, 1.0);
uniform float luce = 1.0;
uniform float colpo = 0.0;
varying float alt;

void vertex() {
	alt = VERTEX.y;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float faccia = 0.5 + 0.5 * sin(TIME * 2.0 + alt * 6.0);
	vec3 calda = mix(energia, vec3(1.0), 0.35);
	ALBEDO = energia * 0.15;
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
	EMISSION = (energia * (0.55 + 0.5 * faccia) + calda * f * 1.4) * luce + energia * colpo;
}
