// Prova delle tecniche a cavallo con bot WebSocket (shared/data.js: MOUNT_SKILLS; server/world.js: linea, oltre, segue, scia).
// Avvia da sé un server con un database temporaneo; per ogni classe un personaggio di livello 40 sale in sella col destriero
// al 20 e usa le sue quattro tecniche su fantocci: danni, effetti, ricariche, spostamenti; le tecniche alte sono rifiutate
// col destriero di livello basso, a piedi non si usano, quelle delle altre classi neppure.
// Uso: node tools/prove/destriero.mjs [porta]            (predefinita 4103)
//      node tools/prove/destriero.mjs [porta] --misura [--secondi 30] [--velocita 4] [--bersagli 1,5] [--classi lama,ombra]
//           danni al secondo in sella (bot che usa sempre la tecnica pronta con la ricarica più lunga), per tarare.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const PORTA = parseInt(args.find(a => /^\d+$/.test(a)) || '4103', 10);
const opz = (nome, pred) => { const i = args.indexOf('--' + nome); return i >= 0 && args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : pred; };
const MISURA = args.includes('--misura');
const VELOCITA = MISURA ? Math.max(1, Math.min(8, parseFloat(opz('velocita', '4')) || 1)) : 1;
const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter, makeEquip } = await import(path.join(RADICE, 'server/world.js'));
const D = await import(path.join(RADICE, 'shared/data.js'));
const { SKILLS, ITEMS, CLASSES, MOBS, MOUNT_SKILLS, BUFFS, QB_SIZE } = D;

const CLASSI = opz('classi', 'lama,ombra,monaco,mistico').split(',').filter(c => CLASSES[c]);
const tecnicheDi = (cls) => (Array.isArray(MOUNT_SKILLS) ? MOUNT_SKILLS : MOUNT_SKILLS[cls]) || [];
const NOMI = { lama: 'Cavalama', ombra: 'Cavaombra', monaco: 'Cavamonaco', mistico: 'Cavamistico' };
const RADURA = { x: -228, z: -228 };                      // nessun branco entro 50 m (initSpawns)
const CAMPO = { lama: [-24, -24], ombra: [24, -24], monaco: [-24, 24], mistico: [24, 24] };   // un campo di prova per classe

