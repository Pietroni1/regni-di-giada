#!/usr/bin/env node
// Simulazione del combattimento SENZA browser: un bot per ogni Via gioca una rotazione sensata contro i fantocci
// e stampa danni al secondo, ripartizione per tecnica, risorsa sprecata, tempo della barra Suprema e Squilibri.
//
//   node tools/sim/simula.mjs [--livello 30] [--secondi 60] [--vie fulmine,arco] [--bersagli 1|5]
//                             [--ripeti 1] [--velocita 1] [--paralleli 8] [--dettagli] [--json file.json]
//   opzioni per indagare: --spalle (il bot sta alle spalle del bersaglio), --senza medio|potente (rotazione senza quegli scarichi),
//                         --vitalita 0.33 (quota di punti statistica in vitalità), --radura x,z, --par chiave=valore (soglie delle rotazioni)
//
// Ogni prova avvia da sé un server (porta libera, database temporaneo), registra l'account GM `admin`, crea il
// personaggio, lo porta al livello scelto (/level), imposta la Via (/via), gli dà l'arma del suo livello, distribuisce i
// punti statistica (2 al valore primario e 1 alla vitalità; la Montagna, da difensore, 1 e 2) e i punti abilità (in parti
// uguali fra le tecniche con `ruolo` e la Suprema), si sposta in una radura lontana dai mostri (/tp -228 -228), crea i
// fantocci (uno, oppure un gruppo stretto: `/spawn fantoccio 1 0.05` in punti precisi) e combatte per il tempo scelto.
// Il bot parla il protocollo vero (WebSocket /ws) e rispetta ricariche e GCD come li comunica il server (`cd`, `cast`).
// I danni si leggono dagli eventi `fx` (`k: 'hit'`), gli Squilibri da `k: 'post'`, risorsa e barra Suprema da `me` e `r`.
// --velocita N accelera l'orologio del server (tools/sim/orologio.mjs): comodo per tarare (fino a 4, con 4 prove in
// parallelo, i risultati coincidono con quelli veri), ma i numeri da pubblicare vanno presi a velocità 1.
// Per aggiungere o cambiare una rotazione: tabella ROTAZIONI qui sotto.
import { spawn } from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import WebSocket from 'ws';
import { CLASSES, VIE, SKILLS, BUFFS, ITEMS, PTS_MAX, SUPREMA, supremaOf } from '../../shared/data.js';

const QUI = path.dirname(fileURLToPath(import.meta.url));
const RADICE = path.resolve(QUI, '..', '..');

// ------------------------------------------------------------------ opzioni
function leggiOpzioni(argv) {
  const o = { livello: 30, secondi: 60, vie: Object.keys(VIE), bersagli: 1, ripeti: 1, velocita: 1, paralleli: 0, spalle: false, senza: null, dettagli: false, json: null, radura: [-228, -228], par: {} };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    switch (a) {
      case '--livello': o.livello = Math.max(1, parseInt(v(), 10) || 30); break;
      case '--secondi': o.secondi = Math.max(5, parseFloat(v()) || 60); break;
      case '--vie': o.vie = v().split(',').map((s) => s.trim()).filter(Boolean); break;
      case '--bersagli': o.bersagli = Math.max(1, Math.min(8, parseInt(v(), 10) || 1)); break;
      case '--ripeti': o.ripeti = Math.max(1, parseInt(v(), 10) || 1); break;
      case '--velocita': o.velocita = Math.max(1, Math.min(8, parseFloat(v()) || 1)); break;
      case '--paralleli': o.paralleli = Math.max(1, parseInt(v(), 10) || 1); break;
      case '--spalle': o.spalle = true; break;
      case '--senza': o.senza = v(); break;
      case '--dettagli': o.dettagli = true; break;
      case '--json': o.json = v(); break;
      case '--vitalita': o.vitalita = Math.max(0, Math.min(1, parseFloat(v()))); break;
      case '--par': for (const kv of v().split(',')) { const [k, x] = kv.split('='); o.par[k] = Number(x); } break;   // prove sulle soglie della rotazione
      case '--radura': o.radura = v().split(',').map(Number); break;
      case '--aiuto': case '-h': case '--help':
        console.log('Uso: node tools/sim/simula.mjs [--livello 30] [--secondi 60] [--vie fulmine,arco] [--bersagli 1|5]\n' +
          '       [--ripeti 1] [--velocita 1] [--paralleli 8] [--dettagli] [--json file]\n' +
          '       per indagare: [--spalle] [--senza medio|potente] [--vitalita 0.33] [--radura x,z] [--par chiave=valore,...]\n' +
          `Vie: ${Object.keys(VIE).join(', ')}`);
        process.exit(0);
      // eslint-disable-next-line no-fallthrough
      default: console.error(`Opzione sconosciuta: ${a} (prova --aiuto)`); process.exit(1);
    }
  }
  for (const v of o.vie) if (!VIE[v]) { console.error(`Via sconosciuta: ${v}. Vie: ${Object.keys(VIE).join(', ')}`); process.exit(1); }
  // a velocità reale un server pesa poco (8 insieme vanno bene su 4 processori); accelerato, uno per processore
  if (!o.paralleli) o.paralleli = Math.max(1, Math.min(o.velocita > 1 ? 4 : 8, os.cpus().length * (o.velocita > 1 ? 1 : 2)));
  return o;
}

// ------------------------------------------------------------------ server di prova
function portaLibera() {
  return new Promise((ok, no) => {
    const s = net.createServer();
    s.unref();
    s.on('error', no);
    s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => ok(p)); });
  });
}

const figli = new Set();
process.on('exit', () => { for (const f of figli) try { f.kill(); } catch { /* già chiuso */ } });
process.on('SIGINT', () => process.exit(130));

