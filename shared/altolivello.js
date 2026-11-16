// Contenuto per il livello alto (30-50): boss del mondo a tempo, seconda Prova del Sigillo (la Forgia del Drago
// Addormentato), stagioni dell'Arena con punti d'onore, imprese e titoli.
// Solo dati e regole pure: la logica è in server/altolivello.js (boss, arena, imprese) e in server/world.js (Prove).
// Questo file non importa nulla (lo importa data.js, che aggiunge MOBS_ALTO a MOBS e OGGETTI_ALTO a ITEMS).

// ------------------------------------------------------------------ meccaniche dei boss (campo `mecc` dei mostri)
// Le legge server/altolivello.js (bossMecc) per i boss del mondo e per il boss della Forgia.
//  fasi:   soglie di vita (frazione) in ordine decrescente; alla soglia: annuncio `nome`/`dice`, `rinforzi` [tipo, n],
//          `furia` { atk, aspd } (moltiplicatori), `zoneOgni` (le zone a terra arrivano più spesso).
//  lanci:  lanci INTERROMPIBILI a rotazione { name, ms, mult (× attacco), cd, raggio (ad area attorno al boss, sennò sul
//          bersaglio), post (frazione di Postura tolta a chi lo interrompe), pozze (lascia pozze ardenti attorno) }.
//  zone:   cerchi a terra sotto i giocatori { name, ogni, ms (preavviso), raggio, mult, pozza { s, mult al secondo } }.
//  anello: { name, ogni, ms, tipo 'lontano' (fa male VICINO al boss: allontanarsi) | 'vicino' (fa male LONTANO: avvicinarsi)
//          | 'alterna', raggio, mult }.
//  scudo:  { sotto, add, n, rid, name }: sotto la soglia il boss si chiude in una corazza (danni subiti −rid) finché i
//          suoi `n` servitori `add` non sono abbattuti; allora resta Squilibrato.
//  furiaS: secondi dall'ingaggio dopo i quali entra in FURIA definitiva (colpi a tutti entro 40 m ogni 2 s, cure
//          ricevute −75%): è il limite che rende il boss impossibile da soli e comodo in 2-3 del livello giusto.
export const FURIA = { ogniMs: 2000, raggio: 40, mult: 1.6, antiCura: 0.75, antiCuraS: 4, atk: 1.5, aspd: 0.6 };

// ------------------------------------------------------------------ boss del mondo a tempo
// luogo: 'mondo' (coordinate del mondo) o id di una mappa lontana (coordinate locali, relative al suo centro).
// ogniMin: intervallo fra una comparsa e la successiva (a caso fra i due valori); primaMin: dopo l'avvio del server;
// avvisi: minuti di preavviso annunciati a tutti; restaMin: se nessuno lo ingaggia, dopo questi minuti se ne va.
export const BOSS_MONDO = {
  colosso_ardente: {
    luogo: 'mondo', x: 0, z: 206, zona: 'Valle delle Braci (Terre di Confine, a nord)', liv: 32,
    ogniMin: [45, 60], primaMin: [6, 10], avvisi: [5, 1], restaMin: 20,
    trofeo: 'trofeo_colosso', pezzi: ['corazza_colosso', 'elmo_colosso', 'calzari_colosso'],
    desc: 'Un gigante di terracotta e bronzo con il cuore ancora acceso. Si sveglia quando la brace sotto la valle si scalda.',
  },
  madre_canne: {
    luogo: 'selva', x: 0, z: 30, zona: 'Radura delle Canne Cantanti (Selva dei Mille Steli)', liv: 40,
    ogniMin: [50, 70], primaMin: [8, 12], avvisi: [5, 1], restaMin: 20,
    trofeo: 'trofeo_canne', pezzi: ['veste_canne', 'corona_canne', 'passi_canne'],
    desc: 'La tigre più antica della Selva: il vento che passa fra le sue strisce suona come mille flauti.',
  },
  re_miraggio: {
    luogo: 'distesa', x: 6, z: 40, zona: 'Trono di Sabbia (Distesa dei Venti Rossi)', liv: 50,
    ogniMin: [55, 75], primaMin: [10, 14], avvisi: [5, 1], restaMin: 20,
    trofeo: 'trofeo_miraggio', pezzi: ['manto_miraggio', 'maschera_miraggio', 'sandali_miraggio'],
    desc: 'Un sovrano dimenticato che il deserto non ha voluto seppellire. Quando il vento rosso si alza, il suo trono riappare.',
  },
};
export const BOSS_IDS = Object.keys(BOSS_MONDO);

