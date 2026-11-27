// Prova delle piante delle Prove del Sigillo (shared/prove.js, server/prove.js) con un bot WebSocket.
// Per ogni Prova (Cripta, Forgia) e per ogni variante settimanale apre un'istanza (comando GM /pianta n) e verifica:
//  - la pianta mandata con dg_start è quella del server ed è la stessa esportata per il client Godot (gioco.json);
//  - le forze: ogni strada sensata (sale comuni + un'ala + il tesoro, oppure due ali) arriva al 100%;
//  - i muri tengono: passi contro un muro, dentro un'ala chiusa, oltre un cancello chiuso, salti da una stanza
//    all'altra vengono respinti; /tp dentro un muro porta al punto libero più vicino;
//  - ogni strada aperta porta al boss camminando con le regole del client (margine 0,5 m, ostacoli aggirati) senza
//    che il server respinga un solo passo; cancelli e leve si aprono (guardiano abbattuto, leva raggiunta);
//  - i mostri restano dentro le stanze mentre inseguono;
//  - Braciere del Ritorno (si rinasce lì), scrigno del tesoro (un premio in più), Prova completata.
// In testa, senza server: scatti che si fermano ai muri, vista attraverso i vuoti ma non attraverso i muri.
// Uso: node tools/prove/prove_sigillo.mjs [porta] [--solo cripta|forgia] [--varianti 0,2]   (porta predefinita 4104)
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const argv = process.argv.slice(2);
const PORTA = parseInt(argv.find(a => /^\d+$/.test(a)) || '4104', 10);
const opz = (k, def) => { const i = argv.indexOf('--' + k); return i < 0 ? def : argv[i + 1]; };
const SOLO = opz('solo', '');
const VARIANTI = opz('varianti', '') ? String(opz('varianti')).split(',').map(Number) : null;
const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter, World } = await import(path.join(RADICE, 'server/world.js'));
const { PROVE } = await import(path.join(RADICE, 'shared/data.js'));
const { villageFrame, toWorld } = await import(path.join(RADICE, 'shared/world.js'));
const { PIANTE, componiPianta, calpestabile, vistaLibera, grafoStanze, forzePianta } = await import(path.join(RADICE, 'shared/prove.js'));

