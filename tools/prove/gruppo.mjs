// Prova del gioco in gruppo con bot WebSocket: tre giocatori (difensore della Montagna, guaritore della Benedizione,
// Monaco del Loto per i danni) più due estranei (stesso regno senza gruppo, altro regno).
// Avvia da sé un server con un database temporaneo e verifica: inviti, accettazione, uscita, espulsione, capogruppo;
// auree di classe (compagni nel raggio, uscita dal raggio o dal gruppo, `au` visto dagli altri, morte); cure
// (alleato scelto, alleato più ferito, Grazia, Risonanza che cura il gruppo, scudo, maestria del Loto, niente cure agli
// stranieri); Radici della Montagna e minaccia del difensore; Serie e Occasione; esperienza, tael e bottino divisi;
// missioni dei compagni vicini; una Prova del Sigillo in tre con una morte, una disconnessione e le ricompense;
// l'arena (PvP fra non compagni, niente fuoco amico, cure solo agli alleati, stordimenti ripetuti); disconnessione
// e rientro nel mondo aperto.
//
// Uso:  node tools/prove/gruppo.mjs [porta]                     tutte le verifiche (predefinita 3981)
//       node tools/prove/gruppo.mjs [porta] --solo auree,cure    solo alcune sezioni
//       node tools/prove/gruppo.mjs [porta] --misura [--secondi 60] [--ripeti 1]
//            [--senza-guaritore] [--elite campione_arenaria] [--branco guerriero_arenaria] [--equip potenziamento,rarità (predefinito 0,0)]
//            misura la tenuta (personaggi di livello 40 con equipaggiamento del 40, +9, Pregiato): il difensore tiene
//            un'élite (Campione d'Arenaria, liv. 48, con lancio) e un branco di 5 Guerrieri d'Arenaria (liv. 47, rimessi
//            quando cadono tutti) per N secondi nella radura; il guaritore lo cura da 12 m. Stampa danni subiti al secondo
//            (dopo gli scudi), assorbiti dagli scudi, cure al secondo, vita minima, morti e branchi abbattuti.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const RADICE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const argv = process.argv.slice(2);
const PORTA = parseInt(argv.find(a => /^\d+$/.test(a)) || '3981', 10);
const opz = (k, def) => { const i = argv.indexOf('--' + k); return i < 0 ? def : (argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true); };
const SOLO = opz('solo', '') ? String(opz('solo')).split(',') : null;
const MISURA = !!opz('misura', false);
const SECONDI = parseFloat(opz('secondi', 60));
const RIPETI = parseInt(opz('ripeti', 1), 10);
const SENZA_CURE = !!opz('senza-guaritore', false);
const ELITE = String(opz('elite', 'campione_arenaria')), BRANCO = String(opz('branco', 'guerriero_arenaria'));

const require = createRequire(path.join(RADICE, 'package.json'));
const WebSocket = require('ws');
const { DB } = await import(path.join(RADICE, 'server/db.js'));
const { newCharacter, makeEquip } = await import(path.join(RADICE, 'server/world.js'));
const { CLASSES, ITEMS, MOBS, DUNGEON } = await import(path.join(RADICE, 'shared/data.js'));
const { villageSpawn, safeZoneAt } = await import(path.join(RADICE, 'shared/world.js'));
const { componiPianta } = await import(path.join(RADICE, 'shared/prove.js'));

