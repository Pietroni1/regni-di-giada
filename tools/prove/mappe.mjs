// Prova delle mappe da esperienza e dell'arena con bot WebSocket (shared/mappe.js, server/mappe.js).
// Avvia da sé un server con un database temporaneo, poi: viaggio verso Selva e Distesa, mostri e obelisco, ritorno,
// confini, rientro dopo una disconnessione; nell'arena due personaggi dello stesso regno, zona sicura, uccisione,
// annuncio, classifica, rinascita, gruppo, uscita dall'Araldo. Uso: node tools/prove/mappe.mjs [porta]  (predefinita 4101)
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

import os from 'node:os';
import { fileURLToPath } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PORTA = parseInt(process.argv[2] || '4101', 10);
const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter } = await import(path.join(RADICE, 'server/world.js'));
const { MAPPE } = await import(path.join(RADICE, 'shared/mappe.js'));
const { MOBS } = await import(path.join(RADICE, 'shared/data.js'));

const DBF = path.join(os.tmpdir(), `regni-prova-mappe-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
db.createAccount('admin', 'prova');
db.createAccount('sfidante', 'prova');
const a = newCharacter('Provalama', 'lama', 'fenice', 'm'); a.lvl = 40; a.tael = 100000;
db.createChar('admin', a);
const b = newCharacter('Sfidante', 'ombra', 'fenice', 'f'); b.lvl = 40; b.tael = 100000; b.exp = 5000;
db.createChar('sfidante', b);
db.save();

const attesa = (ms) => new Promise(r => setTimeout(r, ms));
let srv;
async function avvia() {
  srv = spawn(process.execPath, [path.join(RADICE, 'server/index.js')], { cwd: RADICE, env: { ...process.env, PORT: String(PORTA), DB_FILE: DBF }, stdio: ['ignore', 'pipe', 'pipe'] });
  let err = '';
  srv.stderr.on('data', d => { err += d; process.stderr.write(d); });
  await new Promise((ok, no) => {
    srv.stdout.on('data', d => { if (String(d).includes('server avviato')) ok(); });
    srv.on('exit', c => no(new Error('server chiuso ' + c + err)));
  });
}

class Bot {
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; }
  async entra() {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise(ok => this.ws.on('open', ok));
    this.ws.on('message', raw => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta(m => m.t === 'chars');
    this.manda({ t: 'play', id: ch.list ? ch.list[0].id : ch.chars[0].id });
    const e = await this.aspetta(m => m.t === 'enter');
    this.id = e.id; this.x = e.x; this.z = e.z;
    return e;
  }
  ricevi(m) {
    this.log.push(m);
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; e.hp = u[4]; e.dead = u[7]; } }
      for (const id of m.r) this.ents.delete(id);
    }
    if (m.t === 'pos') { this.x = m.x; this.z = m.z; }
    if (m.t === 'me') this.me = m;
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 5000) {
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta`)); } }, ms);
    });
  }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  async cmd(c) { this.manda({ t: 'chat', m: c }); await attesa(250); }
  async cammina(x, z) {
    for (let i = 0; i < 400; i++) {
      const dx = x - this.x, dz = z - this.z, d = Math.hypot(dx, dz);
      if (d < 0.5) return;
      const s = Math.min(0.7, d);
      this.x += dx / d * s; this.z += dz / d * s;
      this.manda({ t: 'move', x: this.x, z: this.z, r: 0 });
      await attesa(100);
    }
  }
  vicino(f) {
    let best = null, bd = 1e9;
    for (const e of this.ents.values()) if (f(e)) { const d = Math.hypot(e.x - this.x, e.z - this.z); if (d < bd) { bd = d; best = e; } }
    return best;
  }
  chiudi() { this.ws.close(); }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${testo}`); };

async function main() {
  await avvia();
  const A = new Bot('admin');
  await A.entra();
  await attesa(400);
  // --- guida del villaggio
  let g = A.vicino(e => e.k === 'n' && e.role === 'guida');
  verifica(g, `guida nel villaggio della Fenice: ${g && g.n} a ${g && [g.x, g.z]}`);
  await A.cmd(`/tp ${g.x} ${g.z + 2}`);
  A.manda({ t: 'npc', id: g.id });
  let vg = await A.aspetta(m => m.t === 'viaggio');
  verifica(vg.qui === '' && vg.n, `finestra viaggio dal villaggio: ${JSON.stringify(vg)}`);
  // livello troppo basso? (Provalama è 40: va bene); prima prova il requisito con /level 20
  await A.cmd('/level 20');
  A.manda({ t: 'viaggio', npc: g.id, a: 'vai', m: 'selva' });
  const er = await A.aspetta(m => m.t === 'err');
  verifica(/livello 28/.test(er.m), `requisito di livello: «${er.m}»`);
  await A.cmd('/level 40');
  const tael0 = A.me.tael;
  A.manda({ t: 'viaggio', npc: g.id, a: 'vai', m: 'selva' });
  await A.aspetta(m => m.t === 'pos');
  await attesa(600);
  verifica(Math.hypot(A.x - 6000, A.z + 138) < 4, `arrivo nella Selva: ${A.x}, ${A.z}`);
  verifica(A.me.tael === tael0 - MAPPE.selva.prezzo, `prezzo pagato: ${tael0} → ${A.me.tael}`);
  const tipiVisti = new Set([...A.ents.values()].filter(e => e.k === 'm').map(e => e.ty));
  verifica(tipiVisti.size > 0, `mostri visibili dall'arrivo della Selva: ${[...tipiVisti].join(', ')}`);
  // zona sicura: nessun mostro vicino all'arrivo
  const piuVicino = A.vicino(e => e.k === 'm');
  verifica(piuVicino && Math.hypot(piuVicino.x - A.x, piuVicino.z - A.z) > 20, `mostro più vicino all'arrivo a ${piuVicino && Math.hypot(piuVicino.x - A.x, piuVicino.z - A.z).toFixed(1)} m`);
  // uccidi un lupo
  const lupo = A.vicino(e => e.k === 'm' && e.ty === 'lupo_canne');
  await A.cmd(`/tp ${lupo.x} ${lupo.z + 3}`);
  await attesa(300);
  const expPrima = A.me.exp;
  A.manda({ t: 'chat', m: '/uccidi' });
  const gain = await A.aspetta(m => m.t === 'gain' && m.exp);
  verifica(gain.exp > 0, `ucciso un mostro della Selva: +${gain.exp} esperienza (prima ${expPrima})`);
  // obelisco: colpi base finché arriva un'ondata
  await A.cmd('/tp 5928 -12');
  await attesa(500);
  const ob = A.vicino(e => e.k === 'm' && e.ty === 'obelisco_canne');
  verifica(ob, `obelisco nella Selva: ${ob && ob.n} (${ob && ob.hp} vita)`);
  await A.cmd(`/tp ${ob.x} ${ob.z + 3}`);
  await A.cmd('/item spada_gru 1 15 4');
  const inv = A.log.filter(m => m.t === 'inv').pop();
  const idx = inv.inv.findIndex(s => s && s.id === 'spada_gru');
  A.manda({ t: 'use', i: idx });
  await A.cmd('/level 99');
  await attesa(300);
  let ondata = null;
  const tOnd = A.aspetta(m => m.t === 'fx' && m.k === 'wave' && m.s === ob.id, 40000).then(m => { ondata = m; }).catch(() => {});
  for (let i = 0; i < 400 && !ondata; i++) { A.manda({ t: 'atk', id: ob.id }); await attesa(100); }
  await tOnd.catch(() => {});
  await attesa(300);
  const obe = A.ents.get(ob.id);
  const evocati = [...A.ents.values()].filter(e => e.k === 'm' && Math.hypot(e.x - ob.x, e.z - ob.z) < 8 && e.id !== ob.id && !MAPPE.selva.obelischi.some(o => o[0] === e.ty));
  verifica(ondata, `obelisco attivato: ondata a ${obe && obe.hp} vita, ${evocati.length} mostri evocati (${[...new Set(evocati.map(e => e.ty))].join(', ')})`);
  // torna al villaggio con la guida della Selva
  await A.cmd('/tp selva');
  await attesa(400);
  g = A.vicino(e => e.k === 'n' && e.role === 'guida');
  A.manda({ t: 'npc', id: g.id });
  vg = await A.aspetta(m => m.t === 'viaggio');
  verifica(vg.qui === 'selva', `finestra viaggio nella Selva: qui=${vg.qui}, gente=${JSON.stringify(vg.n)}`);
  A.manda({ t: 'viaggio', npc: g.id, a: 'torna' });
  await A.aspetta(m => m.t === 'pos');
  verifica(Math.hypot(A.x - 0, A.z + 195) < 40, `ritorno al Borgo delle Braci: ${A.x}, ${A.z}`);
  // Distesa
  await attesa(300);
  g = A.vicino(e => e.k === 'n' && e.role === 'guida');
  await A.cmd(`/tp ${g.x} ${g.z + 2}`);
  A.manda({ t: 'viaggio', npc: g.id, a: 'vai', m: 'distesa' });
  await A.aspetta(m => m.t === 'pos');
  await attesa(600);
  verifica(Math.hypot(A.x - 7000, A.z + 150) < 4, `arrivo nella Distesa: ${A.x}, ${A.z}`);
  const tipiD = new Set([...A.ents.values()].filter(e => e.k === 'm').map(e => e.ty));
  verifica(tipiD.size > 0, `mostri visibili dall'arrivo della Distesa: ${[...tipiD].join(', ')}`);
  await A.cmd('/level 45');
  const sc = A.vicino(e => e.k === 'm' && !MOBS[e.ty].stone);
  await A.cmd(`/tp ${sc.x} ${sc.z + 3}`);
  await attesa(300);
  A.manda({ t: 'chat', m: '/uccidi' });
  const gain2 = await A.aspetta(m => m.t === 'gain' && m.exp);
  verifica(gain2.exp > 0, `ucciso ${MOBS[sc.ty].name} (liv. ${MOBS[sc.ty].lvl}) nella Distesa: +${gain2.exp} esperienza`);
  // confini: un passo oltre il cerchio viene fermato
  await A.cmd('/tp 7000 165');
  await attesa(200);
  for (let i = 0; i < 20; i++) { A.z += 0.7; A.manda({ t: 'move', x: A.x, z: A.z, r: 0 }); await attesa(100); }
  A.manda({ t: 'chat', m: '/pos' });
  const pos = await A.aspetta(m => m.t === 'sys' && /Posizione/.test(m.m));
  verifica(/7000, 170/.test(pos.m), `confine della Distesa (raggio 170): ${pos.m}`);
  // disconnessione dentro la Distesa → si rientra all'arrivo
  await A.cmd('/tp 7030 20');
  await attesa(300);
  A.chiudi();
  await attesa(600);
  const A2 = new Bot('admin');
  const e2 = await A2.entra();
  verifica(Math.hypot(e2.x - 7000, e2.z + 150) < 4, `rientro dopo disconnessione nella Distesa: ${e2.x}, ${e2.z}`);

  // --- Arena
  await A2.cmd('/level 40');
  await A2.cmd('/tp fenice');
  await attesa(400);
  const B = new Bot('sfidante');
  await B.entra();
  await attesa(400);
  const gb = B.vicino(e => e.k === 'n' && e.role === 'guida');
  await B.cammina(gb.x - 2, gb.z);
  B.manda({ t: 'npc', id: gb.id });
  await B.aspetta(m => m.t === 'viaggio');
  B.manda({ t: 'viaggio', npc: gb.id, a: 'vai', m: 'arena' });
  await B.aspetta(m => m.t === 'pos');
  const arB = await B.aspetta(m => m.t === 'arena');
  verifica(Math.hypot(B.x - 8000, B.z) > 58, `Sfidante nell'arena, a una porta: ${B.x}, ${B.z}; classifica: ${JSON.stringify(arB)}`);
  const ga = A2.vicino(e => e.k === 'n' && e.role === 'guida');
  await A2.cmd(`/tp ${ga.x} ${ga.z + 2}`);
  A2.manda({ t: 'viaggio', npc: ga.id, a: 'vai', m: 'arena' });
  await A2.aspetta(m => m.t === 'pos');
  await A2.aspetta(m => m.t === 'arena');
  // nella zona sicura della porta non si colpisce
  await A2.cmd(`/tp ${B.x + 1} ${B.z}`);
  await attesa(400);
  const hpB0 = B.me.hp;
  for (let i = 0; i < 15; i++) { A2.manda({ t: 'atk', id: B.id }); await attesa(100); }
  await attesa(300);
  verifica(B.me.hp === hpB0, `alla porta (zona sicura) nessun danno: vita ${hpB0} → ${B.me.hp}`);
  // B scende nell'arena; A lo segue e lo colpisce (stesso regno)
  const ang = Math.atan2(B.x - 8000, B.z);
  await B.cammina(8000 + Math.sin(ang) * 40, Math.cos(ang) * 40);
  await A2.cmd(`/tp ${B.x + 1.5} ${B.z}`);
  await attesa(300);
  const expB0 = B.me.exp;
  let morteB = null;
  const tMorte = B.aspetta(m => m.t === 'dead', 30000).then(m => { morteB = m; }).catch(() => {});
  const tAnnuncio = A2.aspetta(m => m.t === 'arena_k', 30000);
  for (let i = 0; i < 200 && !morteB; i++) { A2.manda({ t: 'atk', id: B.id }); await attesa(100); }
  await tMorte.catch(() => {});
  verifica(morteB && morteB.lost === 0, `stesso regno nell'arena: Sfidante abbattuto da ${morteB && morteB.by}, esperienza persa ${morteB && morteB.lost}`);
  const ann = await tAnnuncio;
  verifica(ann.a === 'Provalama' && ann.v === 'Sfidante', `annuncio dell'arena: «${ann.m}»`);
  await attesa(200);
  const cl = A2.log.filter(m => m.t === 'arena' && m.cl).pop();
  verifica(cl.cl[0].n === 'Provalama' && cl.cl[0].u === 1 && cl.cl.find(r => r.n === 'Sfidante').m === 1, `classifica aggiornata: ${JSON.stringify(cl.cl)}`);
  const rin = await B.aspetta(m => m.t === 'pos' && m.alive, 9000);
  await attesa(300);
  verifica(Math.hypot(rin.x - 8000, rin.z) > 58 && B.me.hp === B.me.mhp && B.me.exp === expB0, `rinascita automatica a una porta: ${rin.x}, ${rin.z}, vita ${B.me.hp}/${B.me.mhp}, esperienza ${expB0} → ${B.me.exp}`);
  // gruppo: i compagni non si colpiscono
  A2.manda({ t: 'pinv', id: B.id });
  await B.aspetta(m => m.t === 'pinv');
  B.manda({ t: 'preply', ok: 1 });
  await A2.aspetta(m => m.t === 'party' && m.members && m.members.length === 2);
  await B.cammina(8000 + Math.sin(ang) * 40, Math.cos(ang) * 40);
  await A2.cmd(`/tp ${B.x + 1.5} ${B.z}`);
  await attesa(300);
  const hpB1 = B.me.hp;
  const errori = A2.log.length;
  for (let i = 0; i < 15; i++) { A2.manda({ t: 'atk', id: B.id }); await attesa(100); }
  await attesa(300);
  verifica(B.me.hp === hpB1, `compagni di gruppo nell'arena: nessun danno (vita ${hpB1} → ${B.me.hp})`);
  // B torna al villaggio dall'araldo
  const ar = B.vicino(e => e.k === 'n' && e.role === 'araldo');
  await B.cmd('/pos');
  const dAr = Math.hypot(ar.x - B.x, ar.z - B.z);
  // cammina verso l'araldo passando dal centro della porta più vicina
  const angAr = Math.atan2(ar.x - 8000, ar.z);
  await B.cammina(8000 + Math.sin(angAr) * 50, Math.cos(angAr) * 50);
  await B.cammina(8000 + Math.sin(angAr) * 66, Math.cos(angAr) * 66);
  await B.cammina(ar.x - Math.sin(angAr) * 2, ar.z - Math.cos(angAr) * 2);
  B.manda({ t: 'npc', id: ar.id });
  const vb = await B.aspetta(m => m.t === 'viaggio');
  B.manda({ t: 'viaggio', npc: ar.id, a: 'torna' });
  await B.aspetta(m => m.t === 'pos');
  const fuori = await B.aspetta(m => m.t === 'arena' && m.fuori);
  verifica(vb.qui === 'arena' && fuori && B.x < 300, `uscita dall'arena dall'Araldo (distante ${dAr.toFixed(1)} m all'inizio): ${B.x}, ${B.z}`);
  // fuori dall'arena lo stesso regno non si colpisce più
  await A2.cmd('/tp fenice');
  await attesa(300);
  await A2.cmd(`/tp ${B.x + 60} ${B.z + 60}`);
  // disconnessione dentro l'arena → villaggio
  A2.chiudi();
  B.chiudi();
  await attesa(500);
  const A3 = new Bot('admin');
  await A3.entra();
  await A3.cmd('/tp arena');
  A3.chiudi();
  await attesa(600);
  const A4 = new Bot('admin');
  const e4 = await A4.entra();
  verifica(Math.hypot(e4.x - 0, e4.z + 195) < 40, `rientro dopo disconnessione nell'arena: al villaggio (${e4.x}, ${e4.z})`);
  // la simulazione usa /tp -228 -228 e i fantocci: ancora possibile
  await A4.cmd('/tp -228 -228');
  A4.manda({ t: 'chat', m: '/pos' });
  const p2 = await A4.aspetta(m => m.t === 'sys' && /Posizione/.test(m.m));
  verifica(/-228, -228/.test(p2.m), `/tp -228 -228 come la simulazione: ${p2.m}`);
  A4.chiudi();
}

try { await main(); } catch (e) { console.error('ERRORE', e); esiti.push([false, String(e)]); }
srv.kill('SIGTERM');
await attesa(500);
const ko = esiti.filter(e => !e[0]).length;
console.log(`\n${esiti.length - ko}/${esiti.length} verifiche riuscite`);
process.exit(ko ? 1 : 0);
