// Mappe da esperienza e Arena: zone lontane dal mondo aperto, raggiunte con la Guida dei Sentieri (PNG `guida`).
// Ogni mappa è un'area percorribile attorno al suo centro (cx, cz), molto oltre le istanze della cripta, con un
// terreno proprio calcolato da altezzaMappa: il server la usa direttamente, il client Godot riceve le stesse altezze
// in griglia (tools/godot/esporta.mjs → godot/dati/mappe.bin). Coordinate «locali» = relative al centro della mappa.
// Questo file non importa nulla (data.js e world.js lo importano): niente dipendenze circolari.

export const MAPPE_X = 5000;       // oltre questa x ci sono solo le mappe (le istanze della cripta stanno a 1200 + 400 × posto)
export const MAPPE_REGIONE = 500;  // ogni mappa possiede il quadrato centro ± 500

// ------------------------------------------------------------------ definizioni
// tipo: 'caccia' (mostri e obelischi) o 'arena' (PvP libero).
// raggio: cerchio percorribile; oltre, il terreno sale (montagne o dune) e il movimento si ferma.
// arrivo: punto d'arrivo (zona sicura di raggio `sicuro`); guida: dove sta il PNG per tornare.
// branchi: [tipo, gruppi, [min, max] per gruppo, distanza minima e massima dall'arrivo]
// obelischi: [tipo, x, z] locali. tema: aspetto nel client (colori del terreno, cielo, nebbia, piante).
export const MAPPE = {
  selva: {
    nome: 'Selva dei Mille Steli', tipo: 'caccia', cx: 6000, cz: 0, raggio: 160, liv: [30, 40], minLvl: 28, prezzo: 2000,
    desc: 'Una foresta di bambù giganti dove il vento canta fra le canne. Briganti, scimmie urlatrici e spiriti cavi; nel cuore della selva si aggirano le Tigri di Smeraldo.',
    arrivo: { x: 0, z: -138 }, sicuro: 14, guida: { x: 4, z: -133 },
    terreno: { forma: 'colline', base: 6, ampiezza: 22, frequenza: 0.011, seme: 301, bordo: 34 },
    branchi: [
      ['lupo_canne', 7, [4, 5], 38, 140],
      ['scimmia_urlatrice', 6, [4, 4], 50, 170],
      ['brigante_selva', 5, [3, 4], 110, 230],
      ['cerbottaniere_selva', 4, [3, 3], 120, 240],
      ['spirito_canna', 4, [3, 3], 180, 290],
      ['orso_ventre_giada', 3, [1, 1], 140, 260],
      ['tigre_smeraldo', 2, [1, 1], 220, 300],
      ['lupo_canne', 2, [10, 10], 60, 110],   // radure affollate: grind ad area
    ],
    obelischi: [['obelisco_canne', -72, -20], ['obelisco_canne', 82, 12], ['obelisco_giada_marcia', 0, 112]],
    tema: {
      cielo: '#5d8fb0', orizzonte: '#c8dcc0', nebbia: '#9cc0a2', densita: 0.0042, sole: '#f2f0d0', luce: 0.95,
      suolo: ['#1d3417', '#34502a'], macchie: '#6a6a2c', terra: '#4a3a24', roccia: '#4a4f44', lastrico: '#7a7466',
      piante: { bambu: 0.62, pino: 0.06, cespuglio: 0.05, roccia: 0.02, acero: 0.01 },
      tinte: { bambu: ['#ffffff', '#e0ffd8', '#f4ffe0'], pino: ['#c8f0c0'], cespuglio: ['#d0ffc8', '#ffffff'], acero: ['#ffe0a0'] },
      fitta: 4.0, tetto: '#24402a', accento: '#3a8a5a', quotaRoccia: 24,
    },
  },
  distesa: {
    nome: 'Distesa dei Venti Rossi', tipo: 'caccia', cx: 7000, cz: 0, raggio: 170, liv: [40, 50], minLvl: 38, prezzo: 4000,
    desc: "Dune color ruggine e rocce scolpite dal vento. Predoni del deserto, guerrieri d'arenaria risvegliati e miraggi che non svaniscono quando li tocchi.",
    arrivo: { x: 0, z: -150 }, sicuro: 14, guida: { x: 4, z: -145 },
    terreno: { forma: 'dune', base: 5, ampiezza: 12, frequenza: 0.008, seme: 557, bordo: 40 },
    branchi: [
      ['sciacallo_dune', 7, [4, 5], 38, 150],
      ['cinghiale_zanne_ferro', 5, [3, 4], 50, 170],
      ['predone_dune', 5, [4, 4], 110, 240],
      ['arciere_simun', 4, [3, 3], 130, 250],
      ['guerriero_arenaria', 4, [3, 3], 180, 300],
      ['anima_miraggio', 4, [3, 4], 150, 290],
      ['campione_arenaria', 2, [1, 1], 200, 300],
      ['tigre_sole_rovente', 2, [1, 1], 220, 310],
      ['sciacallo_dune', 2, [10, 10], 60, 110],
    ],
    obelischi: [['obelisco_sabbia', -92, -30], ['obelisco_sabbia', 96, 0], ['obelisco_miraggio', 10, 122]],
    tema: {
      cielo: '#c08850', orizzonte: '#f0c890', nebbia: '#e0a870', densita: 0.0036, sole: '#ffd8a0', luce: 1.25,
      suolo: ['#a0582c', '#d08a4c'], macchie: '#e8b070', terra: '#6a3a20', roccia: '#7a4a32', lastrico: '#9a7a5a',
      piante: { roccia: 0.08, cespuglio: 0.05, acero: 0.012, pino: 0.006 },
      tinte: { cespuglio: ['#c8a060', '#a08048'], acero: ['#ff9050', '#e07038'], pino: ['#a09060'] },
      fitta: 5.5, dune: 1, tetto: '#6a3220', accento: '#c8742c', quotaRoccia: 60,
    },
  },
  arena: {
    nome: 'Arena del Loto Cremisi', tipo: 'arena', cx: 8000, cz: 0, raggio: 58, liv: null, minLvl: 10, prezzo: 0,
    desc: 'Un anello di pietra dove i guerrieri dei tre regni si sfidano senza bandiere: dentro tutti possono colpire tutti, tranne i compagni di gruppo. Nessuna perdita alla morte; si rinasce alle porte.',
    porte: 4, distNicchia: 67, nicchia: 6.5, corridoio: 3,
    terreno: { forma: 'arena', base: 2, piano: 78, bordo: 18, seme: 911 },
    tema: {
      cielo: '#4a6a9a', orizzonte: '#e8c8b0', nebbia: '#d0b0a0', densita: 0.0025, sole: '#ffe8c8', luce: 1.1,
      suolo: ['#3a5a26', '#5a7034'], macchie: '#7a7a3a', terra: '#5a4630', roccia: '#5a5650', lastrico: '#8a7e6e',
      piante: { ciliegio: 0.12, pino: 0.1, cespuglio: 0.06, roccia: 0.02 },
      tinte: { ciliegio: ['#ffffff', '#ffd8e8'], pino: ['#e0ffe0'], cespuglio: ['#ffffff'] },
      fitta: 6.0, tetto: '#4a1a16', accento: '#b02a22', quotaRoccia: 12,
    },
  },
};
export const MAPPE_IDS = Object.keys(MAPPE);

