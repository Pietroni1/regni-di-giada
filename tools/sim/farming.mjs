#!/usr/bin/env node
// Misura del FARMING nel mondo aperto, senza browser: un bot di livello adatto gira in una zona, combatte i mostri con
// i kit a pochi tasti (colpo base ad area finché non c'è la Risonanza, poi il colpo finale; colpo base singolo sui
// solitari) e riporta mostri uccisi al minuto, esperienza al minuto, danni subiti, morti, bottino caduto.
//
//   npm run farming                                  (tutte le zone, Fulmine e Arco, 5 minuti, velocità 3)
//   node tools/sim/farming.mjs [--zone bassa,media,alta] [--vie fulmine,arco] [--minuti 5] [--velocita 3]
//                              [--livello N] [--bonus-livello 5] [--ripeti 1] [--paralleli 1] [--json file]
//                              [--porte 4201-4209]
//
// Zone (anelli attorno a un centro, con le famiglie di mostri che il bot considera suoi bersagli):
//   bassa  intorno al Borgo delle Braci, 58-120 m: lupi, cinghiali, lupi alfa, lupi del branco       (livello 5)
//   media  intorno al Borgo delle Braci, 118-178 m: banditi, scimmie, arcieri, orsi, predoni         (livello 12)
//   alta   intorno al centro della mappa, 38-95 m: terracotta, spiriti, tigri, soldati               (livello 19)
//   gole   intorno al Borgo delle Braci, 135-182 m: razziatori, predoni, banditi, scimmie            (livello 16)
//   cuore  intorno al centro della mappa, 30-66 m: lancieri di bronzo e soldati                      (livello 25)
//   selva  Selva dei Mille Steli (mappa lontana)                                                     (livello 33)
//   distesa  Distesa dei Venti Rossi (mappa lontana)                                                 (livello 43)
// --livello N        forza lo stesso livello in tutte le zone;  --bonus-livello K  aggiunge K livelli a quello della zona
//                    (prova del giocatore sopra la zona: l'esperienza non deve esplodere).
// Vie provabili: fulmine, montagna, pugnali, arco, ferro, loto, tempesta (le rotazioni sono nella tabella ROTAZIONI).
//
// Ogni prova avvia da sé un server (porta fra 4201 e 4209, database temporaneo in TMPDIR), registra l'account GM
// `admin`, crea il personaggio, lo porta al livello (/level), gli dà Via, arma e armatura del suo livello, punti
// statistica e abilità, poi lo lascia CAMMINARE nel mondo (messaggi `move` veri, alla velocità del personaggio):
// va al mostro più vicino della zona, lo combatte (anche quelli che gli si buttano addosso), beve un ginseng sotto il
// 40% di vita (al massimo uno ogni 3 s; li conta), e se non vede più mostri pattuglia l'anello della zona.
// Se muore chiede la rinascita al villaggio e torna a cercare mostri a piedi.
// Misure: uccisioni (dai messaggi di esperienza), esperienza e tael, vita minima toccata, morti, ginseng bevuti,
// oggetti caduti a suo nome (equipaggiamento, gemme, modificatori, materiali) e loro valore di vendita.
// --velocita N accelera l'orologio del server (tools/sim/orologio.mjs) come `npm run sim`; i numeri da pubblicare
// vanno presi a velocità 1-2, perché a velocità alta il bot reagisce con meno ritardo di un giocatore vero.
import { spawn } from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import WebSocket from 'ws';
import { CLASSES, VIE, SKILLS, BUFFS, ITEMS, MOBS, PTS_MAX, SUPREMA, supremaOf, expToNext, equipSlotOf } from '../../shared/data.js';
import { KINGDOMS, CENTER } from '../../shared/world.js';

const QUI = path.dirname(fileURLToPath(import.meta.url));
const RADICE = path.resolve(QUI, '..', '..');

// ------------------------------------------------------------------ zone
const FENICE = KINGDOMS.fenice.village;
const ZONE = {
  bassa: { centro: FENICE, rmin: 58, rmax: 120, livello: 5, tipi: ['lupo', 'cinghiale', 'lupo_alfa', 'lupo_branco'] },
  media: { centro: FENICE, rmin: 118, rmax: 178, livello: 12, tipi: ['bandito', 'scimmia', 'arciere_bandito', 'orso_nero', 'predone'] },
  alta: { centro: CENTER, rmin: 38, rmax: 95, livello: 19, tipi: ['terracotta', 'spirito_lanterna', 'tigre_spettrale', 'soldato_terracotta'] },
  // zone aggiunte con le missioni (curva dei livelli): gole lontane, cuore dell'Altopiano, Selva e Distesa
  gole: { centro: FENICE, rmin: 135, rmax: 182, livello: 16, tipi: ['razziatore_gola', 'predone', 'bandito', 'arciere_bandito', 'scimmia', 'orso_nero'] },
  cuore: { centro: CENTER, rmin: 30, rmax: 66, livello: 25, tipi: ['lanciere_bronzo', 'soldato_terracotta', 'terracotta', 'spirito_lanterna', 'tigre_spettrale'] },
  selva: { centro: { x: 6000, z: 0 }, rmin: 15, rmax: 140, livello: 33, tipi: ['lupo_canne', 'scimmia_urlatrice', 'brigante_selva', 'cerbottaniere_selva', 'spirito_canna', 'orso_ventre_giada', 'tigre_smeraldo'] },
  distesa: { centro: { x: 7000, z: 0 }, rmin: 15, rmax: 150, livello: 43, tipi: ['sciacallo_dune', 'cinghiale_zanne_ferro', 'predone_dune', 'arciere_simun', 'anima_miraggio', 'guerriero_arenaria', 'campione_arenaria', 'tigre_sole_rovente'] },
};