async function avviaServer(velocita) {
  const porta = await portaLibera();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'regni-sim-'));
  const args = [];
  if (velocita !== 1) args.push('--import', pathToFileURL(path.join(QUI, 'orologio.mjs')).href);
  args.push(path.join(RADICE, 'server', 'index.js'));
  const figlio = spawn(process.execPath, args, {
    cwd: RADICE, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, PORT: String(porta), DB_FILE: path.join(dir, 'db.json'), SIM_VELOCITA: String(velocita) },
  });
  figli.add(figlio);
  let errori = '';
  figlio.stderr.on('data', (d) => { errori += d; });
  await new Promise((ok, no) => {
    const scade = setTimeout(() => no(new Error('Il server di prova non parte.\n' + errori)), 20000);
    figlio.stdout.on('data', (d) => { if (String(d).includes('server avviato')) { clearTimeout(scade); ok(); } });
    figlio.on('exit', (c) => { clearTimeout(scade); no(new Error(`Il server di prova si è chiuso (codice ${c}).\n${errori}`)); });
  });
  const chiudi = () => {
    figli.delete(figlio);
    try { figlio.kill(); } catch { /* già chiuso */ }
    try { fs.rmSync(dir, { recursive: true, force: true }); } catch { /* pazienza */ }
  };
  return { porta, chiudi, errori: () => errori };
}

// ------------------------------------------------------------------ rotazioni
// Ogni rotazione riceve lo stato S e restituisce l'id della tecnica da usare al prossimo GCD.
//   S.ok(id)   conosciuta, ricarica pronta, risorsa e punti sufficienti      S.sa(id)  conosciuta a questo livello
//   S.b(id)    millisecondi rimasti di un effetto su di sé                   S.dot(id) millisecondi rimasti sul bersaglio
//   S.eta(id)  millisecondi dall'ultimo uso (Infinity se mai usata)
//   S.res, S.rmax, S.pts, S.multi (più bersagli), S.catena (passo della sequenza del Monaco), S.ultimo ('scarico' | 'altro')
// Regola comune: scarico potente appena possibile (a 4-5 punti per chi li ha), scarico medio per tenere attivi i suoi
// effetti o quando la risorsa avanza (`avanza`), accumuli per il resto, Suprema appena carica.
const avanza = (S, med, pot, margine = 0) => S.ok(med) && (!S.sa(pot) || S.res - S.costo(med) >= S.costo(pot) - S.pct(S.par.margine ?? margine));

function rotLama(S, c) {
  if (S.ok(S.sup)) return S.sup;
  if (!S.multi) {
    if (S.b('scintilla') && S.ok('lama_tuono')) return 'lama_tuono';
    if (S.dot('affondo_ira') < 1500 && S.ok('affondo_ira')) return 'affondo_ira';   // la ferita va tenuta aperta
    if (S.ok(c.pot1)) return c.pot1;
    if (S.ok('squarcio')) return 'squarcio';
    if (!S.sa(c.pot1) && S.ok('affondo_ira')) return 'affondo_ira';
    return 'fendente';
  }
  if (avanza(S, c.medA, c.potA, c.margine)) return c.medA;
  if (S.ok(c.potA)) return c.potA;
  return 'fendente';
}

function rotOmbra(S, c) {
  const pot = S.multi ? c.potA : c.pot1, med = S.multi ? c.medA : 'taglio_netto';
  if (S.ok(S.sup) && (S.pts <= 2 || !S.ok(pot))) return S.sup;                     // la Suprema riempie i punti: prima scarico quelli che ho
  if (c.veleno && S.dot('danza_lame') < 1500 && S.ok('danza_lame')) return 'danza_lame';   // veleno sempre attivo (+25% agli scarichi potenti)
  if (S.b('fuoco_rapido') && S.ok('pioggia_frecce')) return 'pioggia_frecce';       // Pioggia gratuita
  if (S.ok(pot) && (S.pts >= (S.par.soglia ?? PTS_MAX) || (S.pts >= PTS_MAX - 1 && S.res >= S.rmax - 15))) return pot;
  if (S.res >= S.rmax - 20 && S.ok(med)) return med;                                  // Energia quasi al massimo: non sprecarla
  if (S.pts <= PTS_MAX - 2 && S.ok('agguato')) return 'agguato';
  if (S.pts <= PTS_MAX - 1 && S.ok('freccia_inchiodante')) return 'freccia_inchiodante';
  // scarico medio solo con l'Energia che avanza: quella per lo scarico potente deve esserci quando i punti saranno 5
  // (ogni accumulo che manca rende circa 15 di Energia fra rigenerazione e generazione)
  if (avanza(S, med, pot, (PTS_MAX - S.pts) * (S.par.perPunto ?? 15))) return med;
  return 'colpo_rapido';
}

function rotMonaco(S, c) {
  const pot = S.multi ? c.potA : c.pot1;
  if (S.ok(S.sup) && (S.pts <= 2 || !S.ok(pot))) return S.sup;
  if (c.fiore && S.dot('onda_chi') < 1500 && S.ok('onda_chi')) return 'onda_chi';   // Fiore di Loto sempre attivo (+20% agli scarichi potenti)
  if (S.multi && !S.par.catenaArea) {
    // contro un gruppo la sequenza non conviene (Pugno e Palmo colpiscono un solo nemico): Calcio della Gru per le Sfere,
    // scarico medio ad area con il Chi che avanza, scarico potente ad area a Sfere piene
    if (S.pts >= PTS_MAX && S.ok(pot)) return pot;
    if (avanza(S, c.medA, pot, (PTS_MAX - S.pts) * (S.par.perPunto ?? 15))) return c.medA;
    return 'calcio_gru';
  }
  if (S.pts >= (S.par.soglia ?? PTS_MAX - 1) && S.ok(pot)) return pot;
  if (S.multi && avanza(S, c.medA, pot, c.margine)) return c.medA;
  if (!S.multi && S.catena === 0 && avanza(S, 'palmo_chi', pot, c.margine)) return 'palmo_chi';   // Chi che avanza: un Palmo fuori sequenza (a sequenza appena chiusa non la rompe)
  const passo = ['pugno_ferro', 'calcio_gru', 'palmo_chi'][S.catena] || 'pugno_ferro';
  if (passo === 'palmo_chi' && !S.ok('palmo_chi')) return S.multi ? 'calcio_gru' : 'pugno_ferro';   // Chi insufficiente: accumulo
  return passo;                                                                      // Pugno → Calcio → Palmo = Forma Perfetta
}

function rotTempesta(S) {
  const pot = S.multi ? 'diluvio_folgori' : 'giudizio_cielo', med = S.multi ? 'tempesta_saette' : 'lancia_luce';
  if (S.ok(S.sup) && (S.pts <= 3 || !S.ok(pot))) return S.sup;
  if (S.ok('marchio_tuono') && S.dot('marchio_tuono') < 3000) return 'marchio_tuono';
  if (S.ok(pot) && S.pts >= (S.par.soglia ?? PTS_MAX)) return pot;
  if (S.pts <= PTS_MAX - 2 && S.ok('sfera_celeste')) return 'sfera_celeste';
  // scarico medio istantaneo fra un lancio e l'altro se il Mana avanza; a raffica finché la riserva è sopra il 60%
  if (avanza(S, med, pot, 0) && (S.ultimo !== 'scarico' || S.res >= S.pct(S.par.raffica ?? 60))) return med;
  return 'dardo_luce';
}

