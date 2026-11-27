// Prova delle comodità sociali con bot WebSocket (server/sociale.js, shared/sociale.js): scambio fra giocatori (riuscito,
// annullato, interrotto da disconnessione, troppo lontani, borsa piena, tentativi di duplicazione), deposito condiviso fra
// i personaggi di un account, amici e sussurri, ordinamento, vendita rapida, salvataggio nel database dopo il rientro.
// Avvia da sé un server con un database temporaneo. Uso: node tools/prove/sociale.mjs [porta]  (predefinita 4102)
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PORTA = parseInt(process.argv[2] || '4102', 10);
const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter, makeEquip } = await import(path.join(RADICE, 'server/world.js'));
const { ITEMS, INV_SIZE } = await import(path.join(RADICE, 'shared/data.js'));
const { DEPOSITO_SIZE, SCAMBIO_CASELLE } = await import(path.join(RADICE, 'shared/sociale.js'));

const DBF = path.join(os.tmpdir(), `regni-prova-sociale-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const ARMI = Object.keys(ITEMS).filter((k) => ITEMS[k].type === 'weapon' && ITEMS[k].lvl <= 5);
const TROFEO = 'zanna_lupo';

// ------------------------------------------------------------------ database di prova
const db = new DB(DBF);
db.createAccount('admin', 'prova');
db.createAccount('beta', 'prova');
db.createAccount('pieno', 'prova');
function personaggio(utente, nome, cls, f) {
  const c = newCharacter(nome, cls, 'fenice', 'm');
  c.lvl = 30; c.tael = 1000;
  c.inv = Array(INV_SIZE).fill(null);
  f(c);
  db.createChar(utente, c);
}
personaggio('admin', 'Alfa', 'lama', (c) => {
  c.inv[0] = { id: 'ginseng_p', n: 50, up: 0 };
  c.inv[1] = makeEquip(ARMI[0], 2, 3);          // arma rara +3 con bonus
  c.inv[2] = makeEquip(ARMI[1] || ARMI[0], 0, 0);
  c.inv[3] = { id: TROFEO, n: 12, up: 0 };
  c.inv[4] = makeEquip(ARMI[0], 0, 0);
  c.inv[5] = { id: 'minerale_ferro', n: 5, up: 0 };
});
personaggio('admin', 'Alfetta', 'mistico', (c) => { c.inv[0] = { id: 'loto_p', n: 4, up: 0 }; });
personaggio('beta', 'Beta', 'ombra', (c) => {
  c.inv[0] = { id: 'loto_p', n: 30, up: 0 };
  c.inv[1] = makeEquip(ARMI[0], 1, 0);
});
personaggio('pieno', 'Pieno', 'monaco', (c) => { for (let i = 0; i < INV_SIZE; i++) c.inv[i] = makeEquip(ARMI[0], 0, 0); });
db.save();

// Quanti pezzi di un oggetto esistono in tutto il database (borse, pegni, depositi, equipaggiamento).
function conta(dati, id) {
  let n = 0;
  const somma = (s) => { if (s && s.id === id) n += s.n || 1; };
  for (const c of Object.values(dati.chars)) {
    c.inv.forEach(somma);
    Object.values(c.equip || {}).forEach(somma);
    ((c.escrow && c.escrow.o) || []).forEach((x) => somma(x.it));
  }
  for (const a of Object.values(dati.accounts)) (a.deposito || []).forEach(somma);
  return n;
}
const leggiDb = () => JSON.parse(fs.readFileSync(DBF, 'utf8'));
const totaleIniziale = {};
for (const id of ['ginseng_p', 'loto_p', TROFEO, ARMI[0], 'minerale_ferro']) totaleIniziale[id] = conta(db.data, id);

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
const fermaServer = () => new Promise((ok) => { srv.once('exit', ok); srv.kill('SIGINT'); });

class Bot {
  constructor(utente, nome) { this.utente = utente; this.nome = nome; this.log = []; this.inv = []; this.me = null; this.ents = new Map(); }
  async entra() {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise((ok) => this.ws.on('open', ok));
    this.ws.on('message', (raw) => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.utente, pass: 'prova' });
    const ch = await this.trova((m) => m.t === 'chars', 0);
    const voce = ch.list.find((c) => c.name === this.nome);
    this.manda({ t: 'play', id: voce.id });
    const e = await this.trova((m) => m.t === 'enter', 0);
    this.id = e.id; this.x = e.x; this.z = e.z;
    await this.trova((m) => m.t === 'inv', 0);
    return e;
  }
  ricevi(m) {
    this.log.push(m);
    if (m.t === 'inv') this.inv = m.inv;
    if (m.t === 'me') this.me = m;
    if (m.t === 'pos') { this.x = m.x; this.z = m.z; }
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; } }
      for (const id of m.r) this.ents.delete(id);
    }
  }
  segna() { return this.log.length; }
  // aspetta (a polling) un messaggio dopo il segno `da`
  async trova(f, da = this.segna(), ms = 3000) {
    const fine = Date.now() + ms;
    while (Date.now() < fine) {
      const m = this.log.slice(da).find(f);
      if (m) return m;
      await attesa(30);
    }
    throw new Error(`${this.nome}: attesa scaduta`);
  }
  async manca(f, da, ms = 500) { await attesa(ms); return !this.log.slice(da).some(f); }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  async cmd(c) { this.manda({ t: 'chat', m: c }); await attesa(250); }
  ultimo(tipo, f = () => true) { for (let i = this.log.length - 1; i >= 0; i--) if (this.log[i].t === tipo && f(this.log[i])) return this.log[i]; return null; }
  stato() { const s = this.ultimo('scambio', (m) => m.a === 'stato'); return s; }
  conta(id) { return this.inv.reduce((n, s) => n + (s && s.id === id ? s.n : 0), 0); }
  png(ruolo) { return [...this.ents.values()].find((e) => e.k === 'n' && e.role === ruolo); }
  async cammina(x, z) {
    for (let i = 0; i < 200; i++) {
      const dx = x - this.x, dz = z - this.z, d = Math.hypot(dx, dz);
      if (d < 0.5) return;
      const k = Math.min(0.7, d);
      this.x += dx / d * k; this.z += dz / d * k;
      this.manda({ t: 'move', x: this.x, z: this.z, r: 0 });
      await attesa(100);
    }
  }
  chiudi() { this.ws.close(); }
}

const esiti = [];
let num = 0;
const verifica = (cond, testo) => { num++; esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${String(num).padStart(2)}. ${testo}`); };