// ------------------------------------------------------------------ opzioni
function leggiOpzioni(argv) {
  const o = { zone: ['bassa', 'media'], vie: ['fulmine', 'arco'], minuti: 5, velocita: 3, livello: 0, bonus: 0, ripeti: 1, paralleli: 1, json: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    switch (a) {
      case '--zone': o.zone = v().split(',').map((s) => s.trim()).filter(Boolean); break;
      case '--vie': o.vie = v().split(',').map((s) => s.trim()).filter(Boolean); break;
      case '--minuti': o.minuti = Math.max(0.5, parseFloat(v()) || 5); break;
      case '--velocita': o.velocita = Math.max(1, Math.min(6, parseFloat(v()) || 3)); break;
      case '--livello': o.livello = Math.max(1, parseInt(v(), 10) || 0); break;
      case '--bonus-livello': o.bonus = Math.max(0, parseInt(v(), 10) || 0); break;
      case '--ripeti': o.ripeti = Math.max(1, parseInt(v(), 10) || 1); break;
      case '--paralleli': o.paralleli = Math.max(1, Math.min(2, parseInt(v(), 10) || 1)); break;
      case '--json': o.json = v(); break;
      case '--porte': { const [a, b] = v().split('-').map((x) => parseInt(x, 10)); PORTE = [a, b || a]; break; }
      case '--aiuto': case '-h': case '--help':
        console.log('Uso: node tools/sim/farming.mjs [--zone bassa,media,alta] [--vie fulmine,arco] [--minuti 5] [--velocita 3]\n' +
          '       [--livello N] [--bonus-livello K] [--ripeti 1] [--paralleli 1|2] [--json file]\n' +
          `Zone: ${Object.keys(ZONE).join(', ')}\nVie: ${Object.keys(VIE).join(', ')}`);
        process.exit(0);
      // eslint-disable-next-line no-fallthrough
      default: console.error(`Opzione sconosciuta: ${a} (prova --aiuto)`); process.exit(1);
    }
  }
  for (const z of o.zone) if (!ZONE[z]) { console.error(`Zona sconosciuta: ${z}. Zone: ${Object.keys(ZONE).join(', ')}`); process.exit(1); }
  for (const v of o.vie) if (!ROTAZIONI[v]) { console.error(`Via senza rotazione: ${v}. Vie: ${Object.keys(ROTAZIONI).join(', ')}`); process.exit(1); }
  return o;
}

// ------------------------------------------------------------------ server di prova
// porte che il bot può usare per i suoi server (--porte 4201-4209 per non disturbare altri server in prova)
let PORTE = [4201, 4209];
function portaLibera() {
  const prova = (p) => new Promise((ok) => {
    const s = net.createServer();
    s.unref();
    s.once('error', () => ok(false));
    s.listen(p, '127.0.0.1', () => s.close(() => ok(true)));
  });
  return (async () => {
    // solo queste porte (--porte); il server della prova prima può metterci qualche secondo a liberarla
    for (let giro = 0; giro < 40; giro++) {
      for (let p = PORTE[0]; p <= PORTE[1]; p++) if (await prova(p)) return p;
      await new Promise((r) => setTimeout(r, 500));
    }
    throw new Error(`Nessuna porta libera fra ${PORTE[0]} e ${PORTE[1]}.`);
  })();
}

const figli = new Set();
process.on('exit', () => { for (const f of figli) try { f.kill(); } catch { /* già chiuso */ } });
process.on('SIGINT', () => process.exit(130));
let portaOccupata = Promise.resolve();   // le porte si scelgono una alla volta, così due prove non prendono la stessa