function rotBenedizione(S) {
  // prova di danni di un guaritore: accumuli + Lancia di Luce; tiene su di sé Benedizione e Loto Rigenerante
  // e scarica le Cariche nello Scudo di Giada (le cure non contano nei danni, ma riempiono la barra Suprema)
  if (!S.b('benedizione') && S.ok('benedizione')) return 'benedizione';
  if (S.eta('loto_rigenerante') > 12000 && S.pts <= PTS_MAX - 1 && S.ok('loto_rigenerante')) return 'loto_rigenerante';
  if (S.ok(S.sup)) return S.sup;
  if (S.pts >= PTS_MAX - 2 && S.ok('scudo_giada')) return 'scudo_giada';
  if (S.pts <= PTS_MAX - 2 && S.ok('sfera_celeste')) return 'sfera_celeste';
  if (S.ok('lancia_luce') && S.res >= S.pct(25) && (S.ultimo !== 'scarico' || S.res >= S.pct(S.par.raffica ?? 60))) return 'lancia_luce';
  return 'dardo_luce';
}

// gcd: scelta a ogni GCD. fuori: tecniche fuori dal GCD, usate appena pronte se la condizione è vera.
// distanza: a quanti metri dal bersaglio sta il bot.
const ROTAZIONI = {
  fulmine: {
    distanza: 1.6,
    gcd: (S) => rotLama(S, { pot1: 'lama_tuono', potA: 'tempesta_lame', medA: 'arco_folgore', margine: 0 }),
    fuori: { furia_tempesta: (S) => S.res <= S.rmax - 25, carica: (S) => S.res <= S.rmax - 20 },
  },
  montagna: {
    distanza: 1.6, vitalita: 2 / 3,   // il difensore mette due punti su tre in vitalità
    gcd: (S) => rotLama(S, { pot1: 'martello_monte', potA: 'valanga', medA: 'scossa', margine: 0 }),
    fuori: { sfida: (S) => S.res <= S.rmax - 10, pelle_pietra: () => true },
  },
  pugnali: {
    distanza: 1.6,
    gcd: (S) => rotOmbra(S, { pot1: 'taglio_finale', potA: 'ventaglio_veleno', medA: 'danza_lame', veleno: true }),
    fuori: { marchio_morte: (S) => S.pts <= 1, passo_ombra: (S) => S.pts <= PTS_MAX - 1 && (S.multi || S.pts >= 2) },
  },
  arco: {
    distanza: 10,
    gcd: (S) => rotOmbra(S, { pot1: 'freccia_perforante', potA: 'raffica_esplosiva', medA: 'pioggia_frecce' }),
    fuori: { occhio_falco: () => true },
  },
  ferro: {
    distanza: 1.6,
    gcd: (S) => rotMonaco(S, { pot1: 'raffica', potA: 'onda_vuoto', medA: 'ascesa_drago', margine: 0 }),
    fuori: { spirito_tigre: () => true, pelle_bronzo: () => true },
  },
  loto: {
    distanza: 1.6,
    gcd: (S) => rotMonaco(S, { pot1: 'vortice_interiore', potA: 'mille_petali', medA: 'onda_chi', fiore: true, margine: 0 }),
    fuori: { sigillo_interiore: () => true, meditazione: () => true },
  },
  tempesta: { distanza: 12, gcd: rotTempesta, fuori: { occhio_ciclone: () => true } },
  benedizione: { distanza: 12, gcd: rotBenedizione, fuori: { preghiera_antenati: () => true } },
};

// ------------------------------------------------------------------ bot
const ARMA_DI = { fulmine: 'sword', montagna: 'sword', pugnali: 'daggers', arco: 'bow', ferro: 'fists', loto: 'fists', tempesta: 'staff', benedizione: 'staff' };
const BERSAGLIATE = ['strike', 'aoe_target', 'debuff', 'taunt'];

class Bot {
  constructor(via, opt, porta) {
    this.via = via; this.opt = opt; this.porta = porta;
    this.cls = VIE[via].cls;
    this.rot = ROTAZIONI[via];
    this.sup = (supremaOf(this.cls) || {}).id || null;
    this.p0 = performance.now();
    this.me = null; this.id = 0; this.pos = { x: 0, z: 0 }; this.casa = null;
    this.inv = null; this.eq = null;
    this.mob = new Map();          // id -> { ty, x, z, r }
    this.bersagli = []; this.primo = 0;
    this.attese = [];
    this.cds = {}; this.blocco = {}; this.buffs = {}; this.dots = {};
    this.gcdFino = 0; this.lancio = null; this.attesa = null; this.prossimoAtk = 0; this.tpFino = 0;
    this.ultimo = 'altro'; this.ultimoUso = {};
    this.inCorso = false; this.t0 = 0;
    // misure
    this.danni = {}; this.colpi = {}; this.usi = {}; this.spesa = {};
    this.totale = 0; this.totaleSenzaSquil = 0; this.subiti = 0;
    this.squilibri = 0; this.squilFino = {};
    this.rifiuti = 0; this.errori = {}; this.lanciInterrotti = 0;
    this.tMax = 0; this.tRis = 0; this.resPrima = null;
    this.supDa = 0; this.supPronta = false; this.riempimenti = [];
    this.ostili = new Set();
    this.chiuso = null;
  }

  // tempo di gioco in millisecondi (accelerato come il server)
  ora() { return (performance.now() - this.p0) * this.opt.velocita; }
  dormi(ms) { return new Promise((r) => setTimeout(r, ms / this.opt.velocita)); }

  manda(o) { if (this.ws.readyState === 1) this.ws.send(JSON.stringify(o)); }
  chat(m) { this.manda({ t: 'chat', m }); }

