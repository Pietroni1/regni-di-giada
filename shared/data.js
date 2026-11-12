// Dati di gioco condivisi tra server e client.
// Modifica questo file per bilanciare classi, abilità, oggetti e mostri.

export const MAX_LEVEL = 99;
export const INV_SIZE = 45;
export const QB_SIZE = 8;
export const STACK_MAX = 200;
export const STAT_MAX = 90;
export const EQUIP_SLOTS = ['weapon', 'head', 'body', 'feet'];
export const EQUIP_NAMES = { weapon: 'Arma', head: 'Copricapo', body: 'Armatura', feet: 'Calzari' };
export const STAT_NAMES = { vit: 'Vitalità', str: 'Forza', dex: 'Destrezza', int: 'Intelletto' };
export const STAT_DESC = {
  vit: 'Aumenta vita massima e difesa.',
  str: 'Aumenta l\'attacco fisico (Lama, Monaco).',
  dex: 'Aumenta attacco dell\'Ombra, critici, evasione e velocità d\'attacco.',
  int: 'Aumenta chi massimo e attacco magico.',
};
export const VIA_LEVEL = 5;
export const SKILL_MAX_POINTS = 10;
export const SKILL_MAX = 20;
export const BOOK_CHANCE = 0.5;

export function expToNext(l) { return Math.floor(80 * Math.pow(l, 1.85) + 40 * l); }
export function skillVal(arr, lvl) { return arr[0] + arr[1] * (lvl - 1); }
export function skillMp(sk, lvl) { return Math.round(sk.mp * (1 + 0.05 * (lvl - 1))); }
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

// ------------------------------------------------------------------ classi
// hp/mp: [base, per livello, per punto di vitalità/intelletto]
export const CLASSES = {
  lama: {
    name: 'Lama', title: 'Spadaccino errante', glyph: '剣',
    desc: 'Combattente corpo a corpo con la spada. Resistente, colpisce gruppi di nemici e regge la prima linea.',
    start: { vit: 5, str: 6, dex: 3, int: 2 }, hp: [130, 26, 22], mp: [30, 5, 12],
    primary: 'str', autoMagic: false, weapons: ['sword'],
    vie: ['montagna', 'fulmine'], baseSkill: 'fendente', startWeapon: 'spada_ferro', extraItems: [],
    look: { robe: 0x5b3a2c, trim: 0xb8a070, pants: 0x2e2620, armor: 0x8a8f96, hair: 0x1a1210, hairStyle: 'topknot' },
  },
  ombra: {
    name: 'Ombra', title: 'Lama dei vicoli', glyph: '影',
    desc: 'Agile e letale: pugnali da vicino o arco dalla distanza. Critici frequenti e grande mobilità.',
    start: { vit: 3, str: 4, dex: 7, int: 2 }, hp: [105, 21, 18], mp: [40, 7, 14],
    primary: 'dex', autoMagic: false, weapons: ['daggers', 'bow'],
    vie: ['pugnali', 'arco'], baseSkill: 'colpo_rapido', startWeapon: 'pugnali_osso', extraItems: ['arco_bambu'],
    look: { robe: 0x26293a, trim: 0x7a1e22, pants: 0x1c1e28, hair: 0x0e0e10, hairStyle: 'hood' },
  },
  monaco: {
    name: 'Monaco', title: 'Pugno del monastero', glyph: '拳',
    desc: 'Combatte a mani nude incanalando il chi. Ibrido tra forza fisica ed energia interiore.',
    start: { vit: 4, str: 5, dex: 4, int: 3 }, hp: [115, 24, 20], mp: [50, 8, 16],
    primary: 'str', autoMagic: false, weapons: ['fists'],
    vie: ['ferro', 'loto'], baseSkill: 'palmo_chi', startWeapon: 'bende_seta', extraItems: [],
    look: { robe: 0xc8681c, trim: 0x7a3b10, pants: 0x6a3a14, hair: null, hairStyle: 'bald' },
  },
  mistico: {
    name: 'Mistico', title: 'Veggente dei venti', glyph: '仙',
    desc: 'Incantatore con il bastone: cura e protegge gli alleati oppure scatena fulmini dal cielo.',
    start: { vit: 3, str: 2, dex: 3, int: 8 }, hp: [95, 19, 17], mp: [70, 12, 24],
    primary: 'int', autoMagic: true, weapons: ['staff'],
    vie: ['benedizione', 'tempesta'], baseSkill: 'dardo_luce', startWeapon: 'bastone_salice', extraItems: [],
    look: { robe: 0xdcd6c4, trim: 0x2f6a8a, pants: 0xbab4a0, hair: 0x22201e, hairStyle: 'long' },
  },
};

