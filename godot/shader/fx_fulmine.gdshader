shader_type spatial;
// Saetta: una linea spezzata luminosa su un rettangolo verticale sempre rivolto alla visuale.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 colore : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float fase = 0.0;
uniform float seme = 0.0;
float h11(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float spezzata(float y, float s) {
	float i = floor(y), f = fract(y);
	return mix(h11(i + s), h11(i + 1.0 + s), f) - 0.5;
}
void vertex() {
	// ruota attorno all'asse verticale per guardare la visuale
	vec3 verso = normalize(vec3(INV_VIEW_MATRIX[3].x - MODEL_MATRIX[3].x, 0.0, INV_VIEW_MATRIX[3].z - MODEL_MATRIX[3].z));
	vec3 lato = normalize(cross(vec3(0.0, 1.0, 0.0), verso));
	mat4 m = mat4(vec4(lato * length(MODEL_MATRIX[0].xyz), 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(verso, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}
void fragment() {
	float guizzo = floor(fase * 7.0);
	float y = UV.y;
	float stretta = smoothstep(0.0, 0.25, 1.0 - y);        // in basso converge sul punto colpito
	float dev = (spezzata(y * 9.0, seme + guizzo * 3.1) * 0.34 + spezzata(y * 27.0, seme + 7.0 + guizzo) * 0.10) * stretta;
	float dx = abs(UV.x - 0.5 - dev);
	float nucleo = 0.012 / (dx + 0.004);
	// rami secondari
	float dev2 = dev + (spezzata(y * 6.0, seme + 31.0) * 0.5) * smoothstep(0.35, 0.7, y) * step(y, 0.8);
	float ramo = 0.004 / (abs(UV.x - 0.5 - dev2) + 0.004) * step(0.3, y);
	float calato = step(1.0 - smoothstep(0.0, 0.12, fase), y);     // la saetta scende dall'alto
	float vita = 1.0 - smoothstep(0.45, 1.0, fase);
	float lamp = 0.65 + 0.35 * step(0.5, fract(fase * 9.0));
	float a = clamp((nucleo + ramo * 0.6) * calato * vita * lamp, 0.0, 4.0) * smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = mix(colore.rgb, vec3(1.0), clamp(nucleo * 0.25, 0.0, 1.0)) * 2.0;
	ALPHA = clamp(a, 0.0, 1.0) * colore.a;
}
