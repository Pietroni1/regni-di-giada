// Dati di gioco condivisi tra server e client.
// Modifica questo file per bilanciare classi, abilità, oggetti e mostri.
import { MOBS_MAPPE, NPC_MAPPE } from './mappe.js';
import { NPC_MISSIONI } from './missioni.js';
import { MOBS_ALTO, OGGETTI_ALTO, FORGIA } from './altolivello.js';
export { BOSS_MONDO, BOSS_IDS, PREMI_BOSS, FURIA, ARENA, NEGOZIO_ONORE, TITOLI, IMPRESE, FORGIA } from './altolivello.js';
export { CATENA, INCARICHI, MISSIONI, PNG_INCARICHI, ZONE_MISSIONI, SBLOCCHI } from './missioni.js';

export const MAX_LEVEL = 99;
export const INV_SIZE = 45;
export const QB_SIZE = 10;
export const STACK_MAX = 200;
export const STAT_MAX = 90;
export const PTS_MAX = 5;
// Slancio: ogni colpo a segno entro la finestra aggiunge una tacca; le tacche aumentano la risorsa generata,
// la rapidità e la rigenerazione. Se smetti di colpire calano una alla volta.
export const SLANCIO = { max: 5, windowMs: 3200, decayMs: 900, genPct: 10, hastePct: 3, regenPct: 8 };
// Risorsa extra per come giochi (Ira/Energia/Chi in punti; per il Mana vale un quarto, in % del massimo).
// multi: per ogni bersaglio oltre il primo colpito da una tecnica, fino a multiMax.
export const BONUS_RISORSA = { multi: 0.75, multiMax: 3, crit: 3, kill: 10 };
// Serie di uccisioni (il «flow» del farming): ogni mostro ucciso entro `finestraMs` dal precedente allunga la serie.
// Finché la serie è viva: Slancio e Ira non calano, si corre più veloci (+velPct% a uccisione, fino a velMax%),
// ogni uccisione accorcia di scattoS secondi la ricarica degli scatti (`scatto: true`) e di potS quella del
// potenziamento di classe (`potenziamento: true`); ogni `occasioneOgni` uccisioni si ottiene un'Occasione.
export const SERIE = { finestraMs: 7000, velPct: 4, velMax: 24, scattoS: 2, potS: 1, occasioneOgni: 5 };
// Tecnica Suprema: una barra che si riempie spendendo risorsa (perRes per punto di Ira/Energia/Chi, perManaPct per ogni
// 1% di Mana, perPt per ogni punto combo/sfera/carica consumato). Piena, sblocca la tecnica `sup` della classe.
// Taratura (tools/sim/simula.mjs): con i kit "2 accumuli + 4 scarichi" si spendono circa 20-25 punti di risorsa al secondo
// (Mana: ~3% al secondo), quindi la barra si riempie in 50-58 secondi contro un bersaglio e in 45-55 contro un gruppo.
export const SUPREMA = { max: 100, perRes: 0.082, perManaPct: 0.58, perPt: 0.2, lvl: 15 };
export const GCD_MS = 1000;       // tempo globale fra due tecniche (provato a 500: l'autore l'ha trovato troppo frenetico)
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
// Da aumentare quando cambiano gli id delle abilità: il server azzera punti abilità e barra rapida dei vecchi salvataggi.
export const DATA_VERSION = 5;

// Curva dei livelli: la forma di prima (80·l^1,85 + 40·l) per un fattore che cresce con il livello. Stima da
// `npm run farming` (giocatore vero = 45% del bot, missioni della catena comprese; vedi CLAUDE.md, «Crescita: missioni e
// bottino»): con la forma sola si arrivava al 10 in ~25 minuti e al 40 in ~2 ore e mezza; ora il 10 in ~45 minuti,
// il 20 in ~2 ore, il 30 in ~5, il 40 in ~10.
export const CURVA_LIVELLI = [[1, 3.0], [10, 3.2], [15, 3.9], [20, 4.6], [30, 6.2], [40, 8.5], [50, 9.5]];
function fattoreCurva(l) {
  const C = CURVA_LIVELLI;
  if (l <= C[0][0]) return C[0][1];
  for (let i = 1; i < C.length; i++) {
    if (l <= C[i][0]) { const [a, fa] = C[i - 1], [b, fb] = C[i]; return fa + (fb - fa) * (l - a) / (b - a); }
  }
  return C[C.length - 1][1];
}
export function expToNext(l) { return Math.floor((80 * Math.pow(l, 1.85) + 40 * l) * fattoreCurva(l)); }
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
// Energia / Chi: si rigenerano piano da sole (di più con lo Slancio); gli accumuli non costano nulla, ne rendono un po' e danno punti.
// Mana: grande riserva che cala lentamente.
export const RESOURCES = {
  ira: { name: 'Ira', color: '#c8402a', fixedMax: 100, start: 0, decay: 3 },
  energia: { name: 'Energia', color: '#d8b830', fixedMax: 100, start: 100, regen: 5.5 },
  chi: { name: 'Chi', color: '#3fae8a', fixedMax: 100, start: 100, regen: 7 },
  mana: { name: 'Mana', color: '#3a6ad0', start: 1, regenPct: 1.0, regenPctOoc: 4 },
};

// ------------------------------------------------------------------ classi
// hp/mp: [base, per livello, per punto di vitalità/intelletto]. mp vale solo per le classi a mana.
export const CLASSES = {
  lama: {
    name: 'Lama', title: 'Spadaccino errante', glyph: '剣',
    desc: "Combattente con la spada, la classe più diretta. Squarcio e Fendente accumulano Ira e Impeto, il colpo finale li scarica; la Carica ti porta addosso al nemico e lo interrompe.",
    start: { vit: 5, str: 6, dex: 3, int: 2 }, hp: [130, 26, 22], mp: [0, 0, 0],
    primary: 'str', autoMagic: false, weapons: ['sword'], res: 'ira', autoRes: 7,
    vie: ['fulmine', 'montagna'], pts: { name: 'Impeto', glyph: '▲' }, baseSkills: ['squarcio', 'fendente', 'affondo_ira', 'carica', 'grido_guerra'], startWeapon: 'spada_ferro', extraItems: [],
    look: { robe: 0x5b3a2c, trim: 0xb8a070, pants: 0x2e2620, armor: 0x8a8f96, hair: 0x1a1210, hairStyle: 'topknot' },
  },
  ombra: {
    name: 'Ombra', title: 'Lama dei vicoli', glyph: '影',
    desc: 'Agile e letale, con pugnali o arco. Colpo Rapido e Ventaglio accumulano Energia e Punti combo, il colpo finale li scarica; ha un colpo che interrompe e una mossa di Via.',
    start: { vit: 3, str: 4, dex: 7, int: 2 }, hp: [105, 21, 18], mp: [0, 0, 0],
    primary: 'dex', autoMagic: false, weapons: ['daggers', 'bow'], res: 'energia', pts: { name: 'Punti combo', glyph: '◆' },
    vie: ['pugnali', 'arco'], baseSkills: ['colpo_rapido', 'ventaglio', 'taglio_netto', 'colpo_gola', 'velo_ombra'], startWeapon: 'pugnali_osso', extraItems: ['arco_bambu'],
    look: { robe: 0x26293a, trim: 0x7a1e22, pants: 0x1c1e28, hair: 0x0e0e10, hairStyle: 'hood' },
  },
  monaco: {
    name: 'Monaco', title: 'Pugno del monastero', glyph: '拳',
    desc: 'Combatte a mani nude ed è la classe più tecnica: la sua Maestria premia chi alterna i colpi. Pugno e Calcio accumulano Chi e Sfere, il colpo finale li scarica; il Calcio Volante lo porta sul nemico.',
    start: { vit: 4, str: 5, dex: 4, int: 3 }, hp: [115, 24, 20], mp: [0, 0, 0],
    primary: 'str', autoMagic: false, weapons: ['fists'], res: 'chi', pts: { name: 'Sfere', glyph: '●' },
    vie: ['ferro', 'loto'], baseSkills: ['pugno_ferro', 'calcio_gru', 'onda_chi', 'palmo_chi', 'calcio_volante', 'respiro_drago'], startWeapon: 'bende_seta', extraItems: [],
    look: { robe: 0xc8681c, trim: 0x7a3b10, pants: 0x6a3a14, hair: null, hairStyle: 'bald' },
  },
  mistico: {
    name: 'Mistico', title: 'Veggente dei venti', glyph: '仙',
    desc: 'Incantatore con il bastone. Dardo e Sfera (brevi lanci, anche camminando) accumulano Cariche celesti, il colpo finale è istantaneo; il Passo di Luce lo sposta in un lampo. Può diventare guaritore.',
    start: { vit: 3, str: 2, dex: 3, int: 8 }, hp: [95, 19, 17], mp: [120, 14, 26],
    primary: 'int', autoMagic: true, weapons: ['staff'], res: 'mana', pts: { name: 'Cariche celesti', glyph: '✦' },
    vie: ['tempesta', 'benedizione'], baseSkills: ['dardo_luce', 'sfera_celeste', 'lancia_luce', 'sigillo_silenzio', 'passo_luce', 'benedizione_astri'], startWeapon: 'bastone_salice', extraItems: [],
    look: { robe: 0xdcd6c4, trim: 0x2f6a8a, pants: 0xbab4a0, hair: 0x22201e, hairStyle: 'long' },
  },
};