// ---------------------------------------------------------------- personaggi
const DBF = path.join(os.tmpdir(), `regni-prova-gruppo-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
// equipaggiamento del livello 40 di tutti: potenziamento e rarità (--equip 9,2); la misura parte da pezzi comuni +0
const [EQ_UP, EQ_R] = String(opz('equip', MISURA ? '0,0' : '9,2')).split(',').map(Number);
const ARMA = { lama: 'spada_40', mistico: 'bastone_40', monaco: 'pugni_40', ombra: 'pugnali_40' };
function eroe(account, nome, cls, regno, via, punti) {
  db.createAccount(account, 'prova');
  const c = newCharacter(nome, cls, regno, 'm');
  c.lvl = 40; c.tael = 100000; c.via = via;
  // 117 punti statistica: come i bot di `npm run sim` (2 su 3 al valore primario; il difensore in vitalità)
  for (const k in punti) c.stats[k] += punti[k];
  c.equip.weapon = makeEquip(ARMA[cls], EQ_R, EQ_UP);
  c.equip.body = makeEquip('corazza_40', EQ_R, EQ_UP);
  c.equip.head = makeEquip('elmo_40', EQ_R, EQ_UP);
  c.equip.feet = makeEquip('calzari_40', EQ_R, EQ_UP);
  for (let i = 0; i < c.qb.length; i++) c.qb[i] = null;
  db.createChar(account, c);
}
eroe('difensore', 'Roccia', 'lama', 'fenice', 'montagna', { vit: 78, str: 39 });
eroe('guaritore', 'Giada', 'mistico', 'fenice', 'benedizione', { int: 78, vit: 39 });
eroe('danno', 'Loto', 'monaco', 'fenice', 'loto', { str: 78, vit: 39 });
eroe('estraneo', 'Estraneo', 'ombra', 'fenice', 'pugnali', { dex: 78, vit: 39 });
eroe('straniero', 'Straniero', 'lama', 'tigre', 'fulmine', { str: 78, vit: 39 });
db.save();

const attesa = (ms) => new Promise(r => setTimeout(r, ms));
let srv;
async function avvia() {
  srv = spawn(process.execPath, [path.join(RADICE, 'server/index.js')], {
    cwd: RADICE, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, PORT: String(PORTA), DB_FILE: DBF, GM_ACCOUNTS: 'difensore,guaritore,danno,estraneo,straniero' },
  });
  let err = '';
  srv.stderr.on('data', d => { err += d; process.stderr.write(d); });
  await new Promise((ok, no) => {
    srv.stdout.on('data', d => { if (String(d).includes('server avviato')) ok(); });
    srv.on('exit', c => no(new Error('server chiuso ' + c + err)));
  });
}

// ---------------------------------------------------------------- bot
class Bot {
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; this.party = null; this.fxLog = []; this.st = []; }
  async entra() {
    this.ents.clear(); this.party = null; this.me = null;
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise(ok => this.ws.on('open', ok));
    this.ws.on('message', raw => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta(m => m.t === 'chars');
    this.manda({ t: 'play', id: ch.list[0].id });
    const e = await this.aspetta(m => m.t === 'enter');
    this.id = e.id; this.nome = e.name;   // x e z li prende ricevi: un `pos` può arrivare subito dopo `enter`
    await this.finche(() => this.me, 3000);
    return e;
  }
  ricevi(m) {
    this.log.push(m);
    if (this.log.length > 4000) this.log.splice(0, 2000);
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; e.hp = u[4]; e.mhp = u[5]; e.dead = u[7]; } }
      for (const id of m.r) this.ents.delete(id);
    }
    if (m.t === 'pos' || m.t === 'enter') { this.x = m.x; this.z = m.z; }
    if (m.t === 'me') this.me = m;
    if (m.t === 'r' && this.me) Object.assign(this.me, m);
    if (m.t === 'party') this.party = m.none ? null : m;
    if (m.t === 'fx') this.fxLog.push({ ...m, at: Date.now() });
    if (m.t === 'st' && m.stun) this.st.push(m.stun);
    if (this.fxLog.length > 6000) this.fxLog.splice(0, 3000);
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 5000) {
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta`)); } }, ms);
    });
  }
  async forse(f, ms) { try { return await this.aspetta(f, ms); } catch { return null; } }
  async finche(cond, ms = 5000) {
    const t0 = Date.now();
    while (Date.now() - t0 < ms) { const v = cond(); if (v) return v; await attesa(80); }
    return cond();
  }
  manda(m) { if (this.ws.readyState === 1) this.ws.send(JSON.stringify(m)); }
  async cmd(c, ms = 200) { this.manda({ t: 'chat', m: c }); await attesa(ms); }
  async tp(x, z) {
    this.manda({ t: 'chat', m: `/tp ${x} ${z}` });
    await this.forse(m => m.t === 'pos', 2000);
    await attesa(250);
  }
  buff(id) { return !!(this.me && this.me.buffs.some(b => b.b === id)); }
  // usa una tecnica e aspetta l'esito (fine del lancio compresa); restituisce 'ok', il messaggio d'errore o 'scaduto'
  async tecnica(s, id = 0, ms = 3500) {
    const da = this.log.length;
    this.manda({ t: 'skill', s, id });
    const r = await this.forse(m => (m.t === 'cd' && m.s === s && !m.rid) || (m.t === 'skfail' && m.s === s), ms);
    if (!r) return 'scaduto';
    if (r.t === 'cd') return 'ok';
    const e = this.log.slice(da).reverse().find(m => m.t === 'err');
    return e ? e.m : 'rifiutata';
  }
  vicino(f) {
    let best = null, bd = 1e9;
    for (const e of this.ents.values()) if (f(e)) { const d = Math.hypot(e.x - this.x, e.z - this.z); if (d < bd) { bd = d; best = e; } }
    return best;
  }
  mobVivi(r = 30) { return [...this.ents.values()].filter(e => e.k === 'm' && e.hp > 0 && !e.dead && Math.hypot(e.x - this.x, e.z - this.z) < r); }
  cure(da, d) { return this.fxLog.filter(f => f.at >= da && f.k === 'heal' && (d === undefined || f.d === d)); }
  colpi(da, f) { return this.fxLog.filter(x => x.at >= da && x.k === 'hit' && f(x)); }
  chiudi() { try { this.ws.close(); } catch {} }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${testo}`); };
const sezione = (n) => !SOLO || SOLO.includes(n);
const pct = (b) => b.me ? Math.round(b.me.hp / b.me.mhp * 100) : -1;
const RADURA = { x: -228, z: -228 };   // la radura di `npm run sim`: nessun branco entro 50 m

let T, H, D, E, S;   // difensore, guaritore, danno, estraneo (stesso regno), straniero (altro regno)

async function invita(capo, q) {
  capo.manda({ t: 'pinv', id: q.id });
  await q.aspetta(m => m.t === 'pinv', 3000);
  q.manda({ t: 'preply', ok: 1 });
  await q.finche(() => q.party && q.party.members.some(m => m.id === q.id), 3000);
}
async function formaGruppo() {
  for (const b of [T, H, D]) if (b.party && b.party.leader !== T.id) { b.manda({ t: 'pleave' }); await attesa(150); }
  if (!(T.party && T.party.members.some(m => m.id === H.id))) await invita(T, H);
  if (!(T.party && T.party.members.some(m => m.id === D.id))) await invita(T, D);
  await T.finche(() => T.party && T.party.members.length === 3, 3000);
}
async function tuttiA(x, z, bots = [T, H, D]) {
  for (const [i, b] of bots.entries()) await b.tp(x + i * 2, z);
  await attesa(300);
}
async function pulisci(b, r = 25) {
  // abbatte i mostri rimasti attorno (fantocci esclusi: /uccidi li salta)
  for (let k = 0; k < 40; k++) {
    const m = b.mobVivi(r).find(e => e.ty !== 'fantoccio');
    if (!m) return;
    await b.tp(m.x, m.z + 1.5);
    await b.cmd('/uccidi', 120);
  }
}
async function rinasci(b) {
  if (!(b.me && b.me.dead)) return;
  await attesa(3100);
  b.manda({ t: 'respawn', mode: 'village' });
  await b.forse(m => m.t === 'pos' && m.alive, 3000);
  await attesa(200);
}

// ================================================================ sezioni
async function provaGruppo() {
  // regno diverso
  T.manda({ t: 'pinv', id: S.id });
  const e1 = await T.forse(m => m.t === 'err', 2000);
  verifica(e1 && /regno/.test(e1.m), `invito a un altro regno rifiutato: «${e1 && e1.m}»`);
  await invita(T, H);
  verifica(T.party && H.party && T.party.members.length === 2 && T.party.leader === T.id, `gruppo formato: ${T.party && T.party.members.map(m => m.n).join(', ')}, capo ${T.party && T.party.leader === T.id ? 'Roccia' : '?'}`);
  await invita(T, D);
  await H.finche(() => H.party && H.party.members.length === 3, 3000);
  const mm = H.party && H.party.members.find(m => m.id === D.id);
  verifica(H.party && H.party.members.length === 3 && mm && mm.rmax > 0 && mm.mhp > 0 && mm.via === 'loto', `stato del gruppo visto dal guaritore: 3 membri con vita/risorsa (${mm && `${mm.hp}/${mm.mhp}, ${mm.rt} ${mm.res}/${mm.rmax}`})`);
  // solo il capo invita ed espelle
  H.manda({ t: 'pinv', id: E.id });
  const e2 = await H.forse(m => m.t === 'err', 2000);
  H.manda({ t: 'pkick', id: D.id });
  const e3 = await H.forse(m => m.t === 'err', 2000);
  verifica(e2 && /capogruppo/.test(e2.m) && e3 && /capogruppo/.test(e3.m), `un membro non può invitare né espellere: «${e2 && e2.m}» / «${e3 && e3.m}»`);
  // uscita
  D.manda({ t: 'pleave' });
  await T.finche(() => T.party && T.party.members.length === 2, 3000);
  verifica(!D.party && T.party.members.length === 2, `uscita dal gruppo: il Monaco non ha più gruppo, ne restano ${T.party && T.party.members.length}`);
  // espulsione
  await invita(T, D);
  T.manda({ t: 'pkick', id: D.id });
  const esp = await D.forse(m => m.t === 'sys' && /espulso/.test(m.m), 2000);
  await T.finche(() => T.party && T.party.members.length === 2, 3000);
  verifica(esp && !D.party && T.party.members.length === 2, `espulsione: «${esp && esp.m}»`);
  // il capo esce: passa al primo rimasto; poi il gruppo di due si scioglie
  await invita(T, D);
  T.manda({ t: 'pleave' });
  await H.finche(() => H.party && H.party.members.length === 2, 3000);
  verifica(H.party && H.party.leader === H.id && !T.party, `il capo esce: il nuovo capo è ${H.party && H.party.leader === H.id ? 'Giada' : '?'}`);
  H.manda({ t: 'pleave' });
  await D.finche(() => !D.party, 3000);
  verifica(!D.party && !H.party, 'gruppo di due: se uno esce il gruppo si scioglie');
  await formaGruppo();
}

async function provaAuree() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  await H.tp(RADURA.x + 8, RADURA.z);
  await D.tp(RADURA.x - 8, RADURA.z);
  let da = Date.now();
  verifica(await T.tecnica('grido_guerra') === 'ok' && await T.finche(() => T.buff('grido_guerra'), 2000), "Aura di Guerra accesa sul difensore");
  const hOk = await H.finche(() => H.buff('grido_guerra'), 3000), dOk = await D.finche(() => D.buff('grido_guerra'), 3000);
  verifica(hOk && dOk, `aura ai compagni entro 15 m: guaritore ${hOk ? 'sì' : 'no'}, monaco ${dOk ? 'sì' : 'no'}`);
  const visto = D.fxLog.find(f => f.at >= da && f.k === 'aura' && f.s === T.id && f.a === 'grido_guerra');
  verifica(visto, "il compagno vede l'aura accendersi (effetto `aura`)");
  // entrata in vista: `au` nelle informazioni del giocatore
  await E.tp(RADURA.x + 150, RADURA.z);
  await E.finche(() => !E.ents.has(T.id), 2000);
  await E.tp(RADURA.x + 3, RADURA.z + 3);
  const tE = await E.finche(() => E.ents.get(T.id), 2000);
  verifica(tE && tE.au === 'grido_guerra', `chi arriva vede l'aura accesa nelle informazioni (au = ${tE && tE.au})`);
  verifica(!(await E.finche(() => E.buff('grido_guerra'), 2500)), "un estraneo vicino (stesso regno, fuori dal gruppo) non riceve l'aura");
  // fuori dal raggio
  await H.tp(RADURA.x + 25, RADURA.z);
  const via = await H.finche(() => !H.buff('grido_guerra'), 5000);
  await H.tp(RADURA.x + 8, RADURA.z);
  const torna = await H.finche(() => H.buff('grido_guerra'), 3000);
  verifica(via && torna, `a 25 m l'aura sparisce (${via ? 'sì' : 'no'}), tornando entro 15 m riappare (${torna ? 'sì' : 'no'})`);
  // fuori dal gruppo
  D.manda({ t: 'pleave' });
  const viaG = await D.finche(() => !D.buff('grido_guerra'), 5000);
  verifica(viaG, "uscendo dal gruppo l'aura del compagno sparisce");
  await invita(T, D);
  // aura senza gruppo (Monaco): resta solo sua
  verifica(await D.tecnica('respiro_drago') === 'ok' && await D.finche(() => D.buff('respiro_drago'), 2000), 'Aura del Drago accesa sul monaco');
  await attesa(2500);
  verifica(!T.buff('respiro_drago') && !H.buff('respiro_drago'), "l'Aura del Drago (senza raggio di gruppo) non passa ai compagni");
  // Aura degli Astri del guaritore: al difensore (entro 20 m)
  await H.tecnica('benedizione_astri');
  const astri = await T.finche(() => T.buff('benedizione_astri'), 3000);
  verifica(astri && H.buff('benedizione_astri'), "Aura degli Astri: anche il difensore la riceve");
  // spegnimento
  da = Date.now();
  await T.tecnica('grido_guerra');
  const spenta = await T.finche(() => !T.buff('grido_guerra'), 2000);
  const hSp = await H.finche(() => !H.buff('grido_guerra'), 4000);
  const fxOff = H.fxLog.find(f => f.at >= da && f.k === 'aura' && f.s === T.id && f.a === '');
  verifica(spenta && hSp && fxOff, `spegnimento: il difensore la perde, il compagno entro 4 s, effetto di spegnimento visto (${fxOff ? 'sì' : 'no'})`);
  // morte con l'aura accesa
  await T.tecnica('grido_guerra');
  await H.finche(() => H.buff('grido_guerra'), 3000);
  da = Date.now();
  await T.cmd('/vita 0', 300);
  const hMorte = await H.finche(() => !H.buff('grido_guerra'), 4000);
  const fxMorte = H.fxLog.find(f => f.at >= da && f.k === 'aura' && f.s === T.id && f.a === '');
  verifica(T.me.dead && hMorte && fxMorte, "il difensore cade: l'aura si spegne per tutti");
  await rinasci(T);
  await tuttiA(RADURA.x, RADURA.z);
  verifica(!T.buff('grido_guerra') && !(H.ents.get(T.id) || {}).au, `dopo la rinascita l'aura resta spenta (anche per chi guarda)`);
  await D.tecnica('respiro_drago');   // spegne quella del monaco
  await H.tecnica('benedizione_astri'); // spegne quella del guaritore
}