// Premi per chi ha partecipato (presenza in combattimento vicino al boss o danni): personali, nell'inventario.
export const PREMI_BOSS = {
  presenzaS: 20,        // secondi di presenza in combattimento entro `raggio` metri dal boss
  quotaDanni: 0.03,     // oppure almeno il 3% dei danni
  raggio: 45,
  pezzi: 2,             // pezzi della classe (rarità almeno Rara)
  unicoPct: 0.25,       // probabilità di un pezzo unico del boss; garantito alla 4ª uccisione senza (`pietaUnico`)
  pietaUnico: 4,
  espPct: 0.06,         // esperienza in frazione del livello (oltre a quella del mostro)
  essenze: [1, 3],
};

// ------------------------------------------------------------------ mostri nuovi (aggiunti a MOBS in data.js)
const nessuno = [];
export const MOBS_ALTO = {
  // --- boss del mondo
  colosso_ardente: {
    name: 'Colosso Ardente', lvl: 32, hp: 300000, atk: 560, def: 52, exp: 30000, speed: 4, aggro: 16, range: 3.8, aspd: 2100,
    model: 'terracotta', color: 0xb04a20, scale: 2.8, respawn: 0, boss: true, mondo: true, tael: [4000, 7000], drops: nessuno,
    mecc: {
      fasi: [
        { sotto: 1, nome: 'Il Colosso si risveglia' },
        { sotto: 0.7, nome: 'Giunture di brace', dice: 'Dalle crepe del Colosso escono i Soldati di Brace!', rinforzi: ['soldato_brace', 3] },
        { sotto: 0.4, nome: 'Cuore scoperto', dice: 'Il cuore del Colosso arde scoperto: la pioggia di lapilli si infittisce!', rinforzi: ['soldato_brace', 3], zoneOgni: 9000 },
        { sotto: 0.15, nome: 'Ultimo fuoco', dice: 'Il Colosso brucia le ultime forze: colpisce più forte e più in fretta!', furia: { atk: 1.25, aspd: 0.75 } },
      ],
      lanci: [{ name: 'Pugno del Vulcano', ms: 3000, mult: 4.0, cd: 22000, raggio: 12, post: 0.35, pozze: true }],
      zone: { name: 'Pioggia di Lapilli', ogni: 13000, ms: 2600, raggio: 3.5, mult: 3.0, pozza: { s: 8, mult: 0.35 } },
      anello: { name: 'Eruzione', ogni: 30000, ms: 3200, tipo: 'lontano', raggio: 9, mult: 4.5 },
      furiaS: 300,
    } },
  soldato_brace: { name: 'Soldato di Brace', lvl: 30, hp: 2400, atk: 150, def: 30, exp: 300, speed: 4.6, aggro: 14, range: 2.6, aspd: 1700, model: 'terracotta', color: 0xd06a30, scale: 1.0, respawn: 0, bott: 0.3, tael: [40, 80], drops: nessuno },
  madre_canne: {
    name: 'Madre delle Canne Cantanti', lvl: 40, hp: 400000, atk: 680, def: 58, exp: 52000, speed: 6.2, aggro: 15, range: 3.4, aspd: 1800,
    model: 'tiger', color: 0x2a8a5a, scale: 2.6, respawn: 0, boss: true, mondo: true, tael: [7000, 11000], drops: nessuno,
    mecc: {
      fasi: [
        { sotto: 1, nome: 'La Madre si desta' },
        { sotto: 0.65, nome: 'Richiamo del branco', dice: 'La Madre ruggisce: i Lupi delle Canne accorrono!', rinforzi: ['lupo_canne', 4] },
        { sotto: 0.35, nome: 'Canne che piangono', dice: 'Gli Spiriti della Canna Cava escono dal bambù!', rinforzi: ['spirito_canna', 3], zoneOgni: 8000 },
        { sotto: 0.12, nome: 'Ultimo canto', dice: 'La Madre canta il suo ultimo canto: colpisce senza tregua!', furia: { atk: 1.25, aspd: 0.7 } },
      ],
      lanci: [{ name: 'Canto delle Mille Canne', ms: 3400, mult: 3.4, cd: 20000, raggio: 14, post: 0.35 }],
      zone: { name: 'Canne Affilate', ogni: 11000, ms: 2400, raggio: 3.2, mult: 2.4, pozza: { s: 7, mult: 0.3 } },
      anello: { name: 'Abbraccio del Vento', ogni: 28000, ms: 3500, tipo: 'vicino', raggio: 6, mult: 3.2 },
      furiaS: 360,
    } },
  re_miraggio: {
    name: 'Re del Miraggio Rosso', lvl: 50, hp: 480000, atk: 780, def: 64, exp: 90000, speed: 4.6, aggro: 16, range: 3.8, aspd: 2000,
    model: 'general', color: 0xc0602a, scale: 2.5, respawn: 0, boss: true, mondo: true, tael: [11000, 16000], drops: nessuno,
    mecc: {
      fasi: [
        { sotto: 1, nome: 'Il Re reclama il trono' },
        { sotto: 0.7, nome: 'Corte di miraggi', dice: 'I miraggi del Re prendono corpo!', rinforzi: ['anima_miraggio', 4] },
        { sotto: 0.4, nome: 'Guardia di sabbia', dice: "I Guerrieri d'Arenaria si alzano dalle dune per il loro Re!", rinforzi: ['guerriero_arenaria', 3], zoneOgni: 8000 },
        { sotto: 0.15, nome: 'Tempesta rossa', dice: 'Il Re scatena la tempesta rossa!', furia: { atk: 1.3, aspd: 0.7 } },
      ],
      lanci: [
        { name: 'Sentenza del Simun', ms: 3200, mult: 3.6, cd: 18000, raggio: 14, post: 0.35, pozze: true },
        { name: 'Lama di Sabbia', ms: 2200, mult: 4.0, cd: 15000, post: 0.2 },
      ],
      zone: { name: 'Vortici di Sabbia', ogni: 10000, ms: 2300, raggio: 3.6, mult: 2.6, pozza: { s: 8, mult: 0.35 } },
      anello: { name: 'Respiro del Deserto', ogni: 26000, ms: 3300, tipo: 'alterna', raggio: 8, mult: 3.4 },
      furiaS: 360,
    } },

  // --- Forgia del Drago Addormentato (seconda Prova del Sigillo, livello 35+)
  fabbro_cenere: { name: 'Fabbro di Cenere', lvl: 36, hp: 3200, atk: 128, def: 48, exp: 560, speed: 4.2, aggro: 11, range: 2.8, aspd: 1900, model: 'terracotta', color: 0x4a4040, scale: 1.2, respawn: 0, dungeon: true, tael: [80, 160], drops: nessuno },
  cane_brace: { name: 'Cane di Brace', lvl: 36, hp: 1700, atk: 112, def: 28, exp: 380, speed: 7, aggro: 14, range: 2.2, aspd: 1300, model: 'wolf', color: 0xd0502a, scale: 1.15, respawn: 0, dungeon: true, tael: [60, 120], drops: nessuno },
  spirito_fornace: { name: 'Spirito della Fornace', cast: { name: 'Colata di Fuoco', ms: 2200, mult: 2.8, cd: 8000 }, lvl: 36, hp: 1700, atk: 132, def: 22, exp: 420, speed: 3.5, aggro: 13, range: 12, ranged: true, magic: true, aspd: 2100, model: 'lantern', color: 0xff6020, scale: 1.1, respawn: 0, dungeon: true, tael: [60, 120], drops: nessuno },
  martellatore_bronzo: { name: 'Martellatore di Bronzo', cast: { name: "Colpo d'Incudine", ms: 2600, mult: 2.4, cd: 12000, raggio: 7 }, lvl: 37, hp: 9000, atk: 160, def: 56, exp: 1500, speed: 3.8, aggro: 12, range: 3.0, aspd: 2200, model: 'terracotta', color: 0x8a5a2a, scale: 1.6, respawn: 0, dungeon: true, tael: [200, 400], drops: nessuno },
  mantice_forgia: { name: 'Mantice Ardente', lvl: 38, hp: 5200, atk: 0, def: 30, exp: 200, speed: 0, aggro: 0, range: 0.5, aspd: 99999, model: 'obelisk', color: 0xff7030, scale: 0.5, respawn: 0, dungeon: true, drops: nessuno },
  yan_fornace: {
    name: 'Yan, il Cuore della Fornace', lvl: 38, hp: 180000, atk: 380, def: 60, exp: 22000, speed: 4.2, aggro: 18, range: 3.6, aspd: 2100,
    model: 'general', color: 0x6a1a10, scale: 2.2, respawn: 0, dungeon: true, boss: true, dungeonBoss: true, tael: [4000, 6500], drops: nessuno,
    mecc: {
      fasi: [
        { sotto: 1, nome: 'La fornace si accende' },
        { sotto: 0.75, nome: 'Cani della forgia', dice: 'Yan fischia: i Cani di Brace escono dalle bocche della fornace!', rinforzi: ['cane_brace', 3] },
        { sotto: 0.5, nome: 'Corazza di Brace', dice: 'Yan si chiude nella Corazza di Brace: spegnete i Mantici Ardenti!' },
        { sotto: 0.2, nome: 'Il drago si sveglia', dice: 'Il drago sotto la forgia apre un occhio: Yan è in furia!', furia: { atk: 1.25, aspd: 0.7 }, zoneOgni: 8000 },
      ],
      lanci: [{ name: 'Colata Ardente', ms: 3200, mult: 3.0, cd: 20000, raggio: 12, post: 0.35, pozze: true }],
      zone: { name: 'Martello del Drago', ogni: 11000, ms: 2400, raggio: 3.5, mult: 2.4, pozza: { s: 6, mult: 0.3 } },
      scudo: { sotto: 0.5, add: 'mantice_forgia', n: 3, rid: 0.85, name: 'Corazza di Brace', distanza: 13 },
      furiaS: 420,
    } },
};