export const VIE = {
  montagna: { cls: 'lama', name: 'Via della Montagna', desc: 'Difesa incrollabile e controllo dei nemici.', skills: ['pelle_pietra', 'scossa', 'respiro_monte'] },
  fulmine: { cls: 'lama', name: 'Via del Fulmine', desc: 'Velocità e danni devastanti su un singolo bersaglio.', skills: ['carica', 'lama_tuono', 'furia'] },
  pugnali: { cls: 'ombra', name: 'Via dei Pugnali', desc: 'Colpi rapidi, veleni e scatti alle spalle del nemico. Richiede pugnali.', skills: ['passo_ombra', 'lama_veleno', 'danza_lame'] },
  arco: { cls: 'ombra', name: "Via dell'Arco", desc: 'Precisione letale dalla distanza. Richiede un arco.', skills: ['freccia_perforante', 'pioggia_frecce', 'occhio_falco'] },
  ferro: { cls: 'monaco', name: 'Via del Pugno di Ferro', desc: 'Raffiche di colpi e corpo temprato come il bronzo.', skills: ['raffica', 'pelle_bronzo', 'calcio_drago'] },
  loto: { cls: 'monaco', name: 'Via del Loto Interiore', desc: 'Onde di chi a distanza e rigenerazione.', skills: ['onda_chi', 'meditazione', 'sigillo_interiore'] },
  benedizione: { cls: 'mistico', name: 'Via della Benedizione', desc: 'Cure e protezioni per sé e per gli alleati del regno.', skills: ['tocco_curativo', 'benedizione', 'loto_rigenerante'] },
  tempesta: { cls: 'mistico', name: 'Via della Tempesta', desc: 'Fulmini e venti gelidi contro i nemici.', skills: ['fulmine_celeste', 'catena_fulmini', 'vento_gelido'] },
};