async function avviaServer(velocita) {
  let rilascia;
  const precedente = portaOccupata;
  portaOccupata = new Promise((r) => { rilascia = r; });
  await precedente;
  let porta;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'regni-farming-'));
  const args = [];
  if (velocita !== 1) args.push('--import', pathToFileURL(path.join(QUI, 'orologio.mjs')).href);
  args.push(path.join(RADICE, 'server', 'index.js'));
  let figlio, errori = '';
  try {
    porta = await portaLibera();
    figlio = spawn(process.execPath, args, {
      cwd: RADICE, stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, PORT: String(porta), DB_FILE: path.join(dir, 'db.json'), SIM_VELOCITA: String(velocita) },
    });
    figli.add(figlio);
    figlio.stderr.on('data', (d) => { errori += d; });
    await new Promise((ok, no) => {
      const scade = setTimeout(() => no(new Error('Il server di prova non parte.\n' + errori)), 25000);
      figlio.stdout.on('data', (d) => { if (String(d).includes('server avviato')) { clearTimeout(scade); ok(); } });
      figlio.on('exit', (c) => { clearTimeout(scade); no(new Error(`Il server di prova si è chiuso (codice ${c}).\n${errori}`)); });
    });
  } finally { rilascia(); }
  const chiudi = () => {
    figli.delete(figlio);
    try { figlio.kill(); } catch { /* già chiuso */ }
    try { fs.rmSync(dir, { recursive: true, force: true }); } catch { /* pazienza */ }
  };
  return { porta, chiudi };
}

// ------------------------------------------------------------------ rotazioni
// S: ok(id) pronta e pagabile, b(id) ms rimasti di un effetto su di sé, multi (3 o più nemici vicini al bersaglio),
// pts, res, rmax. Vale la regola del bot di `npm run sim`: contro un gruppo colpo base ad area finché si accende la
// Risonanza, poi il finale (che diventa ad area); contro un bersaglio solo colpo base singolo e finale a 3 punti.
function rotazione(S, c) {
  if (S.ok(S.sup)) return S.sup;
  if (S.b('occasione') && S.ok(c.fin)) return c.fin;   // Occasione: finale gratuito e a Concentrazione piena
  if (S.multi) {
    if (S.b('risonanza') && S.ok(c.fin)) return c.fin;
    return c.f2;
  }
  if (!c.cura && S.ok(c.fin) && (S.pts >= 3 || S.res >= S.rmax - 12)) return c.fin;
  if (c.ritmo && S.ultimoBase === c.f1) return c.f2;
  return c.f1;
}
// scatti: tecniche con `scatto` usate per raggiungere prima il bersaglio (Carica, Passo d'Ombra, Ala di Vento,
// Calcio Volante, Passo di Luce) quando è a più di qualche metro.
const ROTAZIONI = {
  fulmine: { distanza: 1.6, arma: 'sword', gcd: (S) => rotazione(S, { f1: 'squarcio', f2: 'fendente', fin: 'lama_tuono' }), fuori: { grido_guerra: () => true }, scatti: ['carica'] },
  montagna: { distanza: 1.6, arma: 'sword', vitalita: 2 / 3, gcd: (S) => rotazione(S, { f1: 'squarcio', f2: 'fendente', fin: 'martello_monte' }), fuori: { grido_guerra: () => true, radici_monte: (S) => S.multi }, scatti: ['carica'] },
  pugnali: { distanza: 1.6, arma: 'daggers', gcd: (S) => rotazione(S, { f1: 'colpo_rapido', f2: 'ventaglio', fin: 'taglio_finale' }), fuori: { velo_ombra: () => true }, scatti: ['passo_ombra'] },
  arco: { distanza: 10, arma: 'bow', gcd: (S) => rotazione(S, { f1: 'colpo_rapido', f2: 'ventaglio', fin: 'freccia_perforante' }), fuori: { velo_ombra: () => true }, scatti: ['ala_vento'] },
  ferro: { distanza: 1.6, arma: 'fists', gcd: (S) => rotazione(S, { f1: 'pugno_ferro', f2: 'calcio_gru', fin: 'raffica', ritmo: true }), fuori: { respiro_drago: () => true, pelle_bronzo: () => true }, scatti: ['calcio_volante'] },
  loto: { distanza: 1.6, arma: 'fists', gcd: (S) => rotazione(S, { f1: 'pugno_ferro', f2: 'calcio_gru', fin: 'vortice_interiore' }), fuori: { respiro_drago: () => true, meditazione: () => true }, scatti: ['calcio_volante'] },
  tempesta: { distanza: 12, arma: 'staff', gcd: (S) => rotazione(S, { f1: 'dardo_luce', f2: 'sfera_celeste', fin: 'giudizio_cielo' }), fuori: { benedizione_astri: () => true, occhio_ciclone: () => true }, scatti: ['passo_luce'] },
};
const BERSAGLIATE = ['strike', 'aoe_target', 'debuff', 'taunt'];
const dist2 = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