// ------------------------------------------------------------------ oggetti nuovi (aggiunti a ITEMS in data.js)
// Pezzi unici dei boss: nome proprio, valori un po' sopra il gradino del loro livello e due bonus fissi (`fissi`,
// righe che si aggiungono a quelle casuali). `boss`: chi li lascia (per il tooltip). `aspetto`: modello dell'elmo/calzari.
export const OGGETTI_ALTO = {
  corazza_colosso: { name: 'Corazza del Colosso Ardente', type: 'body', lvl: 32, def: 58, price: 60000, tier: 4, glyph: '鎧', boss: 'colosso_ardente', fissi: [['hp', 260], ['dmgRed', 4]], desc: 'Piastre di bronzo ancora tiepide, strappate al Colosso Ardente.' },
  elmo_colosso: { name: 'Elmo di Brace del Colosso', type: 'head', lvl: 32, def: 21, price: 42000, tier: 4, glyph: '兜', aspetto: 'elmo_drago', boss: 'colosso_ardente', fissi: [['atkPct', 4], ['matkPct', 4]], desc: 'Nelle fessure della visiera brilla ancora un filo di brace.' },
  calzari_colosso: { name: 'Calzari di Lava Spenta', type: 'feet', lvl: 32, def: 9, speed: 15, price: 40000, tier: 4, glyph: '靴', aspetto: 'stivali_nube', boss: 'colosso_ardente', fissi: [['hp', 160], ['moveSpd', 4]], desc: 'Suole di roccia vulcanica: non temono né fuoco né sassi.' },
  veste_canne: { name: 'Veste della Madre delle Canne', type: 'body', lvl: 40, def: 66, price: 90000, tier: 4, glyph: '鎧', boss: 'madre_canne', fissi: [['hp', 380], ['resRegen', 10]], desc: 'Intrecciata con le canne che cantavano attorno alla Madre.' },
  corona_canne: { name: 'Corona di Canne Cave', type: 'head', lvl: 40, def: 25, price: 64000, tier: 4, glyph: '兜', aspetto: 'elmo_drago', boss: 'madre_canne', fissi: [['crit', 3], ['haste', 3]], desc: 'Quando corri, la corona fischia come il vento fra il bambù.' },
  passi_canne: { name: 'Passi del Vento fra le Canne', type: 'feet', lvl: 40, def: 11, speed: 17, price: 60000, tier: 4, glyph: '靴', aspetto: 'stivali_nube', boss: 'madre_canne', fissi: [['evade', 3], ['moveSpd', 6]], desc: 'Leggeri come una foglia di bambù.' },
  manto_miraggio: { name: 'Manto del Re del Miraggio', type: 'body', lvl: 46, def: 76, price: 130000, tier: 4, glyph: '鎧', boss: 're_miraggio', fissi: [['hp', 480], ['critDmg', 12]], desc: 'Il tessuto cambia colore come la sabbia al tramonto.' },
  maschera_miraggio: { name: 'Maschera del Miraggio', type: 'head', lvl: 46, def: 29, price: 92000, tier: 4, glyph: '兜', aspetto: 'elmo_drago', boss: 're_miraggio', fissi: [['atkPct', 6], ['matkPct', 6]], desc: 'Chi la indossa vede il nemico un istante prima che si muova.' },
  sandali_miraggio: { name: 'Sandali delle Sabbie Erranti', type: 'feet', lvl: 46, def: 13, speed: 19, price: 88000, tier: 4, glyph: '靴', aspetto: 'stivali_nube', boss: 're_miraggio', fissi: [['dropPct', 8], ['moveSpd', 6]], desc: 'Non lasciano impronte: il vento le cancella subito.' },
  // trofei: si vendono bene, e contano per le imprese
  trofeo_colosso: { name: 'Cuore di Brace del Colosso', type: 'material', price: 9000, stack: true, glyph: '心', color: '#d0502a', desc: 'Il cuore ancora caldo del Colosso Ardente. Un trofeo che i mercanti pagano bene.' },
  trofeo_canne: { name: 'Canna Cantante della Madre', type: 'material', price: 15000, stack: true, glyph: '笛', color: '#3aa06a', desc: 'Una canna della Madre delle Canne: se ci soffi dentro, canta da sola.' },
  trofeo_miraggio: { name: 'Specchio del Miraggio Rosso', type: 'material', price: 24000, stack: true, glyph: '鏡', color: '#e08a40', desc: 'Lo specchio in cui il Re del Miraggio guardava il suo regno perduto.' },
};

