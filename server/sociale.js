// Comodità sociali: scambio fra giocatori, deposito condiviso dell'account, amici e sussurri, ordinamento
// dell'inventario, vendita rapida e collegamenti agli oggetti in chat. Logica del server, aggiunta come metodi a World
// (vedi installaSociale in fondo a server/world.js). Dati condivisi in shared/sociale.js, finestre in godot/script/sociale.gd.
//
// SCAMBIO — come si evita di duplicare gli oggetti: un oggetto offerto LASCIA l'inventario (va nel «pegno» del personaggio,
// ch.escrow = { o: [{ it, slot }], tael }) e vi torna solo se lo scambio si annulla; lo scambio riuscito sposta i pegni
// da un personaggio all'altro in un'unica funzione sincrona dopo aver controllato lo spazio di entrambi. In ogni istante
// un oggetto sta in un solo posto, quindi spostarlo, usarlo, venderlo o buttarlo a scambio aperto non ha effetto
// (la casella è vuota). Il pegno è salvato col personaggio: se il server si ferma a metà, al login torna nella borsa.
// La conferma vale per una precisa versione dell'offerta (`v`): ogni modifica la azzera per tutti e due.
//
// DEPOSITO: acc.deposito = DEPOSITO_SIZE caselle per account (condiviso fra i personaggi; un account ha una sola
// sessione alla volta, quindi niente accessi in parallelo). AMICI: acc.amici = [nomi di personaggi].
import { ITEMS, INV_SIZE, STACK_MAX, equipSlotOf } from '../shared/data.js';
import { zoneAt } from '../shared/world.js';
import { DEPOSITO_SIZE, SCAMBIO_CASELLE, SCAMBIO_RAGGIO, SCAMBIO_RAGGIO_MAX, AMICI_MAX } from '../shared/sociale.js';

const NOW = () => Date.now();
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const clona = (o) => JSON.parse(JSON.stringify(o));
const intero = (v) => (Number.isSafeInteger(v) ? v : NaN);
const INVITO_MS = 30000;
const TIPI_ORDINE = ['weapon', 'body', 'head', 'feet', 'potion', 'scroll', 'book', 'gem', 'mod', 'seal', 'material', 'key'];

const impilabile = (id) => !!(ITEMS[id] && ITEMS[id].stack);
const valida = (s) => !!(s && ITEMS[s.id] && Number.isInteger(s.n) && s.n > 0);

// ------------------------------------------------------------------ liste di caselle (inventario e deposito)
// Entrano tutti gli oggetti dell'elenco `voci` nella lista (simulazione, non tocca nulla)?
export function entrano(lista, voci) {
  const spazio = new Map();
  let liberi = 0;
  for (const s of lista) {
    if (!s) liberi++;
    else if (impilabile(s.id)) spazio.set(s.id, (spazio.get(s.id) || 0) + STACK_MAX - s.n);
  }
  for (const v of voci) {
    if (!impilabile(v.id)) { if (liberi <= 0) return false; liberi--; continue; }
    let n = v.n;
    const r = spazio.get(v.id) || 0, k = Math.min(n, r);
    spazio.set(v.id, r - k); n -= k;
    while (n > 0) {
      if (liberi <= 0) return false;
      liberi--;
      const k2 = Math.min(n, STACK_MAX);
      spazio.set(v.id, (spazio.get(v.id) || 0) + STACK_MAX - k2);
      n -= k2;
    }
  }
  return true;
}

// Mette l'oggetto nella lista (dopo aver verificato con `entrano`). `pref`: casella preferita se libera o con la stessa pila.
export function inserisci(lista, voce, pref = -1) {
  if (!impilabile(voce.id)) {
    const i = pref >= 0 && pref < lista.length && !lista[pref] ? pref : lista.findIndex((x) => !x);
    lista[i] = voce;
    return;
  }
  let n = voce.n;
  const ordine = [];
  if (pref >= 0 && pref < lista.length && lista[pref] && lista[pref].id === voce.id) ordine.push(pref);
  for (let i = 0; i < lista.length; i++) if (lista[i] && lista[i].id === voce.id && !ordine.includes(i)) ordine.push(i);
  for (const i of ordine) {
    if (n <= 0) break;
    const k = Math.min(n, STACK_MAX - lista[i].n);
    lista[i].n += k; n -= k;
  }
  while (n > 0) {
    const i = pref >= 0 && pref < lista.length && !lista[pref] ? pref : lista.findIndex((x) => !x);
    const k = Math.min(n, STACK_MAX);
    lista[i] = { id: voce.id, n: k, up: voce.up || 0 };
    n -= k;
  }
}