// ------------------------------------------------------------------ bot
class Bot {
  constructor(via, zonaId, opt, porta) {
    this.via = via; this.zonaId = zonaId; this.zona = ZONE[zonaId]; this.opt = opt; this.porta = porta;
    this.livello = (opt.livello || this.zona.livello) + opt.bonus;
    this.cls = VIE[via].cls;
    this.rot = ROTAZIONI[via];
    this.sup = (supremaOf(this.cls) || {}).id || null;
    this.p0 = performance.now();
    this.me = null; this.id = 0; this.pos = { x: 0, z: 0 };
    this.inv = null; this.eq = null;
    this.mob = new Map(); this.drops = new Map();
    this.attese = [];
    this.cds = {}; this.blocco = {}; this.buffs = {};
    this.gcdFino = 0; this.lancio = null; this.attesa = null; this.prossimoAtk = 0;
    this.ultimoBase = null; this.fuoriAttesa = {};
    this.scatti = 0; this.serieMax = 0; this.serieSomma = 0; this.serieN = 0;
    this.ostili = new Map();        // id del mostro -> istante dell'ultimo colpo subito da lui
    this.primo = 0; this.ondaGiro = 0; this.passoMove = 0; this.pozioneFino = 0; this.rinasciFino = 0;
    this.inCorso = false;
    // misure
    this.uccisioni = 0; this.exp = 0; this.tael = 0; this.subiti = 0; this.minVita = 1; this.morti = 0; this.pozioni = 0;
    this.oggetti = { equip: 0, gemme: 0, modif: 0, materiali: 0, altro: 0 }; this.valore = 0; this.dettaglio = {};
    this.utili = 0; this.utiliPregiati = 0;
    this.tCombatto = 0; this.tCammino = 0; this.tMorto = 0; this.livelloIniziale = 0; this.expIniziale = 0;
    this.chiuso = null;
  }

  ora() { return (performance.now() - this.p0) * this.opt.velocita; }
  dormi(ms) { return new Promise((r) => setTimeout(r, ms / this.opt.velocita)); }
  manda(o) { if (this.ws.readyState === 1) this.ws.send(JSON.stringify(o)); }
  chat(m) { this.manda({ t: 'chat', m }); }

