// Dati di gioco condivisi tra server e client.
// Modifica questo file per bilanciare classi, abilità, oggetti e mostri.

export const MAX_LEVEL = 99;
export const INV_SIZE = 45;
export const QB_SIZE = 10;
export const STACK_MAX = 200;
export const STAT_MAX = 90;
export const PTS_MAX = 5;
export const GCD_MS = 1000;
export const GCD_MIN_MS = 750;
export const EQUIP_SLOTS = ['weapon', 'head', 'body', 'feet'];
export const EQUIP_NAMES = { weapon: 'Arma', head: 'Copricapo', body: 'Armatura', feet: 'Calzari' };
export const STAT_NAMES = { vit: 'Vitalità', str: 'Forza', dex: 'Destrezza', int: 'Intelletto' };
export const STAT_DESC = {
  vit: 'Aumenta vita massima e difesa.',
  str: 'Aumenta l\'attacco fisico (Lama, Monaco).',
  dex: 'Aumenta attacco dell\'Ombra, critici ed evasione.',
  int: 'Aumenta mana massimo e attacco magico.',
};
export const VIA_LEVEL = 5;
export const SKILL_MAX_POINTS = 10;
export const SKILL_MAX = 20;
export const BOOK_CHANCE = 0.5;
export const DATA_VERSION = 2;

export function expToNext(l) { return Math.floor(80 * Math.pow(l, 1.85) + 40 * l); }
export function skillVal(arr, lvl) { return Array.isArray(arr) ? arr[0] + arr[1] * (lvl - 1) : arr; }
export function upgradedStat(base, up, weapon) {
  if (!base) return 0;
  return weapon ? Math.round(base * (1 + 0.12 * up) + up * 2) : Math.round(base * (1 + 0.1 * up) + up);
}
export function equipSlotOf(item) {
  return EQUIP_SLOTS.includes(item.type) ? item.type : null;
}

export const WEAPON_TYPES = {
  sword: { name: 'Spada', aspd: 1100, range: 2.8 },
  daggers: { name: 'Pugnali', aspd: 820, range: 2.5 },
  bow: { name: 'Arco', aspd: 1250, range: 15 },
  fists: { name: 'Armi da pugno', aspd: 760, range: 2.4 },
  staff: { name: 'Bastone', aspd: 1300, range: 15 },
};

// ------------------------------------------------------------------ risorse
// Ira: si genera colpendo e subendo colpi, cala fuori dal combattimento.
// Energia / Chi: si rigenerano in fretta. Mana: grande riserva che cala lentamente.
export const RESOURCES = {
  ira: { name: 'Ira', color: '#c8402a', fixedMax: 100, start: 0, decay: 3 },
  energia: { name: 'Energia', color: '#d8b830', fixedMax: 100, start: 100, regen: 22 },
  chi: { name: 'Chi', color: '#3fae8a', fixedMax: 100, start: 100, regen: 18 },
  mana: { name: 'Mana', color: '#3a6ad0', start: 1, regenPct: 1.2, regenPctOoc: 4 },
};

// ------------------------------------------------------------------ classi
// hp/mp: [base, per livello, per punto di vitalità/intelletto]. mp vale solo per le classi a mana.
export const CLASSES = {
  lama: {
    name: 'Lama', title: 'Spadaccino errante', glyph: '剣',
    desc: "Combattente corpo a corpo con la spada. Accumula Ira colpendo e la scarica in fendenti devastanti.",
    start: { vit: 5, str: 6, dex: 3, int: 2 }, hp: [130, 26, 22], mp: [0, 0, 0],
    primary: 'str', autoMagic: false, weapons: ['sword'], res: 'ira', autoRes: 7,
    vie: ['fulmine', 'montagna'], baseSkills: ['fendente', 'squarcio', 'grido'], startWeapon: 'spada_ferro', extraItems: [],
    look: { robe: 0x5b3a2c, trim: 0xb8a070, pants: 0x2e2620, armor: 0x8a8f96, hair: 0x1a1210, hairStyle: 'topknot' },
  },
  ombra: {
    name: 'Ombra', title: 'Lama dei vicoli', glyph: '影',
    desc: 'Agile e letale: pugnali o arco. Le tecniche accumulano Punti combo che le tecniche finali trasformano in colpi micidiali.',
    start: { vit: 3, str: 4, dex: 7, int: 2 }, hp: [105, 21, 18], mp: [0, 0, 0],
    primary: 'dex', autoMagic: false, weapons: ['daggers', 'bow'], res: 'energia', pts: { name: 'Punti combo', glyph: '◆' },
    vie: ['pugnali', 'arco'], baseSkills: ['colpo_rapido', 'taglio_finale'], startWeapon: 'pugnali_osso', extraItems: ['arco_bambu'],
    look: { robe: 0x26293a, trim: 0x7a1e22, pants: 0x1c1e28, hair: 0x0e0e10, hairStyle: 'hood' },
  },
  monaco: {
    name: 'Monaco', title: 'Pugno del monastero', glyph: '拳',
    desc: 'Combatte a mani nude accumulando Sfere di chi. Eseguire Pugno, Calcio e Palmo in sequenza sblocca la Forma Perfetta.',
    start: { vit: 4, str: 5, dex: 4, int: 3 }, hp: [115, 24, 20], mp: [0, 0, 0],
    primary: 'str', autoMagic: false, weapons: ['fists'], res: 'chi', pts: { name: 'Sfere', glyph: '●' },
    chain: ['pugno_ferro', 'calcio_gru', 'palmo_chi'], chainBuff: 'forma_perfetta',
    vie: ['ferro', 'loto'], baseSkills: ['pugno_ferro', 'calcio_gru', 'palmo_chi'], startWeapon: 'bende_seta', extraItems: [],
    look: { robe: 0xc8681c, trim: 0x7a3b10, pants: 0x6a3a14, hair: null, hairStyle: 'bald' },
  },
  mistico: {
    name: 'Mistico', title: 'Veggente dei venti', glyph: '仙',
    desc: 'Incantatore con il bastone. Lancia incantesimi a tempo di lancio, accumula Cariche celesti e cura gli alleati.',
    start: { vit: 3, str: 2, dex: 3, int: 8 }, hp: [95, 19, 17], mp: [120, 14, 26],
    primary: 'int', autoMagic: true, weapons: ['staff'], res: 'mana', pts: { name: 'Cariche celesti', glyph: '✦' },
    vie: ['tempesta', 'benedizione'], baseSkills: ['dardo_luce', 'tocco_curativo'], startWeapon: 'bastone_salice', extraItems: [],
    look: { robe: 0xdcd6c4, trim: 0x2f6a8a, pants: 0xbab4a0, hair: 0x22201e, hairStyle: 'long' },
  },
};