async function provaCure() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  await T.cmd('/spawn fantoccio 4 1');
  await attesa(400);
  const fant = () => H.vicino(e => e.k === 'm' && e.ty === 'fantoccio');
  for (const b of [T, H, D]) await b.cmd('/risorsa', 50);
  // alleato scelto
  await T.cmd('/vita 30');
  await attesa(300);
  let da = Date.now();
  const r1 = await H.tecnica('tocco_curativo', T.id);
  await attesa(400);
  const c1 = H.cure(da, T.id);
  verifica(r1 === 'ok' && c1.length && pct(T) > 30, `cura sull'alleato scelto: ${r1}, +${c1.map(c => c.v).join('+')} (difensore al ${pct(T)}%)`);
  verifica(D.cure(da, T.id).length > 0 && T.cure(da, T.id).length > 0, 'i numeri verdi della cura arrivano anche agli altri (effetto `heal` a chi è in vista)');
  // bersaglio nemico: il colpo finale di cura va al più ferito
  await H.cmd('/heal'); await T.cmd('/heal'); await D.cmd('/vita 40');
  await attesa(1100);
  da = Date.now();
  const f = fant();
  const r2 = await H.tecnica('tocco_curativo', f.id);
  await attesa(400);
  verifica(r2 === 'ok' && H.cure(da, D.id).length > 0, `con un nemico selezionato la cura va all'alleato più ferito (monaco al 40%): ${r2}`);
  // Grazia: i danni dei colpi base curano il più ferito
  await D.cmd('/heal'); await T.cmd('/vita 50');
  await attesa(300);
  da = Date.now();
  const r3 = await H.tecnica('dardo_luce', f.id);
  await attesa(500);
  const g = H.cure(da, T.id);
  verifica(r3 === 'ok' && g.length > 0, `Grazia: il Dardo di Luce sul fantoccio cura il difensore ferito (+${g.map(c => c.v).join('+')})`);
  // Risonanza: la Sfera Celeste su 3+ nemici, poi la cura del finale vale per tutti gli alleati vicini al bersaglio
  await attesa(1100);
  await H.cmd('/heal');
  await H.tecnica('sfera_celeste', f.id);
  const ris = await H.finche(() => H.buff('risonanza'), 2000);
  await T.cmd('/vita 50'); await D.cmd('/vita 50');
  await attesa(1100);
  da = Date.now();
  await H.tecnica('tocco_curativo', T.id);
  await attesa(400);
  verifica(ris && H.cure(da, T.id).length && H.cure(da, D.id).length, `Risonanza (${ris ? 'accesa' : 'spenta'}): il finale di cura cura difensore e monaco insieme`);
  // scudo sull'alleato
  await attesa(1100);
  await H.tecnica('scudo_giada', T.id);
  const sc = await T.finche(() => T.me.shield > 0, 2000);
  verifica(sc, `Scudo di Giada sul difensore: ${T.me.shield} punti`);
  // maestria del Loto: il finale cura il monaco
  await D.cmd('/vita 50'); await D.cmd('/risorsa');
  await attesa(200);
  da = Date.now();
  const r4 = await D.tecnica('vortice_interiore', f.id);
  await attesa(400);
  verifica(r4 === 'ok' && D.cure(da, D.id).length > 0, `maestria Fiore di Loto: il Vortice Interiore cura il monaco (+${D.cure(da, D.id).map(c => c.v).join('+')})`);
  // niente cure agli stranieri (altro regno), sì agli estranei del regno (fuori dall'arena)
  await S.tp(RADURA.x + 4, RADURA.z + 4);
  await E.tp(RADURA.x - 4, RADURA.z + 4);
  await S.cmd('/vita 50'); await E.cmd('/vita 50');
  await H.cmd('/heal'); await T.cmd('/heal'); await D.cmd('/heal');
  await attesa(1100);
  da = Date.now();
  const rE = await H.tecnica('tocco_curativo', E.id);
  await attesa(300);
  verifica(H.cure(da, E.id).length > 0, `fuori dall'arena si può curare chi è del proprio regno anche senza gruppo (${rE}, estraneo al ${pct(E)}%)`);
  await attesa(1100);
  await E.cmd('/heal');
  da = Date.now();
  await H.tecnica('tocco_curativo', S.id);
  await attesa(300);
  verifica(!H.cure(da, S.id).length, 'la cura scelta su uno straniero (altro regno) non lo cura');
  await E.cmd('/heal'); await S.cmd('/heal');
  await E.tp(RADURA.x + 300, RADURA.z); await S.tp(RADURA.x + 300, RADURA.z + 10);
}

