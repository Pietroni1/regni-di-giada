// Prova del contenuto per il livello alto con bot WebSocket (shared/altolivello.js, server/altolivello.js):
// boss del mondo (annunci, comparsa, fasi, lanci interrompibili, zone a terra, furia, premi a chi ha partecipato,
// imprese e titoli), Forgia del Drago Addormentato (requisito, scelta dal Custode, corazza e mantici, completamento),
// stagione dell'Arena (punti, onore, negozio dell'Araldo, chiusura della stagione, database).
// Uso: node tools/prove/altolivello.mjs [porta]  (predefinita 4102)
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
const { newCharacter } = await import(path.join(RADICE, 'server/world.js'));
const { MOBS, ITEMS, BOSS_MONDO, FORGIA, TITOLI } = await import(path.join(RADICE, 'shared/data.js'));

const { componiPianta } = await import(path.join(RADICE, 'shared/prove.js'));
const DBF = path.join(os.tmpdir(), `regni-prova-altolivello-${PORTA}.json`);
try { fs.unlinkSync(DBF); } catch {}
const db = new DB(DBF);
db.createAccount('admin', 'prova');
db.createAccount('compagno', 'prova');
const a = newCharacter('Provalama', 'lama', 'fenice', 'm'); a.lvl = 40; a.tael = 100000;
db.createChar('admin', a);
const b = newCharacter('Compagna', 'mistico', 'fenice', 'f'); b.lvl = 40; b.tael = 100000;
db.createChar('compagno', b);
db.save();

const attesa = (ms) => new Promise(r => setTimeout(r, ms));
let srv;
async function avvia() {
  srv = spawn(process.execPath, [path.join(RADICE, 'server/index.js')], { cwd: RADICE, env: { ...process.env, PORT: String(PORTA), DB_FILE: DBF, GM_EXTRA: 'compagno' }, stdio: ['ignore', 'pipe', 'pipe'] });
  let err = '';
  srv.stderr.on('data', d => { err += d; process.stderr.write(d); });
  await new Promise((ok, no) => {
    srv.stdout.on('data', d => { if (String(d).includes('server avviato')) ok(); });
    srv.on('exit', c => no(new Error('server chiuso ' + c + err)));
  });
}

class Bot {
  constructor(user) { this.user = user; this.ents = new Map(); this.log = []; this.attese = []; this.me = null; this.inv = null; }
  async entra() {
    this.ws = new WebSocket(`ws://127.0.0.1:${PORTA}/ws`);
    await new Promise(ok => this.ws.on('open', ok));
    this.ws.on('message', raw => this.ricevi(JSON.parse(raw)));
    this.manda({ t: 'login', user: this.user, pass: 'prova' });
    const ch = await this.aspetta(m => m.t === 'chars');
    this.manda({ t: 'play', id: ch.list[0].id });
    const e = await this.aspetta(m => m.t === 'enter');
    this.id = e.id; this.x = e.x; this.z = e.z;
    return e;
  }
  ricevi(m) {
    this.log.push(m);
    if (m.t === 'v') {
      for (const i of m.a) this.ents.set(i.id, i);
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e) { e.x = u[1]; e.z = u[2]; e.hp = u[4]; e.dead = u[7]; if (u.length > 8) { e.po = u[8]; e.sq = u[9]; } } }
      for (const id of m.r) this.ents.delete(id);
    }
    if (m.t === 'pos') { this.x = m.x; this.z = m.z; }
    if (m.t === 'me') this.me = m;
    if (m.t === 'r' && this.me) { this.me.hp = m.hp; }
    if (m.t === 'inv') this.inv = m;
    for (const w of [...this.attese]) if (w.f(m)) { this.attese.splice(this.attese.indexOf(w), 1); w.ok(m); }
  }
  aspetta(f, ms = 6000) {
    return new Promise((ok, no) => {
      const w = { f, ok };
      this.attese.push(w);
      setTimeout(() => { const i = this.attese.indexOf(w); if (i >= 0) { this.attese.splice(i, 1); no(new Error(`${this.user}: attesa scaduta`)); } }, ms);
    });
  }
  // come aspetta, ma cerca anche nei messaggi già arrivati (dall'indice `da`)
  trova(f, da = 0) { return this.log.slice(da).find(f) || null; }
  // il messaggio, se è già arrivato dopo l'indice `da`, altrimenti lo aspetta
  prendi(f, da, ms = 6000) { return this.trova(f, da) || this.aspetta(f, ms); }
  manda(m) { this.ws.send(JSON.stringify(m)); }
  async cmd(c) { this.manda({ t: 'chat', m: c }); await attesa(250); }
  vicino(f) {
    let best = null, bd = 1e9;
    for (const e of this.ents.values()) if (f(e)) { const d = Math.hypot(e.x - this.x, e.z - this.z); if (d < bd) { bd = d; best = e; } }
    return best;
  }
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
  quanti(id) { return this.inv ? this.inv.inv.filter(s => s && s.id === id).reduce((n, s) => n + (s.n || 1), 0) : 0; }
  chiudi() { this.ws.close(); }
}