export const VIE = {
  fulmine: { cls: 'lama', name: 'Via del Fulmine', role: 'Danni', desc: 'Danni devastanti su un bersaglio. Lo Squarcio critico accende la Scintilla: la prossima Lama del Tuono è gratuita e più forte.', passive: {} },
  montagna: { cls: 'lama', name: 'Via della Montagna', role: 'Difensore', desc: 'Regge i colpi e tiene su di sé i nemici. Vita +15%, minaccia generata ×4.', passive: { hpPct: 15, threat: 4 } },
  pugnali: { cls: 'ombra', name: 'Via dei Pugnali', role: 'Danni', desc: 'Veleni e colpi alle spalle. Il Taglio Finale fa il 25% in più contro bersagli avvelenati. Richiede pugnali.', passive: {} },
  arco: { cls: 'ombra', name: "Via dell'Arco", role: 'Danni a distanza', desc: 'Tiri caricati dalla distanza. Il Colpo Rapido può rendere istantaneo il prossimo Tiro Mirato. Richiede un arco.', passive: {} },
  ferro: { cls: 'monaco', name: 'Via del Pugno di Ferro', role: 'Danni', desc: 'Raffiche ravvicinate. La Forma Perfetta dona anche il 20% di Chi.', passive: { chainRes: 20 } },
  loto: { cls: 'monaco', name: 'Via del Loto Interiore', role: 'Danni a distanza', desc: "Combatte dalla distanza: la sequenza diventa Palmo → Fiore di Loto → Palmo. Il Vortice Interiore fa il 20% in più sui bersagli col Fiore di Loto.", passive: { chain: ['palmo_chi', 'fiore_loto', 'palmo_chi'] } },
  tempesta: { cls: 'mistico', name: 'Via della Tempesta', role: 'Danni a distanza', desc: 'Fulmini e saette. Il Marchio del Tuono può rendere istantaneo il prossimo Fulmine Celeste.', passive: {} },
  benedizione: { cls: 'mistico', name: 'Via della Benedizione', role: 'Guaritore', desc: 'Cure, scudi e benedizioni per gli alleati del regno. Le cure generano Cariche che potenziano la Pioggia di Petali.', passive: { healPct: 15 } },
};

// ------------------------------------------------------------------ effetti temporanei
// stats: [valore, incremento per livello dell'abilità che lo applica]
// free/instant/consume: liste di abilità; skillDmg: bonus % a singole abilità; spenderDmg: bonus % alle tecniche che consumano punti.
export const BUFFS = {
  scintilla: { name: 'Scintilla', glyph: '閃', dur: 10, proc: true, free: ['lama_tuono'], skillDmg: { lama_tuono: 30 }, consume: ['lama_tuono'], desc: 'La prossima Lama del Tuono non costa Ira e infligge il 30% di danni in più.' },
  grido: { name: 'Grido di Battaglia', glyph: '吼', dur: 10, stats: { dmgPct: [10, 0.5] }, desc: 'Danni aumentati.' },
  furia_tempesta: { name: 'Furia della Tempesta', glyph: '嵐', dur: 15, stats: { dmgPct: [20, 1] }, costMod: { lama_tuono: -15 }, desc: 'Danni aumentati e Lama del Tuono costa 15 Ira in meno.' },
  pelle_pietra: { name: 'Pelle di Pietra', glyph: '岩', dur: 10, stats: { dmgTaken: [-25, -1] }, desc: 'Danni subiti ridotti.' },
  nell_ombra: { name: "Nell'Ombra", glyph: '隠', dur: 5, proc: true, behind: true, consume: ['pugnalata'], desc: 'La prossima Pugnalata alle Spalle colpisce come se fossi alle spalle del nemico.' },
  fuoco_rapido: { name: 'Fuoco Rapido', glyph: '速', dur: 10, proc: true, instant: ['tiro_mirato'], consume: ['tiro_mirato'], desc: 'Il prossimo Tiro Mirato è istantaneo.' },
  occhio_falco: { name: 'Occhio del Falco', glyph: '鷹', dur: 12, stats: { hastePct: [25, 1], resRegenPct: [50, 2] }, desc: 'Rapidità e rigenerazione dell\'Energia aumentate.' },
  forma_perfetta: { name: 'Forma Perfetta', glyph: '極', dur: 10, proc: true, spenderDmg: 40, consumeSpender: true, desc: 'La prossima tecnica che consuma Sfere infligge il 40% di danni in più.' },
  pelle_bronzo: { name: 'Pelle di Bronzo', glyph: '銅', dur: 10, stats: { dmgTaken: [-20, -1], hpRegen: [2, 0.1] }, desc: 'Danni subiti ridotti e rigenerazione della vita.' },
  spirito_tigre: { name: 'Spirito della Tigre', glyph: '虎', dur: 15, stats: { dmgPct: [20, 1], resRegenPct: [50, 2] }, desc: 'Danni e rigenerazione del Chi aumentati.' },
  sigillo_interiore: { name: 'Sigillo Interiore', glyph: '印', dur: 15, stats: { matkPct: [25, 1.5], atkPct: [10, 0.5] }, desc: 'Attacco magico e fisico aumentati.' },
  tempesta_imminente: { name: 'Tempesta Imminente', glyph: '迅', dur: 10, proc: true, instant: ['fulmine_celeste'], consume: ['fulmine_celeste'], desc: 'Il prossimo Fulmine Celeste è istantaneo.' },
  occhio_ciclone: { name: 'Occhio del Ciclone', glyph: '旋', dur: 15, stats: { hastePct: [30, 1], dmgPct: [10, 0.5] }, desc: 'Rapidità e danni aumentati.' },
  benedizione: { name: 'Benedizione', glyph: '福', dur: 300, stats: { defPct: [12, 1.2], atkPct: [6, 0.6], matkPct: [6, 0.6] }, desc: 'Difesa e attacco aumentati.' },
  // effetti sui nemici
  marchio_morte: { name: 'Marchio della Morte', glyph: '死', dur: 15, debuff: true, vuln: [20, 1], desc: "Subisce più danni da chi l'ha marchiato." },
};