async function provaDifensore() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  for (const b of [T, H, D]) await b.cmd('/heal', 50);
  // il monaco prende un'élite; il difensore la provoca con le Radici
  await D.tp(RADURA.x + 20, RADURA.z);
  await D.cmd('/spawn tigre_smeraldo 1 0.5');
  await attesa(300);
  const el = D.vicino(e => e.k === 'm' && e.ty === 'tigre_smeraldo');
  for (let i = 0; i < 6; i++) { D.manda({ t: 'atk', id: el.id }); await attesa(300); }
  const sulD = await D.finche(() => D.colpi(0, x => x.s === el.id && x.d === D.id).length, 4000);
  verifica(sulD, "l'élite attacca il monaco che l'ha colpita");
  await T.tp(D.x - 3, D.z);
  const rr = await T.tecnica('radici_monte');
  const da = Date.now();
  await attesa(4500);
  const dopo = T.colpi(da + 300, x => x.s === el.id && x.v !== undefined);
  const suT = dopo.filter(x => x.d === T.id).length, suD = dopo.filter(x => x.d === D.id).length;
  verifica(rr === 'ok' && suT >= 1 && suD === 0, `Radici della Montagna: l'élite passa al difensore (${suT} colpi su di lui, ${suD} sul monaco)`);
  await T.tp(el.x, el.z + 1.5); await T.cmd('/uccidi');
  // minaccia senza provocazione: il monaco apre, il difensore colpisce per qualche secondo
  await D.cmd('/spawn tigre_smeraldo 1 0.5');
  await attesa(300);
  const el2 = D.vicino(e => e.k === 'm' && e.ty === 'tigre_smeraldo' && e.hp > 0);
  for (let i = 0; i < 4; i++) { D.manda({ t: 'atk', id: el2.id }); await attesa(300); }
  await D.finche(() => D.colpi(0, x => x.s === el2.id && x.d === D.id).length, 4000);
  await T.tp(el2.x - 1.5, el2.z);
  await T.cmd('/risorsa');
  const t0 = Date.now();
  for (let i = 0; i < 16; i++) {
    T.manda({ t: 'atk', id: el2.id });
    if (i % 3 === 0) await T.tecnica(i % 6 === 0 ? 'martello_monte' : 'squarcio', el2.id, 1500);
    else await attesa(350);
  }
  const t1 = Date.now();
  for (let i = 0; i < 20; i++) { T.manda({ t: 'atk', id: el2.id }); D.manda({ t: 'atk', id: el2.id }); await attesa(300); }
  const ult = T.colpi(t1, x => x.s === el2.id && x.v !== undefined).slice(-3);
  if (!ult.length) console.log('  colpi della tigre dopo t0:', T.colpi(t0, x => x.s === el2.id).length, 'vita', el2.hp, 'distanze', Math.hypot(T.x - el2.x, T.z - el2.z).toFixed(1));
  verifica(ult.length && ult.every(x => x.d === T.id), `minaccia ×4: dopo qualche colpo del difensore l'élite lo prende di mira senza provocazione (ultimi colpi su ${ult.map(x => x.d === T.id ? 'difensore' : x.d === D.id ? 'monaco' : x.d).join(', ')})`);
  await T.tp(el2.x, el2.z + 1.5); await T.cmd('/uccidi');
  // branco sul guaritore: le Radici lo staccano (aspetta la ricarica di 20 s)
  while (Date.now() - da < 20500) await attesa(200);
  await H.tp(RADURA.x - 20, RADURA.z);
  await H.cmd('/spawn brigante_selva 5 1.5');
  await attesa(2500);
  const branco = H.mobVivi(12).filter(e => e.ty === 'brigante_selva').map(e => e.id);
  await T.tp(H.x + 1.5, H.z);
  await attesa(200);
  await T.tecnica('radici_monte');
  const db = Date.now();
  await attesa(4500);
  const cb = T.colpi(db + 300, x => branco.includes(x.s) && x.v !== undefined);
  const suH = cb.filter(x => x.d === H.id).length;
  verifica(cb.length >= 3 && suH === 0, `Radici sul branco di 5 Briganti: ${cb.filter(x => x.d === T.id).length} colpi sul difensore, ${suH} sul guaritore`);
  await pulisci(T);
  await rinasci(H);
}