// ------------------------------------------------------------------ mostri delle mappe (aggiunti a MOBS in data.js)
// Stessi campi di MOBS. Le élite (vita ≥ 1000) hanno la Postura; `cast` = lancio interrompibile.
const GEAR4 = ['spada_gru', 'pugnali_eclissi', 'arco_autunno', 'guanti_sole', 'bastone_nubi', 'armatura_nubi', 'elmo_drago', 'stivali_nube'];
const comuni = (p) => [['ginseng_g', 0.06 * p], ['loto_g', 0.05 * p], ['minerale_ferro', 0.08 * p], ['frammento_obelisco', 0.012 * p]];
const elite = (p) => [['ginseng_g', 0.4, 1, 2], ['frammento_obelisco', 0.15 * p], ['essenza_celeste', 0.05 * p], ['tomo_tecnica', 0.04 * p], ['sigillo_fabbro', 0.02 * p], ...GEAR4.map(id => [id, 0.006 * p])];

export const MOBS_MAPPE = {
  // --- Selva dei Mille Steli (30-40)
  lupo_canne: { name: 'Lupo delle Canne', lvl: 30, hp: 880, atk: 92, def: 30, exp: 430, speed: 6, aggro: 9, range: 2.1, aspd: 1500, model: 'wolf', color: 0x5d6b52, scale: 1.05, respawn: 18, tael: [60, 120], drops: comuni(1) },
  scimmia_urlatrice: { name: 'Scimmia Urlatrice', lvl: 32, hp: 920, atk: 98, def: 32, exp: 480, speed: 6.5, aggro: 0, range: 2.0, aspd: 1200, model: 'monkey', color: 0x8a6a3a, scale: 1.1, respawn: 18, tael: [70, 130], drops: comuni(1) },
  brigante_selva: { name: 'Brigante della Selva', lvl: 34, hp: 980, atk: 106, def: 36, exp: 540, speed: 5.2, aggro: 11, range: 2.4, aspd: 1500, model: 'bandit', color: 0x2f4a32, scale: 1, respawn: 22, tael: [80, 150], drops: comuni(1.2) },
  cerbottaniere_selva: { name: 'Cerbottaniere Nascosto', cast: { name: 'Dardo Soporifero', ms: 1800, mult: 2.6, cd: 9000 }, lvl: 35, hp: 860, atk: 110, def: 30, exp: 580, speed: 5, aggro: 14, range: 13, ranged: true, aspd: 1900, model: 'bandit_archer', color: 0x3a5a3a, scale: 1, respawn: 24, tael: [80, 160], drops: comuni(1.2) },
  spirito_canna: { name: 'Spirito della Canna Cava', cast: { name: 'Lamento del Vento', ms: 2200, mult: 2.7, cd: 8500 }, lvl: 37, hp: 900, atk: 118, def: 28, exp: 640, speed: 4, aggro: 13, range: 12, ranged: true, magic: true, aspd: 2000, model: 'lantern', color: 0x9adf8a, scale: 1.05, respawn: 24, tael: [90, 170], drops: comuni(1.4) },
  orso_ventre_giada: { name: 'Orso dal Ventre di Giada', cast: { name: 'Zampata Sismica', ms: 2400, mult: 2.2, cd: 12000, raggio: 7 }, lvl: 36, hp: 4600, atk: 140, def: 46, exp: 2300, speed: 4.6, aggro: 0, range: 2.9, aspd: 2000, model: 'bear', color: 0x1f3a26, scale: 1.45, respawn: 90, tael: [300, 600], drops: elite(1) },
  tigre_smeraldo: { name: 'Tigre di Smeraldo', lvl: 39, hp: 5400, atk: 155, def: 48, exp: 2700, speed: 6.6, aggro: 13, range: 2.7, aspd: 1450, model: 'tiger', color: 0x3f8a5a, scale: 1.4, respawn: 120, tael: [350, 700], drops: elite(1.2) },
  obelisco_canne: { name: 'Obelisco delle Canne Spezzate', lvl: 34, hp: 22000, atk: 0, def: 40, exp: 9000, stone: true, waves: ['brigante_selva', 'scimmia_urlatrice', 'lupo_canne'], wave: 3, model: 'obelisk', color: 0x3ac07a, scale: 1.35, respawn: 360, tael: [800, 1500],
    drops: [['tomo_tecnica', 0.3], ['frammento_obelisco', 0.6, 1, 3], ['minerale_ferro', 0.8, 2, 4], ['sigillo_fabbro', 0.06], ['ginseng_g', 0.6, 2, 3], ['essenza_celeste', 0.15]] },
  obelisco_giada_marcia: { name: 'Obelisco della Giada Marcia', lvl: 39, hp: 30000, atk: 0, def: 44, exp: 13000, stone: true, waves: ['cerbottaniere_selva', 'spirito_canna', 'brigante_selva'], wave: 3, model: 'obelisk', color: 0x7ad04a, scale: 1.5, respawn: 480, tael: [1200, 2200],
    drops: [['tomo_tecnica', 0.4], ['frammento_obelisco', 0.8, 2, 3], ['essenza_celeste', 0.3, 1, 2], ['sigillo_fabbro', 0.1], ['ginseng_g', 0.6, 2, 4]] },
  // --- Distesa dei Venti Rossi (40-50)
  sciacallo_dune: { name: 'Sciacallo delle Dune', lvl: 40, hp: 950, atk: 128, def: 42, exp: 760, speed: 6.4, aggro: 10, range: 2.0, aspd: 1400, model: 'wolf', color: 0xb08850, scale: 0.95, respawn: 18, tael: [110, 200], drops: comuni(1.4) },
  cinghiale_zanne_ferro: { name: 'Cinghiale dalle Zanne di Ferro', lvl: 42, hp: 990, atk: 134, def: 46, exp: 820, speed: 5.4, aggro: 0, range: 2.3, aspd: 1600, model: 'boar', color: 0x6a4a3a, scale: 1.3, respawn: 20, tael: [120, 220], drops: comuni(1.4) },
  predone_dune: { name: 'Predone delle Dune', lvl: 44, hp: 990, atk: 142, def: 46, exp: 880, speed: 5.2, aggro: 11, range: 2.4, aspd: 1500, model: 'bandit', color: 0x8a4a2a, scale: 1, respawn: 22, tael: [130, 240], drops: comuni(1.6) },
  arciere_simun: { name: 'Arciere del Simun', cast: { name: 'Freccia del Vento Rosso', ms: 1800, mult: 2.6, cd: 9000 }, lvl: 45, hp: 900, atk: 146, def: 40, exp: 920, speed: 5, aggro: 14, range: 13, ranged: true, aspd: 1900, model: 'bandit_archer', color: 0x7a3a22, scale: 1, respawn: 24, tael: [130, 250], drops: comuni(1.6) },
  anima_miraggio: { name: 'Anima del Miraggio', lvl: 46, hp: 940, atk: 150, def: 36, exp: 950, speed: 6.8, aggro: 13, range: 2.3, aspd: 1300, model: 'shade', color: 0xe0a060, scale: 1.05, respawn: 22, tael: [140, 260], drops: comuni(1.8) },
  guerriero_arenaria: { name: "Guerriero d'Arenaria", lvl: 47, hp: 990, atk: 152, def: 56, exp: 980, speed: 4.2, aggro: 10, range: 2.6, aspd: 1800, model: 'terracotta', color: 0xc89a62, scale: 1.1, respawn: 24, tael: [150, 280], drops: comuni(1.8) },
  campione_arenaria: { name: "Campione d'Arenaria", cast: { name: 'Fendente delle Dune', ms: 2600, mult: 2.4, cd: 13000, raggio: 8 }, lvl: 48, hp: 6500, atk: 190, def: 60, exp: 3600, speed: 4.4, aggro: 12, range: 3.0, aspd: 2000, model: 'terracotta', color: 0xb07040, scale: 1.5, respawn: 120, tael: [500, 900], drops: elite(1.5) },
  tigre_sole_rovente: { name: 'Tigre del Sole Rovente', lvl: 49, hp: 6000, atk: 200, def: 56, exp: 3800, speed: 6.8, aggro: 13, range: 2.7, aspd: 1450, model: 'tiger', color: 0xe08a30, scale: 1.4, respawn: 140, tael: [550, 950], drops: elite(1.6) },
  obelisco_sabbia: { name: 'Obelisco della Sabbia Cantante', lvl: 44, hp: 38000, atk: 0, def: 50, exp: 15000, stone: true, waves: ['predone_dune', 'sciacallo_dune', 'cinghiale_zanne_ferro'], wave: 3, model: 'obelisk', color: 0xe07a30, scale: 1.4, respawn: 420, tael: [1500, 2600],
    drops: [['tomo_tecnica', 0.4], ['frammento_obelisco', 0.8, 2, 4], ['essenza_celeste', 0.35, 1, 2], ['sigillo_fabbro', 0.1], ['ginseng_g', 0.6, 2, 4]] },
  obelisco_miraggio: { name: 'Obelisco del Miraggio', lvl: 49, hp: 50000, atk: 0, def: 56, exp: 21000, stone: true, waves: ['guerriero_arenaria', 'anima_miraggio', 'arciere_simun'], wave: 3, model: 'obelisk', color: 0xf0d060, scale: 1.6, respawn: 540, tael: [2200, 3600],
    drops: [['tomo_tecnica', 0.5, 1, 2], ['frammento_obelisco', 0.9, 2, 4], ['essenza_celeste', 0.5, 1, 3], ['sigillo_fabbro', 0.15], ['sigillo_ascensione', 0.06]] },
};