// maestria: la passiva della Via (applicata in server/world.js). passive: bonus fissi.
//   slancio: +% ai danni del finale per tacca di Slancio · baluardo: il finale dà l'effetto Baluardo (campo `buff` della tecnica)
//   veleno: i colpi base avvelenano { mult, dur, every } e il finale fa +bonus% sui bersagli avvelenati
//   distanza: +pct% ai danni sui bersagli più lontani di m metri · ritmo: +% ai danni di un colpo base diverso dal precedente
//   cura: il finale ti cura di questa % della vita massima · critPts: un colpo base critico dà punti in più
//   grazia: i danni dei colpi base curano di questa % l'alleato più ferito entro 25 m
export const VIE = {
  fulmine: { cls: 'lama', name: 'Via del Fulmine', role: 'Danni', desc: 'Danni devastanti. Maestria — Tempesta Crescente: il colpo finale infligge il 6% in più per ogni tacca di Slancio.', passive: {}, maestria: { slancio: 6 } },
  montagna: { cls: 'lama', name: 'Via della Montagna', role: 'Difensore', desc: 'Regge i colpi e tiene su di sé i nemici. Vita +15%, minaccia ×4. Maestria — Baluardo: dopo il colpo finale subisci il 25% di danni in meno per 6 secondi.', passive: { hpPct: 15, threat: 4 }, maestria: { baluardo: true } },
  pugnali: { cls: 'ombra', name: 'Via dei Pugnali', role: 'Danni', desc: 'Veleni e colpi alle spalle. Maestria — Lame Avvelenate: i colpi base avvelenano e il colpo finale fa il 20% in più sui bersagli avvelenati. Richiede pugnali.', passive: {}, maestria: { veleno: { mult: [0.12, 0.006], dur: 8, every: 2, bonus: 20 } } },
  arco: { cls: 'ombra', name: "Via dell'Arco", role: 'Danni a distanza', desc: 'Combatte dalla distanza. Maestria — Occhio Lungo: +12% ai danni sui bersagli a più di 8 metri. Richiede un arco.', passive: {}, maestria: { distanza: { m: 8, pct: 12 } } },
  ferro: { cls: 'monaco', name: 'Via del Pugno di Ferro', role: 'Danni', desc: 'Raffiche ravvicinate. Maestria — Ritmo: un colpo base diverso dal precedente infligge il 15% in più.', passive: {}, maestria: { ritmo: 15 } },
  loto: { cls: 'monaco', name: 'Via del Loto Interiore', role: 'Danni magici', desc: "Chi che colpisce a media distanza e sostiene. Maestria — Fiore di Loto: il colpo finale ti cura del 6% della vita massima.", passive: {}, maestria: { cura: 6 } },
  tempesta: { cls: 'mistico', name: 'Via della Tempesta', role: 'Danni a distanza', desc: 'Fulmini e saette. Maestria — Sovraccarico: un colpo base critico dà una Carica celeste in più.', passive: {}, maestria: { critPts: 1 } },
  benedizione: { cls: 'mistico', name: 'Via della Benedizione', role: 'Guaritore', desc: "Guaritore con gli stessi tasti degli altri. Cure +15%. Maestria — Grazia: i danni dei tuoi colpi base curano del 40% l'alleato più ferito entro 25 metri (te compreso).", passive: { healPct: 15 }, maestria: { grazia: 40 } },
};

// ------------------------------------------------------------------ effetti temporanei
// stats: [valore, incremento per livello dell'abilità che lo applica]
// free/instant/consume: liste di abilità; skillDmg: bonus % a singole abilità; spenderDmg: bonus % alle tecniche che consumano punti.
export const BUFFS = {
  scintilla: { name: 'Scintilla', glyph: '閃', dur: 10, proc: true, costMod: { lama_tuono: -28 }, skillDmg: { lama_tuono: 30 }, consume: ['lama_tuono'], desc: 'La prossima Lama del Tuono costa metà Ira e infligge il 30% di danni in più.' },
  furia_tempesta: { name: 'Furia della Tempesta', glyph: '嵐', dur: 15, stats: { dmgPct: [20, 1] }, costMod: { lama_tuono: -15 }, desc: 'Danni aumentati e Lama del Tuono costa 15 Ira in meno.' },
  pelle_pietra: { name: 'Pelle di Pietra', glyph: '岩', dur: 10, stats: { dmgTaken: [-25, -1], hpRegen: [2, 0.1] }, desc: 'Danni subiti ridotti e rigenerazione della vita.' },
  nell_ombra: { name: "Nell'Ombra", glyph: '隠', dur: 8, proc: true, skillDmg: { taglio_finale: 30 }, consume: ['taglio_finale'], desc: 'Il prossimo Taglio Finale infligge il 30% di danni in più.' },
  fuoco_rapido: { name: 'Fuoco Rapido', glyph: '速', dur: 10, proc: true, free: ['pioggia_frecce'], consume: ['pioggia_frecce'], desc: 'La prossima Pioggia di Frecce non costa Energia.' },
  occhio_falco: { name: 'Occhio del Falco', glyph: '鷹', dur: 6, stats: { hastePct: [15, 0.75], resRegenPct: [50, 2] }, desc: 'Rapidità e rigenerazione dell\'Energia aumentate.' },
  forma_perfetta: { name: 'Forma Perfetta', glyph: '極', dur: 10, proc: true, spenderDmg: 40, consumeSpender: true, desc: 'Il prossimo scarico potente (che consuma le Sfere) infligge il 40% di danni in più.' },
  pelle_bronzo: { name: 'Pelle di Bronzo', glyph: '銅', dur: 10, stats: { dmgTaken: [-20, -1], hpRegen: [2, 0.1] }, desc: 'Danni subiti ridotti e rigenerazione della vita.' },
  spirito_tigre: { name: 'Spirito della Tigre', glyph: '虎', dur: 15, stats: { dmgPct: [20, 1], resRegenPct: [50, 2] }, desc: 'Danni e rigenerazione del Chi aumentati.' },
  sigillo_interiore: { name: 'Sigillo Interiore', glyph: '印', dur: 15, stats: { matkPct: [25, 1.5], atkPct: [10, 0.5] }, desc: 'Attacco magico e fisico aumentati.' },
  tempesta_imminente: { name: 'Tempesta Imminente', glyph: '迅', dur: 10, proc: true, instant: ['dardo_luce', 'sfera_celeste'], consume: ['dardo_luce', 'sfera_celeste'], desc: 'Il prossimo Dardo di Luce o Sfera Celeste è istantaneo.' },
  occhio_ciclone: { name: 'Occhio del Ciclone', glyph: '旋', dur: 15, stats: { hastePct: [30, 1], dmgPct: [10, 0.5] }, desc: 'Rapidità e danni aumentati.' },
  benedizione: { name: 'Benedizione', glyph: '福', dur: 300, stats: { defPct: [12, 1.2], atkPct: [6, 0.6], matkPct: [6, 0.6] }, desc: 'Difesa e attacco aumentati.' },
  risonanza: { name: 'Risonanza', glyph: '響', dur: 8, proc: true, desc: 'Il prossimo colpo finale colpisce (o cura) ad area.' },
  occasione: { name: 'Occasione', glyph: '機', dur: 8, proc: true, finaleGratis: true, desc: 'Il prossimo colpo finale non costa risorsa e vale come se avessi la Concentrazione piena.' },
  baluardo: { name: 'Baluardo', glyph: '塁', dur: 6, stats: { dmgTaken: [-25, -0.3] }, desc: 'Danni subiti ridotti.' },
  // potenziamenti di classe (uno per classe, livello 8; quelli con «gruppo» valgono anche per i compagni vicini)
  grido_guerra: { name: 'Aura di Guerra', glyph: '吼', aura: true, dur: 0, stats: { dmgPct: [5, 0.2], dmgTaken: [-5, -0.15] }, desc: 'Aura: danni aumentati e danni subiti ridotti finché resta accesa.' },
  velo_ombra: { name: "Aura d'Ombra", glyph: '幽', aura: true, dur: 0, stats: { critPct: [8, 0.3], spdPct: [8, 0.2] }, desc: 'Aura: probabilità di critico e velocità di movimento aumentate finché resta accesa.' },
  respiro_drago: { name: 'Aura del Drago', glyph: '龍', aura: true, dur: 0, stats: { hastePct: [6, 0.2], lifesteal: [3, 0.12] }, desc: 'Aura: rapidità aumentata e i tuoi colpi ti curano di una parte dei danni, finché resta accesa.' },
  benedizione_astri: { name: 'Aura degli Astri', glyph: '星', aura: true, dur: 0, stats: { matkPct: [5, 0.2], atkPct: [4, 0.15], resRegenPct: [15, 0.5] }, desc: 'Aura: attacco e rigenerazione della risorsa aumentati finché resta accesa.' },
  // effetti sui nemici
  veleno: { name: 'Veleno', glyph: '毒', dur: 8, debuff: true, desc: 'Subisce danni nel tempo; i colpi finali dei Pugnali fanno più male.' },
  marchio_morte: { name: 'Marchio della Morte', glyph: '死', dur: 15, debuff: true, vuln: [20, 1], desc: "Subisce più danni da chi l'ha marchiato." },
};

