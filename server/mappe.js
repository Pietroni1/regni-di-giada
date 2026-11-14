// Mappe da esperienza e Arena PvP: logica del server, aggiunta come metodi a World (vedi installaMappe in fondo
// a server/world.js). Definizioni, terreno e confini sono in shared/mappe.js.
import { NPC_ROLES } from '../shared/data.js';
import { KINGDOMS, villageSpawn, mulberry32 } from '../shared/world.js';
import { MAPPE, MAPPE_IDS, mappaAt, limitaMappa, arrivoMappa, portaArena, zonaSicuraMappa } from '../shared/mappe.js';

const RINASCITA_ARENA_MS = 5000;   // nell'arena si rinasce da soli dopo 5 secondi
const CLASSIFICA_RIGHE = 10;

const metodi = {
  // ------------------------------------------------------------ mostri e PNG delle mappe
  initMappe() {
    this.arenaPunti = new Map();   // nome del personaggio → { n, kd, cls, u (uccisioni), m (morti), s (serie), best }
    for (const id of MAPPE_IDS) {
      const m = MAPPE[id];
      if (m.tipo === 'arena') {
        // un Araldo in ogni nicchia d'ingresso, rivolto verso il centro
        for (let i = 0; i < m.porte; i++) {
          const a = portaArena(i), r = m.distNicchia + 3.2;
          const x = m.cx + Math.sin(a) * r + Math.cos(a) * 2.5, z = m.cz + Math.cos(a) * r - Math.sin(a) * 2.5;
          this.add({ kind: 'npc', role: 'araldo', kingdom: '', name: NPC_ROLES.araldo.name, x, z, r: a + Math.PI });
        }
        continue;
      }
      this.add({ kind: 'npc', role: 'guida', kingdom: '', name: NPC_ROLES.guida.name, x: m.cx + m.guida.x, z: m.cz + m.guida.z, r: 0 });
      // branchi in posizioni fisse (seme per mappa), lontani dall'arrivo e un po' distanziati fra loro
      const rng = mulberry32(7000 + m.terreno.seme);
      const presi = [];
      const libero = (x, z, dmin) => presi.every(([px, pz]) => Math.hypot(x - px, z - pz) >= dmin);
      for (const [lx, lz] of m.obelischi.map(o => [o[1], o[2]])) presi.push([lx, lz]);
      for (const [tipo, gruppi, [nmin, nmax], dmin, dmax] of m.branchi) {
        let fatti = 0, tentativi = 0;
        while (fatti < gruppi && tentativi++ < 600) {
          const a = rng() * Math.PI * 2, d = dmin + rng() * (dmax - dmin);
          const lx = m.arrivo.x + Math.sin(a) * d, lz = m.arrivo.z + Math.cos(a) * d;
          if (Math.hypot(lx, lz) > m.raggio - 14 || !libero(lx, lz, nmax >= 8 ? 26 : 17)) continue;
          presi.push([lx, lz]);
          const n = nmin + Math.floor(rng() * (nmax - nmin + 1));
          this.addSpawner(tipo, m.cx + lx, m.cz + lz, n, nmax >= 8 ? 10 : 6);
          fatti++;
        }
      }
      for (const [tipo, lx, lz] of m.obelischi) this.addSpawner(tipo, m.cx + lx, m.cz + lz, 1);
    }
  },

  // ------------------------------------------------------------ chi è dove
  mappaDi(e) { return mappaAt(e.x, e.z); },
  inArena(e) { return !!e && mappaAt(e.x, e.z) === 'arena'; },

  // Al login: chi si era disconnesso in una mappa da esperienza riparte dal suo arrivo (se ha ancora il livello);
  // dall'arena (o da una mappa sconosciuta) si torna al villaggio. Restituisce true se l'ha sistemato.
  rientraInMappa(p) {
    const id = mappaAt(p.x, p.z);
    const m = id && MAPPE[id];
    if (!m || m.tipo !== 'caccia' || p.lvl < m.minLvl) return false;
    const a = arrivoMappa(id);
    p.x = a.x; p.z = a.z;
    return true;
  },

  // Se il punto è in una mappa, lo riporta dentro i suoi confini; altrimenti null.
  limitaPosMappa(x, z) {
    const id = mappaAt(x, z);
    return id ? limitaMappa(id, x, z) : null;
  },

  // ------------------------------------------------------------ ogni tick: entrata e uscita dall'arena, rinascita automatica
  tickMappe(t) {
    for (const p of this.players) {
      const qui = mappaAt(p.x, p.z);
      if (qui !== p.mappa) {
        const prima = p.mappa;
        p.mappa = qui;
        if (qui === 'arena') {
          this.sys(p, `Sei nell'${MAPPE.arena.nome}: qui chiunque può colpirti, tranne i compagni di gruppo. Alle porte sei al sicuro.`);
          this.mandaArena(p);
        } else if (prima === 'arena') this.send(p, { t: 'arena', fuori: 1 });
      }
      if (qui === 'arena' && p.dead && t - p.deadAt >= RINASCITA_ARENA_MS) this.respawn(p, 'arena');
    }
  },

  // ------------------------------------------------------------ PvP dell'arena
  // true/false se la regola dell'arena decide, null se nessuno dei due è nell'arena (valgono le regole normali).
  pvpArena(a, b) {
    const ia = this.inArena(a), ib = this.inArena(b);
    if (!ia && !ib) return null;
    if (!ia || !ib || a.kind !== 'player' || b.dead || a.dead) return false;
    if (a.party && a.party === b.party) return false;
    if (zonaSicuraMappa(a.x, a.z) || zonaSicuraMappa(b.x, b.z)) return false;
    return true;
  },

  // Alleato per cure e sostegno: nell'arena solo i compagni di gruppo, altrove chi è del proprio regno.
  alleato(p, q) {
    if (!q || q.kind !== 'player') return false;
    if (q === p) return true;
    if (this.inArena(p) || this.inArena(q)) return !!p.party && p.party === q.party;
    return q.kingdom === p.kingdom;
  },

  // Morte di un giocatore per mano di un altro dentro l'arena: annuncio e classifica. Restituisce true se gestita.
  uccisioneArena(killer, vittima) {
    if (!this.inArena(vittima)) return false;
    const voce = (q) => {
      let v = this.arenaPunti.get(q.name);
      if (!v) { v = { n: q.name, kd: q.kingdom, cls: q.cls, u: 0, m: 0, s: 0, best: 0 }; this.arenaPunti.set(q.name, v); }
      v.kd = q.kingdom; v.cls = q.cls;
      return v;
    };
    const vv = voce(vittima);
    vv.m++;
    const serieSpezzata = vv.s;
    vv.s = 0;
    let ka = null;
    if (killer && killer.kind === 'player' && killer !== vittima) {
      ka = voce(killer);
      ka.u++; ka.s++; ka.best = Math.max(ka.best, ka.s);
    }
    const nome = (q) => `${q.name} (${KINGDOMS[q.kingdom] ? KINGDOMS[q.kingdom].short : '?'})`;
    let testo = ka ? `${nome(killer)} ha abbattuto ${nome(vittima)}` : `${nome(vittima)} è caduto`;
    if (ka && ka.s >= 3) testo += ` — ${ka.s} di fila!`;
    if (serieSpezzata >= 3) testo += ` (serie di ${serieSpezzata} spezzata)`;
    const msg = { t: 'arena_k', a: ka ? killer.name : '', akd: ka ? killer.kingdom : '', v: vittima.name, vkd: vittima.kingdom, s: ka ? ka.s : 0, m: testo };
    for (const q of this.players) if (this.inArena(q)) { this.send(q, msg); this.mandaArena(q); }
    return true;
  },

  classificaArena() {
    return [...this.arenaPunti.values()]
      .sort((a, b) => b.u - a.u || a.m - b.m || b.best - a.best)
      .slice(0, CLASSIFICA_RIGHE)
      .map(v => ({ n: v.n, kd: v.kd, cls: v.cls, u: v.u, m: v.m, s: v.s, b: v.best }));
  },

  mandaArena(p) {
    const io = this.arenaPunti.get(p.name);
    let n = 0;
    for (const q of this.players) if (this.inArena(q)) n++;
    this.send(p, { t: 'arena', cl: this.classificaArena(), io: io ? { u: io.u, m: io.m, s: io.s, b: io.best } : { u: 0, m: 0, s: 0, b: 0 }, n });
  },

  // Rinascita nell'arena: a una porta a caso, con vita e risorsa piene.
  rinasciInArena(p) {
    const a = arrivoMappa('arena');
    p.x = a.x; p.z = a.z; p.hp = p.maxHp;
    if (p.rtype === 'mana') p.res = p.rmax;
  },

  // ------------------------------------------------------------ viaggi (PNG guida e araldo)
  sendViaggio(p, npc) {
    const gente = {};
    for (const id of MAPPE_IDS) gente[id] = 0;
    for (const q of this.players) { const id = mappaAt(q.x, q.z); if (id) gente[id]++; }
    this.send(p, { t: 'viaggio', npc: npc.id, qui: mappaAt(p.x, p.z) || '', n: gente, tael: p.ch.tael });
  },

  onViaggio(p, msg) {
    const npc = this.nearNpc(p, msg.npc, ['guida', 'araldo']);
    if (!npc) return;
    if (msg.a === 'info') return this.sendViaggio(p, npc);
    if (p.dead) return;
    if (p.inst) return this.err(p, 'Prima finisci la Prova del Sigillo');
    if (msg.a === 'torna') {
      if (!mappaAt(p.x, p.z)) return this.err(p, 'Sei già nelle terre dei regni');
      const s = villageSpawn(p.kingdom);
      this.viaggia(p, s.x, s.z);
      return this.send(p, { t: 'notice', m: `Sei tornato a ${KINGDOMS[p.kingdom].villageName}.` });
    }
    if (msg.a !== 'vai') return;
    const id = String(msg.m || ''), m = MAPPE[id];
    if (!m) return;
    if (mappaAt(p.x, p.z) === id) return this.err(p, 'Sei già qui');
    if (p.lvl < m.minLvl) return this.err(p, `Serve il livello ${m.minLvl}`);
    if (p.ch.tael < m.prezzo) return this.err(p, `Il viaggio costa ${m.prezzo} tael`);
    p.ch.tael -= m.prezzo;
    p.selfDirty = true;
    const a = arrivoMappa(id);
    this.viaggia(p, a.x, a.z);
    const fascia = m.liv ? ` (livelli ${m.liv[0]}-${m.liv[1]})` : '';
    this.send(p, { t: 'notice', m: `${m.nome}${fascia}` });
    if (m.tipo === 'caccia') this.sys(p, `Sei arrivato a ${m.nome}. Lo spiazzo dell'arrivo è sicuro; per tornare parla con ${NPC_ROLES.guida.name}.`);
  },

  // Spostamento lontano: annulla lanci e salite in sella, colonna di luce alla partenza e all'arrivo.
  viaggia(p, x, z) {
    if (p.casting) this.cancelCast(p);
    if (p.mountUntil) { p.mountUntil = 0; this.send(p, { t: 'castend', ok: 0 }); }
    this.fx(p, { k: 'tp', s: p.id });
    p.target = null;
    this.teleport(p, x, z);
    p.lastCombat = 0;
    this.fx(p, { k: 'tp', s: p.id });
  },
};

export function installaMappe(World) {
  Object.assign(World.prototype, metodi);
}
// Per il comando GM /tp selva | distesa | arena
export { MAPPE, arrivoMappa };
