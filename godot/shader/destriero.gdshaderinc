// Destrieri (tools/blender/destrieri.py): mantello dipinto del cavallo e materiali dei finimenti, senza texture.
// UV.x = casella della parte, UV.y = curvatura (pelo) o distanza dal bordo in metri × 2 (finimenti);
// UV2.x = metri lungo il pezzo / 4, UV2.y = occlusione dipinta; colore dei vertici = posizione a riposo
// (x, quota, lunghezza: negativa verso il muso) e, in alfa, quanto il crine è libero (0 radice, 1 punta).
#include "res://shader/comune.gdshaderinc"

// ---- mantello
uniform vec3 pelo : source_color = vec3(0.36, 0.2, 0.1);
uniform vec3 pelo_chiaro : source_color = vec3(0.0);            // ventre e interno delle cosce (nero = dal pelo)
uniform vec3 criniera : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 zoccoli : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 occhi : source_color = vec3(0.05, 0.035, 0.03);
uniform float occhi_luce = 0.0;
uniform vec3 pelle_scura : source_color = vec3(0.07, 0.05, 0.05);  // narici, interno delle orecchie
uniform float punte = 0.0;          // estremità scure (baio): stinchi e muso
uniform vec4 balzane = vec4(0.0);   // quota del bianco sulle quattro zampe (ant. sin., ant. des., post. sin., post. des.)
uniform float stella = 0.0;         // lista bianca sulla fronte (0 niente, 1 lista lunga)
uniform float pomelli = 0.0;        // mantello pomellato
uniform vec3 fronte = vec3(0.0, 2.0, -1.15);     // punti a riposo della classe: fronte e muso
uniform vec3 muso = vec3(0.0, 1.55, -1.45);
// ---- finimenti
uniform vec3 cuoio : source_color = vec3(0.26, 0.15, 0.09);
uniform vec3 metallo : source_color = vec3(0.5, 0.52, 0.56);
uniform vec3 oro : source_color = vec3(0.85, 0.62, 0.25);
uniform vec3 stoffa : source_color = vec3(0.5, 0.12, 0.1);
uniform vec3 regno : source_color = vec3(0.16, 0.42, 0.82);
uniform vec3 lacca : source_color = vec3(0.45, 0.05, 0.04);
uniform vec3 giada : source_color = vec3(0.35, 0.72, 0.55);
uniform vec3 corda : source_color = vec3(0.7, 0.6, 0.42);
uniform vec3 grani : source_color = vec3(0.4, 0.2, 0.1);
uniform vec3 lamelle : source_color = vec3(0.42, 0.06, 0.05);
uniform vec3 carta : source_color = vec3(0.92, 0.86, 0.7);
uniform vec3 ricamo : source_color = vec3(0.85, 0.62, 0.25);
uniform int motivo = 0;             // ornato degli orli: 0 onde (Lama), 1 denti (Ombra), 2 grani (Monaco), 3 rombi (Mistico)
// ---- livello massimo: luce propria di criniera, coda e zoccoli (0 = spenta)
uniform int stile_luce = 0;         // 1 fulmine, 2 ombra, 3 fiamma, 4 astrale
uniform vec3 luce1 : source_color = vec3(0.5, 0.8, 1.0);
uniform vec3 luce2 : source_color = vec3(1.0);
uniform float forza_luce = 0.0;

varying vec3 rp;        // posizione a riposo (x, quota, lunghezza)
varying float libero;

void vertex() {
	rp = vec3(COLOR.r * 2.0 - 1.0, COLOR.g * 2.6, COLOR.b * 3.2 - 1.8);
	libero = COLOR.a;
	// i crini liberi ondeggiano appena (il grosso del movimento è dello scheletro)
	float onda = sin(TIME * 2.3 + rp.y * 5.0 + rp.z * 3.0) * 0.012 + sin(TIME * 5.1 + rp.z * 9.0) * 0.005;
	VERTEX.x += onda * libero;
}

float casella(vec2 uv) { return floor(uv.x * 16.0); }