// ------------------------------------------------------------------ abilità
// lvl: livello del personaggio per sbloccarla. cost/gen: risorsa (per il Mana: % del massimo).
// cast: secondi di lancio. offgcd: non attiva il tempo di ricarica globale. range: numero o 'weapon' (gittata dell'arma).
//
// POCHI TASTI: ogni Via ha 4 o 5 tecniche più la Suprema.
//   ruolo 'accumulo' — i due COLPI BASE: gratuiti, senza ricarica, sempre premibili, generano risorsa.
//       · quello a bersaglio singolo dà 1 punto di Concentrazione (`pts: 1`);
//       · quello ad area (`risonanza: true`), se colpisce almeno COMBAT.risMin nemici, accende la Risonanza.
//   ruolo 'potente'  — il COLPO FINALE (`finale: true`): spende risorsa e tutta la Concentrazione.
//       · senza Risonanza colpisce un bersaglio, +COMBAT.concPct% per punto di Concentrazione;
//       · con la Risonanza colpisce tutti i nemici attorno al bersaglio (COMBAT.risPct% dei danni a testa).
//   `interrupt: true` — l'INTERRUZIONE: spezza il lancio del bersaglio e lo stordisce; ricarica breve, fuori dal tempo globale.
//   la MOSSA DI VIA  — scatto, difesa, cura o potenziamento con ricarica (la Lama non ne ha: 4 tasti).
// Niente sequenze di tasti: il finale cambia da solo in base a come si sta combattendo, e ogni Via ha una
// MAESTRIA passiva (VIE[via].maestria) che premia il suo modo di giocare.
// `finoVia: true` — finale di base della classe: vale finché non si sceglie una Via, poi lo sostituisce quello della Via.
export const COMBAT = {
  scalaTecniche: 1, // moltiplicatore dei danni di tutte le tecniche (0,62 quando il tempo globale era a mezzo secondo)
  concPct: 9,        // +% danni (o cure) del finale per punto di Concentrazione, su bersaglio singolo
  risMin: 3,         // nemici colpiti dal colpo base ad area per accendere la Risonanza
  risDur: 8,         // secondi di durata della Risonanza
  risRaggio: 6,      // raggio del finale ad area attorno al bersaglio
  risPct: 60,        // danni del finale ad area su ogni nemico, in % del finale singolo senza Concentrazione
  genInterr: 15,     // risorsa restituita da un'interruzione riuscita (che dà anche un'Occasione)
  occasionePct: 6,   // probabilità che un colpo base a segno dia un'Occasione (prossimo finale gratuito e a Concentrazione piena)
};
export const SKILLS = {
  // ======================= LAMA (Ira) — 4 tasti
  squarcio: { name: 'Squarcio', cls: 'lama', lvl: 1, ruolo: 'accumulo', type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.45, 0.072], gen: 14, pts: 1, glyph: '裂', color: 0xffe0a0, fx: 'slash', desc: 'Colpo base: un taglio su un bersaglio. Genera Ira e 1 punto di Impeto.' },
  fendente: { name: 'Fendente Rotante', cls: 'lama', lvl: 1, ruolo: 'accumulo', type: 'aoe_self', dmg: 'phys', mult: [0.82, 0.041], radius: 4.5, gen: 10, risonanza: true, glyph: '旋', color: 0xffd27a, fx: 'spin', desc: 'Colpo base ad area: colpisce tutti i nemici intorno. Se ne prende 3 o più accende la Risonanza.' },
  affondo_ira: { name: "Affondo dell'Ira", cls: 'lama', lvl: 2, ruolo: 'potente', finale: true, finoVia: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.5, 0.125], cost: 40, glyph: '突', color: 0xff8a4a, fx: 'slash', desc: 'Colpo finale: scarica Ira e Impeto in un affondo. Con la Risonanza colpisce tutti i nemici attorno al bersaglio.' },
  grido_guerra: { name: 'Aura di Guerra', cls: 'lama', lvl: 8, type: 'aura', offgcd: true, aura: true, buff: 'grido_guerra', gruppo: 15, cd: 2, glyph: '吼', color: 0xff8a4a, fx: 'buff_lama', desc: "Aura: un'aura rosso-oro ti avvolge e resta accesa finché non la spegni (o cadi). Tu e i compagni di gruppo entro 15 metri infliggete più danni e ne subite meno. Premi di nuovo per spegnerla." },
  velo_ombra: { name: "Aura d'Ombra", cls: 'ombra', lvl: 8, type: 'aura', offgcd: true, aura: true, buff: 'velo_ombra', cd: 2, glyph: '幽', color: 0x7a5aa8, fx: 'buff_ombra', desc: "Aura: un velo di fumo scuro ti avvolge e resta acceso finché non lo spegni (o cadi). Critico e velocità di movimento aumentano. Premi di nuovo per spegnerla." },
  respiro_drago: { name: 'Aura del Drago', cls: 'monaco', lvl: 8, type: 'aura', offgcd: true, aura: true, buff: 'respiro_drago', cd: 2, glyph: '龍', color: 0xffb040, fx: 'buff_monaco', desc: "Aura: il chi ti arde attorno e resta acceso finché non lo spegni (o cadi). Sei più rapido e i tuoi colpi ti curano. Premi di nuovo per spegnerla." },
  benedizione_astri: { name: 'Aura degli Astri', cls: 'mistico', lvl: 8, type: 'aura', offgcd: true, aura: true, buff: 'benedizione_astri', gruppo: 20, cd: 2, glyph: '星', color: 0xbfe0ff, fx: 'buff_mistico', desc: "Aura: una corona di stelle ti gira attorno e resta accesa finché non la spegni (o cadi). Tu e i compagni di gruppo entro 20 metri avete attacco e rigenerazione aumentati. Premi di nuovo per spegnerla." },
  carica: { name: 'Carica Fulminea', cls: 'lama', lvl: 3, type: 'strike', dash: true, scatto: true, offgcd: true, interrupt: true, range: 14, dmg: 'phys', mult: [0.8, 0.04], gen: 20, stun: [1, 0.02], cd: 12, glyph: '馳', color: 0x9fd4ff, fx: 'dash', desc: 'Interruzione e scatto: carichi in linea retta e ti fermi davanti al bersaglio, spezzi il suo lancio e lo stordisci; ottieni 20 Ira.' },
  // Via del Fulmine
  lama_tuono: { name: 'Lama del Tuono', cls: 'lama', via: 'fulmine', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [3.0, 0.15], cost: 40, glyph: '雷', color: 0x9fd4ff, fx: 'lightning', desc: 'Colpo finale: un fulmine cala con la lama. Con la Risonanza le saette colpiscono tutti i nemici attorno al bersaglio.' },
  // Via della Montagna
  radici_monte: { name: 'Radici della Montagna', cls: 'lama', via: 'montagna', lvl: 7, type: 'aoe_self', offgcd: true, provoca: true, radius: 8, dmg: 'phys', mult: [0.6, 0.03], gen: 15, buff: 'pelle_pietra', cd: 20, glyph: '根', color: 0xc0a070, fx: 'quake', desc: 'Mossa: pesti il suolo e la roccia sale attorno a te. Tutti i nemici entro 8 metri ti prendono di mira e per 10 secondi hai la Pelle di Pietra (danni subiti ridotti, vita che si rigenera).' },
  martello_monte: { name: 'Martello della Montagna', cls: 'lama', via: 'montagna', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.5, 0.125], cost: 40, threat: 3, stun: [1, 0.02], buff: 'baluardo', glyph: '槌', color: 0xc0a070, fx: 'quake', desc: 'Colpo finale: schiaccia e stordisce il bersaglio, attira la minaccia e ti dà il Baluardo. Con la Risonanza la terra frana su tutti i nemici vicini.' },

  // ======================= OMBRA (Energia) — 5 tasti
  colpo_rapido: { name: 'Colpo Rapido', cls: 'ombra', lvl: 1, ruolo: 'accumulo', type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.3, 0.065], gen: 9, pts: 1, glyph: '速', color: 0xd0d0e0, fx: 'slash', desc: 'Colpo base: un colpo veloce su un bersaglio. Genera Energia e 1 Punto combo.' },
  ventaglio: { name: 'Ventaglio di Lame', cls: 'ombra', lvl: 1, ruolo: 'accumulo', type: 'aoe_target', range: 'weapon', radius: 4.5, dmg: 'phys', mult: [0.78, 0.039], gen: 7, risonanza: true, glyph: '扇', color: 0xa0d070, fx: 'rain', desc: 'Colpo base ad area: lame o frecce a ventaglio attorno al bersaglio. Se prende 3 o più nemici accende la Risonanza.' },
  taglio_netto: { name: 'Taglio Netto', cls: 'ombra', lvl: 2, ruolo: 'potente', finale: true, finoVia: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.5, 0.125], cost: 40, glyph: '斬', color: 0xe06a4a, fx: 'slash', desc: 'Colpo finale: scarica Energia e Punti combo. Con la Risonanza colpisce tutti i nemici attorno al bersaglio.' },
  colpo_gola: { name: 'Colpo alla Gola', cls: 'ombra', lvl: 3, type: 'strike', offgcd: true, interrupt: true, range: 'weapon', dmg: 'phys', mult: [0.6, 0.03], gen: 8, stun: [1, 0.02], cd: 12, glyph: '黙', color: 0xb08ae0, fx: 'mark', desc: "Interruzione: spezzi il lancio del bersaglio e lo stordisci. Funziona anche con l'arco." },
  // Via dei Pugnali
  taglio_finale: { name: 'Taglio Finale', cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.45, 0.122], cost: 40, behind: { dmg: 20, pts: 0 }, glyph: '終', color: 0xe04a4a, fx: 'slash', desc: 'Colpo finale: +20% alle spalle. Con la Risonanza colpisce tutti i nemici attorno al bersaglio. Richiede pugnali.' },
  passo_ombra: { name: "Passo d'Ombra", cls: 'ombra', via: 'pugnali', req: 'daggers', lvl: 7, type: 'strike', dash: true, behindDash: true, scatto: true, offgcd: true, range: 12, pts: 2, cd: 12, glyph: '潜', color: 0x7a5aa8, fx: 'dash', desc: 'Mossa: svanisci e riappari alle spalle del bersaglio; ottieni 2 Punti combo.' },
  // Via dell'Arco
  freccia_perforante: { name: 'Freccia Perforante', cls: 'ombra', via: 'arco', req: 'bow', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [2.55, 0.14], cost: 40, ignoreDef: 30, glyph: '貫', color: 0xffc070, fx: 'arrow', desc: 'Colpo finale: una freccia che ignora parte della difesa. Con la Risonanza esplode su tutti i nemici attorno al bersaglio. Richiede un arco.' },
  ala_vento: { name: 'Ala di Vento', cls: 'ombra', via: 'arco', req: 'bow', lvl: 7, type: 'strike', dash: true, dashDist: 9, scatto: true, offgcd: true, range: 20, dmg: 'phys', mult: [0.6, 0.03], slow: { dur: 2 }, pts: 2, buff: 'occhio_falco', cd: 15, glyph: '翼', color: 0xb0e8ff, fx: 'dash', desc: "Mossa e scatto: una folata ti porta a 9 metri dal bersaglio (avanti se sei lontano, indietro se ti sta addosso) e gli scagli contro una raffica di penne che lo rallenta. Ottieni 2 Punti combo e per 6 secondi l'Occhio del Falco (rapidità e rigenerazione dell'Energia)." },

  // ======================= MONACO (Chi) — 5 tasti
  pugno_ferro: { name: 'Pugno di Ferro', cls: 'monaco', lvl: 1, ruolo: 'accumulo', type: 'strike', range: 'weapon', dmg: 'phys', mult: [1.55, 0.078], gen: 9, pts: 1, glyph: '拳', color: 0xffb060, fx: 'slash', desc: 'Colpo base: un pugno su un bersaglio. Genera Chi e 1 Sfera.' },
  calcio_gru: { name: 'Calcio della Gru', cls: 'monaco', lvl: 1, ruolo: 'accumulo', type: 'aoe_self', dmg: 'phys', mult: [0.95, 0.048], radius: 4.5, gen: 7, risonanza: true, glyph: '鶴', color: 0x9fe0c0, fx: 'spin', desc: 'Colpo base ad area: un calcio rotante su tutti i nemici intorno. Se ne prende 3 o più accende la Risonanza.' },
  onda_chi: { name: 'Onda di Chi', cls: 'monaco', lvl: 2, ruolo: 'potente', finale: true, finoVia: true, type: 'strike', range: 8, dmg: 'hybrid', mult: [2.9, 0.145], cost: 40, glyph: '波', color: 0x7fe0c0, fx: 'bolt', desc: 'Colpo finale: scarica Chi e Sfere in un globo di energia. Con la Risonanza investe tutti i nemici attorno al bersaglio.' },
  calcio_volante: { name: 'Calcio Volante', cls: 'monaco', lvl: 4, type: 'strike', dash: true, scatto: true, offgcd: true, range: 12, dmg: 'phys', mult: [0.9, 0.045], gen: 10, pts: 1, cd: 10, glyph: '飛', color: 0xffa040, fx: 'dash', desc: 'Scatto: un balzo avvolto nel chi fino al bersaglio, che colpisci con un calcio in volo. Genera Chi e 1 Sfera.' },
  palmo_chi: { name: 'Palmo che Spezza', cls: 'monaco', lvl: 3, type: 'strike', offgcd: true, interrupt: true, range: 'weapon', dmg: 'phys', mult: [0.7, 0.035], gen: 8, stun: [1.2, 0.02], cd: 12, glyph: '掌', color: 0x7fe0c0, fx: 'bolt', desc: 'Interruzione: un palmo al petto spezza il lancio del bersaglio e lo stordisce.' },
  // Via del Pugno di Ferro
  raffica: { name: 'Raffica dei Cento Pugni', cls: 'monaco', via: 'ferro', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 'weapon', dmg: 'phys', mult: [3.9, 0.195], cost: 40, glyph: '連', color: 0xffa040, fx: 'slash', desc: 'Colpo finale: una raffica di pugni. Con la Risonanza travolge tutti i nemici attorno al bersaglio.' },
  pelle_bronzo: { name: 'Pelle di Bronzo', cls: 'monaco', via: 'ferro', lvl: 7, type: 'buff', offgcd: true, buff: 'pelle_bronzo', cd: 30, glyph: '銅', color: 0xc08a4a, fx: 'aura', desc: 'Mossa: per 10 secondi subisci meno danni e rigeneri vita.' },
  // Via del Loto Interiore
  vortice_interiore: { name: 'Vortice Interiore', cls: 'monaco', via: 'loto', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 10, dmg: 'hybrid', mult: [4.5, 0.225], cost: 40, glyph: '渦', color: 0xf0a0d0, fx: 'bolt', desc: 'Colpo finale a media distanza: un vortice di chi. Con la Risonanza si apre su tutti i nemici attorno al bersaglio.' },
  meditazione: { name: 'Meditazione', cls: 'monaco', via: 'loto', lvl: 7, type: 'hot_self', offgcd: true, heal: [0.035, 0.002], dur: 8, cd: 20, glyph: '禅', color: 0x9fe0c0, fx: 'heal', desc: 'Mossa: rigeneri la vita per 8 secondi.' },

  // ======================= MISTICO (Mana) — 5 tasti
  dardo_luce: { name: 'Dardo di Luce', cls: 'mistico', lvl: 1, ruolo: 'accumulo', type: 'strike', range: 20, dmg: 'magic', mult: [1.95, 0.098], gen: 3, pts: 1, cast: 1.0, mobile: true, glyph: '光', color: 0xfff4b0, fx: 'bolt', desc: 'Colpo base (0,5 s, anche camminando): un dardo su un bersaglio. Rende Mana e 1 Carica celeste.' },
  sfera_celeste: { name: 'Sfera Celeste', cls: 'mistico', lvl: 1, ruolo: 'accumulo', type: 'aoe_target', range: 20, radius: 4.5, dmg: 'magic', mult: [0.92, 0.046], gen: 3, risonanza: true, cast: 1.2, mobile: true, glyph: '球', color: 0xc0e8ff, fx: 'bolt', desc: 'Colpo base ad area (0,6 s, anche camminando): una sfera esplode sul bersaglio. Se prende 3 o più nemici accende la Risonanza.' },
  lancia_luce: { name: 'Lancia di Luce', cls: 'mistico', lvl: 2, ruolo: 'potente', finale: true, finoVia: true, type: 'strike', range: 20, dmg: 'magic', mult: [3.2, 0.16], cost: 9, glyph: '槍', color: 0xffe890, fx: 'lightning', desc: 'Colpo finale istantaneo: scarica Mana e Cariche. Con la Risonanza colpisce tutti i nemici attorno al bersaglio.' },
  passo_luce: { name: 'Passo di Luce', cls: 'mistico', lvl: 4, type: 'blink', dist: 10, scatto: true, offgcd: true, cd: 10, glyph: '閃', color: 0xd8f0ff, fx: 'dash', desc: 'Scatto: ti sciogli in luce e riappari 10 metri più avanti, nella direzione in cui guardi. Non interrompe il lancio in corso.' },
  sigillo_silenzio: { name: 'Sigillo del Silenzio', cls: 'mistico', lvl: 3, type: 'strike', offgcd: true, interrupt: true, range: 20, dmg: 'magic', mult: [0.5, 0.025], gen: 2, stun: [1, 0.02], cd: 14, glyph: '封', color: 0xa0b0ff, fx: 'mark', desc: 'Interruzione a distanza: spezza il lancio del bersaglio e lo stordisce.' },
  // Via della Tempesta
  giudizio_cielo: { name: 'Giudizio del Cielo', cls: 'mistico', via: 'tempesta', lvl: 5, ruolo: 'potente', finale: true, type: 'strike', range: 20, dmg: 'magic', mult: [3.4, 0.17], cost: 9, glyph: '審', color: 0x9fd4ff, fx: 'lightning', desc: 'Colpo finale istantaneo: una folgore. Con la Risonanza un diluvio di saette su tutti i nemici attorno al bersaglio.' },
  occhio_ciclone: { name: 'Occhio del Ciclone', cls: 'mistico', via: 'tempesta', lvl: 7, type: 'buff', offgcd: true, buff: 'occhio_ciclone', cd: 45, glyph: '旋', color: 0xa0d8ff, fx: 'wind', desc: 'Mossa: per 15 secondi rapidità e danni aumentano.' },
  // Via della Benedizione (guaritore): i colpi base fanno danni e, per la Maestria, curano l'alleato più ferito
  tocco_curativo: { name: 'Benedizione di Giada', cls: 'mistico', via: 'benedizione', lvl: 5, ruolo: 'potente', finale: true, type: 'heal_target', range: 25, heal: [3.2, 0.16], cost: 9, glyph: '癒', color: 0x7fd07f, fx: 'heal', desc: "Colpo finale istantaneo: cura l'alleato scelto (o, se hai un nemico come bersaglio, l'alleato più ferito vicino). Con la Risonanza cura tutti gli alleati vicini." },
  scudo_giada: { name: 'Scudo di Giada', cls: 'mistico', via: 'benedizione', lvl: 7, type: 'shield', offgcd: true, range: 25, shield: [3.0, 0.15], cost: 4, cd: 10, glyph: '盾', color: 0x6ad8a0, fx: 'shield', desc: "Mossa: uno scudo assorbe i danni dell'alleato scelto (o tuoi) per 15 secondi." },
};
// ======================= TECNICHE SUPREME (una per classe, dal livello 15: richiedono la barra Suprema piena)
// waves/waveGap: il colpo si ripete a ondate sulla stessa zona (o sullo stesso bersaglio se non ha raggio).
Object.assign(SKILLS, {
  giudizio_tuoni: { name: 'Giudizio dei Cento Tuoni', cls: 'lama', lvl: 15, sup: true, type: 'strike', dash: true, range: 16, dmg: 'phys', mult: [2.6, 0.13], splash: 7, radius: 7, waves: 4, waveGap: 0.28, stun: [1.5, 0.03], glyph: '轟', color: 0x9fd4ff, fx: 'dash', desc: 'TECNICA SUPREMA. Scatti sul bersaglio e il cielo si spezza: quattro ondate di fulmini colpiscono tutti i nemici intorno, stordendoli.' },
  mille_ombre: { name: 'Danza delle Mille Ombre', cls: 'ombra', lvl: 15, sup: true, type: 'strike', dash: true, behindDash: true, range: 20, dmg: 'phys', mult: [1.1, 0.055], hits: 3, waves: 3, waveGap: 0.22, pts: 5, glyph: '幻', color: 0xb08ae0, fx: 'dash', desc: 'TECNICA SUPREMA. Ti dissolvi in copie d\'ombra che colpiscono il bersaglio da ogni lato: nove colpi e Punti combo al massimo.' },
  drago_celeste: { name: 'Ascesa del Drago Celeste', cls: 'monaco', lvl: 15, sup: true, type: 'aoe_self', radius: 9, dmg: 'hybrid', mult: [3.6, 0.18], waves: 3, waveGap: 0.4, stun: [2, 0.03], pts: 3, glyph: '龍', color: 0xffb04a, fx: 'quake', desc: 'TECNICA SUPREMA. Un drago di chi sale dal suolo e ricade tre volte su tutti i nemici intorno, stordendoli. Genera 3 Sfere.' },
  collera_cielo: { name: 'Collera del Cielo', cls: 'mistico', lvl: 15, sup: true, type: 'aoe_target', range: 22, radius: 8, dmg: 'magic', mult: [1.5, 0.075], waves: 5, waveGap: 0.35, pts: 2, glyph: '天', color: 0xa0d8ff, fx: 'lightning', desc: 'TECNICA SUPREMA. Il cielo si apre sul bersaglio: cinque ondate di saette su tutta la zona. Istantanea.' },
});
export const supremaOf = (cls) => Object.values(SKILLS).find((s) => s.sup && s.cls === cls) || null;