  attendi(descr, cond, ms = 8000) {
    return new Promise((ok, no) => {
      const a = { cond, ok, scade: setTimeout(() => { this.attese = this.attese.filter((x) => x !== a); no(new Error(`[${this.via}] tempo scaduto: ${descr}${this.ultimoErr ? ' (' + this.ultimoErr + ')' : ''}`)); }, ms) };
      this.attese.push(a);
      this.controllaAttese();
    });
  }
  controllaAttese() {
    for (const a of [...this.attese]) {
      let v; try { v = a.cond(); } catch { v = false; }
      if (v) { clearTimeout(a.scade); this.attese = this.attese.filter((x) => x !== a); a.ok(v); }
    }
  }

  async collega() {
    this.ws = new WebSocket(`ws://127.0.0.1:${this.porta}/ws`);
    await new Promise((ok, no) => { this.ws.once('open', ok); this.ws.once('error', no); });
    this.ws.on('message', (raw) => { let m; try { m = JSON.parse(raw); } catch { return; } this.ricevi(m); this.controllaAttese(); });
    this.ws.on('close', () => { this.chiuso = this.chiuso || 'collegamento chiuso'; });
  }

  // ---------------------------------------------------------------- messaggi dal server
  ricevi(m) {
    const ora = this.ora();
    switch (m.t) {
      case 'auth_ok': this.autenticato = true; break;
      case 'auth_err': this.ultimoErr = m.m; break;
      case 'chars': this.personaggi = m.list; break;
      case 'kicked': this.chiuso = m.m; break;
      case 'enter': this.id = m.id; this.pos = { x: m.x, z: m.z }; break;
      case 'pos': this.pos = { x: m.x, z: m.z }; this.nPos = (this.nPos || 0) + 1; break;
      case 'inv': this.inv = m.inv; this.eq = m.eq; break;
      case 'err': this.ultimoErr = m.m; if (this.inCorso) this.errori[m.m] = (this.errori[m.m] || 0) + 1; break;
      case 'me':
        this.me = m;
        this.buffs = {};
        for (const b of m.buffs) this.buffs[b.b] = ora + b.ms;
        this.misuraRisorsa(ora, m.res, m.su);
        break;
      case 'r':
        if (!this.me) break;
        this.me.hp = m.hp; this.me.res = m.res; this.me.pts = m.pts; this.me.sl = m.sl || 0; this.me.su = m.su || 0;
        this.misuraRisorsa(ora, m.res, m.su || 0);
        break;
      case 'v':
        for (const e of m.a || []) if (e.k === 'm') this.mob.set(e.id, { ty: e.ty, x: e.x, z: e.z, r: e.r });
        for (const id of m.r || []) this.mob.delete(id);
        break;
      case 'dot': (this.dots[m.d] || (this.dots[m.d] = {}))[m.s] = ora + m.ms; break;
      case 'cast':
        this.lancio = { sid: m.s, fino: ora + m.ms, costo: this.attesa && this.attesa.sid === m.s ? this.attesa.costo : 0 };
        if (m.gcd) this.gcdFino = ora + m.gcd;
        this.attesa = null;
        break;
      case 'castend': if (!m.ok && this.lancio && this.inCorso) this.lanciInterrotti++; if (!m.ok) this.lancio = null; else if (this.lancio) this.lancio.finito = true; break;
      case 'skfail':
        if (this.inCorso) this.rifiuti++;
        if (this.attesa && this.attesa.sid === m.s) { this.gcdFino = this.attesa.gcdPrima; this.attesa = null; }
        this.blocco[m.s] = 0;
        break;
      case 'cd': this.usata(m, ora); break;
      case 'fx': this.effetto(m, ora); break;
    }
  }

  misuraRisorsa(ora, res, su) {
    if (this.inCorso && this.resPrima) {
      const dt = ora - this.resPrima.t;
      this.tRis += dt;
      if (this.resPrima.res >= this.me.rmax - 0.5) this.tMax += dt;
    }
    this.resPrima = { t: ora, res };
    if (this.inCorso && this.sup && this.me.lvl >= SUPREMA.lvl && su >= SUPREMA.max && !this.supPronta) {
      this.supPronta = true;
      this.riempimenti.push((ora - this.supDa) / 1000);
    }
  }

  // il server conferma l'uso di una tecnica: ricarica, GCD e previsione locale di risorsa e punti (poi arriva `me`)
  usata(m, ora) {
    const sk = SKILLS[m.s];
    if (!sk) return;
    this.ultimoUso[m.s] = ora;
    if (m.ms) this.cds[m.s] = ora + m.ms;
    if (m.gcd) this.gcdFino = ora + m.gcd;
    let costo = 0;
    if (this.lancio && this.lancio.sid === m.s) { costo = this.lancio.costo; this.lancio = null; }
    else if (this.attesa && this.attesa.sid === m.s) { costo = this.attesa.costo; this.attesa = null; }
    else if (this.fuoriAttesa && this.fuoriAttesa[m.s] !== undefined) { costo = this.fuoriAttesa[m.s]; delete this.fuoriAttesa[m.s]; }
    if (this.inCorso) {
      this.usi[m.s] = (this.usi[m.s] || 0) + 1;
      this.spesa[m.s] = (this.spesa[m.s] || 0) + costo;
    }
    if (this.me) {
      this.me.res = Math.max(0, this.me.res - costo);
      if (sk.spend && sk.type !== 'heal_aoe') this.me.pts = 0;
      if (sk.spendBonus) this.me.pts = 0;
      if (sk.pts) this.me.pts = Math.min(PTS_MAX, this.me.pts + sk.pts);
      if (sk.sup) { this.me.su = 0; this.supPronta = false; this.supDa = ora; }
    }
    if (!sk.offgcd) this.ultimo = sk.cost > 0 && (sk.ruolo === 'medio' || sk.ruolo === 'potente') ? 'scarico' : 'altro';
  }

  effetto(m, ora) {
    if (m.k === 'hit') {
      if (m.d === this.id && m.s !== this.id) { if (this.inCorso) this.subiti += m.v || 0; this.ostili.add(m.s); return; }
      if (m.s !== this.id || !this.inCorso || !this.bersagli.includes(m.d)) return;
      const v = m.v || 0, sk = m.sk || 'auto';
      this.danni[sk] = (this.danni[sk] || 0) + v;
      this.colpi[sk] = (this.colpi[sk] || 0) + 1;
      this.totale += v;
      this.totaleSenzaSquil += (this.squilFino[m.d] || 0) > ora ? v / (1 + this.vulnSquil / 100) : v;
    } else if (m.k === 'post') {
      if (!this.bersagli.includes(m.d)) return;
      if (this.inCorso) this.squilibri++;
      this.squilFino[m.d] = ora + m.ms;
    } else if (m.k === 'proc' && m.s === this.id && m.b && BUFFS[m.b]) {
      this.buffs[m.b] = ora + BUFFS[m.b].dur * 1000;   // subito, senza aspettare il prossimo `me`
    }
  }