async function scambioAperto(X, Y) {
  const m1 = X.segna(), m2 = Y.segna();
  X.manda({ t: 'scambio', a: 'chiedi', id: Y.id });
  await Y.trova((m) => m.t === 'scambio' && m.a === 'richiesta', m2);
  Y.manda({ t: 'scambio', a: 'rispondi', ok: 1 });
  await X.trova((m) => m.t === 'scambio' && m.a === 'stato', m1);
  await Y.trova((m) => m.t === 'scambio' && m.a === 'stato', m2);
}

async function main() {
  await avvia();
  const A = new Bot('admin', 'Alfa');
  const B = new Bot('beta', 'Beta');
  await A.entra(); await B.entra();
  await attesa(500);

  // ============================================================ scambio riuscito
  let m1 = A.segna(), m2 = B.segna();
  A.manda({ t: 'scambio', a: 'chiedi', id: B.id });
  const rich = await B.trova((m) => m.t === 'scambio' && m.a === 'richiesta', m2);
  verifica(rich.n === 'Alfa', `richiesta di scambio ricevuta da Beta (da ${rich.n})`);
  B.manda({ t: 'scambio', a: 'rispondi', ok: 1 });
  let sa = await A.trova((m) => m.t === 'scambio' && m.a === 'stato', m1);
  let sb = await B.trova((m) => m.t === 'scambio' && m.a === 'stato', m2);
  verifica(sa.con === 'Beta' && sb.con === 'Alfa', 'finestra aperta per entrambi, ciascuno vede il nome dell\'altro');

  const armaRara = A.inv[1];
  m1 = A.segna(); m2 = B.segna();
  A.manda({ t: 'scambio', a: 'offri', i: 0, n: 20 });
  await B.trova((m) => m.t === 'scambio' && m.a === 'stato' && m.suo.o.length === 1, m2);
  await attesa(250);
  verifica(A.conta('ginseng_p') === 30, `offerti 20 ginseng su 50: restano ${A.conta('ginseng_p')} nella borsa`);
  sb = B.stato();
  verifica(sb.suo.o[0].id === 'ginseng_p' && sb.suo.o[0].n === 20, 'Beta vede l\'offerta di Alfa (20 ginseng)');

  A.manda({ t: 'scambio', a: 'offri', i: 1 });
  await attesa(250);
  A.manda({ t: 'scambio', a: 'offri', i: 1 });   // ancora la stessa casella: ormai vuota
  const errVuota = await A.trova((m) => m.t === 'err' && /vuota/i.test(m.m), m1);
  verifica(errVuota && A.stato().mio.o.length === 2, 'offrire due volte lo stesso oggetto: la seconda volta la casella è vuota (offerte: 2)');
  verifica(A.inv[1] === null && A.inv[0].n === 30, 'l\'arma offerta è uscita dalla borsa (casella vuota)');

  // tentativi di duplicazione con lo scambio aperto: spostare, usare, buttare, vendere la casella svuotata
  const seg = A.segna();
  A.manda({ t: 'mv', a: { k: 'i', i: 1 }, b: { k: 'i', i: 9 } });
  A.manda({ t: 'use', i: 1 });
  A.manda({ t: 'drop', i: 1 });
  A.manda({ t: 'mv', a: { k: 'i', i: 1 }, b: { k: 'e', i: 'weapon' } });
  await attesa(500);
  const terra = [...A.ents.values()].filter((e) => e.k === 'd');
  verifica(A.inv[1] === null && A.inv[9] === null && !terra.some((d) => d.it === ARMI[0] && d.r === 2), 'spostare/usare/buttare la casella offerta non crea nulla');
  // buttare la pila rimasta (30): non tocca le 20 offerte
  A.manda({ t: 'drop', i: 0 });
  await attesa(300);
  A.manda({ t: 'scambio', a: 'offri', i: 0 });   // casella ormai vuota
  await attesa(300);
  const offerte = A.stato().mio.o;
  verifica(offerte.length === 2 && offerte[0].n === 20, 'buttare la pila rimasta non cambia le 20 offerte');
  // la pila buttata è l'unica cosa fuori dal sistema: va riconteggiata alla fine
  const gettati = 30;

  // tael: offerta e rilancio non si sommano né si duplicano
  const tael0 = A.me.tael;
  A.manda({ t: 'scambio', a: 'tael', n: 500 });
  await attesa(250);
  A.manda({ t: 'scambio', a: 'tael', n: 700 });
  await attesa(300);
  verifica(A.stato().mio.tael === 700 && A.me.tael === tael0 - 700, `tael offerti 500 poi 700: pegno ${A.stato().mio.tael}, in tasca ${A.me.tael} (erano ${tael0})`);
  A.manda({ t: 'scambio', a: 'tael', n: 999999 });
  await A.trova((m) => m.t === 'err' && /Tael/.test(m.m), A.segna() - 1, 1500).catch(() => null);
  await attesa(200);
  verifica(A.stato().mio.tael === 700, 'offrire più tael di quanti se ne hanno è rifiutato');

  // conferma con versione vecchia: ignorata
  const vecchia = A.stato().v - 1;
  A.manda({ t: 'scambio', a: 'conferma', v: vecchia });
  await attesa(300);
  verifica(A.stato().mio.ok === 0, 'conferma di una versione superata ignorata');

  // Beta offre qualcosa, Alfa conferma, poi Beta cambia l'offerta: la conferma di Alfa si azzera
  B.manda({ t: 'scambio', a: 'offri', i: 0, n: 10 });
  await attesa(300);
  A.manda({ t: 'scambio', a: 'conferma', v: A.stato().v });
  await B.trova((m) => m.t === 'scambio' && m.a === 'stato' && m.suo.ok === 1, B.segna() - 3, 1500).catch(() => null);
  verifica(B.stato().suo.ok === 1, 'Beta vede che Alfa ha confermato');
  B.manda({ t: 'scambio', a: 'offri', i: 1 });
  await attesa(300);
  verifica(A.stato().mio.ok === 0 && B.stato().suo.ok === 0, 'Beta cambia l\'offerta dopo la conferma: la conferma di Alfa si azzera');
  // anche togliere un oggetto azzera
  A.manda({ t: 'scambio', a: 'conferma', v: A.stato().v });
  await attesa(250);
  verifica(A.stato().mio.ok === 1, 'Alfa riconferma');
  const vPrima = A.stato().v;
  B.manda({ t: 'scambio', a: 'togli', k: 1 });
  await attesa(300);
  verifica(A.stato().v > vPrima && A.stato().mio.ok === 0, 'togliere un oggetto cambia versione e azzera le conferme');
  verifica(B.conta(ARMI[0]) >= 1, 'l\'oggetto tolto è tornato nella borsa di Beta');

  // conferma di entrambi
  const prima = { ginsengB: B.conta('ginseng_p'), lotoB: B.conta('loto_p'), taelA: A.me.tael, taelB: B.me.tael };
  A.manda({ t: 'scambio', a: 'conferma', v: A.stato().v });
  await attesa(250);
  B.manda({ t: 'scambio', a: 'conferma', v: B.stato().v });
  await A.trova((m) => m.t === 'scambio' && m.a === 'fine', m1);
  await B.trova((m) => m.t === 'scambio' && m.a === 'fine' && m.ok === 1, m2);
  await attesa(400);
  verifica(B.conta('ginseng_p') === 20 && A.conta('loto_p') === 10, `scambio concluso: Beta ha ${B.conta('ginseng_p')} ginseng, Alfa ha ${A.conta('loto_p')} tè di loto`);
  verifica(B.inv.some((s) => s && s.id === ARMI[0] && s.r === 2 && s.up === 3 && JSON.stringify(s.b) === JSON.stringify(armaRara.b)), 'l\'arma rara +3 è arrivata a Beta con rarità, potenziamento e bonus intatti');
  verifica(A.me.tael === tael0 - 700 && B.me.tael === prima.taelB + 700, `tael passati: Alfa ${A.me.tael}, Beta ${B.me.tael}`);

  // ============================================================ scambio annullato
  await scambioAperto(A, B);
  const prima2 = A.conta(TROFEO);
  A.manda({ t: 'scambio', a: 'offri', i: 3, n: 5 });
  await attesa(300);
  A.manda({ t: 'scambio', a: 'offri', i: 2 });
  await attesa(300);
  verifica(A.conta(TROFEO) === prima2 - 5 && A.inv[2] === null, 'offerti 5 trofei e un\'arma: usciti dalla borsa');
  B.manda({ t: 'scambio', a: 'annulla' });
  await A.trova((m) => m.t === 'scambio' && m.a === 'fine' && m.ok === 0, A.segna() - 10, 2000);
  await attesa(300);
  verifica(A.conta(TROFEO) === prima2 && A.inv[2] && A.inv[2].id === (ARMI[1] || ARMI[0]), 'annullato da Beta: gli oggetti di Alfa tornano nelle loro caselle');
  verifica(!A.stato() || A.ultimo('scambio').a === 'fine', 'lo scambio risulta chiuso');

  // nessuno scambio aperto: i messaggi non fanno nulla
  const s0 = A.segna();
  A.manda({ t: 'scambio', a: 'offri', i: 0, n: 1 });
  A.manda({ t: 'scambio', a: 'conferma', v: 1 });
  await attesa(300);
  verifica(!A.log.slice(s0).some((m) => m.t === 'scambio'), 'nessuna risposta a offerte senza scambio');

  // rifiuto
  m1 = A.segna(); m2 = B.segna();
  A.manda({ t: 'scambio', a: 'chiedi', id: B.id });
  await B.trova((m) => m.t === 'scambio' && m.a === 'richiesta', m2);
  B.manda({ t: 'scambio', a: 'rispondi', ok: 0 });
  await A.trova((m) => m.t === 'sys' && /rifiutato/.test(m.m), m1);
  verifica(true, 'richiesta rifiutata: Alfa avvisata');

  // ============================================================ disconnessione a metà
  await scambioAperto(A, B);
  A.manda({ t: 'scambio', a: 'offri', i: 4 });
  A.manda({ t: 'scambio', a: 'offri', i: 5, n: 3 });
  await attesa(400);
  const minerale0 = A.conta('minerale_ferro');
  verifica(minerale0 === 2 && A.inv[4] === null, 'Alfa ha offerto un\'arma e 3 minerali (restano 2)');
  A.chiudi();
  const fineB = await B.trova((m) => m.t === 'scambio' && m.a === 'fine' && m.ok === 0, B.segna() - 20, 3000);
  verifica(fineB, 'Alfa si disconnette: lo scambio di Beta si chiude');
  await attesa(500);
  verifica(B.conta('minerale_ferro') === 0, 'Beta non riceve nulla dallo scambio interrotto');
  const A1 = new Bot('admin', 'Alfa');
  await A1.entra();
  await attesa(400);
  verifica(A1.conta('minerale_ferro') === 5 && A1.inv.some((s) => s && s.id === ARMI[0] && s.r === 0), 'al rientro Alfa ha tutto: 5 minerali e l\'arma');
  verifica(conta(leggiDb(), 'minerale_ferro') === totaleIniziale.minerale_ferro, 'nessun minerale creato né perso (database)');

  // ============================================================ troppo lontani
  await scambioAperto(A1, B);
  A1.manda({ t: 'scambio', a: 'offri', i: 0 });
  await attesa(300);
  await A1.cmd(`/tp ${B.x + 20} ${B.z}`);
  await A1.trova((m) => m.t === 'scambio' && m.a === 'fine' && m.ok === 0, A1.segna() - 10, 3000).catch(() => null);
  await attesa(300);
  verifica(A1.ultimo('scambio').a === 'fine', 'Alfa si allontana: lo scambio si annulla da solo');
  await A1.cmd(`/tp ${B.x} ${B.z}`);
  // la richiesta da lontano è respinta
  const e0 = A1.segna();
  await A1.cmd(`/tp ${B.x + 14} ${B.z}`);
  A1.manda({ t: 'scambio', a: 'chiedi', id: B.id });
  await A1.trova((m) => m.t === 'err' && /lontano/.test(m.m), e0, 2000).then(() => verifica(true, 'richiesta da lontano respinta')).catch(() => verifica(false, 'richiesta da lontano respinta'));
  // torna accanto a Beta
  await A1.cmd(`/tp ${B.x} ${B.z}`);
  await attesa(300);

  // ============================================================ borsa piena
  const P = new Bot('pieno', 'Pieno');
  await P.entra();
  await attesa(500);
  await A1.cmd(`/tp ${P.x} ${P.z}`);
  await scambioAperto(A1, P);
  A1.manda({ t: 'scambio', a: 'offri', i: A1.inv.findIndex((s) => s && s.id === TROFEO), n: 10 });
  await attesa(300);
  A1.manda({ t: 'scambio', a: 'conferma', v: A1.stato().v });
  await attesa(200);
  P.manda({ t: 'scambio', a: 'conferma', v: P.stato().v });
  const pienoMsg = await A1.trova((m) => m.t === 'sys' && /abbastanza spazio/.test(m.m), A1.segna() - 15, 2000).catch(() => null);
  await attesa(300);
  verifica(pienoMsg && A1.ultimo('scambio').a === 'stato' && A1.ultimo('scambio').mio.ok === 0, 'borsa piena: lo scambio non si conclude, resta aperto e le conferme si azzerano');
  verifica(P.conta(TROFEO) === 0, 'Pieno non ha ricevuto nulla');
  // limite di oggetti offerti
  for (let k = 0; k < SCAMBIO_CASELLE + 1; k++) { P.manda({ t: 'scambio', a: 'offri', i: k }); await attesa(60); }
  await attesa(300);
  verifica(P.stato().mio.o.length === SCAMBIO_CASELLE, `al massimo ${SCAMBIO_CASELLE} oggetti per parte`);
  // Pieno ha offerto 8 armi: ora ha spazio, Alfa pure; concludono
  A1.manda({ t: 'scambio', a: 'conferma', v: A1.stato().v });
  await attesa(200);
  P.manda({ t: 'scambio', a: 'conferma', v: P.stato().v });
  await P.trova((m) => m.t === 'scambio' && m.a === 'fine' && m.ok === 1, P.segna() - 30, 3000).catch(() => null);
  await attesa(300);
  if (process.env.DEBUG) console.log(JSON.stringify(A1.log.filter((m) => m.t !== 'v' && m.t !== 'r').slice(-8).map((m) => m.t === 'scambio' ? [m.a, m.v, m.mio && m.mio.ok, m.suo && m.suo.ok, m.mio && m.mio.o.length] : m)).slice(0, 2500), JSON.stringify(P.log.filter((m) => m.t !== 'v' && m.t !== 'r').slice(-8).map((m) => m.t === 'scambio' ? [m.a, m.v, m.mio && m.mio.ok, m.suo && m.suo.ok, m.mio && m.mio.o.length] : m)).slice(0, 2500));
  verifica(P.conta(TROFEO) === 10 && A1.inv.filter((s) => s && s.id === ARMI[0]).length >= 8, `(${P.conta(TROFEO)}, ${A1.inv.filter((s) => s && s.id === ARMI[0]).length}) liberato lo spazio (offrendo oggetti) lo scambio riesce`);
  P.chiudi();

  // ============================================================ deposito
  const mag = A1.png('magazziniere');
  verifica(mag && mag.n === 'Cassiera Zhou', `magazziniere nel villaggio: ${mag && mag.n}`);
  // da lontano non si apre
  await A1.cmd(`/tp ${mag.x + 25} ${mag.z}`);
  await attesa(300);
  const l0 = A1.segna();
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: 0 });
  await A1.trova((m) => m.t === 'err' && /lontano/.test(m.m), l0, 1500).then(() => verifica(true, 'deposito da lontano rifiutato')).catch(() => verifica(false, 'deposito da lontano rifiutato'));
  await A1.cmd(`/tp ${mag.x + 1} ${mag.z + 1}`);
  await attesa(400);
  let d0 = A1.segna();
  A1.manda({ t: 'npc', id: mag.id });
  let dep = await A1.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  verifica(dep.slots.length === DEPOSITO_SIZE && dep.slots.every((s) => s === null), `parlando col magazziniere si apre il deposito vuoto (${dep.slots.length} caselle)`);
  const ginsengA1 = A1.conta('loto_p'), locA1 = A1.conta('loto_p');
  d0 = A1.segna();
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: A1.inv.findIndex((s) => s && s.id === 'loto_p'), n: 6, s: 5 });
  dep = await A1.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  await attesa(250);
  verifica(dep.slots[5] && dep.slots[5].id === 'loto_p' && dep.slots[5].n === 6 && A1.conta('loto_p') === ginsengA1 - 6, 'depositati 6 tè di loto nella casella 5');
  const iArma = A1.inv.findIndex((s) => s && s.id === ARMI[0] && s.r === 0);
  d0 = A1.segna();
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: iArma });
  dep = await A1.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  await attesa(250);
  verifica(dep.slots.filter(Boolean).length === 2 && A1.inv[iArma] === null, 'depositata un\'arma (casella libera più vicina)');
  d0 = A1.segna();
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: A1.inv.findIndex((s) => s && s.id === 'loto_p'), n: 4 });   // si fonde con la pila
  dep = await A1.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  verifica(dep.slots[5].n === 10, 'altri 4 tè si uniscono alla pila (10)');
  // il Sigillo / oggetti inesistenti
  d0 = A1.segna();
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: 44 });
  A1.manda({ t: 'dep', a: 'prendi', npc: mag.id, s: 30 });
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: -3 });
  A1.manda({ t: 'dep', a: 'metti', npc: mag.id, i: 'x' });
  await attesa(500);
  verifica(true, 'indici vuoti o non validi non fanno cadere il server');
  // riordino dentro il deposito
  d0 = A1.segna();
  A1.manda({ t: 'dep', a: 'sposta', npc: mag.id, da: 5, a2: 20 });
  dep = await A1.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  verifica(dep.slots[20] && dep.slots[20].n === 10 && !dep.slots[5], 'pila spostata dalla casella 5 alla 20');
  // il secondo personaggio dello stesso account
  A1.chiudi();
  await attesa(500);
  const A2 = new Bot('admin', 'Alfetta');
  await A2.entra();
  await attesa(500);
  const mag2 = A2.png('magazziniere');
  await A2.cmd(`/tp ${mag2.x + 1} ${mag2.z + 1}`);
  await attesa(300);
  d0 = A2.segna();
  A2.manda({ t: 'npc', id: mag2.id });
  dep = await A2.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  verifica(dep.slots[20] && dep.slots[20].id === 'loto_p' && dep.slots[20].n === 10, 'un altro personaggio dello stesso account vede lo stesso deposito');
  d0 = A2.segna();
  A2.manda({ t: 'dep', a: 'prendi', npc: mag2.id, s: 20, n: 4 });
  dep = await A2.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  await attesa(300);
  verifica(A2.conta('loto_p') === 8 && dep.slots[20].n === 6, 'Alfetta ritira 4 tè: ora 8 nella borsa, 6 nel deposito');
  const iArmaDep = dep.slots.findIndex((s) => s && s.id === ARMI[0]);
  d0 = A2.segna();
  A2.manda({ t: 'dep', a: 'prendi', npc: mag2.id, s: iArmaDep });
  dep = await A2.trova((m) => m.t === 'dep' && m.a === 'stato', d0);
  await attesa(300);
  verifica(A2.inv.some((s) => s && s.id === ARMI[0]), 'Alfetta ritira anche l\'arma');
  // un altro account non vede il deposito di admin
  const Bm = B.png('magazziniere');
  await B.cammina(Bm.x + 1.5, Bm.z + 1.5);   // il punto d'arrivo può distare più di 8 m dal Cassiere
  d0 = B.segna();
  B.manda({ t: 'npc', id: Bm.id });
  const depB = await B.trova((m) => m.t === 'dep' && m.a === 'stato', d0).catch(() => null);
  verifica(depB && depB.slots.every((s) => s === null), 'Beta (un altro account) ha un deposito suo, vuoto');
  // deposito pieno: si riempie con armi e il successivo è rifiutato
  // riempimento: si butta tutto in deposito finché non c'è più posto (due ondate da 40 armi: l'inventario ne tiene 45)
  for (let giro = 0; giro < 2; giro++) {
    await A2.cmd('/item ' + ARMI[0] + ' 40');
    await attesa(300);
    const indici = A2.inv.map((s, i) => (s && s.id === ARMI[0] ? i : -1)).filter((i) => i >= 0);
    for (const i of indici) { A2.manda({ t: 'dep', a: 'metti', npc: mag2.id, i }); await attesa(30); }
    await attesa(300);
  }
  const resto = A2.inv.filter((s) => s && s.id === ARMI[0]).length;
  await attesa(300);
  const depPieno = A2.ultimo('dep', (m) => m.a === 'stato');
  const piene = depPieno.slots.filter(Boolean).length;
  verifica(piene === DEPOSITO_SIZE && resto > 0, `deposito pieno (${piene}/${DEPOSITO_SIZE}): il resto (${resto} armi) resta nella borsa`);

  // ============================================================ amici e sussurri
  m2 = B.segna();
  B.manda({ t: 'amico', a: 'aggiungi', n: 'alfetta' });
  let lista = await B.trova((m) => m.t === 'amici', m2);
  verifica(lista.list.length === 1 && lista.list[0].n === 'Alfetta' && lista.list[0].on === 1 && lista.list[0].lvl === 30 && lista.list[0].z, `amico aggiunto, in linea: ${JSON.stringify(lista.list[0])}`);
  m2 = B.segna();
  B.manda({ t: 'amico', a: 'aggiungi', n: 'Alfa' });
  lista = await B.trova((m) => m.t === 'amici', m2);
  verifica(lista.list.length === 2 && lista.list.find((x) => x.n === 'Alfa').on === 0, 'secondo amico (Alfa) risulta fuori linea');
  m2 = B.segna();
  B.manda({ t: 'amico', a: 'aggiungi', n: 'ALFA' });
  await B.trova((m) => m.t === 'err' && /già/.test(m.m), m2);
  B.manda({ t: 'amico', a: 'aggiungi', n: 'Nessuno' });
  await B.trova((m) => m.t === 'err' && /Nessun personaggio/.test(m.m), m2);
  B.manda({ t: 'amico', a: 'aggiungi', n: 'Beta' });
  await B.trova((m) => m.t === 'err' && /tuo amico/.test(m.m), m2);
  verifica(true, 'duplicati, nomi inesistenti e se stessi rifiutati');
  // avviso di entrata
  m2 = B.segna();
  const A3 = new Bot('admin', 'Alfa');
  A2.chiudi();
  await attesa(500);
  await A3.entra();
  const avv = await B.trova((m) => m.t === 'amico_on' && m.n === 'Alfa', m2).catch(() => null);
  verifica(avv, 'Beta riceve l\'avviso: il suo amico Alfa è entrato');
  const l2 = await B.trova((m) => m.t === 'amici' && m.list.find((x) => x.n === 'Alfa' && x.on === 1), m2).catch(() => null);
  verifica(l2, 'e la sua lista mostra Alfa in linea');
  // sussurri
  m2 = B.segna(); m1 = A3.segna();
  await A3.cmd('/s Beta ciao amico');
  const wh = await B.trova((m) => m.t === 'chat' && m.ch === 'wh', m2);
  verifica(wh.n === 'Alfa' && wh.m === 'ciao amico', 'sussurro /s ricevuto');
  const eco = await A3.trova((m) => m.t === 'chat' && m.ch === 'wh' && m.to === 'Beta', m1);
  verifica(eco, 'chi sussurra vede la propria riga');
  m1 = A3.segna();
  await B.cmd('/r eccomi');
  const ris = await A3.trova((m) => m.t === 'chat' && m.ch === 'wh' && m.m === 'eccomi', m1).catch(() => null);
  verifica(ris && ris.n === 'Beta', '/r risponde all\'ultimo sussurro');
  m1 = A3.segna();
  await A3.cmd('/s Fantasma ci sei?');
  const nolinea = await A3.trova((m) => m.t === 'sys' && /non è in linea/.test(m.m), m1).catch(() => null);
  verifica(nolinea, 'sussurro a chi non è in linea: avviso');
  // invito al gruppo dall'elenco (stesso messaggio del tasto Invita): Beta invita Alfa
  m1 = A3.segna();
  B.manda({ t: 'pinv', n: 'Alfa' });
  const inv = await A3.trova((m) => m.t === 'pinv', m1).catch(() => null);
  verifica(inv && inv.n === 'Beta', 'invito al gruppo per nome (dalla lista amici)');
  A3.manda({ t: 'preply', ok: 0 });
  // rimozione
  m2 = B.segna();
  B.manda({ t: 'amico', a: 'rimuovi', n: 'alfa' });
  lista = await B.trova((m) => m.t === 'amici', m2);
  verifica(lista.list.length === 1 && lista.list[0].n === 'Alfetta', 'amico rimosso');

  // ============================================================ oggetti collegati in chat
  m2 = B.segna();
  const iPezzo = A3.inv.findIndex((s) => s && ITEMS[s.id].type === 'weapon');
  await A3.cmd(`ecco: [[${iPezzo}]] e una casella vuota [[44]]`);
  const say = await B.trova((m) => m.t === 'chat' && m.ch === 'say' && m.n === 'Alfa', m2).catch(() => null);
  const tok = say && /\u27e6([^\u27e7]*)\u27e7/.exec(say.m);
  const pezzo = tok && JSON.parse(decodeURIComponent(tok[1]));
  verifica(pezzo && pezzo.id === A3.inv[iPezzo].id && !/\[\[/.test(say.m), 'oggetto collegato in chat: Beta riceve l\'oggetto intero, la casella vuota sparisce');

  // ============================================================ ordinamento e vendita rapida
  await A3.cmd('/item ' + TROFEO + ' 3');
  const prima3 = A3.inv.filter(Boolean).length;
  const totPrima = A3.inv.reduce((n, s) => n + (s ? s.n : 0), 0);
  A3.manda({ t: 'ordina' });
  await attesa(400);
  const cont = A3.inv.findIndex((s, i) => !s && A3.inv.slice(i).some(Boolean));
  const totDopo = A3.inv.reduce((n, s) => n + (s ? s.n : 0), 0);
  verifica(cont === -1 && totDopo === totPrima, `ordinamento: oggetti compattati in testa, quantità invariata (${totDopo})`);
  const armi = A3.inv.filter((s) => s && ITEMS[s.id].type === 'weapon').length;
  verifica(armi === 0 || ITEMS[A3.inv[0].id].type === 'weapon', 'le armi vengono per prime');
  const venditore = A3.png('armi');
  await A3.cmd(`/tp ${venditore.x} ${venditore.z + 2}`);
  await attesa(300);
  const taelA3 = A3.me.tael;
  const bianchi = A3.inv.filter((s) => s && ITEMS[s.id].type === 'weapon' && !s.r && !s.up).length;
  A3.manda({ t: 'vendi_comuni', npc: venditore.id });
  await attesa(500);
  const restanti = A3.inv.filter((s) => s && ITEMS[s.id].type === 'weapon' && !s.r && !s.up).length;
  verifica(bianchi > 0 && restanti === 0 && A3.me.tael > taelA3 && A3.conta('minerale_ferro') === 5, `vendita rapida: ${bianchi} armi comuni vendute (+${A3.me.tael - taelA3} tael), i minerali restano`);
  verifica(A3.conta(TROFEO) === 0, 'anche i trofei di caccia sono stati venduti');

  // ============================================================ salvataggio e conservazione
  A3.chiudi(); B.chiudi();
  await attesa(600);
  await fermaServer();
  const finale = leggiDb();
  const acc = finale.accounts.admin, accB = finale.accounts.beta;
  verifica(Array.isArray(acc.deposito) && acc.deposito.length === DEPOSITO_SIZE && acc.deposito.some((s) => s && s.id === 'loto_p'), 'deposito salvato nel database (account admin)');
  verifica(accB.amici && accB.amici.length === 1 && accB.amici[0] === 'Alfetta', 'amici salvati nel database (account beta)');
  verifica(Object.values(finale.chars).every((c) => !c.escrow), 'nessun pegno rimasto nei personaggi');
  // Conservazione: ginseng e loto totali = iniziali meno quelli buttati a terra / venduti nel test
  const gTot = conta(finale, 'ginseng_p');
  verifica(gTot === totaleIniziale.ginseng_p - gettati, `ginseng nel database ${gTot} = iniziali ${totaleIniziale.ginseng_p} - ${gettati} buttati (nessuno creato dallo scambio)`);
  verifica(conta(finale, 'loto_p') === totaleIniziale.loto_p, `tè di loto nel database ${conta(finale, 'loto_p')} = iniziali ${totaleIniziale.loto_p}`);
  verifica(conta(finale, 'minerale_ferro') === totaleIniziale.minerale_ferro, 'minerali conservati');
  verifica(finale.chars && Object.values(finale.chars).find((c) => c.name === 'Beta').inv.some((s) => s && s.id === ARMI[0] && s.r === 2), 'l\'arma scambiata è nel database di Beta');

  const ko = esiti.filter(([ok]) => !ok);
  console.log(`\n${esiti.length - ko.length}/${esiti.length} verifiche riuscite`);
  process.exit(ko.length ? 1 : 0);
}

main().catch(async (e) => { console.error(e); try { srv.kill('SIGKILL'); } catch {} process.exit(2); });
