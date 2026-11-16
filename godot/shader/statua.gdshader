shader_type spatial;
// Guerrieri-statua: tutto il corpo (pelle, vesti, corazza) diventa argilla cotta, bronzo o arenaria, con macchie,
// crepe e scheggiature. Dalle crepe può filtrare una luce (élite, custodi). L'occlusione dei completi (COLOR) scurisce gli incavi.
// materia: 0 argilla (terracotta con resti di colore), 1 bronzo (patina verde negli incavi), 2 arenaria (strati), 3 pietra scura.
render_mode diffuse_burley;

#include "res://shader/comune.gdshaderinc"

uniform vec3 colore : source_color = vec3(0.62, 0.36, 0.24);
uniform int materia = 0;
uniform vec3 crepe_col : source_color = vec3(1.0, 0.45, 0.1);
uniform float crepe_luce = 0.0;
uniform float crepe = 1.0;         // quante crepe
uniform float oro = 0.0;           // foglia d'oro sui rilievi (campioni)

varying vec3 pl;
varying vec3 nl;
varying float occl;

void vertex() {
	pl = VERTEX;
	nl = NORMAL;
	occl = COLOR.r;
}

void fragment() {
	vec2 p = piano(pl, nl);
	float m = fbm3(pl * 6.0);
	float fine = rum3(pl * 40.0);
	vec3 c = colore * (0.78 + 0.35 * m) * (0.92 + 0.12 * fine);
	float rough = 0.85;
	float metal = 0.0;
	if (materia == 0) {
		// resti della pittura antica: chiazze sbiadite rosse e verdi
		float vernice = smoothstep(0.62, 0.7, fbm3(pl * 3.0 + 11.0));
		c = mix(c, mix(vec3(0.55, 0.16, 0.1), vec3(0.2, 0.35, 0.28), step(0.5, rum3(floor(pl * 3.0)))), vernice * 0.45);
	} else if (materia == 1) {
		float patina = smoothstep(0.45, 0.75, fbm3(pl * 5.0 + 3.0)) * (0.5 + 0.5 * (1.0 - occl));
		c = mix(c, vec3(0.22, 0.48, 0.4), patina * 0.75);
		rough = mix(0.35, 0.8, patina);
		metal = mix(0.75, 0.1, patina);
	} else if (materia == 2) {
		float strati = 0.5 + 0.5 * sin(pl.y * 55.0 + m * 6.0);
		c *= 0.88 + 0.16 * strati;
	} else {
		c *= 0.85 + 0.2 * fine;
	}
	// crepe e scheggiature
	vec2 v = celle(p * 5.0 + m * 0.6);
	float crepa = smoothstep(0.03, 0.0, v.x) * step(0.62, v.y) * crepe;
	float scheggia = smoothstep(0.7, 0.75, fbm3(pl * 9.0 + 5.0)) * crepe;
	c = mix(c, c * 0.3, crepa);
	c = mix(c, c * 1.25 + 0.04, scheggia * 0.6);
	// foglia d'oro sugli spigoli in alto
	float foglia = oro * smoothstep(0.55, 0.65, fbm3(pl * 4.0 + 2.0)) * smoothstep(0.0, 0.5, nl.y + 0.3);
	c = mix(c, vec3(0.95, 0.72, 0.3), foglia);
	metal = mix(metal, 0.9, foglia);
	rough = mix(rough, 0.3, foglia);
	float ao = mix(1.0, occl, 0.8);
	ALBEDO = c * (0.45 + 0.55 * ao);
	NORMAL = rilievo(NORMAL, VERTEX, -crepa * 0.6 + m * 0.4 + fine * 0.15, 0.04);
	EMISSION = crepe_col * crepe_luce * crepa * (0.75 + 0.25 * sin(TIME * 2.0 + m * 6.0));
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
