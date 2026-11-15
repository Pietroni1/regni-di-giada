// Missioni: catena principale e incarichi giornalieri (definizioni in shared/missioni.js). Metodi aggiunti a World
// (installaMissioni in fondo a server/world.js), come server/mappe.js; world.js li chiama in pochi punti:
// ingresso (missioniEntra), morte di un mostro (missioniMorte), raccolta (missioniRaccolta), dialogo con un PNG
// (missioniPng), Prova completata e uccisione nell'arena (missioniEvento), livello (missioniLivello), tick (tickMissioni).
//
// Salvataggio nel personaggio: ch.mis = { cat, att, gg }
//   cat  indice della prossima missione della catena (quelle prima sono fatte)
//   att  missioni accettate: id → { p: [avanzamento per obiettivo], eq: [oggetti del premio scelti all'accettazione] }
//   gg   incarichi del giorno: { d: 'AAAA-MM-GG', scelte: [id], fatte: [id] }
// I personaggi creati prima delle missioni ricevono ch.mis al primo ingresso: la catena riparte dalla missione del
// loro livello (quelle più basse si saltano), nient'altro cambia.
import { ITEMS, MOBS, NPC_ROLES, SKILLS, RARITIES, CLASSES, HORSE, expToNext } from '../shared/data.js';
import { CATENA, INCARICHI, MISSIONI, PNG_INCARICHI, INCARICHI_AL_GIORNO, ZONE_MISSIONI, SBLOCCHI } from '../shared/missioni.js';
import { KINGDOMS, CENTER, DUNGEON_X, mulberry32 } from '../shared/world.js';
import { MAPPE, mappaAt } from '../shared/mappe.js';

const STATO_OB = ['via', 'destriero', 'livello', 'luogo'];   // obiettivi che si verificano guardando il personaggio
const RAGGIO_GRUPPO = 80;                                     // i compagni entro questa distanza dividono le uccisioni
const CONTROLLO_MS = 1000;
const r1 = (v) => Math.round(v * 10) / 10;
const migliaia = (n) => Math.round(n).toLocaleString('it-IT');

// Zona per gli obiettivi «luogo» (come zoneAt in shared/world.js, ma con un id).
export function zonaMissione(x, z) {
  const id = mappaAt(x, z);
  if (id) return id;
  if (x > DUNGEON_X) return 'cripta';
  if (Math.hypot(x - CENTER.x, z - CENTER.z) < 95) return 'altopiano';
  for (const kid of Object.keys(KINGDOMS)) {
    const v = KINGDOMS[kid].village;
    if (Math.hypot(x - v.x, z - v.z) < 125) return 'anello';
  }
  return 'confine';
}

// Giorno degli incarichi (UTC). `scarto` in giorni: il comando GM /giorno lo fa avanzare per le prove.
function oggi(scarto = 0) {
  return new Date(Date.now() + scarto * 86400000).toISOString().slice(0, 10);
}

