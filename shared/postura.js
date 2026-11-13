// Postura di élite e boss: le tecniche che SPENDONO risorsa la riducono; a zero il nemico è «Squilibrato»
// (stordito e più vulnerabile) per qualche secondo, poi la Postura torna piena.
// Qui ci sono solo numeri e regole pure: la logica è in server/world.js, la barra in client/js/ui.js.

export const POSTURA = {
  // --- chi ce l'ha
  eliteHp: 1000,          // un mostro normale con almeno questa vita base (MOBS[tipo].hp) è un'élite
  // --- Postura massima (in «punti di Postura»)
  elite: { base: 60, perLvl: 2 },     // es. livello 14 → 88, livello 26 → 112
  boss: { base: 200, perLvl: 4 },     // es. livello 25 → 300, livello 28 → 312
  dummy: 100,                          // Fantoccio d'Addestramento: per provare
  // --- quanta ne toglie una tecnica (totale, diviso fra i suoi colpi; ogni bersaglio colpito la subisce intera)
  perResPct: 1,           // per ogni 1% della risorsa massima speso (30 di Ira = 30 punti; Mana: costo in %)
  perPt: 6,               // per ogni punto combo speso (tecniche `spend`)
  suprema: 150,           // Tecnica Suprema: totale ripartito fra le sue ondate (`waves`) e i colpi di ogni ondata
  base: 0,                // attacchi base e tecniche che generano risorsa: niente
  // --- Squilibrio
  durata: 5,              // secondi di stordimento e vulnerabilità
  durataBoss: 4,          // i boss si riprendono prima
  vuln: 30,               // +% danni subiti da chiunque durante lo Squilibrio
  recupero: 1.5,          // secondi dopo lo Squilibrio prima che la Postura torni piena (in quel tempo non cala)
  // --- tenacia: ogni Squilibrio alza la Postura massima, così un gruppo non tiene il nemico sempre a terra
  tenacia: 0.25,          // +25% della Postura di base a ogni Squilibrio
  tenaciaMax: 1,          // fino a +100%
  // --- rigenerazione se nessuno la colpisce
  regenDopo: 6,           // secondi senza perdite di Postura prima che ricominci a salire
  regenPct: 12,           // % della Postura massima al secondo
};

// Postura massima di base per un tipo di mostro (0 = non ha Postura). `d` è la voce di MOBS.
export function posturaBase(d) {
  if (!d || d.stone || d.explode) return 0;
  if (d.dummy) return POSTURA.dummy;
  if (d.boss) return Math.round(POSTURA.boss.base + POSTURA.boss.perLvl * (d.lvl || 1));
  if ((d.hp || 0) >= POSTURA.eliteHp) return Math.round(POSTURA.elite.base + POSTURA.elite.perLvl * (d.lvl || 1));
  return 0;
}

// Punti di Postura tolti da UN colpo a segno di una tecnica.
// sk: voce di SKILLS; costoPct: costo in % della risorsa massima; punti: punti combo spesi;
// colpi: quanti colpi dà la tecnica allo stesso bersaglio in una volta (il totale si divide fra colpi e ondate).
export function posturaColpo(sk, costoPct, punti, colpi = 1) {
  if (!sk) return POSTURA.base;
  const parti = Math.max(1, sk.waves || 1) * Math.max(1, colpi);
  if (sk.sup) return POSTURA.suprema / parti;
  const tot = costoPct * POSTURA.perResPct + (sk.spend ? punti * POSTURA.perPt : 0);
  return tot > 0 ? tot / parti : POSTURA.base;
}