const esiti = [];
const verifica = (cond, testo) => { esiti.push([!!cond, testo]); console.log(`${cond ? 'OK ' : 'NO '} ${String(esiti.length).padStart(2)}. ${testo}`); };

async function main() {
  await avvia();
  const A = new Bot('admin');
  await A.entra();
  const B = new Bot('compagno');
  await B.entra();
  await attesa(400);

  // ------------------------------------------------ boss del mondo: elenco, annunci, comparsa
  const el = A.trova(m => m.t === 'boss_mondo');
  verifica(el && el.l.length === 3 && el.l.every(x => !x.vivo && x.tra > 0), `elenco dei boss del mondo all'ingresso: ${el && el.l.map(x => `${x.id} fra ${Math.round(x.tra / 60000)} min`).join(', ')}`);
  const n0 = A.log.length;
  await A.cmd('/boss colosso_ardente tra 0.06');
  const avv = await A.prendi(m => m.t === 'notice' && /Fra 1 minuto/.test(m.m) && /Colosso/.test(m.m), n0, 8000);
  verifica(avv, `annuncio a tutti prima della comparsa: «${avv.m}»`);
  const comp = await A.prendi(m => m.t === 'notice' && /Colosso Ardente è comparso/.test(m.m), n0, 12000);
  const el2 = await A.prendi(m => m.t === 'boss_mondo' && m.l.find(x => x.id === 'colosso_ardente').vivo, n0);
  const bm = el2.l.find(x => x.id === 'colosso_ardente');
  verifica(comp && Math.hypot(bm.x - BOSS_MONDO.colosso_ardente.x, bm.z - BOSS_MONDO.colosso_ardente.z) < 1, `comparsa annunciata («${comp.m}») e segnata sulla mappa a ${bm.x}, ${bm.z}`);

  // ------------------------------------------------ combattimento: fase, lancio interrotto, zone a terra
  // livello alto per reggere senza cure vere: qui si provano le meccaniche (la tenuta la misura tools/sim/boss.mjs)
  await A.cmd('/level 60');
  await B.cmd('/level 60');
  await A.cmd(`/tp ${bm.x} ${bm.z - 6}`);
  await B.cmd(`/tp ${bm.x + 2} ${bm.z - 9}`);
  await attesa(600);
  const boss = A.vicino(e => e.k === 'm' && e.ty === 'colosso_ardente');
  verifica(boss && boss.mhp === MOBS.colosso_ardente.hp && boss.po === 100, `Colosso visibile: ${boss && boss.n}, vita ${boss && boss.mhp}, Postura ${boss && boss.po}%`);
  const nLog = A.log.length;
  const tStato = A.aspetta(m => m.t === 'boss' && m.ty === 'colosso_ardente', 8000);
  const tCast = A.aspetta(m => m.t === 'fx' && m.k === 'mcast' && m.s === boss.id, 15000);
  const tZona = A.aspetta(m => m.t === 'fx' && m.k === 'warn' && Math.hypot(m.x - A.x, m.z - A.z) < 1.5, 15000);
  // la compagna (Mistico) partecipa colpendo da lontano
  let colpi = true;
  // (le cure GM tengono in piedi i bot: qui si provano le meccaniche, non la tenuta)
  (async () => { for (let k = 0; colpi; k++) { A.manda({ t: 'atk', id: boss.id }); B.manda({ t: 'atk', id: boss.id }); A.manda({ t: 'chat', m: '/heal' }); B.manda({ t: 'chat', m: '/heal' }); await attesa(300); } })();
  const st = await tStato;
  verifica(st.f === 0 && st.fuS > 250, `stato del boss in combattimento: fase ${st.f}, furia fra ${st.fuS} s, vita ${st.hp}/${st.mhp}`);
  const cast = await tCast;
  const po0 = A.ents.get(boss.id).po;
  A.manda({ t: 'skill', s: 'carica', id: boss.id });
  const fine = await A.aspetta(m => m.t === 'fx' && m.k === 'mcastend' && m.s === boss.id, 6000);
  await attesa(300);
  const po1 = A.ents.get(boss.id).po;
  verifica(fine.int === 1 && po1 < po0, `lancio «${cast.n}» (${cast.ms} ms, raggio ${cast.r}) interrotto con la Carica: Postura ${po0}% → ${po1}%`);
  const zona = await tZona;
  verifica(zona.r > 0 && zona.ms > 1500, `cerchio a terra sotto il giocatore (raggio ${zona.r}, preavviso ${zona.ms} ms)`);

  const pozza = await A.aspetta(m => m.t === 'fx' && m.k === 'hazard', 8000).catch(() => null);
  verifica(pozza && pozza.ms >= 5000, `pozza ardente dopo i lapilli: ${pozza && JSON.stringify({ r: pozza.r, ms: pozza.ms })}`);
  // fase 2: rinforzi
  const tFase = A.aspetta(m => m.t === 'notice' && /Soldati di Brace/.test(m.m), 6000);
  await A.cmd('/boss colosso_ardente vita 0.68');
  const fase = await tFase;
  await attesa(800);
  const soldati = [...A.ents.values()].filter(e => e.k === 'm' && e.ty === 'soldato_brace');
  const st2 = A.log.filter(m => m.t === 'boss').pop();
  verifica(fase && soldati.length >= 3 && st2.f === 1, `fase «${MOBS.colosso_ardente.mecc.fasi[1].nome}»: «${fase.m}», ${soldati.length} Soldati di Brace`);
  // morte: premi a entrambi (la compagna ha solo partecipato)
  for (let i = 0; i < 25; i++) await attesa(1000);   // presenza in combattimento per i premi (20 s)
  colpi = false;
  await A.cmd('/heal');
  const tPremiA = A.aspetta(m => m.t === 'boss_premi', 10000);
  const tPremiB = B.aspetta(m => m.t === 'boss_premi', 10000);
  const tImpresa = B.aspetta(m => m.t === 'impresa', 10000);
  await A.cmd('/boss colosso_ardente vita 0.0001');
  for (let i = 0; i < 20 && !A.trova(m => m.t === 'boss_premi'); i++) { A.manda({ t: 'atk', id: boss.id }); A.manda({ t: 'chat', m: '/heal' }); await attesa(300); }
  const pa = await tPremiA, pb = await tPremiB;
  await attesa(500);
  verifica(pa.got.length >= 5 && pb.got.length >= 5, `premi personali — Provalama: ${pa.got.join(', ')} | Compagna: ${pb.got.join(', ')}`);
  verifica(B.quanti('trofeo_colosso') === 1, `trofeo nell'inventario della compagna: ${B.quanti('trofeo_colosso')} × ${ITEMS.trofeo_colosso.name}`);
  const imp = await tImpresa;
  verifica(imp.id === 'spezzacolossi' && imp.ti === TITOLI.spezzacolossi.nome, `impresa e titolo: ${imp.n} → «${imp.ti}»`);
  const el3 = A.log.filter(m => m.t === 'boss_mondo').pop().l.find(x => x.id === 'colosso_ardente');
  verifica(!el3.vivo && el3.tra > 40 * 60000, `nuova comparsa programmata fra ${Math.round(el3.tra / 60000)} minuti`);
  // titolo sopra il nome
  const nV = A.log.length;
  await B.cmd('/titolo spezzacolossi');
  await attesa(500);
  const infoB = A.log.slice(nV).filter(m => m.t === 'v').flatMap(m => m.a).find(i => i.id === B.id);
  verifica(infoB && infoB.ti === 'spezzacolossi', `titolo di Compagna visto dagli altri: ${infoB && infoB.ti}`);
  B.manda({ t: 'alto', a: 'imprese' });
  const ib = await B.aspetta(m => m.t === 'imprese');
  verifica(ib.tit === 'spezzacolossi' && ib.l.find(x => x.id === 'spezzacolossi').fatto === 1, `finestra delle imprese: ${ib.l.filter(x => x.fatto).map(x => x.n).join(', ')}; titoli ${ib.titoli.join(', ')}`);
  verifica(A.log.slice(nLog).some(m => m.t === 'fx' && m.k === 'mcast' && m.r > 0) && A.log.slice(nLog).some(m => m.t === 'notice' && /interrompetelo/.test(m.m)), 'annuncio del lancio ad area da interrompere');
  // un solo giocatore non regge: la madre delle canne nella Selva, da solo con la furia
  await A.cmd('/heal');
  const nM = A.log.length;
  await A.cmd('/boss madre_canne');
  const lm = (await A.prendi(m => m.t === 'boss_mondo' && m.l.find(x => x.id === 'madre_canne').vivo, nM)).l.find(x => x.id === 'madre_canne');
  await A.cmd(`/tp ${lm.x} ${lm.z - 7}`);
  await attesa(800);
  const madre = A.vicino(e => e.k === 'm' && e.ty === 'madre_canne');
  verifica(madre && madre.mhp === MOBS.madre_canne.hp, `Madre delle Canne nella Selva: vita ${madre && madre.mhp}`);
  let morto = null;
  const tMorto = A.aspetta(m => m.t === 'dead', 40000).then(m => { morto = m; }).catch(() => {});
  A.manda({ t: 'atk', id: madre.id });
  await attesa(1500);
  const tFuria = A.aspetta(m => m.t === 'notice' && /FURIA/.test(m.m), 6000);
  await A.cmd('/boss madre_canne furia');
  const furia = await tFuria.catch(() => null);
  const slam = await A.aspetta(m => m.t === 'fx' && m.k === 'slam' && m.s === madre.id, 5000).catch(() => null);
  verifica(furia && slam, `furia a tempo: «${furia && furia.m}», onda ogni 2 s`);
  for (let i = 0; i < 200 && !morto; i++) { A.manda({ t: 'atk', id: madre.id }); await attesa(200); }
  await tMorto;
  verifica(morto, `da solo, con la Madre in furia: abbattuto da ${morto && morto.by}`);
  A.manda({ t: 'respawn', mode: 'village' });
  await attesa(3500);
  A.manda({ t: 'respawn', mode: 'village' });
  await A.aspetta(m => m.t === 'pos' && m.alive, 6000).catch(() => {});
  await A.cmd('/boss madre_canne via');

  // ------------------------------------------------ Forgia del Drago Addormentato
  await A.cmd('/tp fenice');
  await attesa(500);
  const cu = A.vicino(e => e.k === 'n' && e.role === 'custode');
  await A.cmd(`/tp ${cu.x} ${cu.z + 2}`);
  await A.cmd('/sigillo 4');
  await A.cmd('/level 30');
  A.manda({ t: 'npc', id: cu.id });
  const tr = await A.aspetta(m => m.t === 'trial');
  verifica(tr.prove && tr.prove.map(p => p.id).join() === 'cripta,forgia' && tr.prove[1].min === FORGIA.minLevel, `il Custode offre due Prove: ${tr.prove.map(p => `${p.n} (dal ${p.min})`).join(', ')}`);
  A.manda({ t: 'trial', npc: cu.id, a: 'open', p: 'forgia' });
  const e1 = await A.aspetta(m => m.t === 'err');
  verifica(/livello 35/.test(e1.m), `requisito della Forgia: «${e1.m}»`);
  await A.cmd('/level 40');
  A.manda({ t: 'trial', npc: cu.id, a: 'open', p: 'forgia' });
  const ds = await A.aspetta(m => m.t === 'dg_start', 6000);
  const dg = await A.aspetta(m => m.t === 'dg', 4000);
  await attesa(800);
  const tipi = new Set([...A.ents.values()].filter(e => e.k === 'm' && e.x > ds.ox - 40 && e.x < ds.ox + 100).map(e => e.ty));
  verifica(ds.dg === 'forgia' && dg.name === FORGIA.name && dg.limit === FORGIA.timeLimit * 1000 && tipi.has('fabbro_cenere'), `Forgia aperta (sigillo +${ds.kl}): ${dg.name}, ${dg.limit / 60000} min, mostri ${[...tipi].join(', ')}`);
  const ox = ds.ox, oz = ds.oz;
  // fino al boss
  const pianta = componiPianta('forgia', ds.pianta.v);   // la variante della settimana, mandata con dg_start
  await A.cmd(`/tp ${ox + pianta.boss.x} ${oz + pianta.boss.z - 10}`);
  await attesa(800);
  const yan = A.vicino(e => e.k === 'm' && e.ty === 'yan_fornace');
  verifica(yan && yan.mhp > 50000, `Yan nel Cuore della Forgia: vita ${yan && yan.mhp}`);
  let colpiY = true;
  (async () => { while (colpiY) { A.manda({ t: 'atk', id: yan.id }); await attesa(300); } })();
  await A.aspetta(m => m.t === 'boss' && m.ty === 'yan_fornace', 8000);
  const tCorazza = A.aspetta(m => m.t === 'notice' && /Corazza di Brace/.test(m.m), 8000);
  const sY = A.log.filter(m => m.t === 'boss' && m.ty === 'yan_fornace').pop();
  await A.cmd('/boss vita 0.49');
  const cor = await tCorazza.catch(() => null);
  await attesa(1500);
  const mantici = [...A.ents.values()].filter(e => e.k === 'm' && e.ty === 'mantice_forgia' && e.hp > 0);
  const sc = A.log.filter(m => m.t === 'boss' && m.ty === 'yan_fornace').pop();
  verifica(cor && mantici.length === 3 && sc.sc === 3, `sotto metà vita (${sY.hp} → ${sc.hp}): «${cor && cor.m}», ${mantici.length} Mantici, corazza attiva (${sc.sc})`);
  colpiY = false;
  await attesa(400);
  const tPezzi = A.aspetta(m => m.t === 'notice' && /va in pezzi/.test(m.m), 10000);
  for (const mt of mantici) { await A.cmd(`/tp ${mt.x} ${mt.z + 1.5}`); await A.cmd('/uccidi'); await attesa(200); }
  const pezzi = await tPezzi.catch(() => null);
  verifica(pezzi, `mantici spenti: «${pezzi && pezzi.m}»`);
  // pulizia della Prova: tutti i mostri abbattuti, poi il boss
  const tFine = A.aspetta(m => m.t === 'dg_reward', 60000);
  const tImp2 = A.aspetta(m => m.t === 'impresa' && m.id === 'forgia_spenta', 60000);
  // un branco alla volta (la leva del ponte sulla Terrazza si tira passandoci accanto), per ultimo il boss
  const leva = pianta.leve[0];
  const tappe = [...(leva ? [[leva.x, leva.z + 1.5]] : []), ...pianta.packs.map(b => [b.x, b.z - 1]), [pianta.boss.x, pianta.boss.z - 3]];
  for (let giro = 0; giro < 3; giro++) {
    for (const [lx, lz] of tappe) {
      await A.cmd(`/tp ${ox + lx} ${oz + lz}`);
      await attesa(400);
      for (let k = 0; k < 8; k++) {
        const m = A.vicino(e => e.k === 'm' && e.hp > 0 && !e.dead && Math.hypot(e.x - A.x, e.z - A.z) < 16);
        if (!m) break;
        await A.cmd(`/tp ${m.x} ${m.z + 1.2}`);
        await A.cmd('/uccidi');
        await attesa(150);
      }
    }
    if (A.trova(m => m.t === 'dg_reward')) break;
  }
  const premi = await tFine.catch(() => null);
  const dgFine = A.log.filter(m => m.t === 'dg' && m.done).pop();
  verifica(premi && dgFine && dgFine.result, `Forgia completata: sigillo +${dgFine && dgFine.result.oldKl} → +${dgFine && dgFine.result.newKl}; premi: ${premi && premi.got.join(', ')}`);
  const imp2 = await tImp2.catch(() => null);
  verifica(imp2 && imp2.ti === TITOLI.cuore_brace.nome, `impresa della Forgia: ${imp2 && imp2.n} → «${imp2 && imp2.ti}»`);
  A.manda({ t: 'tleave' });
  await A.aspetta(m => m.t === 'dg_end', 6000).catch(() => {});

  // ------------------------------------------------ Arena: punti stagionali, onore, negozio, chiusura
  await A.cmd('/level 40');
  await B.cmd('/level 40');
  await A.cmd('/tp arena');
  await B.cmd('/tp arena');
  await attesa(600);
  await B.cammina(8000 + (B.x - 8000) * 0.5, B.z * 0.5);
  await A.cmd(`/tp ${B.x + 1.5} ${B.z}`);
  await attesa(300);
  let caduta = null;
  const tCad = B.aspetta(m => m.t === 'dead', 30000).then(m => { caduta = m; }).catch(() => {});
  const tPunti = A.aspetta(m => m.t === 'sys' && /punti stagionali/.test(m.m), 30000);
  for (let i = 0; i < 250 && !caduta; i++) { A.manda({ t: 'atk', id: B.id }); await attesa(100); }
  await tCad;
  const pt = await tPunti;
  verifica(caduta && /\+10 punti/.test(pt.m), `uccisione nell'arena: «${pt.m}»`);
  await attesa(6000);   // rinascita automatica
  const ar = A.vicino(e => e.k === 'n' && e.role === 'araldo');
  await A.cmd(`/tp ${ar.x} ${ar.z + 1.5}`);
  await attesa(300);
  A.manda({ t: 'npc', id: ar.id });
  const on = await A.aspetta(m => m.t === 'onori');
  verifica(on.onore === 10 && on.cl[0].n === 'Provalama' && on.cl[0].p === 10 && on.io.pos === 1 && on.fine > 0, `Araldo: onore ${on.onore}, classifica ${on.cl.map(v => `${v.n} ${v.p}`).join(', ')}, fine stagione fra ${Math.round(on.fine / 3600000)} h`);
  await A.cmd('/onore 300');
  const iT = on.negozio.findIndex(v => v.titolo === 'sfidante');
  A.manda({ t: 'alto', a: 'compra', npc: ar.id, i: iT });
  const on2 = await A.aspetta(m => m.t === 'onori');
  verifica(on2.onore === 10 && on2.negozio[iT].ha === 1, `titolo comprato con l'onore: «${TITOLI.sfidante.nome}», onore rimasto ${on2.onore}`);
  const iE = on.negozio.findIndex(v => v.id === 'essenza_celeste');
  const ess0 = A.quanti('essenza_celeste');
  A.manda({ t: 'alto', a: 'compra', npc: ar.id, i: iE });
  const e2 = await A.aspetta(m => m.t === 'err', 3000).catch(() => null);
  verifica(e2 && /onore/.test(e2.m) && A.quanti('essenza_celeste') === ess0, `onore insufficiente: «${e2 && e2.m}»`);
  const tChiusa = B.aspetta(m => m.t === 'notice' && /Stagione dell'Arena chiusa/.test(m.m), 6000);
  await A.cmd('/stagione chiudi');
  const ch = await tChiusa;
  await A.cmd('/save');
  await attesa(400);
  const salvato = JSON.parse(fs.readFileSync(DBF, 'utf8'));
  const pA = Object.values(salvato.chars).find(c => c.name === 'Provalama');
  verifica(/Provalama \(10\)/.test(ch.m) && salvato.arena.campioni[0] === 'Provalama' && salvato.arena.storico.length === 1 && pA.onore === 10 + 600, `chiusura della stagione: «${ch.m}»; nel database campione ${salvato.arena.campioni[0]}, onore ${pA.onore}`);
  A.manda({ t: 'alto', a: 'imprese' });
  const ia = await A.aspetta(m => m.t === 'imprese');
  verifica(ia.titoli.includes('campione_loto') && ia.titoli.includes('sfidante') && ia.titoli.includes('cuore_brace'), `titoli di Provalama: ${ia.titoli.map(t => TITOLI[t].nome).join(', ')}`);
  A.chiudi(); B.chiudi();
}

try { await main(); } catch (e) { console.error('ERRORE', e); esiti.push([false, String(e)]); }
srv.kill('SIGTERM');
await attesa(500);
const ko = esiti.filter(e => !e[0]).length;
console.log(`\n${esiti.length - ko}/${esiti.length} verifiche riuscite`);
process.exit(ko ? 1 : 0);