  // ---------------------------------------------------------------- preparazione
  async prepara() {
    const o = this.opt, c = CLASSES[this.cls];
    this.vulnSquil = (await import('../../shared/postura.js')).POSTURA.vuln;
    await this.collega();
    this.manda({ t: 'register', user: 'admin', pass: 'simula' });
    await this.attendi('accesso', () => this.autenticato && this.personaggi);
    this.personaggi = null;
    this.manda({ t: 'create', name: 'Sim' + this.via[0].toUpperCase() + this.via.slice(1), cls: this.cls, kd: 'fenice', sex: 'm' });
    const lista = await this.attendi('creazione del personaggio', () => this.personaggi && this.personaggi.length && this.personaggi);
    this.manda({ t: 'play', id: lista[0].id });
    await this.attendi('ingresso nel mondo', () => this.id && this.me && this.inv);
    this.chat(`/level ${o.livello}`);
    await this.attendi('/level', () => this.me.lvl === o.livello);
    if (o.livello >= 5) { this.chat(`/via ${this.via}`); await this.attendi('/via', () => this.me.via === this.via); }
    // arma del livello giusto (sintassi: /item id quantità potenziamento rarità)
    const wt = ARMA_DI[this.via];
    const arma = Object.entries(ITEMS).filter(([, it]) => it.type === 'weapon' && it.wt === wt && it.lvl <= o.livello).sort((a, b) => b[1].lvl - a[1].lvl)[0][0];
    if (!this.eq.weapon || this.eq.weapon.id !== arma) {
      this.chat(`/item ${arma} 1 0 0`);
      const i = await this.attendi('/item', () => { const k = this.inv.findIndex((s) => s && s.id === arma); return k >= 0 ? k + 1 : 0; });
      this.manda({ t: 'use', i: i - 1 });
      await this.attendi("equipaggiamento dell'arma", () => this.eq.weapon && this.eq.weapon.id === arma);
    }
    this.arma = arma;
    // punti statistica: due al valore primario e uno alla vitalità (il difensore al contrario; --vitalita cambia la quota per tutti)
    const prim = c.primary === 'dex' ? 'dex' : c.primary === 'int' ? 'int' : 'str';
    let n = this.me.sp;
    const quotaVit = o.vitalita ?? this.rot.vitalita ?? 1 / 3;
    for (let i = 0, vit = 0; i < n; i++) {
      const inVit = (vit + 1) / (i + 1) <= quotaVit + 1e-9;
      if (inVit) vit++;
      this.manda({ t: 'stat', s: inVit ? 'vit' : prim });
      if (i % 20 === 19) await this.dormi(450);
    }
    await this.attendi('punti statistica', () => this.me.sp === 0);
    // punti abilità: in parti uguali fra le tecniche con ruolo (e la Suprema)
    const mie = Object.values(SKILLS).filter((s) => s.cls === this.cls && (!s.via || s.via === this.via) && s.lvl <= o.livello && (s.ruolo || s.sup)).map((s) => s.id);
    n = this.me.kp;
    for (let i = 0; i < n && mie.length; i++) { this.manda({ t: 'skup', s: mie[i % mie.length] }); if (i % 20 === 19) await this.dormi(450); }
    if (mie.length) await this.attendi('punti abilità', () => this.me.kp === 0);
    await this.dormi(300);
    // radura e fantocci
    const [rx, rz] = o.radura, N = o.bersagli;
    const prima = new Set(this.mob.keys());
    await this.tp(rx, rz);
    await this.dormi(400);
    for (const [id, e] of this.mob) if (e.ty !== 'fantoccio' && Math.hypot(e.x - rx, e.z - rz) < 25) this.vicini = (this.vicini || 0) + 1;
    for (let k = 0; k < N; k++) {
      const a = (k / N) * Math.PI * 2, d = N === 1 ? 0 : 2;
      await this.tp(rx + Math.sin(a) * d, rz + Math.cos(a) * d);
      this.chat('/spawn fantoccio 1 0.05');
      await this.dormi(120);
    }
    const nuovi = () => [...this.mob].filter(([id, e]) => !prima.has(id) && e.ty === 'fantoccio' && Math.hypot(e.x - rx, e.z - rz) < 8).map(([id]) => id);
    this.bersagli = await this.attendi('fantocci', () => { const l = nuovi(); return l.length >= N && l; });
    // posizione: di fronte al bersaglio principale (o alle sue spalle con --spalle); con più bersagli il corpo a corpo sta al centro
    const lato = o.spalle ? -1 : 1, dist = this.rot.distanza;
    const fronte = (e, x, z) => (Math.sin(e.r) * (x - e.x) + Math.cos(e.r) * (z - e.z)) / (Math.hypot(x - e.x, z - e.z) || 1);
    if (N === 1 || dist > 3) {
      this.primo = this.bersagli[0];
      const e = this.mob.get(this.primo);
      this.casa = { x: e.x + Math.sin(e.r) * dist * lato, z: e.z + Math.cos(e.r) * dist * lato };
    } else {
      this.casa = { x: rx, z: rz };
      // bersaglio principale: quello che guarda di più verso il centro (o che gli dà di più le spalle)
      this.primo = [...this.bersagli].sort((a, b) => lato * (fronte(this.mob.get(b), rx, rz) - fronte(this.mob.get(a), rx, rz)))[0];
    }
    await this.tp(this.casa.x, this.casa.z);
    this.chat('/heal');
    await this.dormi(1200);
  }

  async tp(x, z) {
    const n = this.nPos || 0;
    this.chat(`/tp ${x.toFixed(2)} ${z.toFixed(2)}`);
    await this.attendi('/tp', () => (this.nPos || 0) > n);
  }