  attendi(descr, cond, ms = 10000) {
    return new Promise((ok, no) => {
      const a = { cond, ok, scade: setTimeout(() => { this.attese = this.attese.filter((x) => x !== a); no(new Error(`[${this.via}/${this.zonaId}] tempo scaduto: ${descr}${this.ultimoErr ? ' (' + this.ultimoErr + ')' : ''}`)); }, ms) };
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
      case 'err': this.ultimoErr = m.m; break;
      case 'me': {
        const eraMorto = this.me && this.me.dead;
        this.me = m;
        this.buffs = {};
        for (const b of m.buffs) this.buffs[b.b] = ora + b.ms;
        if (this.inCorso) {
          if (m.dead && !eraMorto) this.morti++;
          this.minVita = Math.min(this.minVita, m.hp / m.mhp);
          this.serieMax = Math.max(this.serieMax, m.se || 0);
        }
        break;
      }
      case 'r':
        if (!this.me) break;
        this.me.hp = m.hp; this.me.res = m.res; this.me.pts = m.pts;
        if (this.inCorso) { this.minVita = Math.min(this.minVita, m.hp / this.me.mhp); this.serieMax = Math.max(this.serieMax, m.se || 0); }
        break;
      case 'v':
        for (const e of m.a || []) {
          if (e.k === 'm') this.mob.set(e.id, { ty: e.ty, x: e.x, z: e.z, hp: e.hp, mhp: e.mhp, lvl: e.lvl });
          else if (e.k === 'd') this.dropVisto(e);
        }
        for (const u of m.u || []) {
          const q = this.mob.get(u[0]);
          if (q) { q.x = u[1]; q.z = u[2]; q.hp = u[4]; q.mhp = u[5]; }
        }
        for (const id of m.r || []) this.mob.delete(id);   // i bottini visti restano in `drops`: uscire e rientrare dalla vista non li fa contare due volte
        break;
      case 'cast':
        this.lancio = { sid: m.s, fino: ora + m.ms, costo: this.attesa && this.attesa.sid === m.s ? this.attesa.costo : 0 };
        if (m.gcd) this.gcdFino = ora + m.gcd;
        this.attesa = null;
        break;
      case 'castend': if (!m.ok) this.lancio = null; else if (this.lancio) this.lancio.finito = true; break;
      case 'skfail':
        if (this.attesa && this.attesa.sid === m.s) { this.gcdFino = this.attesa.gcdPrima; this.attesa = null; }
        this.blocco[m.s] = 0;
        break;
      case 'cd': if (m.rid) { this.cds[m.s] = ora + m.ms; break; } this.usata(m, ora); break;   // rid: ricarica accorciata da un'uccisione
      case 'fx': if (m.k === 'hit' && m.d === this.id && m.s !== this.id) { if (this.inCorso) this.subiti += m.v || 0; this.ostili.set(m.s, ora); } break;
      case 'gain':
        if (!this.inCorso) break;
        if (m.exp) { this.exp += m.exp; this.uccisioni++; }
        if (m.tael) this.tael += m.tael;
        break;
    }
  }

  dropVisto(e) {
    if (this.drops.has(e.id)) return;
    this.drops.set(e.id, 1);
    if (!this.inCorso || e.own !== this.id) return;
    const it = ITEMS[e.it];
    if (!it) return;
    const n = e.n || 1;
    const cat = equipSlotOf(it) ? 'equip' : it.type === 'gem' ? 'gemme' : it.type === 'mod' ? 'modif' : it.type === 'material' || it.type === 'seal' || it.type === 'book' ? 'materiali' : 'altro';
    this.oggetti[cat] += n;
    // «utili»: pezzi che il personaggio può indossare ora (classe e livello) e non più vecchi di un grado
    if (cat === 'equip' && (it.type !== 'weapon' || CLASSES[this.cls].weapons.includes(it.wt)) && it.lvl <= this.livello && it.lvl > this.livello - 10) {
      this.utili++;
      if ((e.r || 0) >= 1) this.utiliPregiati++;
    }
    this.valore += (it.price || 0) * n;
    this.dettaglio[e.it] = (this.dettaglio[e.it] || 0) + n;
  }

  usata(m, ora) {
    const sk = SKILLS[m.s];
    if (!sk) return;
    if (m.ms) this.cds[m.s] = ora + m.ms;
    if (m.gcd) this.gcdFino = ora + m.gcd;
    let costo = 0;
    if (this.lancio && this.lancio.sid === m.s) { costo = this.lancio.costo; this.lancio = null; }
    else if (this.attesa && this.attesa.sid === m.s) { costo = this.attesa.costo; this.attesa = null; }
    else if (this.fuoriAttesa[m.s] !== undefined) { costo = this.fuoriAttesa[m.s]; delete this.fuoriAttesa[m.s]; }
    if (this.me) {
      this.me.res = Math.max(0, this.me.res - costo);
      if ((sk.spend && sk.type !== 'heal_aoe') || sk.finale) this.me.pts = 0;
      if (sk.ruolo === 'accumulo') this.ultimoBase = m.s;
      if (sk.pts) this.me.pts = Math.min(PTS_MAX, this.me.pts + sk.pts);
      if (sk.sup) this.me.su = 0;
    }
  }

  // ---------------------------------------------------------------- preparazione
  async prepara() {
    const c = CLASSES[this.cls], L = this.livello;
    await this.collega();
    this.manda({ t: 'register', user: 'admin', pass: 'farming' });
    await this.attendi('accesso', () => this.autenticato && this.personaggi);
    this.personaggi = null;
    this.manda({ t: 'create', name: 'Fa' + this.via[0].toUpperCase() + this.via.slice(1) + this.zonaId[0], cls: this.cls, kd: 'fenice', sex: 'm' });
    const lista = await this.attendi('creazione del personaggio', () => this.personaggi && this.personaggi.length && this.personaggi);
    this.manda({ t: 'play', id: lista[0].id });
    await this.attendi('ingresso nel mondo', () => this.id && this.me && this.inv);
    this.chat(`/level ${L}`);
    await this.attendi('/level', () => this.me.lvl === L);
    if (L >= 5) { this.chat(`/via ${this.via}`); await this.attendi('/via', () => this.me.via === this.via); }
    // equipaggiamento del livello: arma e tre pezzi di armatura, rarità comune, senza potenziamento
    const migliore = (filtro) => Object.entries(ITEMS).filter(([, it]) => filtro(it) && it.lvl <= L).sort((a, b) => b[1].lvl - a[1].lvl)[0];
    const pezzi = [migliore((it) => it.type === 'weapon' && it.wt === this.rot.arma), ...['body', 'head', 'feet'].map((s) => migliore((it) => it.type === s))].filter(Boolean).map(([id]) => id);
    for (const id of pezzi) {
      if (Object.values(this.eq).some((s) => s && s.id === id)) continue;
      this.chat(`/item ${id} 1 0 0`);
      const i = await this.attendi('/item', () => { const k = this.inv.findIndex((s) => s && s.id === id); return k >= 0 ? k + 1 : 0; });
      this.manda({ t: 'use', i: i - 1 });
      await this.attendi(`equipaggiamento di ${id}`, () => Object.values(this.eq).some((s) => s && s.id === id));
    }
    this.arma = pezzi[0];
    // punti statistica: due al valore primario, uno alla vitalità (il difensore al contrario)
    const prim = c.primary === 'dex' ? 'dex' : c.primary === 'int' ? 'int' : 'str';
    let n = this.me.sp;
    const quotaVit = this.rot.vitalita ?? 1 / 3;
    for (let i = 0, vit = 0; i < n; i++) {
      const inVit = (vit + 1) / (i + 1) <= quotaVit + 1e-9;
      if (inVit) vit++;
      this.manda({ t: 'stat', s: inVit ? 'vit' : prim });
      if (i % 20 === 19) await this.dormi(450);
    }
    await this.attendi('punti statistica', () => this.me.sp === 0);
    // punti abilità: in parti uguali fra le tecniche con ruolo (e la Suprema)
    const mie = Object.values(SKILLS).filter((s) => s.cls === this.cls && (!s.via || s.via === this.via) && s.lvl <= L && (s.ruolo || s.sup) && !s.finoVia).map((s) => s.id);
    n = this.me.kp;
    for (let i = 0; i < n && mie.length; i++) { this.manda({ t: 'skup', s: mie[i % mie.length] }); if (i % 20 === 19) await this.dormi(450); }
    if (mie.length) await this.attendi('punti abilità', () => this.me.kp === 0);
    // scorta di ginseng (il più forte che si trova a questo livello)
    const gin = L >= 20 ? 'ginseng_g' : L >= 8 ? 'ginseng_m' : 'ginseng_p';
    this.chat(`/item ${gin} 99 0 0`);
    await this.attendi('ginseng', () => this.inv.some((s) => s && s.id === gin));
    this.ginseng = gin;
    // punto di partenza: sull'anello della zona, in direzione del centro della mappa
    const z = this.zona, rm = (z.rmin + z.rmax) / 2;
    const a0 = Math.atan2(CENTER.z - z.centro.z, CENTER.x - z.centro.x);
    this.angolo = z.centro === CENTER ? Math.PI / 2 : a0;
    const p0 = this.puntoAnello(this.angolo, rm);
    this.chat(`/tp ${p0.x.toFixed(1)} ${p0.z.toFixed(1)}`);
    const k = this.nPos || 0;
    await this.attendi('/tp', () => (this.nPos || 0) > k);
    this.chat('/heal');
    await this.dormi(800);
  }

  puntoAnello(a, r) { return { x: this.zona.centro.x + Math.cos(a) * r, z: this.zona.centro.z + Math.sin(a) * r }; }

  // ---------------------------------------------------------------- scelte del bot
  eligibile(q) {
    if (!q.hp || q.hp <= 0 || !this.zona.tipi.includes(q.ty)) return false;
    const r = dist2(q, this.zona.centro);
    return r >= this.zona.rmin - 6 && r <= this.zona.rmax + 6;
  }
  vivo(q) { return q && q.hp > 0; }

  scegliBersaglio(ora) {
    // prima chi mi sta colpendo (o è vicino e ostile), poi il più vicino della zona
    let best = null, bd = Infinity;
    for (const [id, t] of this.ostili) {
      const q = this.mob.get(id);
      if (!this.vivo(q) || ora - t > 4000) { if (!this.vivo(q) || ora - t > 12000) this.ostili.delete(id); continue; }
      const d = dist2(q, this.pos);
      if (d < bd) { bd = d; best = id; }
    }
    if (best) return best;
    for (const [id, q] of this.mob) {
      if (!this.eligibile(q)) continue;
      const d = dist2(q, this.pos);
      if (d < bd) { bd = d; best = id; }
    }
    return best || 0;
  }

  vicini(centro, raggio) {
    let n = 0;
    for (const q of this.mob.values()) if (this.vivo(q) && q.ty !== 'fantoccio' && dist2(q, centro) <= raggio) n++;
    return n;
  }

  camminaVerso(x, z, ora) {
    if (ora < this.passoMove) return;
    const dt = Math.min(0.2, (ora - (this.ultimoPasso || ora - 50)) / 1000);
    this.ultimoPasso = ora; this.passoMove = ora + 50;
    const dx = x - this.pos.x, dz = z - this.pos.z, d = Math.hypot(dx, dz);
    if (d < 0.05) return;
    const st = Math.min(d, (this.me.spd || 8) * Math.max(dt, 0.05));
    this.pos = { x: this.pos.x + dx / d * st, z: this.pos.z + dz / d * st };
    this.manda({ t: 'move', x: +this.pos.x.toFixed(2), z: +this.pos.z.toFixed(2), r: +Math.atan2(dx, dz).toFixed(2) });
  }

  // ---------------------------------------------------------------- stato visto dalla rotazione
  conosce(sid) {
    const sk = SKILLS[sid], me = this.me;
    if (!sk || sk.cls !== this.cls || me.lvl < sk.lvl) return false;
    if (sk.via && sk.via !== me.via) return false;
    if (sk.finoVia && me.via) return false;
    if (sk.req && ITEMS[this.arma].wt !== sk.req) return false;
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
      if (d.finaleGratis && sk.finale) return 0;
      if (d.costMod && d.costMod[sid]) c += d.costMod[sid];
    }
    c = Math.max(0, c);
    return this.me.rt === 'mana' ? Math.round(this.me.rmax * c / 100) : c;
  }
  stato(bers) {
    const ora = this.ora(), me = this.me, bot = this;
    return {
      sup: this.sup, res: me.res, rmax: me.rmax, pts: me.pts, ultimoBase: this.ultimoBase,
      multi: this.vicini(bers, 4.5) >= 3,
      b: (id) => Math.max(0, (bot.buffs[id] || 0) - ora),
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

  // uno scatto verso il bersaglio lontano, se pronto e a portata (Passo di Luce: nella direzione del bersaglio)
  provaScatti(ora, id, q, d) {
    for (const sid of this.rot.scatti || []) {
      const sk = SKILLS[sid];
      if (!this.conosce(sid) || (this.cds[sid] || 0) > ora || (this.blocco[sid] || 0) > ora) continue;
      const portata = sk.type === 'blink' ? sk.dist + this.rot.distanza + 2 : sk.range + 1.5;
      if (d > portata) continue;
      this.lancia(sid, ora, id, Math.atan2(q.x - this.pos.x, q.z - this.pos.z));
      this.scatti++;
    }
  }

  lancia(sid, ora, id, r) {
    const sk = SKILLS[sid], costo = this.costo(sid);
    const bid = BERSAGLIATE.includes(sk.type) ? id : 0;
    if (sk.offgcd) { this.blocco[sid] = ora + 300; this.fuoriAttesa[sid] = costo; }
    else { this.attesa = { sid, costo, gcdPrima: this.gcdFino, da: ora }; this.gcdFino = ora + (this.me.gcd || 1000); }
    this.manda(r === undefined ? { t: 'skill', s: sid, id: bid } : { t: 'skill', s: sid, id: bid, r: +r.toFixed(2) });
  }

  passo(dtMs) {
    const ora = this.ora(), me = this.me;
    if (!me) return;
    if (me.dead) {
      this.tMorto += dtMs;
      if (ora >= this.rinasciFino) { this.manda({ t: 'respawn', mode: 'village' }); this.rinasciFino = ora + 1000; }
      return;
    }
    if (this.attesa && ora - this.attesa.da > 800) this.attesa = null;
    // ginseng sotto il 40% di vita (al massimo uno ogni 3 secondi)
    if (me.hp / me.mhp < 0.4 && ora >= this.pozioneFino) {
      const i = this.inv.findIndex((s) => s && s.id === this.ginseng);
      if (i >= 0) { this.manda({ t: 'use', i }); this.pozioni++; this.pozioneFino = ora + 3000; this.inv[i] = { ...this.inv[i], n: this.inv[i].n - 1 }; if (this.inv[i].n <= 0) this.inv[i] = null; }
    }
    const id = this.scegliBersaglio(ora);
    this.primo = id;
    const q = id ? this.mob.get(id) : null;
    if (!q) {
      // nessun bersaglio in vista: pattuglia l'anello della zona
      this.tCammino += dtMs;
      const z = this.zona, rm = (z.rmin + z.rmax) / 2;
      let w = this.puntoAnello(this.angolo, rm);
      if (dist2(w, this.pos) < 6) { this.angolo += 0.35; w = this.puntoAnello(this.angolo, rm); }
      this.camminaVerso(w.x, w.z, ora);
      return;
    }
    const d = dist2(q, this.pos), st = this.rot.distanza;
    if (d > st + 0.6) {
      this.tCammino += dtMs;
      // si ferma a distanza di tiro dal bersaglio
      const k = (d - st) / d;
      this.camminaVerso(this.pos.x + (q.x - this.pos.x) * k, this.pos.z + (q.z - this.pos.z) * k, ora);
      if (d > st + 4) this.provaScatti(ora, id, q, d);
      if (d > 14) return;                         // troppo lontano per colpire
    } else this.tCombatto += dtMs;
    const lanciando = this.lancio && !this.lancio.finito;
    if (!lanciando && ora >= this.prossimoAtk) { this.manda({ t: 'atk', id }); this.prossimoAtk = ora + me.aspd; }
    const S = this.stato(q);
    for (const [sid, cond] of Object.entries(this.rot.fuori || {})) {
      if ((this.blocco[sid] || 0) > ora || !S.ok(sid) || !cond(S)) continue;
      // le auree si accendono una volta sola (ripremere il tasto le spegnerebbe)
      if (SKILLS[sid].aura) { if ((me.buffs || []).some((b) => b.b === SKILLS[sid].buff) || ora < (this.auraProva || 0)) continue; this.auraProva = ora + 3000; }
      this.lancia(sid, ora, id);
    }
    if (ora >= this.gcdFino && !this.lancio && !this.attesa && d <= st + 2.5) {
      const sid = this.rot.gcd(S);
      if (sid && S.ok(sid)) this.lancia(sid, ora, id);
    }
  }

  async gira() {
    const durata = this.opt.minuti * 60000;
    this.inCorso = true;
    this.livelloIniziale = this.me.lvl; this.expIniziale = this.me.exp;
    const t0 = this.ora();
    let ultimo = t0;
    while (this.ora() - t0 < durata) {
      if (this.chiuso) throw new Error(`[${this.via}/${this.zonaId}] ${this.chiuso}`);
      const ora = this.ora();
      this.passo(ora - ultimo);
      ultimo = ora;
      await this.dormi(15);
    }
    this.inCorso = false;
    this.durata = (this.ora() - t0) / 1000;
  }

  risultato() {
    const T = this.durata, min = T / 60, me = this.me;
    const bisogno = expToNext(this.livelloIniziale);
    return {
      zona: this.zonaId, via: this.via, livello: this.livelloIniziale, livelloFinale: me.lvl, minuti: min,
      uccisioni: this.uccisioni, ucc_min: this.uccisioni / min,
      exp: this.exp, exp_min: this.exp / min, exp_ora_pct_livello: this.exp / min * 60 / bisogno * 100,
      tael_min: this.tael / min,
      subiti_min: this.subiti / min, vita_min_pct: this.minVita * 100, morti: this.morti, pozioni: this.pozioni,
      oggetti: this.oggetti, equip_ora: this.oggetti.equip / min * 60, utili_ora: this.utili / min * 60, pregiati_ora: this.utiliPregiati / min * 60, valore_min: this.valore / min, dettaglio: this.dettaglio,
      scatti_min: this.scatti / min, serie_max: this.serieMax,
      quote: { combatte: this.tCombatto / (T * 1000) * 100, cammina: this.tCammino / (T * 1000) * 100, morto: this.tMorto / (T * 1000) * 100 },
    };
  }
}

async function prova(via, zona, opt) {
  const srv = await avviaServer(opt.velocita);
  const bot = new Bot(via, zona, opt, srv.porta);
  try {
    await bot.prepara();
    await bot.gira();
    return bot.risultato();
  } finally {
    try { bot.ws && bot.ws.close(); } catch { /* niente */ }
    await new Promise((r) => setTimeout(r, 50));
    srv.chiudi();
  }
}

// ------------------------------------------------------------------ main
async function main() {
  const opt = leggiOpzioni(process.argv.slice(2));
  const lavori = [];
  for (const zona of opt.zone) for (const via of opt.vie) for (let k = 0; k < opt.ripeti; k++) lavori.push({ zona, via });
  const risultati = [];
  let prossimo = 0;
  const operaio = async () => {
    while (prossimo < lavori.length) {
      const l = lavori[prossimo++];
      try {
        const r = await prova(l.via, l.zona, opt);
        risultati.push(r);
        console.error(`fatto: ${l.zona}/${l.via} -> ${r.ucc_min.toFixed(1)} uccisioni/min`);
      } catch (e) { console.error(`ERRORE ${l.zona}/${l.via}: ${e.message}`); }
    }
  };
  await Promise.all(Array.from({ length: opt.paralleli }, operaio));
  // media delle ripetizioni per (zona, via)
  const gruppi = new Map();
  for (const r of risultati) { const k = r.zona + '/' + r.via; (gruppi.get(k) || gruppi.set(k, []).get(k)).push(r); }
  const media = (l, f) => l.reduce((s, r) => s + f(r), 0) / l.length;
  console.log(`\nFarming: ${opt.minuti} min di gioco per prova, velocità ${opt.velocita}, ${opt.ripeti} prova/e per riga${opt.bonus ? `, livello +${opt.bonus}` : ''}`);
  console.log('zona/via          liv  ucc/min  exp/min  exp/h(%liv)  tael/min  subiti/s  vitaMin%  morti  ginseng  equip/h  utili/h (pregiati)  valore/min  (combatte/cammina/morto %)');
  const righe = [];
  for (const [k, l] of [...gruppi.entries()].sort()) {
    const r = {
      chiave: k, livello: l[0].livello, ucc_min: media(l, (r) => r.ucc_min), exp_min: media(l, (r) => r.exp_min), exp_ora_pct: media(l, (r) => r.exp_ora_pct_livello),
      tael_min: media(l, (r) => r.tael_min), subiti_s: media(l, (r) => r.subiti_min / 60), vita_min: Math.min(...l.map((r) => r.vita_min_pct)),
      morti: media(l, (r) => r.morti), pozioni: media(l, (r) => r.pozioni), equip_ora: media(l, (r) => r.equip_ora), utili_ora: media(l, (r) => r.utili_ora), pregiati_ora: media(l, (r) => r.pregiati_ora), valore_min: media(l, (r) => r.valore_min),
      quote: ['combatte', 'cammina', 'morto'].map((q) => Math.round(media(l, (r) => r.quote[q]))),
      livelli: media(l, (r) => r.livelloFinale - r.livello),
      scatti_min: media(l, (r) => r.scatti_min || 0), serie_max: Math.max(...l.map((r) => r.serie_max || 0)),
    };
    righe.push(r);
    console.log(`${k.padEnd(16)} ${String(r.livello).padStart(4)} ${r.ucc_min.toFixed(1).padStart(8)} ${r.exp_min.toFixed(0).padStart(8)} ${r.exp_ora_pct.toFixed(0).padStart(11)}% ${r.tael_min.toFixed(0).padStart(9)} ${r.subiti_s.toFixed(1).padStart(9)} ${r.vita_min.toFixed(0).padStart(9)} ${r.morti.toFixed(1).padStart(6)} ${r.pozioni.toFixed(0).padStart(8)} ${r.equip_ora.toFixed(1).padStart(8)} ${r.utili_ora.toFixed(1).padStart(8)} (${r.pregiati_ora.toFixed(1).padStart(5)}) ${r.valore_min.toFixed(0).padStart(11)}   (${r.quote.join('/')})${r.livelli ? `  +${r.livelli.toFixed(1)} livelli` : ''}  scatti/min ${r.scatti_min.toFixed(1)}, serie max ${r.serie_max}`);
  }
  if (opt.json) fs.writeFileSync(opt.json, JSON.stringify({ opzioni: opt, righe, risultati }, null, 1));
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