// PNG delle mappe (aggiunti a NPC_ROLES in data.js)
export const NPC_MAPPE = {
  guida: { name: 'Viandante Lu', title: 'Guida dei Sentieri Lontani' },
  araldo: { name: 'Araldo Mo', title: "Araldo dell'Arena" },
};

// ------------------------------------------------------------------ rumore (copia di quello di world.js)
function hash2(ix, iz, seed) {
  let h = (Math.imul(ix, 374761393) + Math.imul(iz, 668265263) + Math.imul(seed, 982451653)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
function noise2(x, z, seed) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const a = hash2(ix, iz, seed), b = hash2(ix + 1, iz, seed);
  const c = hash2(ix, iz + 1, seed), d = hash2(ix + 1, iz + 1, seed);
  const u = fx * fx * (3 - 2 * fx), v = fz * fz * (3 - 2 * fz);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export function fbmMappa(x, z, oct, seed) {
  let s = 0, amp = 1, f = 1, norm = 0;
  for (let i = 0; i < oct; i++) {
    s += noise2(x * f, z * f, seed + i * 17) * amp;
    norm += amp; amp *= 0.5; f *= 2;
  }
  return s / norm;
}
const lisc = (e0, e1, x) => { const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };

// ------------------------------------------------------------------ geografia
// Quale mappa contiene il punto (id o null).
export function mappaAt(x, z) {
  if (!(x > MAPPE_X)) return null;
  for (const id of MAPPE_IDS) {
    const m = MAPPE[id];
    if (Math.abs(x - m.cx) < MAPPE_REGIONE && Math.abs(z - m.cz) < MAPPE_REGIONE) return id;
  }
  return null;
}

// Altezza «grezza» in coordinate locali (senza lo spiazzo dell'arrivo).
function grezza(m, lx, lz) {
  const T = m.terreno, d = Math.hypot(lx, lz);
  if (T.forma === 'arena') {
    // anello piano (pavimento, porte e nicchie), poi colline tutto intorno
    if (d <= T.piano) return T.base;
    const t = (d - T.piano) / 40;
    return T.base + t * t * T.bordo + fbmMappa(lx * 0.03, lz * 0.03, 3, T.seme) * Math.min(1, t) * 7;
  }
  let h;
  if (T.forma === 'dune') {
    // dune lunghe e ondulate, increspate dal vento
    const larga = (fbmMappa(lx * T.frequenza, lz * T.frequenza, 3, T.seme) - 0.45) * T.ampiezza;
    const fase = (lx * 0.75 + lz * 0.35) * 0.045 + fbmMappa(lx * 0.01, lz * 0.01, 2, T.seme + 3) * 6;
    const cresta = Math.pow((Math.sin(fase) + 1) / 2, 2.2) * 6.5;
    h = T.base + larga + cresta;
  } else {
    // colline e vallette
    h = T.base + (fbmMappa(lx * T.frequenza, lz * T.frequenza, 4, T.seme) - 0.45) * T.ampiezza;
    h += (fbmMappa(lx * 0.05 + 30, lz * 0.05, 2, T.seme + 9) - 0.5) * 2.5;
  }
  // oltre il cerchio percorribile il terreno sale: montagne o dune alte fanno da confine
  const fuori = d - (m.raggio - 8);
  if (fuori > 0) {
    const t = fuori / 30;
    h += t * t * T.bordo + fbmMappa(lx * 0.04, lz * 0.04, 3, T.seme + 5) * Math.min(1, t) * 14;
  }
  return Math.max(1.2, h);
}

// Altezza del terreno di una mappa nel punto del mondo (0 se non è in una mappa).
export function altezzaMappa(x, z) {
  const id = mappaAt(x, z);
  if (!id) return 0;
  const m = MAPPE[id];
  const lx = x - m.cx, lz = z - m.cz;
  let h = grezza(m, lx, lz);
  if (m.arrivo) {
    // spiazzo pianeggiante all'arrivo
    if (m._hArrivo === undefined) Object.defineProperty(m, '_hArrivo', { value: grezza(m, m.arrivo.x, m.arrivo.z), enumerable: false });
    const da = Math.hypot(lx - m.arrivo.x, lz - m.arrivo.z);
    if (da < 32) h = m._hArrivo + (h - m._hArrivo) * lisc(16, 32, da);
  }
  return h;
}

// Angoli (radianti, come in world.js: direzione (sin a, cos a)) delle porte dell'arena.
export function portaArena(i) {
  const m = MAPPE.arena;
  return Math.PI * 2 * i / m.porte;
}

// Il punto (locale) è dentro una nicchia o un corridoio d'ingresso dell'arena? Restituisce l'indice della porta o -1.
function portaDi(m, lx, lz) {
  for (let i = 0; i < m.porte; i++) {
    const a = portaArena(i), sx = Math.sin(a), sz = Math.cos(a);
    const lungo = lx * sx + lz * sz, lato = lx * sz - lz * sx;
    if (Math.hypot(lx - sx * m.distNicchia, lz - sz * m.distNicchia) <= m.nicchia) return i;
    if (lungo >= m.raggio - 3 && lungo <= m.distNicchia && Math.abs(lato) <= m.corridoio) return i;
  }
  return -1;
}

// Zona sicura in una mappa: lo spiazzo d'arrivo; nell'arena le porte e le nicchie (fuori dal pavimento).
export function zonaSicuraMappa(x, z) {
  const id = mappaAt(x, z);
  if (!id) return null;
  const m = MAPPE[id], lx = x - m.cx, lz = z - m.cz;
  if (m.tipo === 'arena') return Math.hypot(lx, lz) > m.raggio ? 'mappa' : null;
  return Math.hypot(lx - m.arrivo.x, lz - m.arrivo.z) < m.sicuro ? 'mappa' : null;
}

// Nome della zona (come zoneAt in world.js).
export function zonaMappa(x, z) {
  const id = mappaAt(x, z);
  if (!id) return { name: 'Terre Lontane' };
  const safe = zonaSicuraMappa(x, z);
  return safe ? { name: MAPPE[id].nome, mappa: id, safe: 'mappa' } : { name: MAPPE[id].nome, mappa: id };
}

// Riporta un punto dentro l'area percorribile della mappa.
export function limitaMappa(id, x, z) {
  const m = MAPPE[id];
  let lx = x - m.cx, lz = z - m.cz;
  const d = Math.hypot(lx, lz);
  if (m.tipo !== 'arena') {
    const R = m.raggio;
    if (d > R) { lx *= R / d; lz *= R / d; }
    return [m.cx + lx, m.cz + lz];
  }
  if (d <= m.raggio || portaDi(m, lx, lz) >= 0) return [x, z];
  // il punto percorribile più vicino fra pavimento, corridoi e nicchie
  let best = [lx * m.raggio / d, lz * m.raggio / d], bd = d - m.raggio;
  for (let i = 0; i < m.porte; i++) {
    const a = portaArena(i), sx = Math.sin(a), sz = Math.cos(a);
    const nx = sx * m.distNicchia, nz = sz * m.distNicchia, dn = Math.hypot(lx - nx, lz - nz);
    if (dn - m.nicchia < bd) { bd = dn - m.nicchia; best = [nx + (lx - nx) / dn * m.nicchia * 0.99, nz + (lz - nz) / dn * m.nicchia * 0.99]; }
    const lungo = Math.max(m.raggio - 3, Math.min(m.distNicchia, lx * sx + lz * sz));
    const lato = Math.max(-m.corridoio, Math.min(m.corridoio, lx * sz - lz * sx));
    const cx = sx * lungo + sz * lato, cz = sz * lungo - sx * lato, dc = Math.hypot(lx - cx, lz - cz);
    if (dc < bd) { bd = dc; best = [cx, cz]; }
  }
  return [m.cx + best[0], m.cz + best[1]];
}

// Punto d'arrivo nel mondo (con un po' di dispersione). Nell'arena: una nicchia a caso (o la `porta` data).
export function arrivoMappa(id, jitter = 3, porta = -1) {
  const m = MAPPE[id];
  const j = () => (Math.random() - 0.5) * jitter;
  if (m.tipo === 'arena') {
    const i = porta >= 0 ? porta : Math.floor(Math.random() * m.porte);
    const a = portaArena(i), r = m.distNicchia + 1.5;
    return { x: m.cx + Math.sin(a) * r + j(), z: m.cz + Math.cos(a) * r + j() };
  }
  return { x: m.cx + m.arrivo.x + j(), z: m.cz + m.arrivo.z + j() };
}
