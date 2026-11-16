#!/usr/bin/env node
// Misura dei BOSS con meccaniche (boss del mondo e Yan della Forgia), senza browser: un gruppo di bot del livello
// scelto combatte il boss con le rotazioni di `npm run farming` (tools/sim/farming.mjs), beve ginseng sotto il 40% di
// vita, rinasce sul posto dopo 8 s se cade e, con --abili (predefinito), interrompe i lanci del boss con la tecnica
// d'interruzione della sua classe ed esce dai cerchi a terra (o si stringe al boss per gli anelli «vicino»).
// Riporta: boss abbattuto o no, tempo, morti, ginseng, se il boss è entrato in furia.
//
//   node tools/sim/boss.mjs [--boss colosso_ardente] [--vie fulmine,arco,tempesta] [--livello 32] [--velocita 3]
//                           [--goffi] [--ripeti 1] [--porte 3976-3978] [--limite 480]
//
// --goffi: i bot non interrompono e non si spostano (giocatori distratti).  --limite: secondi di gioco prima di arrendersi.
// Obiettivo di taratura: 3 bot del livello del boss lo battono in 2-4 minuti, 2 bot entro la furia, 1 bot no.
import { performance } from 'node:perf_hooks';
import { Bot, avviaServer, usaPorte } from './farming.mjs';
import { MOBS, SKILLS, VIE, BOSS_MONDO } from '../../shared/data.js';
import { MAPPE } from '../../shared/mappe.js';

function opzioni(argv) {
  const o = { boss: 'colosso_ardente', vie: ['fulmine', 'arco', 'tempesta'], livello: 0, velocita: 3, abili: true, ripeti: 1, limite: 0, porte: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    switch (a) {
      case '--boss': o.boss = v(); break;
      case '--vie': o.vie = v().split(',').filter(Boolean); break;
      case '--livello': o.livello = parseInt(v(), 10) || 0; break;
      case '--velocita': o.velocita = Math.max(1, Math.min(6, parseFloat(v()) || 3)); break;
      case '--goffi': o.abili = false; break;
      case '--ripeti': o.ripeti = Math.max(1, parseInt(v(), 10) || 1); break;
      case '--limite': o.limite = parseFloat(v()) || 0; break;
      case '--porte': o.porte = v(); break;
      default: console.error(`Opzione sconosciuta: ${a}`); process.exit(1);
    }
  }
  if (!MOBS[o.boss] || !MOBS[o.boss].mecc) { console.error(`Boss: ${Object.keys(MOBS).filter((k) => MOBS[k].mecc).join(', ')}`); process.exit(1); }
  if (!o.livello) o.livello = BOSS_MONDO[o.boss] ? BOSS_MONDO[o.boss].liv : MOBS[o.boss].lvl;
  if (!o.limite) o.limite = (MOBS[o.boss].mecc.furiaS || 300) + 120;
  return o;
}

function posBoss(id) {
  const b = BOSS_MONDO[id];
  if (!b) return { x: -228, z: -210 };   // boss di una Prova (Yan): nella radura della simulazione, senza la scala della Prova
  return b.luogo === 'mondo' ? { x: b.x, z: b.z } : { x: MAPPE[b.luogo].cx + b.x, z: MAPPE[b.luogo].cz + b.z };
}

// Bot che conosce le meccaniche: interrompe e schiva.
class BotBoss extends Bot {
  constructor(via, opt, porta, k, boss) {
    super(via, 'selva', { ...opt, livello: opt.livello, bonus: 0, minuti: 1 }, porta);
    this.utente = 'boss' + k; this.nome = 'Boss' + k + via.slice(0, 6);
    this.bossTipo = boss; this.abili = opt.abili;
    this.schiva = null; this.morteT = 0;
    this.interr = Object.values(SKILLS).find((s) => s.interrupt && s.cls === VIE[via].cls && !s.via) || null;
    this.lancioBoss = 0;
  }
  ricevi(m) {
    super.ricevi(m);
    if (m.t !== 'fx' || !this.inCorso) return;
    const ora = this.ora();
    if (m.k === 'mcast' && this.mob.get(m.s) && this.mob.get(m.s).ty === this.bossTipo) this.lancioBoss = m.s;
    if (m.k === 'mcastend' && m.s === this.lancioBoss) this.lancioBoss = 0;
    if (m.k === 'warn' && this.abili && this.me && !this.me.dead) {
      const dx = this.pos.x - m.x, dz = this.pos.z - m.z, d = Math.hypot(dx, dz);
      if (m.in) {
        // anello «vicino»: entrare nel cerchio attorno al boss
        if (d > m.r - 1) this.schiva = { x: m.x + dx / (d || 1) * (m.r - 2.5), z: m.z + dz / (d || 1) * (m.r - 2.5), fino: ora + m.ms + 300 };
      } else if (d < m.r + 0.8) {
        const k = (m.r + 2) / (d || 1);
        this.schiva = { x: m.x + (d ? dx : 1) * k, z: m.z + (d ? dz : 0) * k, fino: ora + m.ms + 300 };
      }
    }
  }
  // con la corazza del boss alzata, prima i suoi servitori (Mantici)
  scegliBersaglio(ora) {
    const sc = MOBS[this.bossTipo].mecc.scudo;
    if (sc && this.abili) {
      let best = 0, bd = Infinity;
      for (const [id, q] of this.mob) if (q.ty === sc.add && q.hp > 0) { const d = Math.hypot(q.x - this.pos.x, q.z - this.pos.z); if (d < bd) { bd = d; best = id; } }
      if (best) return best;
    }
    return super.scegliBersaglio(ora);
  }
  passo(dtMs) {
    const ora = this.ora(), me = this.me;
    if (!me) return;
    if (me.dead) {
      // rinascita sul posto dopo 8 s (come un giocatore che non vuole correre dal villaggio)
      if (!this.morteT) this.morteT = ora;
      if (ora - this.morteT > 8200 && ora >= this.rinasciFino) { this.manda({ t: 'respawn', mode: 'here' }); this.rinasciFino = ora + 1000; }
      this.tMorto += dtMs;
      return;
    }
    this.morteT = 0;
    if (this.schiva) {
      if (ora > this.schiva.fino) this.schiva = null;
      else { this.camminaVerso(this.schiva.x, this.schiva.z, ora); return; }
    }
    // interruzione del lancio del boss, appena possibile
    if (this.abili && this.lancioBoss && this.interr && (this.cds[this.interr.id] || 0) <= ora && (this.blocco[this.interr.id] || 0) <= ora) {
      const q = this.mob.get(this.lancioBoss);
      if (q && Math.hypot(q.x - this.pos.x, q.z - this.pos.z) <= (this.interr.range === 'weapon' ? 3 : this.interr.range) + 1) {
        this.lancia(this.interr.id, ora, this.lancioBoss);
        this.lancioBoss = 0;
      }
    }
    super.passo(dtMs);
  }
}

