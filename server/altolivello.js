// Contenuto per il livello alto: metodi aggiunti a World (installaAltoLivello in fondo a server/world.js), come
// server/mappe.js e server/missioni.js. Dati e numeri in shared/altolivello.js.
//
//  · Meccaniche dei boss (`mecc` dei mostri): fasi a soglie di vita con rinforzi e furia, lanci interrompibili (riusano
//    m.cast di updateMob: qui si mette `def`, il lancio del boss), cerchi a terra sotto i giocatori con pozze ardenti,
//    anelli attorno al boss (allontanarsi o avvicinarsi), corazza che cade solo abbattendo i servitori, furia a tempo.
//    Valgono per i boss del mondo e per Yan, il boss della Forgia (Prova del Sigillo).
//  · Boss del mondo a tempo (BOSS_MONDO): annunci qualche minuto prima e alla comparsa, segno sulla mappa (messaggio
//    `boss_mondo`), stato durante il combattimento (`boss`), premi personali a chi ha partecipato (presenza o danni).
//  · Arena: stagione settimanale salvata nel database (db.data.arena), punti e onore, negozio dell'Araldo, premi ai primi tre.
//  · Imprese e titoli (ch.imp, ch.impFatte, ch.titoli, ch.titolo): il titolo compare sopra il nome (`ti` nelle info).
//
// Messaggi al client: boss_mondo, boss, boss_premi, onori, imprese, impresa. Dal client: { t: 'alto', a: 'titolo' | 'compra'
// | 'imprese' | 'onori', ... }. Comandi: /titolo [id]; GM: /boss, /onore, /stagione, /impresa.
import { MOBS, ITEMS, RARITIES, GEM_TYPES, expToNext, trialScale, BOSS_MONDO, BOSS_IDS, PREMI_BOSS, FURIA, ARENA, NEGOZIO_ONORE, TITOLI, IMPRESE } from '../shared/data.js';
import { MAPPE } from '../shared/mappe.js';
import { KINGDOMS } from '../shared/world.js';
import { settimana, fineSettimana } from '../shared/altolivello.js';
import { makeEquip, rollRarity } from './world.js';

const NOW = () => Date.now();
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(a + Math.random() * (b - a + 1));
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const r1 = (v) => Math.round(v * 10) / 10;
const RAGGIO_AVVISI = 80;      // chi è entro questa distanza dal boss riceve annunci di fase e stato
const STATO_MS = 500;
const RIPOSO_MS = 8000;        // senza combattere per 8 s, le meccaniche ripartono da capo al prossimo ingaggio
const migliaia = (n) => Math.round(n).toLocaleString('it-IT');

// Posizione nel mondo di un boss del mondo.
export function posBoss(id) {
  const b = BOSS_MONDO[id];
  if (b.luogo === 'mondo') return { x: b.x, z: b.z };
  const m = MAPPE[b.luogo];
  return { x: m.cx + b.x, z: m.cz + b.z };
}
// I branchi del mondo aperto stanno lontani dalle arene dei boss (usata da initSpawns).
export function radureBoss(x, z) {
  for (const id of BOSS_IDS) if (BOSS_MONDO[id].luogo === 'mondo' && Math.hypot(x - BOSS_MONDO[id].x, z - BOSS_MONDO[id].z) < 42) return true;
  return false;
}