// ------------------------------------------------------------------ Forgia del Drago Addormentato
// Coordinate locali rispetto all'origine dell'istanza (come DUNGEON). Le stanze si toccano con almeno 1 m di sovrapposizione;
// i muri si ricavano dai bordi delle stanze togliendo i tratti che stanno dentro un'altra stanza (murIDaStanze).
const STANZE_FORGIA = [
  [-8, -8, 8, 8],          // ingresso
  [-3, 7, 3, 24],          // discesa
  [-18, 23, 18, 47],       // Sala delle Incudini
  [-16, 46, -10, 64],      // corridoio ovest
  [-30, 63, 0, 89],        // Fonderia
  [-1, 72, 22, 78],        // passaggio dei canali
  [21, 60, 45, 92],        // Galleria dei Mantici
  [29, 91, 37, 106],       // scala del drago
  [12, 105, 54, 141],      // Cuore della Forgia (boss)
];

export function muriDaStanze(stanze) {
  const muri = [];
  const togli = (a, b, buchi) => {
    let pezzi = [[a, b]];
    for (const [h1, h2] of buchi) {
      const nuovi = [];
      for (const [p1, p2] of pezzi) {
        if (h2 <= p1 || h1 >= p2) { nuovi.push([p1, p2]); continue; }
        if (h1 > p1) nuovi.push([p1, h1]);
        if (h2 < p2) nuovi.push([h2, p2]);
      }
      pezzi = nuovi;
    }
    return pezzi.filter(([p1, p2]) => p2 - p1 > 0.2);
  };
  stanze.forEach((r, i) => {
    const [x1, z1, x2, z2] = r;
    const altre = stanze.filter((_, j) => j !== i);
    for (const z of [z1, z2]) {   // bordi orizzontali
      const buchi = altre.filter(o => o[1] < z && z < o[3]).map(o => [o[0], o[2]]);
      for (const [a, b] of togli(x1, x2, buchi)) muri.push([a, z, b, z]);
    }
    for (const x of [x1, x2]) {   // bordi verticali
      const buchi = altre.filter(o => o[0] < x && x < o[2]).map(o => [o[1], o[3]]);
      for (const [a, b] of togli(z1, z2, buchi)) muri.push([x, a, x, b]);
    }
  });
  return muri;
}