async function provaSerie() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  await E.tp(RADURA.x + 2, RADURA.z + 3);
  await attesa(7500);   // la serie delle sezioni prima si spezza
  for (let i = 0; i < 5; i++) {
    await D.cmd('/spawn sciacallo_dune 1 0.5', 250);
    await D.cmd('/uccidi', 250);
  }
  await attesa(400);
  verifica(D.me.se === 5, `Serie del monaco che uccide: ×${D.me.se}`);
  verifica(T.me.se === 5 && H.me.se === 5, `Serie condivisa dai compagni vicini (entro 40 m): difensore ×${T.me.se}, guaritore ×${H.me.se}`);
  verifica(!E.me.se, `l'estraneo vicino non entra nella serie (×${E.me.se || 0})`);
  const occ = await T.finche(() => T.buff('occasione') && H.buff('occasione') && D.buff('occasione'), 2000);
  verifica(occ, 'Occasione alla quinta uccisione per tutti e tre');
  // l'Occasione è di chi la ha: il finale del monaco consuma solo la sua
  await T.cmd('/spawn fantoccio 1 0.5');
  await attesa(300);
  const f = D.vicino(e => e.k === 'm' && e.ty === 'fantoccio');
  await D.tecnica('vortice_interiore', f.id);
  await attesa(300);
  verifica(!D.buff('occasione') && T.buff('occasione') && H.buff('occasione'), "il finale del monaco consuma solo la sua Occasione");
  await E.tp(RADURA.x + 300, RADURA.z);
}

async function provaBottino() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  // esperienza e tael divisi in parti uguali fra i tre (+10% a compagno)
  const raccogli = (b, da, k) => b.log.slice(da).filter(m => m.t === 'gain' && m[k]).reduce((a, m) => a + m[k], 0);
  const iniz = [T, H, D].map(b => b.log.length);
  await D.cmd('/spawn brigante_selva 1 0.5', 250);
  await D.cmd('/uccidi', 600);
  const exp = [T, H, D].map((b, i) => raccogli(b, iniz[i], 'exp'));
  const tael = [T, H, D].map((b, i) => raccogli(b, iniz[i], 'tael'));
  // l'esperienza può differire di qualche punto per i bonus casuali dell'equipaggiamento (esperienza +%)
  const medio = exp.reduce((a, v) => a + v, 0) / 3;
  verifica(exp.every(v => v > 0 && Math.abs(v - medio) / medio < 0.15) && tael.every(v => v > 0 && v === tael[0]), `esperienza (${exp.join('/')}, a parte i bonus dell'equipaggiamento) e tael (${tael.join('/')}) divisi in parti uguali`);
  // confronto con l'uccisione da soli
  D.manda({ t: 'pleave' }); await attesa(300);
  const i0 = D.log.length;
  await D.cmd('/spawn brigante_selva 1 0.5', 250);
  await D.cmd('/uccidi', 600);
  const solo = raccogli(D, i0, 'exp');
  verifica(Math.abs(exp[2] / solo - 0.4) < 0.02, `in tre ognuno prende il 40% dell'esperienza di chi è solo (monaco: ${exp[2]} su ${solo}, ${(exp[2] / solo * 100).toFixed(0)}%)`);
  await formaGruppo();
  // compagno lontano: niente
  await H.tp(RADURA.x + 150, RADURA.z);
  const ih = H.log.length, it = T.log.length;
  await D.cmd('/spawn brigante_selva 1 0.5', 250);
  await D.cmd('/uccidi', 600);
  verifica(raccogli(H, ih, 'exp') === 0 && raccogli(T, it, 'exp') > 0, 'il compagno a 150 m non prende esperienza, quello vicino sì');
  await H.tp(RADURA.x + 2, RADURA.z);
  // bottino: un compagno raccoglie quello di chi ha ucciso, un estraneo no
  await E.tp(RADURA.x + 1, RADURA.z + 2);
  let drop = null;
  for (let i = 0; i < 25 && !drop; i++) {
    await D.cmd('/spawn orso_ventre_giada 1 0.5', 200);
    await D.cmd('/uccidi', 400);
    drop = D.vicino(e => e.k === 'd' && e.own === D.id);
  }
  if (drop) {
    await E.tp(drop.x, drop.z);
    E.manda({ t: 'pick', id: drop.id });
    const eE = await E.forse(m => m.t === 'err', 1500);
    await T.tp(drop.x, drop.z);
    T.manda({ t: 'pick', id: drop.id });
    const gT = await T.forse(m => m.t === 'gain' && m.item, 1500);
    verifica(eE && /appartiene/.test(eE.m) && gT, `bottino di chi ha ucciso: l'estraneo non lo prende («${eE && eE.m}»), il difensore (compagno) sì (${gT && gT.item})`);
  } else verifica(false, 'nessun bottino caduto dalle élite per la prova di raccolta');
  await E.tp(RADURA.x + 300, RADURA.z);
  // pezzi d'equipaggiamento adatti a tutto il gruppo, non solo a chi fa più danni
  await pulisci(T);
  const armi = {};
  await D.tp(RADURA.x + 30, RADURA.z + 30); await T.tp(RADURA.x + 31, RADURA.z + 30); await H.tp(RADURA.x + 29, RADURA.z + 30);
  for (let i = 0; i < 10; i++) {
    const vis0 = new Set(D.ents.keys());
    await D.cmd('/spawn generale 1 0.5', 300);
    await D.cmd('/uccidi', 600);
    for (const e of D.ents.values()) if (e.k === 'd' && !vis0.has(e.id) && ITEMS[e.it].type === 'weapon') armi[ITEMS[e.it].wt] = (armi[ITEMS[e.it].wt] || 0) + 1;
    // via i pezzi a terra (restano 2 minuti): così si contano solo i nuovi
    for (const e of [...D.ents.values()]) if (e.k === 'd') D.ents.delete(e.id);
  }
  const altri = (armi.sword || 0) + (armi.staff || 0);
  verifica(altri > 0, `armi cadute da 10 boss uccisi dal monaco: ${JSON.stringify(armi)} (spade e bastoni per i compagni: ${altri})`);
}

