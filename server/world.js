// Logica di gioco lato server: entità, combattimento, IA dei mostri, oggetti, PNG.
// Il server è autoritativo su danni, oggetti, esperienza e tael.
import {
  CLASSES, VIE, SKILLS, ITEMS, MOBS, UPGRADE, SHOPS, NPC_ROLES, WEAPON_TYPES, GUARD_LINES,
  INV_SIZE, QB_SIZE, STACK_MAX, STAT_MAX, EQUIP_SLOTS, MAX_LEVEL, VIA_LEVEL, SKILL_MAX_POINTS, SKILL_MAX, BOOK_CHANCE,
  expToNext, skillVal, skillMp, upgradedStat, equipSlotOf,
} from '../shared/data.js';
import {
  KINGDOMS, KINGDOM_IDS, CENTER, heightAt, villageFrame, toWorld, VILLAGE_LAYOUT, safeZoneAt, villageSpawn,
  PLAY_LIMIT, mulberry32,
} from '../shared/world.js';

const VIEW = 105;
const NOW = () => Date.now();
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(a + Math.random() * (b - a + 1));
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const r1 = v => Math.round(v * 10) / 10;
const r2 = v => Math.round(v * 100) / 100;

function expMod(plvl, mlvl) {
  const d = mlvl - plvl;
  if (d >= 0) return Math.min(1.25, 1 + d * 0.05);
  if (d >= -4) return 1;
  return Math.max(0.1, 1 + (d + 4) * 0.15);
}

export function newCharacter(name, cls, kingdom) {
  const c = CLASSES[cls];
  const sp = villageSpawn(kingdom);
  const inv = Array(INV_SIZE).fill(null);
  const ch = {
    name, cls, kingdom, lvl: 1, exp: 0, statPts: 0, skillPts: 0,
    stats: { ...c.start }, via: null, skills: { [c.baseSkill]: 1 },
    inv, equip: { weapon: { id: c.startWeapon, n: 1, up: 0 }, head: null, body: { id: 'tunica_canapa', n: 1, up: 0 }, feet: { id: 'sandali', n: 1, up: 0 } },
    tael: 300, x: sp.x, z: sp.z, hp: -1, mp: -1, qb: Array(QB_SIZE).fill(null), created: Date.now(),
  };
  let i = 0;
  for (const id of c.extraItems) inv[i++] = { id, n: 1, up: 0 };
  inv[i++] = { id: 'ginseng_p', n: 10, up: 0 };
  inv[i++] = { id: 'loto_p', n: 6, up: 0 };
  inv[i++] = { id: 'pergamena_ritorno', n: 1, up: 0 };
  ch.qb[0] = { k: 's', id: c.baseSkill };
  ch.qb[6] = { k: 'i', id: 'ginseng_p' };
  ch.qb[7] = { k: 'i', id: 'loto_p' };
  return ch;
}

export class World {
  constructor(db, cfg, saveConfig) {
    this.db = db;
    this.cfg = cfg;
    this.saveConfig = saveConfig || (() => {});
    this.ents = new Map();
    this.players = new Set();
    this.spawners = [];
    this.nextId = 1;
    this.regenAcc = 0;
    this.initNpcs();
    this.initSpawns();
  }

  start() {
    let last = NOW();
    setInterval(() => {
      const t = NOW();
      const dt = Math.min(0.25, (t - last) / 1000);
      last = t;
      try { this.tick(dt, t); } catch (e) { console.error('Errore nel tick:', e); }
    }, 50);
    setInterval(() => { try { this.netTick(); } catch (e) { console.error('Errore di rete:', e); } }, 100);
  }

  // ------------------------------------------------------------ entità
  add(e) { e.id = this.nextId++; e.ver = 1; e.vis = 1; this.ents.set(e.id, e); return e; }
  remove(e) { this.ents.delete(e.id); }
  touch(e) { e.ver++; }
  radiusOf(e) {
    if (e.kind === 'mob') return 0.6 * (e.d.scale || 1) * (e.d.stone ? 2.2 : 1);
    return 0.5;
  }

  initNpcs() {
    for (const kid of KINGDOM_IDS) {
      const f = villageFrame(kid);
      for (const n of VILLAGE_LAYOUT.npcs) {
        const p = toWorld(f, n.x, n.z);
        this.add({ kind: 'npc', role: n.role, kingdom: kid, name: NPC_ROLES[n.role].name, x: p.x, z: p.z, r: f.a + (n.face || 0) });
      }
    }
  }

  initSpawns() {
    const rng = mulberry32(20261112);
    const validPos = (x, z, allowCenter = false) => {
      if (Math.abs(x) > 245 || Math.abs(z) > 245) return false;
      if (heightAt(x, z) < 0.6) return false;
      for (const kid of KINGDOM_IDS) {
        const v = KINGDOMS[kid].village;
        if (Math.hypot(x - v.x, z - v.z) < 54) return false;
      }
      if (!allowCenter && Math.hypot(x - CENTER.x, z - CENTER.z) < 32) return false;
      return true;
    };
    const pick = (table) => {
      const tot = table.reduce((s, t) => s + t[1], 0);
      let r = rng() * tot;
      for (const [ty, w] of table) { if ((r -= w) <= 0) return ty; }
      return table[0][0];
    };
    const place = (cx, cz, rmin, rmax, groups, table, countRange, filter) => {
      let made = 0, tries = 0;
      while (made < groups && tries++ < 500) {
        const a = rng() * Math.PI * 2, r = rmin + rng() * (rmax - rmin);
        const x = cx + Math.cos(a) * r, z = cz + Math.sin(a) * r;
        if (!validPos(x, z) || (filter && !filter(x, z))) continue;
        const type = pick(table);
        const stone = MOBS[type].stone;
        const count = stone ? 1 : countRange[0] + Math.floor(rng() * (countRange[1] - countRange[0] + 1));
        this.addSpawner(type, x, z, count);
        made++;
      }
    };
    const farFromCenter = (x, z) => Math.hypot(x - CENTER.x, z - CENTER.z) > 95;
    for (const kid of KINGDOM_IDS) {
      const v = KINGDOMS[kid].village;
      place(v.x, v.z, 58, 115, 16, [['lupo', 3], ['cinghiale', 3], ['lupo_alfa', 1]], [3, 4]);
      place(v.x, v.z, 118, 175, 12, [['bandito', 3], ['scimmia', 2], ['arciere_bandito', 2], ['orso_nero', 1]], [2, 4], farFromCenter);
      place(v.x, v.z, 80, 160, 2, [['obelisco_minore', 1]], [1, 1], farFromCenter);
    }
    place(CENTER.x, CENTER.z, 38, 92, 16, [['terracotta', 3], ['spirito_lanterna', 3], ['tigre_spettrale', 1]], [2, 3]);
    place(CENTER.x, CENTER.z, 45, 88, 3, [['obelisco_abisso', 1]], [1, 1]);
    this.addSpawner('generale', CENTER.x, CENTER.z, 1);
  }

  addSpawner(type, x, z, count) {
    const sp = { type, x, z, count, pending: [] };
    this.spawners.push(sp);
    for (let i = 0; i < count; i++) this.spawnFromSpawner(sp);
  }

  spawnFromSpawner(sp) {
    let x = sp.x, z = sp.z;
    if (!MOBS[sp.type].stone && !MOBS[sp.type].boss) {
      for (let i = 0; i < 6; i++) {
        const nx = sp.x + rand(-6, 6), nz = sp.z + rand(-6, 6);
        if (heightAt(nx, nz) > 0.3) { x = nx; z = nz; break; }
      }
    }
    const m = this.spawnMob(sp.type, x, z, sp, false);
    if (MOBS[sp.type].boss) this.broadcast({ t: 'notice', m: `${m.name} è apparso sull'Altopiano delle Spade Spezzate!` });
    return m;
  }