// ======================= TECNICHE A CAVALLO (tutte le classi, solo in sella)
// hlvl: livello del destriero richiesto. dmg 'best': il maggiore tra attacco fisico e magico.
Object.assign(SKILLS, {
  carica_destriero: { name: 'Carica del Destriero', cls: '*', mount: true, hlvl: 1, type: 'strike', dash: true, range: 15, dmg: 'best', mult: [1.4, 0.07], splash: 3.5, stun: [0.8, 0.02], cd: 8, glyph: '駆', color: 0xffd27a, fx: 'dash', desc: 'Il destriero carica il bersaglio travolgendo chi gli sta intorno.' },
  fendente_corsa: { name: 'Fendente in Corsa', cls: '*', mount: true, hlvl: 1, type: 'aoe_self', dmg: 'best', mult: [1.1, 0.06], radius: 5.5, cd: 2, glyph: '疾', color: 0xffe0a0, fx: 'spin', desc: 'Un ampio fendente dalla sella su tutti i nemici intorno. Il colpo base del grind a cavallo.' },
  zoccoli_tuono: { name: 'Zoccoli di Tuono', cls: '*', mount: true, hlvl: 8, type: 'aoe_self', dmg: 'best', mult: [1.6, 0.08], radius: 7, stun: [1.2, 0.02], cd: 10, glyph: '蹄', color: 0xc9a66b, fx: 'quake', desc: 'Il destriero si impenna e pesta il suolo: danni ad area e stordimento.' },
  turbine_galoppo: { name: 'Turbine al Galoppo', cls: '*', mount: true, hlvl: 15, type: 'aoe_self', dmg: 'best', mult: [2.4, 0.1], radius: 8, cd: 18, glyph: '旋', color: 0x9fd4ff, fx: 'wind', desc: 'Un turbine di colpi in pieno galoppo su un\'area molto ampia.' },
});
export const MOUNT_SKILLS = ['carica_destriero', 'fendente_corsa', 'zoccoli_tuono', 'turbine_galoppo'];