const DBF = path.join(os.tmpdir(), `regni-prova-sigillo-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
db.createAccount('admin', 'prova');
const a = newCharacter('Provalama', 'lama', 'fenice', 'm'); a.lvl = 45; a.tael = 100000;
db.createChar('admin', a);
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
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; this.dg = null; this.respinti = 0; this.fuori = []; }
  async entra() {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise(ok => this.ws.on('open', ok));
    this.ws.on('message', raw => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta(m => m.t === 'chars');
    this.manda({ t: 'play', id: ch.list[0].id });
    const e = await this.aspetta(m => m.t === 'enter');
    this.id = e.id; this.x = e.x; this.z = e.z;
  }
  ricevi(m) {
    this.log.push(m);
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; e.hp = u[4]; e.dead = u[7]; this.controlla && this.controlla(e); } }
      for (const id of m.r) this.ents.delete(id);
    }
    if (m.t === 'pos') { this.x = m.x; this.z = m.z; if (this.contaRespinti) this.respinti++; }
    if (m.t === 'me') this.me = m;
    if (m.t === 'dg') this.dg = m;
    if (m.t === 'dg_start' || m.t === 'dg_end') { this.ents.clear(); this.dg = null; }
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 6000) {
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta`)); } }, ms);
    });
  }
  forse(f, ms) { return this.aspetta(f, ms).catch(() => null); }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  async cmd(c, ms = 200) { this.manda({ t: 'chat', m: c }); await attesa(ms); }
  async tp(x, z) { const p = this.forse(m => m.t === 'pos', 2000); this.manda({ t: 'chat', m: `/tp ${x} ${z}` }); await p; await attesa(120); }
  vicino(f) {
    let best = null, bd = 1e9;
    for (const e of this.ents.values()) if (f(e)) { const d = Math.hypot(e.x - this.x, e.z - this.z); if (d < bd) { bd = d; best = e; } }
    return best;
  }
  chiudi() { this.ws.close(); }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${String(esiti.length).padStart(2)}. ${testo}`); };

// ------------------------------------------------------------ come cammina il client (cripta.gd: passo)
function passoClient(ax, az, bx, bz, dg) {
  if (calpestabile(bx, bz, 0.5, dg)) return [bx, bz];
  for (const [ox, oz, r] of dg.ostacoli) {
    const lim = r + 0.26, d = Math.hypot(bx - ox, bz - oz);
    if (d < lim && d > 0.001) {
      const q = [ox + (bx - ox) / d * (lim + 0.01), oz + (bz - oz) / d * (lim + 0.01)];
      if (calpestabile(q[0], q[1], 0.5, dg)) return q;
    }
  }
  if (calpestabile(bx, az, 0.5, dg)) return [bx, az];
  if (calpestabile(ax, bz, 0.5, dg)) return [ax, bz];
  return [ax, az];
}

// Cammina fino a (lx, lz) (coordinate locali) con passi da 1,1 m; restituisce true se arriva.
async function cammina(bot, ox, oz, lx, lz, dg, uccidi = true) {
  let fermo = 0;
  for (let i = 0; i < 1500; i++) {
    const ax = bot.x - ox, az = bot.z - oz, dx = lx - ax, dz = lz - az, d = Math.hypot(dx, dz);
    if (d < 0.12) return true;
    const s = Math.min(1.1, d);
    let [nx, nz] = passoClient(ax, az, ax + dx / d * s, az + dz / d * s, dg);
    if (Math.hypot(nx - ax, nz - az) < 0.02) {
      // fermo contro un ostacolo: un passo di lato
      [nx, nz] = passoClient(ax, az, ax + dz / d * 0.9, az - dx / d * 0.9, dg);
      if (++fermo > 12) return false;
    }
    bot.x = nx + ox; bot.z = nz + oz;
    bot.manda({ t: 'move', x: bot.x, z: bot.z, r: 0 });
    await attesa(28);
    if (uccidi && i % 6 === 0 && bot.vicino(e => e.k === 'm' && e.hp > 0 && !e.dead && Math.hypot(e.x - bot.x, e.z - bot.z) < 14)) bot.manda({ t: 'chat', m: '/uccidi' });
    if (i % 25 === 24) bot.manda({ t: 'chat', m: '/vita 100' });   // qui si provano le strade, non la tenuta
  }
  return false;
}

// Strada (elenco di punti locali) dall'ingresso alla sala del boss passando solo per le sale comuni e per l'ala data.
function strada(id, v, ala, daStanza, aStanza) {
  const tutte = {};
  for (const k of Object.keys(PIANTE[id].porte)) tutte[k] = true;
  const dg = componiPianta(id, v, tutte);
  const S = dg.stanze.map(sid => PIANTE[id].stanze.find(s => s.id === sid));
  const g = grafoStanze(dg, 0.35);
  const ok = (s) => !s.ala || s.ala === ala;
  const da = S.findIndex(s => s.id === daStanza), a = S.findIndex(s => s.id === aStanza);
  const prima = new Array(S.length).fill(-2), coda = [da];
  prima[da] = -1;
  while (coda.length) {
    const i = coda.shift();
    if (i === a) break;
    for (const [j] of g[i]) if (prima[j] === -2 && ok(S[j])) { prima[j] = i; coda.push(j); }
  }
  if (prima[a] === -2) return null;
  const stanze = [];
  for (let i = a; i !== -1; i = prima[i]) stanze.unshift(i);
  const punti = [];
  for (let k = 1; k < stanze.length; k++) {
    const varco = g[stanze[k - 1]].find(([j]) => j === stanze[k])[1];
    punti.push({ x: varco[0], z: varco[1], stanza: S[stanze[k]] });
  }
  return { punti, stanze: stanze.map(i => S[i].id), usaAla: stanze.some(i => S[i].ala === ala) };
}

async function apriProva(A, id, v, cu) {
  await A.cmd('/tp fenice', 300);
  await A.tp(cu.x, cu.z + 2);
  await A.cmd(`/pianta ${v}`);
  await A.cmd('/sigillo 2');
  await A.cmd('/vita 100');
  const p = A.aspetta(m => m.t === 'dg_start', 8000);
  A.manda({ t: 'trial', npc: cu.id, a: 'open', p: id });
  const ds = await p;
  await A.aspetta(m => m.t === 'dg', 4000);
  await attesa(300);
  return ds;
}

async function provaVariante(A, id, v, cu, esportate) {
  const P = PIANTE[id], V = P.varianti[v], base = PROVE[id];
  console.log(`\n--- ${base.name}, variante ${v} «${V.nome}»`);
  const attesaPianta = componiPianta(id, v);
  const ds = await apriProva(A, id, v, cu);
  const ox = ds.ox, oz = ds.oz;
  let dg = { ...base, ...componiPianta(id, v, {}) };
  const aggiornaDg = () => { const ap = {}; for (const [k, s] of Object.entries(A.dg.po)) if (s === 1) ap[k] = true; dg = { ...base, ...componiPianta(id, v, ap) }; };

  // 1. la pianta mandata al client
  const pm = ds.pianta;
  verifica(pm && pm.v === v && JSON.stringify(pm.stanze) === JSON.stringify(attesaPianta.stanze) && JSON.stringify(pm.porte) === JSON.stringify(attesaPianta.porte),
    `dg_start porta la pianta del server: variante ${pm && pm.v} «${pm && pm.nome}», ${pm && pm.stanze.length} stanze, porte ${JSON.stringify(pm && pm.porte)}`);
  const ex = esportate[id].composte[v];
  verifica(JSON.stringify(ex.stanze) === JSON.stringify(attesaPianta.stanze) && JSON.stringify(ex.rooms) === JSON.stringify(attesaPianta.rooms) && JSON.stringify(ex.walls) === JSON.stringify(attesaPianta.walls) && JSON.stringify(ex.ostacoli) === JSON.stringify(attesaPianta.ostacoli),
    `la pianta esportata per Godot (gioco.json) coincide: ${ex.rooms.length} stanze calpestabili, ${ex.walls.length} muri, ${ex.ostacoli.length} ostacoli`);

  // 2. le forze per strada
  const tutte = {};
  for (const k of Object.keys(P.porte)) tutte[k] = true;
  const F = forzePianta({ ...base, ...componiPianta(id, v, tutte) });
  const ali = Object.keys(P.ali).filter(k => F[k] && k !== 'ponte');
  const tesoro = (F.tesoro || 0) + (F.ponte || 0);
  // strade sensate: le due ali aperte insieme (senza tesoro), oppure l'ala più ricca più il tesoro
  const strade = ali.map(al => [`sale comuni + ${P.ali[al].nome} + tesoro`, F.tronco + F[al] + tesoro]);
  const insieme = F.tronco + ali.reduce((s, k) => s + F[k], 0);
  verifica(insieme >= base.forcesNeeded && strade.some(([, f]) => f >= base.forcesNeeded) && F.totale >= base.forcesNeeded + 15,
    `forze: totale ${F.totale}% (sale comuni ${F.tronco}%); le ali aperte insieme ${insieme}%; ${strade.map(([n, f]) => `${n} = ${f}%`).join('; ')}`);

  // i mostri: mai fuori dalle stanze mentre il bot gira
  A.fuori = [];
  A.controlla = (e) => { if (e.k === 'm' && e.hp > 0 && !e.dead && !calpestabile(e.x - ox, e.z - oz, -0.05, { rooms: dg.rooms })) A.fuori.push([e.ty, Math.round(e.x - ox), Math.round(e.z - oz)]); };

  // 3. i muri tengono
  const sp = dg.spawn, ing = P.stanze[0].r;
  A.contaRespinti = false;
  for (let i = 0; i < 40; i++) { A.manda({ t: 'move', x: A.x - 0.6, z: A.z, r: 0 }); A.x -= 0.6; await attesa(25); }
  await attesa(300);
  verifica(A.x - ox >= ing[0] + 0.25 && A.x - ox < ing[0] + 1.2, `24 m di passi contro il muro dell'ingresso: il server ferma a x = ${(A.x - ox).toFixed(1)} (muro a ${ing[0]})`);
  // un salto oltre il muro (stesso passo lungo che il limite di velocità concede)
  const prima = [A.x, A.z];
  A.manda({ t: 'move', x: A.x - 2.0, z: A.z, r: 0 });
  await attesa(250);
  verifica(Math.hypot(A.x - prima[0], A.z - prima[1]) < 0.3, `un salto di 2 m oltre il muro è respinto (resta a ${(A.x - ox).toFixed(1)}, ${(A.z - oz).toFixed(1)})`);
  // /tp dentro un muro: punto libero più vicino
  await A.tp(ox + ing[0] - 6, oz + sp[1]);
  verifica(calpestabile(A.x - ox, A.z - oz, 0.45, dg), `/tp dentro la roccia: si finisce nel punto libero più vicino (${(A.x - ox).toFixed(1)}, ${(A.z - oz).toFixed(1)})`);
  // dentro una stanza tolta dalla variante (ala chiusa o tratto sommerso)
  const tolte = [...(V.chiuse || []), ...(V.allagate || [])];
  if (tolte.length) {
    const st = P.stanze.find(s => s.id === tolte[0]);
    const cx = (st.r[0] + st.r[2]) / 2, cz = (st.r[1] + st.r[3]) / 2;
    // dal punto calpestabile più vicino al centro della stanza tolta, dritti verso il centro
    await A.tp(ox + cx, oz + cz);
    const da = [A.x - ox, A.z - oz];
    let entrato = false;
    for (let i = 0; i < 30; i++) {
      const dx = cx - (A.x - ox), dz = cz - (A.z - oz), d = Math.hypot(dx, dz) || 1;
      A.manda({ t: 'move', x: A.x + dx / d * 0.7, z: A.z + dz / d * 0.7, r: 0 }); A.x += dx / d * 0.7; A.z += dz / d * 0.7;
      await attesa(25);
    }
    await attesa(300);
    entrato = Math.abs(A.x - ox - cx) < (st.r[2] - st.r[0]) / 2 - 0.3 && Math.abs(A.z - oz - cz) < (st.r[3] - st.r[1]) / 2 - 0.3 && !calpestabile(A.x - ox, A.z - oz, 0, dg);
    verifica(!entrato && calpestabile(A.x - ox, A.z - oz, 0.25, dg), `«${st.nome}» è chiusa questa settimana: da (${da.map(n => n.toFixed(0)).join(', ')}) non ci si entra (fermo a ${(A.x - ox).toFixed(1)}, ${(A.z - oz).toFixed(1)})`);
  }

  // 4. ogni strada aperta porta al boss
  const stanzaBoss = P.stanze.find(s => s.tipo === 'boss').id, stanzaIngresso = P.stanze[0].id;
  const aliAperte = Object.keys(P.ali).filter(k => k !== 'tesoro' && dg.packs.some(b => b.ala === k));
  let levaTirata = false;
  for (const al of aliAperte) {
    const R = strada(id, v, al, stanzaIngresso, stanzaBoss);
    if (!R || !R.usaAla) { console.log(`   (nessuna strada dall'ingresso al boss per «${P.ali[al].nome}» in questa variante)`); continue; }
    // il ponte della Forgia sommerso: lo si prova dopo aver tirato la leva (più sotto)
    const portaLeva = R.punti.map(p => p.stanza.porta).find(pid => pid && P.porte[pid].apre === 'leva' && A.dg.po[pid] !== 1);
    if (portaLeva) { console.log(`   («${P.ali[al].nome}»: serve la leva, si prova dopo)`); continue; }
    await A.tp(ox + sp[0], oz + sp[1]);
    await A.cmd('/vita 100', 80);
    A.respinti = 0; A.contaRespinti = true;
    let arrivato = true, note = '';
    for (const p of R.punti) {
      const porta = p.stanza.porta;
      if (porta && A.dg.po[porta] !== 1) {
        // cancello chiuso: prima si verifica che non si passa, poi si abbatte chi lo tiene chiuso
        A.contaRespinti = false;
        const fermo = [A.x, A.z];
        const gx = (p.stanza.r[0] + p.stanza.r[2]) / 2 + ox, gz = (p.stanza.r[1] + p.stanza.r[3]) / 2 + oz;
        for (let i = 0; i < 14; i++) {
          const dx = gx - A.x, dz = gz - A.z, d = Math.hypot(dx, dz) || 1;
          A.x += dx / d * 0.7; A.z += dz / d * 0.7;
          A.manda({ t: 'move', x: A.x, z: A.z, r: 0 });
          await attesa(25);
        }
        await attesa(250);
        const passato = calpestabile(A.x - ox, A.z - oz, 0, { rooms: [p.stanza.r] });
        const tApre = A.forse(m => m.t === 'dg' && m.po[porta] === 1, 15000);
        for (let k = 0; k < 12 && A.dg.po[porta] !== 1; k++) { await A.cmd('/uccidi', 150); }
        const aperto = await tApre;
        aggiornaDg();
        note += ` ${P.porte[porta].nome}: chiuso (${passato ? 'ATTRAVERSATO' : 'non si passa'}), poi ${aperto ? 'aperto abbattendo il guardiano' : 'NON aperto'};`;
        if (passato || !aperto) arrivato = false;
        await A.tp(fermo[0], fermo[1]);
        A.contaRespinti = true;
      }
      if (!(await cammina(A, ox, oz, p.x, p.z, dg))) { arrivato = false; note += ` fermo a ${(A.x - ox).toFixed(0)}, ${(A.z - oz).toFixed(0)};`; break; }
      aggiornaDg();
    }
    // ci si ferma appena dentro la sala del boss (più avanti il boss si accorgerebbe del bot e lo seguirebbe ovunque)
    const b = dg.boss, ult = R.punti[R.punti.length - 1];
    if (arrivato) arrivato = await cammina(A, ox, oz, ult.x, ult.z + Math.sign(b.z - ult.z) * 1.5, dg, false);
    if (arrivato) arrivato = calpestabile(A.x - ox, A.z - oz, 0, { rooms: [P.stanze.find(s => s.tipo === 'boss').r] });
    A.contaRespinti = false;
    verifica(arrivato && A.respinti === 0, `«${P.ali[al].nome}» porta al boss camminando (${R.stanze.length} stanze, passi respinti ${A.respinti}):${note || ' nessuna porta'}`);
    if (A.dg.po && Object.entries(A.dg.po).some(([k, s]) => s === 0 && P.porte[k].apre === 'leva') && !levaTirata) {
      // la leva: ci si arriva camminando dalla sala in cui si trova
      const l = dg.leve[0];
      await A.tp(ox + l.x, oz + l.z + 6);
      const tLeva = A.forse(m => m.t === 'dg' && m.po[l.porta] === 1, 6000);
      await cammina(A, ox, oz, l.x + 1.2, l.z + 1.2, dg, false);
      const su = await tLeva;
      aggiornaDg();
      levaTirata = true;
      verifica(su, `leva raggiunta: «${P.porte[l.porta].nome}» aperto (${JSON.stringify(A.dg.po)})`);
    }
  }
  // il ponte (Forgia): dall'ingresso all'isola e oltre, a ponte emerso
  if (P.ali.ponte && A.dg.po.ponte === 1 && attesaPianta.porte.ponte !== 1) {
    const R = strada(id, v, 'ponte', stanzaIngresso, stanzaBoss);
    await A.tp(ox + sp[0], oz + sp[1]);
    await A.cmd('/vita 100', 80);
    A.respinti = 0; A.contaRespinti = true;
    let ok = !!R;
    if (R) for (const p of R.punti) { if (!(await cammina(A, ox, oz, p.x, p.z, dg))) { ok = false; break; } }
    A.contaRespinti = false;
    verifica(ok && A.respinti === 0 && R.stanze.includes('isola'), `«${P.ali.ponte.nome}» emerso: dall'ingresso al boss passando per l'isola (${R && R.stanze.length} stanze, passi respinti ${A.respinti})`);
  }
  verifica(A.fuori.length === 0, `i mostri restano nelle stanze mentre inseguono (${A.fuori.length} posizioni fuori${A.fuori.length ? ': ' + JSON.stringify(A.fuori.slice(0, 4)) : ''})`);

  // 5. Braciere del Ritorno
  const rt = dg.ritorni[0];
  await A.tp(ox + rt.px, oz + rt.pz);
  await attesa(1300);
  const acceso = A.dg.rit === rt.id;
  await A.tp(ox + sp[0], oz + sp[1] + 2);
  await A.cmd('/vita 0', 300);
  await attesa(3100);
  const tPos = A.forse(m => m.t === 'pos' && m.alive, 3000);
  A.manda({ t: 'respawn', mode: 'village' });
  await tPos;
  await attesa(200);
  verifica(acceso && Math.hypot(A.x - ox - rt.px, A.z - oz - rt.pz) < 1.5, `${rt.nome} acceso entrando nella sua zona (${A.dg.rit}); caduti all'ingresso si rinasce lì (${(A.x - ox).toFixed(1)}, ${(A.z - oz).toFixed(1)})`);

  // 6. lo scrigno del tesoro
  const bt = dg.packs.find(b => b.tesoro);
  if (bt && calpestabile(bt.x, bt.z, 0, dg)) {
    await A.tp(ox + bt.x, oz + bt.z - 2);
    await attesa(400);
    const tTes = A.forse(m => m.t === 'dg' && m.tes === 1, 8000);
    for (let k = 0; k < 4 && !(A.dg && A.dg.tes); k++) await A.cmd('/uccidi', 250);
    verifica(await tTes, `guardiano del tesoro abbattuto: scrigno aperto (tes ${A.dg.tes}), forze ${A.dg.forces}%`);
  } else console.log('   (il tesoro non è raggiungibile in questa variante)');

  // 7. si finisce: gli ultimi branchi e il boss
  const tPremi = A.forse(m => m.t === 'dg_reward', 90000);
  for (const b of dg.packs) {
    if (A.dg.done) break;
    await A.tp(ox + b.x, oz + b.z - 1);
    for (let k = 0; k < 8; k++) {
      const m = A.vicino(e => e.k === 'm' && e.hp > 0 && !e.dead && Math.hypot(e.x - A.x, e.z - A.z) < 12);
      if (!m) break;
      await A.cmd('/uccidi', 120);
    }
  }
  await A.tp(ox + dg.boss.x, oz + dg.boss.z - 3);
  for (let k = 0; k < 40 && !(A.dg && A.dg.done); k++) {
    const m = A.vicino(e => e.k === 'm' && e.hp > 0 && !e.dead);
    if (m) await A.tp(m.x, m.z + 1.5);
    await A.cmd('/uccidi', 200);
  }
  const premi = await tPremi;
  const rolls = 1 + Math.floor(2 / 2) + 1;       // sigillo +2, in tempo
  const pezzi = premi ? premi.got.filter(g => /\(/.test(g)).length : 0;
  verifica(A.dg && A.dg.done && A.dg.result && premi && A.dg.forces >= base.forcesNeeded,
    `Prova completata: forze ${A.dg && A.dg.forces}%, sigillo +${A.dg && A.dg.result && A.dg.result.oldKl} → +${A.dg && A.dg.result && A.dg.result.newKl}; pezzi ${pezzi}${A.dg && A.dg.tes ? ` (${rolls} + 1 dello scrigno)` : ` (${rolls})`}`);
  const essenze = 1 + (id === 'forgia' ? 1 : 0) + (A.dg && A.dg.tes ? 1 : 0);
  if (A.dg && A.dg.tes) verifica(premi && pezzi <= rolls + 1 && premi.got.includes(`Essenza Celeste x${essenze}`), `lo scrigno aggiunge un premio (un pezzo e un'essenza in più): ${premi && premi.got.join(', ')}`);
  A.controlla = null;
  const fine = A.forse(m => m.t === 'dg_end', 6000);
  A.manda({ t: 'tleave' });
  await fine;
  await attesa(300);
}