  spawnMob(type, x, z, spawner, temp) {
    const d = MOBS[type];
    return this.add({
      kind: 'mob', type, d, name: d.name, lvl: d.lvl, x, z, r: Math.random() * Math.PI * 2,
      hp: d.hp, maxHp: d.hp, atk: d.atk, def: d.def, spawn: { x, z }, spawner, temp,
      state: 'idle', target: null, aggro: new Map(), nextAttack: 0, wanderAt: NOW() + rand(1000, 8000), dest: null,
      stunUntil: 0, slowUntil: 0, dots: [], waveIdx: 0, removeAt: 0, lastActive: NOW(),
    });
  }

  spawnDrop(id, n, x, z, owner) {
    const it = ITEMS[id];
    const make = (cnt) => this.add({
      kind: 'drop', item: { id, n: cnt, up: 0 }, x: x + rand(-1.6, 1.6), z: z + rand(-1.6, 1.6),
      owner: owner || 0, ownerUntil: NOW() + 20000, expire: NOW() + 90000,
    });
    if (it.stack) make(n); else for (let i = 0; i < n; i++) make(1);
  }

  // ------------------------------------------------------------ giocatori
  addPlayer(sess, ch) {
    const p = {
      kind: 'player', sess, ch, name: ch.name, cls: ch.cls, kingdom: ch.kingdom, lvl: ch.lvl,
      x: ch.x, z: ch.z, r: 0, hp: ch.hp, mp: ch.mp, buffs: [], hots: [], dots: [], cds: {},
      nextAttack: 0, dead: false, known: new Map(), knownVis: new Map(), stunUntil: 0, slowUntil: 0,
      lastMoveAt: NOW(), lastCombat: 0, selfDirty: true, invDirty: true, gm: !!sess.gm, online: true,
    };
    this.add(p);
    this.players.add(p);
    this.recalc(p);
    if (!Number.isFinite(p.x) || !Number.isFinite(p.z) || p.hp === 0) {
      const sp = villageSpawn(p.kingdom); p.x = sp.x; p.z = sp.z; p.hp = p.maxHp; p.mp = p.maxMp;
    }
    if (p.hp < 0 || p.hp > p.maxHp) p.hp = p.maxHp;
    if (p.mp < 0 || p.mp > p.maxMp) p.mp = p.maxMp;
    this.send(p, {
      t: 'enter', id: p.id, name: p.name, cls: p.cls, kd: p.kingdom, gm: p.gm ? 1 : 0, x: r1(p.x), z: r1(p.z),
      pvp: this.cfg.pvp ? 1 : 0, pvpMin: this.cfg.pvpMinLevel,
    });
    this.broadcast({ t: 'sys', m: `${p.name} (${KINGDOMS[p.kingdom].short}) è entrato nel mondo.` });
    return p;
  }

  removePlayer(p) {
    p.online = false;
    this.saveChar(p);
    this.remove(p);
    this.players.delete(p);
    this.broadcast({ t: 'sys', m: `${p.name} ha lasciato il mondo.` });
  }

  saveChar(p) {
    const ch = p.ch;
    ch.lvl = p.lvl; ch.x = r1(p.x); ch.z = r1(p.z);
    ch.hp = p.dead ? 0 : Math.round(p.hp); ch.mp = Math.round(p.mp);
  }
  saveAll() { for (const p of this.players) this.saveChar(p); }

  buffTotals(p) {
    const out = {};
    for (const b of p.buffs) for (const k in b.stats) out[k] = (out[k] || 0) + b.stats[k];
    return out;
  }

  recalc(p) {
    const c = CLASSES[p.cls], s = p.ch.stats, L = p.lvl, eq = p.ch.equip;
    let watk = 0, wmatk = 0, def = 0, spdPct = 0, range = 2.2, aspd = 1000;
    if (eq.weapon) {
      const it = ITEMS[eq.weapon.id];
      const wt = WEAPON_TYPES[it.wt];
      watk = upgradedStat(it.atk, eq.weapon.up, true);
      wmatk = upgradedStat(it.matk, eq.weapon.up, true);
      range = it.range || wt.range; aspd = wt.aspd;
    }
    for (const k of ['head', 'body', 'feet']) if (eq[k]) {
      const it = ITEMS[eq[k].id];
      def += upgradedStat(it.def, eq[k].up, false);
      spdPct += it.speed || 0;
    }
    const b = this.buffTotals(p);
    const prim = c.primary === 'dex' ? s.dex : s.str;
    const sec = c.primary === 'dex' ? s.str : s.dex;
    p.maxHp = Math.round(c.hp[0] + L * c.hp[1] + s.vit * c.hp[2]);
    p.maxMp = Math.round(c.mp[0] + L * c.mp[1] + s.int * c.mp[2]);
    p.atk = Math.round((watk + prim * 2 + sec * 0.5 + L * 2) * (1 + (b.atkPct || 0) / 100));
    p.matk = Math.round((wmatk + s.int * 2.5 + L * 2) * (1 + (b.matkPct || 0) / 100));
    p.def = Math.round((def + s.vit * 1.2 + L) * (1 + (b.defPct || 0) / 100));
    p.crit = Math.min(50, 2 + s.dex * 0.4 + (b.critPct || 0));
    p.evade = Math.min(15, s.dex * 0.2);
    p.aspd = Math.round(aspd / (1 + (b.aspdPct || 0) / 100 + s.dex * 0.004));
    p.speed = 8 * (1 + spdPct / 100);
    p.range = range;
    p.hpRegen = b.hpRegen || 0;
    if (p.hp > p.maxHp) p.hp = p.maxHp;
    if (p.mp > p.maxMp) p.mp = p.maxMp;
    p.selfDirty = true;
  }

  // ------------------------------------------------------------ rete
  send(p, obj) { if (p.sess) p.sess.send(obj); }
  err(p, m) { this.send(p, { t: 'err', m }); }
  sys(p, m) { this.send(p, { t: 'sys', m }); }
  broadcast(obj) { for (const p of this.players) this.send(p, obj); }
  fx(src, obj) {
    for (const p of this.players) {
      if (Math.abs(p.x - src.x) < VIEW && Math.abs(p.z - src.z) < VIEW) this.send(p, { t: 'fx', ...obj });
    }
  }

  info(e) {
    const base = { id: e.id, x: r1(e.x), z: r1(e.z), r: r2(e.r || 0) };
    switch (e.kind) {
      case 'player': {
        const eq = e.ch.equip;
        return { ...base, k: 'p', n: e.name, cls: e.cls, kd: e.kingdom, lvl: e.lvl, hp: Math.round(e.hp), mhp: e.maxHp,
          w: eq.weapon ? eq.weapon.id : null, wu: eq.weapon ? eq.weapon.up : 0, b: eq.body ? eq.body.id : null, h: eq.head ? eq.head.id : null,
          gm: e.gm ? 1 : 0, dead: e.dead ? 1 : 0 };
      }
      case 'mob': return { ...base, k: 'm', ty: e.type, n: e.name, lvl: e.lvl, hp: Math.round(e.hp), mhp: e.maxHp };
      case 'npc': return { ...base, k: 'n', role: e.role, kd: e.kingdom, n: e.name };
      case 'drop': return { ...base, k: 'd', it: e.item.id, n: e.item.n, up: e.item.up, own: e.owner };
    }
    return base;
  }
  upd(e) { return [e.id, r1(e.x), r1(e.z), r2(e.r || 0), Math.round(e.hp || 0), e.maxHp || 0, e.lvl || 0, e.dead ? 1 : 0]; }