// bianco di balzane e lista, con il bordo frastagliato
float bianco(vec3 p) {
	float quale = p.z < 0.1 ? (p.x > 0.0 ? balzane.x : balzane.y) : (p.x > 0.0 ? balzane.z : balzane.w);
	float orlo = (rum(vec2(p.x * 40.0, p.z * 40.0)) - 0.5) * 0.05;
	float b = quale > 0.01 ? smoothstep(quale + 0.02, quale - 0.02, p.y + orlo) : 0.0;
	if (stella > 0.0) {
		// lista: dalla fronte verso il muso, stretta, sul lato dorsale della testa
		vec3 asse = normalize(muso - fronte);
		float t = dot(p - fronte, asse);
		float lung = length(muso - fronte);
		vec3 su_asse = fronte + asse * clamp(t, 0.0, lung * (0.25 + 0.6 * stella));
		float dist = length((p - su_asse) * vec3(1.0, 0.45, 0.45));
		float larg = mix(0.05, 0.026, clamp(t / lung, 0.0, 1.0)) * (0.8 + 0.4 * rum(vec2(t * 30.0, 1.0)));
		// solo davanti (il lato dorsale è verso il muso e in alto)
		float dors = dot(p - fronte, normalize(vec3(0.0, -asse.z, asse.y)));
		b = max(b, smoothstep(larg, larg * 0.7, dist) * step(-0.02, dors));
	}
	return b;
}