for (const [id, sk] of Object.entries(SKILLS)) sk.id = id;

// ------------------------------------------------------------------ destriero
export const HORSE = {
  minLevel: 10, price: 5000, maxLevel: 20, mountMs: 1500,
  speed: (l) => 1.5 + 0.025 * (l - 1),
  need: (l) => Math.floor(300 * Math.pow(l, 1.5)),
  expShare: 0.3, // parte dell'esperienza base dei mostri che va al destriero quando sei in sella
  trainCost: (l) => 1500 * l, trainPct: 25,
  tierOf: (l) => (l >= 20 ? 3 : l >= 10 ? 2 : 1),
  names: ['', 'Puledro', 'Destriero', 'Destriero da Guerra'],
};

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
  sigillo_prova: { name: 'Sigillo della Prova', type: 'key', price: 0, glyph: '鍵', color: '#a02a2a', tier: 4, desc: 'Apre una Prova del Sigillo dal Custode Yun: la Cripta delle Mille Lanterne (dal livello 20) o la Forgia del Drago Addormentato (dal 35). Completala in tempo per far salire il livello del sigillo.' },
  // Modificatori: si trascinano su un'arma o un'armatura
  pietra_affinamento: { name: "Pietra dell'Affinamento", type: 'mod', mod: 'refine', price: 2500, stack: true, glyph: '磨', color: '#5a7a8a', desc: "Trascinala su un oggetto: rilancia i valori dei bonus casuali mantenendone i tipi." },
  pergamena_mutamento: { name: 'Pergamena del Mutamento', type: 'mod', mod: 'reroll', price: 6000, stack: true, glyph: '変', color: '#7a5a2a', desc: "Trascinala su un oggetto: rimescola completamente i bonus casuali (tipi e valori)." },
  sigillo_ascensione: { name: "Sigillo dell'Ascensione", type: 'mod', mod: 'ascend', price: 40000, stack: true, glyph: '昇', color: '#a05ac0', desc: "Trascinalo su un oggetto: 35% di probabilità di alzarne la rarità di un grado (nuovo bonus e incavi). Si consuma comunque." },
  scalpello: { name: 'Scalpello del Gioielliere', type: 'mod', mod: 'extract', price: 1500, stack: true, glyph: '鑿', color: '#6a6a6a', desc: "Trascinalo su un oggetto: estrae tutte le gemme incastonate e te le restituisce." },
};