  meMsg(p) {
    const ch = p.ch, t = NOW();
    return {
      t: 'me', lvl: p.lvl, exp: ch.exp, need: expToNext(p.lvl), hp: Math.round(p.hp), mhp: p.maxHp, mp: Math.round(p.mp), mmp: p.maxMp,
      atk: p.atk, matk: p.matk, def: p.def, crit: r1(p.crit), ev: r1(p.evade), aspd: p.aspd, spd: r2(p.speed), range: p.range,
      sp: ch.statPts, kp: ch.skillPts, st: ch.stats, via: ch.via, sk: ch.skills, tael: ch.tael, qb: ch.qb,
      buffs: p.buffs.map(b => ({ s: b.sid, ms: b.until - t })), dead: p.dead ? 1 : 0,
    };
  }

  netTick() {
    for (const p of this.players) {
      const adds = [], ups = [], rms = [];
      const seen = new Set();
      for (const e of this.ents.values()) {
        if (e === p) continue;
        if (Math.abs(e.x - p.x) > VIEW || Math.abs(e.z - p.z) > VIEW) continue;
        seen.add(e.id);
        const kv = p.known.get(e.id);
        if (kv === undefined || p.knownVis.get(e.id) !== e.vis) {
          adds.push(this.info(e)); p.known.set(e.id, e.ver); p.knownVis.set(e.id, e.vis);
        } else if (kv !== e.ver) {
          ups.push(this.upd(e)); p.known.set(e.id, e.ver);
        }
      }
      for (const id of p.known.keys()) if (!seen.has(id)) { rms.push(id); p.known.delete(id); p.knownVis.delete(id); }
      if (adds.length || ups.length || rms.length) this.send(p, { t: 'v', a: adds, u: ups, r: rms });
      if (p.selfDirty) { p.selfDirty = false; this.send(p, this.meMsg(p)); }
      if (p.invDirty) { p.invDirty = false; this.send(p, { t: 'inv', inv: p.ch.inv, eq: p.ch.equip }); }
    }
  }

  // ------------------------------------------------------------ ciclo
  tick(dt, t) {
    this.regenAcc += dt;
    const regen = this.regenAcc >= 1;
    if (regen) this.regenAcc -= 1;
    for (const p of this.players) this.updatePlayer(p, t, regen);
    for (const e of [...this.ents.values()]) {
      if (e.kind === 'mob') this.updateMob(e, dt, t);
      else if (e.kind === 'drop' && t > e.expire) this.remove(e);
    }
    for (const sp of this.spawners) {
      for (let i = sp.pending.length - 1; i >= 0; i--) {
        if (sp.pending[i] <= t) { sp.pending.splice(i, 1); this.spawnFromSpawner(sp); }
      }
    }
  }

  updatePlayer(p, t, regen) {
    if (p.dead) return;
    const before = p.buffs.length;
    p.buffs = p.buffs.filter(b => b.until > t);
    if (p.buffs.length !== before) this.recalc(p);
    this.tickDots(p, t);
    if (p.dead) return;
    for (const h of p.hots) {
      if (t >= h.next && h.next <= h.until) { h.next += 1000; this.heal(p, h.amt, true); }
    }
    p.hots = p.hots.filter(h => h.next <= h.until);
    if (regen && (p.hp < p.maxHp || p.mp < p.maxMp)) {
      const fight = t - p.lastCombat < 6000;
      p.hp = Math.min(p.maxHp, p.hp + p.maxHp * (fight ? 0.004 : 0.02) + p.maxHp * p.hpRegen / 100);
      p.mp = Math.min(p.maxMp, p.mp + p.maxMp * (fight ? 0.01 : 0.03));
      p.selfDirty = true; this.touch(p);
    }
  }

  tickDots(e, t) {
    if (!e.dots.length) return;
    for (const d of e.dots) {
      if (t >= d.next && d.next <= d.until) {
        d.next += 1000;
        const src = this.ents.get(d.src) || { kind: 'env', id: 0, name: 'Veleno', x: e.x, z: e.z };
        this.fx(e, { k: 'hit', s: src.id, d: e.id, v: d.dmg, dot: 1 });
        this.applyDamage(e, d.dmg, src);
        if ((e.kind === 'mob' && e.hp <= 0) || e.dead) break;
      }
    }
    e.dots = e.dots.filter(d => d.next <= d.until);
  }

  // ------------------------------------------------------------ IA dei mostri
  validMobTarget(p) {
    return p && p.kind === 'player' && p.online && !p.dead && !safeZoneAt(p.x, p.z) && !p.hidden;
  }

  moveToward(m, tx, tz, step, stopDist) {
    const dx = tx - m.x, dz = tz - m.z, d = Math.hypot(dx, dz);
    if (d <= stopDist) return true;
    const s = Math.min(step, d - stopDist);
    m.x += dx / d * s; m.z += dz / d * s; m.r = Math.atan2(dx, dz);
    this.touch(m);
    return false;
  }

  updateMob(m, dt, t) {
    if (m.hp <= 0) { if (t >= m.removeAt) this.remove(m); return; }
    this.tickDots(m, t);
    if (m.hp <= 0) return;
    const d = m.d;
    if (d.stone) {
      if (m.aggro.size && t - m.lastActive > 30000) { m.aggro.clear(); m.hp = m.maxHp; m.waveIdx = 0; this.touch(m); }
      return;
    }
    if (m.temp && !m.target && t - m.lastActive > 60000) { this.remove(m); return; }
    if (m.stunUntil > t) return;
    const spd = d.speed * (m.slowUntil > t ? 0.5 : 1);
    let tgt = m.target ? this.ents.get(m.target) : null;
    if (m.target && !this.validMobTarget(tgt)) { m.aggro.delete(m.target); m.target = null; tgt = null; }
    if (!tgt && m.state !== 'return') {
      let best = null, bv = -1;
      for (const [pid, v] of m.aggro) {
        const p = this.ents.get(pid);
        if (!this.validMobTarget(p) || dist(p, m) > 45) { m.aggro.delete(pid); continue; }
        if (v > bv) { bv = v; best = p; }
      }
      if (!best && d.aggro > 0) {
        for (const p of this.players) {
          if (!this.validMobTarget(p)) continue;
          const dd = dist(p, m);
          if (dd < d.aggro && (!best || dd < dist(best, m))) best = p;
        }
      }
      if (best) { tgt = best; m.target = best.id; }
    }
    if (tgt) {
      m.lastActive = t;
      const leash = m.temp ? 70 : (d.boss ? 42 : 34);
      if (dist(m, m.spawn) > leash) {
        m.state = 'return'; m.target = null; m.aggro.clear();
      } else {
        const dd = dist(m, tgt);
        const reach = (d.range || 2.2) + this.radiusOf(m) * 0.5 + 0.4;
        if (dd > reach) this.moveToward(m, tgt.x, tgt.z, spd * dt, reach * 0.85);
        else {
          const nr = Math.atan2(tgt.x - m.x, tgt.z - m.z);
          if (Math.abs(nr - m.r) > 0.05) { m.r = nr; this.touch(m); }
          if (t >= m.nextAttack) { m.nextAttack = t + d.aspd; this.mobAttack(m, tgt); }
        }
        if (d.boss) this.bossLogic(m, t);
        return;
      }
    }
    if (m.state === 'return') {
      this.moveToward(m, m.spawn.x, m.spawn.z, spd * 1.7 * dt, 0.5);
      if (m.hp < m.maxHp) { m.hp = Math.min(m.maxHp, m.hp + m.maxHp * 0.25 * dt); this.touch(m); }
      if (dist(m, m.spawn) < 1) { m.state = 'idle'; m.hp = m.maxHp; m.summoned = 0; this.touch(m); }
      return;
    }
    if (m.dest) {
      if (this.moveToward(m, m.dest.x, m.dest.z, spd * 0.4 * dt, 0.3)) m.dest = null;
    } else if (t > m.wanderAt) {
      m.wanderAt = t + rand(4000, 11000);
      const a = Math.random() * Math.PI * 2, r = Math.random() * 7;
      const nx = m.spawn.x + Math.cos(a) * r, nz = m.spawn.z + Math.sin(a) * r;
      if (heightAt(nx, nz) > 0.2 && !safeZoneAt(nx, nz)) m.dest = { x: nx, z: nz };
    }
  }