// Sposta n pezzi dalla casella `i` di `da` a `a`; `pref` = casella di destinazione scelta (trascinamento).
// Una sola funzione sincrona: o va tutto o non cambia nulla. Restituisce null se ok, altrimenti il motivo.
export function sposta(da, i, a, n, pref = -1) {
  const s = da[i];
  if (!valida(s)) return 'Non c\'è niente da spostare';
  if (ITEMS[s.id].type === 'key') return 'Il Sigillo della Prova non si può spostare';
  n = impilabile(s.id) ? Math.min(Math.max(1, intero(n) || s.n), s.n) : 1;
  const parte = n === s.n ? s : { ...clona(s), n };
  if (da === a && pref === i) return null;
  if (pref >= 0 && pref < a.length && a[pref]) {
    const b = a[pref];
    const fonde = impilabile(b.id) && b.id === s.id;
    if (!fonde && n === s.n && valida(b) && ITEMS[b.id].type !== 'key') {   // scambio di posto fra due caselle occupate
      da[i] = b; a[pref] = s;
      return null;
    }
  }
  // si toglie prima dalla lista d'origine (anche se è la stessa), poi si controlla lo spazio; se non basta si ripristina
  if (n === s.n) da[i] = null; else s.n -= n;
  if (!entrano(a, [parte])) {
    if (n === s.n) da[i] = s; else s.n += n;
    return 'Non c\'è abbastanza spazio';
  }
  inserisci(a, parte, pref);
  return null;
}

