// Prove del Sigillo: piante con strade a scelta. Metodi aggiunti a World (installaProve in fondo a server/world.js),
// come server/mappe.js. Le piante (stanze, ali, porte, leve, varianti, pericoli, tesoro) sono in shared/prove.js.
//  - ogni istanza ha la SUA definizione (`inst.dg`): la Prova con la variante della settimana e le porte nello stato
//    attuale; quando una porta si apre la definizione si ricompone e i giocatori ricevono lo stato nuovo;
//  - i muri valgono per tutti: passi dei giocatori (onMove), scatti (arrivoScatto), mostri (cammino per stanze, vista
//    libera per accorgersi e per colpire), nascite e teletrasporti (punto libero più vicino);
//  - leve, Braciere del Ritorno (chi cade rinasce più avanti), trappole a tempo, scrigno del tesoro.
import { trialScale, PROVE } from '../shared/data.js';
import { PIANTE, componiPianta, varianteSettimana, calpestabile, vistaLibera, puntoLibero, grafoStanze, prossimoPasso, saltiStanze } from '../shared/prove.js';

const NOW = () => Date.now();
const r1 = (v) => Math.round(v * 10) / 10;
const RAGGIO_LEVA = 2.6;        // metri: un giocatore vivo così vicino tira la leva
const RAGGIO_SVEGLIA = 30;      // le trappole lavorano solo con un giocatore entro questa distanza
const MARGINE_SERVER = 0.3;     // il client tiene 0,5 m dai muri: il server ne concede 0,3

