// Interfaccia di gioco (DOM): finestre, inventario, abilità, barra rapida, negozi, chat, minimappa.
import {
  ITEMS, SKILLS, CLASSES, VIE, STAT_NAMES, STAT_DESC, EQUIP_SLOTS, EQUIP_NAMES, INV_SIZE, QB_SIZE, WEAPON_TYPES, UPGRADE,
  VIA_LEVEL, SKILL_MAX_POINTS, SKILL_MAX, BUFFS, RESOURCES, PTS_MAX, STATS_NAMES, skillVal, upgradedStat, equipSlotOf,
  RARITIES, BONUS_STATS, GEM_TYPES, bonusText, bonusStars, MOUNT_SKILLS, HORSE, DUNGEON, AFFIXES, activeAffixes, trialScale, SLANCIO, SUPREMA, supremaOf,
} from '/shared/data.js';
import { KINGDOMS, KINGDOM_IDS, WALL_RADIUS, CENTER, zoneAt } from '/shared/world.js';

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pct = (v) => `${Math.round(v * 100)}%`;

export function itemIconHtml(s, count) {
  const it = ITEMS[s.id];
  if (!it) return '';
  const r = s.r || 0;
  const styles = [];
  if (it.color) styles.push(`background:radial-gradient(${it.color},#120a07)`);
  if (r > 0) styles.push(`box-shadow:inset 0 0 0 2px ${RARITIES[r].color}, inset 0 0 10px ${RARITIES[r].color}88`);
  const st = styles.length ? ` style="${styles.join(';')}"` : '';
  const n = count ?? s.n;
  const sockets = (s.s && s.s.length) ? `<span class="sock">${s.s.map(g => `<i style="background:${g ? GEM_TYPES[ITEMS[g].gem].color : '#0008'}"></i>`).join('')}</span>` : '';
  const upv = s.up || s.kl;
  return `<div class="icon t${it.tier || 1}"${st}>${it.glyph}${n > 1 ? `<span class="cnt">${n}</span>` : ''}${upv ? `<span class="upl">+${upv}</span>` : ''}${sockets}</div>`;
}
function skillIconHtml(sid, disabled) {
  const sk = SKILLS[sid];
  return `<div class="icon skill${disabled ? ' disabled' : ''}" style="box-shadow:inset 0 0 0 2px #${sk.color.toString(16).padStart(6, '0')}88">${sk.glyph}</div>`;
}
function itemNameClass(s) { return 'r' + (s.r || 0); }
function rarityColor(s) { return RARITIES[s.r || 0].color; }

export class UI {
  constructor(game) {
    this.g = game;
    this.drag = null;
    this.shop = null; this.smith = null; this.smithSlot = -1;
    this.buffT = 0;
    this.noticeTimer = 0;
    this.setupWindows();
    this.buildStaticSlots();
    this.setupDrag();
    this.setupTooltips();
    $('btn-respawn-here').onclick = () => this.g.net.send({ t: 'respawn', mode: 'here' });
    $('btn-respawn-town').onclick = () => this.g.net.send({ t: 'respawn', mode: 'town' });
    $('dps-reset').onclick = () => { this.g.meter.reset(); this.renderDps(); };
  }

  // ------------------------------------------------------------ finestre
  setupWindows() {
    document.querySelectorAll('#game-ui .window').forEach(w => {
      const title = w.querySelector('.title');
      const close = w.querySelector('.close');
      if (close) close.onclick = () => this.close(w.id);
      if (!title) return;
      title.addEventListener('mousedown', (e) => {
        if (e.target.classList.contains('close')) return;
        const r = w.getBoundingClientRect();
        w.style.transform = 'none'; w.style.left = r.left + 'px'; w.style.top = r.top + 'px'; w.style.right = 'auto';
        const ox = e.clientX - r.left, oy = e.clientY - r.top;
        const mv = (ev) => { w.style.left = Math.max(0, Math.min(innerWidth - 60, ev.clientX - ox)) + 'px'; w.style.top = Math.max(0, Math.min(innerHeight - 30, ev.clientY - oy)) + 'px'; };
        const up = () => { removeEventListener('mousemove', mv); removeEventListener('mouseup', up); };
        addEventListener('mousemove', mv); addEventListener('mouseup', up);
        this.focusWin(w);
      });
      w.addEventListener('mousedown', () => this.focusWin(w));
    });
    document.querySelectorAll('#menu-buttons button[data-win]').forEach(b => { b.onclick = () => this.toggle(b.dataset.win); });
    document.getElementById('btn-mount').onclick = () => this.g.toggleMount();
  }
  focusWin(w) { this.z = (this.z || 10) + 1; w.style.zIndex = this.z; }
  isOpen(id) { return !$(id).classList.contains('hidden'); }
  open(id) { $(id).classList.remove('hidden'); this.focusWin($(id)); this.refreshWin(id); }
  close(id) {
    $(id).classList.add('hidden');
    if (id === 'win-shop') this.shop = null;
    if (id === 'win-smith') { this.smith = null; this.smithSlot = -1; }
    this.hideTip();
  }
  toggle(id) { this.isOpen(id) ? this.close(id) : this.open(id); }
  closeAll() {
    let any = false;
    document.querySelectorAll('#game-ui .window').forEach(w => { if (!w.classList.contains('hidden')) { any = true; this.close(w.id); } });
    return any;
  }
  refreshWin(id) {
    if (id === 'win-inventory') this.renderInventory();
    if (id === 'win-character') this.renderCharacter();
    if (id === 'win-skills') this.renderSkills();
    if (id === 'win-smith') this.renderSmith();
    if (id === 'win-dps') this.renderDps();
  }