// ------------------------------------------------------------------ abilità
// lvl: livello del personaggio per sbloccarla. cost/gen: risorsa (per il Mana: % del massimo).
// pts: punti generati. spend: consuma tutti i punti (mult è per punto). cast: secondi di lancio.
// offgcd: non attiva il tempo di ricarica globale. range: numero o 'weapon' (gittata dell'arma).
export const SKILLS = {
  // ======================= LAMA (Ira)
  fendente: { name: 'Fendente Rotante', cls: 'lama', lvl: 1, type: 'aoe_self', dmg: 'phys', mult: [0.8, 0.04], radius: 4.5, gen: 8, cd: 0, glyph: '旋', color: 0xffd27a, fx: 'spin', desc: 'Colpisce tutti i nemici intorno a te e genera Ira. Ottimo contro i gruppi.' },
  squarcio: { name: 'Squarcio', cls: 'lama', lvl: 1, type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.4, 0.07], gen: 15, cd: 4.5, onCrit: { buff: 'scintilla', via: 'fulmine' }, glyph: '裂', color: 0xffe0a0, fx: 'slash', desc: 'Un colpo potente che genera molta Ira.' },
  grido: { name: 'Grido di Battaglia', cls: 'lama', lvl: 3, type: 'buff', offgcd: true, gen: 25, buff: 'grido', cd: 60, glyph: '吼', color: 0xff8a3a, fx: 'aura', desc: 'Genera subito Ira e aumenta i danni per 10 secondi. Non attiva il tempo di ricarica globale.' },
  // Via del Fulmine
  lama_tuono: { name: 'Lama del Tuono', cls: 'lama', via: 'fulmine', lvl: 5, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.4, 0.12], cost: 35, cd: 0, bonusVs: { dot: 'ferita_aperta', dmg: 20 }, glyph: '雷', color: 0x9fd4ff, fx: 'lightning', desc: 'Il colpo principale della Via: consuma Ira. +20% contro bersagli con Ferita Aperta.' },
  ferita_aperta: { name: 'Ferita Aperta', cls: 'lama', via: 'fulmine', lvl: 7, type: 'strike', range: 'weapon', dmg: 'phys', mult: [0.3, 0.015], cost: 15, dot: { mult: [0.45, 0.022], dur: 12, every: 2 }, glyph: '傷', color: 0xd03a2a, fx: 'slash', desc: 'Apre una ferita che sanguina per 12 secondi. Rinnovarla prima della scadenza conserva fino al 30% del tempo rimasto.' },
  carica: { name: 'Carica Fulminea', cls: 'lama', via: 'fulmine', lvl: 9, type: 'strike', dash: true, offgcd: true, range: 14, dmg: 'phys', mult: [0.8, 0.04], gen: 20, stun: [1, 0.02], cd: 15, glyph: '突', color: 0x9fd4ff, fx: 'dash', desc: 'Scatti sul bersaglio, lo stordisci e generi Ira.' },
  colpo_grazia: { name: 'Colpo di Grazia', cls: 'lama', via: 'fulmine', lvl: 12, type: 'strike', range: 'weapon', dmg: 'phys', mult: [4.5, 0.2], cost: 30, execute: 0.25, cd: 0, glyph: '斬', color: 0xff4a3a, fx: 'lightning', desc: 'Utilizzabile solo su bersagli sotto il 25% di vita. Danni enormi.' },
  furia_tempesta: { name: 'Furia della Tempesta', cls: 'lama', via: 'fulmine', lvl: 15, type: 'buff', offgcd: true, buff: 'furia_tempesta', cd: 90, glyph: '嵐', color: 0x9fd4ff, fx: 'aura', desc: 'Per 15 secondi: danni aumentati e Lama del Tuono costa meno Ira. Allineala con la Scintilla e il Grido.' },
  // Via della Montagna
  martello_monte: { name: 'Martello della Montagna', cls: 'lama', via: 'montagna', lvl: 5, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.0, 0.1], cost: 20, cd: 5, threat: 2.5, glyph: '槌', color: 0xc0a070, fx: 'quake', desc: 'Colpo pesante che genera molta minaccia.' },
  scossa: { name: 'Scossa della Terra', cls: 'lama', via: 'montagna', lvl: 7, type: 'aoe_self', dmg: 'phys', mult: [1.0, 0.05], radius: 6, gen: 10, stun: [1.2, 0.03], cd: 12, glyph: '震', color: 0xc9a66b, fx: 'quake', desc: 'Colpisci il suolo: danni ad area, stordimento e Ira.' },
  sfida: { name: 'Sfida', cls: 'lama', via: 'montagna', lvl: 9, type: 'taunt', offgcd: true, range: 20, cd: 8, glyph: '挑', color: 0xff5a3a, fx: 'taunt', desc: 'Costringe il nemico ad attaccare te.' },
  pelle_pietra: { name: 'Pelle di Pietra', cls: 'lama', via: 'montagna', lvl: 12, type: 'buff', offgcd: true, buff: 'pelle_pietra', cd: 45, glyph: '岩', color: 0xc0a070, fx: 'aura', desc: 'Riduce i danni subiti per 10 secondi.' },
  respiro_monte: { name: 'Respiro del Monte', cls: 'lama', via: 'montagna', lvl: 15, type: 'heal_self', heal: [0.18, 0.01], cost: 30, cd: 20, glyph: '息', color: 0x7fd07f, fx: 'heal', desc: 'Consuma Ira per recuperare una parte della vita massima.' },

  // ======================= OMBRA (Energia + Punti combo)
  colpo_rapido: { name: 'Colpo Rapido', cls: 'ombra', lvl: 1, type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.3, 0.065], cost: 30, pts: 1, proc: { chance: 0.3, buff: 'fuoco_rapido', via: 'arco' }, glyph: '速', color: 0xe0e0ff, fx: 'slash', desc: "Colpo veloce con l'arma impugnata. Genera 1 Punto combo." },
  taglio_finale: { name: 'Taglio Finale', cls: 'ombra', lvl: 3, type: 'strike', range: 'weapon', dmg: 'phys', mult: [0.95, 0.05], cost: 25, spend: true, bonusVs: { dot: 'lama_veleno', dmg: 25 }, glyph: '終', color: 0xff6a6a, fx: 'slash', desc: 'Tecnica finale: consuma tutti i Punti combo, i danni crescono con ogni punto.' },
  // Via dei Pugnali
  pugnalata: { name: 'Pugnalata alle Spalle', cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 5, type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.8, 0.09], cost: 35, pts: 2, behind: { dmg: 30, pts: 1 }, glyph: '背', color: 0xb08ae0, fx: 'slash', desc: 'Genera 2 Punti combo. Alle spalle del nemico: +30% danni e 1 punto in più.' },
  lama_veleno: { name: 'Lama Avvelenata', cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 7, type: 'strike', range: 'weapon', dmg: 'phys', cost: 25, spend: true, dot: { mult: [0.45, 0.022], durPerPt: 3, every: 1.5 }, glyph: '毒', color: 0x6fd04a, fx: 'slash', desc: 'Tecnica finale: avvelena il bersaglio per 3 secondi per ogni Punto combo.' },
  passo_ombra: { name: "Passo d'Ombra", cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 9, type: 'strike', dash: true, behindDash: true, offgcd: true, range: 12, pts: 1, buff: 'nell_ombra', cd: 20, glyph: '潜', color: 0x9a7ad0, fx: 'dash', desc: 'Ti materializzi alle spalle del bersaglio: 1 Punto combo e la prossima Pugnalata conta come alle spalle.' },
  danza_lame: { name: 'Danza delle Lame', cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 12, type: 'aoe_self', dmg: 'phys', mult: [1.0, 0.05], radius: 5, cost: 45, pts: 1, glyph: '舞', color: 0xd0d0ff, fx: 'spin', desc: 'Colpisce tutti i nemici intorno a te. Genera 1 Punto combo.' },
  marchio_morte: { name: 'Marchio della Morte', cls: 'ombra', via: 'pugnali', lvl: 15, type: 'debuff', offgcd: true, range: 20, debuff: 'marchio_morte', pts: 5, cd: 90, glyph: '死', color: 0x8a2a5a, fx: 'mark', desc: 'Il bersaglio subisce più danni da te per 15 secondi e ottieni subito 5 Punti combo.' },
  // Via dell'Arco
  tiro_mirato: { name: 'Tiro Mirato', cls: 'ombra', via: 'arco', req: 'bow', lvl: 5, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.7, 0.13], cost: 30, pts: 2, cast: 1.6, glyph: '狙', color: 0xffe08a, fx: 'arrow', desc: 'Tiro caricato (1,6 s). Genera 2 Punti combo.' },
  freccia_perforante: { name: 'Freccia Perforante', cls: 'ombra', via: 'arco', req: 'bow', lvl: 7, type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.15, 0.055], cost: 25, spend: true, ignoreDef: 50, glyph: '貫', color: 0xffc04a, fx: 'arrow', desc: 'Tecnica finale che ignora metà della difesa del bersaglio.' },
  pioggia_frecce: { name: 'Pioggia di Frecce', cls: 'ombra', via: 'arco', req: 'bow', lvl: 9, type: 'aoe_target', range: 'weapon', radius: 5, dmg: 'phys', mult: [0.9, 0.05], cost: 45, pts: 1, glyph: '雨', color: 0xffe08a, fx: 'rain', desc: "Frecce sull'area del bersaglio. Genera 1 Punto combo." },
  freccia_inchiodante: { name: 'Freccia Inchiodante', cls: 'ombra', via: 'arco', req: 'bow', lvl: 12, type: 'strike', range: 'weapon', dmg: 'phys', mult: [0.6, 0.03], cost: 20, pts: 1, stun: [1.5, 0.03], cd: 15, glyph: '釘', color: 0xe8dcc0, fx: 'arrow', desc: 'Inchioda il bersaglio stordendolo. Genera 1 Punto combo.' },
  occhio_falco: { name: 'Occhio del Falco', cls: 'ombra', via: 'arco', lvl: 15, type: 'buff', offgcd: true, buff: 'occhio_falco', cd: 60, glyph: '鷹', color: 0xffc04a, fx: 'aura', desc: "Rapidità e rigenerazione dell'Energia aumentate per 12 secondi." },

  // ======================= MONACO (Chi + Sfere, sequenza Pugno → Calcio → Palmo)
  pugno_ferro: { name: 'Pugno di Ferro', cls: 'monaco', lvl: 1, type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.1, 0.055], cost: 30, pts: 1, glyph: '拳', color: 0xffd27a, fx: 'slash', desc: 'Primo colpo della sequenza. Genera 1 Sfera.' },
  calcio_gru: { name: 'Calcio della Gru', cls: 'monaco', lvl: 1, type: 'aoe_self', dmg: 'phys', mult: [0.7, 0.035], radius: 4, cost: 30, pts: 1, glyph: '鶴', color: 0xffb04a, fx: 'spin', desc: 'Secondo colpo della sequenza: colpisce chi ti circonda. Genera 1 Sfera.' },
  palmo_chi: { name: 'Palmo di Chi', cls: 'monaco', lvl: 3, type: 'strike', range: 14, dmg: 'hybrid', mult: [1.3, 0.065], cost: 20, pts: 1, glyph: '掌', color: 0xffb04a, fx: 'bolt', desc: 'Terzo colpo della sequenza, a distanza. Pugno → Calcio → Palmo in ordine attiva la Forma Perfetta (+2 Sfere).' },
  // Via del Pugno di Ferro
  raffica: { name: 'Raffica dei Cento Pugni', cls: 'monaco', via: 'ferro', lvl: 5, type: 'strike', range: 'weapon', dmg: 'phys', mult: [0.25, 0.012], hits: 4, spend: true, minPts: 2, glyph: '連', color: 0xffd27a, fx: 'slash', desc: 'Consuma tutte le Sfere (minimo 2): 4 colpi, ognuno più forte per ogni Sfera.' },
  ascesa_drago: { name: 'Ascesa del Drago', cls: 'monaco', via: 'ferro', lvl: 7, type: 'aoe_self', dmg: 'phys', mult: [0.5, 0.025], radius: 5, spend: true, minPts: 2, stun: [1, 0.02], cd: 10, glyph: '昇', color: 0xff8a3a, fx: 'quake', desc: 'Consuma le Sfere (minimo 2): danni ad area e stordimento.' },
  pelle_bronzo: { name: 'Pelle di Bronzo', cls: 'monaco', via: 'ferro', lvl: 9, type: 'buff', offgcd: true, buff: 'pelle_bronzo', cd: 60, glyph: '銅', color: 0xc8883a, fx: 'aura', desc: 'Riduce i danni subiti e rigenera vita per 10 secondi.' },
  spirito_tigre: { name: 'Spirito della Tigre', cls: 'monaco', via: 'ferro', lvl: 12, type: 'buff', offgcd: true, buff: 'spirito_tigre', cd: 90, glyph: '虎', color: 0xff8a3a, fx: 'aura', desc: 'Danni e rigenerazione del Chi aumentati per 15 secondi.' },
  colpo_vuoto: { name: 'Colpo del Vuoto', cls: 'monaco', via: 'ferro', lvl: 15, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.4, 0.12], cost: 40, pts: 2, cd: 8, glyph: '空', color: 0xe0e0ff, fx: 'quake', desc: 'Colpo potente che genera 2 Sfere.' },
  // Via del Loto Interiore
  onda_chi: { name: 'Onda di Chi', cls: 'monaco', via: 'loto', lvl: 5, type: 'aoe_target', range: 14, radius: 4.5, dmg: 'magic', mult: [0.75, 0.038], spend: true, glyph: '波', color: 0xffc85a, fx: 'bolt', desc: "Consuma le Sfere: un'onda esplode sul bersaglio e intorno a lui." },
  fiore_loto: { name: 'Fiore di Loto', cls: 'monaco', via: 'loto', lvl: 7, type: 'strike', range: 14, dmg: 'magic', mult: [0.9, 0.045], cost: 25, pts: 1, dot: { mult: [0.5, 0.025], dur: 12, every: 2 }, glyph: '蓮', color: 0xf0a0d0, fx: 'bolt', desc: 'Un fiore di chi consuma il bersaglio per 12 secondi. Genera 1 Sfera.' },
  meditazione: { name: 'Meditazione', cls: 'monaco', via: 'loto', lvl: 9, type: 'hot_self', heal: [0.035, 0.003], dur: 10, cost: 30, cd: 40, glyph: '禅', color: 0x7fd07f, fx: 'heal', desc: 'Rigenera vita ogni secondo per 10 secondi.' },
  sigillo_interiore: { name: 'Sigillo Interiore', cls: 'monaco', via: 'loto', lvl: 12, type: 'buff', offgcd: true, buff: 'sigillo_interiore', cd: 90, glyph: '印', color: 0xffe0a0, fx: 'aura', desc: 'Attacco magico e fisico aumentati per 15 secondi.' },
  vortice_interiore: { name: 'Vortice Interiore', cls: 'monaco', via: 'loto', lvl: 15, type: 'strike', range: 14, dmg: 'magic', mult: [1.3, 0.065], spend: true, bonusVs: { dot: 'fiore_loto', dmg: 20 }, glyph: '渦', color: 0xffc85a, fx: 'bolt', desc: 'Consuma le Sfere in un colpo concentrato. +20% sui bersagli col Fiore di Loto.' },

  // ======================= MISTICO (Mana in % + Cariche celesti)
  dardo_luce: { name: 'Dardo di Luce', cls: 'mistico', lvl: 1, type: 'strike', range: 20, dmg: 'magic', mult: [1.8, 0.09], cost: 2, pts: 1, cast: 1.5, glyph: '光', color: 0xfff4b0, fx: 'bolt', desc: 'Incantesimo base (1,5 s). Genera 1 Carica celeste.' },
  tocco_curativo: { name: 'Tocco Curativo', cls: 'mistico', lvl: 3, type: 'heal_target', range: 20, heal: [2.0, 0.12], cost: 6, cast: 1.5, glyph: '癒', color: 0x7fd07f, fx: 'heal', desc: 'Cura un alleato del regno (o te stesso).' },
  // Via della Tempesta
  fulmine_celeste: { name: 'Fulmine Celeste', cls: 'mistico', via: 'tempesta', lvl: 5, type: 'strike', range: 20, dmg: 'magic', mult: [3.5, 0.17], cost: 4, pts: 1, cast: 2.0, glyph: '電', color: 0xa0d8ff, fx: 'lightning', desc: 'Un fulmine dal cielo (2 s). Genera 1 Carica celeste.' },
  marchio_tuono: { name: 'Marchio del Tuono', cls: 'mistico', via: 'tempesta', lvl: 7, type: 'strike', range: 20, dmg: 'magic', mult: [0.2, 0.01], cost: 3, dot: { mult: [0.7, 0.035], dur: 15, every: 3 }, tickProc: { chance: 0.25, buff: 'tempesta_imminente' }, glyph: '標', color: 0x9ad8ff, fx: 'mark', desc: 'Istantaneo: danni nel tempo per 15 secondi. Ogni impulso può rendere istantaneo il prossimo Fulmine Celeste.' },
  giudizio_cielo: { name: 'Giudizio del Cielo', cls: 'mistico', via: 'tempesta', lvl: 9, type: 'strike', range: 20, dmg: 'magic', mult: [1.45, 0.07], cost: 5, spend: true, glyph: '審', color: 0xffffff, fx: 'lightning', desc: 'Istantaneo: consuma tutte le Cariche celesti, i danni crescono con ogni carica.' },
  tempesta_saette: { name: 'Tempesta di Saette', cls: 'mistico', via: 'tempesta', lvl: 12, type: 'aoe_target', range: 20, radius: 5, dmg: 'magic', mult: [1.5, 0.075], cost: 8, pts: 1, cast: 2.0, glyph: '嵐', color: 0xa0d8ff, fx: 'lightning', desc: 'Saette su tutti i nemici attorno al bersaglio (2 s). Genera 1 Carica.' },
  occhio_ciclone: { name: 'Occhio del Ciclone', cls: 'mistico', via: 'tempesta', lvl: 15, type: 'buff', offgcd: true, buff: 'occhio_ciclone', cd: 120, glyph: '旋', color: 0xc0f0ff, fx: 'wind', desc: 'Rapidità e danni aumentati per 15 secondi.' },
  // Via della Benedizione
  loto_rigenerante: { name: 'Loto Rigenerante', cls: 'mistico', via: 'benedizione', lvl: 5, type: 'hot_target', range: 20, heal: [0.03, 0.003], dur: 12, cost: 5, pts: 1, glyph: '蓮', color: 0xf0a0d0, fx: 'heal', desc: 'Rigenera la vita del bersaglio per 12 secondi. Genera 1 Carica.' },
  benedizione: { name: 'Benedizione', cls: 'mistico', via: 'benedizione', lvl: 7, type: 'buff_allies', radius: 20, buff: 'benedizione', cost: 10, cd: 30, glyph: '福', color: 0xfff0a0, fx: 'aura', desc: 'Tu e gli alleati vicini del regno ricevete difesa e attacco per 5 minuti.' },
  scudo_giada: { name: 'Scudo di Giada', cls: 'mistico', via: 'benedizione', lvl: 9, type: 'shield', range: 20, shield: [3.0, 0.15], cost: 7, pts: 1, cd: 12, glyph: '盾', color: 0x6ad8a0, fx: 'shield', desc: 'Uno scudo assorbe i danni subiti dal bersaglio per 15 secondi. Genera 1 Carica.' },
  pioggia_petali: { name: 'Pioggia di Petali', cls: 'mistico', via: 'benedizione', lvl: 12, type: 'heal_aoe', range: 20, radius: 10, heal: [1.2, 0.06], cost: 12, cast: 2.0, spendBonus: 20, glyph: '花', color: 0xf0a0d0, fx: 'heal', desc: 'Cura tutti gli alleati vicini al bersaglio (2 s). Consuma le Cariche: +20% cura per carica.' },
  preghiera_antenati: { name: 'Preghiera degli Antenati', cls: 'mistico', via: 'benedizione', lvl: 15, type: 'heal_aoe', healPct: true, radius: 20, heal: [0.35, 0.01], offgcd: true, cd: 120, glyph: '祖', color: 0xfff0a0, fx: 'heal', desc: 'Cura tutti gli alleati vicini di una grande parte della loro vita massima.' },
};
for (const [id, sk] of Object.entries(SKILLS)) sk.id = id;