function proveSenzaServer() {
  console.log('--- regole dei muri (senza server)');
  const W = World.prototype;
  const cr = { ...PROVE.cripta, ...componiPianta('cripta', 0, {}) };
  cr.grafo = grafoStanze(cr);
  const inst = { ox: 1000, oz: 0, dg: cr };
  const mondo = { instances: new Map([[1, inst]]) };
  // scatto dalla Sala dei Guardiani verso la Sala dei Sigilli con il cancello chiuso
  let q = W.scattoProva.call(mondo, { x: 1000, z: 70 }, inst, 1000, 95);
  verifica(q[1] <= 79.8, `scatto contro il cancello chiuso: ci si ferma a z = ${q[1].toFixed(1)} (cancello da 79)`);
  // scatto dal corridoio attraverso il muro
  q = W.scattoProva.call(mondo, { x: 1000, z: 14 }, inst, 988, 14);
  verifica(q[0] - 1000 >= -2.8, `scatto contro il muro del corridoio: ci si ferma a x = ${(q[0] - 1000).toFixed(1)} (muro a -3)`);
  // scatto oltre l'abisso: fermo al bordo
  q = W.scattoProva.call(mondo, { x: 1040, z: 40 }, inst, 1040, 75);
  verifica(q[1] <= 45.8, `scatto sopra l'abisso: ci si ferma sul bordo, z = ${q[1].toFixed(1)}`);
  // vista: attraverso l'abisso sì, attraverso un muro no
  verifica(vistaLibera(40, 44, 40, 72, cr) && !vistaLibera(0, 70, -22, 62, cr) && !vistaLibera(0, 70, 0, 95, cr),
    "vista dei mostri: libera sopra l'abisso (le lanterne tirano dall'altra sponda), chiusa dai muri e dal cancello");
  // cammino dei mostri: dalla Sala dei Guardiani al corridoio si passa dal varco, non dal muro
  const passo = W.passoMostroProva.call(mondo, { inst: 1, x: 1008, z: 62 }, 1000, 50);
  verifica(passo && Math.abs(passo[0] - 1000) <= 3.7 && Math.abs(passo[1] - 58.5) < 0.6, `cammino dei mostri: verso un bersaglio nel corridoio si va al varco (${passo && (passo[0] - 1000).toFixed(1)}, ${passo && passo[1].toFixed(1)})`);
  const chiuso = W.passoMostroProva.call(mondo, { inst: 1, x: 1000, z: 70 }, 1000, 95);
  const giro = chiuso && Math.hypot(chiuso[0] - 1000, chiuso[1] - 87) > 3;
  verifica(chiuso === null || giro, `cancello chiuso: un mostro non lo attraversa (${chiuso ? 'fa il giro da ' + (chiuso[0] - 1000).toFixed(0) + ', ' + chiuso[1].toFixed(0) : 'resta dov\'è'})`);
}