const metodi = {
  initAltoLivello() {
    this.pozze = [];          // pozze ardenti a terra: { x, z, r, fino, dmg, src, inst, next }
    this.altoTimer = [];      // colpi ritardati delle meccaniche: { at, fn }
    this.bossStato = {};      // id del boss del mondo → { prossimo, avvisi, mob, comparso }
    this.arenaRecenti = new Map();   // «uccisore>vittima» → istanti delle uccisioni (niente accordi fra amici)
    this._altoT = 0;
    const t = NOW();
    for (const id of BOSS_IDS) {
      const b = BOSS_MONDO[id];
      this.bossStato[id] = { prossimo: t + rand(b.primaMin[0], b.primaMin[1]) * 60000, avvisi: new Set(), mob: 0, comparso: 0 };
    }
    const D = this.db.data || (this.db.data = {});
    if (!D.arena) D.arena = { sett: settimana(), cl: {}, campioni: [], storico: [] };
  },

  tickAltoLivello(t) {
    if (this.altoTimer.length) {
      const pronti = this.altoTimer.filter(x => x.at <= t);
      if (pronti.length) { this.altoTimer = this.altoTimer.filter(x => x.at > t); for (const x of pronti) x.fn(); }
    }
    if (this.pozze.length) this.tickPozze(t);
    if (t - this._altoT < 1000) return;
    this._altoT = t;
    this.tickBossMondo(t);
    if (settimana(t) !== this.db.data.arena.sett) this.chiudiStagione();
  },

  // ------------------------------------------------------------ chi subisce e chi ascolta
  // Giocatori che le meccaniche del boss colpiscono: i membri della Prova, oppure chi è vicino nel mondo.
  bersagliBoss(m, raggio = 45) {
    if (m.inst) { const inst = this.instances.get(m.inst); return inst ? this.instMembers(inst).filter(q => !q.dead) : []; }
    return [...this.players].filter(q => this.validMobTarget(q) && dist(q, m) < raggio);
  },
  ascoltatoriBoss(m) {
    if (m.inst) { const inst = this.instances.get(m.inst); return inst ? this.instMembers(inst) : []; }
    return [...this.players].filter(q => dist(q, m) < RAGGIO_AVVISI);
  },
  avvisoBoss(m, testo) { for (const q of this.ascoltatoriBoss(m)) this.send(q, { t: 'notice', m: testo }); },

  // ------------------------------------------------------------ meccaniche dei boss
  bossMecc(m, t) {
    const d = m.d, M = d.mecc;
    let mc = m.mc;
    if (!mc || t - mc.ultimo > RIPOSO_MS) {
      // primo ingaggio (o ripresa dopo un ritorno a riposo): tutto da capo
      if (mc) { m.atk = mc.atkBase; m.aspdMul = 1; m.riduzione = 0; }
      mc = m.mc = {
        atkBase: mc ? mc.atkBase : m.atk, fase: 0, ingaggio: t, ultimo: t, statoT: 0, partT: t, part: mc ? mc.part : new Map(),
        pronto: (M.lanci || []).map((l, i) => t + 6000 + i * 5000), prossZona: t + 8000, prossAnello: t + 16000, alterna: 0,
        zoneOgni: 0, furia: false, furiaT: 0, scudo: null, scudoFatto: false,
      };
      this.avvisoBoss(m, `${d.name}: ${M.fasi[0].nome}!`);
    }
    mc.ultimo = t;
    // presenza: chi combatte vicino al boss (anche chi cura) conta per i premi
    if (t - mc.partT >= 1000) {
      mc.partT = t;
      for (const q of this.players) if (!q.dead && dist(q, m) < PREMI_BOSS.raggio && t - q.lastCombat < 8000) mc.part.set(q.name, (mc.part.get(q.name) || 0) + 1);
    }
    // fasi a soglie di vita
    const pct = m.hp / m.maxHp;
    while (mc.fase + 1 < M.fasi.length && pct < M.fasi[mc.fase + 1].sotto) {
      mc.fase++;
      this.faseBoss(m, M.fasi[mc.fase], t);
    }
    if (M.scudo && !mc.scudoFatto && pct < M.scudo.sotto) this.alzaScudo(m, M.scudo, t);
    if (mc.scudo) this.controllaScudo(m, t);
    // furia a tempo: il limite oltre il quale un boss non si batte più
    if (M.furiaS && !mc.furia && t - mc.ingaggio > M.furiaS * 1000) {
      mc.furia = true; mc.furiaT = t;
      m.atk = Math.round(m.atk * FURIA.atk); m.aspdMul = Math.min(m.aspdMul || 1, FURIA.aspd);
      this.avvisoBoss(m, `${d.name} è in FURIA: abbattetelo subito o ritiratevi!`);
    }
    if (mc.furia && t - mc.furiaT >= FURIA.ogniMs) {
      mc.furiaT = t;
      this.fx(m, { k: 'slam', s: m.id, x: r1(m.x), z: r1(m.z), r: 12 });
      for (const q of this.bersagliBoss(m, FURIA.raggio)) {
        this.hit(m, q, mc.atkBase * FURIA.mult, {});
        q.antiCura = FURIA.antiCura; q.antiCuraUntil = t + FURIA.antiCuraS * 1000;
      }
    }
    // lanci interrompibili (si parte solo se non è stordito: lo stordimento li spezza)
    if (M.lanci && !m.cast && m.stunUntil <= t) {
      for (let i = 0; i < M.lanci.length; i++) {
        if (t < mc.pronto[i]) continue;
        const l = M.lanci[i];
        mc.pronto[i] = t + l.cd;
        for (let k = 0; k < mc.pronto.length; k++) mc.pronto[k] = Math.max(mc.pronto[k], t + l.ms + 3000);   // mai due lanci attaccati
        m.cast = { until: t + l.ms, tid: m.target, def: l };
        this.fx(m, { k: 'mcast', s: m.id, n: l.name, ms: l.ms, r: l.raggio || 0 });
        if (l.raggio) this.avvisoBoss(m, `${d.name} prepara ${l.name}: interrompetelo o allontanatevi!`);
        break;
      }
    }
    // cerchi a terra sotto i giocatori
    if (M.zone && t >= mc.prossZona) {
      const Z = M.zone;
      mc.prossZona = t + (mc.zoneOgni || Z.ogni);
      for (const q of this.bersagliBoss(m)) this.zonaBoss(m, q.x, q.z, Z, t);
    }
    // anello attorno al boss
    if (M.anello && t >= mc.prossAnello) {
      const A = M.anello;
      mc.prossAnello = t + A.ogni;
      const tipo = A.tipo === 'alterna' ? (mc.alterna++ % 2 ? 'vicino' : 'lontano') : A.tipo;
      this.fx(m, { k: 'warn', x: r1(m.x), z: r1(m.z), r: A.raggio, ms: A.ms, in: tipo === 'vicino' ? 1 : 0 });
      this.avvisoBoss(m, tipo === 'vicino' ? `${A.name}: stringetevi a ${d.name}!` : `${A.name}: allontanatevi da ${d.name}!`);
      this.altoTimer.push({ at: t + A.ms, fn: () => {
        if (m.hp <= 0 || !this.ents.has(m.id)) return;
        this.fx(m, { k: 'slam', s: m.id, x: r1(m.x), z: r1(m.z), r: tipo === 'vicino' ? 30 : A.raggio, in: tipo === 'vicino' ? A.raggio : 0 });
        for (const q of this.bersagliBoss(m)) {
          const dd = dist(q, m);
          if (tipo === 'lontano' ? dd < A.raggio : dd > A.raggio) this.hit(m, q, mc.atkBase * A.mult, {});
        }
      } });
    }
    if (t - mc.statoT >= STATO_MS) { mc.statoT = t; this.statoBoss(m); }
  },

  faseBoss(m, f, t) {
    const mc = m.mc;
    this.fx(m, { k: 'wave', s: m.id });
    this.avvisoBoss(m, f.dice || `${m.d.name}: ${f.nome}`);
    if (f.zoneOgni) mc.zoneOgni = f.zoneOgni;
    if (f.furia) { m.atk = Math.round(mc.atkBase * f.furia.atk * (mc.furia ? FURIA.atk : 1)); m.aspdMul = Math.min(m.aspdMul || 1, f.furia.aspd); }
    if (f.rinforzi) {
      const [tipo, n] = f.rinforzi;
      const bers = this.bersagliBoss(m);
      for (let i = 0; i < n; i++) {
        const a = Math.PI * 2 * i / n + Math.random() * 0.6;
        const s = this.rinforzoBoss(m, tipo, m.x + Math.cos(a) * 7, m.z + Math.sin(a) * 7);
        const q = bers.length ? bers[i % bers.length] : null;
        if (q) { s.target = q.id; s.aggro.set(q.id, 1); }
      }
    }
  },

  rinforzoBoss(m, tipo, x, z) {
    if (m.inst) {
      const inst = this.instances.get(m.inst);
      if (inst) return this.spawnTrialMob(inst, tipo, x, z, trialScale(inst.kl, inst.players));
    }
    return this.spawnMob(tipo, x, z, null, true);
  },

  zonaBoss(m, x, z, Z, t) {
    this.fx(m, { k: 'warn', x: r1(x), z: r1(z), r: Z.raggio, ms: Z.ms });
    this.altoTimer.push({ at: t + Z.ms, fn: () => {
      if (m.hp <= 0 || !this.ents.has(m.id)) return;
      this.fx(m, { k: 'slam', x: r1(x), z: r1(z), r: Z.raggio });
      for (const q of this.bersagliBoss(m, 60)) if (Math.hypot(q.x - x, q.z - z) < Z.raggio) this.hit(m, q, m.mc.atkBase * Z.mult, {});
      if (Z.pozza) this.nuovaPozza(m, x, z, Z.raggio * 0.9, Z.pozza.s, m.mc.atkBase * Z.pozza.mult);
    } });
  },

  nuovaPozza(m, x, z, r, s, dmg) {
    const t = NOW();
    this.pozze.push({ x, z, r, fino: t + s * 1000, dmg, src: m.id, inst: m.inst || 0, next: t + 500 });
    this.fx(m, { k: 'hazard', x: r1(x), z: r1(z), r, ms: s * 1000 });
  },

  // Dopo un lancio con `pozze` (anche se arrivato a segno): pozze ardenti attorno al boss.
  pozzeLancio(m, c) {
    if (!m.mc) return;
    for (let i = 0; i < 4; i++) {
      const a = Math.random() * Math.PI * 2, r = (c.raggio || 8) * rand(0.35, 0.8);
      this.nuovaPozza(m, m.x + Math.cos(a) * r, m.z + Math.sin(a) * r, 3, 6, m.mc.atkBase * 0.3);
    }
  },

  tickPozze(t) {
    this.pozze = this.pozze.filter(z => z.fino > t);
    for (const z of this.pozze) {
      if (t < z.next) continue;
      z.next += 1000;
      const src = this.ents.get(z.src) || { kind: 'env', id: 0, name: 'Pozza ardente', x: z.x, z: z.z };
      const lista = z.inst ? (this.instances.get(z.inst) ? this.instMembers(this.instances.get(z.inst)) : []) : this.players;
      for (const q of lista) {
        if (q.dead || !this.validMobTarget(q) || Math.hypot(q.x - z.x, q.z - z.z) > z.r) continue;
        const v = this.mitigate(q, this.calcDamage(z.dmg, q.def, 1), src).dmg;
        this.fx(q, { k: 'hit', s: src.id || 0, d: q.id, v, dot: 1, sk: 'pozza' });
        this.applyDamage(q, v, src);
      }
    }
  },

  // Corazza: danni ridotti finché i servitori sono in piedi; quando cadono il boss resta Squilibrato.
  alzaScudo(m, S, t) {
    const mc = m.mc;
    mc.scudoFatto = true;
    m.riduzione = S.rid;
    mc.scudo = [];
    for (let i = 0; i < S.n; i++) {
      const a = Math.PI * 2 * i / S.n + 0.4;
      const s = this.rinforzoBoss(m, S.add, m.x + Math.cos(a) * S.distanza, m.z + Math.sin(a) * S.distanza);
      s.r = a + Math.PI;
      mc.scudo.push(s.id);
    }
    this.fx(m, { k: 'wave', s: m.id });
    this.avvisoBoss(m, `${S.name}: ${m.d.name} subisce pochissimi danni finché i servitori sono in piedi!`);
  },
  controllaScudo(m, t) {
    const mc = m.mc;
    const vivi = mc.scudo.filter(id => { const s = this.ents.get(id); return s && s.hp > 0; });
    if (vivi.length) return;
    mc.scudo = null;
    m.riduzione = 0;
    this.avvisoBoss(m, `La ${m.d.mecc.scudo.name} va in pezzi: ${m.d.name} barcolla!`);
    if (m.postMax) { m.squilUntil = 0; this.colpisciPostura(m, m.post + 1); }
  },

  statoBoss(m) {
    const mc = m.mc, M = m.d.mecc;
    const msg = {
      t: 'boss', id: m.id, ty: m.type, n: m.name, hp: Math.round(m.hp), mhp: m.maxHp, f: mc ? mc.fase : 0,
      sc: mc && mc.scudo ? mc.scudo.filter(id => { const s = this.ents.get(id); return s && s.hp > 0; }).length : 0,
      fu: mc && mc.furia ? 1 : 0, fuS: mc && M.furiaS && !mc.furia ? Math.max(0, Math.round(M.furiaS - (NOW() - mc.ingaggio) / 1000)) : -1,
      mondo: m.d.mondo ? 1 : 0,
    };
    for (const q of this.ascoltatoriBoss(m)) this.send(q, msg);
  },

  // ------------------------------------------------------------ boss del mondo a tempo
  tickBossMondo(t) {
    for (const id of BOSS_IDS) {
      const S = this.bossStato[id], b = BOSS_MONDO[id];
      if (S.mob) {
        const m = this.ents.get(S.mob);
        if (!m || m.hp <= 0) { if (!m) this.riprogramma(id, t); continue; }
        // nessuno lo ha toccato per un pezzo: torna a dormire
        if (t - S.comparso > b.restaMin * 60000 && t - m.lastActive > 60000 && !m.target) {
          this.fx(m, { k: 'tp', s: m.id });
          this.remove(m);
          this.broadcast({ t: 'notice', m: `${MOBS[id].name} torna a dormire: nessuno lo ha sfidato.` });
          this.riprogramma(id, t);
        }
        continue;
      }
      const mancano = S.prossimo - t;
      for (const minuti of b.avvisi) {
        if (mancano <= minuti * 60000 && mancano > 0 && !S.avvisi.has(minuti)) {
          S.avvisi.add(minuti);
          this.broadcast({ t: 'notice', m: `Fra ${minuti} ${minuti === 1 ? 'minuto' : 'minuti'} ${MOBS[id].name} comparirà: ${b.zona} (livello ${b.liv}).` });
          this.mandaBossMondo();
        }
      }
      if (mancano <= 0) this.compareBoss(id);
    }
  },

  compareBoss(id, x, z) {
    const S = this.bossStato[id], b = BOSS_MONDO[id];
    if (S.mob && this.ents.has(S.mob)) return this.ents.get(S.mob);
    const pos = x === undefined ? posBoss(id) : { x, z };
    const m = this.spawnMob(id, pos.x, pos.z, null, false);
    m.r = Math.PI;
    m.bossMondo = id;
    S.mob = m.id; S.comparso = NOW(); S.avvisi.clear();
    this.fx(m, { k: 'tp', s: m.id });
    this.broadcast({ t: 'notice', m: `${MOBS[id].name} è comparso: ${b.zona}! Serve un gruppo del livello ${b.liv} o più.` });
    this.mandaBossMondo();
    return m;
  },

  riprogramma(id, t) {
    const S = this.bossStato[id], b = BOSS_MONDO[id];
    S.mob = 0; S.comparso = 0; S.avvisi.clear();
    S.prossimo = t + rand(b.ogniMin[0], b.ogniMin[1]) * 60000;
    this.mandaBossMondo();
  },

  elencoBoss() {
    const t = NOW();
    return BOSS_IDS.map(id => {
      const S = this.bossStato[id], b = BOSS_MONDO[id], pos = posBoss(id), m = S.mob ? this.ents.get(S.mob) : null;
      const vivo = !!(m && m.hp > 0);
      return { id, n: MOBS[id].name, zona: b.zona, liv: b.liv, x: r1(m && vivo ? m.x : pos.x), z: r1(m && vivo ? m.z : pos.z), vivo: vivo ? 1 : 0, tra: vivo ? 0 : Math.max(0, S.prossimo - t), hp: vivo ? Math.round(m.hp / m.maxHp * 100) : 100 };
    });
  },
  mandaBossMondo(p) {
    const msg = { t: 'boss_mondo', l: this.elencoBoss() };
    if (p) this.send(p, msg); else this.broadcast(msg);
  },

  // Morte di un boss del mondo (chiamata da mobDie): premi personali a chi ha partecipato.
  bossMondoMorto(m, top) {
    const id = m.type, b = BOSS_MONDO[id], d = m.d;
    let tot = 0;
    for (const v of m.aggro.values()) tot += v;
    const chi = new Set();
    const part = m.mc ? m.mc.part : new Map();
    for (const q of this.players) {
      if (!q.online) continue;
      const quota = tot > 0 ? (m.aggro.get(q.id) || 0) / tot : 0;
      if ((part.get(q.name) || 0) >= PREMI_BOSS.presenzaS || quota >= PREMI_BOSS.quotaDanni) chi.add(q);
    }
    if (top && top.kind === 'player') chi.add(top);
    for (const q of chi) this.premiBoss(q, id, b, d);
    const nomi = [...chi].map(q => q.name);
    this.broadcast({ t: 'notice', m: `${d.name} è stato abbattuto${nomi.length ? ' da ' + (nomi.length > 1 ? nomi.slice(0, -1).join(', ') + ' e ' + nomi[nomi.length - 1] : nomi[0]) : ''}!` });
    this.statoBoss(m);
    if (this.bossStato[id] && this.bossStato[id].mob === m.id) this.riprogramma(id, NOW());
  },

  premiBoss(q, id, b, d) {
    const ch = q.ch, got = [];
    const give = (itemId, n = 1, inst = null) => {
      const left = this.addItem(q, itemId, n, 0, inst);
      if (left) { if (inst) this.dropInstance(inst, q.x, q.z, q.id); else this.spawnDrop(itemId, left, q.x, q.z, q.id); }
    };
    // pezzi della classe, rari o meglio, qualche livello sopra il boss
    for (let i = 0; i < PREMI_BOSS.pezzi; i++) {
      const r = Math.max(2, rollRarity('boss'));
      const it = this.premioEquip(q, Math.min(45, b.liv + 3), null, r);
      if (it) { give(it.id, 1, it); got.push(`${ITEMS[it.id].name} (${RARITIES[r].name})`); }
    }
    // pezzo unico del boss: 25%, garantito dopo qualche uccisione senza
    ch.pieta = ch.pieta || {};
    ch.pieta[id] = (ch.pieta[id] || 0) + 1;
    if (Math.random() < PREMI_BOSS.unicoPct || ch.pieta[id] >= PREMI_BOSS.pietaUnico) {
      ch.pieta[id] = 0;
      const pid = b.pezzi[randi(0, b.pezzi.length - 1)];
      const r = Math.max(2, rollRarity('boss'));
      const it = this.pezzoUnico(pid, r);
      give(pid, 1, it);
      got.push(`${ITEMS[pid].name} (${RARITIES[r].name})`);
      this.broadcast({ t: 'sys', m: `${q.name} ha ottenuto un pezzo unico: ${ITEMS[pid].name}!` });
    }
    give(b.trofeo, 1); got.push(ITEMS[b.trofeo].name);
    const ess = randi(PREMI_BOSS.essenze[0], PREMI_BOSS.essenze[1]);
    give('essenza_celeste', ess); got.push(`Essenza Celeste x${ess}`);
    if (Math.random() < 0.5) {
      const gems = Object.keys(GEM_TYPES), g = `gemma_${gems[randi(0, gems.length - 1)]}_${Math.random() < 0.3 ? 2 : 1}`;
      give(g); got.push(ITEMS[g].name);
    }
    const tael = Math.round(randi(d.tael[0], d.tael[1]) * 0.5 * this.cfg.rates.tael);
    ch.tael += tael; got.push(`${migliaia(tael)} tael`);
    const lontano = q.lvl > b.liv + 12 ? 0.2 : 1;   // chi è molto sopra il boss impara poco
    this.gainExp(q, Math.round(expToNext(q.lvl) * PREMI_BOSS.espPct * lontano));
    q.selfDirty = true;
    this.send(q, { t: 'boss_premi', b: id, n: d.name, got });
    // imprese
    this.imp(q)[id] = (this.imp(q)[id] || 0) + 1;
    this.controllaImprese(q);
  },

  // Un pezzo unico: rarità con i suoi bonus casuali, più i due bonus fissi del boss in testa.
  pezzoUnico(id, r) {
    const it = makeEquip(id, r);
    const fissi = (ITEMS[id].fissi || []).map(x => [...x]);
    it.b = [...fissi, ...it.b.filter(([k]) => !fissi.some(([f]) => f === k))];
    return it;
  },

  // ------------------------------------------------------------ arena: stagione settimanale e onore
  voceArena(q) {
    const cl = this.db.data.arena.cl;
    let v = cl[q.name];
    if (!v) v = cl[q.name] = { n: q.name, kd: q.kingdom, cls: q.cls, p: 0, u: 0, m: 0, b: 0 };
    v.kd = q.kingdom; v.cls = q.cls;
    return v;
  },

  // Chiamata da uccisioneArena (server/mappe.js): punti stagionali, onore, imprese.
  puntiArena(killer, vittima, serie, serieSpezzata) {
    const t = NOW();
    const vv = this.voceArena(vittima);
    vv.m++;
    vv.p = Math.max(0, vv.p - ARENA.morte);
    if (!killer) return;
    const kv = this.voceArena(killer);
    kv.u++;
    kv.b = Math.max(kv.b, serie);
    const chiave = `${killer.name}>${vittima.name}`;
    const prima = (this.arenaRecenti.get(chiave) || []).filter(x => t - x < ARENA.stessoBersaglioMin * 60000);
    prima.push(t);
    this.arenaRecenti.set(chiave, prima);
    let pt = ARENA.uccisione + Math.min(ARENA.serieMax, ARENA.perSerie * Math.max(0, serie - 1)) + (serieSpezzata >= 3 ? ARENA.spezza : 0);
    if (vittima.lvl < killer.lvl - ARENA.dislivello) pt = 2;
    if (prima.length > 2) pt = 0;   // la stessa vittima più di due volte in dieci minuti non vale nulla
    kv.p += pt;
    killer.ch.onore = (killer.ch.onore || 0) + pt;
    if (pt > 0) this.sys(killer, `Arena: +${pt} punti stagionali e d'onore (stagione ${kv.p}, onore ${killer.ch.onore}).`);
    this.imp(killer).arena_u = (this.imp(killer).arena_u || 0) + 1;
    this.controllaImprese(killer);
  },

  classificaStagione(n = ARENA.righe) {
    return Object.values(this.db.data.arena.cl).filter(v => v.p > 0 || v.u > 0)
      .sort((a, b) => b.p - a.p || b.u - a.u || a.m - b.m).slice(0, n)
      .map(v => ({ n: v.n, kd: v.kd, cls: v.cls, p: v.p, u: v.u, m: v.m, b: v.b }));
  },

  mandaOnori(p, npc) {
    const A = this.db.data.arena;
    const tutti = this.classificaStagione(1e9);
    const pos = tutti.findIndex(v => v.n === p.name);
    const io = A.cl[p.name] || { p: 0, u: 0, m: 0, b: 0 };
    const tit = this.titoliDi(p.ch);
    this.send(p, {
      t: 'onori', npc: npc ? npc.id : 0, onore: p.ch.onore || 0, sett: A.sett, fine: Math.max(0, fineSettimana(A.sett) - NOW()),
      cl: tutti.slice(0, ARENA.righe), io: { pos: pos + 1, p: io.p, u: io.u, m: io.m, b: io.b }, campioni: A.campioni || [],
      ultima: (A.storico || []).slice(-1)[0] || null, premi: ARENA.premiSettimana,
      negozio: NEGOZIO_ONORE.map((v, i) => ({ i, id: v.id, n: v.n || 0, tael: v.tael || 0, costo: v.costo, titolo: v.titolo || '', ha: v.titolo && tit.includes(v.titolo) ? 1 : 0 })),
    });
  },

  compraOnore(p, msg) {
    const npc = this.nearNpc(p, msg.npc, ['araldo']);
    if (!npc) return;
    const v = NEGOZIO_ONORE[msg.i | 0];
    if (!v) return;
    const ch = p.ch;
    if ((ch.onore || 0) < v.costo) return this.err(p, `Servono ${v.costo} punti d'onore`);
    if (v.titolo) {
      if (this.titoliDi(ch).includes(v.titolo)) return this.err(p, 'Hai già questo titolo');
      ch.titoli = [...(ch.titoli || []), v.titolo];
      this.sys(p, `Nuovo titolo: «${TITOLI[v.titolo].nome}». Sceglilo dalla finestra delle Imprese (J).`);
    } else if (v.tael) {
      ch.tael += v.tael; p.selfDirty = true;
    } else {
      if (!this.canAdd(p, v.id, v.n)) return this.err(p, 'Inventario pieno');
      this.addItem(p, v.id, v.n);
      this.sys(p, `Hai ricevuto: ${ITEMS[v.id].name}${v.n > 1 ? ' x' + v.n : ''}.`);
    }
    ch.onore -= v.costo;
    p.selfDirty = true;
    this.mandaOnori(p, npc);
  },

  // Fine della settimana: i primi tre ricevono onore, tael e (il primo) il titolo di Campione; la classifica riparte.
  chiudiStagione() {
    const A = this.db.data.arena;
    const top = this.classificaStagione(3);
    const nomi = [];
    top.forEach((v, i) => {
      const premio = ARENA.premiSettimana[i];
      const p = [...this.players].find(q => q.name === v.n);
      const ch = p ? p.ch : Object.values(this.db.data.chars || {}).find(c => c.name === v.n);
      if (!ch) return;
      ch.onore = (ch.onore || 0) + premio.onore;
      ch.tael = (ch.tael || 0) + premio.tael;
      nomi.push(`${i + 1}. ${v.n} (${v.p})`);
      if (p) { p.selfDirty = true; this.sys(p, `Stagione dell'Arena chiusa: sei arrivato ${i + 1}°! +${premio.onore} onore, +${migliaia(premio.tael)} tael.`); }
    });
    A.storico = [...(A.storico || []), { sett: A.sett, top }].slice(-12);
    A.campioni = top.length ? [top[0].n] : [];
    A.sett = settimana();
    A.cl = {};
    this.arenaRecenti.clear();
    // il titolo di Campione passa al nuovo vincitore: chi lo mostrava e non lo è più lo perde
    for (const q of this.players) {
      if (q.ch.titolo && TITOLI[q.ch.titolo] && TITOLI[q.ch.titolo].settimana && !this.titoliDi(q.ch).includes(q.ch.titolo)) { q.ch.titolo = null; q.vis++; this.touch(q); }
      if (A.campioni.includes(q.name)) { q.vis++; this.touch(q); }
    }
    this.broadcast({ t: 'notice', m: nomi.length ? `Stagione dell'Arena chiusa! ${nomi.join(' · ')}` : "Stagione dell'Arena chiusa: nessun combattente in classifica." });
  },

  // ------------------------------------------------------------ imprese e titoli
  imp(q) { return q.ch.imp || (q.ch.imp = {}); },
  titoliDi(ch) {
    const out = [...(ch.titoli || [])];
    if ((this.db.data.arena.campioni || []).includes(ch.name)) out.push('campione_loto');
    return out;
  },
  valoreImpresa(ch, I) {
    const imp = ch.imp || {};
    if (I.tutti) return Math.min(...I.tutti.map(k => imp[k] || 0));
    return imp[I.c] || 0;
  },
  controllaImprese(q) {
    const ch = q.ch;
    ch.impFatte = ch.impFatte || [];
    for (const I of IMPRESE) {
      if (ch.impFatte.includes(I.id) || this.valoreImpresa(ch, I) < I.n) continue;
      ch.impFatte.push(I.id);
      if (I.titolo && !(ch.titoli || []).includes(I.titolo)) ch.titoli = [...(ch.titoli || []), I.titolo];
      const tit = I.titolo ? ` — nuovo titolo «${TITOLI[I.titolo].nome}»` : '';
      this.send(q, { t: 'impresa', id: I.id, n: I.nome, ti: I.titolo ? TITOLI[I.titolo].nome : '' });
      this.send(q, { t: 'notice', m: `Impresa compiuta: ${I.nome}${tit}` });
      this.broadcast({ t: 'sys', m: `${q.name} ha compiuto l'impresa «${I.nome}»!` });
    }
  },
  // Chiamata da completeTrial: Prove completate e sigilli superati in tempo.
  impresaProva(q, prova, kl, inTime) {
    const imp = this.imp(q);
    imp['prova_' + prova] = Math.max(imp['prova_' + prova] || 0, kl);
    imp['fatte_' + prova] = (imp['fatte_' + prova] || 0) + 1;
    if (inTime) imp.sigillo = Math.max(imp.sigillo || 0, kl);
    this.controllaImprese(q);
  },
  mandaImprese(p) {
    const ch = p.ch, fatte = ch.impFatte || [];
    this.send(p, {
      t: 'imprese', tit: ch.titolo || '', onore: ch.onore || 0,
      l: IMPRESE.map(I => ({ id: I.id, n: I.nome, desc: I.desc, v: Math.min(I.n, this.valoreImpresa(ch, I)), max: I.n, fatto: fatte.includes(I.id) ? 1 : 0, ti: I.titolo || '' })),
      titoli: this.titoliDi(ch),
      boss: Object.fromEntries(BOSS_IDS.map(id => [id, (ch.imp || {})[id] || 0])),
    });
  },
  mettiTitolo(p, id) {
    id = String(id || '');
    if (id && !this.titoliDi(p.ch).includes(id)) return this.err(p, 'Non hai questo titolo');
    p.ch.titolo = id || null;
    p.vis++; this.touch(p);
    this.sys(p, id ? `Titolo mostrato: «${TITOLI[id].nome}».` : 'Nessun titolo mostrato.');
    this.mandaImprese(p);
  },

  // ------------------------------------------------------------ ingresso, messaggi, comandi
  altoLivelloEntra(p) {
    const ch = p.ch;
    if (ch.titolo && !this.titoliDi(ch).includes(ch.titolo)) ch.titolo = null;
    this.mandaBossMondo(p);
  },

  onAltoLivello(p, msg) {
    if (!msg) return;
    switch (msg.a) {
      case 'titolo': return this.mettiTitolo(p, msg.id);
      case 'imprese': return this.mandaImprese(p);
      case 'compra': return this.compraOnore(p, msg);
      case 'onori': { const npc = this.nearNpc(p, msg.npc, ['araldo']); return npc ? this.mandaOnori(p, npc) : null; }
      case 'boss': return this.mandaBossMondo(p);
    }
  },

  // true se il comando è stato gestito qui.
  comandoAltoLivello(p, c, a) {
    const sys = (m) => this.sys(p, m);
    if (c === 'titolo') { this.mettiTitolo(p, a[0] || ''); return true; }
    if (!p.gm) return false;
    switch (c) {
      case 'boss': {
        // /boss id [qui | via | tra minuti]   ·   /boss (elenco)
        const id = a[0];
        if (id === 'vita' || id === 'furia') {      // sul boss con meccaniche più vicino (anche nella Forgia)
          let m = null;
          for (const e of this.ents.values()) if (e.kind === 'mob' && e.d.mecc && e.hp > 0 && dist(e, p) < 40 && (!m || dist(e, p) < dist(m, p))) m = e;
          if (!m) { sys('Nessun boss entro 40 metri.'); return true; }
          if (id === 'furia') { if (m.mc) m.mc.ingaggio = NOW() - (m.d.mecc.furiaS || 0) * 1000 - 1; return true; }
          m.hp = Math.max(1, Math.round(m.maxHp * Math.min(1, Math.max(0.001, parseFloat(a[1]) || 0.5))));
          this.touch(m);
          sys(`${m.name}: vita ${m.hp}/${m.maxHp}.`);
          return true;
        }
        if (!id || !Object.hasOwn(BOSS_MONDO, id)) {
          sys(`Boss: ${this.elencoBoss().map(b => `${b.id} (${b.vivo ? 'vivo ' + b.hp + '%' : 'fra ' + Math.round(b.tra / 60000) + ' min'})`).join(', ')}. Uso: /boss id [qui|via|tra minuti]`);
          return true;
        }
        const S = this.bossStato[id];
        const vivo = S.mob ? this.ents.get(S.mob) : null;
        if (a[1] === 'vita' && vivo) {               // per le prove: /boss id vita 0.6 (porta il boss a quella frazione)
          vivo.hp = Math.max(1, Math.round(vivo.maxHp * Math.min(1, Math.max(0.001, parseFloat(a[2]) || 0.5))));
          this.touch(vivo);
          sys(`${MOBS[id].name}: vita ${vivo.hp}/${vivo.maxHp}.`);
          return true;
        }
        if (a[1] === 'furia' && vivo && vivo.mc) {   // per le prove: la furia scatta subito
          vivo.mc.ingaggio = NOW() - (vivo.d.mecc.furiaS || 0) * 1000 - 1;
          return true;
        }
        if (a[1] === 'via') {
          const m = S.mob ? this.ents.get(S.mob) : null;
          if (m) this.remove(m);
          this.riprogramma(id, NOW());
          sys(`${MOBS[id].name} rimosso.`);
        } else if (a[1] === 'tra') {
          const min = Math.max(0, parseFloat(a[2]) || 0);
          const m = S.mob ? this.ents.get(S.mob) : null;
          if (m) this.remove(m);
          S.mob = 0; S.avvisi.clear(); S.prossimo = NOW() + min * 60000;
          this.mandaBossMondo();
          sys(`${MOBS[id].name} comparirà fra ${min} minuti.`);
        } else {
          const m = a[1] === 'qui' ? this.compareBoss(id, p.x + 8, p.z) : this.compareBoss(id);
          sys(`${MOBS[id].name} a ${Math.round(m.x)}, ${Math.round(m.z)}.`);
        }
        return true;
      }
      case 'onore': p.ch.onore = Math.max(0, (p.ch.onore || 0) + (parseInt(a[0], 10) || 0)); sys(`Onore: ${p.ch.onore}.`); return true;
      case 'stagione': {
        if (a[0] === 'chiudi') { this.chiudiStagione(); return true; }
        if (a[0] === 'punti') { const v = this.voceArena(p); v.p += parseInt(a[1], 10) || 0; sys(`Punti stagionali: ${v.p}.`); return true; }
        sys(`Stagione ${this.db.data.arena.sett}: ${this.classificaStagione(5).map(v => `${v.n} ${v.p}`).join(', ') || 'vuota'}. Uso: /stagione chiudi | punti n`);
        return true;
      }
      case 'impresa': {
        const I = IMPRESE.find(x => x.id === a[0]);
        if (!I) { sys(`Imprese: ${IMPRESE.map(x => x.id).join(', ')}`); return true; }
        const imp = this.imp(p);
        for (const k of I.tutti || [I.c]) imp[k] = Math.max(imp[k] || 0, I.n);
        this.controllaImprese(p);
        return true;
      }
    }
    return false;
  },
};

export function installaAltoLivello(World) {
  Object.assign(World.prototype, metodi);
}
export { KINGDOMS };