export function skillCost(sk, lvl) { return sk.cost ? sk.cost : 0; }
export const STATS_NAMES = {
  dmgPct: 'Danni', atkPct: 'Attacco', matkPct: 'Attacco magico', defPct: 'Difesa', hastePct: 'Rapidità', critPct: 'Critico',
  dmgTaken: 'Danni subiti', hpRegen: 'Rigenerazione vita (%/s)', resRegenPct: 'Rigenerazione risorsa',
};

// ------------------------------------------------------------------ oggetti
// tier: 1-4 (colore del nome). price: prezzo di acquisto (vendita = 1/5).
export const ITEMS = {
  // Lama
  spada_ferro: { name: 'Spada di Ferro', type: 'weapon', wt: 'sword', lvl: 1, atk: 14, price: 300, tier: 1, glyph: '剣' },
  sciabola_bronzo: { name: 'Sciabola di Bronzo', type: 'weapon', wt: 'sword', lvl: 10, atk: 32, price: 2500, tier: 2, glyph: '剣' },
  spada_giada: { name: 'Spada di Giada', type: 'weapon', wt: 'sword', lvl: 20, atk: 55, price: 14000, tier: 3, glyph: '剣' },
  spada_gru: { name: 'Spada delle Cento Gru', type: 'weapon', wt: 'sword', lvl: 30, atk: 82, price: 40000, tier: 4, glyph: '剣' },
  // Ombra
  pugnali_osso: { name: "Pugnali d'Osso", type: 'weapon', wt: 'daggers', lvl: 1, atk: 11, price: 300, tier: 1, glyph: '刃' },
  pugnali_acciaio: { name: "Pugnali d'Acciaio", type: 'weapon', wt: 'daggers', lvl: 10, atk: 26, price: 2500, tier: 2, glyph: '刃' },
  pugnali_serpe: { name: 'Pugnali della Serpe', type: 'weapon', wt: 'daggers', lvl: 20, atk: 45, price: 14000, tier: 3, glyph: '刃' },
  pugnali_eclissi: { name: "Pugnali dell'Eclissi", type: 'weapon', wt: 'daggers', lvl: 30, atk: 68, price: 40000, tier: 4, glyph: '刃' },
  arco_bambu: { name: 'Arco di Bambù', type: 'weapon', wt: 'bow', lvl: 1, atk: 10, range: 15, price: 300, tier: 1, glyph: '弓' },
  arco_corno: { name: 'Arco di Corno', type: 'weapon', wt: 'bow', lvl: 10, atk: 24, range: 16, price: 2500, tier: 2, glyph: '弓' },
  arco_airone: { name: "Arco dell'Airone", type: 'weapon', wt: 'bow', lvl: 20, atk: 42, range: 17, price: 14000, tier: 3, glyph: '弓' },
  arco_autunno: { name: "Arco del Vento d'Autunno", type: 'weapon', wt: 'bow', lvl: 30, atk: 64, range: 18, price: 40000, tier: 4, glyph: '弓' },
  // Monaco
  bende_seta: { name: 'Bende di Seta', type: 'weapon', wt: 'fists', lvl: 1, atk: 10, matk: 6, price: 300, tier: 1, glyph: '拳' },
  artigli_ferro: { name: 'Artigli di Ferro', type: 'weapon', wt: 'fists', lvl: 10, atk: 24, matk: 14, price: 2500, tier: 2, glyph: '拳' },
  artigli_tigre: { name: 'Artigli della Tigre Bianca', type: 'weapon', wt: 'fists', lvl: 20, atk: 42, matk: 26, price: 14000, tier: 3, glyph: '拳' },
  guanti_sole: { name: 'Guanti del Sole Nascente', type: 'weapon', wt: 'fists', lvl: 30, atk: 62, matk: 40, price: 40000, tier: 4, glyph: '拳' },
  // Mistico
  bastone_salice: { name: 'Bastone di Salice', type: 'weapon', wt: 'staff', lvl: 1, atk: 5, matk: 14, range: 15, price: 300, tier: 1, glyph: '杖' },
  bastone_pruno: { name: 'Bastone di Pruno', type: 'weapon', wt: 'staff', lvl: 10, atk: 10, matk: 32, range: 16, price: 2500, tier: 2, glyph: '杖' },
  bastone_cielo: { name: 'Bastone del Cielo Limpido', type: 'weapon', wt: 'staff', lvl: 20, atk: 16, matk: 55, range: 17, price: 14000, tier: 3, glyph: '杖' },
  bastone_nubi: { name: 'Bastone delle Mille Nubi', type: 'weapon', wt: 'staff', lvl: 30, atk: 22, matk: 80, range: 18, price: 40000, tier: 4, glyph: '杖' },
  // Armature (tutte le classi)
  tunica_canapa: { name: 'Tunica di Canapa', type: 'body', lvl: 1, def: 6, price: 200, tier: 1, glyph: '衣' },
  corazza_lamelle: { name: 'Corazza Lamellare', type: 'body', lvl: 10, def: 16, price: 2200, tier: 2, glyph: '鎧' },
  armatura_giada: { name: 'Armatura di Giada', type: 'body', lvl: 20, def: 30, price: 13000, tier: 3, glyph: '鎧' },
  armatura_nubi: { name: 'Armatura delle Nubi', type: 'body', lvl: 30, def: 46, price: 38000, tier: 4, glyph: '鎧' },
  cappello_paglia: { name: 'Cappello di Paglia', type: 'head', lvl: 1, def: 2, price: 120, tier: 1, glyph: '笠' },
  elmo_bronzo: { name: 'Elmo di Bronzo', type: 'head', lvl: 10, def: 6, price: 1500, tier: 2, glyph: '兜' },
  elmo_cornuto: { name: 'Elmo Cornuto', type: 'head', lvl: 20, def: 11, price: 9000, tier: 3, glyph: '兜' },
  elmo_drago: { name: 'Elmo del Drago Sopito', type: 'head', lvl: 30, def: 17, price: 26000, tier: 4, glyph: '兜' },
  sandali: { name: 'Sandali di Corda', type: 'feet', lvl: 1, def: 1, price: 80, tier: 1, glyph: '履' },
  stivali_cuoio: { name: 'Stivali di Cuoio', type: 'feet', lvl: 10, def: 3, speed: 5, price: 1400, tier: 2, glyph: '靴' },
  stivali_vento: { name: 'Stivali del Vento', type: 'feet', lvl: 20, def: 5, speed: 10, price: 8500, tier: 3, glyph: '靴' },
  stivali_nube: { name: 'Stivali di Nuvola', type: 'feet', lvl: 30, def: 8, speed: 14, price: 24000, tier: 4, glyph: '靴' },
  // Consumabili
  ginseng_p: { name: 'Infuso di Ginseng (piccolo)', type: 'potion', hp: 120, price: 25, stack: true, glyph: '薬', color: '#b8322a', desc: 'Ripristina 120 punti vita.' },
  ginseng_m: { name: 'Infuso di Ginseng (medio)', type: 'potion', hp: 400, price: 110, stack: true, glyph: '薬', color: '#b8322a', desc: 'Ripristina 400 punti vita.' },
  ginseng_g: { name: 'Infuso di Ginseng (grande)', type: 'potion', hp: 1100, price: 380, stack: true, glyph: '薬', color: '#b8322a', desc: 'Ripristina 1100 punti vita.' },
  loto_p: { name: 'Tè di Loto (piccolo)', type: 'potion', mpPct: 10, price: 25, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina il 10% del Mana (solo per chi usa il Mana).' },
  loto_m: { name: 'Tè di Loto (medio)', type: 'potion', mpPct: 25, price: 110, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina il 25% del Mana (solo per chi usa il Mana).' },
  loto_g: { name: 'Tè di Loto (grande)', type: 'potion', mpPct: 50, price: 380, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina il 50% del Mana (solo per chi usa il Mana).' },
  pergamena_ritorno: { name: 'Pergamena del Ritorno', type: 'scroll', price: 150, stack: true, glyph: '帰', color: '#8a6a2a', desc: 'Ti riporta al villaggio del tuo regno. Non utilizzabile in combattimento.' },
  // Materiali
  zanna_lupo: { name: 'Zanna di Lupo', type: 'material', price: 40, stack: true, glyph: '牙', color: '#6a6a6a', desc: 'Un trofeo di caccia. Si vende ai mercanti.' },
  pelle_cinghiale: { name: 'Pelle di Cinghiale', type: 'material', price: 50, stack: true, glyph: '皮', color: '#6a4a2a', desc: 'Pelle robusta. Si vende ai mercanti.' },
  benda_bandito: { name: 'Benda del Bandito', type: 'material', price: 90, stack: true, glyph: '布', color: '#7a2a2a', desc: 'Strappata a un fuorilegge. Si vende ai mercanti.' },
  coccio_terracotta: { name: 'Coccio di Terracotta', type: 'material', price: 200, stack: true, glyph: '陶', color: '#a0603a', desc: 'Frammento di un guerriero animato. Si vende ai mercanti.' },
  minerale_ferro: { name: 'Minerale di Ferro Grezzo', type: 'material', price: 300, stack: true, glyph: '鉄', color: '#4a5a6a', desc: 'Il fabbro lo richiede per i potenziamenti da +4 a +6.' },
  frammento_obelisco: { name: "Frammento d'Obelisco", type: 'material', price: 1200, stack: true, glyph: '晶', color: '#6a3a8a', desc: 'Il fabbro lo richiede per i potenziamenti da +7 a +9.' },
  tomo_tecnica: { name: 'Tomo della Tecnica', type: 'book', price: 5000, stack: true, glyph: '書', color: '#2a6a4a', desc: "Permette di studiare un'abilità oltre il livello 10 (50% di successo). Si usa dal tasto + nella finestra Abilità." },
  sigillo_fabbro: { name: 'Sigillo del Fabbro', type: 'seal', price: 15000, stack: true, glyph: '印', color: '#8a7a2a', desc: "Se un potenziamento rischioso fallisce, l'oggetto non viene distrutto (da +9 in su scende di un livello). Il sigillo si consuma solo se il potenziamento fallisce." },
  essenza_celeste: { name: 'Essenza Celeste', type: 'material', price: 6000, stack: true, glyph: '霊', color: '#3a8ac0', desc: 'Il fabbro la richiede per i potenziamenti da +10 a +15. La lasciano i boss e gli obelischi più potenti.' },
  // Modificatori: si trascinano su un'arma o un'armatura
  pietra_affinamento: { name: "Pietra dell'Affinamento", type: 'mod', mod: 'refine', price: 2500, stack: true, glyph: '磨', color: '#5a7a8a', desc: "Trascinala su un oggetto: rilancia i valori dei bonus casuali mantenendone i tipi." },
  pergamena_mutamento: { name: 'Pergamena del Mutamento', type: 'mod', mod: 'reroll', price: 6000, stack: true, glyph: '変', color: '#7a5a2a', desc: "Trascinala su un oggetto: rimescola completamente i bonus casuali (tipi e valori)." },
  sigillo_ascensione: { name: "Sigillo dell'Ascensione", type: 'mod', mod: 'ascend', price: 40000, stack: true, glyph: '昇', color: '#a05ac0', desc: "Trascinalo su un oggetto: 35% di probabilità di alzarne la rarità di un grado (nuovo bonus e incavi). Si consuma comunque." },
  scalpello: { name: 'Scalpello del Gioielliere', type: 'mod', mod: 'extract', price: 1500, stack: true, glyph: '鑿', color: '#6a6a6a', desc: "Trascinalo su un oggetto: estrae tutte le gemme incastonate e te le restituisce." },
};

// ------------------------------------------------------------------ rarità e bonus casuali
export const RARITIES = [
  { name: 'Comune', color: '#e8e0d0', mult: 1.0, bonuses: 0, sockets: 0 },
  { name: 'Pregiato', color: '#6ad86a', mult: 1.05, bonuses: 1, sockets: 0 },
  { name: 'Raro', color: '#5aa0ff', mult: 1.1, bonuses: 2, sockets: 1 },
  { name: 'Epico', color: '#c070ff', mult: 1.15, bonuses: 3, sockets: 2 },
  { name: 'Leggendario', color: '#ff9a30', mult: 1.25, bonuses: 4, sockets: 3 },
];
// probabilità (in peso) delle rarità per fonte del bottino
export const RARITY_WEIGHTS = {
  mob: [60, 26, 10, 3.4, 0.6],
  stone: [25, 35, 25, 12, 3],
  boss: [0, 20, 40, 28, 12],
};
// range: valori al tier 3 (livello 20); TIER_SCALE li adatta al tier dell'oggetto.
export const BONUS_STATS = {
  hp: { name: 'Vita massima', range: [40, 220], flat: true, slots: ['body', 'head', 'feet'] },
  def: { name: 'Difesa', range: [4, 26], flat: true, slots: ['body', 'head', 'feet'] },
  atkPct: { name: 'Attacco', range: [2, 9], slots: ['weapon', 'head'] },
  matkPct: { name: 'Attacco magico', range: [2, 9], slots: ['weapon', 'head'] },
  crit: { name: 'Critico', range: [1, 5], slots: ['weapon', 'head', 'feet'] },
  critDmg: { name: 'Danni critici', range: [4, 20], slots: ['weapon', 'body'] },
  haste: { name: 'Rapidità', range: [1, 6], slots: ['weapon', 'head', 'feet'] },
  monDmg: { name: 'Danni ai mostri', range: [3, 14], slots: ['weapon', 'body'] },
  bossDmg: { name: 'Danni a boss e obelischi', range: [4, 18], slots: ['weapon'] },
  aoeDmg: { name: 'Danni ad area', range: [4, 16], slots: ['weapon', 'body'] },
  lifesteal: { name: 'Vita rubata', range: [0.5, 3], slots: ['weapon'] },
  dmgRed: { name: 'Riduzione danni dai mostri', range: [2, 9], slots: ['body', 'head'] },
  moveSpd: { name: 'Velocità di movimento', range: [2, 8], slots: ['feet'] },
  evade: { name: 'Evasione', range: [1, 4], slots: ['feet', 'body'] },
  resRegen: { name: 'Rigenerazione risorsa', range: [4, 15], slots: ['head', 'body'] },
  expPct: { name: 'Esperienza', range: [2, 10], slots: ['head', 'feet', 'body'] },
  taelPct: { name: 'Tael trovati', range: [4, 18], slots: ['feet', 'head'] },
  dropPct: { name: 'Probabilità di bottino', range: [3, 12], slots: ['feet', 'head'] },
};
export const TIER_SCALE = [0, 0.55, 0.75, 1.0, 1.25];

export function bonusText(stat, v) {
  const b = BONUS_STATS[stat];
  if (!b) return stat;
  return `${b.name} +${b.flat ? Math.round(v) : String(v).replace('.', ',') + '%'}`;
}
// Qualità del valore rispetto al massimo possibile, da 1 a 5 stelle.
export function bonusStars(stat, v, tier) {
  const b = BONUS_STATS[stat];
  if (!b) return 1;
  const s = TIER_SCALE[tier] || 1, lo = b.range[0] * s, hi = b.range[1] * s;
  const q = hi > lo ? (v - lo) / (hi - lo) : 1;
  return Math.max(1, Math.min(5, Math.ceil(q * 5 + 0.0001)));
}

// ------------------------------------------------------------------ gemme
export const GEM_TYPES = {
  rubino: { name: 'Rubino', stat: 'atkPct', vals: [2, 4, 7], color: '#c0302a', glyph: '紅' },
  zaffiro: { name: 'Zaffiro', stat: 'matkPct', vals: [2, 4, 7], color: '#2a5ad0', glyph: '藍' },
  giada: { name: 'Giada', stat: 'hp', vals: [60, 150, 320], color: '#2fae7e', glyph: '翠' },
  ambra: { name: 'Ambra', stat: 'crit', vals: [1, 2, 3.5], color: '#d89a20', glyph: '琥' },
  onice: { name: 'Onice', stat: 'def', vals: [6, 14, 28], color: '#3a3a48', glyph: '黒' },
  perla: { name: 'Perla', stat: 'haste', vals: [1.5, 3, 5], color: '#c8c8d8', glyph: '珠' },
};
const GEM_GRADE_NAMES = ['Scheggia', 'Gemma', 'Gemma Perfetta'];
for (const [type, g] of Object.entries(GEM_TYPES)) {
  for (let grade = 0; grade < 3; grade++) {
    const of = /^[AEIOU]/.test(g.name) ? `d'${g.name}` : `di ${g.name}`;
    ITEMS[`gemma_${type}_${grade}`] = {
      name: `${GEM_GRADE_NAMES[grade]} ${of}`, type: 'gem', gem: type, grade, stack: true,
      price: [400, 2500, 15000][grade], glyph: g.glyph, color: g.color, tier: grade + 2,
      desc: `Trascinala su un oggetto con un incavo libero: ${bonusText(g.stat, g.vals[grade])}.${grade < 2 ? ' Clic destro con 3 gemme uguali per fonderle nel grado successivo.' : ''}`,
    };
  }
}

// ------------------------------------------------------------------ mostri
// drops: [oggetto, probabilità, min, max]
export const MOBS = {
  lupo: { name: 'Lupo Grigio', lvl: 2, hp: 90, atk: 9, def: 2, exp: 30, speed: 5.5, aggro: 0, range: 2.0, aspd: 1600, model: 'wolf', color: 0x777370, scale: 1, respawn: 20, tael: [4, 10],
    drops: [['zanna_lupo', 0.35], ['ginseng_p', 0.08], ['tunica_canapa', 0.01], ['sandali', 0.01]] },
  cinghiale: { name: 'Cinghiale Selvatico', lvl: 3, hp: 140, atk: 11, def: 4, exp: 42, speed: 5, aggro: 0, range: 2.2, aspd: 1700, model: 'boar', color: 0x5a3e2b, scale: 1, respawn: 20, tael: [5, 12],
    drops: [['pelle_cinghiale', 0.35], ['ginseng_p', 0.1], ['cappello_paglia', 0.015], ['loto_p', 0.06]] },
  lupo_alfa: { name: 'Lupo Alfa', lvl: 5, hp: 260, atk: 17, def: 6, exp: 85, speed: 6, aggro: 9, range: 2.3, aspd: 1500, model: 'wolf', color: 0x3c3a40, scale: 1.3, respawn: 30, tael: [10, 25],
    drops: [['zanna_lupo', 0.6, 1, 2], ['ginseng_p', 0.15], ['loto_p', 0.1], ['pergamena_ritorno', 0.03]] },
  bandito: { name: 'Bandito della Strada', lvl: 8, hp: 420, atk: 26, def: 10, exp: 150, speed: 5, aggro: 10, range: 2.4, aspd: 1500, model: 'bandit', color: 0x3b2f2f, scale: 1, respawn: 30, tael: [25, 55],
    drops: [['benda_bandito', 0.4], ['ginseng_m', 0.08], ['minerale_ferro', 0.04], ['sciabola_bronzo', 0.006], ['pugnali_acciaio', 0.006], ['artigli_ferro', 0.006], ['bastone_pruno', 0.006], ['arco_corno', 0.006], ['corazza_lamelle', 0.006]] },
  scimmia: { name: 'Scimmia Ladra', lvl: 10, hp: 480, atk: 30, def: 12, exp: 185, speed: 6.5, aggro: 0, range: 2.0, aspd: 1200, model: 'monkey', color: 0x7a5230, scale: 1, respawn: 30, tael: [40, 90],
    drops: [['ginseng_m', 0.12], ['loto_m', 0.1], ['minerale_ferro', 0.05], ['elmo_bronzo', 0.008], ['stivali_cuoio', 0.008]] },
  arciere_bandito: { name: 'Arciere Bandito', lvl: 12, hp: 520, atk: 36, def: 12, exp: 230, speed: 5, aggro: 14, range: 13, ranged: true, aspd: 1900, model: 'bandit_archer', color: 0x3b3a2f, scale: 1, respawn: 35, tael: [40, 85],
    drops: [['benda_bandito', 0.4], ['ginseng_m', 0.1], ['minerale_ferro', 0.06], ['arco_corno', 0.01], ['corazza_lamelle', 0.008]] },
  orso_nero: { name: 'Orso Nero della Gola', lvl: 14, hp: 1100, atk: 48, def: 20, exp: 380, speed: 4.5, aggro: 0, range: 2.8, aspd: 2000, model: 'bear', color: 0x2a2420, scale: 1.25, respawn: 45, tael: [60, 120],
    drops: [['ginseng_m', 0.2, 1, 2], ['minerale_ferro', 0.1], ['elmo_bronzo', 0.01], ['corazza_lamelle', 0.01]] },
  spirito_lanterna: { name: 'Spirito della Lanterna', lvl: 16, hp: 800, atk: 52, def: 16, exp: 420, speed: 4, aggro: 12, range: 12, ranged: true, magic: true, aspd: 2000, model: 'lantern', color: 0xff8a3a, scale: 1, respawn: 40, tael: [70, 140],
    drops: [['loto_m', 0.2], ['loto_g', 0.04], ['minerale_ferro', 0.08], ['bastone_cielo', 0.004], ['stivali_vento', 0.004]] },
  terracotta: { name: 'Guerriero di Terracotta', lvl: 18, hp: 1500, atk: 62, def: 30, exp: 560, speed: 4, aggro: 10, range: 2.6, aspd: 1800, model: 'terracotta', color: 0xa86a42, scale: 1.1, respawn: 45, tael: [90, 180],
    drops: [['coccio_terracotta', 0.4], ['ginseng_g', 0.05], ['minerale_ferro', 0.1], ['spada_giada', 0.004], ['pugnali_serpe', 0.004], ['artigli_tigre', 0.004], ['arco_airone', 0.004], ['armatura_giada', 0.004], ['elmo_cornuto', 0.004]] },
  tigre_spettrale: { name: 'Tigre Spettrale', lvl: 21, hp: 1900, atk: 78, def: 32, exp: 720, speed: 6.5, aggro: 12, range: 2.6, aspd: 1500, model: 'tiger', color: 0xc8d0f0, scale: 1.2, respawn: 60, tael: [120, 220],
    drops: [['ginseng_g', 0.08], ['frammento_obelisco', 0.02], ['minerale_ferro', 0.12], ['artigli_tigre', 0.006], ['stivali_vento', 0.006]] },
  generale: { name: 'Generale Senza Volto', lvl: 25, hp: 18000, atk: 120, def: 45, exp: 9000, speed: 4.5, aggro: 14, range: 3.4, aspd: 2200, model: 'general', color: 0x2a1a1a, scale: 1.9, respawn: 900, boss: true, tael: [3000, 6000],
    drops: [['frammento_obelisco', 0.9, 2, 4], ['tomo_tecnica', 0.7, 1, 2], ['sigillo_fabbro', 0.35], ['spada_gru', 0.12], ['pugnali_eclissi', 0.12], ['arco_autunno', 0.12], ['guanti_sole', 0.12], ['bastone_nubi', 0.12], ['armatura_nubi', 0.1], ['elmo_drago', 0.1], ['stivali_nube', 0.1]] },
  fantoccio: { name: "Fantoccio d'Addestramento", lvl: 30, hp: 9999999, atk: 0, def: 25, exp: 0, dummy: true, model: 'dummy', color: 0xc8a860, scale: 1, respawn: 0, speed: 0, aggro: 0, drops: [] },
  obelisco_minore: { name: 'Obelisco Corrotto', lvl: 8, hp: 3000, atk: 0, def: 12, exp: 900, stone: true, waves: ['lupo_alfa', 'bandito'], wave: 3, model: 'obelisk', color: 0x8a3ac0, scale: 1, respawn: 300, tael: [200, 400],
    drops: [['tomo_tecnica', 0.12], ['minerale_ferro', 0.6, 1, 3], ['ginseng_m', 0.5, 2, 4], ['frammento_obelisco', 0.08], ['pergamena_ritorno', 0.3]] },
  obelisco_abisso: { name: "Obelisco dell'Abisso", lvl: 18, hp: 9000, atk: 0, def: 30, exp: 3500, stone: true, waves: ['terracotta', 'spirito_lanterna'], wave: 3, model: 'obelisk', color: 0xd03a4a, scale: 1.3, respawn: 420, tael: [600, 1200],
    drops: [['tomo_tecnica', 0.3], ['frammento_obelisco', 0.5, 1, 2], ['minerale_ferro', 0.8, 2, 4], ['sigillo_fabbro', 0.05], ['ginseng_g', 0.5, 2, 3]] },
};

// ------------------------------------------------------------------ fabbro
export const UPGRADE = {
  max: 15,
  chance: [95, 90, 80, 70, 60, 50, 40, 30, 20, 15, 12, 9, 7, 5, 3],
  cost: [300, 600, 1200, 2500, 5000, 10000, 20000, 40000, 80000, 120000, 160000, 220000, 300000, 400000, 550000],
  mats: [null, null, null, ['minerale_ferro', 1], ['minerale_ferro', 2], ['minerale_ferro', 3], ['frammento_obelisco', 1], ['frammento_obelisco', 2], ['frammento_obelisco', 3],
    ['essenza_celeste', 1], ['essenza_celeste', 1], ['essenza_celeste', 2], ['essenza_celeste', 2], ['essenza_celeste', 3], ['essenza_celeste', 4]],
  safeBelow: 3, // da +0 a +3 un fallimento non distrugge l'oggetto
  downgradeFrom: 9, // da +9 in su, con il sigillo, un fallimento fa scendere di un livello
  failBonus: 2, failBonusMax: 20, // perseveranza: +2% per ogni fallimento sullo stesso oggetto, fino a +20%
}

// ------------------------------------------------------------------ PNG
export const SHOPS = {
  armi: ['spada_ferro', 'sciabola_bronzo', 'pugnali_osso', 'pugnali_acciaio', 'arco_bambu', 'arco_corno', 'bende_seta', 'artigli_ferro', 'bastone_salice', 'bastone_pruno',
    'tunica_canapa', 'corazza_lamelle', 'cappello_paglia', 'elmo_bronzo', 'sandali', 'stivali_cuoio',
    'pietra_affinamento', 'pergamena_mutamento', 'scalpello', 'sigillo_fabbro'],
  erbe: ['ginseng_p', 'ginseng_m', 'ginseng_g', 'loto_p', 'loto_m', 'loto_g', 'pergamena_ritorno'],
};

export const NPC_ROLES = {
  armi: { name: 'Mastro Weng', title: 'Armaiolo' },
  erbe: { name: 'Nonna Lin', title: 'Erborista' },
  fabbro: { name: 'Fabbro Gao', title: 'Fabbro' },
  maestro: { name: 'Eremita Shou', title: 'Maestro delle Vie' },
  guardia: { name: 'Guardia', title: 'Guardia del villaggio' },
};

export const GUARD_LINES = [
  'Fuori dalle mura i lupi si fanno audaci. Non allontanarti senza infusi di ginseng.',
  "Dicono che al centro della valle, sull'altopiano, si aggiri un generale senza volto.",
  'Gli obelischi corrotti richiamano mostri quando vengono colpiti. Affrontali in compagnia.',
  'Oltre le mura vale la legge della spada: i guerrieri degli altri regni possono attaccarti.',
];