// ------------------------------------------------------------------ database di prova
const DBF = path.join(os.tmpdir(), `regni-prova-destriero-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
db.createAccount('admin', 'prova');
db.createAccount('compagno', 'prova');
function personaggio(utente, nome, cls, f) {
  const c = newCharacter(nome, cls, 'fenice', 'm');
  c.lvl = 40; c.tael = 1000;
  const wt = ITEMS[CLASSES[cls].startWeapon].wt;
  const arma = Object.entries(ITEMS).filter(([, it]) => it.type === 'weapon' && it.wt === wt && it.lvl <= 40 && !it.boss).sort((a, b) => b[1].lvl - a[1].lvl)[0][0];
  c.equip.weapon = makeEquip(arma, 0, 0);
  // punti statistica come un giocatore vero: due su tre al valore primario
  const prim = CLASSES[cls].primary === 'dex' ? 'dex' : CLASSES[cls].primary === 'int' ? 'int' : 'str';
  c.stats[prim] += 78; c.stats.vit += 39;
  c.horse = { lvl: 20, exp: 0 };
  if (f) f(c);
  db.createChar(utente, c);
}
for (const cls of ['lama', 'ombra', 'monaco', 'mistico']) personaggio('admin', NOMI[cls], cls, (c) => {
  // una tecnica a cavallo di prima rimasta sulla barra: al login deve sparire (niente tasti morti)
  if (cls === 'lama') { c.qb[4] = { k: 's', id: 'fendente_corsa' }; c.qb[5] = { k: 's', id: 'carica_destriero' }; }
});
personaggio('compagno', 'Compagno', 'lama');
db.save();

const attesa = (ms) => new Promise(r => setTimeout(r, ms / VELOCITA));
let srv;
async function avvia() {
  const a = [];
  if (VELOCITA !== 1) a.push('--import', pathToFileURL(path.join(RADICE, 'tools/sim/orologio.mjs')).href);
  a.push(path.join(RADICE, 'server/index.js'));
  srv = spawn(process.execPath, a, { cwd: RADICE, env: { ...process.env, PORT: String(PORTA), DB_FILE: DBF, SIM_VELOCITA: String(VELOCITA), GM_ACCOUNTS: 'compagno' }, stdio: ['ignore', 'pipe', 'pipe'] });
  let err = '';
  srv.stderr.on('data', d => { err += d; process.stderr.write(d); });
  await new Promise((ok, no) => {
    srv.stdout.on('data', d => { if (String(d).includes('server avviato')) ok(); });
    srv.on('exit', c => no(new Error('server chiuso ' + c + err)));
  });
}

class Bot {
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; this.gcdA = 0; this.cd = {}; }
  async entra(nome) {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise(ok => this.ws.on('open', ok));
    this.ws.on('message', raw => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta(m => m.t === 'chars');
    const scelto = ch.list.find(c => c.name === nome) || ch.list[0];
    this.manda({ t: 'play', id: scelto.id });
    const e = await this.aspetta(m => m.t === 'enter');
    this.id = e.id; this.x = e.x; this.z = e.z; this.cls = e.cls;
    await this.finche(() => this.me);
    return e;
  }
  ricevi(m) {
    m._t = Date.now();
    this.log.push(m);
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; e.r = u[3]; e.hp = u[4]; e.dead = u[7]; } }
      for (const id of m.r) this.ents.delete(id);
    }
    if (m.t === 'pos') { this.x = m.x; this.z = m.z; }
    if (m.t === 'me') this.me = m;
    if (m.t === 'party') this.party = m.none ? null : m;
    if (m.t === 'cd') { if (m.ms > 0) this.cd[m.s] = Date.now() + m.ms / VELOCITA; if (m.gcd > 0) this.gcdA = Date.now() + m.gcd / VELOCITA; }
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 5000) {
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta`)); } }, ms);
    });
  }
  async finche(f, ms = 5000) {
    const fine = Date.now() + ms;
    while (Date.now() < fine) { const v = f(); if (v) return v; await new Promise(r => setTimeout(r, 25)); }
    return f();
  }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  async cmd(c, ms = 200) { this.manda({ t: 'chat', m: c }); await attesa(ms); }
  async tp(x, z) {
    this.manda({ t: 'chat', m: `/tp ${x.toFixed(2)} ${z.toFixed(2)}` });
    await this.finche(() => Math.hypot(this.x - x, this.z - z) < 0.3, 2000);
    await attesa(120);
  }
  // cammina in linea retta (passi da 0,7 m ogni 100 ms: 7 m/s, meno del galoppo)
  async cammina(x, z, passo = 0.7) {
    for (let i = 0; i < 400; i++) {
      const dx = x - this.x, dz = z - this.z, d = Math.hypot(dx, dz);
      if (d < 0.3) return;
      const s = Math.min(passo, d);
      this.x += dx / d * s; this.z += dz / d * s;
      this.manda({ t: 'move', x: this.x, z: this.z, r: Math.atan2(dx, dz) });
      await attesa(100);
    }
  }
  // fa nascere un mostro in un punto preciso e ne restituisce l'entità
  async piazza(tipo, x, z) {
    const prima = new Set(this.ents.keys());
    await this.tp(x, z);
    this.manda({ t: 'chat', m: `/spawn ${tipo} 1 0.05` });
    const e = await this.finche(() => [...this.ents.values()].find(q => !prima.has(q.id) && q.k === 'm' && Math.hypot(q.x - x, q.z - z) < 1), 3000);
    if (!e) throw new Error(`il mostro ${tipo} non è nato in ${x},${z}`);
    return e;
  }
  async sella(su) {
    if (!!(this.me && this.me.mounted) === su) return;
    this.manda({ t: 'mount' });
    await this.finche(() => !!this.me.mounted === su, 4000);
  }
  // Usa una tecnica e raccoglie ciò che il server risponde nei `ms` successivi.
  async usa(sid, tid, ms = 900) {
    const fuoriGcd = SKILLS[sid] && SKILLS[sid].offgcd;
    if (!fuoriGcd) { const resto = this.gcdA - Date.now(); if (resto > -80) await new Promise(r => setTimeout(r, resto + 80)); }
    const i0 = this.log.length, t0 = Date.now(), res0 = this.me.res;
    this.manda({ t: 'skill', s: sid, id: tid || null });
    await attesa(ms);
    return this.raccolta(sid, i0, t0, res0);
  }
  raccolta(sid, i0, t0, res0) {
    const L = this.log.slice(i0), mio = (m) => m.t === 'fx' && m.k === 'hit' && m.s === this.id && m.sk === sid;
    const colpi = L.filter(m => mio(m) && !m.dot && !m.miss);
    return {
      fx: L.find(m => m.t === 'fx' && m.k === 'sk' && m.sk === sid && m.s === this.id),
      colpi, danni: colpi.reduce((s, m) => s + (m.v || 0), 0), colpiti: new Set(colpi.map(m => m.d)),
      suDi: (id) => colpi.filter(m => m.d === id),
      nelTempo: L.filter(m => mio(m) && m.dot), nelTempoDi: (a) => L.filter(m => m.t === 'fx' && m.k === 'hit' && m.s === this.id && m.dot && m.sk === a),
      cd: L.find(m => m.t === 'cd' && m.s === sid && !m.rid), lancio: L.find(m => m.t === 'cast' && m.s === sid),
      err: L.find(m => m.t === 'err'), rifiuto: L.find(m => m.t === 'skfail' && m.s === sid),
      pos: L.find(m => m.t === 'pos'), marchi: L.filter(m => m.t === 'fx' && m.k === 'marchi' && m.s === this.id), aff: L.filter(m => m.t === 'fx' && m.k === 'aff'), stun: L.filter(m => m.t === 'fx' && m.k === 'stun'),
      durata: colpi.length ? (colpi[colpi.length - 1]._t - t0) * VELOCITA : 0, res0, res1: this.me.res, t0,
    };
  }
  chiudi() { this.ws.close(); }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${testo}`); };
const n1 = (v) => Math.round(v * 10) / 10;

// Fantocci del campo di una classe: bersaglio T a 10 m a est con due vicini, due sulla linea, uno fuori linea, uno lontano.
async function campo(b, cls) {
  const cx = RADURA.x + CAMPO[cls][0], cz = RADURA.z + CAMPO[cls][1];
  const f = {};
  f.T = await b.piazza('fantoccio', cx + 10, cz);
  f.V1 = await b.piazza('fantoccio', cx + 10, cz + 2.2);
  f.V2 = await b.piazza('fantoccio', cx + 10, cz - 2.2);
  f.L1 = await b.piazza('fantoccio', cx + 4, cz + 0.7);
  f.L2 = await b.piazza('fantoccio', cx + 7, cz - 0.7);
  f.F = await b.piazza('fantoccio', cx + 5, cz + 7);        // fuori dalla linea
  f.X = await b.piazza('fantoccio', cx - 13, cz - 9);       // lontano da tutto
  return { cx, cz, f };
}

// Controlli comuni a ogni tecnica: effetto a tutti, ricarica giusta, nessun lancio, nessuna risorsa spesa, secondo uso rifiutato.
async function comuni(b, sid, r, danni = true) {
  const sk = SKILLS[sid];
  verifica(r.fx && r.fx.l === 20 && !r.rifiuto, `${sk.name}: parte (effetto «sk» col livello del destriero ${r.fx && r.fx.l})${r.err ? ' — errore: ' + r.err.m : ''}`);
  if (danni) verifica(r.colpi.length > 0 && r.danni > 0, `${sk.name}: ${r.colpi.length} colpi su ${r.colpiti.size} bersagli, ${r.danni} danni`);
  verifica(r.cd && r.cd.ms === sk.cd * 1000 && !r.lancio && r.res1 >= r.res0, `${sk.name}: ricarica ${r.cd && r.cd.ms / 1000} s, nessun tempo di lancio, risorsa ${r.res0} → ${r.res1}`);
  const r2 = await b.usa(sid, r.fx && r.fx.d, 350);
  verifica(r2.rifiuto && !r2.fx && r2.err && /ricarica/i.test(r2.err.m), `${sk.name}: in ricarica è rifiutata («${r2.err && r2.err.m}»)`);
}

async function provaClasse(cls, C) {
  const b = new Bot('admin');
  await b.entra(NOMI[cls]);
  const tec = tecnicheDi(cls);
  console.log(`\n=== ${CLASSES[cls].name}: ${tec.map(s => SKILLS[s].name).join(' · ')}`);
  if (cls === 'lama') verifica(!b.me.qb.some(q => q && q.k === 's' && (!SKILLS[q.id] || SKILLS[q.id].mount)), `le vecchie tecniche a cavallo spariscono dalla barra al login (${b.me.qb.filter(q => q && q.k === 's').map(q => q.id).join(', ')})`);
  await b.cmd('/destriero 20');
  const { cx, cz, f } = await campo(b, cls);
  await b.tp(cx, cz);
  // --- a piedi
  let r = await b.usa(tec[0], f.T.id, 350);
  verifica(r.rifiuto && !r.fx && r.err && /sella/i.test(r.err.m), `a piedi la tecnica a cavallo è rifiutata («${r.err && r.err.m}»)`);
  // --- destriero di livello basso
  await b.cmd('/destriero 1');
  await b.sella(true);
  verifica(b.me.mounted === 1, 'sale in sella');
  const rif = [];
  for (const sid of tec.slice(1)) { r = await b.usa(sid, f.T.id, 300); rif.push(!!r.rifiuto && !r.fx && r.err && new RegExp('livello ' + SKILLS[sid].hlvl).test(r.err.m)); }
  verifica(rif.every(Boolean), `destriero al livello 1: rifiutate ${tec.slice(1).map(s => `${SKILLS[s].name} (${SKILLS[s].hlvl})`).join(', ')}`);
  await b.cmd(`/destriero ${SKILLS[tec[3]].hlvl - 1}`);
  r = await b.usa(tec[3], f.T.id, 300);
  verifica(r.rifiuto && !r.fx, `destriero al livello ${SKILLS[tec[3]].hlvl - 1}: ${SKILLS[tec[3]].name} ancora rifiutata`);
  const altra = tecnicheDi(cls === 'lama' ? 'ombra' : 'lama')[0];
  r = await b.usa(altra, f.T.id, 300);
  verifica(r.rifiuto && !r.fx, `la tecnica a cavallo di un'altra classe (${SKILLS[altra].name}) è rifiutata`);
  await b.cmd('/destriero 20');
  // --- barra e punti abilità
  b.manda({ t: 'qb', i: QB_SIZE - 3, v: { k: 's', id: tec[0] } });
  b.manda({ t: 'skup', s: tec[0] });
  await attesa(400);
  verifica(!b.me.qb.some(q => q && q.id === tec[0]) && !(tec[0] in b.me.sk), 'le tecniche a cavallo non entrano nella barra rapida a piedi e non prendono punti abilità');
  await C[cls](b, tec, cx, cz, f);
  // --- lo stordimento/rallentamento si vede su un mostro vero (i fantocci non si stordiscono)
  await b.sella(false);
  verifica(b.me.mounted === 0, 'scende da cavallo');
  r = await b.usa(tec[0], f.T.id, 300);
  verifica(r.rifiuto && !r.fx, 'sceso da cavallo, la tecnica è di nuovo rifiutata');
  b.chiudi();
  await attesa(500);
}

