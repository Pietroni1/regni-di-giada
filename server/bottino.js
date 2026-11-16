// Bottino: equipaggiamento adatto alla classe e al livello, gemme, modificatori ed essenze lasciati dai mostri.
// Metodi aggiunti a World (installaBottino in fondo a server/world.js), come server/mappe.js.
//
// Regole (taratura con `npm run farming`, che conta anche i pezzi «utili»: della propria classe e del proprio livello):
//  · ogni zona lascia i pezzi del suo livello: si sceglie fra i pezzi con livello richiesto in (L - 10, L + 1], dove L è il
//    livello del mostro (élite +2, obelischi +2, boss +5), di solito il gradino più alto (65%), a volte quello sotto;
//  · bottino adatto alla classe: nel 75% dei casi il pezzo è della classe di chi ha fatto più danni (armature per tutti,
//    armi solo del suo tipo: per l'Ombra quella che impugna, 70%), altrimenti uno qualsiasi (da vendere o smontare);
//    in gruppo la classe è, a turno, quella di uno dei compagni vicini (il bottino resta di tutto il gruppo);
//  · le élite (solitari con vita ≥ 1000) lasciano pezzi più spesso e più rari (`RARITY_WEIGHTS.elite`).
import { ITEMS, CLASSES, GEM_TYPES, equipSlotOf } from '../shared/data.js';
import { makeEquip, rollRarity } from './world.js';

const SLOT = ['weapon', 'body', 'head', 'feet'];
const EQUIP_IDS = Object.keys(ITEMS).filter((id) => equipSlotOf(ITEMS[id]));
const PROB_CLASSE = 0.75;
const PROB_STESSA_ARMA = 0.7;
const CHANCE = { mob: 0.032, elite: 0.3, stone: 0.8, boss: 1 };   // probabilità di un pezzo per tiro
const randi = (a, b) => Math.floor(a + Math.random() * (b - a + 1));
const scegli = (arr) => arr[Math.floor(Math.random() * arr.length)];

export function usabile(cls, it) {
  if (it.type !== 'weapon') return true;
  return !!CLASSES[cls] && CLASSES[cls].weapons.includes(it.wt);
}

// Un pezzo di equipaggiamento per il livello `liv`. opz: { cls, slot, wt (tipo d'arma preferito), esatto (solo il gradino
// più alto), classe (true = sempre della classe) }. Restituisce l'id dell'oggetto o null.
export function equipAdatto(liv, opz = {}) {
  const { cls, wt } = opz;
  const perClasse = cls && (opz.classe || Math.random() < PROB_CLASSE);
  let slot = opz.slot || (perClasse ? scegli(SLOT) : null);
  let pool = EQUIP_IDS.filter((id) => {
    const it = ITEMS[id];
    if (it.lvl > liv + 1 || it.lvl <= liv - 10) return false;
    if (slot && equipSlotOf(it) !== slot) return false;
    if (perClasse && !usabile(cls, it)) return false;
    return true;
  });
  if (perClasse && slot === 'weapon' && wt && (opz.slot || Math.random() < PROB_STESSA_ARMA)) {
    const stessa = pool.filter((id) => ITEMS[id].wt === wt);
    if (stessa.length) pool = stessa;
  }
  if (!pool.length) {
    // livello fuori dalle tabelle (es. 1 o oltre il 46): il pezzo più vicino
    pool = EQUIP_IDS.filter((id) => (!slot || equipSlotOf(ITEMS[id]) === slot) && (!perClasse || usabile(cls, ITEMS[id])));
    if (!pool.length) return null;
    const vicino = Math.min(...pool.map((id) => Math.abs(ITEMS[id].lvl - liv)));
    pool = pool.filter((id) => Math.abs(ITEMS[id].lvl - liv) === vicino);
  }
  const livelli = [...new Set(pool.map((id) => ITEMS[id].lvl))].sort((a, b) => b - a);
  const gradino = livelli.length > 1 && !opz.esatto && Math.random() >= 0.65 ? livelli[1] : livelli[0];
  return scegli(pool.filter((id) => ITEMS[id].lvl === gradino));
}

// Tipo d'arma che il personaggio impugna (per scegliere fra pugnali e arco dell'Ombra).
export function armaDi(p) {
  const w = p && p.ch && p.ch.equip && p.ch.equip.weapon;
  return w && ITEMS[w.id] ? ITEMS[w.id].wt : null;
}

export function fonteDi(d) {
  if (d.boss) return 'boss';
  if (d.stone) return 'stone';
  if (d.hp >= 1000 && !d.dungeon && !d.dummy) return 'elite';
  return 'mob';
}

const metodi = {
  // Bottino aggiuntivo per fascia di livello: equipaggiamento (per classe e livello), gemme, modificatori, essenze.
  // perChi: il compagno per cui si sceglie la classe dei pezzi (a turno nel gruppo); il bottino resta di `top` e del suo gruppo
  extraDrops(m, top, perChi = top) {
    const d = m.d, lv = d.lvl;
    const source = fonteDi(d);
    const mul = this.cfg.rates.drop * (1 + ((top && top.dropPct) || 0) / 100) * (d.bott ?? 1);   // bott: bottino ridotto per i mostri dei branchi
    const owner = top ? top.id : 0;
    const roll = (ch) => Math.random() < ch * mul;
    const rolls = d.boss ? 3 : d.stone ? 2 : 1;
    const livPezzi = lv + (source === 'boss' ? 5 : source === 'mob' ? 0 : 2);
    for (let i = 0; i < rolls; i++) {
      if (!roll(CHANCE[source])) continue;
      const id = equipAdatto(livPezzi, { cls: perChi && perChi.cls, wt: armaDi(perChi) });
      if (id) this.dropInstance(makeEquip(id, rollRarity(source)), m.x, m.z, owner);
    }
    const gems = Object.keys(GEM_TYPES);
    if (roll(d.boss ? 0.8 : d.stone ? 0.45 : source === 'elite' ? 0.08 : lv >= 5 ? 0.015 : 0)) {
      const grade = d.boss ? (Math.random() < 0.25 ? 2 : 1) : d.stone && lv >= 15 ? 1 : 0;
      this.spawnDrop(`gemma_${gems[randi(0, gems.length - 1)]}_${grade}`, 1, m.x, m.z, owner);
    }
    if (lv >= 8 && roll(d.boss ? 0.6 : d.stone ? 0.3 : source === 'elite' ? 0.05 : 0.008)) this.spawnDrop('pietra_affinamento', d.boss ? 2 : 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.4 : d.stone ? 0.12 : lv >= 12 ? 0.002 : 0)) this.spawnDrop('pergamena_mutamento', 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.25 : d.stone && lv >= 15 ? 0.05 : 0)) this.spawnDrop('sigillo_ascensione', 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.9 : d.stone && lv >= 15 ? 0.3 : lv >= 18 ? 0.01 : 0)) this.spawnDrop('essenza_celeste', d.boss ? randi(2, 4) : 1, m.x, m.z, owner);
  },

  // Un pezzo della classe per un premio (missioni, Prove del Sigillo). slot facoltativo; r = rarità.
  premioEquip(p, liv, slot, r = 0) {
    const id = equipAdatto(liv, { cls: p.cls, wt: armaDi(p), slot, esatto: true, classe: true });
    return id ? makeEquip(id, r) : null;
  },
};

export function installaBottino(World) {
  Object.assign(World.prototype, metodi);
}