async function provaMissioni() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  for (const b of [T, H, D]) await b.cmd('/missione c27', 250);
  const ini = [T, H, D].map(b => b.log.length);
  await D.cmd('/spawn brigante_selva 2 0.5', 250);
  await D.cmd('/uccidi', 300); await D.cmd('/uccidi', 600);
  const av = [T, H, D].map((b, i) => b.log.slice(ini[i]).filter(m => m.t === 'mis_ev' && m.id === 'c27' && m.k === 'avanza').length);
  verifica(av.every(v => v === 2), `missione «uccidi» avanzata per tutti i compagni vicini: ${av.join('/')}`);
  await H.tp(RADURA.x + 150, RADURA.z);
  const ih = H.log.length;
  await D.cmd('/spawn brigante_selva 1 0.5', 250);
  await D.cmd('/uccidi', 600);
  verifica(!H.log.slice(ih).some(m => m.t === 'mis_ev' && m.id === 'c27'), 'il compagno lontano (150 m) non avanza');
  await H.tp(RADURA.x + 2, RADURA.z);
  // raccolta: l'oggetto della missione cade per chi ha la missione e solo lui può raccoglierlo
  await H.cmd('/missione c17', 300);
  let drop = null;
  for (let i = 0; i < 30 && !drop; i++) {
    await D.cmd('/spawn soldato_terracotta 1 0.5', 200);
    await D.cmd('/uccidi', 350);
    drop = D.vicino(e => e.k === 'd' && e.it === 'coccio_terracotta' && e.own === H.id);
  }
  if (!drop) return verifica(false, 'nessun coccio caduto per la missione del guaritore');
  await D.tp(drop.x, drop.z);
  D.manda({ t: 'pick', id: drop.id });
  const eD = await D.forse(m => m.t === 'err' || (m.t === 'gain' && m.item), 1500);
  verifica(eD && eD.t === 'err', `il coccio della missione del guaritore non lo raccoglie il compagno: «${eD && (eD.m || eD.item)}»`);
  await H.tp(drop.x, drop.z);
  const ih2 = H.log.length;
  H.manda({ t: 'pick', id: drop.id });
  const avH = await H.forse(m => m.t === 'mis_ev' && m.id === 'c17', 2000);
  verifica(avH || (D.ents.get(drop.id) === undefined && H.log.slice(ih2).some(m => m.t === 'gain')), `il guaritore lo raccoglie e la missione avanza: «${avH && avH.m}»`);
}

async function provaProva() {
  await formaGruppo();
  // al custode della Fenice
  for (const b of [T, H, D]) await b.cmd('/tp fenice', 300);
  await attesa(400);
  const cu = T.vicino(e => e.k === 'n' && e.role === 'custode');
  await tuttiA(cu.x + 1.5, cu.z + 1.5);
  T.manda({ t: 'trial', npc: cu.id, a: 'key' });
  await T.forse(m => m.t === 'trial', 2000);
  const dg = [T, H, D].map(b => b.aspetta(m => m.t === 'dg_start', 5000).catch(() => null));
  T.manda({ t: 'trial', npc: cu.id, a: 'open' });
  const st = await Promise.all(dg);
  verifica(st.every(Boolean), `Prova del Sigillo aperta dal capo: tutti e tre dentro (+${st[0] && st[0].kl})`);
  const ox = st[0].ox, oz = st[0].oz;
  await attesa(500);
  const dentro = (b) => b.x > ox - 20 && b.x < ox + 90;
  verifica([T, H, D].every(dentro), `posizioni nella cripta: ${[T, H, D].map(b => Math.round(b.x)).join(', ')}`);
  // la pianta di questa istanza: la variante della settimana, che il server manda con dg_start
  const pianta = componiPianta('cripta', st[0].pianta.v);
  // primo branco
  const pk = pianta.packs[0];
  await tuttiA(ox + pk.x, oz + pk.z - 2);
  await pulisci(T, 12);
  // il guaritore cade e rinasce all'ingresso della cripta
  await H.cmd('/vita 0', 400);
  const mH = H.me.dead;
  await attesa(1200);
  const stato = T.log.filter(m => m.t === 'dg').pop();
  await rinasci(H);
  verifica(mH && stato && stato.deaths === 1 && Math.hypot(H.x - (ox + DUNGEON.spawn[0]), H.z - (oz + DUNGEON.spawn[1])) < 4 && !H.me.dead, `morte del guaritore (morti: ${stato && stato.deaths}) e rinascita all'ingresso della cripta (${Math.round(H.x - ox)}, ${Math.round(H.z - oz)})`);
  // il monaco si disconnette e rientra: torna nel gruppo e nella cripta
  D.chiudi();
  await T.finche(() => T.party && T.party.members.length === 2, 3000);
  await attesa(500);
  const dg2 = D.aspetta(m => m.t === 'dg_start', 6000).catch(() => null);
  await D.entra();
  const st2 = await dg2;
  await D.finche(() => D.party && D.party.members.length === 3, 3000);
  verifica(st2 && st2.ox === ox && dentro(D), `il monaco si disconnette e rientra nella cripta (${D.x}, ${D.z})`);
  verifica(D.party && D.party.members.length === 3 && T.party.members.some(m => m.id === D.id), `...e torna nel gruppo (${D.party && D.party.members.map(m => m.n).join(', ')})`);
  // tutto il resto, boss per ultimo
  const t0 = Date.now();
  let fine = null;
  const premi = [T, H, D].map(b => b.aspetta(m => m.t === 'dg_reward', 150000).catch(() => null));
  for (let giro = 0; giro < 40 && !fine; giro++) {
    for (const p of pianta.packs.slice(1)) { await T.tp(ox + p.x, oz + p.z - 1); await pulisci(T, 14); }
    await T.tp(ox + pianta.boss.x, oz + pianta.boss.z - 14); await pulisci(T, 30);
    await T.tp(ox + pianta.boss.x, oz + pianta.boss.z - 2); await pulisci(T, 25);
    fine = T.log.find(m => m.t === 'dg' && m.done);
    const ult = T.log.filter(m => m.t === 'dg').pop();
    console.log(`  giro ${giro}: forze ${ult && ult.forces}%, custode ${ult && ult.boss}%, ${Math.round((Date.now() - t0) / 1000)} s`);
    if (Date.now() - t0 > 120000) break;
  }
  verifica(fine && fine.result, `Prova completata: ${fine && JSON.stringify(fine.result)}, morti ${fine && fine.deaths}`);
  const got = await Promise.all(premi);
  verifica(got.every(g => g && g.got && g.got.length >= 4), `ricompense a tutti e tre: ${got.map(g => g ? g.got.length + ' premi' : 'nessuna').join(' / ')}`);
  for (const b of [T, H, D]) b.manda({ t: 'tleave' });
  await attesa(800);
}