  mobAttack(m, tgt) {
    this.hit(m, tgt, m.atk, { auto: m.d.ranged ? (m.d.magic ? 3 : 2) : 1 });
  }

  bossLogic(m, t) {
    if (!m.slamAt) m.slamAt = t + 8000;
    if (t >= m.slamAt) {
      m.slamAt = t + 9000;
      this.fx(m, { k: 'slam', s: m.id, x: r1(m.x), z: r1(m.z), r: 7 });
      for (const p of this.players) {
        if (this.validMobTarget(p) && dist(p, m) < 7) this.hit(m, p, m.atk * 1.5, {});
      }
    }
    const pct = m.hp / m.maxHp;
    const want = pct < 0.3 ? 2 : pct < 0.6 ? 1 : 0;
    if ((m.summoned || 0) < want) {
      m.summoned = want;
      this.fx(m, { k: 'wave', s: m.id });
      for (let i = 0; i < 3; i++) {
        const a = Math.random() * Math.PI * 2;
        const s = this.spawnMob('terracotta', m.x + Math.cos(a) * 4, m.z + Math.sin(a) * 4, null, true);
        s.target = m.target;
      }
    }
  }

  stoneWaves(m, src) {
    const th = [0.8, 0.6, 0.4, 0.2];
    m.lastActive = NOW();
    while (m.waveIdx < th.length && m.hp / m.maxHp < th[m.waveIdx]) {
      m.waveIdx++;
      this.fx(m, { k: 'wave', s: m.id });
      for (let i = 0; i < m.d.wave; i++) {
        const a = Math.random() * Math.PI * 2;
        const ty = m.d.waves[randi(0, m.d.waves.length - 1)];
        const s = this.spawnMob(ty, m.x + Math.cos(a) * 5, m.z + Math.sin(a) * 5, null, true);
        if (src.kind === 'player') { s.target = src.id; s.aggro.set(src.id, 1); }
      }
    }
  }

  // ------------------------------------------------------------ combattimento
  canAttack(a, b) {
    if (!b || b === a) return false;
    if (b.kind === 'mob') return b.hp > 0;
    if (b.kind === 'player') {
      if (!this.cfg.pvp || b.dead || a.kingdom === b.kingdom) return false;
      if (a.lvl < this.cfg.pvpMinLevel || b.lvl < this.cfg.pvpMinLevel) return false;
      if (safeZoneAt(a.x, a.z) || safeZoneAt(b.x, b.z)) return false;
      return true;
    }
    return false;
  }

  calcDamage(base, def, mult) {
    return Math.max(1, Math.round(base * mult * rand(0.9, 1.1) * 60 / (60 + def)));
  }

  hit(src, tgt, base, opts = {}) {
    let mult = 1, crit = false;
    if (src.kind === 'player' && Math.random() * 100 < src.crit) { crit = true; mult = 1.6; }
    if (src.kind === 'player' && tgt.kind === 'player') mult *= 0.6;
    const ev = { k: 'hit', s: src.id, d: tgt.id };
    if (opts.auto) ev.a = opts.auto;
    if (opts.i) ev.i = opts.i;
    if (tgt.kind === 'player' && Math.random() * 100 < tgt.evade) {
      this.fx(tgt, { ...ev, v: 0, miss: 1 });
      return;
    }
    const dmg = this.calcDamage(base, tgt.def, mult);
    ev.v = dmg;
    if (crit) ev.c = 1;
    this.fx(tgt, ev);
    this.applyDamage(tgt, dmg, src);
  }

  applyDamage(tgt, dmg, src) {
    if (tgt.kind === 'mob') {
      if (tgt.hp <= 0) return;
      tgt.hp = Math.max(0, tgt.hp - dmg);
      this.touch(tgt);
      tgt.lastActive = NOW();
      if (src.kind === 'player') {
        tgt.aggro.set(src.id, (tgt.aggro.get(src.id) || 0) + dmg);
        if (!tgt.target && tgt.state !== 'return') tgt.target = src.id;
        src.lastCombat = NOW();
      }
      if (tgt.d.stone && tgt.hp > 0) this.stoneWaves(tgt, src);
      if (tgt.hp <= 0) this.mobDie(tgt, src);
    } else if (tgt.kind === 'player') {
      if (tgt.dead) return;
      tgt.hp = Math.max(0, tgt.hp - dmg);
      tgt.lastCombat = NOW();
      tgt.selfDirty = true;
      this.touch(tgt);
      if (src.kind === 'player') src.lastCombat = NOW();
      if (tgt.hp <= 0) this.playerDie(tgt, src);
    }
  }

  heal(q, amt, quiet) {
    if (q.dead) return;
    const before = q.hp;
    q.hp = Math.min(q.maxHp, q.hp + amt);
    const v = Math.round(q.hp - before);
    q.selfDirty = true; this.touch(q);
    if (v > 0 && !quiet) this.fx(q, { k: 'heal', d: q.id, v });
    else if (v > 0) this.send(q, { t: 'fx', k: 'heal', d: q.id, v, q: 1 });
  }

  stun(e, sec) {
    const until = NOW() + sec * 1000;
    if (e.d && (e.d.boss || e.d.stone)) return;
    e.stunUntil = Math.max(e.stunUntil || 0, until);
    if (e.kind === 'player') this.send(e, { t: 'st', stun: Math.round(sec * 1000) });
    this.fx(e, { k: 'stun', d: e.id, ms: Math.round(sec * 1000) });
  }

  slow(e, sec) {
    e.slowUntil = Math.max(e.slowUntil || 0, NOW() + sec * 1000);
    if (e.kind === 'player') this.send(e, { t: 'st', slow: Math.round(sec * 1000) });
  }

  mobDie(m, killer) {
    m.hp = 0; m.removeAt = NOW() + 2500; this.touch(m);
    this.fx(m, { k: 'die', d: m.id });
    const d = m.d;
    let total = 0;
    for (const v of m.aggro.values()) total += v;
    let top = null, tv = -1;
    for (const [pid, v] of m.aggro) {
      const p = this.ents.get(pid);
      if (!p || p.kind !== 'player' || p.dead || dist(p, m) > 80) continue;
      const exp = Math.max(1, Math.round(d.exp * (total > 0 ? v / total : 1) * expMod(p.lvl, d.lvl) * this.cfg.rates.exp));
      this.gainExp(p, exp);
      if (v > tv) { tv = v; top = p; }
    }
    if (!top && killer && killer.kind === 'player') top = killer;
    if (top && d.tael) {
      const amt = Math.round(randi(d.tael[0], d.tael[1]) * this.cfg.rates.tael);
      top.ch.tael += amt; top.selfDirty = true;
      this.send(top, { t: 'gain', tael: amt });
    }
    for (const [id, ch, mn = 1, mx = 1] of d.drops || []) {
      if (Math.random() < ch * this.cfg.rates.drop) this.spawnDrop(id, randi(mn, mx), m.x, m.z, top ? top.id : 0);
    }
    if (m.spawner) m.spawner.pending.push(NOW() + d.respawn * 1000 * rand(0.9, 1.15));
    if (d.boss) this.broadcast({ t: 'notice', m: `${top ? top.name : 'Un eroe'} ha sconfitto ${d.name}!` });
    m.aggro.clear(); m.target = null; m.dots = [];
  }