// ------------------------------------------------------------------ abilità
// mult/heal/stun/buff: [valore al livello 1, incremento per livello]
export const SKILLS = {
  // Lama
  fendente: { name: 'Fendente Rotante', cls: 'lama', type: 'aoe_self', dmg: 'phys', mult: [1.4, 0.07], radius: 4.5, mp: 12, cd: 6, glyph: '旋', color: 0xffd27a, fx: 'spin', desc: 'Una rotazione completa della lama che colpisce tutti i nemici intorno a te.' },
  pelle_pietra: { name: 'Pelle di Pietra', cls: 'lama', via: 'montagna', type: 'buff_self', buff: { defPct: [20, 2] }, dur: 60, mp: 30, cd: 90, glyph: '岩', color: 0xc0a070, fx: 'aura', desc: 'Il corpo si indurisce come la roccia: difesa aumentata.' },
  scossa: { name: 'Scossa della Terra', cls: 'lama', via: 'montagna', type: 'aoe_self', dmg: 'phys', mult: [1.6, 0.09], radius: 6, stun: [1.2, 0.05], mp: 26, cd: 12, glyph: '震', color: 0xc9a66b, fx: 'quake', desc: 'Colpisci il suolo: danni ad area e stordimento.' },
  respiro_monte: { name: 'Respiro del Monte', cls: 'lama', via: 'montagna', type: 'heal_self', heal: [0.12, 0.012], mp: 35, cd: 30, glyph: '息', color: 0x7fd07f, fx: 'heal', desc: 'Un respiro profondo ripristina parte della vita massima.' },
  carica: { name: 'Carica Fulminea', cls: 'lama', via: 'fulmine', type: 'strike', dash: true, range: 14, dmg: 'phys', mult: [1.8, 0.1], stun: [0.6, 0.03], mp: 22, cd: 10, glyph: '突', color: 0x9fd4ff, fx: 'dash', desc: 'Scatti verso il bersaglio, lo colpisci e lo stordisci.' },
  lama_tuono: { name: 'Lama del Tuono', cls: 'lama', via: 'fulmine', type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.8, 0.15], mp: 28, cd: 8, glyph: '雷', color: 0x9fd4ff, fx: 'lightning', desc: 'Un fendente carico di fulmine su un singolo nemico.' },
  furia: { name: 'Furia', cls: 'lama', via: 'fulmine', type: 'buff_self', buff: { aspdPct: [15, 1.5], atkPct: [8, 0.8] }, dur: 45, mp: 30, cd: 80, glyph: '怒', color: 0xff5a3a, fx: 'aura', desc: "Velocità d'attacco e attacco aumentati." },
  // Ombra
  colpo_rapido: { name: 'Colpo Rapido', cls: 'ombra', type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.7, 0.08], mp: 10, cd: 5, glyph: '速', color: 0xe0e0ff, fx: 'slash', desc: "Un colpo fulmineo con l'arma impugnata (pugnali o arco)." },
  passo_ombra: { name: "Passo d'Ombra", cls: 'ombra', via: 'pugnali', req: 'daggers', type: 'strike', dash: true, behind: true, range: 12, dmg: 'phys', mult: [2.1, 0.11], mp: 22, cd: 10, glyph: '潜', color: 0x9a7ad0, fx: 'dash', desc: 'Ti materializzi alle spalle del bersaglio e lo colpisci.' },
  lama_veleno: { name: 'Lama Avvelenata', cls: 'ombra', via: 'pugnali', req: 'daggers', type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.2, 0.06], dot: { mult: [0.25, 0.015], dur: 8 }, mp: 18, cd: 9, glyph: '毒', color: 0x6fd04a, fx: 'slash', desc: 'Il veleno continua a infliggere danni per 8 secondi.' },
  danza_lame: { name: 'Danza delle Lame', cls: 'ombra', via: 'pugnali', req: 'daggers', type: 'aoe_self', dmg: 'phys', mult: [1.7, 0.09], radius: 4.5, mp: 26, cd: 11, glyph: '舞', color: 0xd0d0ff, fx: 'spin', desc: 'Una vorticosa danza di pugnali colpisce chi ti circonda.' },
  freccia_perforante: { name: 'Freccia Perforante', cls: 'ombra', via: 'arco', req: 'bow', type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.4, 0.13], mp: 20, cd: 7, glyph: '貫', color: 0xffe08a, fx: 'arrow', desc: 'Una freccia caricata che trapassa le difese.' },
  pioggia_frecce: { name: 'Pioggia di Frecce', cls: 'ombra', via: 'arco', req: 'bow', type: 'aoe_target', range: 'weapon', radius: 5, dmg: 'phys', mult: [1.4, 0.08], mp: 30, cd: 12, glyph: '雨', color: 0xffe08a, fx: 'rain', desc: "Una pioggia di frecce sull'area del bersaglio." },
  occhio_falco: { name: 'Occhio del Falco', cls: 'ombra', via: 'arco', type: 'buff_self', buff: { critPct: [10, 1], atkPct: [5, 0.5] }, dur: 60, mp: 25, cd: 75, glyph: '鷹', color: 0xffc04a, fx: 'aura', desc: 'Concentrazione assoluta: più critici e più danni.' },
  // Monaco
  palmo_chi: { name: 'Palmo di Chi', cls: 'monaco', type: 'strike', range: 9, dmg: 'hybrid', mult: [1.5, 0.08], mp: 12, cd: 5, glyph: '掌', color: 0xffb04a, fx: 'bolt', desc: 'Un colpo di palmo proietta il chi verso il nemico.' },
  raffica: { name: 'Raffica dei Cento Pugni', cls: 'monaco', via: 'ferro', type: 'strike', range: 'weapon', hits: 4, dmg: 'phys', mult: [0.75, 0.04], mp: 24, cd: 9, glyph: '連', color: 0xffd27a, fx: 'slash', desc: 'Quattro colpi in rapidissima successione.' },
  pelle_bronzo: { name: 'Pelle di Bronzo', cls: 'monaco', via: 'ferro', type: 'buff_self', buff: { defPct: [22, 2], hpRegen: [1, 0.1] }, dur: 60, mp: 30, cd: 90, glyph: '銅', color: 0xc8883a, fx: 'aura', desc: 'Difesa aumentata e lenta rigenerazione della vita.' },
  calcio_drago: { name: 'Calcio della Gru', cls: 'monaco', via: 'ferro', type: 'aoe_self', dmg: 'phys', mult: [1.8, 0.1], radius: 5, stun: [1.0, 0.05], mp: 28, cd: 12, glyph: '鶴', color: 0xff8a3a, fx: 'quake', desc: 'Un calcio rotante che stordisce i nemici vicini.' },
  onda_chi: { name: 'Onda di Chi', cls: 'monaco', via: 'loto', type: 'aoe_target', range: 14, radius: 4.5, dmg: 'magic', mult: [1.9, 0.1], mp: 28, cd: 9, glyph: '波', color: 0xffc85a, fx: 'bolt', desc: "Un'onda di energia esplode sul bersaglio e intorno a lui." },
  meditazione: { name: 'Meditazione', cls: 'monaco', via: 'loto', type: 'hot_self', heal: [0.035, 0.003], dur: 10, mp: 30, cd: 40, glyph: '禅', color: 0x7fd07f, fx: 'heal', desc: 'Rigenera una parte della vita ogni secondo per 10 secondi.' },
  sigillo_interiore: { name: 'Sigillo Interiore', cls: 'monaco', via: 'loto', type: 'buff_self', buff: { matkPct: [18, 1.8], atkPct: [6, 0.6] }, dur: 60, mp: 30, cd: 80, glyph: '印', color: 0xffe0a0, fx: 'aura', desc: 'Il chi si concentra: attacco magico e fisico aumentati.' },
  // Mistico
  dardo_luce: { name: 'Dardo di Luce', cls: 'mistico', type: 'strike', range: 18, dmg: 'magic', mult: [1.5, 0.08], mp: 10, cd: 4, glyph: '光', color: 0xfff4b0, fx: 'bolt', desc: 'Un dardo di luce colpisce un nemico a distanza.' },
  tocco_curativo: { name: 'Tocco Curativo', cls: 'mistico', via: 'benedizione', type: 'heal_target', range: 18, heal: [2.2, 0.15], mp: 25, cd: 6, glyph: '癒', color: 0x7fd07f, fx: 'heal', desc: 'Cura un alleato del tuo regno, oppure te stesso se non hai un alleato selezionato.' },
  benedizione: { name: 'Benedizione', cls: 'mistico', via: 'benedizione', type: 'buff_allies', radius: 14, buff: { defPct: [12, 1.2], atkPct: [6, 0.6] }, dur: 120, mp: 40, cd: 60, glyph: '福', color: 0xfff0a0, fx: 'aura', desc: 'Tu e gli alleati vicini del tuo regno ricevete più difesa e attacco.' },
  loto_rigenerante: { name: 'Loto Rigenerante', cls: 'mistico', via: 'benedizione', type: 'hot_target', range: 18, heal: [0.03, 0.003], dur: 12, mp: 30, cd: 20, glyph: '蓮', color: 0xf0a0d0, fx: 'heal', desc: 'Un fiore di loto rigenera la vita del bersaglio nel tempo.' },
  fulmine_celeste: { name: 'Fulmine Celeste', cls: 'mistico', via: 'tempesta', type: 'strike', range: 18, dmg: 'magic', mult: [2.6, 0.14], mp: 26, cd: 7, glyph: '電', color: 0xa0d8ff, fx: 'lightning', desc: 'Un fulmine dal cielo si abbatte sul bersaglio.' },
  catena_fulmini: { name: 'Tempesta di Saette', cls: 'mistico', via: 'tempesta', type: 'aoe_target', range: 18, radius: 5, dmg: 'magic', mult: [1.6, 0.09], mp: 34, cd: 11, glyph: '嵐', color: 0xa0d8ff, fx: 'lightning', desc: 'Saette colpiscono tutti i nemici attorno al bersaglio.' },
  vento_gelido: { name: 'Vento Gelido', cls: 'mistico', via: 'tempesta', type: 'aoe_self', radius: 7, dmg: 'magic', mult: [1.1, 0.06], slow: { dur: 4 }, mp: 28, cd: 14, glyph: '氷', color: 0xc0f0ff, fx: 'wind', desc: 'Un vento gelido danneggia e rallenta i nemici intorno a te.' },
};