const DURO = Object.entries(MOBS).filter(([, d]) => !d.boss && !d.stone && !d.dummy && !d.mecc && !d.cast && !d.waves).sort((a, b) => b[1].hp - a[1].hp)[0][0];
async function mostroVero(b, x, z) {
  const m = await b.piazza(DURO, x, z);
  await b.cmd('/heal', 50);
  return m;
}
async function viaMostro(b) { await b.cmd('/uccidi', 300); await b.cmd('/heal', 50); }

const PROVE = {
  // ---------------------------------------------------------------- Lama
  async lama(b, [falciata, carica, impennata, tuono], cx, cz, f) {
    await b.tp(cx + 8.5, cz);
    let r = await b.usa(falciata);
    verifica([f.T, f.V1, f.V2, f.L2].every(e => r.suDi(e.id).length === 1) && !r.colpiti.has(f.X.id), `Falciata: un colpo a testa sui ${r.colpiti.size} fantocci attorno, non su quello lontano`);
    await comuni(b, falciata, r);
    await b.tp(cx, cz);
    r = await b.usa(carica, f.T.id);
    const fronte = Math.hypot(b.x - f.T.x, b.z - f.T.z);
    verifica(r.pos && fronte < 2.2 && b.x < f.T.x, `Carica Travolgente: arriva davanti al bersaglio (a ${n1(fronte)} m, senza oltrepassarlo)`);
    verifica([f.T, f.L1, f.L2].every(e => r.colpiti.has(e.id)) && !r.colpiti.has(f.F.id) && !r.colpiti.has(f.X.id), `Carica Travolgente: travolge chi sta sulla linea (${r.colpiti.size} colpiti), non chi sta di lato`);
    verifica(r.fx.tx !== undefined && r.fx.fx !== undefined, `Carica Travolgente: l'effetto porta partenza e arrivo (${r.fx.fx},${r.fx.fz} → ${r.fx.tx},${r.fx.tz})`);
    await comuni(b, carica, r);
    await b.tp(cx + 8.5, cz);
    r = await b.usa(impennata);
    verifica(r.colpiti.size >= 4 && !r.colpiti.has(f.X.id), `Impennata di Ferro: schiaccia ${r.colpiti.size} fantocci attorno`);
    await comuni(b, impennata, r);
    await b.tp(cx - 10, cz);
    r = await b.usa(tuono, f.T.id, 1600);
    verifica(r.suDi(f.T.id).length === 3 && r.suDi(f.V1.id).length === 3 && r.durata > 600, `Galoppo del Tuono: da 20 m, tre scariche su bersaglio e vicini (${r.suDi(f.T.id).length}/${r.suDi(f.V1.id).length} colpi in ${Math.round(r.durata)} ms)`);
    verifica(r.suDi(f.L1.id).length >= 1 && !r.colpiti.has(f.X.id) && Math.hypot(b.x - f.T.x, b.z - f.T.z) < 2.2, 'Galoppo del Tuono: travolge chi sta sulla linea e arriva sul bersaglio');
    await comuni(b, tuono, r);
    // stordimenti su un mostro vero
    await b.tp(cx - 14, cz + 12);
    const m = await mostroVero(b, cx - 14, cz + 15);
    await attesa(Math.max(0, b.cd[impennata] - Date.now()) * VELOCITA + 100);
    r = await b.usa(impennata, null, 500);
    verifica(r.stun.some(s => s.d === m.id && s.ms >= 1500), `Impennata di Ferro: stordisce un mostro vero (${r.stun.map(s => s.ms + ' ms').join(', ')})`);
    await viaMostro(b);
  },
  // ---------------------------------------------------------------- Ombra
  async ombra(b, [lame, passaggio, agguato, branco], cx, cz, f) {
    await b.tp(cx, cz);
    let r = await b.usa(lame, f.T.id);
    verifica([f.T, f.V1, f.V2, f.L2].every(e => r.suDi(e.id).length === 1) && !r.pos && !r.colpiti.has(f.L1.id), `Lame al Galoppo: da 10 m una lama sul bersaglio e una su ogni vicino entro 4,5 m, senza muoversi (${r.colpi.length} colpi)`);
    await comuni(b, lame, r);
    verifica(r.marchi.filter(m => m.n >= 1).length >= 4, `Lame al Galoppo: un Marchio su ogni nemico colpito (${r.marchi.length} effetti «marchi»)`);
    r = await b.usa(passaggio, f.T.id, 2600);
    const oltre = b.x - f.T.x;
    verifica(r.pos && oltre > 3.5 && oltre < 6.5 && Math.abs(b.z - f.T.z) < 1.5, `Passaggio Tagliente: attraversa il bersaglio e finisce ${n1(oltre)} m oltre`);
    verifica([f.T, f.L1, f.L2].every(e => r.colpiti.has(e.id)) && !r.colpiti.has(f.F.id), `Passaggio Tagliente: colpisce chi sta lungo la corsa (${r.colpiti.size} colpiti)`);
    const marchiati = new Map(r.marchi.map(m => [m.d, m.n]));
    verifica([...r.colpiti].every(id => (marchiati.get(id) || 0) >= 2), `Passaggio Tagliente: due Marchi su tutti i ${r.colpiti.size} colpiti (effetto «marchi»: ${[...marchiati.values()].join('/')})`);
    await comuni(b, passaggio, r);
    await b.tp(cx, cz);
    r = await b.usa(lame, f.T.id);
    r = await b.usa(agguato, f.T.id);
    const tr = f.T.r || 0, dietro = (b.x - f.T.x) * Math.sin(tr) + (b.z - f.T.z) * Math.cos(tr);
    verifica(r.pos && r.fx.tp === 1 && dietro < -0.8 && Math.hypot(b.x - f.T.x, b.z - f.T.z) < 2.4, `Agguato dal Buio: riappare alle spalle del bersaglio (${n1(dietro)} m lungo il suo sguardo), effetto di teletrasporto`);
    verifica(r.suDi(f.T.id).length === 1 && r.aff.some(a => a.a === '__lento' && a.d === f.T.id), `Agguato dal Buio: un colpo solo sul bersaglio (${r.suDi(f.T.id).map(m => m.v).join('/')}) che resta rallentato`);
    verifica(r.fx.mk >= 3 && r.marchi.some(m => m.d === f.T.id && m.boom >= 3), `Agguato dal Buio: fa esplodere i Marchi del bersaglio (${r.fx.mk})`);
    verifica(r.colpiti.size > 1 && r.marchi.filter(m => m.boom).length > 1, `Agguato dal Buio: i nemici marchiati vicini saltano a catena (${r.colpiti.size} colpiti)`);
    await comuni(b, agguato, r);
    await b.tp(cx - 4, cz);
    r = await b.usa(branco, f.T.id, 2000);
    verifica(r.suDi(f.T.id).length === 4 && r.suDi(f.V1.id).length === 4 && r.durata > 1000 && !r.pos, `Branco d'Ombre: da 14 m quattro sagome una dopo l'altra su bersaglio e vicini (${r.suDi(f.T.id).length}/${r.suDi(f.V1.id).length} in ${Math.round(r.durata)} ms), senza muoversi`);
    await comuni(b, branco, r);
    // le sagome seguono il bersaglio: un mostro vero che corre addosso al cavaliere viene colpito anche lontano da dov'era
    await b.tp(cx - 14, cz + 6);
    const m = await mostroVero(b, cx - 14, cz + 22);
    await attesa(Math.max(0, b.cd[branco] - Date.now()) * VELOCITA + 100);
    await b.usa(lame, m.id, 400);                       // lo si provoca, poi si fugge: il mostro insegue
    const x0 = m.x, z0 = m.z;
    const fuga = b.cammina(cx - 14, cz - 16, 1.1);
    r = await b.usa(branco, m.id, 2000);
    await fuga;
    const e = b.ents.get(m.id), spost = e ? Math.hypot(e.x - x0, e.z - z0) : 0;
    verifica(r.suDi(m.id).length === 4 && spost > SKILLS[branco].radius + 1, `Branco d'Ombre: le sagome inseguono il bersaglio che si sposta (${r.suDi(m.id).length} colpi, si è mosso di ${n1(spost)} m; raggio delle ondate ${SKILLS[branco].radius} m)`);
    await viaMostro(b);
  },
  // ---------------------------------------------------------------- Monaco
  async monaco(b, [onda, zoccoli, balzo, ruota], cx, cz, f) {
    await b.tp(cx, cz);
    let r = await b.usa(onda, f.L2.id);
    verifica([f.L1, f.L2, f.T].every(e => r.suDi(e.id).length === 1) && !r.colpiti.has(f.F.id) && !r.pos, `Onda Ardente: in linea, colpisce chi sta prima del bersaglio, lui e chi sta subito dietro (${r.colpiti.size} colpiti), senza muoversi`);
    verifica(r.fx.tx !== undefined, `Onda Ardente: l'effetto porta la fine della linea (${r.fx.tx},${r.fx.tz})`);
    await comuni(b, onda, r);
    r = await b.usa(balzo, f.T.id);
    verifica([f.T, f.V1, f.V2].every(e => r.colpiti.has(e.id)) && !r.colpiti.has(f.L1.id) && !r.pos, `Balzo della Gru Ardente: da 10 m colpisce la zona del bersaglio (${r.colpiti.size} colpiti); in sella si resta dove si è`);
    await comuni(b, balzo, r);
    await b.tp(cx + 8.5, cz);
    r = await b.usa(ruota, null, 3200);
    verifica([f.T, f.V1, f.V2].every(e => r.suDi(e.id).length === 3) && r.durata > 450, `Ruota del Sole: tre calci su tutti attorno (${r.colpi.length} colpi in ${Math.round(r.durata)} ms)`);
    verifica(r.aff.some(a => a.a === ruota && a.d === f.T.id) && r.nelTempo.length > 0, `Ruota del Sole: i colpiti restano in fiamme («aff» sul nemico, ${r.nelTempo.length} danni nel tempo)`);
    await comuni(b, ruota, r);
    // la scia: si parte a ovest del fantoccio lontano X, lo si supera e ci si allontana; X brucia quando il cavaliere è già lontano
    const X = f.X;
    await b.tp(X.x - 5, X.z);
    const i0 = b.log.length, t0 = Date.now(), res0 = b.me.res;
    b.manda({ t: 'skill', s: zoccoli, id: null });
    await attesa(150);
    await b.cammina(X.x + 14, X.z);
    await attesa(3200);
    r = b.raccolta(zoccoli, i0, t0, res0);
    const colpiX = r.suDi(X.id);
    const lontano = b.log.slice(i0).filter(m => m.t === 'fx' && m.k === 'hit' && m.sk === zoccoli && m.d === X.id && (m._t - t0) * VELOCITA > 2300);
    verifica(colpiX.length >= 3 && lontano.length >= 1, `Zoccoli di Fiamma: il fantoccio sulla scia brucia ${colpiX.length} volte, ${lontano.length} quando il cavaliere è già a più di 9 m`);
    verifica(r.aff.some(a => a.d === X.id && a.a === zoccoli), 'Zoccoli di Fiamma: chi calpesta la scia si vede bruciare («aff» sul nemico)');
    verifica(!r.colpiti.has(f.T.id), 'Zoccoli di Fiamma: chi non è sulla scia non brucia');
    await b.tp(cx, cz);
    await attesa(Math.max(0, b.cd[zoccoli] - Date.now()) * VELOCITA + 100);
    await b.tp(cx + 9, cz);
    r = await b.usa(zoccoli, null, 1200);
    await comuni(b, zoccoli, r);
    // stordimento del Balzo su un mostro vero
    await b.tp(cx - 14, cz + 6);
    const m = await mostroVero(b, cx - 14, cz + 16);
    await attesa(Math.max(0, b.cd[balzo] - Date.now()) * VELOCITA + 100);
    r = await b.usa(balzo, m.id, 500);
    verifica(r.stun.some(s => s.d === m.id), `Balzo della Gru Ardente: stordisce un mostro vero (${r.stun.map(s => s.ms + ' ms').join(', ')})`);
    await viaMostro(b);
  },
  // ---------------------------------------------------------------- Mistico
  async mistico(b, [dardi, velo, cometa, pioggia], cx, cz, f) {
    await b.tp(cx - 5, cz);
    let r = await b.usa(dardi, f.T.id);
    verifica([f.T, f.V1, f.V2].every(e => r.suDi(e.id).length === 1) && !r.colpiti.has(f.L1.id) && !r.pos, `Dardi d'Astri: da 15 m colpiscono il bersaglio e i due vicini (${r.colpi.length} colpi), senza muoversi`);
    await comuni(b, dardi, r);
    r = await b.usa(cometa, f.T.id);
    verifica([f.T, f.V1, f.V2, f.L2].every(e => r.colpiti.has(e.id)) && !r.colpiti.has(f.X.id) && !r.pos, `Cometa: da 15 m esplode su tutta la zona del bersaglio (${r.colpiti.size} colpiti)`);
    await comuni(b, cometa, r);
    // Velo di Stelle: a sé e al compagno di gruppo vicino, non a quello lontano
    const c = new Bot('compagno');
    await c.entra('Compagno');
    await c.tp(cx - 3, cz + 3);
    b.manda({ t: 'pinv', id: c.id });
    await c.aspetta(m => m.t === 'pinv', 3000);
    c.manda({ t: 'preply', ok: 1 });
    await c.finche(() => c.party && c.party.members.some(m => m.id === c.id), 3000);
    const ic = c.log.length;
    r = await b.usa(velo, null, 500);
    const mio = b.me.buffs.find(x => x.b === 'velo_stelle'), suo = c.me.buffs.find(x => x.b === 'velo_stelle');
    verifica(mio && mio.ms > 6000 && r.colpi.length === 0, `Velo di Stelle: effetto su di sé per ${mio && n1(mio.ms / 1000)} s (${BUFFS.velo_stelle.desc})`);
    verifica(suo && c.log.slice(ic).some(m => m.t === 'fx' && m.k === 'sk' && m.sk === velo && m.ally === 1), 'Velo di Stelle: il compagno di gruppo vicino lo riceve (effetto ridotto «ally»)');
    verifica(r.cd && !r.cd.gcd, 'Velo di Stelle: fuori dal tempo globale');
    await comuni(b, velo, r, false);
    await c.tp(cx - 40, cz);
    await attesa(Math.max(0, b.cd[velo] - Date.now()) * VELOCITA + 100);
    await c.finche(() => !c.me.buffs.some(x => x.b === 'velo_stelle'), 3000);
    r = await b.usa(velo, null, 500);
    verifica(r.fx && !c.me.buffs.some(x => x.b === 'velo_stelle'), 'Velo di Stelle: il compagno lontano (oltre 15 m) non lo riceve');
    c.chiudi();
    // Pioggia di Stelle: parte vicino al gruppo e segue il cavaliere fino al fantoccio lontano
    await b.tp(cx + 8.5, cz);
    const i0 = b.log.length, t0 = Date.now(), res0 = b.me.res;
    b.manda({ t: 'skill', s: pioggia, id: null });
    await attesa(700);
    await b.tp(f.X.x + 2, f.X.z);
    await attesa(2600);
    r = b.raccolta(pioggia, i0, t0, res0);
    verifica(r.suDi(f.T.id).length >= 1 && r.suDi(f.X.id).length >= 2 && r.colpi.length >= 6, `Pioggia di Stelle: le stelle seguono il cavaliere (${r.suDi(f.T.id).length} scrosci sul gruppo di partenza, ${r.suDi(f.X.id).length} sul fantoccio raggiunto dopo)`);
    verifica(r.aff.some(a => a.a === '__lento'), 'Pioggia di Stelle: il primo scroscio rallenta');
    await attesa(Math.max(0, b.cd[pioggia] - Date.now()) * VELOCITA + 100);
    await b.tp(cx + 8.5, cz);
    r = await b.usa(pioggia, null, 3200);
    verifica(r.suDi(f.T.id).length === 6 && r.durata > 2200, `Pioggia di Stelle: da fermi sei scrosci in ${Math.round(r.durata)} ms`);
    await comuni(b, pioggia, r);
    // stordimento della Cometa su un mostro vero
    await b.tp(cx - 14, cz + 6);
    const m = await mostroVero(b, cx - 14, cz + 20);
    await attesa(Math.max(0, b.cd[cometa] - Date.now()) * VELOCITA + 100);
    r = await b.usa(cometa, m.id, 500);
    verifica(r.stun.some(s => s.d === m.id), `Cometa: stordisce un mostro vero (${r.stun.map(s => s.ms + ' ms').join(', ')})`);
    await viaMostro(b);
  },
};