  // ---------------------------------------------------------------- stato visto dalla rotazione
  conosce(sid) {
    const sk = SKILLS[sid], me = this.me;
    if (!sk || sk.cls !== this.cls || me.lvl < sk.lvl) return false;
    if (sk.via && sk.via !== me.via) return false;
    if (sk.req && ITEMS[this.arma].wt !== sk.req) return false;
    if (this.opt.senza && sk.ruolo === this.opt.senza) return false;
    return true;
  }
  costo(sid) {
    const sk = SKILLS[sid], ora = this.ora();
    if (!sk || !sk.cost) return 0;
    let c = sk.cost;
    for (const [b, fino] of Object.entries(this.buffs)) {
      if (fino <= ora) continue;
      const d = BUFFS[b];
      if (d.free && d.free.includes(sid)) return 0;
      if (d.costMod && d.costMod[sid]) c += d.costMod[sid];
    }
    c = Math.max(0, c);
    return this.me.rt === 'mana' ? Math.round(this.me.rmax * c / 100) : c;
  }
  stato() {
    const ora = this.ora(), me = this.me, bot = this;
    return {
      par: this.opt.par, sup: this.sup, res: me.res, rmax: me.rmax, pts: me.pts, multi: this.opt.bersagli > 1, catena: me.chain || 0, ultimo: this.ultimo,
      pct: (x) => me.rmax * x / 100,
      sa: (id) => bot.conosce(id),
      eta: (id) => (bot.ultimoUso[id] === undefined ? Infinity : ora - bot.ultimoUso[id]),
      costo: (id) => bot.costo(id),
      b: (id) => Math.max(0, (bot.buffs[id] || 0) - ora),
      dot: (id) => Math.max(0, ((bot.dots[bot.primo] || {})[id] || 0) - ora),
      ok: (id) => {
        const sk = SKILLS[id];
        if (!id || !bot.conosce(id)) return false;
        if ((bot.cds[id] || 0) > ora) return false;
        if (bot.costo(id) > me.res) return false;
        if (sk.sup && (me.su || 0) < SUPREMA.max) return false;
        if (sk.spend && sk.type !== 'heal_aoe' && me.pts < (sk.minPts || 1)) return false;
        return true;
      },
    };
  }

  lancia(sid, ora) {
    const sk = SKILLS[sid], costo = this.costo(sid);
    const id = BERSAGLIATE.includes(sk.type) ? this.primo : 0;
    if (sk.offgcd) {
      this.blocco[sid] = ora + 300;
      (this.fuoriAttesa || (this.fuoriAttesa = {}))[sid] = costo;
    } else {
      this.attesa = { sid, costo, gcdPrima: this.gcdFino, da: ora };
      this.gcdFino = ora + (this.me.gcd || 1000);
    }
    this.manda({ t: 'skill', s: sid, id });
  }

  passo() {
    const ora = this.ora(), me = this.me;
    if (!me || me.dead) return;
    // uno scatto (Carica, Passo d'Ombra, Suprema) sposta il bot: torna al suo posto, come un nemico che si gira verso di lui
    if (Math.hypot(this.pos.x - this.casa.x, this.pos.z - this.casa.z) > 0.6 && ora > this.tpFino) {
      this.chat(`/tp ${this.casa.x.toFixed(2)} ${this.casa.z.toFixed(2)}`);
      this.tpFino = ora + 500;
    }
    if (this.attesa && ora - this.attesa.da > 800) this.attesa = null;          // risposta persa: non restare fermo
    const lanciando = this.lancio && !this.lancio.finito;
    if (!lanciando && ora >= this.prossimoAtk) { this.manda({ t: 'atk', id: this.primo }); this.prossimoAtk = ora + me.aspd; }
    const S = this.stato();
    for (const [sid, cond] of Object.entries(this.rot.fuori || {})) {
      if ((this.blocco[sid] || 0) > ora || !S.ok(sid) || !cond(S)) continue;
      this.lancia(sid, ora);
    }
    if (ora >= this.gcdFino && !this.lancio && !this.attesa) {
      const sid = this.rot.gcd(S);
      if (sid && S.ok(sid)) this.lancia(sid, ora);
    }
  }

  async combatti() {
    const durata = this.opt.secondi * 1000;
    this.t0 = this.ora(); this.supDa = this.t0; this.inCorso = true;
    this.resPrima = { t: this.t0, res: this.me.res };
    this.supPronta = (this.me.su || 0) >= SUPREMA.max;
    while (this.ora() - this.t0 < durata) {
      if (this.chiuso) throw new Error(`[${this.via}] ${this.chiuso}`);
      this.passo();
      await this.dormi(15);
    }
    this.inCorso = false;
    this.durata = (this.ora() - this.t0) / 1000;
  }

  risultato() {
    const T = this.durata, me = this.me, mana = me.rt === 'mana';
    const tecniche = {};
    const ids = new Set([...Object.keys(this.danni), ...Object.keys(this.usi)]);
    for (const id of ids) {
      const sk = SKILLS[id];
      const cat = id === 'auto' ? 'auto' : sk.sup ? 'suprema' : sk.ruolo || 'supporto';
      const spesa = mana ? (this.spesa[id] || 0) / me.rmax * 100 : (this.spesa[id] || 0);   // Mana in % del massimo
      tecniche[id] = { nome: id === 'auto' ? 'Attacco base' : sk.name, cat, usi: this.usi[id] || 0, colpi: this.colpi[id] || 0, danni: this.danni[id] || 0, spesa };
    }
    const perCat = {};
    for (const t of Object.values(tecniche)) perCat[t.cat] = (perCat[t.cat] || 0) + t.danni;
    // stima del riempimento se la barra non si è mai riempita nella prova
    let suprema = this.riempimenti.length ? this.riempimenti.reduce((a, b) => a + b, 0) / this.riempimenti.length : null, stimata = false;
    if (suprema === null && me.lvl >= SUPREMA.lvl && (me.su || 0) > 0) { suprema = T * SUPREMA.max / me.su; stimata = true; }
    return {
      via: this.via, livello: me.lvl, bersagli: this.opt.bersagli, secondi: T, arma: this.arma,
      atk: me.atk, matk: me.matk, crit: me.crit, rmax: me.rmax,
      dps: this.totale / T, dpsSenzaSquil: this.totaleSenzaSquil / T, totale: this.totale,
      perCat, tecniche,
      sprecoPct: this.tRis ? this.tMax / this.tRis * 100 : 0,
      risFinalePct: me.res / me.rmax * 100,
      suprema, supremaStimata: stimata, supremaUsi: this.usi[this.sup] || 0,
      squilibri: this.squilibri, rifiuti: this.rifiuti, errori: this.errori, lanciInterrotti: this.lanciInterrotti,
      subiti: this.subiti, mostriVicini: this.vicini || 0,
    };
  }
}