// ------------------------------------------------------------------ metodi di World
const metodi = {
  // ------------------------------------------------------------ messaggi dal client
  sociale(p, msg) {
    switch (msg.t) {
      case 'scambio': return this.onScambio(p, msg);
      case 'dep': return this.onDeposito(p, msg);
      case 'amico': return this.onAmico(p, msg);
      case 'amici': return this.mandaAmici(p);
      case 'ordina': return this.ordinaInventario(p);
      case 'vendi_comuni': return this.vendiComuni(p, msg.npc);
    }
  },

  // Al login (fine di addPlayer): pegno di uno scambio interrotto, amici.
  socialeEntra(p) {
    const ch = p.ch;
    if (ch.escrow) this.restituisciPegno(p, 'Lo scambio interrotto è stato annullato: i tuoi oggetti sono tornati nella borsa.');
    const acc = this.accountDi(p);
    if (acc && !Array.isArray(acc.amici)) acc.amici = [];
    this.mandaAmici(p);
    this.avvisaAmici(p, true);
  },

  // All'uscita (inizio di removePlayer, prima del salvataggio).
  socialeEsci(p) {
    if (p.scambio) this.scambioChiudi(p.scambio, `${p.name} ha lasciato il mondo.`);
    p.ch.visto = NOW();
    this.avvisaAmici(p, false);
  },

  accountDi(p) { return p.sess && p.sess.user ? this.db.account(p.sess.user) : null; },

  salvaPresto() {
    if (this._salvaTimer) return;
    this._salvaTimer = setTimeout(() => { this._salvaTimer = null; try { this.db.save(); } catch (e) { console.error('Salvataggio:', e); } }, 400);
  },

  // ============================================================ SCAMBIO
  onScambio(p, m) {
    switch (m.a) {
      case 'chiedi': return this.scambioChiedi(p, m.id ? this.ents.get(m.id | 0) : this.playerByName(m.n));
      case 'rispondi': return this.scambioRispondi(p, !!m.ok);
      case 'offri': return this.scambioOffri(p, m.i, m.n);
      case 'togli': return this.scambioTogli(p, m.k);
      case 'tael': return this.scambioTael(p, m.n);
      case 'conferma': return this.scambioConferma(p, m.v);
      case 'annulla': return p.scambio ? this.scambioChiudi(p.scambio, `${p.name} ha annullato lo scambio.`) : undefined;
    }
  },

  scambioImpossibile(p) {
    if (p.dead) return 'Non puoi scambiare da morto';
    if (p.scambio) return 'Hai già uno scambio aperto';
    if (p.inst) return 'Non si scambia dentro una Prova';
    if (this.inArena(p)) return 'Non si scambia nell\'Arena';
    return null;
  },

  scambioChiedi(p, q) {
    if (!q || q.kind !== 'player' || !q.online) return this.err(p, 'Giocatore non trovato');
    if (q === p) return;
    let e = this.scambioImpossibile(p);
    if (e) return this.err(p, e);
    e = this.scambioImpossibile(q);
    if (e) return this.err(p, q.scambio ? `${q.name} sta già scambiando con qualcuno` : `${q.name}: ${e.toLowerCase()}`);
    if (dist(p, q) > SCAMBIO_RAGGIO) return this.err(p, `${q.name} è troppo lontano per scambiare`);
    if (q.scambioInvito && q.scambioInvito.da !== p.id && NOW() - q.scambioInvito.at < INVITO_MS) return this.err(p, `${q.name} ha già una richiesta in sospeso`);
    q.scambioInvito = { da: p.id, at: NOW() };
    this.send(q, { t: 'scambio', a: 'richiesta', id: p.id, n: p.name });
    this.sys(p, `Richiesta di scambio inviata a ${q.name}.`);
  },

  scambioRispondi(q, ok) {
    const inv = q.scambioInvito;
    q.scambioInvito = null;
    if (!inv || NOW() - inv.at > INVITO_MS) return;
    const p = this.ents.get(inv.da);
    if (!p || p.kind !== 'player' || !p.online) return this.err(q, 'La richiesta non è più valida');
    if (!ok) return this.sys(p, `${q.name} ha rifiutato lo scambio.`);
    let e = this.scambioImpossibile(p) || this.scambioImpossibile(q);
    if (e) return this.err(q, e);
    if (dist(p, q) > SCAMBIO_RAGGIO) return this.err(q, 'Siete troppo lontani per scambiare');
    this.scambioApri(p, q);
  },

  scambioApri(a, b) {
    const sc = { g: [a, b], v: 1, ok: [false, false], inizio: NOW() };
    for (const x of sc.g) {
      if (x.ch.escrow) this.restituisciPegno(x);   // pegno rimasto da un'interruzione
      x.ch.escrow = { o: [], tael: 0 };
      x.scambio = sc;
    }
    this.scambi.add(sc);
    this.scambioStato(sc);
  },

  pegno(p) { return p.ch.escrow || (p.ch.escrow = { o: [], tael: 0 }); },

  // Ogni modifica all'offerta cambia versione e azzera le conferme.
  scambioModifica(sc) { sc.v++; sc.ok = [false, false]; this.scambioStato(sc); },

  scambioStato(sc) {
    for (let k = 0; k < 2; k++) {
      const me = sc.g[k], lui = sc.g[1 - k];
      this.send(me, {
        t: 'scambio', a: 'stato', v: sc.v, con: lui.name, conId: lui.id,
        mio: { o: this.pegno(me).o.map((x) => x.it), tael: this.pegno(me).tael, ok: sc.ok[k] ? 1 : 0 },
        suo: { o: this.pegno(lui).o.map((x) => x.it), tael: this.pegno(lui).tael, ok: sc.ok[1 - k] ? 1 : 0 },
      });
    }
  },

  scambioOffri(p, i, n) {
    const sc = p.scambio;
    if (!sc) return;
    const pg = this.pegno(p);
    i = intero(i);
    if (!(i >= 0 && i < INV_SIZE)) return;
    const s = p.ch.inv[i];
    if (!valida(s)) return this.err(p, 'Casella vuota');
    if (ITEMS[s.id].type === 'key') return this.err(p, 'Il Sigillo della Prova non si può scambiare');
    if (pg.o.length >= SCAMBIO_CASELLE) return this.err(p, `Puoi offrire al massimo ${SCAMBIO_CASELLE} oggetti`);
    n = impilabile(s.id) ? Math.min(Math.max(1, intero(n) || s.n), s.n) : 1;
    let it;
    if (n === s.n) { it = s; p.ch.inv[i] = null; }
    else { it = { ...clona(s), n }; s.n -= n; }
    pg.o.push({ it, slot: i });
    p.invDirty = true;
    this.scambioModifica(sc);
  },

  scambioTogli(p, k) {
    const sc = p.scambio;
    if (!sc) return;
    const pg = this.pegno(p);
    k = intero(k);
    if (!(k >= 0 && k < pg.o.length)) return;
    const [v] = pg.o.splice(k, 1);
    this.rimettiInBorsa(p, v);
    this.scambioModifica(sc);
  },

  scambioTael(p, n) {
    const sc = p.scambio;
    if (!sc) return;
    const pg = this.pegno(p);
    n = intero(n);
    if (!(n >= 0)) return;
    if (n > p.ch.tael + pg.tael) return this.err(p, 'Tael insufficienti');
    p.ch.tael += pg.tael - n;
    pg.tael = n;
    p.selfDirty = true;
    this.scambioModifica(sc);
  },

  scambioConferma(p, v) {
    const sc = p.scambio;
    if (!sc) return;
    if (v !== sc.v) return this.scambioStato(sc);   // conferma di un'offerta ormai cambiata: ignorata
    const k = sc.g[0] === p ? 0 : 1;
    sc.ok[k] = true;
    if (sc.ok[0] && sc.ok[1]) return this.scambioEsegui(sc);
    this.scambioStato(sc);
  },

  // L'unico punto in cui gli oggetti cambiano proprietario. Sincrono: nessun altro messaggio può inserirsi.
  scambioEsegui(sc) {
    const [a, b] = sc.g;
    const pa = this.pegno(a), pb = this.pegno(b);
    if (!sc.ok[0] || !sc.ok[1]) return;
    const daA = pa.o.map((x) => x.it), daB = pb.o.map((x) => x.it);
    for (const [q, voci] of [[a, daB], [b, daA]]) {
      if (!entrano(q.ch.inv, voci)) {
        sc.ok = [false, false]; sc.v++;
        this.sys(a, `${q.name} non ha abbastanza spazio nella borsa: liberate delle caselle.`);
        this.sys(b, `${q.name} non ha abbastanza spazio nella borsa: liberate delle caselle.`);
        return this.scambioStato(sc);
      }
    }
    for (const it of daB) inserisci(a.ch.inv, it);
    for (const it of daA) inserisci(b.ch.inv, it);
    a.ch.tael += pb.tael; b.ch.tael += pa.tael;
    a.ch.escrow = null; b.ch.escrow = null;
    a.scambio = b.scambio = null;
    this.scambi.delete(sc);
    for (const x of [a, b]) { x.invDirty = true; x.selfDirty = true; this.send(x, { t: 'scambio', a: 'fine', ok: 1 }); }
    this.sys(a, `Scambio con ${b.name} concluso.`);
    this.sys(b, `Scambio con ${a.name} concluso.`);
    this.salvaPresto();
  },

  // Annulla e restituisce i pegni.
  scambioChiudi(sc, motivo) {
    if (!this.scambi.has(sc)) return;
    this.scambi.delete(sc);
    for (const x of sc.g) {
      x.scambio = null;
      this.restituisciPegno(x);
      if (x.online) { this.send(x, { t: 'scambio', a: 'fine', ok: 0, m: motivo || '' }); if (motivo) this.sys(x, `Scambio annullato. ${motivo}`); }
    }
  },

  // Un oggetto del pegno torna nella borsa (casella d'origine se libera); se non c'è posto cade a terra, solo per lui.
  rimettiInBorsa(p, v) {
    const inv = p.ch.inv;
    if (entrano(inv, [v.it])) inserisci(inv, v.it, v.slot);
    else {
      this.add({ kind: 'drop', item: v.it, x: p.x, z: p.z, owner: p.id, ownerUntil: NOW() + 180000, expire: NOW() + 240000 });
      this.sys(p, 'Borsa piena: un oggetto è stato lasciato a terra accanto a te.');
    }
    p.invDirty = true;
  },

  restituisciPegno(p, avviso) {
    const pg = p.ch.escrow;
    if (!pg) return;
    p.ch.escrow = null;
    for (const v of pg.o) this.rimettiInBorsa(p, v);
    if (pg.tael > 0) { p.ch.tael += pg.tael; p.selfDirty = true; }
    p.invDirty = true;
    if (avviso && p.online) this.sys(p, avviso);
  },

  tickSociale(t) {
    for (const sc of [...this.scambi]) {
      const [a, b] = sc.g;
      let m = null;
      if (!a.online || !b.online) m = 'Un giocatore non è più presente.';
      else if (a.dead || b.dead) m = 'Uno dei due è caduto in battaglia.';
      else if (a.inst || b.inst || this.inArena(a) || this.inArena(b)) m = 'Uno dei due ha lasciato la zona.';
      else if (dist(a, b) > SCAMBIO_RAGGIO_MAX) m = 'Vi siete allontanati troppo.';
      if (m) this.scambioChiudi(sc, m);
    }
  },

  // ============================================================ DEPOSITO
  deposito(p) {
    const acc = this.accountDi(p);
    if (!acc) return null;
    if (!Array.isArray(acc.deposito)) acc.deposito = [];
    while (acc.deposito.length < DEPOSITO_SIZE) acc.deposito.push(null);
    if (acc.deposito.length > DEPOSITO_SIZE) acc.deposito.length = DEPOSITO_SIZE;
    return acc.deposito;
  },

  mandaDeposito(p, npc) {
    const dep = this.deposito(p);
    if (dep) this.send(p, { t: 'dep', a: 'stato', npc, slots: dep });
  },

  apriDeposito(p, npc) { this.mandaDeposito(p, npc.id); },

  onDeposito(p, m) {
    if (p.dead) return;
    const npc = this.nearNpc(p, m.npc | 0, ['magazziniere']);
    if (!npc) return this.err(p, 'Sei troppo lontano dal magazziniere');
    const dep = this.deposito(p);
    if (!dep) return;
    const inv = p.ch.inv;
    const i = intero(m.i), s = intero(m.s);
    const pref = Number.isInteger(s) && s >= 0 && s < DEPOSITO_SIZE ? s : -1;
    let e = null;
    switch (m.a) {
      case 'metti':
        if (!(i >= 0 && i < INV_SIZE)) return;
        e = sposta(inv, i, dep, m.n, pref);
        if (!e) p.invDirty = true;
        break;
      case 'prendi':
        if (!(s >= 0 && s < DEPOSITO_SIZE)) return;
        e = sposta(dep, s, inv, m.n, i >= 0 && i < INV_SIZE ? i : -1);
        if (!e) p.invDirty = true;
        break;
      case 'sposta': {
        const a = intero(m.da), b = intero(m.a2);
        if (!(a >= 0 && a < DEPOSITO_SIZE && b >= 0 && b < DEPOSITO_SIZE)) return;
        e = sposta(dep, a, dep, m.n, b);
        break;
      }
      case 'ordina': this.ordinaLista(dep); break;
      case 'apri': break;
      default: return;
    }
    if (e) this.err(p, e);
    this.mandaDeposito(p, npc.id);
    this.salvaPresto();
  },

  // Raggruppa le pile uguali e ordina per tipo, nome e rarità.
  ordinaLista(lista) {
    const voci = lista.filter(valida);
    const strani = lista.filter((x) => x && !valida(x));
    const out = [];
    for (const v of voci) {
      if (impilabile(v.id)) {
        const g = out.find((x) => x.id === v.id && x.n < STACK_MAX);
        if (g) { const k = Math.min(v.n, STACK_MAX - g.n); g.n += k; if (v.n - k > 0) out.push({ ...v, n: v.n - k }); continue; }
      }
      out.push(v);
    }
    const chiave = (x) => {
      const t = TIPI_ORDINE.indexOf(ITEMS[x.id].type);
      return [t < 0 ? 99 : t, ITEMS[x.id].lvl || 0, ITEMS[x.id].name];
    };
    out.sort((x, y) => {
      const a = chiave(x), b = chiave(y);
      return a[0] - b[0] || b[1] - a[1] || String(a[2]).localeCompare(String(b[2]), 'it') || (y.r || 0) - (x.r || 0) || (y.up || 0) - (x.up || 0) || y.n - x.n;
    });
    out.push(...strani);
    for (let i = 0; i < lista.length; i++) lista[i] = out[i] || null;
  },

  ordinaInventario(p) {
    if (p.dead) return;
    this.ordinaLista(p.ch.inv);
    p.invDirty = true;
  },

  // Vende ai mercanti tutti gli oggetti comuni: equipaggiamento bianco senza potenziamenti né gemme e i trofei di caccia
  // («Si vende ai mercanti»). Il resto (materiali per il fabbro, pozioni, gemme, libri) non si tocca.
  vendiComuni(p, npcId) {
    const npc = this.nearNpc(p, npcId | 0, ['armi', 'erbe']);
    if (!npc || p.dead) return;
    let tot = 0, n = 0;
    p.ch.inv.forEach((s, i) => {
      if (!valida(s)) return;
      const it = ITEMS[s.id];
      const equip = equipSlotOf(it) && !(s.r > 0) && !(s.up > 0) && !(s.s || []).some(Boolean);
      const trofeo = it.type === 'material' && /Si vende ai mercanti/.test(it.desc || '');
      if (!equip && !trofeo) return;
      tot += Math.floor(it.price / 5 * (1 + (s.up || 0) * 0.5) * (1 + (s.r || 0) * 0.6)) * s.n;
      n += s.n;
      p.ch.inv[i] = null;
    });
    if (!n) return this.sys(p, 'Non hai oggetti comuni da vendere.');
    p.ch.tael += tot;
    p.invDirty = true; p.selfDirty = true;
    this.sys(p, `Venduti ${n} oggetti comuni per ${tot} tael.`);
  },

  // ============================================================ AMICI E SUSSURRI
  amiciDi(p) {
    const acc = this.accountDi(p);
    if (!acc) return [];
    if (!Array.isArray(acc.amici)) acc.amici = [];
    return acc.amici;
  },

  personaggioPerNome(nome) {
    const n = String(nome || '').toLowerCase();
    return Object.values(this.db.data.chars).find((c) => c.name.toLowerCase() === n) || null;
  },

  voceAmico(nome) {
    const q = this.playerByName(nome);
    if (q) {
      const z = q.inst ? 'Prova del Sigillo' : zoneAt(q.x, q.z).name;
      return { n: q.name, on: 1, lvl: q.lvl, cls: q.cls, kd: q.kingdom, z };
    }
    const c = this.personaggioPerNome(nome);
    return c ? { n: c.name, on: 0, lvl: c.lvl, cls: c.cls, kd: c.kingdom, v: c.visto || 0 } : { n: nome, on: 0, lvl: 0, cls: '', kd: '' };
  },

  mandaAmici(p) {
    if (!p || !p.online) return;
    this.send(p, { t: 'amici', max: AMICI_MAX, list: this.amiciDi(p).map((n) => this.voceAmico(n)) });
  },

  // Chi ha `p` fra gli amici: avviso di entrata e aggiornamento della lista.
  avvisaAmici(p, entra) {
    const mio = p.name.toLowerCase();
    for (const q of this.players) {
      if (q === p || !q.online) continue;
      if (!this.amiciDi(q).some((n) => n.toLowerCase() === mio)) continue;
      if (entra) this.send(q, { t: 'amico_on', n: p.name });
      if (entra) this.sys(q, `Il tuo amico ${p.name} è entrato nel mondo.`);
      this.mandaAmici(q);
    }
  },

  onAmico(p, m) {
    const lista = this.amiciDi(p);
    const c = this.personaggioPerNome(String(m.n || '').trim());
    switch (m.a) {
      case 'aggiungi': {
        if (!c) return this.err(p, 'Nessun personaggio con quel nome');
        if (c.name.toLowerCase() === p.name.toLowerCase()) return this.err(p, 'Sei già tuo amico');
        if (lista.some((n) => n.toLowerCase() === c.name.toLowerCase())) return this.err(p, `${c.name} è già fra i tuoi amici`);
        if (lista.length >= AMICI_MAX) return this.err(p, `Puoi avere al massimo ${AMICI_MAX} amici`);
        lista.push(c.name);
        this.sys(p, `${c.name} è stato aggiunto agli amici.`);
        break;
      }
      case 'rimuovi': {
        const k = lista.findIndex((n) => n.toLowerCase() === String(m.n || '').trim().toLowerCase());
        if (k < 0) return this.err(p, 'Non è fra i tuoi amici');
        this.sys(p, `${lista[k]} è stato tolto dagli amici.`);
        lista.splice(k, 1);
        break;
      }
      case 'lista': break;
      default: return;
    }
    this.mandaAmici(p);
    this.salvaPresto();
  },

  sussurra(p, nome, testo) {
    testo = String(testo || '').trim();
    if (!nome || !testo) return this.sys(p, 'Uso: /s nome testo');
    const q = this.playerByName(nome);
    if (!q) return this.sys(p, `${nome} non è in linea.`);
    this.send(q, { t: 'chat', ch: 'wh', n: p.name, m: testo });
    this.send(p, { t: 'chat', ch: 'wh', n: p.name, to: q.name, m: testo });
    q.ultimoSussurro = p.name;
    p.ultimoSussurro = q.name;
  },

  // Comandi di chat: /s nome testo, /r testo, /amico nome, /amici, /scambia nome. true se il comando era uno dei nostri.
  comandoSociale(p, c, a) {
    switch (c) {
      case 's': case 'w': case 'sussurra': this.sussurra(p, a[0], a.slice(1).join(' ')); return true;
      case 'r': case 'rispondi':
        if (!p.ultimoSussurro) this.sys(p, 'Nessuno a cui rispondere.');
        else this.sussurra(p, p.ultimoSussurro, a.join(' '));
        return true;
      case 'amico': this.onAmico(p, { a: 'aggiungi', n: a[0] }); return true;
      case 'amici': {
        const l = this.amiciDi(p).map((n) => this.voceAmico(n));
        this.sys(p, l.length ? 'Amici: ' + l.map((x) => `${x.n} (${x.on ? 'in linea, livello ' + x.lvl + ', ' + x.z : 'fuori linea'})`).join('; ') : 'Non hai ancora amici: /amico nome');
        return true;
      }
      case 'scambia': this.scambioChiedi(p, this.playerByName(a[0])); return true;
    }
    return false;
  },

  // Collegamenti agli oggetti in chat: «[[3]]» (casella dell'inventario) diventa «⟦oggetto⟧», con l'oggetto intero
  // (id, potenziamento, rarità, bonus, incavi) in JSON codificato: il client lo mostra come «[Nome]» con la descrizione al
  // passaggio del mouse. Al massimo 3 per messaggio; una casella vuota non produce nulla.
  collegaOggetti(p, testo) {
    if (!/\[\[\d{1,2}\]\]/.test(testo)) return testo;
    let n = 0;
    return testo.replace(/\[\[(\d{1,2})\]\]/g, (_, i) => {
      const s = p.ch.inv[+i];
      if (!valida(s) || n >= 3) return '';
      n++;
      return `\u27e6${encodeURIComponent(JSON.stringify(s))}\u27e7`;
    });
  },
};

export function installaSociale(World) {
  Object.assign(World.prototype, metodi);
  Object.defineProperty(World.prototype, 'scambi', { get() { return this._scambi || (this._scambi = new Set()); } });
}