async function provaArena() {
  await formaGruppo();
  for (const b of [T, H, D, E]) await b.cmd('/heal', 50);
  // tutti sul pavimento dell'arena (fuori dalle nicchie sicure)
  await T.tp(8000, 20); await H.tp(8000, 26); await D.tp(8002, 20); await E.tp(7998, 20);
  await attesa(600);
  verifica(!safeZoneAt(T.x, T.z), `tutti nell'arena: ${[T, H, D, E].map(b => `${Math.round(b.x)},${Math.round(b.z)}`).join(' ')}`);
  // PvP fra non compagni: il monaco colpisce l'estraneo
  let da = Date.now();
  for (let i = 0; i < 6; i++) { D.manda({ t: 'atk', id: E.id }); await attesa(300); }
  verifica(D.colpi(da, x => x.s === D.id && x.d === E.id && x.v > 0).length > 0, "il monaco colpisce l'estraneo (stesso regno, fuori dal gruppo)");
  // niente fuoco amico: attacco e colpo ad area sui compagni
  da = Date.now();
  for (let i = 0; i < 6; i++) { D.manda({ t: 'atk', id: T.id }); await attesa(300); }
  await D.tecnica('calcio_gru');
  await attesa(300);
  const amico = D.colpi(da, x => x.s === D.id && (x.d === T.id || x.d === H.id));
  const nemico = D.colpi(da, x => x.s === D.id && x.d === E.id);
  verifica(amico.length === 0 && nemico.length > 0, `niente fuoco amico: ${amico.length} colpi sui compagni, ${nemico.length} sull'estraneo col Calcio della Gru`);
  // cure: al compagno sì, all'estraneo no
  await T.cmd('/vita 50'); await E.cmd('/vita 50'); await H.cmd('/risorsa');
  await attesa(1100);
  da = Date.now();
  await H.tecnica('tocco_curativo', T.id);
  await attesa(300);
  const cT = H.cure(da, T.id).length;
  await attesa(1100);
  da = Date.now();
  await H.tecnica('tocco_curativo', E.id);
  await attesa(300);
  verifica(cT > 0 && !H.cure(da, E.id).length, `nell'arena la cura va al compagno (${cT}) e non all'estraneo (${H.cure(da, E.id).length})`);
  // aura: all'estraneo no
  await T.tecnica('grido_guerra');
  await attesa(2500);
  verifica(H.buff('grido_guerra') && !E.buff('grido_guerra'), "nell'arena l'aura va al compagno e non all'estraneo");
  await T.tecnica('grido_guerra');
  // stordimenti ripetuti: pieno, metà, un quarto, respinto; un tentativo respinto non allunga l'immunità
  for (const b of [T, H, D, E]) await b.cmd('/heal', 50);
  await T.tp(E.x + 6, E.z); await H.tp(E.x + 8, E.z + 4); await D.tp(E.x + 1.5, E.z);
  E.st = [];
  const t0 = Date.now();
  await D.tecnica('palmo_chi', E.id); await attesa(300);
  await T.tecnica('carica', E.id); await attesa(300);
  await H.tecnica('sigillo_silenzio', E.id); await attesa(300);
  await T.tp(E.x + 6, E.z);
  const prime = [...E.st];
  while (Date.now() - t0 < 12600) await attesa(100);
  await D.tp(E.x + 1.5, E.z);
  await D.tecnica('palmo_chi', E.id);   // entro 15 s: respinto
  await attesa(300);
  const respinto = E.st.length === prime.length;
  while (Date.now() - t0 < 17500) await attesa(100);
  await T.tp(E.x + 6, E.z);
  await T.tecnica('carica', E.id);      // oltre 15 s dal terzo stordimento: di nuovo pieno
  await attesa(400);
  const ultimo = E.st.length > prime.length ? E.st[E.st.length - 1] : 0;
  verifica(prime.length === 3 && prime[1] < prime[0] && prime[2] < prime[1], `stordimenti ripetuti in PvP: ${prime.join(' → ')} ms`);
  verifica(respinto && ultimo >= 900, `il quarto è respinto e non rinnova l'immunità: dopo 15 s dal terzo lo stordimento torna pieno (${ultimo} ms)`);
  for (const b of [T, H, D, E]) await b.cmd('/tp fenice', 200);
}

async function provaDisconnessione() {
  await formaGruppo();
  await tuttiA(RADURA.x, RADURA.z);
  H.chiudi();
  await T.finche(() => T.party && T.party.members.length === 2, 3000);
  verifica(T.party && T.party.members.length === 2, 'il guaritore si disconnette: nel gruppo restano in due');
  await attesa(400);
  await H.entra();
  await H.finche(() => H.party && H.party.members.length === 3, 3000);
  verifica(H.party && H.party.members.length === 3 && T.party.members.some(m => m.id === H.id), `rientra entro pochi minuti: di nuovo nel gruppo (${H.party && H.party.members.map(m => m.n).join(', ')})`);
  // gruppo di due: chi resta non perde il gruppo mentre l'altro rientra
  D.manda({ t: 'pleave' });
  await T.finche(() => T.party && T.party.members.length === 2, 3000);
  H.chiudi();
  await attesa(600);
  const restaT = !!T.party;
  await H.entra();
  await H.finche(() => H.party, 3000);
  verifica(restaT && H.party && T.party && H.party.members.length === 2, `gruppo di due: il capo resta in gruppo durante la disconnessione (${restaT ? 'sì' : 'no'}) e il guaritore ci rientra`);
  await formaGruppo();
}