// ------------------------------------------------------------------ gradi intermedi (un pezzo ogni 5 livelli)
// Fra i quattro gradi dei livelli 1/10/20/30 c'erano dieci livelli vuoti: qui un pezzo ai livelli 5, 15, 25, 35, 40 e 45
// per ogni arma e per armatura, copricapo e calzari. L'aspetto nel client viene dal grado (`tier`, 1-4) come per gli
// altri; copricapi e calzari hanno anche `aspetto`, l'id del pezzo di cui usano il modello (i modelli si chiamano come
// gli oggetti dei quattro gradi). Statistiche e prezzi stanno a metà fra i gradi vicini (oltre il 30 crescono allo stesso passo).
export const LIV_INTERMEDI = [5, 15, 25, 35, 40, 45];
const tierDi = (l) => (l < 10 ? 1 : l < 20 ? 2 : l < 30 ? 3 : 4);
const ELMO_DI = ['', 'cappello_paglia', 'elmo_bronzo', 'elmo_cornuto', 'elmo_drago'];
const CALZARE_DI = ['', 'sandali', 'stivali_cuoio', 'stivali_vento', 'stivali_nube'];
const PREZZI_ARMI = [1000, 7000, 24000, 60000, 85000, 115000];
const PREZZI_CORAZZE = [800, 6500, 22000, 55000, 78000, 105000];
const INTERMEDI = [
  // [prefisso dell'id, campi comuni, valori per livello, nomi per livello]
  ['spada', { type: 'weapon', wt: 'sword', glyph: '剣' }, { atk: [22, 43, 68, 95, 108, 121] },
    ['Spada del Viandante', 'Lama di Ferro Temprato', 'Spada del Fiume di Giada', 'Spada della Gru Argentata', 'Spada del Vento Rosso', 'Spada delle Dune Cantanti']],
  ['pugnali', { type: 'weapon', wt: 'daggers', glyph: '刃' }, { atk: [18, 35, 56, 79, 90, 101] },
    ['Pugnali del Cacciatore', 'Pugnali a Dente di Lupo', 'Pugnali della Vipera Verde', 'Pugnali della Luna Nuova', 'Pugnali dello Scorpione Rosso', 'Pugnali del Miraggio']],
  ['arco', { type: 'weapon', wt: 'bow', glyph: '弓' }, { atk: [16, 33, 53, 75, 86, 97], range: [15, 16, 17, 18, 18, 18] },
    ['Arco di Gelso', 'Arco del Cacciatore di Gole', 'Arco del Salice Piangente', 'Arco della Canna Cava', 'Arco del Simun', 'Arco del Sole Calante']],
  ['pugni', { type: 'weapon', wt: 'fists', glyph: '拳' }, { atk: [16, 33, 52, 72, 82, 92], matk: [9, 20, 33, 47, 54, 61] },
    ['Fasce di Cuoio Intrecciato', 'Nocche di Bronzo', 'Artigli della Gru di Giada', 'Guanti del Tuono Verde', 'Guanti della Sabbia Rovente', 'Pugni del Leone delle Dune']],
  ['bastone', { type: 'weapon', wt: 'staff', glyph: '杖' }, { atk: [7, 13, 19, 25, 28, 31], matk: [22, 43, 67, 93, 106, 119], range: [15, 16, 17, 18, 18, 18] },
    ['Bastone di Bambù Nero', 'Bastone della Lanterna', "Bastone del Loto d'Argento", 'Bastone dello Smeraldo Cavo', 'Bastone del Vento Rosso', 'Bastone del Miraggio Eterno']],
  ['corazza', { type: 'body', glyph: '鎧' }, { def: [10, 23, 38, 54, 62, 70] },
    ['Giubba Imbottita', 'Corazza di Cuoio Borchiato', 'Corazza del Guardiano di Giada', 'Armatura della Gru Celeste', 'Armatura delle Dune', 'Armatura del Sole Rosso']],
  ['elmo', { type: 'head', glyph: '兜' }, { def: [4, 8, 14, 20, 23, 26] },
    ['Fascia del Viandante', 'Elmo del Predone', 'Elmo del Guardiano di Giada', 'Elmo della Gru Celeste', 'Elmo delle Dune', 'Elmo del Sole Rosso']],
  ['calzari', { type: 'feet', glyph: '靴' }, { def: [2, 4, 6, 9, 10, 11], speed: [2, 7, 12, 15, 16, 17] },
    ['Calzari di Feltro', 'Stivali delle Gole', 'Stivali del Guardiano di Giada', 'Stivali della Gru Celeste', 'Stivali delle Dune', 'Stivali del Sole Rosso']],
];
for (const [pre, comuni, valori, nomi] of INTERMEDI) {
  LIV_INTERMEDI.forEach((lvl, i) => {
    const tier = tierDi(lvl);
    const it = { name: nomi[i], ...comuni, lvl, tier };
    for (const [k, arr] of Object.entries(valori)) it[k] = arr[i];
    const prezzi = comuni.type === 'weapon' ? PREZZI_ARMI : PREZZI_CORAZZE;
    it.price = Math.round(prezzi[i] * (comuni.type === 'head' ? 0.7 : comuni.type === 'feet' ? 0.65 : 1));
    if (comuni.type === 'head') it.aspetto = ELMO_DI[tier];
    if (comuni.type === 'feet') it.aspetto = CALZARE_DI[tier];
    ITEMS[`${pre}_${lvl}`] = it;
  });
}

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
  elite: [20, 40, 28, 10, 2],   // solitari élite (vita ≥ 1000): pezzi migliori
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
// cast: lancio interrompibile { name, ms, mult (× attacco), cd, raggio (se colpisce ad area attorno al mostro) }
export const MOBS = {
  lupo: { name: 'Lupo Grigio', lvl: 2, hp: 72, atk: 9, def: 2, exp: 25, speed: 5.5, aggro: 0, range: 2.0, aspd: 1600, model: 'wolf', color: 0x777370, scale: 1, bott: 0.8, respawn: 24, tael: [3, 8],
    drops: [['zanna_lupo', 0.35], ['ginseng_p', 0.08]] },
  cinghiale: { name: 'Cinghiale Selvatico', lvl: 3, hp: 112, atk: 11, def: 4, exp: 34, speed: 5, aggro: 0, range: 2.2, aspd: 1700, model: 'boar', color: 0x5a3e2b, scale: 1, bott: 0.8, respawn: 24, tael: [4, 10],
    drops: [['pelle_cinghiale', 0.35], ['ginseng_p', 0.1], ['loto_p', 0.06]] },
  lupo_alfa: { name: 'Lupo Alfa', lvl: 5, hp: 260, atk: 17, def: 6, exp: 85, speed: 6, aggro: 9, range: 2.3, aspd: 1500, model: 'wolf', color: 0x3c3a40, scale: 1.3, respawn: 30, tael: [10, 25],
    drops: [['zanna_lupo', 0.6, 1, 2], ['ginseng_p', 0.15], ['loto_p', 0.1], ['pergamena_ritorno', 0.03]] },
  lupo_anziano: { name: 'Lupo Anziano', lvl: 6, hp: 1000, atk: 20, def: 8, exp: 330, speed: 5.5, aggro: 8, range: 2.4, aspd: 1500, model: 'wolf', color: 0xb8b8c4, scale: 1.45, respawn: 60, tael: [30, 60],
    drops: [['zanna_lupo', 0.7, 1, 2], ['ginseng_p', 0.25], ['loto_p', 0.12], ['pergamena_ritorno', 0.05]] },
  bandito: { name: 'Bandito della Strada', lvl: 8, hp: 330, atk: 26, def: 10, exp: 118, speed: 5, aggro: 10, range: 2.4, aspd: 1500, model: 'bandit', color: 0x3b2f2f, scale: 1, bott: 0.9, respawn: 32, tael: [20, 45],
    drops: [['benda_bandito', 0.4], ['ginseng_m', 0.08], ['minerale_ferro', 0.04]] },
  scimmia: { name: 'Scimmia Ladra', lvl: 10, hp: 380, atk: 30, def: 12, exp: 146, speed: 6.5, aggro: 0, range: 2.0, aspd: 1200, model: 'monkey', color: 0x7a5230, scale: 1, bott: 0.9, respawn: 32, tael: [32, 72],
    drops: [['ginseng_m', 0.12], ['loto_m', 0.1], ['minerale_ferro', 0.05]] },
  arciere_bandito: { name: 'Arciere Bandito', cast: { name: 'Tiro Mirato', ms: 1800, mult: 2.4, cd: 9000 }, lvl: 12, hp: 420, atk: 36, def: 12, exp: 185, speed: 5, aggro: 14, range: 13, ranged: true, aspd: 1900, model: 'bandit_archer', color: 0x3b3a2f, scale: 1, bott: 0.9, respawn: 36, tael: [32, 68],
    drops: [['benda_bandito', 0.4], ['ginseng_m', 0.1], ['minerale_ferro', 0.06]] },
  orso_nero: { name: 'Orso Nero della Gola', lvl: 14, hp: 1100, atk: 48, def: 20, exp: 380, speed: 4.5, aggro: 0, range: 2.8, aspd: 2000, model: 'bear', color: 0x2a2420, scale: 1.25, respawn: 45, tael: [60, 120],
    drops: [['ginseng_m', 0.2, 1, 2], ['minerale_ferro', 0.15], ['frammento_obelisco', 0.01]] },
  spirito_lanterna: { name: 'Spirito della Lanterna', cast: { name: 'Fuoco Fatuo', ms: 2000, mult: 2.4, cd: 9000 }, lvl: 16, hp: 800, atk: 52, def: 16, exp: 420, speed: 4, aggro: 12, range: 12, ranged: true, magic: true, aspd: 2000, model: 'lantern', color: 0xff8a3a, scale: 1, respawn: 40, tael: [70, 140],
    drops: [['loto_m', 0.2], ['loto_g', 0.04], ['minerale_ferro', 0.08]] },
  terracotta: { name: 'Guerriero di Terracotta', lvl: 18, hp: 1500, atk: 62, def: 30, exp: 560, speed: 4, aggro: 10, range: 2.6, aspd: 1800, model: 'terracotta', color: 0xa86a42, scale: 1.1, respawn: 45, tael: [90, 180],
    drops: [['coccio_terracotta', 0.4], ['ginseng_g', 0.05], ['minerale_ferro', 0.15], ['frammento_obelisco', 0.015]] },
  tigre_spettrale: { name: 'Tigre Spettrale', lvl: 21, hp: 1900, atk: 78, def: 32, exp: 720, speed: 6.5, aggro: 12, range: 2.6, aspd: 1500, model: 'tiger', color: 0xc8d0f0, scale: 1.2, respawn: 60, tael: [120, 220],
    drops: [['ginseng_g', 0.08], ['frammento_obelisco', 0.02], ['minerale_ferro', 0.15]] },
  generale: { name: 'Generale Senza Volto', cast: { name: 'Grido di Guerra', ms: 2600, mult: 2.4, cd: 14000, raggio: 9 }, lvl: 25, hp: 18000, atk: 120, def: 45, exp: 9000, speed: 4.5, aggro: 14, range: 3.4, aspd: 2200, model: 'general', color: 0x2a1a1a, scale: 1.9, respawn: 900, boss: true, tael: [3000, 6000],
    drops: [['frammento_obelisco', 0.9, 2, 4], ['tomo_tecnica', 0.7, 1, 2], ['sigillo_fabbro', 0.35], ['spada_gru', 0.12], ['pugnali_eclissi', 0.12], ['arco_autunno', 0.12], ['guanti_sole', 0.12], ['bastone_nubi', 0.12], ['armatura_nubi', 0.1], ['elmo_drago', 0.1], ['stivali_nube', 0.1]] },
  fantoccio: { name: "Fantoccio d'Addestramento", lvl: 30, hp: 9999999, atk: 0, def: 25, exp: 0, dummy: true, model: 'dummy', color: 0xc8a860, scale: 1, respawn: 0, speed: 0, aggro: 0, drops: [] },
  lupo_branco: { name: 'Lupo del Branco', lvl: 6, hp: 120, atk: 14, def: 4, exp: 33, speed: 5.5, aggro: 8, range: 2.0, aspd: 1600, model: 'wolf', color: 0x8a8378, scale: 0.9, bott: 0.8, respawn: 24, tael: [3, 7],
    drops: [['zanna_lupo', 0.25], ['ginseng_p', 0.05]] },
  predone: { name: 'Predone delle Colline', lvl: 12, hp: 255, atk: 30, def: 10, exp: 76, speed: 5, aggro: 9, range: 2.4, aspd: 1600, model: 'bandit', color: 0x4a3a2f, scale: 1, bott: 0.9, respawn: 30, tael: [10, 21],
    drops: [['benda_bandito', 0.25], ['ginseng_m', 0.04], ['minerale_ferro', 0.02]] },
  soldato_terracotta: { name: 'Soldato di Terracotta', lvl: 20, hp: 520, atk: 58, def: 22, exp: 175, speed: 4.2, aggro: 9, range: 2.5, aspd: 1700, model: 'terracotta', color: 0xb07a52, scale: 0.95, bott: 0.85, respawn: 36, tael: [24, 48],
    drops: [['coccio_terracotta', 0.25], ['ginseng_g', 0.02], ['minerale_ferro', 0.04]] },
  // Razziatori delle Gole (Terre di Confine lontane, 14-18) e Lancieri di Bronzo (cuore dell'Altopiano, 22-28): riempiono
  // i due buchi della curva (prima non c'erano branchi adatti fra il 13 e il 19 né fra il 22 e il 28).
  razziatore_gola: { name: 'Razziatore delle Gole', lvl: 15, hp: 340, atk: 40, def: 14, exp: 108, speed: 5.2, aggro: 10, range: 2.4, aspd: 1550, model: 'bandit', color: 0x5a2a22, scale: 1.02, bott: 0.9, respawn: 30, tael: [14, 30],
    drops: [['benda_bandito', 0.25], ['ginseng_m', 0.05], ['minerale_ferro', 0.03]] },
  lanciere_bronzo: { name: 'Lanciere di Bronzo', lvl: 24, hp: 640, atk: 70, def: 26, exp: 228, speed: 4.3, aggro: 10, range: 2.8, aspd: 1750, model: 'terracotta', color: 0x8a6a3a, scale: 1.0, bott: 0.85, respawn: 36, tael: [30, 60],
    drops: [['coccio_terracotta', 0.25], ['ginseng_g', 0.03], ['minerale_ferro', 0.05]] },
  sentinella_cripta: { name: 'Sentinella di Bronzo', lvl: 26, hp: 2600, atk: 72, def: 40, exp: 420, speed: 4, aggro: 11, range: 2.7, aspd: 1900, model: 'terracotta', color: 0x8a6a3a, scale: 1.25, respawn: 0, dungeon: true, tael: [60, 120], drops: [] },
  ombra_cripta: { name: 'Ombra Velata', lvl: 26, hp: 1400, atk: 66, def: 20, exp: 300, speed: 6.5, aggro: 13, range: 2.3, aspd: 1300, model: 'shade', color: 0x3a2a5a, scale: 1, respawn: 0, dungeon: true, tael: [40, 90], drops: [] },
  lanterna_cripta: { name: 'Lanterna Insonne', cast: { name: 'Fiamma Spettrale', ms: 2200, mult: 2.6, cd: 8000 }, lvl: 26, hp: 1300, atk: 78, def: 18, exp: 320, speed: 3.5, aggro: 13, range: 12, ranged: true, magic: true, aspd: 2100, model: 'lantern', color: 0x8a5aff, scale: 1.05, respawn: 0, dungeon: true, tael: [40, 90], drops: [] },
  custode_insonne: { name: 'Shen, il Custode Insonne', cast: { name: 'Giudizio delle Lanterne', ms: 3000, mult: 2.8, cd: 16000, raggio: 10 }, lvl: 28, hp: 60000, atk: 135, def: 50, exp: 15000, speed: 4.2, aggro: 16, range: 3.6, aspd: 2200, model: 'custode', color: 0x1a2a4a, scale: 2.0, respawn: 0, dungeon: true, boss: true, dungeonBoss: true, tael: [3000, 5000], drops: [] },
  lanterna_instabile: { name: 'Lanterna Instabile', lvl: 26, hp: 900, atk: 0, def: 10, exp: 0, speed: 2.6, aggro: 40, range: 1.5, aspd: 99999, model: 'lantern', color: 0xff4a20, scale: 0.8, respawn: 0, dungeon: true, explode: { after: 10, radius: 6, mult: 2.2 }, drops: [] },
  eco_spirito: { name: 'Eco Inquieta', lvl: 24, hp: 500, atk: 40, def: 10, exp: 60, speed: 5, aggro: 20, range: 10, ranged: true, magic: true, aspd: 1800, model: 'lantern', color: 0xa0d8ff, scale: 0.6, respawn: 0, dungeon: true, drops: [] },
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
  stalliere: { name: 'Mastro Bo', title: 'Stalliere' },
  custode: { name: 'Custode Yun', title: 'Guardiano delle Prove' },
};