// ------------------------------------------------------------------ misura dei danni al secondo in sella
async function misura() {
  const secondi = parseFloat(opz('secondi', '30')), scenari = opz('bersagli', '1,5').split(',').map(Number);
  console.log(`\nDanni al secondo in sella (livello 40, destriero 20, ${secondi} s, orologio ×${VELOCITA}; senza attacchi base)`);
  const righe = [];
  let spot = 0;
  for (const cls of CLASSI) {
    const b = new Bot('admin');
    await b.entra(NOMI[cls]);
    await b.cmd('/destriero 20');
    const tec = tecnicheDi(cls).filter(s => SKILLS[s].mult);
    const riga = { cls };
    for (const n of scenari) {
      const a = spot++ * 1.1, cx = RADURA.x + Math.cos(a) * 30, cz = RADURA.z + Math.sin(a) * 30;
      await b.sella(false);
      await b.tp(cx, cz);
      const prima = new Set(b.ents.keys());
      await b.cmd(`/spawn fantoccio ${n} ${n > 1 ? 3 : 0.05}`, 500);
      const bers = [...b.ents.values()].filter(e => !prima.has(e.id) && e.k === 'm');
      await b.tp(cx + (n > 1 ? 0 : 2), cz);
      await b.sella(true);
      const i0 = b.log.length, t0 = Date.now();
      const per = {};
      while ((Date.now() - t0) * VELOCITA < secondi * 1000) {
        const ora = Date.now();
        const vicino = bers.map(e => [Math.hypot(e.x - b.x, e.z - b.z), e]).sort((p, q) => p[0] - q[0])[0];
        const pronte = tec.filter(s => (b.cd[s] || 0) <= ora && (SKILLS[s].type === 'aoe_self' ? vicino[0] < SKILLS[s].radius : vicino[0] <= (SKILLS[s].range || 0) + 1)).sort((p, q) => SKILLS[q].cd - SKILLS[p].cd);
        if (pronte.length && b.gcdA <= ora) { b.manda({ t: 'skill', s: pronte[0], id: vicino[1].id }); b.gcdA = ora + 300 / VELOCITA; }
        else if (!pronte.length && vicino[0] > 4) await b.cammina(vicino[1].x + 1.5, vicino[1].z, 1.2);
        await new Promise(r => setTimeout(r, 30));
      }
      const dt = (Date.now() - t0) * VELOCITA / 1000;
      let tot = 0;
      for (const m of b.log.slice(i0)) if (m.t === 'fx' && m.k === 'hit' && m.s === b.id && m.sk !== 'auto') { tot += m.v || 0; per[m.sk] = (per[m.sk] || 0) + (m.v || 0); }
      riga[n] = Math.round(tot / dt);
      riga['d' + n] = Object.entries(per).sort((p, q) => q[1] - p[1]).map(([k, v]) => `${SKILLS[k] ? SKILLS[k].name : k} ${Math.round(v / tot * 100)}%`).join(', ');
    }
    riga.atk = Math.max(b.me.atk, b.me.matk);
    righe.push(riga);
    b.chiudi();
    await attesa(400);
  }
  for (const r of righe) {
    console.log(`${CLASSES[r.cls].name.padEnd(8)} attacco ${String(r.atk).padStart(5)}  ` + scenari.map(n => `${n} bers.: ${String(r[n]).padStart(6)} (${n1(r[n] / r.atk)}×)`).join('   '));
    for (const n of scenari) console.log(`           ${n}: ${r['d' + n]}`);
  }
}

async function main() {
  await avvia();
  if (MISURA) await misura();
  else for (const cls of CLASSI) await provaClasse(cls, PROVE);
}

main().catch(e => { console.error(e); esiti.push([false, 'errore: ' + e.message]); }).finally(() => {
  if (srv) srv.kill();
  try { fs.unlinkSync(DBF); } catch {}
  if (!MISURA) {
    const no = esiti.filter(e => !e[0]);
    console.log(`\n${esiti.length - no.length}/${esiti.length} verifiche superate`);
    for (const e of no) console.log('  NO ' + e[1]);
    process.exit(no.length ? 1 : 0);
  }
  process.exit(0);
});