  buildStaticSlots() {
    const eqEl = $('equip-slots');
    eqEl.innerHTML = EQUIP_SLOTS.map(s => `<div class="eqw"><div class="slot" data-drop="eq" data-slot="${s}"></div>${EQUIP_NAMES[s]}</div>`).join('');
    const invEl = $('inv-slots');
    invEl.innerHTML = Array.from({ length: INV_SIZE }, (_, i) => `<div class="slot" data-drop="inv" data-i="${i}"></div>`).join('');
    const qb = $('quickbar');
    qb.innerHTML = Array.from({ length: QB_SIZE }, (_, i) => `<div class="slot qb" data-drop="qb" data-i="${i}"><span class="key">${(i + 1) % 10}</span><div class="qc"></div><div class="cool"></div></div>`).join('');
    // clic destro sull'inventario: usa / vendi / metti nel fabbro
    invEl.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const sl = e.target.closest('[data-drop="inv"]');
      if (!sl) return;
      const i = +sl.dataset.i;
      if (!this.g.inv || !this.g.inv[i]) return;
      const it = ITEMS[this.g.inv[i].id];
      if (this.shop) this.g.net.send({ t: 'sell', npc: this.shop.npc, i });
      else if (this.smith && equipSlotOf(it)) this.setSmithSlot(i);
      else if (it.type === 'gem') {
        if (it.grade < 2 && this.g.inv[i].n >= 3) {
          const next = ITEMS[`gemma_${it.gem}_${it.grade + 1}`];
          this.confirm(`Fondere 3 × ${esc(it.name)} in 1 × <b>${esc(next.name)}</b>?`, () => this.g.net.send({ t: 'combine', i }));
        } else this.notice(it.grade < 2 ? 'Servono 3 gemme uguali per fonderle. Trascina la gemma su un oggetto per incastonarla.' : 'Trascina la gemma su un oggetto con un incavo libero', true);
      }
      else if (it.type === 'mod') this.notice('Trascina il modificatore su un\'arma o un\'armatura', true);
      else this.g.net.send({ t: 'use', i });
    });
    eqEl.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const sl = e.target.closest('[data-drop="eq"]');
      if (!sl || !this.g.eq || !this.g.eq[sl.dataset.slot]) return;
      const free = this.g.inv.findIndex(x => !x);
      if (free >= 0) this.g.net.send({ t: 'mv', a: { k: 'e', i: sl.dataset.slot }, b: { k: 'i', i: free } });
    });
    qb.addEventListener('click', (e) => {
      const sl = e.target.closest('[data-drop="qb"]');
      if (sl && !this.dragMoved) this.g.useQuickbar(+sl.dataset.i);
    });
    qb.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  // ------------------------------------------------------------ trascinamento
  setupDrag() {
    const ghost = $('drag-ghost');
    document.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return;
      const slot = e.target.closest('[data-drop]');
      const skillEl = e.target.closest('[data-skill]');
      let src = null, html = '';
      if (skillEl) { src = { kind: 'skill', id: skillEl.dataset.skill }; html = skillIconHtml(src.id); }
      else if (slot) {
        const k = slot.dataset.drop;
        if (k === 'inv' && this.g.inv?.[+slot.dataset.i]) { src = { kind: 'inv', i: +slot.dataset.i }; html = itemIconHtml(this.g.inv[src.i]); }
        else if (k === 'eq' && this.g.eq?.[slot.dataset.slot]) { src = { kind: 'eq', slot: slot.dataset.slot }; html = itemIconHtml(this.g.eq[src.slot]); }
        else if (k === 'qb' && !this.g.me?.mounted && this.g.me?.qb?.[+slot.dataset.i]) { src = { kind: 'qb', i: +slot.dataset.i }; html = slot.querySelector('.qc').innerHTML; }
      }
      if (!src) return;
      e.preventDefault();
      this.drag = { src, html, x0: e.clientX, y0: e.clientY, active: false };
      this.dragMoved = false;
    });
    document.addEventListener('mousemove', (e) => {
      const d = this.drag;
      if (!d) return;
      if (!d.active && Math.hypot(e.clientX - d.x0, e.clientY - d.y0) > 5) {
        d.active = true; this.dragMoved = true;
        ghost.innerHTML = d.html; ghost.classList.remove('hidden'); this.hideTip();
      }
      if (d.active) { ghost.style.left = (e.clientX - 20) + 'px'; ghost.style.top = (e.clientY - 20) + 'px'; }
    });
    document.addEventListener('mouseup', (e) => {
      const d = this.drag;
      this.drag = null;
      ghost.classList.add('hidden');
      if (!d || !d.active) return;
      setTimeout(() => { this.dragMoved = false; }, 0);
      const el = document.elementFromPoint(e.clientX, e.clientY);
      const tgt = el && el.closest('[data-drop]');
      const overUi = el && el.closest('.window, .hud-panel, #quickbar, #chat, #menu-buttons');
      this.handleDrop(d.src, tgt, !overUi && el && el.id === 'scene');
    });
  }

  handleDrop(src, tgt, onWorld) {
    const net = this.g.net;
    const k = tgt?.dataset.drop;
    if (src.kind === 'qb') {
      if (k === 'qb') {
        const j = +tgt.dataset.i, qb = this.g.me.qb;
        const a = qb[src.i], b = qb[j];
        net.send({ t: 'qb', i: j, v: a }); net.send({ t: 'qb', i: src.i, v: b ?? null });
      } else if (!k) net.send({ t: 'qb', i: src.i, v: null });
      return;
    }
    if (src.kind === 'skill') {
      if (k === 'qb') net.send({ t: 'qb', i: +tgt.dataset.i, v: { k: 's', id: src.id } });
      return;
    }
    if (src.kind === 'inv') {
      const s = this.g.inv[src.i];
      if (!s) return;
      const sit = ITEMS[s.id];
      if ((sit.type === 'mod' || sit.type === 'gem') && (k === 'inv' || k === 'eq')) {
        const target = k === 'inv' ? this.g.inv[+tgt.dataset.i] : this.g.eq[tgt.dataset.slot];
        if (target && equipSlotOf(ITEMS[target.id])) {
          const tk = k === 'inv' ? { k: 'i', i: +tgt.dataset.i } : { k: 'e', i: tgt.dataset.slot };
          const tname = `<b style="color:${rarityColor(target)}">${esc(ITEMS[target.id].name)}</b>`;
          const send = () => net.send({ t: 'apply', i: src.i, tgt: tk });
          if (sit.mod === 'reroll') this.confirm(`Rimescolare tutti i bonus di ${tname}? Quelli attuali andranno persi.`, send);
          else if (sit.mod === 'ascend') this.confirm(`Tentare l'ascensione di ${tname}? (35% di successo, il sigillo si consuma comunque)`, send);
          else send();
          return;
        }
      }
      if (k === 'inv') net.send({ t: 'mv', a: { k: 'i', i: src.i }, b: { k: 'i', i: +tgt.dataset.i } });
      else if (k === 'eq') net.send({ t: 'mv', a: { k: 'i', i: src.i }, b: { k: 'e', i: tgt.dataset.slot } });
      else if (k === 'qb') {
        const it = ITEMS[s.id];
        if (it.type === 'potion' || it.type === 'scroll' || equipSlotOf(it)) net.send({ t: 'qb', i: +tgt.dataset.i, v: { k: 'i', id: s.id } });
      } else if (k === 'shop' && this.shop) net.send({ t: 'sell', npc: this.shop.npc, i: src.i });
      else if (k === 'smith' && this.smith) this.setSmithSlot(src.i);
      else if (onWorld) {
        const it = ITEMS[s.id];
        this.confirm(`Gettare a terra ${esc(it.name)}${s.n > 1 ? ' x' + s.n : ''}${s.up ? ' +' + s.up : ''}?`, () => net.send({ t: 'drop', i: src.i }));
      }
      return;
    }
    if (src.kind === 'eq') {
      if (k === 'inv') net.send({ t: 'mv', a: { k: 'e', i: src.slot }, b: { k: 'i', i: +tgt.dataset.i } });
    }
  }

  confirm(html, yes) {
    $('confirm-text').innerHTML = html;
    $('confirm').classList.remove('hidden');
    this.focusWin($('confirm'));
    $('confirm-yes').onclick = () => { $('confirm').classList.add('hidden'); yes(); };
    $('confirm-no').onclick = () => $('confirm').classList.add('hidden');
  }

  // ------------------------------------------------------------ suggerimenti
  setupTooltips() {
    const tip = $('tooltip');
    document.addEventListener('mousemove', (e) => {
      if (this.drag?.active) return;
      const el = e.target.closest?.('[data-drop], [data-skill], [data-skill-info], [data-shop-item], .buff');
      if (!el) { this.hideTip(); return; }
      const html = this.tipFor(el);
      if (!html) { this.hideTip(); return; }
      if (tip.dataset.key !== html) { tip.innerHTML = html; tip.dataset.key = html; }
      tip.classList.remove('hidden');
      const r = tip.getBoundingClientRect();
      let x = e.clientX + 16, y = e.clientY + 16;
      if (x + r.width > innerWidth - 6) x = e.clientX - r.width - 12;
      if (y + r.height > innerHeight - 6) y = innerHeight - r.height - 6;
      tip.style.left = x + 'px'; tip.style.top = y + 'px';
    });
  }
  hideTip() { const t = $('tooltip'); t.classList.add('hidden'); t.dataset.key = ''; }

  tipFor(el) {
    if (el.dataset.skill) return this.skillTip(el.dataset.skill);
    if (el.dataset.skillInfo) return this.skillTip(el.dataset.skillInfo);
    if (el.dataset.shopItem) return this.itemTip({ id: el.dataset.shopItem, n: 1, up: 0 }, true);
    if (el.classList.contains('buff')) return el.dataset.tip;
    const k = el.dataset.drop;
    if (k === 'inv' && this.g.inv?.[+el.dataset.i]) return this.itemTip(this.g.inv[+el.dataset.i]);
    if (k === 'eq') { const s = this.g.eq?.[el.dataset.slot]; return s ? this.itemTip(s) : `<span class="tt">${EQUIP_NAMES[el.dataset.slot]}: vuoto</span>`; }
    if (k === 'qb') {
      const q = this.g.qbView()[+el.dataset.i];
      if (!q) return '<span class="tt">Trascina qui un\'abilità o un consumabile</span>';
      return q.k === 's' ? this.skillTip(q.id) : this.itemTip({ id: q.id, n: 1, up: 0 });
    }
    if (k === 'smith') return this.smithSlot >= 0 ? this.itemTip(this.g.inv[this.smithSlot]) : '<span class="tt">Trascina qui un\'arma o un\'armatura</span>';
    return null;
  }

  itemTip(s, buying) {
    const it = ITEMS[s.id];
    if (!it) return '';
    const me = this.g.me || {};
    const up = s.up || 0, r = s.r || 0;
    const R = RARITIES[r];
    const isEq = !!equipSlotOf(it);
    const L = [`<div class="tn" style="color:${R.color}">${esc(it.name)}${up ? ' +' + up : ''}</div>`];
    if (isEq) L.push(`<div class="tt" style="color:${R.color}">${R.name}</div>`);
    if (it.type === 'weapon') {
      const users = Object.values(CLASSES).filter(c => c.weapons.includes(it.wt)).map(c => c.name).join(', ');
      L.push(`<div class="tt">${WEAPON_TYPES[it.wt].name} — ${users}</div>`);
    } else if (isEq) L.push(`<div class="tt">${EQUIP_NAMES[it.type]} — tutte le classi</div>`);
    if (it.lvl) L.push(`<div class="${me.lvl >= it.lvl ? 'tt' : 'tr'}">Livello richiesto: ${it.lvl}</div>`);
    const rm = R.mult;
    if (it.atk) L.push(`<div>Attacco: <b>${Math.round(upgradedStat(it.atk, up, true) * rm)}</b></div>`);
    if (it.matk) L.push(`<div>Attacco magico: <b>${Math.round(upgradedStat(it.matk, up, true) * rm)}</b></div>`);
    if (it.def) L.push(`<div>Difesa: <b>${Math.round(upgradedStat(it.def, up, false) * rm)}</b></div>`);
    if (it.range) L.push(`<div>Gittata: ${it.range}</div>`);
    if (it.type === 'weapon') L.push(`<div class="tt">Velocità: ${WEAPON_TYPES[it.wt].aspd < 900 ? 'rapida' : WEAPON_TYPES[it.wt].aspd < 1200 ? 'normale' : 'lenta'}</div>`);
    if (it.speed) L.push(`<div class="tg">Velocità di movimento +${it.speed}%</div>`);
    if (isEq && s.b && s.b.length) {
      L.push('<div class="tsep"></div>');
      for (const [k, v] of s.b) {
        const st = bonusStars(k, v, it.tier || 1);
        L.push(`<div class="tb">${esc(bonusText(k, v))} <span class="stars s${st}">${'★'.repeat(st)}${'☆'.repeat(5 - st)}</span></div>`);
      }
    }
    if (isEq && s.s && s.s.length) {
      L.push('<div class="tsep"></div>');
      for (const g of s.s) {
        if (g) { const gi = ITEMS[g], gt = GEM_TYPES[gi.gem]; L.push(`<div><span style="color:${gt.color}">◆</span> ${esc(gi.name)}: ${esc(bonusText(gt.stat, gt.vals[gi.grade]))}</div>`); }
        else L.push('<div class="tt">◇ Incavo libero</div>');
      }
    }
    if (isEq && s.fs) L.push(`<div style="color:#9ad8ff">Perseveranza del fabbro: +${Math.min(UPGRADE.failBonusMax, s.fs * UPGRADE.failBonus)}%</div>`);
    if (it.type === 'key') {
      const kl = s.kl || DUNGEON.startKey, sc = trialScale(kl, 5);
      L[0] = `<div class="tn" style="color:#ffb060">${esc(it.name)} +${kl}</div>`;
      L.push(`<div>Nemici: vita ×${sc.hp.toFixed(2)} (gruppo di 5), danni ×${sc.dmg.toFixed(2)}</div>`);
      const af = activeAffixes(kl);
      L.push(`<div class="tt">Modificatori: ${af.length ? af.map(a => AFFIXES[a].name).join(', ') : 'nessuno (dal +3)'}</div>`);
    }
    if (it.desc) L.push(`<div class="td">${esc(it.desc)}</div>`);
    if (isEq && !buying) L.push('<div class="tt">Trascina qui una gemma o un modificatore per applicarlo.</div>');
    if (buying) L.push(`<div style="color:#ffe08a">Prezzo: ${it.price.toLocaleString('it-IT')} tael</div>`);
    else L.push(`<div class="tt">Valore: ${(Math.floor(it.price / 5 * (1 + up * 0.5) * (1 + r * 0.6)) * (s.n || 1)).toLocaleString('it-IT')} tael</div>`);
    return L.join('');
  }

  skillTip(sid) {
    const sk = SKILLS[sid];
    const me = this.g.me || {};
    const lvl = this.g.lvlOf(sid);
    const show = Math.max(1, lvl);
    const cls = CLASSES[sk.cls] || CLASSES[this.g.cls];
    const resName = RESOURCES[cls.res].name;
    const ptsName = cls.pts ? cls.pts.name : 'punti';
    const L = [`<div class="tn">${esc(sk.name)}</div>`];
    L.push(`<div class="tt">${sk.mount ? 'Tecnica a cavallo' : sk.via ? VIE[sk.via].name : 'Abilità di base'} — Livello ${lvl}/${SKILL_MAX}</div>`);
    if (sk.mount) L.push(`<div class="${me.horse && me.horse.lvl >= sk.hlvl ? 'tt' : 'tr'}">Richiede un destriero di livello ${sk.hlvl}; si usa solo in sella. Il livello segue quello del destriero.</div>`);
    else if (!lvl) L.push(`<div class="tr">Si sblocca al livello ${sk.lvl}${sk.via && me.via !== sk.via ? ` (${VIE[sk.via].name})` : ''}</div>`);
    const line = [];
    if (sk.cost) line.push(`Costo: ${sk.cost}${cls.res === 'mana' ? '% del Mana' : ' ' + resName}`);
    if (sk.gen) line.push(`<span class="tg">+${sk.gen} ${resName}</span>`);
    if (line.length) L.push(`<div>${line.join(' · ')}</div>`);
    L.push(`<div class="tt">${sk.cast ? `Lancio ${String(sk.cast).replace('.', ',')} s` : 'Istantaneo'}${sk.cd ? ` · Ricarica ${String(sk.cd).replace('.', ',')} s` : ''}${sk.offgcd ? ' · fuori dal GCD' : ''}</div>`);
    if (sk.pts) L.push(`<div class="tg">Genera ${sk.pts} ${ptsName}${sk.behind ? ` (+${sk.behind.pts} alle spalle)` : ''}</div>`);
    if (sk.spend && sk.type !== 'heal_aoe') L.push(`<div style="color:#ffc860">Consuma tutti i ${ptsName}${sk.minPts ? ` (minimo ${sk.minPts})` : ''}</div>`);
    if (sk.mult) L.push(`<div>Danno: <b>${pct(skillVal(sk.mult, show))}</b>${sk.spend ? ' per punto' : ''} ${sk.dmg === 'magic' ? "dell'attacco magico" : sk.dmg === 'hybrid' ? 'di attacco fisico e magico' : sk.dmg === 'best' ? "dell'attacco migliore (fisico o magico)" : "dell'attacco"}${sk.hits ? ` × ${sk.hits} colpi` : ''}</div>`);
    if (sk.splash) L.push(`<div class="tt">Colpisce anche i nemici entro ${sk.splash} m dal bersaglio</div>`);
    if (sk.dot) L.push(`<div>Nel tempo: ${pct(skillVal(sk.dot.mult, show))} ogni ${String(sk.dot.every).replace('.', ',')} s per ${sk.dot.durPerPt ? sk.dot.durPerPt + ' s per punto' : sk.dot.dur + ' s'}</div>`);
    if (sk.radius) L.push(`<div class="tt">Area: ${sk.radius} m</div>`);
    if (sk.range) L.push(`<div class="tt">Distanza: ${sk.range === 'weapon' ? "quella dell'arma" : sk.range + ' m'}</div>`);
    if (sk.stun) L.push(`<div>Stordimento: ${skillVal(sk.stun, show).toFixed(1)} s</div>`);
    if (sk.slow) L.push(`<div>Rallenta per ${sk.slow.dur} s</div>`);
    if (sk.execute) L.push(`<div style="color:#ffc860">Solo sotto il ${Math.round(sk.execute * 100)}% di vita del bersaglio</div>`);
    if (sk.ignoreDef) L.push(`<div>Ignora il ${sk.ignoreDef}% della difesa</div>`);
    const bf = BUFFS[sk.buff || sk.debuff];
    if (bf && bf.stats) for (const k in bf.stats) L.push(`<div class="tg">${STATS_NAMES[k]} ${skillVal(bf.stats[k], show) > 0 ? '+' : ''}${skillVal(bf.stats[k], show).toFixed(1)}%</div>`);
    if (bf && bf.vuln) L.push(`<div class="tg">Il bersaglio subisce +${skillVal(bf.vuln, show).toFixed(0)}% danni da te</div>`);
    if (bf && bf.dur && sk.type !== 'strike') L.push(`<div class="tt">Durata: ${bf.dur >= 60 ? bf.dur / 60 + ' min' : bf.dur + ' s'}</div>`);
    if (sk.heal) {
      const v = skillVal(sk.heal, show);
      if (sk.type === 'heal_target' || (sk.type === 'heal_aoe' && !sk.healPct)) L.push(`<div class="tg">Cura: ${pct(v)} dell'attacco magico + 40</div>`);
      else if (sk.type.startsWith('hot')) L.push(`<div class="tg">Cura: ${(v * 100).toFixed(1)}% della vita al secondo per ${sk.dur} s</div>`);
      else L.push(`<div class="tg">Cura: ${pct(v)} della vita massima</div>`);
    }
    if (sk.shield) L.push(`<div class="tg">Scudo: ${pct(skillVal(sk.shield, show))} dell'attacco magico</div>`);
    if (sk.req) L.push(`<div class="tt">Richiede: ${sk.req === 'bow' ? 'arco' : 'pugnali'}</div>`);
    L.push(`<div class="td">${esc(sk.desc)}</div>`);
    if (lvl >= SKILL_MAX_POINTS && lvl < SKILL_MAX) L.push('<div class="tt">Oltre il livello 10 serve un Tomo della Tecnica (50%).</div>');
    return L.join('');
  }

  // ------------------------------------------------------------ aggiornamenti dal server
  onMe() {
    const me = this.g.me;
    const c = CLASSES[this.g.cls], k = KINGDOMS[this.g.kd];
    $('pf-name').textContent = this.g.name;
    $('pf-sub').textContent = `Liv. ${me.lvl} ${c.name}${me.via ? ' · ' + VIE[me.via].name.replace(/^Via (della |delle |dello |degli |dei |del |dell')/, '') : ''} — ${k.short}`;
    const gl = $('pf-glyph'); gl.textContent = c.glyph; gl.style.borderColor = k.color; gl.style.color = k.color;
    this.onRes();
    const e = $('exp-bar');
    e.querySelector('.fill').style.width = Math.min(100, me.exp / me.need * 100) + '%';
    e.querySelector('span').textContent = `Esperienza ${(me.exp / me.need * 100).toFixed(1)}%  (${me.exp} / ${me.need})`;
    this.buffT = performance.now();
    this.renderBuffs();
    this.renderQuickbar();
    $('tael').textContent = me.tael.toLocaleString('it-IT');
    if (this.isOpen('win-character')) this.renderCharacter();
    if (this.isOpen('win-skills')) this.renderSkills();
    if (this.isOpen('win-smith')) this.renderSmith();
    this.renderStable();
    if (me.dead) this.showDeath(); else $('death-overlay').classList.add('hidden');
  }

  // Aggiornamento rapido di vita, risorsa e punti.
  onRes() {
    const me = this.g.me;
    const R = RESOURCES[me.rt];
    this.setBar('#player-frame .bar.hp', me.hp, me.mhp);
    const hpb = document.querySelector('#player-frame .bar.hp');
    let sh = hpb.querySelector('.shield');
    if (me.shield > 0) {
      if (!sh) { sh = document.createElement('div'); sh.className = 'shield'; hpb.insertBefore(sh, hpb.querySelector('span')); }
      const w = Math.min(100, me.shield / me.mhp * 100), left = Math.min(100, me.hp / me.mhp * 100);
      sh.style.left = Math.max(0, Math.min(left, 100 - w)) + '%'; sh.style.width = w + '%';
    } else if (sh) sh.remove();
    const mb = document.querySelector('#player-frame .bar.mp');
    mb.querySelector('.fill').style.background = `linear-gradient(${R.color}, #10101088)`;
    mb.querySelector('.fill').style.width = (me.rmax > 0 ? Math.max(0, Math.min(100, me.res / me.rmax * 100)) : 0) + '%';
    mb.querySelector('span').textContent = `${R.name} ${Math.floor(me.res)} / ${me.rmax}`;
    const c = CLASSES[this.g.cls];
    let html = '';
    const sl = me.sl || 0;
    html += `<div class="slancio${sl >= SLANCIO.max ? ' pieno' : ''}" title="Slancio: ogni colpo a segno aggiunge una tacca. Più tacche: più ${R.name} generata e colpi più rapidi. Cala se smetti di colpire."><span class="lbl">Slancio</span>`;
    for (let i = 0; i < SLANCIO.max; i++) html += `<i class="${i < sl ? 'on' : ''}"></i>`;
    html += '</div>';
    const sup = supremaOf(this.g.cls);
    if (sup && me.lvl >= sup.lvl) {
      const su = Math.min(SUPREMA.max, me.su || 0), pronta = su >= SUPREMA.max;
      html += `<div class="suprema${pronta ? ' pronta' : ''}" onclick="window.__game && window.__game.useSuprema()" title="${sup.name}: si carica spendendo ${R.name}. Quando è piena premi V.">`
        + `<span class="g">${sup.glyph}</span><div class="b"><div class="f" style="width:${Math.round(su / SUPREMA.max * 100)}%"></div></div><span class="k">${pronta ? 'V' : Math.round(su) + '%'}</span></div>`;
    }
    if (c.pts) {
      html += `<span class="lbl">${c.pts.name}</span>`;
      for (let i = 0; i < PTS_MAX; i++) html += `<div class="pip ${i < me.pts ? 'on' : ''}"></div>`;
    }
    const chain = this.g.chainList();
    if (chain) html += `<div class="chain">${chain.map((s, i) => `<span class="${i < (me.chain || 0) ? 'on' : ''}" title="${SKILLS[s].name}">${SKILLS[s].glyph}</span>`).join('')}</div>`;
    const row = $('pts-row');
    if (row.dataset.h !== html) { row.innerHTML = html; row.dataset.h = html; }
  }
  onInv() {
    this.renderQuickbar();
    if (this.isOpen('win-inventory')) this.renderInventory();
    if (this.smith && this.smithSlot >= 0 && !this.g.inv[this.smithSlot]) this.smithSlot = -1;
    if (this.isOpen('win-smith')) this.renderSmith();
  }

  setBar(sel, v, max) {
    const b = document.querySelector(sel);
    b.querySelector('.fill').style.width = (max > 0 ? Math.max(0, Math.min(100, v / max * 100)) : 0) + '%';
    b.querySelector('span').textContent = `${Math.max(0, Math.round(v))} / ${max}`;
  }

  renderBuffs() {
    const me = this.g.me;
    const el = $('buff-row');
    const el2 = (performance.now() - this.buffT);
    el.innerHTML = (me.buffs || []).filter(b => b.ms - el2 > 0 && BUFFS[b.b]).map(b => {
      const d = BUFFS[b.b];
      const sec = Math.ceil((b.ms - el2) / 1000);
      const tip = `<div class='tn'>${esc(d.name)}</div><div class='tt'>${sec > 90 ? Math.ceil(sec / 60) + ' min' : sec + ' s'} rimanenti</div><div class='td'>${esc(d.desc || '')}</div>`;
      return `<div class="buff ${d.proc ? 'proc' : ''}" data-tip="${tip}">${d.glyph}<small>${sec > 90 ? Math.ceil(sec / 60) + 'm' : sec}</small></div>`;
    }).join('');
  }

  renderInventory() {
    const inv = this.g.inv, eq = this.g.eq;
    if (!inv) return;
    document.querySelectorAll('#inv-slots .slot').forEach((el, i) => { el.innerHTML = inv[i] ? itemIconHtml(inv[i]) : ''; });
    document.querySelectorAll('#equip-slots .slot').forEach(el => { const s = eq[el.dataset.slot]; el.innerHTML = s ? itemIconHtml(s) : ''; });
    if (this.g.me) $('tael').textContent = this.g.me.tael.toLocaleString('it-IT');
  }

  renderQuickbar() {
    const me = this.g.me;
    if (!me) return;
    const view = this.g.qbView();
    document.querySelectorAll('#quickbar .slot').forEach((el, i) => {
      const q = view[i];
      const qc = el.querySelector('.qc');
      let html = '';
      if (q && q.k === 's' && SKILLS[q.id]) html = skillIconHtml(q.id, !this.g.lvlOf(q.id));
      else if (q && q.k === 'i' && ITEMS[q.id]) {
        const n = (this.g.inv || []).reduce((s, x) => s + (x && x.id === q.id ? x.n : 0), 0);
        html = itemIconHtml({ id: q.id, n, up: 0 }, n);
        if (!n) html = html.replace('class="icon', 'class="icon disabled');
      }
      if (qc.dataset.h !== html) { qc.innerHTML = html; qc.dataset.h = html; }
    });
  }

  updateCooldowns(now) {
    const me = this.g.me;
    if (!me) return;
    const g = this.g;
    const gcdRem = Math.max(0, g.gcdUntil - now);
    const view = g.qbView();
    document.querySelectorAll('#quickbar .slot').forEach((el, i) => {
      const q = view[i];
      const cool = el.querySelector('.cool');
      let html = '', state = '';
      if (q && q.k === 's' && SKILLS[q.id]) {
        const sk = SKILLS[q.id];
        const cd = g.cds[q.id];
        const cdRem = cd && cd.until > now ? cd.until - now : 0;
        if (cdRem > gcdRem || (sk.offgcd && cdRem > 0)) {
          const p = cdRem / cd.total;
          html = `<div style="position:absolute;inset:2px;background:conic-gradient(#000000b8 ${p * 360}deg, transparent 0)"></div><span>${cdRem > 1500 ? Math.ceil(cdRem / 1000) : (cdRem / 1000).toFixed(1)}</span>`;
        } else if (!sk.offgcd && gcdRem > 0 && g.gcdTotal > 0) {
          const p = Math.min(1, gcdRem / g.gcdTotal);
          html = `<div style="position:absolute;inset:2px;background:conic-gradient(#00000090 ${p * 360}deg, transparent 0)"></div>`;
        }
        state = g.skillState(q.id);
        if (g.queued === q.id) state += ' queued';
      }
      if (cool.dataset.h !== html) { cool.innerHTML = html; cool.dataset.h = html; }
      const cls = 'slot qb ' + state;
      if (el.className !== cls) el.className = cls;
    });
    if (now - (this.lastBuffRender || 0) > 500) { this.lastBuffRender = now; this.renderBuffs(); this.renderTargetDots(now); this.updateDungeonTimer(); }
    if (this.isOpen('win-dps') && now - (this.lastDps || 0) > 500) { this.lastDps = now; this.renderDps(); }
    const cb = $('cast-bar');
    if (g.casting && g.casting.until > now) {
      cb.classList.remove('hidden');
      const p = 1 - (g.casting.until - now) / g.casting.total;
      cb.querySelector('.fill').style.width = (p * 100).toFixed(1) + '%';
      cb.querySelector('span').textContent = `${g.casting.sid === '__mount' ? 'Richiamo del destriero' : SKILLS[g.casting.sid].name}  ${((g.casting.until - now) / 1000).toFixed(1)} s`;
    } else cb.classList.add('hidden');
  }

  renderTargetDots(now) {
    const el = $('tf-dots');
    const t = this.g.target;
    const list = t ? Object.entries(this.g.dots[t.id] || {}).filter(([, u]) => u > now) : [];
    const html = list.map(([s, u]) => {
      const d = SKILLS[s] || BUFFS[s];
      const sec = (u - now) / 1000;
      return `<div class="dt ${sec < 3 ? 'low' : ''}" title="${esc(d.name)}">${d.glyph}<small>${Math.ceil(sec)}</small></div>`;
    }).join('');
    if (el.dataset.h !== html) { el.innerHTML = html; el.dataset.h = html; }
  }

  renderDps() {
    const s = this.g.meter.seg;
    const el = $('dps-body');
    if (!s || !s.total) { el.innerHTML = '<div class="empty">Attacca un nemico o un fantoccio d\'addestramento:<br>qui vedrai i tuoi danni divisi per abilità.</div>'; return; }
    const dur = Math.max(1, (s.last - s.start) / 1000);
    const rows = Object.entries(s.by).sort((a, b) => b[1].v - a[1].v);
    const max = rows.length ? rows[0][1].v : 1;
    el.innerHTML = `<div class="head"><div>Durata<b>${dur.toFixed(0)} s</b></div><div>Danni<b>${s.total.toLocaleString('it-IT')}</b></div><div>DPS<b>${Math.round(s.total / dur).toLocaleString('it-IT')}</b></div></div>` +
      rows.map(([k, a]) => {
        const name = k === 'auto' ? 'Attacco base' : (SKILLS[k] ? SKILLS[k].name : k);
        return `<div class="rowd"><div class="fill" style="width:${(a.v / max * 100).toFixed(1)}%"></div><div class="txt"><span>${esc(name)} <small style="color:#e0d0a8">${a.n}× · crit ${Math.round(a.c / a.n * 100)}%</small></span><span>${Math.round(a.v / dur)} · ${(a.v / s.total * 100).toFixed(1)}%</span></div></div>`;
      }).join('');
  }

  renderCharacter() {
    const me = this.g.me;
    if (!me) return;
    const c = CLASSES[this.g.cls], k = KINGDOMS[this.g.kd];
    const stats = ['vit', 'str', 'dex', 'int'].map(s => `<div class="stat-row" title="${STAT_DESC[s]}"><span>${STAT_NAMES[s]}</span><span><b>${me.st[s]}</b> ${me.sp > 0 ? `<button class="btn plus" data-stat="${s}">+</button>` : ''}</span></div>`).join('');
    $('char-body').innerHTML = `
      <div class="cb-head"><div class="n">${esc(this.g.name)}</div><div class="s">${c.name} (${c.title}) — Livello ${me.lvl}</div>
      <div class="s" style="color:${k.color}">${k.name}</div>${me.via ? `<div class="s">${VIE[me.via].name}</div>` : ''}</div>
      ${me.sp > 0 ? `<div class="pts">Punti statistica: ${me.sp}</div>` : ''}
      ${stats}
      <div class="derived">
        <span>Vita</span><span>${me.hp} / ${me.mhp}</span>
        <span>${RESOURCES[me.rt].name}</span><span>${Math.floor(me.res)} / ${me.rmax}</span>
        <span>Rapidità</span><span>${me.haste}% (GCD ${(me.gcd / 1000).toFixed(2)} s)</span>
        <span>Bonus ai danni</span><span>${me.dmgPct}%</span>
        <span>Destriero</span><span>${me.horse ? `${HORSE.names[HORSE.tierOf(me.horse.lvl)]} liv. ${me.horse.lvl}` : 'nessuno'}</span>
        <span>Moltiplicatore critico</span><span>×${me.cm || 1.6}</span>
      </div>
      <div class="via-title" style="margin-top:8px">Bonus dell'equipaggiamento</div>
      <div class="derived">
        ${Object.entries(me.g || {}).filter(([k]) => !['hp', 'def', 'atkPct', 'matkPct', 'crit', 'haste'].includes(k)).map(([k, v]) => `<span>${BONUS_STATS[k].name}</span><span>+${v}%</span>`).join('') || '<span>Nessuno</span><span></span>'}
        <span>Attacco</span><span>${me.atk}</span>
        <span>Attacco magico</span><span>${me.matk}</span>
        <span>Difesa</span><span>${me.def}</span>
        <span>Critico</span><span>${me.crit}%</span>
        <span>Evasione</span><span>${me.ev}%</span>
        <span>Intervallo d'attacco</span><span>${(me.aspd / 1000).toFixed(2)}s</span>
        <span>Velocità</span><span>${(me.spd / 8 * 100).toFixed(0)}%</span>
        <span>Esperienza</span><span>${me.exp} / ${me.need}</span>
      </div>`;
    $('char-body').querySelectorAll('[data-stat]').forEach(b => { b.onclick = () => this.g.net.send({ t: 'stat', s: b.dataset.stat }); });
  }

  renderSkills() {
    const me = this.g.me;
    if (!me) return;
    const c = CLASSES[this.g.cls];
    const tomes = (this.g.inv || []).reduce((s, x) => s + (x && x.id === 'tomo_tecnica' ? x.n : 0), 0);
    const row = (sid) => {
      const sk = SKILLS[sid];
      const lvl = this.g.lvlOf(sid);
      const canUp = lvl > 0 && ((lvl < SKILL_MAX_POINTS && me.kp > 0) || (lvl >= SKILL_MAX_POINTS && lvl < SKILL_MAX && tomes > 0));
      const meta = [sk.cost ? `${sk.cost}${c.res === 'mana' ? '% Mana' : ' ' + RESOURCES[c.res].name}` : '', sk.cast ? sk.cast + ' s' : '', sk.cd ? 'ric. ' + sk.cd + ' s' : '', sk.offgcd ? 'fuori GCD' : ''].filter(Boolean).join(' · ');
      return `<div class="skill-row ${lvl ? '' : 'locked'}"><div class="slot" ${lvl > 0 ? `data-skill="${sid}"` : ''} data-skill-info="${sid}">${skillIconHtml(sid, lvl <= 0)}</div>
        <div class="si" data-skill-info="${sid}"><div class="sn">${esc(sk.name)}</div><div class="sl">${lvl ? `Livello ${lvl}/${SKILL_MAX}${lvl >= SKILL_MAX_POINTS && lvl < SKILL_MAX ? ' — serve un tomo' : ''}` : `Si sblocca al livello ${sk.lvl}`}</div><div class="meta">${meta}</div></div>
        <button class="btn plus" data-up="${sid}" ${canUp ? '' : 'disabled'}>+</button></div>`;
    };
    let html = `<div class="pts">Punti abilità: ${me.kp}${tomes ? ` — Tomi della Tecnica: ${tomes}` : ''}</div>`;
    html += `<div class="via-title">Abilità di base</div>` + c.baseSkills.map(row).join('');
    const viaSkills = (v) => Object.values(SKILLS).filter(s => s.via === v).sort((a, b) => a.lvl - b.lvl).map(s => s.id);
    if (me.via) {
      html += `<div class="via-title">${VIE[me.via].name} — ${VIE[me.via].role}</div><div class="via-passive">${esc(VIE[me.via].desc)}</div>` + viaSkills(me.via).map(row).join('');
    } else if (me.lvl >= VIA_LEVEL) {
      html += `<div class="via-title">Scegli la tua Via (scelta definitiva)</div><div class="via-pick">` +
        c.vie.map(v => `<div class="pick" data-via="${v}"><div class="pn">${VIE[v].name}</div><div class="pd"><b>${VIE[v].role}</b> — ${VIE[v].desc}</div><div class="pd" style="margin-top:4px">${viaSkills(v).map(s => SKILLS[s].name).join(' · ')}</div></div>`).join('') + '</div>';
    } else {
      html += `<div class="via-title">Le Vie</div><div class="pd" style="margin:4px 0 8px">Al livello ${VIA_LEVEL} potrai scegliere una delle due Vie della tua classe:</div>` +
        c.vie.map(v => `<div style="margin-bottom:6px"><b>${VIE[v].name}</b> <span class="meta">(${VIE[v].role})</span><div class="pd">${VIE[v].desc}</div></div>`).join('');
    }
    html += `<div class="via-title">Tecniche a cavallo</div><div class="pd" style="margin:2px 0 6px">${me.horse ? `Destriero di livello ${me.horse.lvl}: le tecniche salgono con lui. Si usano in sella (R).` : 'Richiedono un destriero: parla con lo Stalliere del villaggio dal livello 10.'}</div>` +
      MOUNT_SKILLS.map(sid => { const sk = SKILLS[sid]; const ok = me.horse && me.horse.lvl >= sk.hlvl;
        return `<div class="skill-row ${ok ? '' : 'locked'}"><div class="slot" data-skill-info="${sid}">${skillIconHtml(sid, !ok)}</div><div class="si" data-skill-info="${sid}"><div class="sn">${esc(sk.name)}</div><div class="sl">${ok ? `Livello ${Math.min(20, me.horse.lvl)}` : `Destriero di livello ${sk.hlvl}`}</div><div class="meta">ric. ${sk.cd} s</div></div></div>`; }).join('');
    $('skills-body').innerHTML = html;
    $('skills-body').querySelectorAll('[data-up]').forEach(b => { b.onclick = () => this.g.net.send({ t: 'skup', s: b.dataset.up }); });
    $('skills-body').querySelectorAll('[data-via]').forEach(b => {
      b.onclick = () => this.confirm(`Intraprendere la <b>${VIE[b.dataset.via].name}</b>? La scelta è definitiva.`, () => this.g.net.send({ t: 'via', v: b.dataset.via }));
    });
  }

  // ------------------------------------------------------------ negozio e fabbro
  openShop(m) {
    this.close('win-smith');
    this.shop = { npc: m.npc, role: m.role };
    $('shop-title').textContent = m.role === 'armi' ? 'Mastro Weng — Armaiolo' : 'Nonna Lin — Erborista';
    const el = $('shop-items');
    el.innerHTML = m.items.map(id => {
      const it = ITEMS[id];
      return `<div class="shop-item" data-shop-item="${id}" data-drop="shop"><div class="slot" style="pointer-events:none">${itemIconHtml({ id, n: 1, up: 0 })}</div><div><div class="sn">${esc(it.name)}</div><div class="sp">${it.price} tael${it.lvl > 1 ? ` — liv. ${it.lvl}` : ''}</div></div></div>`;
    }).join('');
    el.querySelectorAll('.shop-item').forEach(row => {
      row.onclick = (e) => {
        const id = row.dataset.shopItem;
        const n = e.shiftKey && ITEMS[id].stack ? 10 : 1;
        this.g.net.send({ t: 'buy', npc: this.shop.npc, it: id, n });
      };
    });
    this.open('win-shop');
    if (!this.isOpen('win-inventory')) this.open('win-inventory');
  }

  // ------------------------------------------------------------ Prove del Sigillo
  openTrial(m) {
    this.trial = m;
    this.open('win-trial');
    const me = this.g.me;
    const L = [];
    L.push(`<p>"La Cripta delle Mille Lanterne custodisce i sigilli degli antichi. Ripulitela dalle forze nemiche e sconfiggete <b>Shen, il Custode Insonne</b>, prima che scada il tempo: ${Math.round(DUNGEON.timeLimit / 60)} minuti."</p>`);
    if (m.key) {
      L.push(`<div class="key">Sigillo della Prova +${m.key}</div>`);
      L.push(`<div class="tt" style="text-align:center">In tempo: il sigillo sale di 1-3 livelli secondo la velocità. Fuori tempo o abbandonando: scende di 1. Ogni morte costa ${DUNGEON.deathPenalty} secondi.</div>`);
    } else {
      L.push(`<p class="tt">Non hai ancora un sigillo. Dal livello ${m.minLevel} posso affidartene uno di livello +${DUNGEON.startKey}.</p>`);
    }
    L.push('<div class="via-title">Modificatori di questa settimana</div>');
    m.week.forEach((a, i) => {
      const on = m.key && (i === 0 ? m.key >= 3 : m.key >= 6);
      L.push(`<div class="affrow ${on ? '' : 'off'}"><div class="g">${AFFIXES[a].glyph}</div><div><b>${AFFIXES[a].name}</b> <small class="tt">(dal +${i === 0 ? 3 : 6})</small><br><small>${esc(AFFIXES[a].desc)}</small></div></div>`);
    });
    if (m.best) L.push(`<div class="tt" style="margin-top:6px">Miglior prova completata in tempo: +${m.best}</div>`);
    L.push(`<div class="tt" style="margin-top:6px">${m.party > 1 ? `Gruppo di ${m.party}: entrano i compagni entro 40 metri da me.` : 'Puoi entrare da solo o con un gruppo (fino a 5): la vita dei nemici si adatta al numero di partecipanti.'}</div>`);
    L.push('<div class="row" style="justify-content:center">');
    if (!m.key) L.push(`<button class="btn primary" id="tr-key" ${me.lvl >= m.minLevel ? '' : 'disabled'}>Ricevi il sigillo</button>`);
    else L.push(`<button class="btn primary" id="tr-open" ${m.leader ? '' : 'disabled'} title="${m.leader ? '' : 'Solo il capogruppo può aprire la prova'}">Apri la Prova +${m.key}</button>`);
    L.push('</div>');
    $('trial-body').innerHTML = L.join('');
    const k = $('tr-key'); if (k) k.onclick = () => this.g.net.send({ t: 'trial', npc: m.npc, a: 'key' });
    const o = $('tr-open'); if (o) o.onclick = () => { this.g.net.send({ t: 'trial', npc: m.npc, a: 'open' }); this.close('win-trial'); };
  }

  renderDungeonHud() {
    const el = $('dg-hud');
    const g = this.g, st = g.dgState;
    if (!g.dg) { el.classList.add('hidden'); el.innerHTML = ''; return; }
    el.classList.remove('hidden');
    const kl = st ? st.kl : g.dg.kl, aff = st ? st.affixes : g.dg.affixes;
    let html = `<div class="dgt">${DUNGEON.trial} +${kl}</div><div class="dgs">${DUNGEON.name}</div>`;
    html += `<div class="timer" id="dg-timer">--:--</div>`;
    if (st) {
      html += `<div class="dgs">Forze nemiche</div><div class="bar forces"><div class="fill" style="width:${Math.min(100, st.forces / st.need * 100)}%"></div><span>${Math.min(st.forces, 999)}% / ${st.need}%</span></div>`;
      html += `<div class="dgs">Shen, il Custode Insonne</div><div class="bar boss"><div class="fill" style="width:${st.bossDead ? 0 : st.boss}%"></div><span>${st.bossDead ? 'Sconfitto' : st.boss + '%'}</span></div>`;
      html += `<div class="dgs">Morti: ${st.deaths} (−${st.deaths * DUNGEON.deathPenalty} s)</div>`;
    }
    if (aff && aff.length) html += `<div class="aff">${aff.map(a => `<span title="${esc(AFFIXES[a].name + ': ' + AFFIXES[a].desc)}">${AFFIXES[a].glyph}</span>`).join('')}</div>`;
    if (st && st.result) {
      const r = st.result, mm = Math.floor(r.elapsed / 60), ss = String(r.elapsed % 60).padStart(2, '0');
      html += `<div class="res">${r.inTime ? 'Completata in tempo!' : 'Completata fuori tempo'}<br>${mm}:${ss} — Sigillo <b>+${r.oldKl} → +${r.newKl}</b><br><small class="tt">Uscita automatica tra ${Math.ceil(st.closeIn / 1000)} s</small></div>`;
    }
    html += `<button class="btn" id="dg-leave">${st && st.done ? 'Esci dalla cripta' : 'Abbandona la prova'}</button>`;
    el.innerHTML = html;
    $('dg-leave').onclick = () => {
      if (st && st.done) this.g.net.send({ t: 'tleave' });
      else this.confirm('Abbandonare la prova? Se hai aperto tu il sigillo, scenderà di un livello.', () => this.g.net.send({ t: 'tleave' }));
    };
    this.updateDungeonTimer();
  }

  updateDungeonTimer() {
    const g = this.g, st = g.dgState, el = $('dg-timer');
    if (!el || !st) return;
    const used = (st.done && st.result ? st.result.elapsed * 1000 : st.elapsed + (performance.now() - g.dgStateAt)) + (st.done ? 0 : st.penalty);
    const left = st.limit - used;
    const t = Math.abs(left) / 1000, mm = Math.floor(t / 60), ss = String(Math.floor(t % 60)).padStart(2, '0');
    el.textContent = `${left < 0 ? '+' : ''}${mm}:${ss}`;
    el.className = 'timer' + (left < 0 ? ' over' : '');
  }

  openStable(m) {
    this.stable = { npc: m.npc };
    this.open('win-stable');
    this.renderStable();
  }

  renderStable() {
    if (!this.stable || !this.isOpen('win-stable')) return;
    const me = this.g.me, h = me.horse;
    let html;
    if (!h) {
      const can = me.lvl >= HORSE.minLevel && me.tael >= HORSE.price;
      html = `<div class="hn">Un Puledro tutto tuo</div>
        <p>"Ogni guerriero ha bisogno di un compagno a quattro zampe. Te lo affido per ${HORSE.price.toLocaleString('it-IT')} tael: trattalo bene e diventerà un Destriero da Guerra."</p>
        <p class="tt">Richiede il livello ${HORSE.minLevel}. In sella corri più veloce e usi le tecniche a cavallo, ad area: perfette per gli accampamenti di mostri.</p>
        <div class="row" style="justify-content:center"><button class="btn primary" id="st-buy" ${can ? '' : 'disabled'}>Compra (${HORSE.price.toLocaleString('it-IT')} tael)</button></div>`;
    } else {
      const tier = HORSE.tierOf(h.lvl), maxed = h.lvl >= HORSE.maxLevel, cost = HORSE.trainCost(h.lvl);
      html = `<div class="hn">${HORSE.names[tier]} — livello ${h.lvl}</div>
        <div class="bar"><div class="fill" style="width:${maxed ? 100 : Math.min(100, h.exp / h.need * 100)}%"></div><span>${maxed ? 'Livello massimo' : `${h.exp} / ${h.need}`}</span></div>
        <div>Velocità in sella: <b>+${Math.round((HORSE.speed(h.lvl) - 1) * 100)}%</b></div>
        <div class="tt">Il destriero guadagna esperienza quando combatti in sella. Ai livelli 10 e 20 cambia aspetto.</div>
        <div style="margin-top:6px">${MOUNT_SKILLS.map(sid => { const sk = SKILLS[sid]; return `<div class="ms ${h.lvl >= sk.hlvl ? '' : 'lock'}"><div class="slot" data-skill-info="${sid}">${skillIconHtml(sid, h.lvl < sk.hlvl)}</div><div>${esc(sk.name)}<br><small class="tt">${h.lvl >= sk.hlvl ? 'disponibile' : 'dal livello ' + sk.hlvl}</small></div></div>`; }).join('')}</div>
        <div class="row" style="justify-content:center"><button class="btn" id="st-train" ${!maxed && me.tael >= cost ? '' : 'disabled'}>Addestra (+${HORSE.trainPct}% · ${cost.toLocaleString('it-IT')} tael)</button></div>`;
    }
    $('stable-body').innerHTML = html;
    const b = $('st-buy'); if (b) b.onclick = () => this.g.net.send({ t: 'stable', npc: this.stable.npc, a: 'buy' });
    const t = $('st-train'); if (t) t.onclick = () => this.g.net.send({ t: 'stable', npc: this.stable.npc, a: 'train' });
  }

  openSmith(m) {
    this.close('win-shop');
    this.smith = { npc: m.npc };
    this.smithSlot = -1;
    this.smithRes = '';
    this.open('win-smith');
    if (!this.isOpen('win-inventory')) this.open('win-inventory');
  }
  setSmithSlot(i) {
    const s = this.g.inv[i];
    if (!s || !equipSlotOf(ITEMS[s.id])) { this.notice('Il fabbro lavora solo armi e armature', true); return; }
    this.smithSlot = i; this.smithRes = '';
    this.renderSmith();
  }
  renderSmith() {
    if (!this.smith) return;
    const s = this.smithSlot >= 0 ? this.g.inv[this.smithSlot] : null;
    const me = this.g.me;
    let info = '<div class="smith-info">Trascina qui un\'arma o un\'armatura dall\'inventario, oppure fai clic destro su di essa.</div>';
    let canGo = false;
    const seals = (this.g.inv || []).reduce((a, x) => a + (x && x.id === 'sigillo_fabbro' ? x.n : 0), 0);
    if (s) {
      const it = ITEMS[s.id], lv = s.up;
      const nameHtml = `<b style="color:${rarityColor(s)}">${esc(it.name)}</b>`;
      if (lv >= UPGRADE.max) info = `<div class="smith-info">${nameHtml} +${lv}<br>Questo oggetto ha raggiunto la perfezione.</div>`;
      else {
        const cost = UPGRADE.cost[lv], mat = UPGRADE.mats[lv];
        const have = mat ? (this.g.inv || []).reduce((a, x) => a + (x && x.id === mat[0] ? x.n : 0), 0) : 0;
        const okT = me.tael >= cost, okM = !mat || have >= mat[1];
        canGo = okT && okM;
        const risky = lv >= UPGRADE.safeBelow;
        const bonus = Math.min(UPGRADE.failBonusMax, (s.fs || 0) * UPGRADE.failBonus);
        const fail = !risky ? '<span class="ok">Se fallisce, l\'oggetto resta intatto.</span>'
          : lv >= UPGRADE.downgradeFrom ? '<span class="bad">Se fallisce, l\'oggetto viene distrutto!</span><br><span class="tt">Con il sigillo: scende di un livello invece di rompersi.</span>'
          : '<span class="bad">Se fallisce, l\'oggetto viene distrutto!</span><br><span class="tt">Con il sigillo: resta intatto.</span>';
        info = `<div class="smith-info">${nameHtml}: +${lv} → <b>+${lv + 1}</b><br>
          Probabilità di successo: <b>${UPGRADE.chance[lv] + bonus}%</b>${bonus ? ` <span style="color:#9ad8ff">(perseveranza +${bonus}%)</span>` : ''}<br>
          Costo: <span class="${okT ? 'ok' : 'bad'}">${cost.toLocaleString('it-IT')} tael</span><br>
          ${mat ? `Materiale: <span class="${okM ? 'ok' : 'bad'}">${ITEMS[mat[0]].name} ${have}/${mat[1]}</span><br>` : ''}
          ${fail}
          ${risky ? `<label style="display:inline-flex;gap:6px;align-items:center;margin-top:6px"><input type="checkbox" id="smith-seal" style="width:auto" ${seals ? '' : 'disabled'} ${this.sealChecked && seals ? 'checked' : ''}> Usa Sigillo del Fabbro (${seals})</label>` : ''}
          </div>`;
      }
    }
    $('smith-body').innerHTML = `<div class="slot" data-drop="smith">${s ? itemIconHtml(s) : ''}</div>${info}
      <div class="row" style="justify-content:center"><button class="btn primary" id="smith-go" ${canGo ? '' : 'disabled'}>Potenzia</button>
      <button class="btn" id="smith-salvage" ${s ? '' : 'disabled'} title="Distrugge l'oggetto e restituisce materiali e gemme">Smonta</button></div>
      <div class="smith-res">${this.smithRes || ''}</div>`;
    const seal = $('smith-seal');
    if (seal) seal.onchange = () => { this.sealChecked = seal.checked; };
    $('smith-go').onclick = () => {
      const st = this.g.inv[this.smithSlot];
      const go = () => this.g.net.send({ t: 'up', npc: this.smith.npc, i: this.smithSlot, seal: !!this.sealChecked });
      if (st && st.up >= UPGRADE.safeBelow && !this.sealChecked) this.confirm(`Senza sigillo, se il potenziamento fallisce <b>${esc(ITEMS[st.id].name)}</b> verrà distrutto. Procedere?`, go);
      else go();
    };
    $('smith-salvage').onclick = () => {
      const st = this.g.inv[this.smithSlot];
      if (!st) return;
      this.confirm(`Smontare <b style="color:${rarityColor(st)}">${esc(ITEMS[st.id].name)}${st.up ? ' +' + st.up : ''}</b>? L'oggetto andrà perso; riceverai materiali e le gemme incastonate.`,
        () => this.g.net.send({ t: 'salvage', npc: this.smith.npc, i: this.smithSlot }));
    };
  }
  onSmithResult(m) {
    if (m.salvaged) { this.smithRes = `<span style="color:#ffd060">Smontato: ${esc(m.got.join(', '))}</span>`; this.smithSlot = -1; this.g.sound('coin'); }
    else if (m.ok) { this.smithRes = `<span style="color:#8aff9a">Successo! ${esc(m.name)} è ora +${m.up}.</span>`; this.g.sound('ok'); }
    else if (m.destroyed) { this.smithRes = `<span style="color:#ff6a4a">Il metallo si è spezzato... ${esc(m.name)} è andato distrutto.</span>`; this.smithSlot = -1; this.g.sound('die'); }
    else if (m.down) this.smithRes = `<span style="color:#ffd060">Fallito: il Sigillo ha salvato l'oggetto, che scende a +${m.up}.</span>`;
    else if (m.sealUsed) this.smithRes = '<span style="color:#ffd060">Fallito, ma il Sigillo del Fabbro ha protetto l\'oggetto.</span>';
    else this.smithRes = '<span style="color:#ffb060">Fallito. L\'oggetto è rimasto intatto.</span>';
    this.renderSmith();
  }

  openDialog(m) {
    $('dialog-title').textContent = m.n;
    $('dialog-text').textContent = m.m;
    this.open('win-dialog');
  }

  // ------------------------------------------------------------ messaggi
  chat(cls, html) {
    const log = $('chat-log');
    const d = document.createElement('div');
    if (cls) d.className = cls;
    d.innerHTML = html;
    const atBottom = log.scrollTop + log.clientHeight >= log.scrollHeight - 20;
    log.appendChild(d);
    while (log.children.length > 150) log.firstChild.remove();
    if (atBottom) log.scrollTop = log.scrollHeight;
  }
  chatMsg(m) {
    const k = KINGDOMS[m.kd];
    const name = `<b style="color:${k ? k.color : '#e0a0ff'}">${esc(m.n)}</b>`;
    if (m.ch === 'shout') this.chat('shout', `[Regno] ${name}: ${esc(m.m)}`);
    else if (m.ch === 'party') this.chat('party', `[Gruppo] <b>${esc(m.n)}</b>: ${esc(m.m)}`);
    else if (m.ch === 'wh') this.chat('wh', m.to ? `A <b>${esc(m.to)}</b>: ${esc(m.m)}` : `<b>${esc(m.n)}</b> sussurra: ${esc(m.m)}`);
    else this.chat('', `${name}: ${esc(m.m)}`);
  }

  notice(text, err) {
    const n = $('notice');
    n.textContent = text;
    n.className = err ? 'err' : '';
    n.style.opacity = 1;
    clearTimeout(this.noticeTimer);
    this.noticeTimer = setTimeout(() => { n.style.opacity = 0; }, err ? 1600 : 3200);
  }

  showDeath(by, lost) {
    const ov = $('death-overlay');
    if (by !== undefined) {
      this.deathAt = performance.now();
      $('death-text').innerHTML = `Sei stato sconfitto da <b>${esc(by)}</b>.${lost ? `<br>Hai perso ${lost} punti esperienza.` : ''}`;
    }
    if (!this.deathAt) this.deathAt = performance.now();
    ov.classList.remove('hidden');
  }
  updateDeath(now) {
    if ($('death-overlay').classList.contains('hidden')) return;
    const el = (now - (this.deathAt || now)) / 1000;
    const here = $('btn-respawn-here'), town = $('btn-respawn-town');
    here.disabled = el < 8; town.disabled = el < 3;
    here.textContent = el < 8 ? `Rialzati qui (${Math.ceil(8 - el)})` : 'Rialzati qui';
    town.textContent = el < 3 ? `Torna al villaggio (${Math.ceil(3 - el)})` : 'Torna al villaggio';
  }
  hideDeath() { $('death-overlay').classList.add('hidden'); this.deathAt = 0; }

  updateTarget(ent) {
    const tf = $('target-frame');
    if (!ent) { tf.classList.add('hidden'); return; }
    tf.classList.remove('hidden');
    const i = ent.info;
    let name = esc(i.n);
    if (i.k === 'm' || i.k === 'p') name += ` <span style="color:#d8c8a0">[${ent.lvl}]</span>`;
    if (i.k === 'p') name = `<span style="color:${KINGDOMS[i.kd].color}">${name}</span>`;
    if (tf.dataset.n !== name) { $('tf-name').innerHTML = name; tf.dataset.n = name; }
    const bar = tf.querySelector('.bar');
    if (i.k === 'm' || i.k === 'p') { bar.style.display = ''; this.setBar('#target-frame .bar.hp', ent.hp, ent.mhp); }
    else bar.style.display = 'none';
    // Postura: barra sottile sotto la vita, solo per i nemici che ce l'hanno; lampeggia se Squilibrato
    const pb = $('tf-post'), conPostura = i.k === 'm' && ent.po !== undefined && ent.hp > 0;
    pb.classList.toggle('hidden', !conPostura);
    if (conPostura) {
      const sq = !!ent.sqOn;
      pb.querySelector('.fill').style.width = Math.max(0, Math.min(100, ent.po)) + '%';
      pb.classList.toggle('squil', sq);
      pb.querySelector('span').textContent = sq ? 'Squilibrato!' : '';
      pb.title = sq ? 'Squilibrato: stordito e subisce più danni' : `Postura ${ent.po}% — le tecniche che spendono risorsa la spezzano`;
    }
    if (tf.dataset.id !== String(ent.id)) { tf.dataset.id = ent.id; this.renderTargetDots(performance.now()); }
    const g = this.g, party = g.party;
    const canInvite = i.k === 'p' && i.kd === g.kd && !(party && party.members.some(m => m.id === ent.id)) && (!party || (party.leader === g.myId && party.members.length < 5));
    $('tf-invite').classList.toggle('hidden', !canInvite);
    $('tf-invite').onclick = () => g.net.send({ t: 'pinv', id: ent.id });
  }

  renderParty() {
    const el = $('party-frames');
    const party = this.g.party;
    if (!party) { el.classList.add('hidden'); el.innerHTML = ''; el.dataset.h = ''; return; }
    el.classList.remove('hidden');
    const me = this.g.myId, lead = party.leader === me;
    const self = this.g.self;
    const html = `<div class="ph"><span>Gruppo (${party.members.length}/5)</span><button class="btn" id="party-leave">Lascia</button></div>` +
      party.members.filter(m => m.id !== me).map(m => {
        const c = CLASSES[m.cls], R = RESOURCES[m.rt];
        const far = self && Math.hypot(m.x - self.x, m.z - self.z) > 100;
        const sel = this.g.target && this.g.target.id === m.id;
        return `<div class="pm ${far ? 'far' : ''} ${sel ? 'sel' : ''}" data-pm="${m.id}">
          <div class="pn"><span>${party.leader === m.id ? '★ ' : ''}${esc(m.n)}</span><span><small>${c.name} ${m.lvl}</small>${lead ? `<button class="kick" data-kick="${m.id}" title="Espelli">✕</button>` : ''}</span></div>
          <div class="bar hp"><div class="fill" style="width:${m.dead ? 0 : Math.max(0, m.hp / m.mhp * 100)}%"></div><span>${m.dead ? 'Caduto' : `${m.hp} / ${m.mhp}`}</span></div>
          <div class="bar mp"><div class="fill" style="width:${m.rmax ? m.res / m.rmax * 100 : 0}%;background:linear-gradient(${R.color}, #10101088)"></div></div>
        </div>`;
      }).join('');
    if (el.dataset.h === html) return;
    el.dataset.h = html;
    el.innerHTML = html;
    $('party-leave').onclick = () => this.confirm('Lasciare il gruppo?', () => this.g.net.send({ t: 'pleave' }));
    el.querySelectorAll('[data-kick]').forEach(b => { b.onclick = (e) => { e.stopPropagation(); const id = +b.dataset.kick; const m = party.members.find(x => x.id === id); this.confirm(`Espellere ${esc(m.n)} dal gruppo?`, () => this.g.net.send({ t: 'pkick', id })); }; });
    el.querySelectorAll('[data-pm]').forEach(d => {
      d.onclick = () => {
        const ent = this.g.ents.get(+d.dataset.pm);
        if (ent) this.g.setTarget(ent); else this.notice('Compagno troppo lontano', true);
      };
    });
  }

  // ------------------------------------------------------------ minimappa
  initMinimap(terrainMesh) {
    const geo = terrainMesh.geometry;
    const pos = geo.attributes.position, col = geo.attributes.color;
    const N = Math.round(Math.sqrt(pos.count));
    const cv = document.createElement('canvas'); cv.width = cv.height = N;
    const ctx = cv.getContext('2d');
    const img = ctx.createImageData(N, N);
    const toS = (v) => Math.round(255 * (v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055));
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i);
      let r, g, b;
      if (y < -0.05) { r = 44; g = 98; b = 128; }
      else { r = toS(col.getX(i)); g = toS(col.getY(i)); b = toS(col.getZ(i)); }
      img.data[i * 4] = r; img.data[i * 4 + 1] = g; img.data[i * 4 + 2] = b; img.data[i * 4 + 3] = 255;
    }
    ctx.putImageData(img, 0, 0);
    const scale = N / 600;
    for (const kid of KINGDOM_IDS) {
      const v = KINGDOMS[kid].village;
      ctx.strokeStyle = KINGDOMS[kid].color; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc((v.x + 300) * scale, (v.z + 300) * scale, WALL_RADIUS * scale, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.strokeStyle = '#6a3a2a'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc((CENTER.x + 300) * scale, (CENTER.z + 300) * scale, 26 * scale, 0, Math.PI * 2); ctx.stroke();
    this.mapImg = cv; this.mapScale = scale;
    this.mm = $('minimap').getContext('2d');
    this.lastZone = '';
  }

  drawMinimap(self, ents, target) {
    if (!this.mapImg) return;
    const ctx = this.mm, R = 75, S = 180, k = S / (R * 2);
    ctx.save();
    ctx.clearRect(0, 0, S, S);
    ctx.beginPath(); ctx.arc(S / 2, S / 2, S / 2, 0, Math.PI * 2); ctx.clip();
    if (this.g.dg && self.x > 800) {
      ctx.fillStyle = '#0c0807'; ctx.fillRect(0, 0, S, S);
      ctx.fillStyle = '#4a3e36';
      for (const [x1, z1, x2, z2] of DUNGEON.rooms) {
        ctx.fillRect(S / 2 + (this.g.dg.ox + x1 - self.x) * k, S / 2 + (this.g.dg.oz + z1 - self.z) * k, (x2 - x1) * k, (z2 - z1) * k);
      }
    } else {
      ctx.fillStyle = '#2c6280'; ctx.fillRect(0, 0, S, S);
      const sc = this.mapScale;
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(this.mapImg, (self.x - R + 300) * sc, (self.z - R + 300) * sc, R * 2 * sc, R * 2 * sc, 0, 0, S, S);
    }
    for (const e of ents.values()) {
      if (e === self) continue;
      const dx = e.x - self.x, dz = e.z - self.z;
      if (Math.abs(dx) > R || Math.abs(dz) > R) continue;
      const x = S / 2 + dx * k, y = S / 2 + dz * k;
      const i = e.info;
      let c = null, r = 2.5;
      if (i.k === 'm') { if (e.hp <= 0) continue; c = e.boss ? '#ff3a1a' : e.stone ? '#c060ff' : '#e04030'; r = e.boss ? 5 : e.stone ? 4 : 2.5; }
      else if (i.k === 'p') { c = this.g.inParty(e.id) ? '#8aff9a' : KINGDOMS[i.kd].color; r = 3.5; }
      else if (i.k === 'n') { c = '#ffd860'; r = 3; }
      else if (i.k === 'd') { c = '#d8e8ff'; r = 1.6; }
      if (!c) continue;
      ctx.fillStyle = c; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
      if (target === e) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(x, y, r + 2.5, 0, Math.PI * 2); ctx.stroke(); }
    }
    // compagni di gruppo fuori dal campo visivo: puntino sul bordo
    for (const m of (this.g.party ? this.g.party.members : [])) {
      if (m.id === this.g.myId || ents.has(m.id)) continue;
      let dx = m.x - self.x, dz = m.z - self.z;
      const d = Math.hypot(dx, dz), lim = R * 0.92;
      if (d > lim) { dx = dx / d * lim; dz = dz / d * lim; }
      ctx.fillStyle = '#8aff9a'; ctx.strokeStyle = '#000';
      ctx.beginPath(); ctx.arc(S / 2 + dx * k, S / 2 + dz * k, 3.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    }
    ctx.translate(S / 2, S / 2);
    ctx.rotate(-self.r + Math.PI);
    ctx.fillStyle = '#fff'; ctx.strokeStyle = '#000'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, -7); ctx.lineTo(5, 5); ctx.lineTo(0, 2); ctx.lineTo(-5, 5); ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.restore();
    const z = zoneAt(self.x, self.z);
    if (z.name !== this.lastZone) {
      if (this.lastZone) this.notice(z.name + (z.safe ? ' — zona sicura' : ''));
      this.lastZone = z.name;
      $('zone-name').textContent = z.name;
    }
    $('coords').textContent = `${Math.round(self.x)}, ${Math.round(self.z)}`;
  }
}