export const FORGIA = {
  id: 'forgia', name: 'Forgia del Drago Addormentato', trial: 'Prova della Forgia',
  desc: 'Sotto le montagne i fabbri di cenere battono ancora il metallo per un drago che dorme. Yan, il Cuore della Fornace, non permette a nessuno di svegliarlo.',
  minLevel: 35, startKey: 2, timeLimit: 1080, deathPenalty: 5, forcesNeeded: 100, maxKey: 30,
  originX: 1200, slotSpacing: 400, boundsMin: [-31, -9], boundsMax: [55, 142],
  spawn: [0, -4],
  rooms: STANZE_FORGIA,
  walls: muriDaStanze(STANZE_FORGIA),
  packs: [
    { x: -9, z: 31, mobs: ['fabbro_cenere', 'fabbro_cenere', 'cane_brace'] },
    { x: 9, z: 40, mobs: ['cane_brace', 'cane_brace', 'cane_brace', 'spirito_fornace'] },
    { x: -20, z: 70, mobs: ['fabbro_cenere', 'fabbro_cenere', 'spirito_fornace', 'spirito_fornace'] },
    { x: -9, z: 83, mobs: ['cane_brace', 'cane_brace', 'cane_brace', 'cane_brace'] },
    { x: 33, z: 68, mobs: ['martellatore_bronzo', 'cane_brace', 'cane_brace'] },
    { x: 33, z: 85, mobs: ['fabbro_cenere', 'fabbro_cenere', 'spirito_fornace', 'spirito_fornace'] },
    { x: 33, z: 100, mobs: ['martellatore_bronzo'] },
  ],
  boss: { type: 'yan_fornace', x: 33, z: 128 },
  forces: { fabbro_cenere: 5, cane_brace: 3, spirito_fornace: 5, martellatore_bronzo: 10, eco_spirito: 1 },
  // premi: pezzi di livello più alto della Cripta (dal 40), essenze e un pezzo unico della Forgia dal sigillo +6
  livPremi: 40,
  tema: { muro: '#5a4038', lume: '#ff7a30', lumeBoss: '#ff3a10', lava: '#ff5a10', nebbia: '#1a0a06', pavimento: '#7a6a62' },
};