async function prova(opt) {
  const srv = await avviaServer(opt.velocita, { GM_EXTRA: opt.vie.map((_, k) => 'boss' + k).join(',') });
  const bots = opt.vie.map((via, k) => new BotBoss(via, opt, srv.porta, k, opt.boss));
  try {
    for (const b of bots) await b.prepara();
    const pos = posBoss(opt.boss);
    const M = MOBS[opt.boss].mecc;
    const zona = { centro: pos, rmin: 0, rmax: 60, livello: opt.livello, tipi: [opt.boss, ...M.fasi.filter((f) => f.rinforzi).map((f) => f.rinforzi[0]), ...(M.scudo ? [M.scudo.add] : [])] };
    for (const b of bots) { b.zona = zona; b.chat(`/tp ${pos.x.toFixed(1)} ${(pos.z - 14).toFixed(1)}`); }
    await bots[0].dormi(1500);
    bots[0].chat(BOSS_MONDO[opt.boss] ? `/boss ${opt.boss}` : `/spawn ${opt.boss} 1 0.05`);
    await bots[0].attendi('comparsa del boss', () => [...bots[0].mob.values()].some((q) => q.ty === opt.boss));
    for (const b of bots) b.chat('/heal');
    await bots[0].dormi(500);
    const t0 = bots[0].ora();
    for (const b of bots) { b.inCorso = true; b.livelloIniziale = b.me.lvl; }
    let ultimo = t0, esito = null, furia = false;
    const bossVivo = () => [...bots[0].mob.values()].find((q) => q.ty === opt.boss);
    while (!esito) {
      const ora = bots[0].ora();
      for (const b of bots) b.passo(ora - ultimo);
      ultimo = ora;
      for (const b of bots) if (b.chiuso) throw new Error(b.chiuso);
      if (bots.some((b) => b.notizie && b.notizie.some((n) => /FURIA/.test(n)))) furia = true;
      const q = bossVivo();
      if (q && q.hp <= 0) esito = 'abbattuto';
      else if (bots.some((b) => (b.notizie || []).some((n) => /abbattuto/.test(n)))) esito = 'abbattuto';
      else if ((ora - t0) / 1000 > opt.limite) esito = 'resa';
      await bots[0].dormi(15);
    }
    const q = bossVivo();
    return {
      esito, secondi: (bots[0].ora() - t0) / 1000, furia, vitaBoss: q ? Math.round(q.hp / q.mhp * 100) : 0,
      morti: bots.reduce((s, b) => s + b.morti, 0), ginseng: bots.reduce((s, b) => s + b.pozioni, 0),
      subiti: bots.map((b) => Math.round(b.subiti)),
    };
  } finally {
    for (const b of bots) try { b.ws && b.ws.close(); } catch { /* niente */ }
    await new Promise((r) => setTimeout(r, 50));
    srv.chiudi();
  }
}

// gli annunci servono a sapere furia e morte del boss
const ricevi0 = Bot.prototype.ricevi;
Bot.prototype.ricevi = function (m) {
  ricevi0.call(this, m);
  if (m.t === 'notice') (this.notizie = this.notizie || []).push(m.m);
};

const opt = opzioni(process.argv.slice(2));
if (opt.porte) { const [a, b] = opt.porte.split('-').map((x) => parseInt(x, 10)); usaPorte(a, b); }
const t = performance.now();
for (let k = 0; k < opt.ripeti; k++) {
  const r = await prova(opt);
  console.log(`${opt.boss} · ${opt.vie.join('+')} · livello ${opt.livello}${opt.abili ? '' : ' · goffi'}: ${r.esito} in ${r.secondi.toFixed(0)} s` +
    `${r.esito !== 'abbattuto' ? ` (boss al ${r.vitaBoss}%)` : ''} · morti ${r.morti} · ginseng ${r.ginseng} · furia ${r.furia ? 'sì' : 'no'} · danni subiti ${r.subiti.join('/')}`);
}
console.error(`(${((performance.now() - t) / 1000).toFixed(0)} s reali)`);
process.exit(0);
