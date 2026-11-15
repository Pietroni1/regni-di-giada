shader_type spatial;
// Pietre luminose dei completi alti: luce interna che pulsa piano e riflesso sul bordo.
// Intensità bassa: col bagliore (glow) fanno un alone leggero, non un faro.
render_mode diffuse_burley, cull_disabled;

uniform vec3 colore : source_color = vec3(1.0, 0.5, 0.1);
uniform float forza = 1.6;

void fragment() {
	float bordo = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float battito = 0.8 + 0.2 * sin(TIME * 2.2 + NODE_POSITION_WORLD.x * 3.0);
	ALBEDO = colore * 0.5;
	EMISSION = colore * forza * battito * (0.7 + 0.6 * bordo);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
