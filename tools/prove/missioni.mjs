// Prova delle missioni e del bottino con bot WebSocket (shared/missioni.js, server/missioni.js, server/bottino.js).
// Avvia da sé un server con un database temporaneo, poi: prima missione che arriva da sola, consegna dal maestro,
// uccisioni e raccolta che fanno avanzare gli obiettivi, consegne con premi adatti alla classe, catena (Via al livello 5),
// incarichi giornalieri (scelta, consegna, nuovo giorno), salvataggio e rientro, personaggio vecchio senza missioni,
// segni sopra i PNG e avviso dei livelli; infine il bottino per classe e livello (senza server).
// Uso: node tools/prove/missioni.mjs [porta]   (predefinita 3987)
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PORTA = parseInt(process.argv[2] || '3987', 10);
const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter } = await import(path.join(RADICE, 'server/world.js'));
const { equipAdatto, usabile } = await import(path.join(RADICE, 'server/bottino.js'));
const { ITEMS, CATENA, INCARICHI, MISSIONI, CLASSES } = await import(path.join(RADICE, 'shared/data.js'));

const DBF = path.join(os.tmpdir(), `regni-prova-missioni-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
db.createAccount('admin', 'prova');
db.createAccount('vecchio', 'prova');
db.createAccount('arciera', 'prova');
db.createChar('admin', newCharacter('Novizio', 'lama', 'fenice', 'm'));
// personaggio «di prima delle missioni»: livello 12, nessun campo mis
const v = newCharacter('Veterano', 'monaco', 'tigre', 'm'); v.lvl = 12; v.exp = 100;
delete v.mis;
db.createChar('vecchio', v);
// Ombra con l'arco in mano, arrivata al «Campo devastato» (catena al passo 4)
const o = newCharacter('Arciera', 'ombra', 'drago', 'f'); o.lvl = 3;
const arco = o.inv.findIndex((s) => s && s.id === 'arco_bambu');
[o.equip.weapon, o.inv[arco]] = [o.inv[arco], o.equip.weapon];
o.mis = { cat: 3, att: {}, gg: null };
db.createChar('arciera', o);
db.save();

const attesa = (ms) => new Promise((r) => setTimeout(r, ms));
let srv;
async function avvia() {
  srv = spawn(process.execPath, [path.join(RADICE, 'server/index.js')], { cwd: RADICE, env: { ...process.env, PORT: String(PORTA), DB_FILE: DBF }, stdio: ['ignore', 'pipe', 'pipe'] });
  let err = '';
  srv.stderr.on('data', (d) => { err += d; process.stderr.write(d); });
  await new Promise((ok, no) => {
    srv.stdout.on('data', (d) => { if (String(d).includes('server avviato')) ok(); });
    srv.on('exit', (c) => no(new Error('server chiuso ' + c + err)));
  });
}

class Bot {
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; this.mis = null; this.inv = null; }
  async entra() {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise((ok) => this.ws.on('open', ok));
    this.ws.on('message', (raw) => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta((m) => m.t === 'chars');
    const da = this.log.length;
    this.manda({ t: 'play', id: ch.list[0].id });
    const e = await this.aspetta((m) => m.t === 'enter');
    this.id = e.id; this.x = e.x; this.z = e.z; this.gm = !!e.gm;
    await this.trova((m) => m.t === 'mis', da);   // arriva subito dopo `enter`, a volte nello stesso pacchetto
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
    if (m.t === 'mis') this.mis = m;
    if (m.t === 'inv') this.inv = m;
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 30000) {
    const dove = (new Error().stack.split('\n')[2] || '').trim();
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta ${dove} (ultimo errore: ${(this.log.filter((m) => m.t === "err").pop() || {}).m || "nessuno"})`)); } }, ms);
    });
  }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  // un messaggio già arrivato (dall'indice `da` del registro) o il prossimo che soddisfa f
  trova(f, da = 0) { const m = this.log.slice(da).reverse().find(f); return m ? Promise.resolve(m) : this.aspetta(f); }
  async cmd(c) { this.manda({ t: 'chat', m: c }); await attesa(250); }
  vicino(f) {
    let best = null, bd = 1e9;
    for (const e of this.ents.values()) if (f(e)) { const d = Math.hypot(e.x - this.x, e.z - this.z); if (d < bd) { bd = d; best = e; } }
    return best;
  }
  png(ruolo) { return this.vicino((e) => e.k === 'n' && e.role === ruolo); }
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
  // va dal PNG e gli parla; restituisce il dialogo delle missioni (o null se il PNG non ne ha)
  async parla(ruolo, serve = true) {
    const n = this.png(ruolo);
    if (!n) throw new Error(`nessun PNG ${ruolo} in vista`);
    if (this.gm) await this.cmd(`/tp ${n.x} ${n.z + 2}`);
    else await this.cammina(n.x + 1.5, n.z + 1.5);
    await attesa(500);   // i dialoghi rimasti in viaggio dal passo prima non vanno scambiati per la risposta
    this.manda({ t: 'npc', id: n.id });
    const d = await this.aspetta((m) => m.t === 'mis_png' && m.npc === n.id, serve ? 6000 : 1500).catch(() => null);
    this.npc = n;
    return d;
  }
  attiva(id) { return this.mis && this.mis.a.find((x) => x.id === id); }
  contaInv(id) { return (this.inv ? this.inv.inv : []).reduce((s, x) => s + (x && x.id === id ? x.n : 0), 0); }
  chiudi() { this.ws.close(); }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${testo}`); };

async function main() {
  await avvia();
  const A = new Bot('admin');
  await A.entra();
  await attesa(400);
  // --- la prima missione arriva da sola
  verifica(A.attiva('c01'), `prima missione automatica: ${JSON.stringify(A.mis.a.map((x) => x.ti))}`);
  verifica(A.mis.png.maestro === '?' && A.mis.png.scrivano === '!', `segni sopra i PNG: «?» sul maestro, «!» sullo Scrivano: ${JSON.stringify(A.mis.png)}`);
  const d1 = A.attiva('c01').dove;
  const maestro = A.png('maestro');
  verifica(d1 && maestro && Math.hypot(d1.x - maestro.x, d1.z - maestro.z) < 1, `indicazione sulla mappa verso il maestro: ${JSON.stringify(d1)}`);
  // --- parla con il maestro: la consegna e la missione dopo
  let dlg = await A.parla('maestro');
  verifica(dlg && dlg.consegne.some((c) => c.id === 'c01'), `dialogo del maestro con la consegna: ${dlg && JSON.stringify(dlg.consegne.map((c) => c.ti))}`);
  const exp0 = A.me.exp;
  A.manda({ t: 'mis', a: 'consegna', id: 'c01', npc: A.npc.id });
  const fatta = await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === 'c01');
  dlg = await A.trova((m) => m.t === 'mis_png' && m.offerte.length > 0, A.log.indexOf(fatta));
  await attesa(300);
  verifica(A.me.exp > exp0 || A.me.lvl > 1, `consegna c01: ${fatta.got.join(', ')} (esperienza ${exp0} → ${A.me.exp}, livello ${A.me.lvl})`);
  verifica(dlg.offerte.some((x) => x.id === 'c02'), `il maestro offre subito la missione dopo: ${dlg.offerte.map((x) => x.ti).join(', ')}`);
  A.manda({ t: 'mis', a: 'accetta', id: 'c02', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'nuova' && m.id === 'c02');
  await attesa(200);
  verifica(A.attiva('c02') && A.mis.png.guardia !== '!' && A.mis.cat === 1, `c02 accettata: ${A.attiva('c02').ob.map((x) => `${x.t} ${x.p}/${x.n}`).join(', ')}; dove: ${JSON.stringify(A.attiva('c02').dove)}`);
  // --- uccisioni: sei lupi
  await A.cmd('/tp 0 -110');
  await attesa(300);
  for (let i = 0; i < 6; i++) {
    await A.cmd('/spawn lupo 1 1');
    await attesa(150);
    A.manda({ t: 'chat', m: '/uccidi' });
    await A.aspetta((m) => m.t === 'mis_ev' && m.id === 'c02');
  }
  await attesa(300);
  const c02 = A.attiva('c02');
  verifica(c02 && c02.ok === 1 && c02.ob[0].p === 6, `lupi abbattuti ${c02 && c02.ob[0].p}/6, completa: ${c02 && c02.ok}`);
  verifica(A.mis.png.guardia === '?', `segno «?» sopra la guardia: ${JSON.stringify(A.mis.png)}`);
  // --- consegna alla guardia: 5 infusi di ginseng
  await A.cmd('/tp fenice');
  await attesa(500);
  const gin0 = A.contaInv('ginseng_p');
  dlg = await A.parla('guardia');
  A.manda({ t: 'mis', a: 'consegna', id: 'c02', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === 'c02');
  await attesa(300);
  verifica(A.contaInv('ginseng_p') === gin0 + 5, `premio c02: ginseng ${gin0} → ${A.contaInv('ginseng_p')}`);
  // --- raccolta: zanne di lupo dal bottino (c03)
  dlg = await A.aspetta((m) => m.t === 'mis_png').catch(() => null) || await A.parla('guardia');
  A.manda({ t: 'mis', a: 'accetta', id: 'c03', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.id === 'c03');
  await A.cmd('/tp 0 -110');
  await attesa(300);
  for (let k = 0; k < 40 && !(A.attiva('c03') && A.attiva('c03').ok); k++) {
    await A.cmd('/spawn lupo 1 0.5');
    await attesa(150);
    A.manda({ t: 'chat', m: '/uccidi' });
    await attesa(500);
    for (const e of [...A.ents.values()]) if (e.k === 'd' && e.it === 'zanna_lupo' && e.own === A.id) { A.manda({ t: 'pick', id: e.id }); await attesa(80); }
    await attesa(200);
  }
  const c03 = A.attiva('c03');
  verifica(c03 && c03.ok === 1, `zanne raccolte ${c03 && c03.ob[0].p}/5 (zanne in borsa: ${A.contaInv('zanna_lupo')})`);
  // --- consegna a Nonna Lin: un copricapo del livello 1
  await A.cmd('/tp fenice');
  await attesa(500);
  await A.parla('erbe');
  const prima3 = A.log.length;
  A.manda({ t: 'mis', a: 'consegna', id: 'c03', npc: A.npc.id });
  const f3 = await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === 'c03');
  await attesa(300);
  const cappello = A.inv.inv.find((s) => s && ITEMS[s.id].type === 'head');
  verifica(cappello && cappello.r === 1, `premio c03: ${f3.got.join(', ')} → in borsa ${cappello && cappello.id} (rarità ${cappello && cappello.r})`);
  // --- c04 con /missione fatta: arma del livello 5 della classe (Lama → spada)
  let da4 = prima3;
  if (A.me.lvl < 3) {   // «Il campo devastato» è del livello 3: con poche uccisioni si può essere ancora al 2
    await A.cmd('/level 3');
    da4 = A.log.length;
    await A.parla('erbe');
  }
  const dl4 = await A.trova((m) => m.t === 'mis_png' && m.offerte.some((x) => x.id === 'c04'), da4);
  verifica(dl4.offerte.some((x) => x.id === 'c04'), `Nonna Lin offre «Il campo devastato»: premio «${dl4.offerte.find((x) => x.id === 'c04').pr}»`);
  A.manda({ t: 'mis', a: 'accetta', id: 'c04', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.id === 'c04');
  await attesa(200);
  verifica(/Spada del Viandante/.test(A.attiva('c04').pr), `premio annunciato all'accettazione: ${A.attiva('c04').pr}`);
  await A.cmd('/missione fatta');
  await A.parla('armi');
  A.manda({ t: 'mis', a: 'consegna', id: 'c04', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === 'c04');
  await attesa(300);
  verifica(A.inv.inv.some((s) => s && s.id === 'spada_5'), `arma del premio adatta alla classe: ${A.inv.inv.filter((s) => s && ITEMS[s.id].type === 'weapon').map((s) => s.id).join(', ')}`);
  // --- catena: la Via al livello 5
  verifica(A.mis.pross && A.mis.pross.liv === 5 && !A.mis.pross.ok, `prossima missione in attesa del livello: ${JSON.stringify(A.mis.pross)}`);
  const lv0 = A.me.lvl;
  A.manda({ t: 'chat', m: `/exp ${200000}` });
  const sb = await A.aspetta((m) => m.t === 'sblocchi');
  verifica(sb.lvl >= 5 && sb.m.some((x) => /Via/.test(x)), `avviso al passaggio di livello (${lv0} → ${sb.lvl}): ${sb.m.join(' | ')}`);
  await attesa(300);
  verifica(A.mis.png.armi === '!', `segno «!» sopra Mastro Weng per «Il sentiero delle Vie»: ${JSON.stringify(A.mis.png)}`);
  await A.parla('armi');
  A.manda({ t: 'mis', a: 'accetta', id: 'c05', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.id === 'c05');
  A.manda({ t: 'via', v: 'fulmine' });
  await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'pronta' && m.id === 'c05');
  await A.trova((m) => m.t === 'mis' && m.a.some((x) => x.id === 'c05' && x.ok === 1));
  verifica(A.attiva('c05').ok === 1, 'obiettivo «scegli la Via» completato dalla scelta della Via');
  await A.parla('maestro');
  A.manda({ t: 'mis', a: 'consegna', id: 'c05', npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === 'c05');
  await attesa(300);
  verifica(A.mis.cat === 5 && !A.attiva('c05'), `catena al passo ${A.mis.cat + 1}/${A.mis.tot}`);
  // --- incarichi giornalieri dallo Scrivano
  dlg = await A.parla('scrivano');
  verifica(dlg && dlg.offerte.length === A.mis.gg.tot && dlg.offerte.length >= 3 && dlg.offerte.every((x) => x.g === 1), `lo Scrivano offre ${dlg && dlg.offerte.length} incarichi: ${dlg && dlg.offerte.map((x) => x.ti).join(', ')}`);
  const g1 = dlg.offerte[0].id;
  A.manda({ t: 'mis', a: 'accetta', id: g1, npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.id === g1);
  await A.cmd('/missione fatta');
  const tael0 = A.me.tael;
  await A.parla('scrivano');
  A.manda({ t: 'mis', a: 'consegna', id: g1, npc: A.npc.id });
  const fg = await A.aspetta((m) => m.t === 'mis_ev' && m.k === 'fatta' && m.id === g1);
  dlg = await A.trova((m) => m.t === 'mis_png', A.log.indexOf(fg));
  await attesa(300);
  verifica(A.me.tael > tael0 && !dlg.offerte.some((x) => x.id === g1) && A.mis.gg.fatte === 1, `incarico consegnato (${fg.got.join(', ')}); non si ripete oggi: restano ${dlg.offerte.length}`);
  await A.cmd('/missione giorno');
  await attesa(300);
  verifica(A.mis.gg.fatte === 0 && A.mis.gg.libere === A.mis.gg.tot && A.mis.gg.tot === (A.me.lvl >= 20 ? 4 : 3), `nuovo giorno: incarichi ${JSON.stringify(A.mis.gg)}`);
  // un incarico lasciato a metà sopravvive al rientro
  dlg = await A.parla('scrivano');
  const g2 = dlg.offerte.find((x) => x.ob.some((ob) => ob.n > 1)) || dlg.offerte[0];
  A.manda({ t: 'mis', a: 'accetta', id: g2.id, npc: A.npc.id });
  await A.aspetta((m) => m.t === 'mis_ev' && m.id === g2.id);
  // --- salvataggio e rientro
  await A.cmd('/missione c06');
  await attesa(200);
  const prima = JSON.stringify({ cat: A.mis.cat, a: A.mis.a.map((x) => [x.id, x.ob.map((ob) => ob.p)]) });
  A.chiudi();
  await attesa(800);
  const A2 = new Bot('admin');
  await A2.entra();
  await attesa(300);
  const dopo = JSON.stringify({ cat: A2.mis.cat, a: A2.mis.a.map((x) => [x.id, x.ob.map((ob) => ob.p)]) });
  verifica(prima === dopo, `rientro: missioni conservate ${dopo}`);
  const salvato = JSON.parse(fs.readFileSync(DBF, 'utf8'));
  const chA = Object.values(salvato.chars).find((c) => c.name === 'Novizio');
  verifica(chA.mis && chA.mis.cat === 5 && chA.mis.att[g2.id], `nel database: catena ${chA.mis.cat}, aperte ${Object.keys(chA.mis.att).join(', ')}`);
  // --- abbandono
  A2.manda({ t: 'mis', a: 'abbandona', id: g2.id });
  await A2.aspetta((m) => m.t === 'mis_ev' && m.k === 'via');
  await attesa(200);
  verifica(!A2.attiva(g2.id), 'incarico abbandonato');
  A2.chiudi();

  // --- personaggio vecchio, senza campo missioni
  const V = new Bot('vecchio');
  await V.entra();
  await attesa(300);
  verifica(V.mis && V.mis.cat === CATENA.findIndex((m) => m.liv >= 11) && V.mis.pross, `personaggio di livello 12 senza missioni: catena da «${V.mis.pross && V.mis.pross.ti}» (passo ${V.mis.cat + 1}), incarichi ${JSON.stringify(V.mis.gg)}`);
  const ex = V.log.filter((m) => m.t === 'me').pop();
  verifica(ex.lvl === 12 && ex.exp === 100, `livello ed esperienza intatti: ${ex.lvl}, ${ex.exp}`);
  V.chiudi();

  // --- Ombra con l'arco: il premio è un arco
  const O = new Bot('arciera');
  await O.entra();
  await attesa(300);
  const dO = await O.parla('erbe');
  const off = dO && dO.offerte.find((x) => x.id === 'c04');
  O.manda({ t: 'mis', a: 'accetta', id: 'c04', npc: O.npc.id });
  await O.aspetta((m) => m.t === 'mis_ev' && m.id === 'c04');
  await attesa(200);
  verifica(/Arco di Gelso/.test(O.attiva('c04').pr), `Ombra con l'arco: premio ${O.attiva('c04').pr} (offerta: ${off && off.pr})`);
  O.chiudi();

  // --- bottino per classe e livello (senza server)
  let adatti = 0, livelloGiusto = 0;
  const N = 4000;
  for (let i = 0; i < N; i++) {
    const id = equipAdatto(15, { cls: 'mistico', wt: 'staff' });
    if (usabile('mistico', ITEMS[id])) adatti++;
    if (ITEMS[id].lvl > 5 && ITEMS[id].lvl <= 16) livelloGiusto++;
  }
  verifica(adatti / N > 0.75 && livelloGiusto === N, `bottino di un mostro di livello 15 per un Mistico: ${(adatti / N * 100).toFixed(0)}% usabile, ${(livelloGiusto / N * 100).toFixed(0)}% fra i livelli 6 e 16`);
  const tutti = CATENA.every((m) => (m.premio.equip || []).every((e) => Object.keys(CLASSES).every((c) => equipAdatto(e.liv, { cls: c, slot: e.slot, esatto: true, classe: true }))));
  verifica(tutti && Object.keys(MISSIONI).length === CATENA.length + INCARICHI.length, `ogni premio della catena ha un pezzo per ogni classe (${CATENA.length} missioni, ${INCARICHI.length} incarichi)`);
}

try { await main(); } catch (e) { console.error(e); esiti.push([false, String(e)]); }
srv.kill();
const ok = esiti.filter((e) => e[0]).length;
console.log(`\n${ok}/${esiti.length} verifiche riuscite`);
process.exit(ok === esiti.length ? 0 : 1);