// ---------------------------------------------------------------- misura della tenuta
async function misura(secondi) {
  await formaGruppo();
  for (const b of [T, H, D]) await b.cmd('/heal', 50);
  await D.cmd('/tp fenice');   // il monaco resta fuori: solo difensore e guaritore
  const cx = RADURA.x + 10, cz = RADURA.z + 10;
  await pulisci(T);
  await T.tp(cx, cz);
  await H.tp(cx - 12, cz);
  for (const b of [T, H]) { await b.cmd('/heal', 50); await b.cmd('/risorsa', 50); }
  await T.tecnica('grido_guerra'); await H.tecnica('benedizione_astri');
  await T.cmd(`/spawn ${ELITE} 1 1`, 250);
  await T.cmd(`/spawn ${BRANCO} 5 2`, 400);
  const t0 = Date.now(), fine = t0 + secondi * 1000;
  let minimo = 100, morti = 0, branchi = 1, ultimoCampione = t0;
  const campioni = [];
  // il difensore: Radici appena possibile, finale con l'Ira, colpo ad area se attorno ci sono 3+ nemici
  const tank = (async () => {
    while (Date.now() < fine) {
      if (T.me.dead) { morti++; await rinasci(T); await T.tp(cx, cz); continue; }
      const vivi = T.mobVivi(12);
      if (!vivi.filter(e => e.ty === BRANCO).length && Date.now() < fine - 5000) { await T.cmd(`/spawn ${BRANCO} 5 2`, 200); branchi++; continue; }
      if (!vivi.length) { await attesa(200); continue; }
      const el = vivi.find(e => e.ty === ELITE) || vivi[0];
      T.manda({ t: 'atk', id: el.id });
      if (await T.tecnica('radici_monte', 0, 600) === 'ok') continue;
      if (T.me.res >= 40 && await T.tecnica('martello_monte', el.id, 1200) === 'ok') { await attesa(1000); continue; }
      const r = await T.tecnica(vivi.length >= 3 ? 'fendente' : 'squarcio', el.id, 1200);
      await attesa(r === 'ok' ? 1000 : 250);
    }
  })();
  // il guaritore: scudo sul difensore a ricarica, cura sotto il 75%, altrimenti Dardo (la Grazia cura)
  const healer = (async () => {
    while (Date.now() < fine && !SENZA_CURE) {
      if (H.me.dead) { await rinasci(H); await H.tp(cx - 12, cz); continue; }
      const tm = H.party && H.party.members.find(m => m.id === T.id);
      const tp = tm ? tm.hp / tm.mhp : 1;
      if (await H.tecnica('scudo_giada', T.id, 600) === 'ok') continue;
      if (tp < 0.75 && await H.tecnica('tocco_curativo', T.id, 1200) === 'ok') { await attesa(1000); continue; }
      const nem = H.mobVivi(22).find(e => e.ty === ELITE) || H.mobVivi(22)[0];
      if (nem) { const r = await H.tecnica('dardo_luce', nem.id, 2500); await attesa(r === 'ok' ? 100 : 300); } else await attesa(300);
    }
  })();
  const camp = (async () => {
    while (Date.now() < fine) {
      if (T.me && !T.me.dead) minimo = Math.min(minimo, T.me.hp / T.me.mhp * 100);
      if (Date.now() - ultimoCampione > 5000) { ultimoCampione = Date.now(); campioni.push(Math.round(T.me.hp / T.me.mhp * 100)); }
      await attesa(100);
    }
  })();
  await Promise.all([tank, healer, camp]);
  const dur = (Date.now() - t0) / 1000;
  const subiti = T.colpi(t0, x => x.d === T.id && x.s !== T.id);
  const danni = subiti.reduce((a, x) => a + (x.v || 0), 0), assorbiti = subiti.reduce((a, x) => a + (x.ab || 0), 0);
  const cureT = T.cure(t0, T.id).reduce((a, x) => a + x.v, 0);
  const cureH = H.cure(t0).filter(c => c.d === T.id || c.d === H.id).reduce((a, x) => a + x.v, 0);
  const inflitti = T.colpi(t0, x => x.s === T.id).reduce((a, x) => a + (x.v || 0), 0);
  const fuori = T.colpi(t0, x => x.s !== T.id && x.d === H.id && x.v > 0).length;
  const ris = {
    secondi: Math.round(dur), danniSubitiAlSecondo: Math.round(danni / dur), assorbitiDalloScudoAlSecondo: Math.round(assorbiti / dur),
    cureAlSecondo: Math.round(cureH / dur), cureSulDifensoreAlSecondo: Math.round(cureT / dur),
    vitaMinimaPct: Math.round(minimo), morti, branchi, danniInflittiAlSecondo: Math.round(inflitti / dur), colpiSulGuaritore: fuori,
    vitaMax: T.me.mhp, difesa: T.me.def, colpiRicevuti: subiti.length, mancati: subiti.filter(x => x.miss).length, vitaOgni5s: campioni.join(' '),
  };
  await pulisci(T);
  await T.tecnica('grido_guerra'); await H.tecnica('benedizione_astri');
  return ris;
}

// ---------------------------------------------------------------- avvio
async function main() {
  await avvia();
  T = new Bot('difensore'); H = new Bot('guaritore'); D = new Bot('danno'); E = new Bot('estraneo'); S = new Bot('straniero');
  for (const b of [T, H, D, E, S]) await b.entra();
  for (const b of [T, H, D, E, S]) await b.cmd('/tp fenice', 50);
  await attesa(500);
  if (MISURA) {
    const tutte = [];
    for (let i = 0; i < RIPETI; i++) { const r = await misura(SECONDI); tutte.push(r); console.log(JSON.stringify(r)); }
    verifica(tutte.length === RIPETI, `misura della tenuta (${RIPETI} × ${SECONDI} s)`);
    return;
  }
  const SEZIONI = [
    ['gruppo', provaGruppo], ['auree', provaAuree], ['cure', provaCure], ['difensore', provaDifensore], ['serie', provaSerie],
    ['bottino', provaBottino], ['missioni', provaMissioni], ['prova', provaProva], ['arena', provaArena], ['disconnessione', provaDisconnessione],
  ];
  for (const [n, f] of SEZIONI) {
    if (!sezione(n)) continue;
    console.log(`\n--- ${n}`);
    try { await f(); } catch (e) { console.error('ERRORE in', n, e); esiti.push([false, `${n}: ${e.message}`]); }
    for (const b of [T, H, D]) if (b.me && b.me.dead) await rinasci(b);
  }
}

try { await main(); } catch (e) { console.error('ERRORE', e); esiti.push([false, String(e)]); }
for (const b of [T, H, D, E, S]) if (b) b.chiudi();
srv.kill('SIGTERM');
await attesa(500);
const ko = esiti.filter(e => !e[0]).length;
console.log(`\n${esiti.length - ko}/${esiti.length} verifiche riuscite`);
process.exit(ko ? 1 : 0);