// materiali: colore, luce propria, ruvidità, metallo
void destriero(vec2 uv, vec2 uv2, vec3 n_vista, vec3 vista, out vec3 alb, out vec3 emi, out float rough, out float metal) {
	float s = casella(uv);
	float ao = uv2.y;
	float lungo = uv2.x * 4.0;
	emi = vec3(0.0);
	rough = 0.85;
	metal = 0.0;
	vec3 c;
	if (s < 0.5) {
		// ---------------- pelo
		c = pelo;
		vec3 chiaro = pelo_chiaro.r + pelo_chiaro.g + pelo_chiaro.b > 0.0 ? pelo_chiaro : pelo * 1.25 + 0.03;
		// ventre e interno delle zampe più chiari, dorso appena più scuro
		float sotto = smoothstep(1.02, 0.86, rp.y) * smoothstep(0.55, 0.8, rp.y) * smoothstep(-0.75, -0.5, rp.z) * smoothstep(0.75, 0.5, rp.z);
		c = mix(c, chiaro, sotto * 0.6);
		c *= mix(1.0, 0.88, smoothstep(1.35, 1.6, rp.y) * smoothstep(-0.6, -0.3, rp.z));
		// pomelli: anelli chiari su groppa, fianchi e spalle
		if (pomelli > 0.0) {
			vec2 q = vec2(rp.z * 12.0 + abs(rp.x) * 6.0, rp.y * 12.0) + 0.6 * vec2(rum(rp.zy * 7.0), rum(rp.yz * 7.0 + 3.0));
			vec2 ce = celle(q);
			float dove = smoothstep(0.85, 1.1, rp.y) * smoothstep(-0.8, -0.45, rp.z);
			c = mix(c, c * 0.84, (1.0 - smoothstep(0.0, 0.32, ce.x)) * dove * pomelli);
			c = mix(c, c * 1.06 + 0.02, smoothstep(0.3, 0.7, ce.x) * dove * pomelli);
		}
		// estremità scure del baio: stinchi, ginocchia, muso, bordo delle orecchie
		float gamba = smoothstep(0.62, 0.38, rp.y + (rum(vec2(rp.x * 30.0, rp.z * 30.0)) - 0.5) * 0.1);
		float verso_muso = 1.0 - smoothstep(0.1, 0.24, length(rp - muso));
		c = mix(c, c * 0.22 + vec3(0.012), max(gamba * punte, verso_muso * (0.45 + 0.4 * punte)));
		c = mix(c, vec3(0.86, 0.84, 0.8), bianco(rp));
		// muso: pelle rosata/grigia attorno alle narici quando c'è la lista
		// pennellate lungo il corpo
		float ciuffi = rum(vec2(rp.z * 30.0 + rp.y * 6.0, rp.y * 14.0 + abs(rp.x) * 20.0)) * 0.6 + rum(vec2(rp.z * 70.0, rp.y * 60.0 + rp.x * 50.0)) * 0.4;
		c *= 0.88 + 0.22 * ciuffi;
		// lucentezza del pelo corto: curvatura e occlusione dipinte
		float cv = (uv.y - 0.5) * 2.0;
		c *= (0.5 + 0.5 * ao) * (1.0 + 0.18 * cv);
		rough = 0.5;
	} else if (s < 1.5) {
		// ---------------- crini: fili lungo la ciocca, radice scura, punta sfibrata
		float filo = rum(vec2(uv.y * 9.0 + rp.z * 70.0 + rp.x * 40.0, lungo * 4.0));
		c = criniera * (0.7 + 0.6 * filo) * (0.75 + 0.25 * uv.y);
		c *= 0.6 + 0.4 * ao;
		rough = 0.45;
		if (stile_luce > 0) {
			float t = TIME;
			float g = 0.0;
			vec3 lc = luce1;
			if (stile_luce == 1) {            // fulmine: fili che si accendono a scatti dalla radice alla punta
				float scatto = step(0.72, rum(vec2(floor(t * 14.0) * 1.7, floor(rp.z * 9.0 + rp.y * 6.0))));
				float vena = smoothstep(0.62, 0.9, rum(vec2(uv.y * 6.0 + rp.z * 50.0, lungo * 9.0 - t * 6.0)));
				g = 0.25 * libero + vena * (0.5 + 2.2 * scatto);
				lc = mix(luce1, luce2, vena * scatto);
			} else if (stile_luce == 2) {     // ombra: nero che beve la luce, con un filo viola sulle punte
				c *= 0.35;
				g = pow(libero, 2.0) * (0.5 + 0.5 * rum(vec2(rp.z * 20.0, t * 1.5 + lungo * 6.0)));
			} else if (stile_luce == 3) {     // fiamma: brace alla radice, lingue chiare che salgono verso le punte
				float lingua = fbm(vec2(rp.z * 14.0 + uv.y * 3.0, lungo * 7.0 - t * 3.2));
				g = 0.4 + 1.1 * lingua * (0.4 + libero);
				lc = mix(luce1, luce2, smoothstep(0.35, 0.8, lingua + libero * 0.3));
				c = mix(c, lc, 0.6);
			} else {                           // astrale: chiarore morbido e scintille che scorrono
				float scint = step(0.93, rum(vec2(floor(rp.z * 60.0) + floor(uv.y * 5.0) * 7.0, floor(lungo * 40.0 - t * 5.0))));
				g = 0.5 + 0.3 * sin(t * 1.7 + rp.z * 8.0) + 1.5 * scint;
				lc = mix(luce1, luce2, 0.3 + 0.7 * scint);
				c = mix(c, lc, 0.45);
			}
			emi = lc * g * forza_luce;
		}
	} else if (s < 2.5) {
		// ---------------- zoccoli: corno a strati
		c = zoccoli * (0.8 + 0.3 * rum(vec2(rp.x * 60.0 + rp.z * 60.0, rp.y * 120.0)));
		c *= 0.55 + 0.45 * ao;
		rough = 0.35;
		if (stile_luce == 1 || stile_luce == 3 || stile_luce == 4) {
			float orlo = smoothstep(0.07, 0.0, rp.y);
			float fiam = stile_luce == 3 ? fbm(vec2(rp.x * 30.0 + rp.z * 30.0, rp.y * 40.0 - TIME * 3.0)) : 0.6;
			emi = mix(luce1, luce2, orlo) * (0.5 + 1.8 * orlo * fiam) * forza_luce;
		}
	} else if (s < 3.5) {
		c = occhi;
		rough = 0.12;
		emi = occhi * occhi_luce;
	} else if (s < 4.5) {
		c = pelle_scura * (0.6 + 0.4 * ao);
		rough = 0.6;
	} else {
		// ---------------- finimenti
		float d = uv.y * 0.5;                    // metri dal bordo
		float bordo = smoothstep(0.022, 0.016, d);
		float filetto = smoothstep(0.004, 0.0015, abs(d - 0.026));
		if (s < 5.5) {                          // cuoio: grana, bordo consumato, cucitura
			float grana = fbm(vec2(lungo * 60.0, d * 240.0 + rp.y * 90.0));
			c = cuoio * (0.78 + 0.4 * grana);
			float cuci = smoothstep(0.0025, 0.001, abs(d - 0.008)) * step(0.5, fract(lungo * 90.0));
			c = mix(c, cuoio * 2.2 + 0.08, cuci * 0.8);
			c = mix(c, cuoio * 0.5, smoothstep(0.004, 0.0, d) * 0.6);
			rough = 0.55;
		} else if (s < 6.5) {                   // ferro: martellato, bordo lucido
			float mart = fbm(rp.zy * 40.0 + rp.x * 23.0);
			c = metallo * (0.75 + 0.4 * mart);
			c = mix(c, metallo * 1.5, smoothstep(0.006, 0.0, d) * 0.6);
			rough = 0.32 + 0.2 * mart;
			metal = 0.85;
		} else if (s < 7.5) {                   // oro
			c = oro * (0.85 + 0.3 * rum(rp.zy * 55.0 + rp.x * 31.0));
			rough = 0.28;
			metal = 0.9;
		} else if (s < 9.5) {                   // stoffa della classe e del regno: trama, orlo ricamato
			vec3 base = s < 8.5 ? stoffa : regno;
			float trama = 0.5 * rum(vec2(lungo * 400.0, d * 60.0)) + 0.5 * rum(vec2(lungo * 60.0, d * 800.0));
			c = base * (0.82 + 0.3 * trama);
			// pieghe morbide verso il basso
			c *= 0.9 + 0.1 * sin(lungo * 42.0 + rp.y * 6.0);
			float orn = 0.0;
			float a = lungo * 38.0;
			float y = d / 0.022;                // 0 al bordo, 1 al filetto
			if (motivo == 0) orn = smoothstep(0.12, 0.04, abs(y - 0.5 - 0.3 * sin(a)));                       // onde
			else if (motivo == 1) orn = step(y, abs(fract(a / 6.28) * 2.0 - 1.0) * 0.9 + 0.05);                   // denti di sega
			else if (motivo == 2) orn = smoothstep(0.42, 0.3, length(vec2(fract(a / 3.14) - 0.5, y - 0.5)));     // grani
			else orn = smoothstep(0.1, 0.02, abs(abs(fract(a / 4.0) - 0.5) + abs(y - 0.5) - 0.42));             // rombi
			c = mix(c, base * 0.45, bordo * 0.85);
			c = mix(c, ricamo, bordo * orn);
			c = mix(c, ricamo, filetto);
			metal = bordo * orn * 0.6 + filetto * 0.6;
			rough = mix(0.9, 0.4, max(bordo * orn, filetto));
		} else if (s < 10.5) {                  // lacca: liscia e lucida, filetto d'oro
			c = lacca * (0.9 + 0.2 * rum(rp.zy * 12.0));
			c = mix(c, oro, max(filetto, smoothstep(0.006, 0.003, d)));
			rough = 0.18;
			metal = max(filetto, smoothstep(0.006, 0.003, d)) * 0.8;
		} else if (s < 11.5) {                  // giada: venature e luce bassa dentro la pietra
			float vena = fbm3(rp * 30.0);
			c = giada * (0.7 + 0.55 * vena);
			float fr = pow(1.0 - clamp(dot(n_vista, vista), 0.0, 1.0), 2.0);
			emi = giada * (0.18 + 0.25 * fr);
			rough = 0.15;
		} else if (s < 12.5) {                  // corda ritorta
			float giro = sin(lungo * 260.0 + uv.y * 12.56);
			c = corda * (0.72 + 0.3 * giro) * (0.85 + 0.25 * rum(vec2(lungo * 300.0, uv.y * 9.0)));
			rough = 0.95;
		} else if (s < 13.5) {                  // grani di legno lucidato
			c = grani * (0.8 + 0.35 * rum(rp.zy * 70.0 + rp.x * 30.0));
			rough = 0.3;
		} else if (s < 14.5) {                  // lamelle laccate: file lungo il pezzo, piastrine separate, lacci del regno
			float riga = lungo / 0.07;
			float col = (abs(rp.x) > 0.12 ? rp.z + rp.y * 0.6 : rp.x * 1.2) / 0.035;
			vec2 f = fract(vec2(col + floor(riga) * 0.5, riga));
			float giunto = smoothstep(0.06, 0.0, min(f.x, 1.0 - f.x));
			float tinta = h21(floor(vec2(col + floor(riga) * 0.5, riga)));
			c = lamelle * (0.78 + 0.35 * tinta);
			c = mix(c, lamelle * 0.3, giunto * 0.8);
			// laccio colorato che lega ogni fila, borchia d'oro al centro della piastrina
			float laccio = smoothstep(0.1, 0.06, abs(f.y - 0.22));
			c = mix(c, regno, laccio * 0.85);
			float borchia = smoothstep(0.16, 0.1, length((f - vec2(0.5, 0.68)) * vec2(1.0, 2.0)));
			c = mix(c, oro, borchia);
			c = mix(c, oro, smoothstep(0.008, 0.004, d));
			rough = mix(0.22, 0.7, laccio);
			metal = max(borchia, smoothstep(0.008, 0.004, d)) * 0.8 + 0.25 * (1.0 - laccio);
		} else {                                // carta dei talismani: segni d'inchiostro e sigillo rosso
			c = carta * (0.9 + 0.12 * rum(rp.zy * 80.0));
			float segno = step(0.62, rum(vec2(floor(lungo * 70.0), floor(d * 260.0)))) * step(0.008, d);
			c = mix(c, vec3(0.08, 0.05, 0.05), segno * 0.85);
			c = mix(c, vec3(0.7, 0.1, 0.08), smoothstep(0.012, 0.008, length(vec2(fract(lungo * 8.0) - 0.5, d * 30.0 - 0.3)) * 0.04));
			rough = 0.9;
		}
		c *= 0.5 + 0.5 * ao;
	}
	alb = c;
}