export const BUFF_NAMES = {
  defPct: 'Difesa', atkPct: 'Attacco', matkPct: 'Attacco magico', aspdPct: "Velocità d'attacco", critPct: 'Critico', hpRegen: 'Rigenerazione vita',
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
  loto_p: { name: 'Tè di Loto (piccolo)', type: 'potion', mp: 60, price: 25, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina 60 punti chi.' },
  loto_m: { name: 'Tè di Loto (medio)', type: 'potion', mp: 180, price: 110, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina 180 punti chi.' },
  loto_g: { name: 'Tè di Loto (grande)', type: 'potion', mp: 480, price: 380, stack: true, glyph: '茶', color: '#2a5ab8', desc: 'Ripristina 480 punti chi.' },
  pergamena_ritorno: { name: 'Pergamena del Ritorno', type: 'scroll', price: 150, stack: true, glyph: '帰', color: '#8a6a2a', desc: 'Ti riporta al villaggio del tuo regno. Non utilizzabile in combattimento.' },
  // Materiali
  zanna_lupo: { name: 'Zanna di Lupo', type: 'material', price: 40, stack: true, glyph: '牙', color: '#6a6a6a', desc: 'Un trofeo di caccia. Si vende ai mercanti.' },
  pelle_cinghiale: { name: 'Pelle di Cinghiale', type: 'material', price: 50, stack: true, glyph: '皮', color: '#6a4a2a', desc: 'Pelle robusta. Si vende ai mercanti.' },
  benda_bandito: { name: 'Benda del Bandito', type: 'material', price: 90, stack: true, glyph: '布', color: '#7a2a2a', desc: 'Strappata a un fuorilegge. Si vende ai mercanti.' },
  coccio_terracotta: { name: 'Coccio di Terracotta', type: 'material', price: 200, stack: true, glyph: '陶', color: '#a0603a', desc: 'Frammento di un guerriero animato. Si vende ai mercanti.' },
  minerale_ferro: { name: 'Minerale di Ferro Grezzo', type: 'material', price: 300, stack: true, glyph: '鉄', color: '#4a5a6a', desc: 'Il fabbro lo richiede per i potenziamenti da +4 a +6.' },
  frammento_obelisco: { name: "Frammento d'Obelisco", type: 'material', price: 1200, stack: true, glyph: '晶', color: '#6a3a8a', desc: 'Il fabbro lo richiede per i potenziamenti da +7 a +9.' },
  tomo_tecnica: { name: 'Tomo della Tecnica', type: 'book', price: 5000, stack: true, glyph: '書', color: '#2a6a4a', desc: "Permette di studiare un'abilità oltre il livello 10 (50% di successo). Si usa dal tasto + nella finestra Abilità." },
  sigillo_fabbro: { name: 'Sigillo del Fabbro', type: 'seal', price: 8000, stack: true, glyph: '印', color: '#8a7a2a', desc: "Se un potenziamento rischioso fallisce, l'oggetto non viene distrutto (il sigillo si consuma)." },
};

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
  obelisco_minore: { name: 'Obelisco Corrotto', lvl: 8, hp: 3000, atk: 0, def: 12, exp: 900, stone: true, waves: ['lupo_alfa', 'bandito'], wave: 3, model: 'obelisk', color: 0x8a3ac0, scale: 1, respawn: 300, tael: [200, 400],
    drops: [['tomo_tecnica', 0.12], ['minerale_ferro', 0.6, 1, 3], ['ginseng_m', 0.5, 2, 4], ['frammento_obelisco', 0.08], ['pergamena_ritorno', 0.3]] },
  obelisco_abisso: { name: "Obelisco dell'Abisso", lvl: 18, hp: 9000, atk: 0, def: 30, exp: 3500, stone: true, waves: ['terracotta', 'spirito_lanterna'], wave: 3, model: 'obelisk', color: 0xd03a4a, scale: 1.3, respawn: 420, tael: [600, 1200],
    drops: [['tomo_tecnica', 0.3], ['frammento_obelisco', 0.5, 1, 2], ['minerale_ferro', 0.8, 2, 4], ['sigillo_fabbro', 0.05], ['ginseng_g', 0.5, 2, 3]] },
};

// ------------------------------------------------------------------ fabbro
export const UPGRADE = {
  max: 9,
  chance: [95, 90, 80, 70, 60, 50, 40, 30, 20],
  cost: [300, 600, 1200, 2500, 5000, 10000, 20000, 40000, 80000],
  mats: [null, null, null, ['minerale_ferro', 1], ['minerale_ferro', 2], ['minerale_ferro', 3], ['frammento_obelisco', 1], ['frammento_obelisco', 2], ['frammento_obelisco', 3]],
  safeBelow: 3, // da +0 a +3 un fallimento non distrugge l'oggetto
};

// ------------------------------------------------------------------ PNG
export const SHOPS = {
  armi: ['spada_ferro', 'sciabola_bronzo', 'pugnali_osso', 'pugnali_acciaio', 'arco_bambu', 'arco_corno', 'bende_seta', 'artigli_ferro', 'bastone_salice', 'bastone_pruno',
    'tunica_canapa', 'corazza_lamelle', 'cappello_paglia', 'elmo_bronzo', 'sandali', 'stivali_cuoio'],
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