async function provaVia(via, opt) {
  const srv = await avviaServer(opt.velocita);
  const bot = new Bot(via, opt, srv.porta);
  try {
    await bot.prepara();
    await bot.combatti();
    return bot.risultato();
  } finally {
    try { bot.ws && bot.ws.close(); } catch { /* niente */ }
    await new Promise((r) => setTimeout(r, 50));
    srv.chiudi();
  }
}

// ------------------------------------------------------------------ tabelle
const num = (v, d = 0) => (v === null || v === undefined || Number.isNaN(v) ? '—' : v.toLocaleString('it-IT', { minimumFractionDigits: d, maximumFractionDigits: d }));
const media = (l) => (l.length ? l.reduce((a, b) => a + b, 0) / l.length : null);
function tabella(righe, allinea) {
  const larg = righe[0].map((_, c) => Math.max(...righe.map((r) => String(r[c]).length)));
  return righe.map((r, i) => r.map((v, c) => (allinea[c] === 's' ? String(v).padEnd(larg[c]) : String(v).padStart(larg[c]))).join('  ') +
    (i === 0 ? '\n' + larg.map((l) => '-'.repeat(l)).join('  ') : '')).join('\n');
}

// media di più ripetizioni della stessa Via
function unisci(lista) {
  const r = { ...lista[0], n: lista.length };
  for (const k of ['dps', 'dpsSenzaSquil', 'sprecoPct', 'risFinalePct', 'squilibri', 'rifiuti', 'subiti', 'lanciInterrotti', 'supremaUsi']) r[k] = media(lista.map((x) => x[k]));
  const sup = lista.filter((x) => x.suprema !== null);
  r.suprema = sup.length ? media(sup.map((x) => x.suprema)) : null;
  r.supremaStimata = sup.length > 0 && sup.every((x) => x.supremaStimata);
  r.dpsMin = Math.min(...lista.map((x) => x.dps)); r.dpsMax = Math.max(...lista.map((x) => x.dps));
  r.perCat = {}; r.tecniche = {}; r.errori = {};
  for (const x of lista) {
    for (const [k, v] of Object.entries(x.perCat)) r.perCat[k] = (r.perCat[k] || 0) + v / lista.length;
    for (const [k, v] of Object.entries(x.errori)) r.errori[k] = (r.errori[k] || 0) + v;
    for (const [id, t] of Object.entries(x.tecniche)) {
      const a = r.tecniche[id] || (r.tecniche[id] = { nome: t.nome, cat: t.cat, usi: 0, colpi: 0, danni: 0, spesa: 0 });
      for (const k of ['usi', 'colpi', 'danni', 'spesa']) a[k] += t[k] / lista.length;
    }
  }
  r.totale = media(lista.map((x) => x.totale));
  return r;
}

const DA_DANNO = ['fulmine', 'pugnali', 'arco', 'ferro', 'loto', 'tempesta'];

function stampa(ris, opt) {
  const pc = (r, k) => num((r.perCat[k] || 0) / (r.totale || 1) * 100, 0) + '%';
  console.log(`\n=== Livello ${opt.livello} · ${opt.bersagli} ${opt.bersagli === 1 ? 'bersaglio' : 'bersagli'} · ${opt.secondi} s` +
    `${opt.ripeti > 1 ? ' · media di ' + opt.ripeti + ' prove' : ''}${opt.velocita > 1 ? ' · orologio ×' + opt.velocita : ''}${opt.spalle ? ' · alle spalle' : ''}${opt.senza ? ' · senza scarichi di ruolo «' + opt.senza + '»' : ''} ===`);
  const dd = ris.filter((r) => DA_DANNO.includes(r.via));
  const rif = dd.length ? media(dd.map((r) => r.dps)) : media(ris.map((r) => r.dps));
  const righe = [['Via', 'DPS', 'vs media', 'min-max', 'senza Squil.', 'accum.', 'medio', 'potente', 'Suprema', 'base', 'altro', 'ris. al max', 'ris. finale', 'barra Supr.', 'Squil.', 'rifiuti']];
  for (const r of ris) {
    righe.push([r.via, num(r.dps), (r.dps >= rif ? '+' : '') + num((r.dps / rif - 1) * 100, 0) + '%', r.n > 1 ? `${num(r.dpsMin)}-${num(r.dpsMax)}` : '', num(r.dpsSenzaSquil),
      pc(r, 'accumulo'), pc(r, 'medio'), pc(r, 'potente'), pc(r, 'suprema'), pc(r, 'auto'), pc(r, 'supporto'),
      num(r.sprecoPct, 0) + '%', num(r.risFinalePct, 0) + '%',
      r.suprema === null ? '—' : (r.supremaStimata ? '~' : '') + num(r.suprema, 0) + ' s', num(r.squilibri, r.n > 1 ? 1 : 0), num(r.rifiuti, r.n > 1 ? 1 : 0)]);
  }
  console.log(tabella(righe, ['s']));
  console.log(`«vs media»: rispetto alla media delle Vie da danno presenti (${num(rif)} DPS). «ris. al max»: tempo passato con la risorsa al massimo (sprecata).` +
    ' «barra Supr.»: secondi per riempirla (~ = stima, non si è riempita).');
  // scarichi: danno per uso e per punto di risorsa
  const sc = [['Via', 'scarico', 'ruolo', 'usi', 'danno/uso', 'costo medio', 'danno/punto risorsa']];
  for (const r of ris) {
    for (const [id, t] of Object.entries(r.tecniche)) {
      if (t.cat !== 'medio' && t.cat !== 'potente') continue;
      if (!t.usi) continue;
      sc.push([r.via, t.nome, t.cat, num(t.usi, r.n > 1 ? 1 : 0), num(t.danni / t.usi), num(t.spesa / t.usi, 1), t.spesa > 0 ? num(t.danni / t.spesa, 1) : '—']);
    }
  }
  if (sc.length > 1) { console.log('\nScarichi (danni dei colpi e dei danni nel tempo che lasciano; costo in punti, per il Mana in % del massimo):'); console.log(tabella(sc, ['s', 's', 's'])); }
  if (opt.dettagli) {
    for (const r of ris) {
      console.log(`\n--- ${VIE[r.via].name} (${r.arma}, attacco ${r.atk}, magico ${r.matk}, critico ${num(r.crit, 1)}%)`);
      const t = [['tecnica', 'ruolo', 'usi', 'colpi', 'danni', '%', 'danno/uso']];
      for (const [id, x] of Object.entries(r.tecniche).sort((a, b) => b[1].danni - a[1].danni)) {
        t.push([x.nome, x.cat, num(x.usi, r.n > 1 ? 1 : 0), num(x.colpi, r.n > 1 ? 1 : 0), num(x.danni), num(x.danni / (r.totale || 1) * 100, 1) + '%', x.usi ? num(x.danni / x.usi) : '—']);
      }
      console.log(tabella(t, ['s', 's']));
      const err = Object.entries(r.errori).map(([m, n]) => `${m} ×${n}`).join(', ');
      if (err) console.log(`Messaggi di errore del server: ${err}`);
    }
  }
  obiettivi(ris, opt, rif);
  for (const r of ris) {
    if (r.subiti > 0) console.log(`ATTENZIONE ${r.via}: il bot ha subito ${num(r.subiti)} danni (mostri ostili vicino alla radura?)`);
    if (r.lanciInterrotti > 0) console.log(`ATTENZIONE ${r.via}: ${num(r.lanciInterrotti, 1)} lanci interrotti`);
  }
}