// ------------------------------------------------------------------ Arena: stagioni settimanali e onore
// Punti stagionali (classifica della settimana, salvata nel database) e onore (moneta da spendere dall'Araldo).
export const ARENA = {
  uccisione: 10,          // punti per un avversario abbattuto
  perSerie: 2,            // +2 per ogni uccisione della propria serie (fino a +10)
  serieMax: 10,
  spezza: 5,              // +5 se si spezza una serie di 3 o più
  morte: 2,               // −2 punti a ogni caduta (mai sotto zero); l'onore non si perde
  dislivello: 10,         // contro chi ha 10 livelli in meno: solo 2 punti
  stessoBersaglioMin: 10, // la 3ª uccisione dello stesso avversario entro 10 minuti non vale nulla (niente accordi)
  premiSettimana: [       // alla fine della settimana: primi tre della classifica
    { onore: 600, tael: 150000, titolo: 'campione_loto' },
    { onore: 400, tael: 90000 },
    { onore: 250, tael: 50000 },
  ],
  righe: 10,
};
// Negozio dell'Araldo (costi in onore).
export const NEGOZIO_ONORE = [
  { id: 'titolo_sfidante', titolo: 'sfidante', costo: 300 },
  { id: 'titolo_lama_cremisi', titolo: 'lama_cremisi', costo: 1500 },
  { id: 'essenza_celeste', n: 1, costo: 120 },
  { id: 'gemma_rubino_2', n: 1, costo: 450 },
  { id: 'gemma_zaffiro_2', n: 1, costo: 450 },
  { id: 'sigillo_ascensione', n: 1, costo: 700 },
  { id: 'tael', tael: 25000, costo: 100 },
];