export const GUARD_LINES = [
  'Fuori dalle mura i lupi si fanno audaci. Non allontanarti senza infusi di ginseng.',
  "Dicono che al centro della valle, sull'altopiano, si aggiri un generale senza volto.",
  'Gli obelischi corrotti richiamano mostri quando vengono colpiti. Affrontali in compagnia.',
  'Oltre le mura vale la legge della spada: i guerrieri degli altri regni possono attaccarti.',
];

// ------------------------------------------------------------------ Prove del Sigillo
// Coordinate locali rispetto all'origine dell'istanza. rooms: rettangoli calpestabili [x1, z1, x2, z2].
export const DUNGEON = {
  id: 'cripta', name: 'Cripta delle Mille Lanterne', trial: 'Prova del Sigillo',
  desc: "Un labirinto di sale funebri dove le lanterne non si spengono mai. In fondo veglia Shen, il Custode Insonne.",
  minLevel: 20, startKey: 2, timeLimit: 900, deathPenalty: 5, forcesNeeded: 100, maxKey: 30,
  originX: 1200, slotSpacing: 400, boundsMin: [-15, -15], boundsMax: [82, 125],
  spawn: [0, -5],
  rooms: [
    [-10, -10, 10, 10], [-4, 9, 4, 31], [-15, 30, 15, 60], [14, 41, 41, 49], [40, 30, 70, 60], [51, 59, 59, 81], [33, 80, 77, 120],
  ],
  // muri: [x1, z1, x2, z2] (segmenti orizzontali o verticali)
  walls: [
    [-10, -10, 10, -10], [-10, -10, -10, 10], [10, -10, 10, 10], [-10, 10, -4, 10], [4, 10, 10, 10],
    [-4, 10, -4, 30], [4, 10, 4, 30],
    [-15, 30, -4, 30], [4, 30, 15, 30], [-15, 60, 15, 60], [-15, 30, -15, 60], [15, 30, 15, 41], [15, 49, 15, 60],
    [15, 41, 40, 41], [15, 49, 40, 49],
    [40, 30, 40, 41], [40, 49, 40, 60], [40, 30, 70, 30], [70, 30, 70, 60], [40, 60, 51, 60], [59, 60, 70, 60],
    [51, 60, 51, 80], [59, 60, 59, 80],
    [33, 80, 51, 80], [59, 80, 77, 80], [33, 80, 33, 120], [77, 80, 77, 120], [33, 120, 77, 120],
  ],
  packs: [
    { x: 0, z: 22, mobs: ['sentinella_cripta', 'sentinella_cripta', 'ombra_cripta'] },
    { x: -7, z: 44, mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta', 'lanterna_cripta'] },
    { x: 8, z: 53, mobs: ['sentinella_cripta', 'sentinella_cripta', 'lanterna_cripta', 'lanterna_cripta'] },
    { x: 28, z: 45, mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta'] },
    { x: 54, z: 39, mobs: ['sentinella_cripta', 'sentinella_cripta', 'lanterna_cripta', 'lanterna_cripta'] },
    { x: 62, z: 53, mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta', 'ombra_cripta'] },
    { x: 55, z: 70, mobs: ['sentinella_cripta', 'sentinella_cripta'] },
  ],
  boss: { type: 'custode_insonne', x: 55, z: 106 },
  forces: { sentinella_cripta: 5, ombra_cripta: 4, lanterna_cripta: 5, eco_spirito: 1 },
};

// Modificatori settimanali (a rotazione). Dal livello 3 ne è attivo uno, dal livello 6 due.
export const AFFIXES = {
  pietra: { name: 'Pelle di Pietra', glyph: '岩', desc: 'I nemici normali hanno il 25% di vita e il 15% di danni in più.' },
  tiranno: { name: 'Re Tiranno', glyph: '王', desc: 'Il boss ha il 30% di vita e il 15% di danni in più.' },
  furia: { name: 'Furia Ancestrale', glyph: '怒', desc: 'Sotto il 30% di vita i nemici infliggono il 40% di danni in più.' },
  brace: { name: 'Sangue di Brace', glyph: '炎', desc: 'I nemici sconfitti lasciano a terra braci ardenti per 6 secondi.' },
  eco: { name: 'Eco degli Spiriti', glyph: '霊', desc: 'I nemici sconfitti possono liberare un\'Eco Inquieta da abbattere.' },
};
const AFFIX_ROTATION = [['pietra', 'furia'], ['tiranno', 'brace'], ['pietra', 'eco'], ['tiranno', 'furia'], ['pietra', 'brace'], ['tiranno', 'eco']];
export function weeklyAffixes(now = Date.now()) {
  const week = Math.floor((now - Date.UTC(2024, 0, 1)) / (7 * 86400000));
  return AFFIX_ROTATION[((week % AFFIX_ROTATION.length) + AFFIX_ROTATION.length) % AFFIX_ROTATION.length];
}
export function activeAffixes(level, now = Date.now()) {
  const w = weeklyAffixes(now);
  return level >= 6 ? w : level >= 3 ? [w[0]] : [];
}
// Moltiplicatori per livello del sigillo e numero di giocatori.
export function trialScale(level, players) {
  return { hp: Math.pow(1.1, level - 2) * (0.45 + 0.15 * Math.max(1, Math.min(5, players))), dmg: Math.pow(1.08, level - 2) };
}
// Avanzamento del sigillo in base al tempo impiegato.
export function keyChange(elapsed, limit) {
  if (elapsed > limit) return -1;
  if (elapsed <= limit * 0.6) return 3;
  if (elapsed <= limit * 0.8) return 2;
  return 1;
}

// Il punto (coordinate locali della cripta) è calpestabile? margin = raggio del personaggio.
export function dungeonWalkable(lx, lz, margin = 0.5, dg = DUNGEON) {
  for (const [x1, z1, x2, z2] of dg.rooms) {
    if (lx >= x1 + margin && lx <= x2 - margin && lz >= z1 + margin && lz <= z2 - margin) return true;
  }
  return false;
}

// Mostri e PNG delle mappe da esperienza e dell'Arena (definiti in shared/mappe.js).
Object.assign(MOBS, MOBS_MAPPE);
Object.assign(NPC_ROLES, NPC_MAPPE);
Object.assign(NPC_ROLES, NPC_MISSIONI);

// Contenuto per il livello alto (shared/altolivello.js): boss del mondo, Forgia, pezzi unici e trofei.
Object.assign(MOBS, MOBS_ALTO);
Object.assign(ITEMS, OGGETTI_ALTO);
// Prove del Sigillo disponibili dal Custode (la Cripta e la Forgia): id → definizione con stanze, muri, branchi e boss.
export const PROVE = { cripta: DUNGEON, forgia: FORGIA };