// Confronto con gli obiettivi di taratura (vedi CLAUDE.md, «Sistema di combattimento»).
function obiettivi(ris, opt, rif) {
  const righe = [], area = opt.bersagli > 1;
  const esito = (ok) => (ok ? 'sì ' : 'NO ');
  const dd = ris.filter((r) => DA_DANNO.includes(r.via));
  if (dd.length > 1) {
    const lim = area ? 15 : 10, sc = dd.map((r) => (r.dps / rif - 1) * 100);
    righe.push(`${esito(Math.max(...sc.map(Math.abs)) <= lim)}Vie da danno entro ±${lim}% dalla loro media: da ${num(Math.min(...sc), 1)}% a +${num(Math.max(...sc), 1)}%`);
  }
  for (const r of ris.filter((x) => !DA_DANNO.includes(x.via))) {
    if (!dd.length) break;
    const q = r.dps / rif * 100;
    righe.push(`${esito(q >= 60 && q <= 75)}${r.via} al 60-75% delle Vie da danno: ${num(q, 0)}%`);
  }
  const quota = (r, k) => (r.perCat[k] || 0) / (r.totale || 1) * 100;
  const fuoriAcc = ris.filter((r) => quota(r, 'accumulo') < 19.5 || quota(r, 'accumulo') > 35.5);
  righe.push(`${esito(!fuoriAcc.length)}accumuli al 20-35% dei danni${fuoriAcc.length ? ': fuori ' + fuoriAcc.map((r) => `${r.via} ${num(quota(r, 'accumulo'), 0)}%`).join(', ') : ''}`);
  // scarico potente contro scarico medio dello stesso tipo (singolo con un bersaglio, ad area con un gruppo)
  const tipo = (id) => (SKILLS[id].type === 'strike' ? 'singolo' : ['aoe_self', 'aoe_target'].includes(SKILLS[id].type) ? 'area' : 'altro');
  const male = [];
  for (const r of ris) {
    const voci = Object.entries(r.tecniche).filter(([id, t]) => t.usi >= 1 && t.spesa > 0 && t.danni > 0 && tipo(id) === (area ? 'area' : 'singolo'));
    for (const [, p] of voci.filter(([, t]) => t.cat === 'potente')) {
      for (const [, m] of voci.filter(([, t]) => t.cat === 'medio')) {
        if (p.danni / p.usi <= m.danni / m.usi) male.push(`${r.via}: ${p.nome} non supera ${m.nome} per uso`);
        if (p.danni / p.spesa >= m.danni / m.spesa) male.push(`${r.via}: ${p.nome} rende più di ${m.nome} per punto di risorsa`);
      }
    }
  }
  righe.push(`${esito(!male.length)}scarico potente: più del medio per uso, meno per punto di risorsa${male.length ? ' — ' + male.join('; ') : ''}`);
  const conBarra = ris.filter((r) => r.suprema !== null);
  if (conBarra.length) {
    const fuori = conBarra.filter((r) => r.suprema < 44.5 || r.suprema > 60.5);
    righe.push(`${esito(!fuori.length)}barra Suprema piena in 45-60 s${fuori.length ? ': fuori ' + fuori.map((r) => `${r.via} ${num(r.suprema, 0)} s`).join(', ') : ''}`);
    if (area) {
      const troppo = conBarra.filter((r) => quota(r, 'suprema') > 20);
      righe.push(`${esito(!troppo.length)}Suprema entro il 15-20% dei danni su un gruppo${troppo.length ? ': fuori ' + troppo.map((r) => `${r.via} ${num(quota(r, 'suprema'), 0)}%`).join(', ') : ''}`);
    }
  }
  console.log('\nObiettivi di taratura:');
  for (const r of righe) console.log('  ' + r);
}

// ------------------------------------------------------------------ principale
async function main() {
  const opt = leggiOpzioni(process.argv.slice(2));
  const lavori = [];
  for (const via of opt.vie) for (let k = 0; k < opt.ripeti; k++) lavori.push({ via, k });
  const esiti = new Map(opt.vie.map((v) => [v, []]));
  let fatti = 0, i = 0;
  const durataStimata = Math.ceil(lavori.length / opt.paralleli) * (opt.secondi + 8) / opt.velocita;
  console.error(`Simulazione: ${lavori.length} prove (${opt.paralleli} in parallelo), circa ${Math.round(durataStimata)} s...`);
  const operaio = async () => {
    while (i < lavori.length) {
      const l = lavori[i++];
      try { esiti.get(l.via).push(await provaVia(l.via, opt)); }
      catch (e) { console.error(`Prova fallita (${l.via}): ${e.message}`); }
      fatti++;
      if (process.stderr.isTTY) process.stderr.write(`\r${fatti}/${lavori.length} `);
    }
  };
  await Promise.all(Array.from({ length: Math.min(opt.paralleli, lavori.length) }, operaio));
  const ris = opt.vie.filter((v) => esiti.get(v).length).map((v) => unisci(esiti.get(v)));
  if (!ris.length) { console.error('Nessuna prova riuscita.'); process.exit(1); }
  stampa(ris, opt);
  if (opt.json) fs.writeFileSync(opt.json, JSON.stringify({ opzioni: opt, risultati: ris }, null, 1));
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