  gainExp(p, amt) {
    if (p.lvl >= MAX_LEVEL) return;
    p.ch.exp += amt;
    this.send(p, { t: 'gain', exp: amt });
    let up = false;
    while (p.lvl < MAX_LEVEL && p.ch.exp >= expToNext(p.lvl)) {
      p.ch.exp -= expToNext(p.lvl);
      p.lvl++; p.ch.lvl = p.lvl;
      p.ch.statPts += 3; p.ch.skillPts += 1;
      up = true;
    }
    if (up) {
      this.recalc(p);
      p.hp = p.maxHp; p.mp = p.maxMp;
      this.touch(p);
      this.fx(p, { k: 'lvl', s: p.id });
      this.send(p, { t: 'notice', m: `Sei salito al livello ${p.lvl}!` });
      if (p.lvl >= VIA_LEVEL && !p.ch.via) this.sys(p, 'Hai raggiunto il livello 5: scegli la tua Via nella finestra Abilità (tasto K).');
    }
    p.selfDirty = true;
  }

  playerDie(p, killer) {
    p.dead = true; p.hp = 0; p.deadAt = NOW();
    p.buffs = []; p.hots = []; p.dots = [];
    this.recalc(p);
    this.touch(p); p.selfDirty = true;
    let lost = 0;
    if (killer.kind === 'mob') {
      lost = Math.min(p.ch.exp, Math.floor(expToNext(p.lvl) * 0.03));
      p.ch.exp -= lost;
    } else if (killer.kind === 'player') {
      this.broadcast({ t: 'sys', m: `${killer.name} (${KINGDOMS[killer.kingdom].short}) ha sconfitto ${p.name} (${KINGDOMS[p.kingdom].short}).` });
    }
    this.fx(p, { k: 'die', d: p.id });
    this.send(p, { t: 'dead', by: killer.name || 'sconosciuto', lost });
  }