async function main() {
  proveSenzaServer();
  await avvia();
  const A = new Bot('admin');
  await A.entra();
  await attesa(300);
  const f = villageFrame('fenice');
  const cw = toWorld(f, 7.5, -18.4);
  await A.cmd('/tp fenice', 300);
  await A.tp(cw.x, cw.z + 2);
  await attesa(500);
  const cu = A.vicino(e => e.k === 'n' && e.role === 'custode');
  // la finestra del Custode racconta la variante della settimana
  A.manda({ t: 'npc', id: cu.id });
  const tr = await A.aspetta(m => m.t === 'trial');
  verifica(tr.prove.every(p => p.pianta && p.pianta.nota && p.pianta.ali.length >= 2), `il Custode annuncia le strade della settimana: ${tr.prove.map(p => `${p.n}: ${p.pianta.nome}`).join('; ')}`);
  const esportate = JSON.parse(fs.readFileSync(path.join(RADICE, 'godot/dati/gioco.json'), 'utf8')).PIANTE;
  for (const id of Object.keys(PIANTE)) {
    if (SOLO && SOLO !== id) continue;
    for (let v = 0; v < PIANTE[id].varianti.length; v++) {
      if (VARIANTI && !VARIANTI.includes(v)) continue;
      await provaVariante(A, id, v, cu, esportate);
    }
  }
  const ok = esiti.filter(e => e[0]).length;
  console.log(`\n${ok}/${esiti.length} verifiche riuscite`);
  A.chiudi();
  srv.kill();
  try { fs.unlinkSync(DBF); } catch {}
  process.exit(ok === esiti.length ? 0 : 1);
}

main().catch(e => { console.error(e); if (srv) srv.kill(); process.exit(1); });