// ------------------------------------------------------------------ titoli e imprese
// Un titolo compare sopra il nome; si sceglie dalla finestra delle Imprese (tasto J). `colore` del titolo.
export const TITOLI = {
  spezzacolossi: { nome: 'Spezzacolossi', colore: '#ff9a50' },
  flagello_selva: { nome: 'Flagello della Selva', colore: '#6ad08a' },
  oltre_miraggio: { nome: 'Oltre il Miraggio', colore: '#f0c060' },
  cacciatore_leggende: { nome: 'Cacciatore di Leggende', colore: '#ffd040' },
  custode_sigillo: { nome: 'Custode del Sigillo', colore: '#90b0ff' },
  signore_prove: { nome: 'Signore delle Prove', colore: '#c08aff' },
  cuore_brace: { nome: 'Cuore di Brace', colore: '#ff7040' },
  lama_arena: { nome: "Lama dell'Arena", colore: '#ff6a6a' },
  loto_cremisi: { nome: 'Loto Cremisi', colore: '#ff4a6a' },
  sfidante: { nome: 'Sfidante del Loto', colore: '#e0a0a0' },
  lama_cremisi: { nome: 'Lama Cremisi', colore: '#ff3040' },
  campione_loto: { nome: 'Campione della Settimana', colore: '#ffe070', settimana: true },
};
// Imprese: contatore `c` in ch.imp (uccisioni dei boss, migliore sigillo superato in tempo, abbattuti nell'arena...)
// che deve arrivare a `n`; il premio è un titolo. `tutti`: ogni contatore dell'elenco deve arrivare a `n`.
export const IMPRESE = [
  { id: 'spezzacolossi', nome: 'Spezzacolossi', desc: 'Abbatti il Colosso Ardente.', c: 'colosso_ardente', n: 1, titolo: 'spezzacolossi' },
  { id: 'flagello_selva', nome: 'Il silenzio delle canne', desc: 'Abbatti la Madre delle Canne Cantanti.', c: 'madre_canne', n: 1, titolo: 'flagello_selva' },
  { id: 'oltre_miraggio', nome: 'Oltre il miraggio', desc: 'Abbatti il Re del Miraggio Rosso.', c: 're_miraggio', n: 1, titolo: 'oltre_miraggio' },
  { id: 'cacciatore_leggende', nome: 'Cacciatore di leggende', desc: 'Abbatti tre volte ciascuno dei tre boss del mondo.', tutti: ['colosso_ardente', 'madre_canne', 're_miraggio'], n: 3, titolo: 'cacciatore_leggende' },
  { id: 'forgia_spenta', nome: 'La fornace spenta', desc: 'Completa la Prova della Forgia.', c: 'fatte_forgia', n: 1, titolo: 'cuore_brace' },
  { id: 'sigillo_8', nome: "Sigillo d'argento", desc: 'Completa in tempo una Prova del Sigillo +8 o più.', c: 'sigillo', n: 8, titolo: 'custode_sigillo' },
  { id: 'sigillo_15', nome: "Sigillo d'oro", desc: 'Completa in tempo una Prova del Sigillo +15 o più.', c: 'sigillo', n: 15, titolo: 'signore_prove' },
  { id: 'arena_25', nome: 'Venticinque duelli', desc: "Abbatti 25 avversari nell'Arena del Loto Cremisi.", c: 'arena_u', n: 25, titolo: 'lama_arena' },
  { id: 'arena_100', nome: 'Cento duelli', desc: "Abbatti 100 avversari nell'Arena del Loto Cremisi.", c: 'arena_u', n: 100, titolo: 'loto_cremisi' },
];

// Numero della settimana (da lunedì 1 gennaio 2024, come weeklyAffixes in data.js).
export function settimana(now = Date.now()) {
  return Math.floor((now - Date.UTC(2024, 0, 1)) / (7 * 86400000));
}
export function fineSettimana(n) { return Date.UTC(2024, 0, 1) + (n + 1) * 7 * 86400000; }