  respawn(p, mode) {
    if (!p.dead) return;
    const el = NOW() - p.deadAt;
    if (mode === 'here') {
      if (el < 8000) return;
      p.hp = Math.round(p.maxHp * 0.5); p.mp = Math.round(p.maxMp * 0.5);
    } else {
      if (el < 3000) return;
      const sp = villageSpawn(p.kingdom);
      p.x = sp.x; p.z = sp.z; p.hp = p.maxHp; p.mp = p.maxMp;
    }
    p.dead = false; p.lastCombat = 0;
    this.touch(p); p.selfDirty = true;
    this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z), alive: 1 });
  }

  teleport(p, x, z) {
    p.x = clamp(x, -PLAY_LIMIT, PLAY_LIMIT); p.z = clamp(z, -PLAY_LIMIT, PLAY_LIMIT);
    this.touch(p);
    this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z) });
  }

  // ------------------------------------------------------------ azioni del giocatore
  handle(p, msg) {
    switch (msg.t) {
      case 'move': return this.onMove(p, msg);
      case 'atk': return this.onAttack(p, msg.id);
      case 'skill': return this.onSkill(p, msg.s, msg.id);
      case 'chat': return this.onChat(p, msg.m);
      case 'pick': return this.onPickup(p, msg.id);
      case 'use': return this.onUse(p, msg.i | 0);
      case 'mv': return this.onMoveItem(p, msg.a, msg.b);
      case 'drop': return this.onDropItem(p, msg.i | 0);
      case 'stat': return this.onStat(p, msg.s);
      case 'skup': return this.onSkillUp(p, msg.s);
      case 'via': return this.onVia(p, msg.v);
      case 'qb': return this.onQuickbar(p, msg.i | 0, msg.v);
      case 'npc': return this.onNpc(p, msg.id);
      case 'buy': return this.onBuy(p, msg.npc, msg.it, msg.n | 0);
      case 'sell': return this.onSell(p, msg.npc, msg.i | 0);
      case 'up': return this.onUpgrade(p, msg.npc, msg.i | 0, !!msg.seal);
      case 'respawn': return this.respawn(p, msg.mode);
    }
  }

  onMove(p, msg) {
    if (p.dead) return;
    const t = NOW();
    const x = +msg.x, z = +msg.z;
    if (!Number.isFinite(x) || !Number.isFinite(z)) return;
    const dt = Math.min(1.5, (t - p.lastMoveAt) / 1000);
    p.lastMoveAt = t;
    if (p.stunUntil > t) { this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z) }); return; }
    const maxD = p.speed * Math.max(dt, 0.12) * 1.6 + 1.2;
    if (Math.hypot(x - p.x, z - p.z) > maxD) { this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z) }); return; }
    p.x = clamp(x, -PLAY_LIMIT, PLAY_LIMIT); p.z = clamp(z, -PLAY_LIMIT, PLAY_LIMIT);
    if (Number.isFinite(+msg.r)) p.r = +msg.r;
    this.touch(p);
  }

  onAttack(p, id) {
    if (p.dead) return;
    const t = NOW();
    if (p.stunUntil > t) return;
    const e = this.ents.get(id);
    if (!this.canAttack(p, e)) return;
    if (t < p.nextAttack - 150) return;
    if (dist(p, e) > p.range + 2 + this.radiusOf(e)) return;
    p.nextAttack = t + p.aspd;
    p.lastCombat = t;
    const base = CLASSES[p.cls].autoMagic ? p.matk * 0.8 : p.atk;
    const wt = p.ch.equip.weapon ? ITEMS[p.ch.equip.weapon.id].wt : 'fists';
    this.hit(p, e, base, { auto: wt === 'bow' ? 2 : wt === 'staff' ? 3 : 1 });
  }

  onSkill(p, sid, tid) {
    if (p.dead) return;
    const t = NOW();
    if (p.stunUntil > t) return this.err(p, 'Sei stordito!');
    const sk = SKILLS[sid];
    if (!sk || sk.cls !== p.cls) return;
    const lvl = p.ch.skills[sid] || 0;
    if (lvl <= 0) return this.err(p, 'Non conosci ancora questa abilità');
    if (sk.via && sk.via !== p.ch.via) return;
    if ((p.cds[sid] || 0) > t + 200) return this.err(p, 'Abilità in ricarica');
    const cost = skillMp(sk, lvl);
    if (p.mp < cost) return this.err(p, 'Chi insufficiente');
    if (sk.req) {
      const w = p.ch.equip.weapon;
      if (!w || ITEMS[w.id].wt !== sk.req) return this.err(p, sk.req === 'bow' ? 'Serve un arco equipaggiato' : 'Servono dei pugnali equipaggiati');
    }
    const range = sk.range === 'weapon' ? p.range : (sk.range || 0);
    const target = tid ? this.ents.get(tid) : null;
    const base = sk.dmg === 'magic' ? p.matk : sk.dmg === 'hybrid' ? (p.atk + p.matk) * 0.55 : p.atk;
    const mult = sk.mult ? skillVal(sk.mult, lvl) : 0;
    const hostilesAround = (cx, cz, rad) => {
      const out = [];
      for (const e of this.ents.values()) {
        if ((e.kind === 'mob' || e.kind === 'player') && this.canAttack(p, e) && Math.hypot(e.x - cx, e.z - cz) <= rad + this.radiusOf(e)) out.push(e);
      }
      return out;
    };
    const friendlyTarget = () => (target && target.kind === 'player' && target.kingdom === p.kingdom && !target.dead && dist(target, p) <= range + 2) ? target : p;
    const fxd = { k: 'sk', s: p.id, sk: sid };
    let offensive = false;
    switch (sk.type) {
      case 'strike': {
        if (!this.canAttack(p, target)) return this.err(p, 'Nessun bersaglio valido');
        if (dist(p, target) > range + 2 + this.radiusOf(target)) return this.err(p, 'Bersaglio troppo lontano');
        if (sk.dash) {
          const ang = Math.atan2(target.x - p.x, target.z - p.z);
          const off = this.radiusOf(target) + 1.1;
          const sgn = sk.behind ? 1 : -1;
          p.x = clamp(target.x + Math.sin(ang) * off * sgn, -PLAY_LIMIT, PLAY_LIMIT);
          p.z = clamp(target.z + Math.cos(ang) * off * sgn, -PLAY_LIMIT, PLAY_LIMIT);
          p.r = Math.atan2(target.x - p.x, target.z - p.z);
          this.touch(p);
          this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z), r: r2(p.r) });
        }
        const hits = sk.hits || 1;
        for (let i = 0; i < hits; i++) if (this.canAttack(p, target)) this.hit(p, target, base * mult, { i });
        if (this.canAttack(p, target)) {
          if (sk.stun) this.stun(target, skillVal(sk.stun, lvl));
          if (sk.dot) target.dots.push({ src: p.id, dmg: Math.max(1, Math.round(base * skillVal(sk.dot.mult, lvl) * 60 / (60 + target.def))), until: t + sk.dot.dur * 1000, next: t + 1000 });
        }
        fxd.d = target.id; offensive = true;
        break;
      }
      case 'aoe_self': {
        for (const e of hostilesAround(p.x, p.z, sk.radius)) {
          this.hit(p, e, base * mult);
          if (this.canAttack(p, e)) {
            if (sk.stun) this.stun(e, skillVal(sk.stun, lvl));
            if (sk.slow) this.slow(e, sk.slow.dur);
          }
        }
        fxd.x = r1(p.x); fxd.z = r1(p.z); offensive = true;
        break;
      }
      case 'aoe_target': {
        if (!this.canAttack(p, target)) return this.err(p, 'Nessun bersaglio valido');
        if (dist(p, target) > range + 2 + this.radiusOf(target)) return this.err(p, 'Bersaglio troppo lontano');
        const cx = target.x, cz = target.z;
        for (const e of hostilesAround(cx, cz, sk.radius)) this.hit(p, e, base * mult);
        fxd.d = target.id; fxd.x = r1(cx); fxd.z = r1(cz); offensive = true;
        break;
      }
      case 'buff_self': this.addBuff(p, sid, sk, lvl); break;
      case 'buff_allies': {
        for (const q of this.players) {
          if (q.kingdom === p.kingdom && !q.dead && dist(q, p) <= sk.radius) {
            this.addBuff(q, sid, sk, lvl);
            if (q !== p) this.fx(q, { k: 'sk', s: q.id, sk: sid, ally: 1 });
          }
        }
        break;
      }
      case 'heal_self': this.heal(p, p.maxHp * skillVal(sk.heal, lvl)); break;
      case 'heal_target': {
        const q = friendlyTarget();
        this.heal(q, p.matk * skillVal(sk.heal, lvl) + 40);
        fxd.d = q.id;
        break;
      }
      case 'hot_self': p.hots.push({ amt: p.maxHp * skillVal(sk.heal, lvl), until: t + sk.dur * 1000, next: t + 1000 }); break;
      case 'hot_target': {
        const q = friendlyTarget();
        q.hots.push({ amt: q.maxHp * skillVal(sk.heal, lvl), until: t + sk.dur * 1000, next: t + 1000 });
        fxd.d = q.id;
        break;
      }
    }
    p.mp -= cost;
    p.cds[sid] = t + sk.cd * 1000;
    if (offensive) p.lastCombat = t;
    p.selfDirty = true; this.touch(p);
    this.send(p, { t: 'cd', s: sid, ms: sk.cd * 1000 });
    this.fx(p, fxd);
  }

  addBuff(p, sid, sk, lvl) {
    const stats = {};
    for (const k in sk.buff) stats[k] = Math.round(skillVal(sk.buff[k], lvl) * 10) / 10;
    p.buffs = p.buffs.filter(b => b.sid !== sid);
    p.buffs.push({ sid, stats, until: NOW() + sk.dur * 1000 });
    this.recalc(p);
  }

  // ------------------------------------------------------------ chat e comandi
  onChat(p, raw) {
    const msg = String(raw || '').replace(/[\u0000-\u001f]/g, '').slice(0, 200).trim();
    if (!msg) return;
    if (msg[0] === '/') return this.command(p, msg);
    if (msg[0] === '!') {
      const m = msg.slice(1).trim();
      if (!m) return;
      for (const q of this.players) if (q.kingdom === p.kingdom) this.send(q, { t: 'chat', ch: 'shout', n: p.name, kd: p.kingdom, m });
      return;
    }
    if (msg[0] === '@') {
      const sp = msg.indexOf(' ');
      if (sp < 0) return;
      const name = msg.slice(1, sp).toLowerCase(), m = msg.slice(sp + 1).trim();
      const q = [...this.players].find(x => x.name.toLowerCase() === name);
      if (!q) return this.sys(p, 'Giocatore non trovato o non in linea.');
      this.send(q, { t: 'chat', ch: 'wh', n: p.name, m });
      this.send(p, { t: 'chat', ch: 'wh', n: p.name, to: q.name, m });
      return;
    }
    for (const q of this.players) if (dist(q, p) < 50) this.send(q, { t: 'chat', ch: 'say', id: p.id, n: p.name, kd: p.kingdom, m: msg });
  }

  command(p, line) {
    const [cmdRaw, ...a] = line.slice(1).split(/\s+/);
    const c = (cmdRaw || '').toLowerCase();
    const sys = m => this.sys(p, m);
    switch (c) {
      case 'aiuto': case 'help':
        sys('Comandi: /online, /pos, /aiuto. Chat: !testo = grido al regno, @nome testo = sussurro.');
        if (p.gm) sys('GM: /item id [n] [+liv], /level n, /exp n, /tael n, /tp x z | /tp nome | /tp fenice|tigre|drago, /spawn mostro [n], /heal, /rate exp|drop|tael valore, /items, /mobs, /save, /annuncio testo');
        return;
      case 'online': return sys(`In linea (${this.players.size}): ${[...this.players].map(q => `${q.name} [${q.lvl}]`).join(', ')}`);
      case 'pos': return sys(`Posizione: ${Math.round(p.x)}, ${Math.round(p.z)}`);
    }
    if (!p.gm) return sys('Comando sconosciuto. Scrivi /aiuto');
    switch (c) {
      case 'item': {
        const id = a[0];
        if (!ITEMS[id]) return sys('Oggetto inesistente. Scrivi /items per la lista.');
        const n = clamp(parseInt(a[1], 10) || 1, 1, STACK_MAX), up = clamp(parseInt(a[2], 10) || 0, 0, UPGRADE.max);
        const left = this.addItem(p, id, n, up);
        return sys(left ? 'Inventario pieno.' : `Ricevuto: ${ITEMS[id].name} x${n}${up ? ' +' + up : ''}`);
      }
      case 'level': {
        const L = clamp(parseInt(a[0], 10) || 1, 1, MAX_LEVEL), diff = L - p.lvl;
        p.lvl = L; p.ch.lvl = L; p.ch.exp = 0;
        if (diff > 0) { p.ch.statPts += diff * 3; p.ch.skillPts += diff; }
        this.recalc(p); p.hp = p.maxHp; p.mp = p.maxMp; this.touch(p);
        return sys(`Livello impostato a ${L}.`);
      }
      case 'exp': return this.gainExp(p, Math.max(0, parseInt(a[0], 10) || 0));
      case 'tael': p.ch.tael = Math.max(0, p.ch.tael + (parseInt(a[0], 10) || 0)); p.selfDirty = true; return;
      case 'tp': {
        if (a.length >= 2 && !isNaN(+a[0]) && !isNaN(+a[1])) return this.teleport(p, +a[0], +a[1]);
        if (KINGDOMS[a[0]]) { const s = villageSpawn(a[0]); return this.teleport(p, s.x, s.z); }
        const q = [...this.players].find(x => x.name.toLowerCase() === String(a[0]).toLowerCase());
        if (!q) return sys('Destinazione non trovata.');
        return this.teleport(p, q.x + 1.5, q.z);
      }
      case 'spawn': {
        const ty = a[0];
        if (!MOBS[ty]) return sys('Mostro inesistente. Scrivi /mobs per la lista.');
        const n = clamp(parseInt(a[1], 10) || 1, 1, 30);
        for (let i = 0; i < n; i++) this.spawnMob(ty, p.x + rand(-5, 5), p.z + rand(-5, 5), null, true);
        return;
      }
      case 'heal': p.hp = p.maxHp; p.mp = p.maxMp; p.selfDirty = true; this.touch(p); return;
      case 'rate': {
        const k = a[0], v = parseFloat(a[1]);
        if (!['exp', 'drop', 'tael'].includes(k) || !(v > 0)) return sys('Uso: /rate exp|drop|tael valore (es. /rate exp 2)');
        this.cfg.rates[k] = v; this.saveConfig();
        return this.broadcast({ t: 'sys', m: `Moltiplicatore ${k} impostato a x${v}.` });
      }
      case 'items': return sys(Object.keys(ITEMS).join(', '));
      case 'mobs': return sys(Object.keys(MOBS).join(', '));
      case 'save': this.saveAll(); this.db.save(); return sys('Salvataggio completato.');
      case 'annuncio': return this.broadcast({ t: 'notice', m: a.join(' ').slice(0, 120) });
    }
    sys('Comando sconosciuto. Scrivi /aiuto');
  }

  // ------------------------------------------------------------ inventario
  addItem(p, id, n = 1, up = 0) {
    const it = ITEMS[id], inv = p.ch.inv;
    if (it.stack) {
      for (let i = 0; i < INV_SIZE && n > 0; i++) {
        const s = inv[i];
        if (s && s.id === id && s.n < STACK_MAX) { const k = Math.min(n, STACK_MAX - s.n); s.n += k; n -= k; }
      }
      for (let i = 0; i < INV_SIZE && n > 0; i++) if (!inv[i]) { const k = Math.min(n, STACK_MAX); inv[i] = { id, n: k, up: 0 }; n -= k; }
    } else {
      for (let i = 0; i < INV_SIZE && n > 0; i++) if (!inv[i]) { inv[i] = { id, n: 1, up }; n--; }
    }
    p.invDirty = true;
    return n;
  }

  canAdd(p, id, n) {
    const it = ITEMS[id];
    let room = 0;
    for (const s of p.ch.inv) {
      if (!s) room += it.stack ? STACK_MAX : 1;
      else if (it.stack && s.id === id) room += STACK_MAX - s.n;
      if (room >= n) return true;
    }
    return room >= n;
  }

  countItem(p, id) { return p.ch.inv.reduce((s, x) => s + (x && x.id === id ? x.n : 0), 0); }

  takeItem(p, id, n) {
    if (this.countItem(p, id) < n) return false;
    const inv = p.ch.inv;
    for (let i = 0; i < INV_SIZE && n > 0; i++) {
      const s = inv[i];
      if (s && s.id === id) { const k = Math.min(n, s.n); s.n -= k; n -= k; if (s.n <= 0) inv[i] = null; }
    }
    p.invDirty = true;
    return true;
  }

  canEquip(p, it) {
    if (it.lvl > p.lvl) return `Serve il livello ${it.lvl}`;
    if (it.type === 'weapon' && !CLASSES[p.cls].weapons.includes(it.wt)) return 'La tua classe non può usare questa arma';
    return null;
  }

  equip(p, slot) {
    const s = p.ch.inv[slot];
    if (!s) return;
    const it = ITEMS[s.id], es = equipSlotOf(it);
    if (!es) return;
    const e = this.canEquip(p, it);
    if (e) return this.err(p, e);
    p.ch.inv[slot] = p.ch.equip[es];
    p.ch.equip[es] = s;
    this.afterEquip(p);
  }

  afterEquip(p) {
    this.recalc(p);
    p.invDirty = true; p.vis++; this.touch(p);
  }

  onMoveItem(p, a, b) {
    if (!a || !b) return;
    const inv = p.ch.inv, eq = p.ch.equip;
    const validInv = i => Number.isInteger(i) && i >= 0 && i < INV_SIZE;
    if (a.k === 'i' && b.k === 'i') {
      if (!validInv(a.i) || !validInv(b.i) || a.i === b.i) return;
      const sa = inv[a.i], sb = inv[b.i];
      if (!sa) return;
      if (sb && sa.id === sb.id && ITEMS[sa.id].stack) {
        const k = Math.min(sa.n, STACK_MAX - sb.n);
        sb.n += k; sa.n -= k;
        if (sa.n <= 0) inv[a.i] = null;
      } else { inv[a.i] = sb; inv[b.i] = sa; }
      p.invDirty = true;
    } else if (a.k === 'i' && b.k === 'e') {
      if (!validInv(a.i) || !inv[a.i]) return;
      if (equipSlotOf(ITEMS[inv[a.i].id]) !== b.i) return this.err(p, 'Questo oggetto non va in quello spazio');
      this.equip(p, a.i);
    } else if (a.k === 'e' && b.k === 'i') {
      if (!EQUIP_SLOTS.includes(a.i) || !eq[a.i] || !validInv(b.i)) return;
      const target = inv[b.i];
      if (!target) { inv[b.i] = eq[a.i]; eq[a.i] = null; this.afterEquip(p); }
      else if (equipSlotOf(ITEMS[target.id]) === a.i) this.equip(p, b.i);
      else {
        const free = inv.findIndex(x => !x);
        if (free < 0) return this.err(p, 'Inventario pieno');
        inv[free] = eq[a.i]; eq[a.i] = null; this.afterEquip(p);
      }
    }
  }

  onDropItem(p, i) {
    const s = p.ch.inv[i];
    if (!s || p.dead) return;
    p.ch.inv[i] = null;
    p.invDirty = true;
    this.add({ kind: 'drop', item: { ...s }, x: p.x + rand(-1, 1), z: p.z + rand(-1, 1), owner: 0, ownerUntil: 0, expire: NOW() + 60000 });
  }

  onPickup(p, id) {
    const d = this.ents.get(id);
    if (!d || d.kind !== 'drop' || p.dead) return;
    if (dist(d, p) > 4) return;
    if (d.owner && d.owner !== p.id && NOW() < d.ownerUntil) return this.err(p, 'Questo bottino appartiene a un altro giocatore');
    const it = ITEMS[d.item.id];
    if (!this.canAdd(p, d.item.id, d.item.n)) return this.err(p, 'Inventario pieno');
    this.addItem(p, d.item.id, d.item.n, d.item.up);
    this.remove(d);
    this.send(p, { t: 'gain', item: it.name, n: d.item.n, up: d.item.up });
  }

  onUse(p, i) {
    if (p.dead) return;
    const s = p.ch.inv[i];
    if (!s) return;
    const it = ITEMS[s.id];
    if (equipSlotOf(it)) return this.equip(p, i);
    if (it.type === 'potion') {
      if (it.hp && !it.mp && p.hp >= p.maxHp) return this.err(p, 'La vita è già al massimo');
      if (it.mp && !it.hp && p.mp >= p.maxMp) return this.err(p, 'Il chi è già al massimo');
      if (it.hp) this.heal(p, it.hp);
      if (it.mp) { p.mp = Math.min(p.maxMp, p.mp + it.mp); p.selfDirty = true; }
      s.n--; if (s.n <= 0) p.ch.inv[i] = null;
      p.invDirty = true;
      return;
    }
    if (it.type === 'scroll') {
      if (NOW() - p.lastCombat < 5000) return this.err(p, 'Non puoi usarla durante un combattimento');
      s.n--; if (s.n <= 0) p.ch.inv[i] = null;
      p.invDirty = true;
      const sp = villageSpawn(p.kingdom);
      this.fx(p, { k: 'tp', s: p.id });
      return this.teleport(p, sp.x, sp.z);
    }
    if (it.type === 'book') return this.sys(p, "I tomi si usano dalla finestra Abilità (K): premi + su un'abilità di livello 10 o superiore.");
    if (it.type === 'seal') return this.sys(p, 'Il sigillo si usa dal Fabbro, durante un potenziamento.');
    if (it.type === 'material') return this.sys(p, 'Questo oggetto si vende ai mercanti o serve al fabbro.');
  }

  onStat(p, s) {
    if (!['vit', 'str', 'dex', 'int'].includes(s)) return;
    if (p.ch.statPts <= 0) return;
    if (p.ch.stats[s] >= STAT_MAX) return this.err(p, 'Valore massimo raggiunto');
    p.ch.statPts--; p.ch.stats[s]++;
    this.recalc(p);
  }

  onSkillUp(p, sid) {
    const sk = SKILLS[sid];
    if (!sk || sk.cls !== p.cls) return;
    if (sk.via && p.ch.via !== sk.via) return this.err(p, 'Questa abilità appartiene a un\'altra Via');
    const cur = p.ch.skills[sid] || 0;
    if (cur >= SKILL_MAX) return this.err(p, 'Abilità già al livello massimo');
    if (cur < SKILL_MAX_POINTS) {
      if (p.ch.skillPts <= 0) return this.err(p, 'Nessun punto abilità disponibile');
      p.ch.skillPts--; p.ch.skills[sid] = cur + 1;
    } else {
      if (!this.takeItem(p, 'tomo_tecnica', 1)) return this.err(p, 'Serve un Tomo della Tecnica per studiare oltre il livello 10');
      if (Math.random() < BOOK_CHANCE) { p.ch.skills[sid] = cur + 1; this.sys(p, `Studio riuscito! ${sk.name} è ora al livello ${cur + 1}.`); }
      else this.sys(p, 'Lo studio non ha dato frutti: il tomo è andato perduto.');
    }
    p.selfDirty = true;
  }

  onVia(p, via) {
    if (p.ch.via) return this.err(p, 'Hai già scelto la tua Via');
    if (p.lvl < VIA_LEVEL) return this.err(p, `Potrai scegliere una Via al livello ${VIA_LEVEL}`);
    if (!VIE[via] || !CLASSES[p.cls].vie.includes(via)) return;
    p.ch.via = via; p.selfDirty = true;
    this.send(p, { t: 'notice', m: `Hai intrapreso la ${VIE[via].name}` });
  }

  onQuickbar(p, i, v) {
    if (i < 0 || i >= QB_SIZE) return;
    if (v === null) { p.ch.qb[i] = null; p.selfDirty = true; return; }
    if (!v || typeof v !== 'object') return;
    if (v.k === 's' && SKILLS[v.id] && SKILLS[v.id].cls === p.cls) p.ch.qb[i] = { k: 's', id: v.id };
    else if (v.k === 'i' && ITEMS[v.id]) p.ch.qb[i] = { k: 'i', id: v.id };
    else return;
    p.selfDirty = true;
  }

  // ------------------------------------------------------------ PNG, negozi, fabbro
  nearNpc(p, id, roles) {
    const n = this.ents.get(id);
    if (!n || n.kind !== 'npc' || dist(n, p) > 8) return null;
    if (roles && !roles.includes(n.role)) return null;
    return n;
  }

  onNpc(p, id) {
    const n = this.nearNpc(p, id);
    if (!n) return;
    if (n.role === 'armi' || n.role === 'erbe') return this.send(p, { t: 'shop', npc: n.id, role: n.role, items: SHOPS[n.role] });
    if (n.role === 'fabbro') return this.send(p, { t: 'smith', npc: n.id });
    let m;
    if (n.role === 'maestro') {
      const c = CLASSES[p.cls];
      if (p.ch.via) m = `Cammini sulla ${VIE[p.ch.via].name}. Allenati con costanza: oltre il decimo livello di un'abilità serviranno i Tomi della Tecnica.`;
      else if (p.lvl < VIA_LEVEL) m = `Giovane ${c.name}, torna da me quando avrai raggiunto il livello ${VIA_LEVEL}. Allora potrai scegliere tra ${c.vie.map(v => VIE[v].name).join(' e ')}.`;
      else m = `Sei pronto. Apri la finestra Abilità (K) e scegli tra ${c.vie.map(v => VIE[v].name).join(' e ')}. La scelta è definitiva.`;
    } else {
      m = n.kingdom === p.kingdom ? GUARD_LINES[randi(0, GUARD_LINES.length - 1)] : 'Straniero... tieni la spada nel fodero finché sei tra queste mura.';
    }
    this.send(p, { t: 'dialog', npc: n.id, n: `${n.name} — ${NPC_ROLES[n.role].title}`, m });
  }

  onBuy(p, npcId, itemId, n) {
    const npc = this.nearNpc(p, npcId, ['armi', 'erbe']);
    if (!npc || !SHOPS[npc.role].includes(itemId)) return;
    const it = ITEMS[itemId];
    n = it.stack ? clamp(n || 1, 1, STACK_MAX) : 1;
    const cost = it.price * n;
    if (p.ch.tael < cost) return this.err(p, 'Tael insufficienti');
    if (!this.canAdd(p, itemId, n)) return this.err(p, 'Inventario pieno');
    p.ch.tael -= cost;
    this.addItem(p, itemId, n);
    p.selfDirty = true;
    this.sys(p, `Acquistato: ${it.name}${n > 1 ? ' x' + n : ''} per ${cost} tael.`);
  }

  onSell(p, npcId, i) {
    const npc = this.nearNpc(p, npcId, ['armi', 'erbe']);
    const s = p.ch.inv[i];
    if (!npc || !s) return;
    const it = ITEMS[s.id];
    const val = Math.floor(it.price / 5 * (1 + (s.up || 0) * 0.5)) * s.n;
    p.ch.inv[i] = null;
    p.ch.tael += val;
    p.invDirty = true; p.selfDirty = true;
    this.sys(p, `Venduto: ${it.name}${s.n > 1 ? ' x' + s.n : ''} per ${val} tael.`);
  }

  onUpgrade(p, npcId, i, useSeal) {
    if (!this.nearNpc(p, npcId, ['fabbro'])) return;
    const s = p.ch.inv[i];
    if (!s) return;
    const it = ITEMS[s.id];
    if (!equipSlotOf(it)) return this.err(p, 'Il fabbro lavora solo armi e armature');
    if (s.up >= UPGRADE.max) return this.err(p, 'Questo oggetto è già al massimo');
    const lv = s.up, cost = UPGRADE.cost[lv], mat = UPGRADE.mats[lv];
    if (p.ch.tael < cost) return this.err(p, 'Tael insufficienti');
    if (mat && this.countItem(p, mat[0]) < mat[1]) return this.err(p, `Servono ${mat[1]}x ${ITEMS[mat[0]].name}`);
    const risky = lv >= UPGRADE.safeBelow;
    if (useSeal && this.countItem(p, 'sigillo_fabbro') < 1) useSeal = false;
    p.ch.tael -= cost;
    if (mat) this.takeItem(p, mat[0], mat[1]);
    const ok = Math.random() * 100 < UPGRADE.chance[lv];
    let destroyed = false, sealUsed = false;
    if (ok) s.up++;
    else if (risky) {
      if (useSeal) { this.takeItem(p, 'sigillo_fabbro', 1); sealUsed = true; }
      else { p.ch.inv[i] = null; destroyed = true; }
    }
    p.invDirty = true; p.selfDirty = true;
    this.send(p, { t: 'smith_res', ok, destroyed, sealUsed, up: s.up, name: it.name, i });
    if (ok && s.up >= 7) this.broadcast({ t: 'sys', m: `${p.name} ha portato ${it.name} a +${s.up}!` });
  }
}