function semeDi(testo) {
  let h = 2166136261;
  for (let i = 0; i < testo.length; i++) { h ^= testo.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

const metodi = {
  // ------------------------------------------------------------ stato salvato
  statoMissioni(p) {
    const ch = p.ch;
    if (!ch.mis || typeof ch.mis !== 'object') {
      // personaggio nuovo (livello 1) o creato prima delle missioni: si parte dalla missione adatta al livello
      let cat = 0;
      if (ch.lvl > 1) { cat = CATENA.findIndex((m) => m.liv >= ch.lvl - 1); if (cat < 0) cat = CATENA.length; }
      ch.mis = { cat, att: {}, gg: null };
    }
    const s = ch.mis;
    if (!Number.isInteger(s.cat) || s.cat < 0) s.cat = 0;
    if (!s.att || typeof s.att !== 'object') s.att = {};
    for (const id of Object.keys(s.att)) {
      const def = MISSIONI[id];
      if (!def) { delete s.att[id]; continue; }   // missione tolta dai dati
      const a = s.att[id];
      if (!Array.isArray(a.p)) a.p = [];
      a.p = def.ob.map((o, i) => Math.min(o.n || 1, Math.max(0, a.p[i] | 0)));
      if (!Array.isArray(a.eq)) a.eq = [];
    }
    return s;
  },

  // ------------------------------------------------------------ ingresso, tick e livello
  missioniEntra(p) {
    this.statoMissioni(p);
    this.giornoMissioni(p);
    this.catenaAutomatica(p);
    this.controllaMissioni(p);
    this.mandaMissioni(p);
  },

  tickMissioni(t) {
    if (t < (this._misAt || 0)) return;
    this._misAt = t + CONTROLLO_MS;
    for (const p of this.players) {
      if (!p.ch.mis) continue;
      const g = p.ch.mis.gg;
      if (!g || g.d !== oggi(this.giornoScarto || 0)) { this.giornoMissioni(p); this.mandaMissioni(p); }
      this.controllaMissioni(p);
    }
  },

  // Passaggio di livello: avviso con ciò che si sblocca, missioni che arrivano da sole, obiettivi di livello.
  missioniLivello(p, prima) {
    if (p.lvl <= prima) return;
    const voci = [];
    for (let L = prima + 1; L <= p.lvl; L++) {
      if (SBLOCCHI[L]) voci.push(SBLOCCHI[L]);
      for (const sk of Object.values(SKILLS)) {
        if (sk.cls !== p.cls || sk.lvl !== L || sk.mount || sk.sup) continue;
        if (sk.via && sk.via !== p.ch.via) continue;
        if (sk.finoVia && p.ch.via) continue;
        voci.push(`Nuova tecnica: ${sk.name}.`);
      }
      const pezzi = Object.values(ITEMS).filter((it) => it.lvl === L && it.type && ['weapon', 'body', 'head', 'feet'].includes(it.type) &&
        (it.type !== 'weapon' || CLASSES[p.cls].weapons.includes(it.wt)));
      if (pezzi.length && L > 1) voci.push(`Equipaggiamento del livello ${L}: ${pezzi.length} pezzi nuovi da trovare.`);
    }
    // una catena che aspettava questo livello
    const prossima = CATENA[p.ch.mis ? p.ch.mis.cat : 0];
    if (prossima && prossima.liv > prima && prossima.liv <= p.lvl && prossima.da) {
      voci.push(`${NPC_ROLES[prossima.da].name} ha una missione per te: «${prossima.titolo}».`);
    }
    this.send(p, { t: 'sblocchi', lvl: p.lvl, m: voci });
    this.giornoMissioni(p, true);
    this.catenaAutomatica(p);
    this.controllaMissioni(p);
    this.mandaMissioni(p);
  },

  // Le missioni della catena senza PNG che le affida (`da: null`) si accettano da sole.
  catenaAutomatica(p) {
    const s = p.ch.mis;
    const def = CATENA[s.cat];
    if (def && !def.da && !s.att[def.id] && p.lvl >= def.liv) this.accettaMissione(p, def, true);
  },

  // Nuovo giorno: si scelgono gli incarichi (sempre gli stessi per quel personaggio in quel giorno e a quel livello).
  // Con `livello` (passaggio di livello) si rifà la scelta tenendo quelli già fatti o accettati.
  giornoMissioni(p, livello = false) {
    const s = p.ch.mis, d = oggi(this.giornoScarto || 0);
    const stesso = s.gg && s.gg.d === d && Array.isArray(s.gg.scelte);
    if (stesso && !livello) return;
    const tieni = stesso ? s.gg.scelte.filter((id) => s.gg.fatte.includes(id) || s.att[id]) : [];
    const adatti = INCARICHI.filter((m) => p.lvl >= m.liv[0] && p.lvl <= m.liv[1] && !tieni.includes(m.id));
    const rng = mulberry32(semeDi(`${p.ch.name}|${d}|${p.lvl}`));
    for (let i = adatti.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [adatti[i], adatti[j]] = [adatti[j], adatti[i]]; }
    // l'Arena solo se non resta altro: è PvP e non tutti la vogliono fare
    adatti.sort((a, b) => (a.id === 'g_arena') - (b.id === 'g_arena'));
    const posti = Math.max(0, INCARICHI_AL_GIORNO(p.lvl) - tieni.length);
    s.gg = { d, scelte: [...tieni, ...adatti.slice(0, posti).map((m) => m.id)], fatte: stesso ? s.gg.fatte : [] };
  },

  // ------------------------------------------------------------ avanzamento
  // Obiettivi che dipendono dallo stato del personaggio: Via, destriero, livello, luogo raggiunto.
  controllaMissioni(p) {
    const s = p.ch.mis;
    if (!s || p.dead) return;
    let zona = null;
    for (const [id, a] of Object.entries(s.att)) {
      const def = MISSIONI[id];
      def.ob.forEach((o, i) => {
        if (!STATO_OB.includes(o.tipo) || a.p[i] >= (o.n || 1)) return;
        let fatto = false;
        if (o.tipo === 'via') fatto = !!p.ch.via;
        else if (o.tipo === 'destriero') fatto = !!p.ch.horse;
        else if (o.tipo === 'livello') fatto = p.lvl >= o.n;
        else if (o.tipo === 'luogo') { zona = zona || zonaMissione(p.x, p.z); fatto = zona === o.zona; }
        if (fatto) this.segnaObiettivo(p, id, i, o.n || 1);
      });
    }
    if (p.misDirty) { p.misDirty = false; this.mandaMissioni(p); }
  },

  // Porta l'obiettivo i della missione id al valore v (non oltre n) e avvisa.
  segnaObiettivo(p, id, i, v) {
    const a = p.ch.mis.att[id], def = MISSIONI[id], o = def.ob[i], n = o.n || 1;
    const prima = a.p[i];
    a.p[i] = Math.min(n, Math.max(prima, v));
    if (a.p[i] === prima) return;
    if (this.missioneCompleta(def, a)) {
      const dove = def.giornaliera ? NPC_ROLES.scrivano.name : NPC_ROLES[def.a].name;
      this.send(p, { t: 'mis_ev', k: 'pronta', id, ti: def.titolo, m: `«${def.titolo}» completata: torna da ${dove}.` });
    } else {
      this.send(p, { t: 'mis_ev', k: 'avanza', id, ti: def.titolo, m: `${o.testo}: ${a.p[i]}/${n}` });
    }
    p.misDirty = true;
  },

  missioneCompleta(def, a) { return def.ob.every((o, i) => a.p[i] >= (o.n || 1)); },

  // Aggiunge `quanto` agli obiettivi che `filtro(o)` accetta, in tutte le missioni aperte.
  avanzaMissioni(p, filtro, quanto = 1) {
    const s = p.ch.mis;
    if (!s) return;
    for (const [id, a] of Object.entries(s.att)) {
      MISSIONI[id].ob.forEach((o, i) => {
        if (a.p[i] < (o.n || 1) && filtro(o)) this.segnaObiettivo(p, id, i, a.p[i] + quanto);
      });
    }
    if (p.misDirty) { p.misDirty = false; this.mandaMissioni(p); }
  },

  // Morte di un mostro: conta per chi l'ha colpito e per i suoi compagni vicini; bottino delle missioni di raccolta.
  missioniMorte(m, killer) {
    const chi = new Set();
    const aggiungi = (q) => { if (q && q.kind === 'player' && q.online && Math.hypot(q.x - m.x, q.z - m.z) <= RAGGIO_GRUPPO) chi.add(q); };
    for (const pid of m.aggro.keys()) {
      const q = this.ents.get(pid);
      if (!q || q.kind !== 'player') continue;
      aggiungi(q);
      const party = q.party ? this.parties.get(q.party) : null;
      if (party) for (const id of party.members) aggiungi(this.ents.get(id));
    }
    if (killer && killer.kind === 'player') aggiungi(killer);
    const d = m.d;
    for (const q of chi) {
      if (!q.ch.mis) continue;
      this.avanzaMissioni(q, (o) => (o.tipo === 'uccidi' && o.mob.includes(m.type)) ||
        (o.tipo === 'obelisco' && d.stone && (!o.liv || (d.lvl >= o.liv[0] && d.lvl <= o.liv[1]))));
      if (m.inst) continue;
      // raccolta: finché la missione è aperta i mostri giusti lasciano più spesso l'oggetto cercato
      for (const [id, a] of Object.entries(q.ch.mis.att)) {
        MISSIONI[id].ob.forEach((o, i) => {
          if (o.tipo === 'raccogli' && a.p[i] < o.n && o.mob.includes(m.type) && Math.random() < (o.prob || 0)) {
            this.spawnDrop(o.item, 1, m.x, m.z, q.id);
          }
        });
      }
    }
  },

  missioniRaccolta(p, id, n) {
    this.avanzaMissioni(p, (o) => o.tipo === 'raccogli' && o.item === id, n);
  },

  // Eventi: 'prova' (Prova del Sigillo completata), 'arena' (avversario abbattuto nell'arena).
  missioniEvento(p, tipo) {
    if (!p || p.kind !== 'player') return;
    this.avanzaMissioni(p, (o) => o.tipo === tipo);
  },

  // ------------------------------------------------------------ dialoghi con i PNG
  // Missioni che questo PNG affida (offerte) o riceve (consegne). lontano: il PNG è in una mappa lontana (la Guida
  // affida gli incarichi solo lì, dove non c'è lo Scrivano; nei villaggi apre soltanto i viaggi).
  missioniDelPng(p, ruolo, lontano = false) {
    const s = p.ch.mis, offerte = [], consegne = [];
    if (!s) return { offerte, consegne };
    const def = CATENA[s.cat];
    if (def && def.da === ruolo && !s.att[def.id] && p.lvl >= def.liv) offerte.push(def);
    if (PNG_INCARICHI.includes(ruolo) && s.gg && (ruolo !== 'guida' || lontano)) {
      for (const id of s.gg.scelte) if (MISSIONI[id] && !s.att[id] && !s.gg.fatte.includes(id)) offerte.push(MISSIONI[id]);
    }
    for (const [id, a] of Object.entries(s.att)) {
      const d = MISSIONI[id];
      const qui = d.giornaliera ? PNG_INCARICHI.includes(ruolo) : d.a === ruolo;
      if (qui && this.missioneCompleta(d, a)) consegne.push(d);
    }
    return { offerte, consegne };
  },

  // Clic su un PNG: completa gli obiettivi «parla»; se ha missioni da dare o da ricevere manda il loro dialogo e
  // restituisce true (con `sempre` lo manda comunque, anche vuoto).
  missioniPng(p, n, sempre = false) {
    if (!p.ch.mis) return false;
    this.avanzaMissioni(p, (o) => o.tipo === 'parla' && o.png === n.role);
    const { offerte, consegne } = this.missioniDelPng(p, n.role, !n.kingdom);
    if (!offerte.length && !consegne.length && !sempre) return false;
    const ruolo = NPC_ROLES[n.role] || { name: n.name, title: '' };
    this.send(p, {
      t: 'mis_png', npc: n.id, n: `${ruolo.name} — ${ruolo.title}`,
      offerte: offerte.map((d) => this.voceMissione(p, d, null)),
      consegne: consegne.map((d) => this.voceMissione(p, d, p.ch.mis.att[d.id])),
    });
    return offerte.length > 0 || consegne.length > 0;
  },

  onMissione(p, msg) {
    const s = p.ch.mis;
    if (!s || !msg || p.dead) return;
    const id = String(msg.id || '');
    if (!Object.hasOwn(MISSIONI, id)) return;
    const def = MISSIONI[id];
    if (msg.a === 'abbandona') {
      if (!s.att[id]) return;
      delete s.att[id];
      this.send(p, { t: 'mis_ev', k: 'via', id, ti: def.titolo, m: `Hai abbandonato «${def.titolo}».` });
      return this.mandaMissioni(p);
    }
    const npc = this.nearNpc(p, msg.npc);
    if (!npc) return this.err(p, 'Avvicinati al PNG');
    const { offerte, consegne } = this.missioniDelPng(p, npc.role, !npc.kingdom);
    if (msg.a === 'accetta') {
      if (!offerte.includes(def)) return;
      this.accettaMissione(p, def, false);
    } else if (msg.a === 'consegna') {
      if (!consegne.includes(def)) return;
      if (!this.consegnaMissione(p, def)) return;
    } else return;
    // il dialogo resta aperto se il PNG ha altro da dire (la prossima missione della catena, altri incarichi)
    this.missioniPng(p, npc, true);
  },

  accettaMissione(p, def, sola) {
    const s = p.ch.mis;
    const eq = [];
    for (const e of (def.premio && def.premio.equip) || []) {
      const it = this.premioEquip(p, e.liv, e.slot, e.r || 0);
      if (it) eq.push(it);
    }
    s.att[def.id] = { p: def.ob.map(() => 0), eq };
    this.send(p, { t: 'mis_ev', k: 'nuova', id: def.id, ti: def.titolo, m: `${sola ? 'Nuova missione' : 'Missione accettata'}: «${def.titolo}»`, d: def.testo });
    this.controllaMissioni(p);
    this.mandaMissioni(p);
  },

  // Premio: esperienza, tael, oggetti, equipaggiamento scelto all'accettazione, destriero. false se manca spazio.
  consegnaMissione(p, def) {
    const s = p.ch.mis, a = s.att[def.id], pr = def.premio || {};
    const oggetti = pr.oggetti || [];
    const scrigno = pr.scrigno ? this.scrignoIncarico(p) : null;
    const pezzi = [...(a.eq || []), ...(scrigno && scrigno.inst ? [scrigno.inst] : [])];
    const liberi = p.ch.inv.filter((x) => !x).length;
    if (liberi < pezzi.length + oggetti.filter(([id, n]) => !this.canAdd(p, id, n)).length) {
      this.err(p, "Fai spazio nell'inventario per il premio");
      return false;
    }
    delete s.att[def.id];
    if (def.giornaliera) s.gg.fatte.push(def.id);
    else if (CATENA[s.cat] === def) s.cat++;
    const got = [];
    const exp = Math.round((pr.exp || 0) * expToNext(def.giornaliera ? p.lvl : def.liv) * this.cfg.rates.exp);
    if (pr.tael) { p.ch.tael += pr.tael; got.push(`${migliaia(pr.tael)} tael`); this.send(p, { t: 'gain', tael: pr.tael }); }
    for (const [id, n] of oggetti) {
      const left = this.addItem(p, id, n);
      if (left) this.spawnDrop(id, left, p.x, p.z, p.id);
      got.push(`${ITEMS[id].name}${n > 1 ? ' ×' + n : ''}`);
    }
    if (scrigno && scrigno.id) {
      const left = this.addItem(p, scrigno.id, scrigno.n);
      if (left) this.spawnDrop(scrigno.id, left, p.x, p.z, p.id);
      got.push(`${ITEMS[scrigno.id].name}${scrigno.n > 1 ? ' ×' + scrigno.n : ''}`);
    }
    for (const inst of pezzi) {
      if (this.addItem(p, inst.id, 1, inst.up || 0, inst)) this.dropInstance(inst, p.x, p.z, p.id);
      got.push(`${ITEMS[inst.id].name}${inst.r ? ' (' + RARITIES[inst.r].name + ')' : ''}`);
    }
    if (pr.destriero && !p.ch.horse) {
      p.ch.horse = { lvl: 1, exp: 0 };
      got.push(`un ${HORSE.names[1]} (tasto R per salire in sella)`);
    }
    if (exp > 0) got.unshift(`${migliaia(exp)} esperienza`);
    p.selfDirty = true; p.invDirty = true;
    this.send(p, { t: 'mis_ev', k: 'fatta', id: def.id, ti: def.titolo, m: `Missione compiuta: «${def.titolo}»`, d: def.fine || '', got });
    this.sys(p, `Missione compiuta: «${def.titolo}». Premio: ${got.join(', ')}.`);
    if (exp > 0) this.gainExp(p, exp);   // può far salire di livello (e quindi offrire la missione dopo)
    this.catenaAutomatica(p);
    this.mandaMissioni(p);
    return true;
  },

  // Oggetto in più degli incarichi con `scrigno`: un pezzo della classe (1 volta su 4) o materiali per il fabbro.
  scrignoIncarico(p) {
    if (Math.random() < 0.25) {
      const inst = this.premioEquip(p, p.lvl, null, Math.random() < 0.3 ? 2 : 1);
      if (inst) return { inst };
    }
    if (p.lvl >= 30) return { id: Math.random() < 0.5 ? 'essenza_celeste' : 'frammento_obelisco', n: 1 };
    if (p.lvl >= 18) return { id: Math.random() < 0.5 ? 'frammento_obelisco' : 'pietra_affinamento', n: 1 };
    if (p.lvl >= 8) return { id: Math.random() < 0.5 ? 'minerale_ferro' : 'pietra_affinamento', n: Math.random() < 0.5 ? 2 : 1 };
    return { id: 'ginseng_p', n: 5 };
  },

  // ------------------------------------------------------------ verso il client
  testoPremio(p, def, a) {
    const pr = def.premio || {}, out = [];
    const exp = Math.round((pr.exp || 0) * expToNext(def.giornaliera ? p.lvl : def.liv) * this.cfg.rates.exp);
    if (exp) out.push(`${migliaia(exp)} esperienza`);
    if (pr.tael) out.push(`${migliaia(pr.tael)} tael`);
    for (const [id, n] of pr.oggetti || []) out.push(`${ITEMS[id].name}${n > 1 ? ' ×' + n : ''}`);
    if (a && a.eq) for (const inst of a.eq) out.push(`${ITEMS[inst.id].name}${inst.r ? ' (' + RARITIES[inst.r].name + ')' : ''}`);
    else for (const e of pr.equip || []) out.push(`${{ weapon: 'arma', body: 'armatura', head: 'copricapo', feet: 'calzari' }[e.slot]} del livello ${e.liv}${e.r ? ' (' + RARITIES[e.r].name + ')' : ''} per la tua classe`);
    if (pr.scrigno) out.push('uno scrigno a sorpresa');
    if (pr.destriero && !p.ch.horse) out.push('un Puledro');
    return out.join(' · ');
  },

  // Una missione per il client: titolo, testo, obiettivi con l'avanzamento, premio, dove andare.
  voceMissione(p, def, a) {
    const ob = def.ob.map((o, i) => ({ t: o.testo || o.tipo, p: a ? a.p[i] : 0, n: o.n || 1 }));
    const v = {
      id: def.id, ti: def.titolo, d: def.testo, liv: def.giornaliera ? 0 : def.liv, g: def.giornaliera ? 1 : 0, ob,
      ok: a && this.missioneCompleta(def, a) ? 1 : 0, pr: this.testoPremio(p, def, a),
      a: def.giornaliera ? `${NPC_ROLES.scrivano.name} o ${NPC_ROLES.guida.name}` : NPC_ROLES[def.a].name,
    };
    if (a) v.dove = this.doveMissione(p, def, a);
    return v;
  },

  // Dove andare per la missione: il primo obiettivo da fare, o il PNG a cui consegnarla. { x, z, n } o null.
  doveMissione(p, def, a) {
    if (this.missioneCompleta(def, a)) return this.dovePng(p, def.giornaliera ? PNG_INCARICHI : [def.a]);
    const i = def.ob.findIndex((o, k) => a.p[k] < (o.n || 1));
    const o = def.ob[i];
    switch (o.tipo) {
      case 'uccidi': case 'raccogli': case 'obelisco': {
        const tipi = o.mob || [];
        let best = null, bd = Infinity;
        for (const sp of this.spawners) {
          const ty = (sp.slots || [sp.type]).find((x) => o.tipo === 'obelisco' && !tipi.length ? MOBS[x].stone : tipi.includes(x));
          if (!ty) continue;
          const dd = Math.hypot(sp.x - p.x, sp.z - p.z);
          if (dd < bd) { bd = dd; best = { x: r1(sp.x), z: r1(sp.z), n: MOBS[ty].name }; }
        }
        return best;
      }
      case 'parla': return this.dovePng(p, [o.png]);
      case 'prova': return this.dovePng(p, ['custode']);
      case 'via': return this.dovePng(p, ['maestro']);
      case 'destriero': return this.dovePng(p, ['stalliere']);
      case 'arena': return MAPPE.arena ? { x: MAPPE.arena.cx, z: MAPPE.arena.cz, n: MAPPE.arena.nome } : null;
      case 'luogo': {
        if (MAPPE[o.zona]) { const m = MAPPE[o.zona]; return { x: m.cx + (m.arrivo ? m.arrivo.x : 0), z: m.cz + (m.arrivo ? m.arrivo.z : 0), n: m.nome }; }
        if (o.zona === 'altopiano') return { x: CENTER.x, z: CENTER.z + 60, n: ZONE_MISSIONI.altopiano };
        // Terre di Confine: il tratto fra il proprio villaggio e quello vicino più prossimo al personaggio
        const v = KINGDOMS[p.kingdom].village;
        let best = null, bd = Infinity;
        for (const kid of Object.keys(KINGDOMS)) {
          if (kid === p.kingdom) continue;
          const w = KINGDOMS[kid].village;
          const c = { x: (v.x + w.x) / 2, z: (v.z + w.z) / 2 };
          const fuori = Math.hypot(c.x - CENTER.x, c.z - CENTER.z);
          const pt = { x: CENTER.x + (c.x - CENTER.x) / fuori * 150, z: CENTER.z + (c.z - CENTER.z) / fuori * 150 };
          const dd = Math.hypot(pt.x - p.x, pt.z - p.z);
          if (dd < bd) { bd = dd; best = { x: r1(pt.x), z: r1(pt.z), n: ZONE_MISSIONI.confine }; }
        }
        return best;
      }
    }
    return null;
  },

  // Il PNG di uno di questi ruoli più vicino (del proprio regno, o delle mappe lontane).
  dovePng(p, ruoli) {
    let best = null, bd = Infinity;
    for (const e of this.ents.values()) {
      if (e.kind !== 'npc' || !ruoli.includes(e.role) || (e.kingdom && e.kingdom !== p.kingdom)) continue;
      const dd = Math.hypot(e.x - p.x, e.z - p.z);
      if (dd < bd) { bd = dd; best = { x: r1(e.x), z: r1(e.z), n: e.name, png: e.id }; }
    }
    return best;
  },

  // Stato completo per il client: missioni aperte, segni sopra i PNG, prossima missione della catena, incarichi del giorno.
  mandaMissioni(p) {
    const s = p.ch.mis;
    if (!s) return;
    const a = Object.keys(s.att).map((id) => this.voceMissione(p, MISSIONI[id], s.att[id]));
    // segni: «?» chi ha una consegna, «!» chi ha una missione da dare
    const png = {};
    const ruoli = new Set(['maestro', 'guardia', 'erbe', 'armi', 'fabbro', 'stalliere', 'custode', 'guida', 'scrivano', 'araldo']);
    const lontano = !!mappaAt(p.x, p.z);
    for (const r of ruoli) {
      const { offerte, consegne } = this.missioniDelPng(p, r, lontano);
      if (consegne.length) png[r] = '?';
      else if (offerte.length) png[r] = '!';
    }
    // anche chi va soltanto raggiunto per parlargli
    for (const [id, st] of Object.entries(s.att)) {
      MISSIONI[id].ob.forEach((o, i) => { if (o.tipo === 'parla' && st.p[i] < 1) png[o.png] = '?'; });
    }
    const def = CATENA[s.cat];
    const pross = def && !s.att[def.id] ? { ti: def.titolo, liv: def.liv, da: def.da ? NPC_ROLES[def.da].name : '', ok: p.lvl >= def.liv ? 1 : 0 } : null;
    const gg = s.gg ? { fatte: s.gg.fatte.length, tot: s.gg.scelte.length, libere: s.gg.scelte.filter((id) => !s.att[id] && !s.gg.fatte.includes(id)).length } : null;
    this.send(p, { t: 'mis', a, png, pross, gg, cat: s.cat, tot: CATENA.length });
  },

  // ------------------------------------------------------------ comandi GM per le prove
  comandoMissione(p, a) {
    const s = this.statoMissioni(p);
    const sys = (m) => this.sys(p, m);
    if (a[0] === 'giorno') {
      this.giornoScarto = (this.giornoScarto || 0) + 1;
      for (const q of this.players) { this.giornoMissioni(q); this.mandaMissioni(q); }
      return sys(`Nuovo giorno degli incarichi: ${oggi(this.giornoScarto)}.`);
    }
    if (a[0] === 'fatta') {
      // completa gli obiettivi di tutte le missioni aperte (per provare le consegne)
      for (const [id, st] of Object.entries(s.att)) st.p = MISSIONI[id].ob.map((o) => o.n || 1);
      this.mandaMissioni(p);
      return sys('Obiettivi delle missioni aperte completati.');
    }
    const i = CATENA.findIndex((m) => m.id === a[0]);
    if (i < 0) return sys(`Uso: /missione c01..c${String(CATENA.length).padStart(2, '0')} (la porta lì e la accetta) | fatta | giorno. Catena al passo ${s.cat + 1}/${CATENA.length}.`);
    for (const id of Object.keys(s.att)) if (!MISSIONI[id].giornaliera) delete s.att[id];
    s.cat = i;
    this.accettaMissione(p, CATENA[i], true);   // per le prove: accettata subito, senza andare dal PNG
    return sys(`Catena spostata a «${CATENA[i].titolo}» (livello ${CATENA[i].liv}).`);
  },
};

export function installaMissioni(World) {
  Object.assign(World.prototype, metodi);
}