const metodi = {
  // ------------------------------------------------------------ pianta dell'istanza
  piantaProva(base, v, aperte = {}) {
    const dg = { ...PROVE[base.id], ...componiPianta(base.id, v, aperte) };
    dg.grafo = grafoStanze(dg);
    return dg;
  },

  // Variante con cui si apre una Prova: quella della settimana, o quella forzata dal GM (/pianta n).
  varianteProva(p, id) {
    const n = PIANTE[id].varianti.length;
    if (p && Number.isInteger(p.piantaForzata)) return ((p.piantaForzata % n) + n) % n;
    return varianteSettimana(id);
  },

  // Stato della pianta da mandare ai giocatori: variante, stanze, porte, braciere acceso, scrigno aperto.
  statoPianta(inst) {
    const dg = inst.dg;
    return { v: dg.var, id: dg.variante.id, nome: dg.variante.nome, nota: dg.variante.nota, stanze: dg.stanze, porte: dg.porte, rit: inst.ritorno ? inst.ritorno.id : '', tes: inst.scrigno ? 1 : 0 };
  },

  // Dopo la nascita dei branchi: conta i vivi per branco e arma le trappole.
  preparaProva(inst) {
    const t = NOW();
    inst.aperte = {}; inst.ritorno = null; inst.scrigno = false;
    inst.vivi = new Map();
    inst.trappole = inst.dg.pericoli.map(p => ({ ...p, at: t + 5000 + p.sfasa }));
  },

  // Dove rinasce chi cade nella Prova: all'ultimo Braciere del Ritorno acceso, altrimenti all'ingresso.
  puntoRinascita(inst) {
    const r = inst.ritorno;
    return r ? { x: inst.ox + r.px, z: inst.oz + r.pz } : { x: inst.ox + inst.dg.spawn[0], z: inst.oz + inst.dg.spawn[1] };
  },

  apriPortaProva(inst, pid) {
    if (inst.dg.porte[pid] !== 0) return false;
    inst.aperte[pid] = true;
    const scrigno = inst.dg.scrigno;
    inst.dg = this.piantaProva(inst.dg, inst.dg.var, inst.aperte);
    inst.dg.scrigno = scrigno;
    const porta = PIANTE[inst.dg.id].porte[pid];
    this.instBroadcast(inst, { t: 'notice', m: porta.dice || `${porta.nome}: aperto!` });
    this.sendTrialState(inst);
    return true;
  },

  // Un mostro della Prova è caduto: se era l'ultimo del suo branco, apre la porta o lo scrigno legati al branco.
  provaMostroCaduto(inst, m) {
    if (m.pk == null || !inst.vivi) return;
    const n = (inst.vivi.get(m.pk) || 0) - 1;
    inst.vivi.set(m.pk, n);
    if (n > 0) return;
    const b = inst.dg.packs.find(x => x.id === m.pk);
    if (!b) return;
    if (b.apre) this.apriPortaProva(inst, b.apre);
    if (b.tesoro && !inst.scrigno) {
      inst.scrigno = true; inst.dg.scrigno = true;
      const T = inst.dg.tesoro;
      this.instBroadcast(inst, { t: 'notice', m: (T && T.dice) || 'Lo scrigno si apre: un premio in più alla fine della Prova!' });
      this.sendTrialState(inst);
    }
  },

  // Leve, bracieri e trappole: una volta per giro del mondo.
  tickProva(inst, t) {
    if (inst.done || !inst.trappole) return;
    const dg = inst.dg;
    const vivi = this.instMembers(inst).filter(q => !q.dead);
    if (!vivi.length) return;
    for (const l of dg.leve) {
      if (dg.porte[l.porta] !== 0) continue;
      if (vivi.some(q => Math.hypot(q.x - inst.ox - l.x, q.z - inst.oz - l.z) < RAGGIO_LEVA)) { this.apriPortaProva(inst, l.porta); return; }
    }
    for (const r of dg.ritorni) {
      if (inst.ritorno && inst.ritorno.id === r.id) continue;
      const [x1, z1, x2, z2] = r.zona;
      if (!vivi.some(q => { const lx = q.x - inst.ox, lz = q.z - inst.oz; return lx >= x1 && lx <= x2 && lz >= z1 && lz <= z2; })) continue;
      inst.ritorno = r;
      this.instBroadcast(inst, { t: 'notice', m: `Il ${r.nome} si accende: chi cade rinasce qui.` });
      this.sendTrialState(inst);
    }
    for (const tr of inst.trappole) {
      if (t < tr.at) continue;
      const x = inst.ox + tr.x, z = inst.oz + tr.z;
      if (!vivi.some(q => Math.hypot(q.x - x, q.z - z) < RAGGIO_SVEGLIA)) { tr.at = t + 1000 + tr.sfasa % 1000; continue; }
      tr.at = t + tr.ogni;
      this.instBroadcast(inst, { t: 'fx', k: 'warn', x: r1(x), z: r1(z), r: tr.r, ms: tr.ms, trap: tr.id });
      const dmg = Math.max(1, Math.round(dg.dannoPericoli * trialScale(inst.kl, inst.players).dmg * tr.mult));
      inst.timers.push({ at: t + tr.ms, fn: () => {
        if (inst.done) return;
        this.instBroadcast(inst, { t: 'fx', k: 'slam', x: r1(x), z: r1(z), r: tr.r, trap: tr.id });
        const env = { kind: 'env', id: 0, name: tr.nome };
        for (const q of this.instMembers(inst)) {
          if (q.dead || Math.hypot(q.x - x, q.z - z) > tr.r) continue;
          this.fx(q, { k: 'hit', s: 0, d: q.id, v: dmg, sk: 'trappola' });
          this.applyDamage(q, dmg, env);
        }
      } });
    }
  },

  // ------------------------------------------------------------ muri per i giocatori
  // Il passo da dove sta a (x, z) è lecito? Dentro le stanze (margine del server) e senza scavalcare muri: fra i due
  // punti ci devono essere al più due varchi (con la rete lenta un passo può girare un angolo).
  passoLecitoProva(p, x, z) {
    const inst = this.instances.get(p.inst);
    if (!inst) return true;
    const dg = inst.dg, lx = x - inst.ox, lz = z - inst.oz, ax = p.x - inst.ox, az = p.z - inst.oz;
    if (!calpestabile(lx, lz, MARGINE_SERVER, dg)) {
      // già fuori (scatto, spinta, porta appena vista aperta dal client): si accetta solo un passo verso il punto libero
      if (calpestabile(ax, az, MARGINE_SERVER, dg)) return false;
      const [fx, fz] = puntoLibero(ax, az, 0.5, dg);
      return Math.hypot(lx - fx, lz - fz) < Math.hypot(ax - fx, az - fz);
    }
    if (!calpestabile(ax, az, 0, dg)) return true;   // rientra da fuori
    return saltiStanze(ax, az, lx, lz, dg, dg.grafo) <= 2;
  },

  // Punto libero più vicino dentro la Prova (coordinate del mondo): teletrasporti, nascite dei mostri.
  liberoProva(inst, x, z, margine = 0.5) {
    const [lx, lz] = puntoLibero(x - inst.ox, z - inst.oz, margine, inst.dg);
    return [lx + inst.ox, lz + inst.oz];
  },

  // Scatto dentro una Prova: si avanza da dove si è verso (x, z) e ci si ferma all'ultimo punto libero prima di un
  // muro, di un vuoto o di un ostacolo (niente salti da una stanza all'altra attraverso le pareti).
  scattoProva(p, inst, x, z) {
    const dg = inst.dg, ax = p.x - inst.ox, az = p.z - inst.oz, bx = x - inst.ox, bz = z - inst.oz;
    const d = Math.hypot(bx - ax, bz - az), n = Math.max(1, Math.ceil(d / 0.4));
    let ux = ax, uz = az;
    for (let i = 1; i <= n; i++) {
      const qx = ax + (bx - ax) * i / n, qz = az + (bz - az) * i / n;
      if (!calpestabile(qx, qz, MARGINE_SERVER, dg)) break;
      ux = qx; uz = qz;
    }
    return [ux + inst.ox, uz + inst.oz];
  },

  // ------------------------------------------------------------ muri per i mostri
  // Verso dove deve camminare un mostro della Prova per raggiungere (tx, tz): il punto stesso se è nella sua stanza,
  // altrimenti il varco verso la stanza successiva. null = non c'è strada (porta chiusa): resta dov'è.
  passoMostroProva(m, tx, tz) {
    const inst = this.instances.get(m.inst);
    if (!inst) return [tx, tz];
    const w = prossimoPasso(m.x - inst.ox, m.z - inst.oz, tx - inst.ox, tz - inst.oz, inst.dg, inst.dg.grafo);
    return w ? [w[0] + inst.ox, w[1] + inst.oz] : null;
  },

  // Dopo un passo: fuori dagli ostacoli (pilastri, sarcofagi, incudini), scivolando attorno.
  fuoriDagliOstacoli(m) {
    const inst = this.instances.get(m.inst);
    if (!inst) return;
    const lx = m.x - inst.ox, lz = m.z - inst.oz;
    for (const [ox, oz, r] of inst.dg.ostacoli) {
      const dx = lx - ox, dz = lz - oz, d = Math.hypot(dx, dz), lim = r + 0.35;
      if (d >= lim) continue;
      const k = d > 0.01 ? lim / d : 0;
      m.x = inst.ox + (d > 0.01 ? ox + dx * k : ox + lim);
      m.z = inst.oz + (d > 0.01 ? oz + dz * k : oz);
      return;
    }
  },

  // Un mostro della Prova vede il bersaglio? (i vuoti lasciano passare vista e colpi a distanza, i muri no)
  vedeProva(m, q) {
    const inst = this.instances.get(m.inst);
    if (!inst) return true;
    return vistaLibera(m.x - inst.ox, m.z - inst.oz, q.x - inst.ox, q.z - inst.oz, inst.dg);
  },

  // Il primo che si accorge di un giocatore chiama i compagni del suo branco (stesso `pk`).
  chiamaBrancoProva(m, p) {
    const inst = this.instances.get(m.inst);
    if (!inst || m.pk == null) return;
    for (const id of inst.mobs) {
      const q = this.ents.get(id);
      if (!q || q === m || q.pk !== m.pk || q.hp <= 0 || q.target) continue;
      q.chiamato = true;
      q.aggro.set(p.id, 1);
      q.target = p.id;
    }
  },

  // Informazioni per la finestra del Custode: la variante della settimana di ogni Prova e le sue strade.
  infoPianta(p, id) {
    const P = PIANTE[id], v = this.varianteProva(p, id), V = P.varianti[v];
    return { v, nome: V.nome, nota: V.nota, ali: Object.entries(P.ali).map(([k, a]) => ({ id: k, n: a.nome, c: a.colore, nota: a.nota })) };
  },
};

export function installaProve(World) {
  Object.assign(World.prototype, metodi);
}
