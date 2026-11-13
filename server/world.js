// Logica di gioco lato server: entità, combattimento, IA dei mostri, oggetti, PNG.
// Il server è autoritativo su danni, oggetti, esperienza e tael.
import {
  CLASSES, VIE, SKILLS, BUFFS, RESOURCES, ITEMS, MOBS, UPGRADE, SHOPS, NPC_ROLES, WEAPON_TYPES, GUARD_LINES,
  INV_SIZE, QB_SIZE, STACK_MAX, STAT_MAX, EQUIP_SLOTS, MAX_LEVEL, VIA_LEVEL, SKILL_MAX_POINTS, SKILL_MAX, BOOK_CHANCE,
  PTS_MAX, GCD_MS, GCD_MIN_MS, DATA_VERSION, MOUNT_SKILLS, HORSE, DUNGEON, AFFIXES, activeAffixes, weeklyAffixes, trialScale, keyChange, RARITIES, RARITY_WEIGHTS, BONUS_STATS, TIER_SCALE, GEM_TYPES,
  expToNext, skillVal, upgradedStat, equipSlotOf, SLANCIO, BONUS_RISORSA, SUPREMA,
} from '../shared/data.js';
import {
  KINGDOMS, KINGDOM_IDS, CENTER, heightAt, villageFrame, toWorld, VILLAGE_LAYOUT, safeZoneAt, villageSpawn,
  PLAY_LIMIT, mulberry32, DUNGEON_X,
} from '../shared/world.js';
import { POSTURA, posturaBase, posturaColpo } from '../shared/postura.js';

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

// ------------------------------------------------------------------ oggetti con rarità e bonus
const GEAR_BY_TIER = {};
for (const [id, it] of Object.entries(ITEMS)) {
  if (!equipSlotOf(it)) continue;
  (GEAR_BY_TIER[it.tier] || (GEAR_BY_TIER[it.tier] = [])).push(id);
}
function tierForLevel(l) { return l < 10 ? 1 : l < 20 ? 2 : l < 30 ? 3 : 4; }

export function rollRarity(source) {
  const w = RARITY_WEIGHTS[source] || RARITY_WEIGHTS.mob;
  let r = Math.random() * w.reduce((a, b) => a + b, 0);
  for (let i = 0; i < w.length; i++) { if ((r -= w[i]) <= 0) return i; }
  return 0;
}

function rollValue(stat, tier) {
  const b = BONUS_STATS[stat], s = TIER_SCALE[tier] || 1;
  const q = Math.pow(Math.random(), 1.6); // i valori alti sono più rari
  const v = (b.range[0] + (b.range[1] - b.range[0]) * q) * s;
  return b.flat ? Math.max(1, Math.round(v)) : Math.max(0.1, Math.round(v * 10) / 10);
}

function rollBonuses(slot, tier, count, exclude) {
  const pool = Object.keys(BONUS_STATS).filter(k => BONUS_STATS[k].slots.includes(slot) && !exclude.includes(k));
  for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
  return pool.slice(0, Math.max(0, count)).map(k => [k, rollValue(k, tier)]);
}

export function makeEquip(id, r = 0, up = 0) {
  const it = ITEMS[id];
  r = Math.max(0, Math.min(4, r | 0));
  return { id, n: 1, up, r, b: rollBonuses(equipSlotOf(it), it.tier || 1, RARITIES[r].bonuses, []), s: Array(RARITIES[r].sockets).fill(null), fs: 0 };
}

function normalizeEquip(s) {
  if (!s) return s;
  if (s.r === undefined) s.r = 0;
  if (!s.b) s.b = [];
  if (!s.s) s.s = [];
  if (!s.fs) s.fs = 0;
  return s;
}

export function newCharacter(name, cls, kingdom, sex = 'm') {
  const c = CLASSES[cls];
  const sp = villageSpawn(kingdom);
  const inv = Array(INV_SIZE).fill(null);
  const ch = {
    name, cls, kingdom, sex: sex === 'f' ? 'f' : 'm', lvl: 1, exp: 0, statPts: 0, skillPts: 0,
    stats: { ...c.start }, via: null, skills: {}, v: DATA_VERSION,
    inv, equip: { weapon: makeEquip(c.startWeapon), head: null, body: makeEquip('tunica_canapa'), feet: makeEquip('sandali') },
    tael: 300, x: sp.x, z: sp.z, hp: -1, mp: -1, qb: Array(QB_SIZE).fill(null), created: Date.now(),
  };
  let i = 0;
  for (const id of c.extraItems) inv[i++] = makeEquip(id);
  inv[i++] = { id: 'ginseng_p', n: 10, up: 0 };
  inv[i++] = { id: 'loto_p', n: 6, up: 0 };
  inv[i++] = { id: 'pergamena_ritorno', n: 1, up: 0 };
  defaultQuickbar(ch);
  return ch;
}

function defaultQuickbar(ch) {
  const c = CLASSES[ch.cls];
  ch.qb = Array(QB_SIZE).fill(null);
  c.baseSkills.forEach((s, i) => { if (SKILLS[s].lvl <= ch.lvl) ch.qb[i] = { k: 's', id: s }; });
  ch.qb[QB_SIZE - 2] = { k: 'i', id: 'ginseng_p' };
  ch.qb[QB_SIZE - 1] = { k: 'i', id: c.res === 'mana' ? 'loto_p' : 'pergamena_ritorno' };
}

// Adegua i personaggi creati con versioni precedenti dei dati.
function migrate(ch) {
  if (ch.horse === undefined) ch.horse = null;
  if (ch.v === DATA_VERSION) return;
  ch.skills = {};
  ch.skillPts = Math.max(0, ch.lvl - 1);
  if (ch.via && (!VIE[ch.via] || VIE[ch.via].cls !== ch.cls)) ch.via = null;
  defaultQuickbar(ch);
  ch.v = DATA_VERSION;
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
    this.parties = new Map();
    this.instances = new Map();
    this.instSlots = [];
    this.nextInst = 1;
    this.nextParty = 1;
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
      for (const [lx, lz] of VILLAGE_LAYOUT.dummies) {
        const p = toWorld(f, lx, lz);
        const m = this.spawnMob('fantoccio', p.x, p.z, null, false);
        m.r = f.a + Math.PI;
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
    // accampamenti: molti mostri deboli e vicini, ricomparsa rapida (grind ad area, ideale a cavallo)
    const camp = (cx, cz, rmin, rmax, n, type, count, filter) => {
      let made = 0, tries = 0;
      while (made < n && tries++ < 400) {
        const a = rng() * Math.PI * 2, r = rmin + rng() * (rmax - rmin);
        const x = cx + Math.cos(a) * r, z = cz + Math.sin(a) * r;
        if (!validPos(x, z) || (filter && !filter(x, z))) continue;
        this.addSpawner(type, x, z, count, 10);
        made++;
      }
    };
    for (const kid of KINGDOM_IDS) {
      const v = KINGDOMS[kid].village;
      camp(v.x, v.z, 82, 118, 2, 'lupo_branco', 12);
      camp(v.x, v.z, 132, 172, 2, 'predone', 12, farFromCenter);
    }
    camp(CENTER.x, CENTER.z, 55, 90, 3, 'soldato_terracotta', 12);
  }

  addSpawner(type, x, z, count, radius = 6) {
    const sp = { type, x, z, count, radius, pending: [] };
    this.spawners.push(sp);
    for (let i = 0; i < count; i++) this.spawnFromSpawner(sp);
  }

  spawnFromSpawner(sp) {
    let x = sp.x, z = sp.z;
    if (!MOBS[sp.type].stone && !MOBS[sp.type].boss) {
      for (let i = 0; i < 6; i++) {
        const nx = sp.x + rand(-sp.radius, sp.radius), nz = sp.z + rand(-sp.radius, sp.radius);
        if (heightAt(nx, nz) > 0.3) { x = nx; z = nz; break; }
      }
    }
    const m = this.spawnMob(sp.type, x, z, sp, false);
    if (MOBS[sp.type].boss) this.broadcast({ t: 'notice', m: `${m.name} è apparso sull'Altopiano delle Spade Spezzate!` });
    return m;
  }

  spawnMob(type, x, z, spawner, temp) {
    const d = MOBS[type];
    const pb = posturaBase(d);
    return this.add({
      postBase: pb, postMax: pb, post: pb, squil: false, squilUntil: 0, postBackAt: 0, postHitAt: 0, squilN: 0,
      kind: 'mob', type, d, name: d.name, lvl: d.lvl, x, z, r: Math.random() * Math.PI * 2,
      hp: d.hp, maxHp: d.hp, atk: d.atk, def: d.def, spawn: { x, z }, spawner, temp,
      state: 'idle', target: null, aggro: new Map(), nextAttack: 0, wanderAt: NOW() + rand(1000, 8000), dest: null,
      stunUntil: 0, slowUntil: 0, dots: [], debuffs: [], waveIdx: 0, removeAt: 0, lastActive: NOW(),
    });
  }

  spawnDrop(id, n, x, z, owner, source = 'mob') {
    const it = ITEMS[id];
    if (it.stack) return this.dropInstance({ id, n, up: 0 }, x, z, owner);
    for (let i = 0; i < n; i++) this.dropInstance(makeEquip(id, rollRarity(source)), x, z, owner);
  }

  dropInstance(inst, x, z, owner) {
    const op = owner ? this.ents.get(owner) : null;
    return this.add({
      kind: 'drop', item: inst, x: x + rand(-1.8, 1.8), z: z + rand(-1.8, 1.8),
      owner: owner || 0, ownerParty: (op && op.party) || 0, ownerUntil: NOW() + 20000, expire: NOW() + 120000,
    });
  }

  // Bottino aggiuntivo per fascia di livello: equipaggiamento casuale, gemme, modificatori, essenze.
  extraDrops(m, top) {
    const d = m.d, lv = d.lvl;
    const source = d.boss ? 'boss' : d.stone ? 'stone' : 'mob';
    const mul = this.cfg.rates.drop * (1 + ((top && top.dropPct) || 0) / 100);
    const owner = top ? top.id : 0;
    const roll = (ch) => Math.random() < ch * mul;
    const rolls = d.boss ? 3 : d.stone ? 2 : 1;
    const gearChance = d.boss ? 1 : d.stone ? 0.7 : 0.05;
    for (let i = 0; i < rolls; i++) {
      if (!roll(gearChance)) continue;
      const pool = GEAR_BY_TIER[d.boss ? 4 : tierForLevel(lv)];
      this.dropInstance(makeEquip(pool[randi(0, pool.length - 1)], rollRarity(source)), m.x, m.z, owner);
    }
    const gems = Object.keys(GEM_TYPES);
    if (roll(d.boss ? 0.8 : d.stone ? 0.45 : lv >= 5 ? 0.015 : 0)) {
      const grade = d.boss ? (Math.random() < 0.25 ? 2 : 1) : d.stone && lv >= 15 ? 1 : 0;
      this.spawnDrop(`gemma_${gems[randi(0, gems.length - 1)]}_${grade}`, 1, m.x, m.z, owner);
    }
    if (lv >= 8 && roll(d.boss ? 0.6 : d.stone ? 0.3 : 0.008)) this.spawnDrop('pietra_affinamento', d.boss ? 2 : 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.4 : d.stone ? 0.12 : lv >= 12 ? 0.002 : 0)) this.spawnDrop('pergamena_mutamento', 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.25 : d.stone && lv >= 15 ? 0.05 : 0)) this.spawnDrop('sigillo_ascensione', 1, m.x, m.z, owner);
    if (roll(d.boss ? 0.9 : d.stone && lv >= 15 ? 0.3 : lv >= 18 ? 0.01 : 0)) this.spawnDrop('essenza_celeste', d.boss ? randi(2, 4) : 1, m.x, m.z, owner);
  }

  // ------------------------------------------------------------ giocatori
  addPlayer(sess, ch) {
    migrate(ch);
    for (const s of [...ch.inv, ...Object.values(ch.equip)]) if (s && equipSlotOf(ITEMS[s.id])) normalizeEquip(s);
    const p = {
      kind: 'player', sess, ch, name: ch.name, cls: ch.cls, kingdom: ch.kingdom, lvl: ch.lvl,
      x: ch.x, z: ch.z, r: 0, hp: ch.hp, buffs: [], hots: [], dots: [], debuffs: [], cds: {},
      rtype: CLASSES[ch.cls].res, res: 0, rmax: 100, pts: 0, gcdUntil: 0, casting: null, chainIdx: 0, chainAt: 0,
      shield: 0, shieldUntil: 0, dmgPct: 0, haste: 0, mounted: false, mountUntil: 0, slancio: 0, slancioUntil: 0, sup: 0, waves: [],
      nextAttack: 0, dead: false, known: new Map(), knownVis: new Map(), stunUntil: 0, slowUntil: 0,
      lastMoveAt: NOW(), lastCombat: 0, selfDirty: true, invDirty: true, resDirty: false, gm: !!sess.gm, online: true,
    };
    this.add(p);
    this.players.add(p);
    this.recalc(p);
    const R = RESOURCES[p.rtype];
    p.res = p.rtype === 'mana' ? (ch.mp >= 0 ? Math.min(ch.mp, p.rmax) : p.rmax) : Math.round(R.start * p.rmax);
    if (!Number.isFinite(p.x) || !Number.isFinite(p.z) || p.hp === 0 || p.x > DUNGEON_X) {
      const sp = villageSpawn(p.kingdom); p.x = sp.x; p.z = sp.z; p.hp = p.maxHp;
    }
    if (p.hp < 0 || p.hp > p.maxHp) p.hp = p.maxHp;
    this.send(p, {
      t: 'enter', id: p.id, name: p.name, cls: p.cls, kd: p.kingdom, sx: ch.sex === 'f' ? 'f' : 'm', gm: p.gm ? 1 : 0, x: r1(p.x), z: r1(p.z),
      pvp: this.cfg.pvp ? 1 : 0, pvpMin: this.cfg.pvpMinLevel,
    });
    this.broadcast({ t: 'sys', m: `${p.name} (${KINGDOMS[p.kingdom].short}) è entrato nel mondo.` });
    return p;
  }

  removePlayer(p) {
    this.leaveTrial(p, true);
    this.leaveParty(p, true);
    p.online = false;
    this.saveChar(p);
    this.remove(p);
    this.players.delete(p);
    this.broadcast({ t: 'sys', m: `${p.name} ha lasciato il mondo.` });
  }

  saveChar(p) {
    const ch = p.ch;
    ch.lvl = p.lvl; ch.x = r1(p.x); ch.z = r1(p.z);
    ch.hp = p.dead ? 0 : Math.round(p.hp); ch.mp = p.rtype === 'mana' ? Math.round(p.res) : -1;
  }
  saveAll() { for (const p of this.players) this.saveChar(p); }

  buffTotals(p) {
    const out = {};
    for (const b of p.buffs) for (const k in b.stats) out[k] = (out[k] || 0) + b.stats[k];
    return out;
  }

  // Livello effettivo di un'abilità per il giocatore (0 = non disponibile).
  lvlOf(p, sid) {
    const sk = SKILLS[sid];
    if (sk && sk.mount) return p.mounted && p.ch.horse && p.ch.horse.lvl >= sk.hlvl ? Math.min(SKILL_MAX, p.ch.horse.lvl) : 0;
    if (!sk || sk.cls !== p.cls || p.lvl < sk.lvl) return 0;
    if (sk.via && sk.via !== p.ch.via) return 0;
    return Math.max(1, p.ch.skills[sid] || 0);
  }

  gcdMs(p) { return Math.max(GCD_MIN_MS, Math.round(GCD_MS / (1 + p.haste / 100))); }

  recalc(p) {
    const c = CLASSES[p.cls], s = p.ch.stats, L = p.lvl, eq = p.ch.equip;
    const pas = (p.ch.via && VIE[p.ch.via].passive) || {};
    let watk = 0, wmatk = 0, def = 0, spdPct = 0, range = 2.2, aspd = 1000;
    const rm = (s) => RARITIES[(s && s.r) || 0].mult;
    if (eq.weapon) {
      const it = ITEMS[eq.weapon.id];
      const wt = WEAPON_TYPES[it.wt];
      watk = upgradedStat(it.atk, eq.weapon.up, true) * rm(eq.weapon);
      wmatk = upgradedStat(it.matk, eq.weapon.up, true) * rm(eq.weapon);
      range = it.range || wt.range; aspd = wt.aspd;
    }
    for (const k of ['head', 'body', 'feet']) if (eq[k]) {
      const it = ITEMS[eq[k].id];
      def += upgradedStat(it.def, eq[k].up, false) * rm(eq[k]);
      spdPct += it.speed || 0;
    }
    // bonus casuali e gemme
    const g = {};
    for (const slot of EQUIP_SLOTS) {
      const s = eq[slot];
      if (!s) continue;
      for (const [k, v] of s.b || []) g[k] = (g[k] || 0) + v;
      for (const gem of s.s || []) if (gem && ITEMS[gem]) { const gi = ITEMS[gem], gt = GEM_TYPES[gi.gem]; g[gt.stat] = (g[gt.stat] || 0) + gt.vals[gi.grade]; }
    }
    for (const k in g) g[k] = Math.round(g[k] * 10) / 10;
    p.gear = g;
    const b = this.buffTotals(p);
    const prim = c.primary === 'dex' ? s.dex : s.str;
    const sec = c.primary === 'dex' ? s.str : s.dex;
    p.maxHp = Math.round((c.hp[0] + L * c.hp[1] + s.vit * c.hp[2] + (g.hp || 0)) * (1 + (pas.hpPct || 0) / 100));
    p.rmax = p.rtype === 'mana' ? Math.round(c.mp[0] + L * c.mp[1] + s.int * c.mp[2]) : RESOURCES[p.rtype].fixedMax;
    p.atk = Math.round((watk + prim * 2 + sec * 0.5 + L * 2) * (1 + ((b.atkPct || 0) + (g.atkPct || 0)) / 100));
    p.matk = Math.round((wmatk + s.int * 2.5 + L * 2) * (1 + ((b.matkPct || 0) + (g.matkPct || 0)) / 100));
    p.def = Math.round((def + (g.def || 0) + s.vit * 1.2 + L) * (1 + (b.defPct || 0) / 100));
    p.crit = Math.min(60, 2 + s.dex * 0.4 + (b.critPct || 0) + (g.crit || 0));
    p.critMult = 1.6 + (g.critDmg || 0) / 100;
    p.evade = Math.min(25, s.dex * 0.2 + (g.evade || 0));
    p.haste = (b.hastePct || 0) + (g.haste || 0) + (p.slancio || 0) * SLANCIO.hastePct;
    p.aspd = Math.round(aspd / (1 + p.haste / 100 + s.dex * 0.004));
    p.speed = 8 * (1 + (spdPct + (g.moveSpd || 0)) / 100) * (p.mounted && p.ch.horse ? HORSE.speed(p.ch.horse.lvl) : 1);
    p.monDmg = g.monDmg || 0; p.bossDmg = g.bossDmg || 0; p.aoeDmg = g.aoeDmg || 0;
    p.lifesteal = g.lifesteal || 0; p.dmgRed = Math.min(50, g.dmgRed || 0);
    p.expPct = g.expPct || 0; p.taelPct = g.taelPct || 0; p.dropPct = g.dropPct || 0;
    p.range = range;
    p.hpRegen = b.hpRegen || 0;
    p.dmgPct = b.dmgPct || 0;
    p.dmgTaken = b.dmgTaken || 0;
    p.resRegenPct = (b.resRegenPct || 0) + (g.resRegen || 0) + (p.slancio || 0) * SLANCIO.regenPct;
    p.threat = pas.threat || 1;
    p.healPct = pas.healPct || 0;
    if (p.hp > p.maxHp) p.hp = p.maxHp;
    if (p.res > p.rmax) p.res = p.rmax;
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
        return { ...base, k: 'p', n: e.name, cls: e.cls, kd: e.kingdom, sx: e.ch.sex === 'f' ? 'f' : 'm', lvl: e.lvl, hp: Math.round(e.hp), mhp: e.maxHp,
          w: eq.weapon ? eq.weapon.id : null, wu: eq.weapon ? eq.weapon.up : 0, wr: eq.weapon ? eq.weapon.r || 0 : 0,
          b: eq.body ? eq.body.id : null, bu: eq.body ? eq.body.up : 0, br: eq.body ? eq.body.r || 0 : 0, h: eq.head ? eq.head.id : null, f: eq.feet ? eq.feet.id : null,
          gm: e.gm ? 1 : 0, dead: e.dead ? 1 : 0, mt: e.mounted && e.ch.horse ? HORSE.tierOf(e.ch.horse.lvl) : 0 };
      }
      case 'mob': {
        const o = { ...base, k: 'm', ty: e.type, n: e.name, lvl: e.lvl, hp: Math.round(e.hp), mhp: e.maxHp };
        // Postura (solo élite, boss e fantoccio): po = % rimasta, sq = millisecondi di Squilibrio rimasti
        if (e.postMax) { o.po = Math.round(e.post / e.postMax * 100); if (e.squil) o.sq = Math.max(0, e.squilUntil - NOW()); }
        return o;
      }
      case 'npc': return { ...base, k: 'n', role: e.role, kd: e.kingdom, n: e.name };
      case 'drop': return { ...base, k: 'd', it: e.item.id, n: e.item.n, up: e.item.up, r: e.item.r || 0, own: e.owner, op: e.ownerParty || 0 };
    }
    return base;
  }
  upd(e) {
    const u = [e.id, r1(e.x), r1(e.z), r2(e.r || 0), Math.round(e.hp || 0), e.maxHp || 0, e.lvl || 0, e.dead ? 1 : 0];
    if (e.postMax) u.push(Math.round(e.post / e.postMax * 100), e.squil ? 1 : 0);   // Postura in % e Squilibrio
    return u;
  }

  meMsg(p) {
    const ch = p.ch, t = NOW();
    const chain = this.chainOf(p) && t - p.chainAt < 6000 ? p.chainIdx : 0;
    return {
      t: 'me', lvl: p.lvl, exp: ch.exp, need: expToNext(p.lvl), hp: Math.round(p.hp), mhp: p.maxHp,
      res: Math.floor(p.res), rmax: p.rmax, rt: p.rtype, pts: p.pts, sl: p.slancio, su: Math.floor(p.sup), chain, shield: Math.round(p.shieldUntil > t ? p.shield : 0),
      atk: p.atk, matk: p.matk, def: p.def, crit: r1(p.crit), ev: r1(p.evade), aspd: p.aspd, spd: r2(p.speed), range: p.range,
      haste: r1(p.haste), gcd: this.gcdMs(p), dmgPct: r1(p.dmgPct),
      sp: ch.statPts, kp: ch.skillPts, st: ch.stats, via: ch.via, sk: ch.skills, tael: ch.tael, qb: ch.qb,
      buffs: p.buffs.map(b => ({ b: b.id, ms: b.until - t })), dead: p.dead ? 1 : 0,
      g: p.gear, cm: r2(p.critMult),
      mounted: p.mounted ? 1 : 0, horse: p.ch.horse ? { lvl: p.ch.horse.lvl, exp: Math.floor(p.ch.horse.exp), need: HORSE.need(p.ch.horse.lvl) } : null,
    };
  }

  partyState(party) {
    return {
      t: 'party', id: party.id, leader: party.leader,
      members: party.members.map(id => this.ents.get(id)).filter(Boolean).map(q => ({
        id: q.id, n: q.name, cls: q.cls, lvl: q.lvl, hp: Math.round(q.hp), mhp: q.maxHp, res: Math.floor(q.res), rmax: q.rmax, rt: q.rtype,
        dead: q.dead ? 1 : 0, x: r1(q.x), z: r1(q.z), via: q.ch.via,
      })),
    };
  }

  netTick() {
    for (const party of this.parties.values()) {
      const st = this.partyState(party);
      const key = JSON.stringify(st);
      if (key === party.last) continue;
      party.last = key;
      for (const id of party.members) { const q = this.ents.get(id); if (q) this.send(q, st); }
    }
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
      if (p.selfDirty) { p.selfDirty = false; p.resDirty = false; this.send(p, this.meMsg(p)); }
      else if (p.resDirty) { p.resDirty = false; this.send(p, { t: 'r', hp: Math.round(p.hp), res: Math.floor(p.res), pts: p.pts, sl: p.slancio, su: Math.floor(p.sup) }); }
      if (p.invDirty) { p.invDirty = false; this.send(p, { t: 'inv', inv: p.ch.inv, eq: p.ch.equip }); }
    }
  }

  // ------------------------------------------------------------ ciclo
  tick(dt, t) {
    this.regenAcc += dt;
    const regen = this.regenAcc >= 1;
    if (regen) this.regenAcc -= 1;
    for (const p of this.players) this.updatePlayer(p, t, regen, dt);
    for (const e of [...this.ents.values()]) {
      if (e.kind === 'mob') this.updateMob(e, dt, t);
      else if (e.kind === 'drop' && t > e.expire) this.remove(e);
    }
    for (const inst of [...this.instances.values()]) this.updateTrial(inst, t, regen);
    for (const sp of this.spawners) {
      for (let i = sp.pending.length - 1; i >= 0; i--) {
        if (sp.pending[i] <= t) { sp.pending.splice(i, 1); this.spawnFromSpawner(sp); }
      }
    }
  }

  updatePlayer(p, t, regen, dt) {
    if (p.dead) return;
    const before = p.buffs.length;
    p.buffs = p.buffs.filter(b => b.until > t);
    if (p.buffs.length !== before) this.recalc(p);
    if (p.debuffs.length) p.debuffs = p.debuffs.filter(d => d.until > t);
    this.tickDots(p, t);
    if (p.dead) return;
    for (const h of p.hots) {
      if (t >= h.next && h.next <= h.until) { h.next += 1000; this.heal(p, h.amt, true); }
    }
    p.hots = p.hots.filter(h => h.next <= h.until);
    if (p.mountUntil && t >= p.mountUntil) {
      p.mountUntil = 0;
      p.mounted = true;
      this.send(p, { t: 'castend', ok: 1 });
      this.recalc(p); p.vis++; this.touch(p);
    }
    if (p.casting && t >= p.casting.until) {
      const c = p.casting;
      p.casting = null;
      this.send(p, { t: 'castend', ok: 1 });
      this.resolveSkill(p, c.sid, c.tid, 0, true);
    }
    // ondate delle Tecniche Supreme
    if (p.waves.length && p.waves[0].at <= t) {
      const due = p.waves.filter(w => w.at <= t);
      p.waves = p.waves.filter(w => w.at > t);
      for (const w of due) {
        const sk = SKILLS[w.sid], rad = sk.radius || 0;
        const list = rad ? this.hostilesAround(p, w.x, w.z, rad) : [this.ents.get(w.tid)].filter(e => this.canAttack(p, e));
        for (const e of list) for (let i = 0; i < (rad ? 1 : (sk.hits || 1)); i++) if (this.canAttack(p, e)) this.hit(p, e, w.dmg * (1 + this.vulnFrom(e, p) / 100), { sk: w.sid, aoe: rad > 0, i, post: w.post });
      }
    }
    // risorsa
    const R = RESOURCES[p.rtype], ooc = t - p.lastCombat > 6000, old = p.res;
    if (R.regen) p.res = Math.min(p.rmax, p.res + R.regen * dt * (1 + p.haste / 100) * (1 + p.resRegenPct / 100));
    if (R.decay && ooc) p.res = Math.max(0, p.res - R.decay * dt);
    if (R.regenPct) p.res = Math.min(p.rmax, p.res + p.rmax * (ooc ? R.regenPctOoc : R.regenPct) / 100 * dt);
    if (Math.floor(old) !== Math.floor(p.res)) p.resDirty = true;
    if (ooc && p.pts > 0 && t - p.lastCombat > 20000) { p.pts = 0; p.resDirty = true; }
    if (p.slancio > 0 && t > p.slancioUntil) { p.slancio--; p.slancioUntil = t + SLANCIO.decayMs; this.recalc(p); p.resDirty = true; }
    if (regen && p.hp < p.maxHp) {
      p.hp = Math.min(p.maxHp, p.hp + p.maxHp * (ooc ? 0.02 : 0.004) + p.maxHp * p.hpRegen / 100);
      p.resDirty = true; this.touch(p);
    }
  }

  tickDots(e, t) {
    if (!e.dots.length) return;
    for (const d of e.dots) {
      if (t >= d.next && d.next <= d.until) {
        d.next += d.every || 1000;
        const src = this.ents.get(d.src) || { kind: 'env', id: 0, name: 'Veleno', x: e.x, z: e.z };
        let v = d.dmg, crit = false;
        if (src.kind === 'player') {
          if (Math.random() * 100 < src.crit) { v = Math.round(v * (src.critMult || 1.6)); crit = true; }
          if (e.kind === 'mob') { v *= 1 + (src.monDmg || 0) / 100; if (e.d.boss || e.d.stone) v *= 1 + (src.bossDmg || 0) / 100; }
          v = Math.round(v);
        }
        if (e.squil) v = Math.round(v * (1 + POSTURA.vuln / 100));
        const m = this.mitigate(e, v, src);
        const ev = { k: 'hit', s: src.id, d: e.id, v: m.dmg, dot: 1, sk: d.sid };
        if (crit) ev.c = 1;
        if (m.ab) ev.ab = m.ab;
        this.fx(e, ev);
        this.applyDamage(e, m.dmg, src);
        const sk = SKILLS[d.sid];
        if (src.kind === 'player' && sk && sk.tickProc && Math.random() < sk.tickProc.chance) this.addBuff(src, sk.tickProc.buff, 1, true);
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
    if (m.debuffs.length) m.debuffs = m.debuffs.filter(x => x.until > t);
    this.tickDots(m, t);
    if (m.hp <= 0) return;
    const d = m.d;
    if (m.postMax) this.tickPostura(m, dt, t);
    if (d.dummy) {
      if (t - m.lastActive > 6000 && (m.hp < m.maxHp || m.dots.length)) { m.hp = m.maxHp; m.dots = []; m.debuffs = []; this.touch(m); }
      return;
    }
    if (d.stone) {
      if (m.aggro.size && t - m.lastActive > 30000) { m.aggro.clear(); m.hp = m.maxHp; m.waveIdx = 0; this.touch(m); }
      return;
    }
    if (m.temp && !m.target && t - m.lastActive > 60000) { this.remove(m); return; }
    if (d.explode && m.explodeAt && t >= m.explodeAt) return this.explodeLantern(m);
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
      const leash = m.inst ? 9999 : m.temp ? 70 : (d.boss ? 42 : 34);
      if (dist(m, m.spawn) > leash) {
        m.state = 'return'; m.target = null; m.aggro.clear();
      } else {
        const dd = dist(m, tgt);
        const reach = (d.range || 2.2) + this.radiusOf(m) * 0.5 + 0.4;
        if (dd > reach) this.moveToward(m, tgt.x, tgt.z, spd * dt, reach * 0.85);
        else {
          const nr = Math.atan2(tgt.x - m.x, tgt.z - m.z);
          if (Math.abs(nr - m.r) > 0.05) { m.r = nr; this.touch(m); }
          if (t >= m.nextAttack) { m.nextAttack = t + d.aspd * (m.aspdMul || 1); this.mobAttack(m, tgt); }
        }
        if (d.dungeonBoss) this.trialBossLogic(m, t);
        else if (d.boss) this.bossLogic(m, t);
        return;
      }
    }
    if (m.state === 'return') {
      this.moveToward(m, m.spawn.x, m.spawn.z, spd * 1.7 * dt, 0.5);
      if (m.hp < m.maxHp) { m.hp = Math.min(m.maxHp, m.hp + m.maxHp * 0.25 * dt); this.touch(m); }
      if (dist(m, m.spawn) < 1) { m.state = 'idle'; m.hp = m.maxHp; m.summoned = 0; m.dots = []; m.debuffs = []; this.touch(m); }
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
    let base = m.atk;
    const inst = m.inst ? this.instances.get(m.inst) : null;
    if (inst && inst.affixes.includes('furia') && m.hp / m.maxHp < 0.3) base *= 1.4;
    this.hit(m, tgt, base, { auto: m.d.ranged ? (m.d.magic ? 3 : 2) : 1 });
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
    if (src.kind === 'player') {
      if (Math.random() * 100 < src.crit) { crit = true; mult = src.critMult || 1.6; }
      if (tgt.kind === 'mob') {
        mult *= 1 + (src.monDmg || 0) / 100;
        if (tgt.d.boss || tgt.d.stone) mult *= 1 + (src.bossDmg || 0) / 100;
      }
      if (opts.aoe) mult *= 1 + (src.aoeDmg || 0) / 100;
      if (tgt.kind === 'player') mult *= 0.6;
    }
    if (tgt.squil) mult *= 1 + POSTURA.vuln / 100;   // Squilibrato: subisce più danni da chiunque
    const ev = { k: 'hit', s: src.id, d: tgt.id, sk: opts.sk || 'auto' };
    if (opts.auto) ev.a = opts.auto;
    if (opts.i) ev.i = opts.i;
    if (tgt.kind === 'player' && Math.random() * 100 < tgt.evade) {
      this.fx(tgt, { ...ev, v: 0, miss: 1 });
      return { miss: true };
    }
    const def = tgt.def * (1 - (opts.ignoreDef || 0) / 100);
    const m = this.mitigate(tgt, this.calcDamage(base, def, mult), src);
    ev.v = m.dmg;
    if (crit) ev.c = 1;
    if (m.ab) ev.ab = m.ab;
    this.fx(tgt, ev);
    this.applyDamage(tgt, m.dmg, src, opts.threat || 1);
    if (opts.post > 0 && tgt.postMax) this.colpisciPostura(tgt, opts.post);
    if (src.kind === 'player' && src.lifesteal && m.dmg > 0 && !src.dead) this.heal(src, m.dmg * src.lifesteal / 100, 'silent');
    return { crit, dmg: m.dmg };
  }

  // Riduzioni dei danni subiti (effetti difensivi e scudi).
  mitigate(tgt, dmg, src) {
    if (tgt.kind !== 'player') return { dmg };
    if (tgt.dmgTaken) dmg = Math.max(1, Math.round(dmg * (1 + tgt.dmgTaken / 100)));
    if (src && src.kind === 'mob' && tgt.dmgRed) dmg = Math.max(1, Math.round(dmg * (1 - tgt.dmgRed / 100)));
    let ab = 0;
    if (tgt.shield > 0 && tgt.shieldUntil > NOW()) {
      ab = Math.min(tgt.shield, dmg);
      tgt.shield -= ab; dmg -= ab;
      tgt.selfDirty = true;
    }
    return { dmg, ab };
  }

  applyDamage(tgt, dmg, src, threat = 1) {
    if (tgt.kind === 'mob') {
      if (tgt.hp <= 0) return;
      tgt.lastActive = NOW();
      if (tgt.d.dummy) { tgt.hp = Math.max(1, tgt.hp - dmg); this.touch(tgt); if (src.kind === 'player') src.lastCombat = NOW(); return; }
      tgt.hp = Math.max(0, tgt.hp - dmg);
      this.touch(tgt);
      if (src.kind === 'player') {
        tgt.aggro.set(src.id, (tgt.aggro.get(src.id) || 0) + dmg * threat * (src.threat || 1));
        if (!tgt.target && tgt.state !== 'return') tgt.target = src.id;
        src.lastCombat = NOW();
      }
      if (tgt.d.stone && tgt.hp > 0) this.stoneWaves(tgt, src);
      if (tgt.hp <= 0) this.mobDie(tgt, src);
    } else if (tgt.kind === 'player') {
      if (tgt.dead) return;
      tgt.hp = Math.max(0, tgt.hp - dmg);
      tgt.lastCombat = NOW();
      if (tgt.rtype === 'ira' && dmg > 0) tgt.res = Math.min(tgt.rmax, tgt.res + dmg / tgt.maxHp * 60);
      tgt.resDirty = true;
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
    if (q.kind === 'player') { q.resDirty = true; }
    this.touch(q);
    if (quiet === 'silent' || v <= 0) return;
    if (!quiet) this.fx(q, { k: 'heal', d: q.id, v });
    else this.send(q, { t: 'fx', k: 'heal', d: q.id, v, q: 1 });
  }

  stun(e, sec) {
    const until = NOW() + sec * 1000;
    if (e.d && (e.d.boss || e.d.stone || e.d.dummy)) return;
    e.stunUntil = Math.max(e.stunUntil || 0, until);
    if (e.kind === 'player') { this.send(e, { t: 'st', stun: Math.round(sec * 1000) }); if (e.casting) this.cancelCast(e); }
    this.fx(e, { k: 'stun', d: e.id, ms: Math.round(sec * 1000) });
  }

  // ------------------------------------------------------------ Postura (numeri in shared/postura.js)
  // Toglie Postura a un mostro; a zero lo Squilibra: stordito e vulnerabile, poi la Postura torna piena.
  colpisciPostura(m, punti) {
    if (m.kind !== 'mob' || !m.postMax || m.hp <= 0 || m.squilUntil) return;   // durante Squilibrio e recupero non cala
    const t = NOW();
    m.post = Math.max(0, m.post - punti);
    m.postHitAt = t;
    this.touch(m);
    if (m.post > 0) return;
    const ms = Math.round((m.d.boss ? POSTURA.durataBoss : POSTURA.durata) * 1000);
    m.squil = true; m.squilN++;
    m.squilUntil = t + ms;
    m.postBackAt = m.squilUntil + POSTURA.recupero * 1000;
    m.stunUntil = Math.max(m.stunUntil || 0, m.squilUntil);   // vale anche per boss e fantoccio, che ignorano gli stordimenti normali
    this.fx(m, { k: 'post', d: m.id, ms });
  }

  tickPostura(m, dt, t) {
    if (m.squilUntil) {
      if (m.squil && t >= m.squilUntil) { m.squil = false; this.touch(m); }
      if (t >= m.postBackAt) {
        // la tenacia alza la Postura massima a ogni Squilibrio
        m.postMax = Math.round(m.postBase * (1 + Math.min(POSTURA.tenaciaMax, m.squilN * POSTURA.tenacia)));
        m.post = m.postMax; m.squilUntil = 0; m.postBackAt = 0; m.postHitAt = t;
        this.touch(m);
      }
      return;
    }
    if (m.post < m.postMax && t - m.postHitAt > POSTURA.regenDopo * 1000) {
      const prima = Math.round(m.post / m.postMax * 100);
      m.post = Math.min(m.postMax, m.post + m.postMax * POSTURA.regenPct / 100 * dt);
      if (Math.round(m.post / m.postMax * 100) !== prima) this.touch(m);
    }
    // fuori dal combattimento da un po': la tenacia si azzera
    if (m.squilN && m.post >= m.postMax && t - m.lastActive > 20000) { m.squilN = 0; m.postMax = m.post = m.postBase; this.touch(m); }
  }

  slow(e, sec) {
    e.slowUntil = Math.max(e.slowUntil || 0, NOW() + sec * 1000);
    if (e.kind === 'player') this.send(e, { t: 'st', slow: Math.round(sec * 1000) });
  }

  mobDie(m, killer) {
    if (killer && killer.kind === 'player') this.giveRes(killer, BONUS_RISORSA.kill);
    m.hp = 0; m.removeAt = NOW() + 2500; this.touch(m);
    this.fx(m, { k: 'die', d: m.id });
    const d = m.d;
    let total = 0;
    for (const v of m.aggro.values()) total += v;
    // il danno di un gruppo conta come un'unica quota, divisa tra i membri vicini (+10% per ogni compagno)
    const shares = new Map();
    let top = null, tv = -1;
    for (const [pid, v] of m.aggro) {
      const p = this.ents.get(pid);
      if (!p || p.kind !== 'player') continue;
      if (v > tv && !p.dead) { tv = v; top = p; }
      const key = p.party ? 'g' + p.party : 'p' + p.id;
      const sh = shares.get(key) || { dmg: 0, party: p.party ? this.parties.get(p.party) : null, solo: p };
      sh.dmg += v; shares.set(key, sh);
    }
    if (!top && killer && killer.kind === 'player') top = killer;
    const near = (q) => q && q.kind === 'player' && q.online && !q.dead && dist(q, m) <= 80;
    const groupOf = (q) => {
      const party = q && q.party ? this.parties.get(q.party) : null;
      return party ? party.members.map(id => this.ents.get(id)).filter(near) : (near(q) ? [q] : []);
    };
    for (const sh of shares.values()) {
      const members = sh.party ? sh.party.members.map(id => this.ents.get(id)).filter(near) : (near(sh.solo) ? [sh.solo] : []);
      if (!members.length) continue;
      const pool = d.exp * (total > 0 ? sh.dmg / total : 1) * this.cfg.rates.exp * (1 + 0.1 * (members.length - 1));
      const maxL = Math.max(...members.map(q => q.lvl));
      for (const q of members) {
        const gap = maxL - q.lvl > 15 ? 0.2 : 1; // niente "trasporto" di personaggi molto più bassi
        const got = Math.max(1, Math.round(pool / members.length * expMod(q.lvl, d.lvl) * gap * (1 + (q.expPct || 0) / 100)));
        this.gainExp(q, got);
        if (q.mounted) this.gainHorseExp(q, pool / members.length * HORSE.expShare);
      }
    }
    if (top && d.tael) {
      const amt = Math.round(randi(d.tael[0], d.tael[1]) * this.cfg.rates.tael * (1 + (top.taelPct || 0) / 100));
      const members = groupOf(top);
      const each = Math.max(1, Math.round(amt / Math.max(1, members.length)));
      for (const q of members) { q.ch.tael += each; q.selfDirty = true; this.send(q, { t: 'gain', tael: each }); }
    }
    if (m.inst) { this.trialMobDied(m); m.aggro.clear(); m.target = null; m.dots = []; m.debuffs = []; return; }
    const source = d.boss ? 'boss' : d.stone ? 'stone' : 'mob';
    const dmul = this.cfg.rates.drop * (1 + ((top && top.dropPct) || 0) / 100);
    for (const [id, ch, mn = 1, mx = 1] of d.drops || []) {
      if (Math.random() < ch * dmul) this.spawnDrop(id, randi(mn, mx), m.x, m.z, top ? top.id : 0, source);
    }
    this.extraDrops(m, top);
    if (m.spawner) m.spawner.pending.push(NOW() + d.respawn * 1000 * rand(0.9, 1.15));
    if (d.boss) this.broadcast({ t: 'notice', m: `${top ? top.name : 'Un eroe'} ha sconfitto ${d.name}!` });
    m.aggro.clear(); m.target = null; m.dots = []; m.debuffs = [];
  }

  gainHorseExp(p, amt) {
    const h = p.ch.horse;
    if (!h || h.lvl >= HORSE.maxLevel) return;
    h.exp += amt;
    let up = false;
    while (h.lvl < HORSE.maxLevel && h.exp >= HORSE.need(h.lvl)) { h.exp -= HORSE.need(h.lvl); h.lvl++; up = true; }
    if (up) {
      const name = HORSE.names[HORSE.tierOf(h.lvl)];
      this.send(p, { t: 'notice', m: `Il tuo destriero è salito al livello ${h.lvl}!` });
      const unlocked = MOUNT_SKILLS.filter(s => SKILLS[s].hlvl === h.lvl).map(s => SKILLS[s].name);
      if (unlocked.length) this.sys(p, `Nuova tecnica a cavallo: ${unlocked.join(', ')}`);
      if (h.lvl === 10 || h.lvl === 20) this.sys(p, `Il tuo cavallo è diventato un ${name}!`);
      this.recalc(p); p.vis++; this.touch(p);
    }
    p.selfDirty = true;
  }

  // Sale o scende dal destriero (salire richiede 1,5 s fermi).
  onMount(p) {
    if (p.dead) return;
    if (p.mounted) { p.mounted = false; this.recalc(p); p.vis++; this.touch(p); return; }
    if (!p.ch.horse) return this.err(p, `Non hai un destriero: parla con lo Stalliere del villaggio (dal livello ${HORSE.minLevel})`);
    if (p.casting) this.cancelCast(p);
    p.mountUntil = NOW() + HORSE.mountMs;
    p.mountX = p.x; p.mountZ = p.z;
    this.send(p, { t: 'cast', s: '__mount', ms: HORSE.mountMs, gcd: 0 });
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
      p.hp = p.maxHp;
      if (p.rtype === 'mana') p.res = p.rmax;
      this.touch(p);
      this.fx(p, { k: 'lvl', s: p.id });
      this.send(p, { t: 'notice', m: `Sei salito al livello ${p.lvl}!` });
      if (p.lvl >= VIA_LEVEL && !p.ch.via) this.sys(p, 'Hai raggiunto il livello 5: scegli la tua Via nella finestra Abilità (tasto K).');
      this.autoQuickbar(p, true);
    }
    p.selfDirty = true;
  }

  playerDie(p, killer) {
    p.dead = true; p.hp = 0; p.deadAt = NOW();
    p.buffs = []; p.hots = []; p.dots = []; p.debuffs = []; p.casting = null; p.pts = 0; p.shield = 0;
    p.mounted = false; p.mountUntil = 0; p.vis++;
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
    if (p.inst) { const inst = this.instances.get(p.inst); if (inst && !inst.done) inst.deaths++; }
    this.send(p, { t: 'dead', by: killer.name || 'sconosciuto', lost });
  }

  respawn(p, mode) {
    if (!p.dead) return;
    const el = NOW() - p.deadAt;
    if (mode === 'here') {
      if (el < 8000) return;
      p.hp = Math.round(p.maxHp * 0.5);
      if (p.rtype === 'mana') p.res = Math.round(p.rmax * 0.5);
    } else {
      if (el < 3000) return;
      const inst = p.inst ? this.instances.get(p.inst) : null;
      const sp = inst ? { x: inst.ox + DUNGEON.spawn[0], z: inst.oz + DUNGEON.spawn[1] } : villageSpawn(p.kingdom);
      p.x = sp.x; p.z = sp.z; p.hp = p.maxHp;
      if (p.rtype === 'mana') p.res = p.rmax;
    }
    p.dead = false; p.lastCombat = 0;
    this.touch(p); p.selfDirty = true;
    this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z), alive: 1 });
  }

  clampPos(p, x, z) {
    const inst = p.inst ? this.instances.get(p.inst) : null;
    if (inst) return [clamp(x, inst.ox + DUNGEON.boundsMin[0], inst.ox + DUNGEON.boundsMax[0]), clamp(z, inst.oz + DUNGEON.boundsMin[1], inst.oz + DUNGEON.boundsMax[1])];
    return [clamp(x, -PLAY_LIMIT, PLAY_LIMIT), clamp(z, -PLAY_LIMIT, PLAY_LIMIT)];
  }

  teleport(p, x, z) {
    [p.x, p.z] = this.clampPos(p, x, z);
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
      case 'salvage': return this.onSalvage(p, msg.npc, msg.i | 0);
      case 'apply': return this.onApply(p, msg.i | 0, msg.tgt);
      case 'combine': return this.onCombine(p, msg.i | 0);
      case 'respawn': return this.respawn(p, msg.mode);
      case 'cancel': if (p.casting) this.cancelCast(p); if (p.mountUntil) { p.mountUntil = 0; this.send(p, { t: 'castend', ok: 0 }); } return;
      case 'mount': return this.onMount(p);
      case 'trial': return this.onTrial(p, msg.npc, msg.a);
      case 'tleave': return this.leaveTrial(p);
      case 'stable': return this.onStable(p, msg.npc, msg.a);
      case 'pinv': return this.onPartyInvite(p, msg.id ? this.ents.get(msg.id) : this.playerByName(msg.n));
      case 'preply': return this.onPartyReply(p, !!msg.ok);
      case 'pleave': return this.leaveParty(p);
      case 'pkick': return this.onPartyKick(p, msg.id);
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
    [p.x, p.z] = this.clampPos(p, x, z);
    if (Number.isFinite(+msg.r)) p.r = +msg.r;
    if (p.casting && Math.hypot(p.x - p.casting.x, p.z - p.casting.z) > 0.35) this.cancelCast(p);
    if (p.mountUntil && Math.hypot(p.x - p.mountX, p.z - p.mountZ) > 0.35) { p.mountUntil = 0; this.send(p, { t: 'castend', ok: 0 }); }
    this.touch(p);
  }

  // ------------------------------------------------------------ Slancio e risorsa dinamica
  gainSlancio(p) {
    const old = p.slancio;
    p.slancio = Math.min(SLANCIO.max, p.slancio + 1);
    p.slancioUntil = NOW() + SLANCIO.windowMs;
    if (p.slancio !== old) { this.recalc(p); p.resDirty = true; }
  }

  // Risorsa generata giocando: cresce con lo Slancio; per il Mana i punti valgono un quarto, in % del massimo.
  giveRes(p, amount) {
    if (!amount || p.dead) return;
    const v = amount * (1 + p.slancio * SLANCIO.genPct / 100);
    p.res = Math.min(p.rmax, p.res + (p.rtype === 'mana' ? p.rmax * v * 0.25 / 100 : v));
    p.resDirty = true;
  }

  onAttack(p, id) {
    if (p.dead) return;
    const t = NOW();
    if (p.stunUntil > t) return;
    if (p.casting && CLASSES[p.cls].autoMagic) return;
    const e = this.ents.get(id);
    if (!this.canAttack(p, e)) return;
    if (t < p.nextAttack - 150) return;
    if (dist(p, e) > p.range + 2 + this.radiusOf(e)) return;
    p.nextAttack = t + p.aspd;
    p.lastCombat = t;
    const base = (CLASSES[p.cls].autoMagic ? p.matk * 0.8 : p.atk) * (1 + p.dmgPct / 100) * (1 + this.vulnFrom(e, p) / 100);
    const wt = p.ch.equip.weapon ? ITEMS[p.ch.equip.weapon.id].wt : 'fists';
    const r = this.hit(p, e, base, { auto: wt === 'bow' ? 2 : wt === 'staff' ? 3 : 1, sk: 'auto' });
    const ar = CLASSES[p.cls].autoRes;
    if (r.miss) return;
    if (ar) this.giveRes(p, ar * p.aspd / 1000);
    if (r.crit) this.giveRes(p, BONUS_RISORSA.crit);
    this.gainSlancio(p);
  }

  // ------------------------------------------------------------ motore delle abilità
  skfail(p, sid, m) { if (m) this.err(p, m); this.send(p, { t: 'skfail', s: sid }); }

  hasBuffWith(p, key, sid) { return p.buffs.some(b => { const d = BUFFS[b.id]; return d[key] && d[key].includes(sid); }); }

  costOf(p, sk) {
    if (!sk.cost) return 0;
    if (this.hasBuffWith(p, 'free', sk.id)) return 0;
    let c = sk.cost;
    for (const b of p.buffs) { const cm = BUFFS[b.id].costMod; if (cm && cm[sk.id]) c += cm[sk.id]; }
    c = Math.max(0, c);
    return p.rtype === 'mana' ? Math.round(p.rmax * c / 100) : c;
  }

  vulnFrom(tgt, p) {
    let v = 0;
    const t = NOW();
    for (const d of tgt.debuffs || []) if (d.src === p.id && d.until > t) v += d.vuln || 0;
    return v;
  }

  isBehind(p, tgt) {
    const fx = Math.sin(tgt.r || 0), fz = Math.cos(tgt.r || 0);
    const dx = p.x - tgt.x, dz = p.z - tgt.z, l = Math.hypot(dx, dz) || 1;
    return (fx * dx + fz * dz) / l < -0.25;
  }

  hostilesAround(p, cx, cz, rad) {
    const out = [];
    for (const e of this.ents.values()) {
      if ((e.kind === 'mob' || e.kind === 'player') && this.canAttack(p, e) && Math.hypot(e.x - cx, e.z - cz) <= rad + this.radiusOf(e)) out.push(e);
    }
    return out;
  }

  friendly(p, target, range) {
    return (target && target.kind === 'player' && target.kingdom === p.kingdom && !target.dead && dist(target, p) <= range + 2) ? target : p;
  }

  // Controlla se l'abilità può partire ora; restituisce { target } oppure { err }.
  checkSkill(p, sk, lvl, tid) {
    const t = NOW();
    if (sk.req) {
      const w = p.ch.equip.weapon;
      if (!w || ITEMS[w.id].wt !== sk.req) return { err: sk.req === 'bow' ? 'Serve un arco equipaggiato' : 'Servono dei pugnali equipaggiati' };
    }
    if (this.costOf(p, sk) > p.res + 0.001) return { err: `${RESOURCES[p.rtype].name} insufficiente` };
    if (sk.sup && p.sup < SUPREMA.max) return { err: 'La Tecnica Suprema non è ancora carica' };
    if (sk.spend && sk.type !== 'heal_aoe' && p.pts < (sk.minPts || 1)) return { err: `Servono almeno ${sk.minPts || 1} ${(CLASSES[p.cls].pts || {}).name || 'punti'}` };
    const range = sk.range === 'weapon' ? p.range : (sk.range || 0);
    const target = tid ? this.ents.get(tid) : null;
    switch (sk.type) {
      case 'strike': case 'aoe_target': case 'debuff': case 'taunt': {
        if (!this.canAttack(p, target)) return { err: 'Nessun bersaglio valido' };
        if (dist(p, target) > range + 2 + this.radiusOf(target)) return { err: 'Bersaglio troppo lontano' };
        if (sk.execute && target.hp / target.maxHp > sk.execute) return { err: `Il bersaglio deve essere sotto il ${Math.round(sk.execute * 100)}% di vita` };
        if (sk.type === 'taunt' && target.kind !== 'mob') return { err: 'Puoi sfidare solo i mostri' };
        return { target };
      }
      case 'heal_target': case 'hot_target': case 'shield': case 'heal_aoe':
        return { target: this.friendly(p, target, range || 20) };
      default:
        return { target: null };
    }
  }

  onSkill(p, sid, tid) {
    const sk = SKILLS[sid];
    if (!sk || p.dead) return;
    const t = NOW();
    const lvl = this.lvlOf(p, sid);
    if (p.mounted && !sk.mount) return this.skfail(p, sid, 'Scendi da cavallo per usare le tecniche della tua classe (R)');
    if (!lvl) return this.skfail(p, sid, sk.mount ? (p.mounted ? `Il destriero deve essere di livello ${sk.hlvl}` : 'Le tecniche a cavallo si usano in sella (R)') : 'Non conosci ancora questa abilità');
    if (p.stunUntil > t) return this.skfail(p, sid, 'Sei stordito!');
    if ((p.cds[sid] || 0) > t + 150) return this.skfail(p, sid, 'Abilità in ricarica');
    if (!sk.offgcd && (p.gcdUntil > t + 150 || p.casting)) return this.skfail(p, sid);
    const chk = this.checkSkill(p, sk, lvl, tid);
    if (chk.err) return this.skfail(p, sid, chk.err);
    const gcd = sk.offgcd ? 0 : this.gcdMs(p);
    if (gcd) p.gcdUntil = t + gcd;
    const castMs = sk.cast && !this.hasBuffWith(p, 'instant', sid) ? Math.round(sk.cast * 1000 / (1 + p.haste / 100)) : 0;
    if (castMs > 0) {
      p.casting = { sid, tid, until: t + castMs, x: p.x, z: p.z };
      this.send(p, { t: 'cast', s: sid, ms: castMs, gcd });
      this.fx(p, { k: 'cast', s: p.id, sk: sid, ms: castMs });
      return;
    }
    this.resolveSkill(p, sid, tid, gcd);
  }

  cancelCast(p) {
    p.casting = null;
    p.gcdUntil = Math.min(p.gcdUntil, NOW());
    this.send(p, { t: 'castend', ok: 0 });
    this.fx(p, { k: 'castend', s: p.id });
  }

  applyDot(p, target, sk, lvl, n, base, pct) {
    const t = NOW();
    const dur = (sk.dot.durPerPt ? sk.dot.durPerPt * Math.max(1, n) : sk.dot.dur) * 1000;
    const every = sk.dot.every * 1000;
    const tick = Math.max(1, Math.round(base * skillVal(sk.dot.mult, lvl) * (1 + pct / 100) * 60 / (60 + target.def)));
    const ex = target.dots.find(d => d.src === p.id && d.sid === sk.id);
    if (ex) {
      const carry = Math.min(Math.max(0, ex.until - t), dur * 0.3);
      ex.dmg = tick; ex.until = t + dur + carry;
      this.send(p, { t: 'dot', d: target.id, s: sk.id, ms: ex.until - t });
    } else {
      target.dots.push({ src: p.id, sid: sk.id, dmg: tick, every, next: t + every, until: t + dur });
      this.send(p, { t: 'dot', d: target.id, s: sk.id, ms: dur });
    }
  }

  // lanciata: la tecnica arriva dalla fine di un tempo di lancio vero (non resa istantanea da un effetto)
  resolveSkill(p, sid, tid, gcd, lanciata = false) {
    const sk = SKILLS[sid];
    const lvl = this.lvlOf(p, sid);
    if (!sk || !lvl || p.dead) return;
    const t = NOW();
    const chk = this.checkSkill(p, sk, lvl, tid);
    if (chk.err) return this.skfail(p, sid, chk.err);
    const target = chk.target;
    // costo, punti e bonus dagli effetti attivi (calcolati prima di consumarli)
    const speso = this.costOf(p, sk);
    p.res = Math.max(0, p.res - speso);
    let n = 0;
    if (sk.spend && sk.type !== 'heal_aoe') { n = p.pts; p.pts = 0; }
    // la barra Suprema si riempie spendendo risorsa e punti; la Suprema stessa la svuota
    if (sk.sup) p.sup = 0;
    else if (p.lvl >= SUPREMA.lvl) p.sup = Math.min(SUPREMA.max, p.sup + (p.rtype === 'mana' ? speso / Math.max(1, p.rmax) * 100 * SUPREMA.perManaPct : speso * SUPREMA.perRes) + n * SUPREMA.perPt);
    let bonus = 0;
    for (const b of p.buffs) {
      const d = BUFFS[b.id];
      if (d.skillDmg && d.skillDmg[sid]) bonus += d.skillDmg[sid];
      if (sk.spend && d.spenderDmg) bonus += d.spenderDmg;
    }
    const behind = !!(sk.behind && target && (this.isBehind(p, target) || this.hasBuffWith(p, 'consume', sid) && p.buffs.some(b => BUFFS[b.id].behind)));
    // un effetto «prossimo lancio istantaneo» ottenuto mentre il lancio era già in corso resta per il lancio dopo
    p.buffs = p.buffs.filter(b => {
      const d = BUFFS[b.id];
      if (lanciata && d.instant && d.instant.includes(sid)) return true;
      return !((d.consume && d.consume.includes(sid)) || (sk.spend && d.consumeSpender));
    });
    const base = sk.dmg === 'magic' ? p.matk : sk.dmg === 'hybrid' ? (p.atk + p.matk) * 0.55 : sk.dmg === 'best' ? Math.max(p.atk, p.matk) : p.atk;
    const pctFor = (tgt) => {
      let pct = p.dmgPct + bonus + (behind ? sk.behind.dmg : 0) + this.vulnFrom(tgt, p);
      if (sk.bonusVs && tgt.dots.some(d => d.src === p.id && d.sid === sk.bonusVs.dot)) pct += sk.bonusVs.dmg;
      return pct;
    };
    const dmgFor = (tgt) => base * (sk.mult ? skillVal(sk.mult, lvl) : 0) * (sk.spend ? n : 1) * (1 + pctFor(tgt) / 100);
    const opts = { sk: sid, ignoreDef: sk.ignoreDef, threat: sk.threat };
    // Postura: la riducono solo le tecniche che spendono risorsa o punti (costo nominale in % del massimo) e le Supreme
    const costoPct = sk.cost > 0 ? (p.rtype === 'mana' ? sk.cost : sk.cost / Math.max(1, p.rmax) * 100) : 0;
    const postDi = (colpi) => posturaColpo(sk, costoPct, n, colpi);
    let crit = false, offensive = false;
    const colpiti = new Set();
    const strikeOne = (tgt, i = 0, colpi = 1) => {
      if (!sk.mult || !this.canAttack(p, tgt)) return;
      const r = this.hit(p, tgt, dmgFor(tgt), { ...opts, i, aoe: sk.type === 'aoe_self' || sk.type === 'aoe_target', post: postDi(colpi) });
      if (r.crit) crit = true;
      if (!r.miss) colpiti.add(tgt.id);
    };
    const control = (tgt) => {
      if (!this.canAttack(p, tgt)) return;
      if (sk.stun) this.stun(tgt, skillVal(sk.stun, lvl));
      if (sk.slow) this.slow(tgt, sk.slow.dur);
    };
    const fxd = { k: 'sk', s: p.id, sk: sid };
    switch (sk.type) {
      case 'strike': {
        if (sk.dash) {
          const ang = Math.atan2(target.x - p.x, target.z - p.z);
          const off = this.radiusOf(target) + 1.1, sgn = sk.behindDash ? 1 : -1;
          const from = { x: r1(p.x), z: r1(p.z) };
          p.x = clamp(target.x + Math.sin(ang) * off * sgn, -PLAY_LIMIT, PLAY_LIMIT);
          p.z = clamp(target.z + Math.cos(ang) * off * sgn, -PLAY_LIMIT, PLAY_LIMIT);
          p.r = Math.atan2(target.x - p.x, target.z - p.z);
          if (p.casting) p.casting = null;
          this.touch(p);
          this.send(p, { t: 'pos', x: r1(p.x), z: r1(p.z), r: r2(p.r) });
          fxd.fx = from.x; fxd.fz = from.z;
        }
        for (let i = 0; i < (sk.hits || 1); i++) strikeOne(target, i, sk.hits || 1);
        if (sk.splash) for (const e of this.hostilesAround(p, target.x, target.z, sk.splash)) if (e !== target) { strikeOne(e); control(e); }
        control(target);
        if (sk.dot && this.canAttack(p, target)) this.applyDot(p, target, sk, lvl, n, base, pctFor(target));
        fxd.d = target.id; offensive = true;
        break;
      }
      case 'aoe_self':
        for (const e of this.hostilesAround(p, p.x, p.z, sk.radius)) { strikeOne(e); control(e); if (sk.dot && this.canAttack(p, e)) this.applyDot(p, e, sk, lvl, n, base, pctFor(e)); }
        fxd.x = r1(p.x); fxd.z = r1(p.z); offensive = true;
        break;
      case 'aoe_target': {
        const cx = target.x, cz = target.z;
        for (const e of this.hostilesAround(p, cx, cz, sk.radius)) { strikeOne(e); control(e); if (sk.dot && this.canAttack(p, e)) this.applyDot(p, e, sk, lvl, n, base, pctFor(e)); }
        fxd.d = target.id; fxd.x = r1(cx); fxd.z = r1(cz); offensive = true;
        break;
      }
      case 'debuff': {
        const d = BUFFS[sk.debuff];
        target.debuffs = (target.debuffs || []).filter(x => !(x.id === sk.debuff && x.src === p.id));
        target.debuffs.push({ id: sk.debuff, src: p.id, until: t + d.dur * 1000, vuln: skillVal(d.vuln || 0, lvl) });
        this.send(p, { t: 'dot', d: target.id, s: sk.debuff, ms: d.dur * 1000 });
        fxd.d = target.id; offensive = true;
        break;
      }
      case 'taunt': {
        if (!target.d.dummy && !target.d.stone) {
          let max = 0;
          for (const v of target.aggro.values()) max = Math.max(max, v);
          target.aggro.set(p.id, max * 1.1 + 100);
          target.target = p.id;
          if (target.state === 'return') target.state = 'idle';
        }
        fxd.d = target.id; offensive = true;
        break;
      }
      case 'buff': this.addBuff(p, sk.buff, lvl); break;
      case 'buff_allies':
        for (const q of this.players) {
          if (q.kingdom === p.kingdom && !q.dead && dist(q, p) <= sk.radius) {
            this.addBuff(q, sk.buff, lvl);
            if (q !== p) this.fx(q, { k: 'sk', s: q.id, sk: sid, ally: 1 });
          }
        }
        break;
      case 'heal_self': this.heal(p, p.maxHp * skillVal(sk.heal, lvl)); break;
      case 'heal_target':
        this.heal(target, (p.matk * skillVal(sk.heal, lvl) + 40) * (1 + p.healPct / 100));
        fxd.d = target.id;
        break;
      case 'heal_aoe': {
        let extra = 0;
        if (sk.spendBonus && p.pts > 0) { extra = p.pts * sk.spendBonus; this.supDaPunti(p, p.pts); p.pts = 0; }
        for (const q of this.players) {
          if (q.kingdom !== p.kingdom || q.dead || dist(q, target) > sk.radius) continue;
          const amt = sk.healPct ? q.maxHp * skillVal(sk.heal, lvl) : p.matk * skillVal(sk.heal, lvl) + 40;
          this.heal(q, amt * (1 + (p.healPct + extra) / 100));
        }
        fxd.d = target.id;
        break;
      }
      case 'hot_self': p.hots.push({ amt: p.maxHp * skillVal(sk.heal, lvl), until: t + sk.dur * 1000, next: t + 1000 }); break;
      case 'hot_target':
        target.hots.push({ amt: target.maxHp * skillVal(sk.heal, lvl) * (1 + p.healPct / 100), until: t + sk.dur * 1000, next: t + 1000 });
        fxd.d = target.id;
        break;
      case 'shield': {
        let extra = 0;
        if (sk.spendBonus && p.pts > 0) { extra = p.pts * sk.spendBonus; this.supDaPunti(p, p.pts); p.pts = 0; }
        target.shield = Math.round(p.matk * skillVal(sk.shield, lvl) * (1 + (p.healPct + extra) / 100));
        target.shieldUntil = t + 15000;
        target.selfDirty = true;
        fxd.d = target.id;
        break;
      }
    }
    if (sk.waves > 1 && offensive) {
      const cx = sk.type === 'aoe_self' ? p.x : target.x, cz = sk.type === 'aoe_self' ? p.z : target.z;
      const dmg = base * skillVal(sk.mult, lvl) * (1 + (p.dmgPct + bonus) / 100);
      for (let i = 1; i < sk.waves; i++) p.waves.push({ at: t + i * sk.waveGap * 1000, sid, x: cx, z: cz, tid: target ? target.id : 0, dmg, post: postDi(sk.radius ? 1 : (sk.hits || 1)) });
    }
    // generazione di risorsa e punti, effetti su di sé
    if (sk.gen) this.giveRes(p, sk.gen);
    if (colpiti.size) {
      // più bersagli insieme e colpi critici rendono risorsa; ogni tecnica a segno alimenta lo Slancio
      if (colpiti.size > 1) this.giveRes(p, Math.min(BONUS_RISORSA.multiMax, (colpiti.size - 1) * BONUS_RISORSA.multi));
      if (crit) this.giveRes(p, BONUS_RISORSA.crit);
      this.gainSlancio(p);
    }
    if (sk.pts) p.pts = Math.min(PTS_MAX, p.pts + sk.pts + (behind ? sk.behind.pts : 0));
    if (sk.buff && sk.type === 'strike') this.addBuff(p, sk.buff, lvl);
    const viaOk = (o) => !o.via || o.via === p.ch.via;
    if (crit && sk.onCrit && viaOk(sk.onCrit)) this.addBuff(p, sk.onCrit.buff, 1);
    if (sk.proc && viaOk(sk.proc) && Math.random() < sk.proc.chance) this.addBuff(p, sk.proc.buff, 1);
    this.advanceChain(p, sid, t);
    if (sk.cd) { p.cds[sid] = t + sk.cd * 1000; }
    if (offensive) p.lastCombat = t;
    p.selfDirty = true; this.touch(p);
    this.send(p, { t: 'cd', s: sid, ms: (sk.cd || 0) * 1000, gcd: gcd ?? (sk.offgcd ? 0 : this.gcdMs(p)) });
    this.fx(p, fxd);
  }

  // Punti consumati da cure e scudi (`spendBonus`): riempiono la barra Suprema come quelli degli scarichi.
  supDaPunti(p, n) {
    if (p.lvl >= SUPREMA.lvl) p.sup = Math.min(SUPREMA.max, p.sup + n * SUPREMA.perPt);
  }

  // Monaco: Pugno → Calcio → Palmo in ordine attiva la Forma Perfetta.
  advanceChain(p, sid, t) {
    const c = CLASSES[p.cls];
    const chain = this.chainOf(p);
    if (!chain || !chain.includes(sid)) return;
    if (t - p.chainAt > 6000) p.chainIdx = 0;
    if (sid === chain[p.chainIdx]) { p.chainIdx++; p.chainAt = t; }
    else if (sid === chain[0]) { p.chainIdx = 1; p.chainAt = t; }
    else p.chainIdx = 0;
    if (p.chainIdx >= chain.length) {
      p.chainIdx = 0;
      p.pts = Math.min(PTS_MAX, p.pts + 2);
      const pr = p.ch.via && VIE[p.ch.via].passive.chainRes;
      if (pr) p.res = Math.min(p.rmax, p.res + pr);
      const ph = p.ch.via && VIE[p.ch.via].passive.chainHeal;
      if (ph) this.heal(p, p.maxHp * ph / 100);
      this.addBuff(p, c.chainBuff, 1, true);
    }
  }

  chainOf(p) {
    const v = p.ch.via && VIE[p.ch.via].passive.chain;
    return v || CLASSES[p.cls].chain || null;
  }

  // Mette nella barra rapida le abilità appena sbloccate.
  autoQuickbar(p, announce) {
    const c = CLASSES[p.cls];
    const known = new Set(p.ch.qb.filter(Boolean).filter(q => q.k === 's').map(q => q.id));
    const list = [...c.baseSkills, ...(p.ch.via ? Object.values(SKILLS).filter(s => s.via === p.ch.via).map(s => s.id) : [])];
    for (const sid of list) {
      if (!this.lvlOf(p, sid) || known.has(sid)) continue;
      const slot = p.ch.qb.findIndex((q, i) => !q && i < QB_SIZE - 2);
      if (slot >= 0) p.ch.qb[slot] = { k: 's', id: sid };
      if (announce) this.sys(p, `Nuova abilità: ${SKILLS[sid].name}`);
    }
    p.selfDirty = true;
  }

  addBuff(p, id, lvl = 1, notify = false) {
    const def = BUFFS[id];
    if (!def) return;
    const stats = {};
    if (def.stats) for (const k in def.stats) stats[k] = Math.round(skillVal(def.stats[k], lvl) * 10) / 10;
    p.buffs = p.buffs.filter(b => b.id !== id);
    p.buffs.push({ id, stats, until: NOW() + def.dur * 1000 });
    this.recalc(p);
    if (notify || def.proc) this.send(p, { t: 'fx', k: 'proc', s: p.id, b: id });
  }

  onStable(p, npcId, action) {
    if (!this.nearNpc(p, npcId, ['stalliere'])) return;
    const h = p.ch.horse;
    if (action === 'buy') {
      if (h) return this.err(p, 'Hai già un destriero');
      if (p.lvl < HORSE.minLevel) return this.err(p, `Serve il livello ${HORSE.minLevel}`);
      if (p.ch.tael < HORSE.price) return this.err(p, 'Tael insufficienti');
      p.ch.tael -= HORSE.price;
      p.ch.horse = { lvl: 1, exp: 0 };
      p.selfDirty = true;
      this.send(p, { t: 'notice', m: 'Hai un nuovo Puledro! Premi R per salire in sella.' });
    } else if (action === 'train') {
      if (!h) return;
      if (h.lvl >= HORSE.maxLevel) return this.err(p, 'Il destriero ha raggiunto il massimo');
      const cost = HORSE.trainCost(h.lvl);
      if (p.ch.tael < cost) return this.err(p, 'Tael insufficienti');
      p.ch.tael -= cost;
      this.gainHorseExp(p, HORSE.need(h.lvl) * HORSE.trainPct / 100);
      this.sys(p, `Addestramento completato (-${cost} tael).`);
    }
  }

  // ------------------------------------------------------------ Prove del Sigillo
  sendTrialInfo(p, npcId) {
    const key = p.ch.inv.find(s => s && s.id === 'sigillo_prova');
    const party = this.partyOf(p);
    this.send(p, {
      t: 'trial', npc: npcId, key: key ? key.kl : null, best: p.ch.trialBest || 0, week: weeklyAffixes(),
      leader: !party || party.leader === p.id, party: party ? party.members.length : 1, minLevel: DUNGEON.minLevel,
    });
  }

  onTrial(p, npcId, action) {
    const npc = this.nearNpc(p, npcId, ['custode']);
    if (!npc) return;
    if (action === 'key') {
      if (p.lvl < DUNGEON.minLevel) return this.err(p, `Serve il livello ${DUNGEON.minLevel}`);
      if (p.ch.inv.some(s => s && s.id === 'sigillo_prova')) return this.err(p, 'Hai già un Sigillo della Prova');
      if (this.addItem(p, 'sigillo_prova', 1, 0, { id: 'sigillo_prova', n: 1, kl: DUNGEON.startKey })) return this.err(p, 'Inventario pieno');
      this.sys(p, `Hai ricevuto un Sigillo della Prova +${DUNGEON.startKey}.`);
      return this.sendTrialInfo(p, npcId);
    }
    if (action === 'open') return this.openTrial(p, npc);
  }

  openTrial(p, npc) {
    if (p.inst) return;
    const key = p.ch.inv.find(s => s && s.id === 'sigillo_prova');
    if (!key) return this.err(p, 'Ti serve un Sigillo della Prova');
    const party = this.partyOf(p);
    if (party && party.leader !== p.id) return this.err(p, 'Solo il capogruppo può aprire la prova');
    const members = (party ? party.members.map(id => this.ents.get(id)) : [p])
      .filter(q => q && q.kind === 'player' && q.online && !q.dead && !q.inst && dist(q, npc) < 40);
    if (!members.includes(p)) return;
    const low = members.find(q => q.lvl < DUNGEON.minLevel);
    if (low) return this.err(p, `${low.name} non ha ancora il livello ${DUNGEON.minLevel}`);
    let slot = 0;
    while (this.instSlots[slot]) slot++;
    const ox = DUNGEON.originX + slot * DUNGEON.slotSpacing, oz = 0;
    const kl = key.kl || DUNGEON.startKey;
    const inst = {
      id: this.nextInst++, slot, ox, oz, kl, affixes: activeAffixes(kl), members: new Set(members.map(q => q.id)), owner: p.id, key,
      players: members.length, start: NOW(), deaths: 0, forces: 0, bossDead: false, bossId: 0, done: false, result: null,
      mobs: new Set(), hazards: [], timers: [], closeAt: 0, lastSend: 0, overtime: false,
    };
    this.instSlots[slot] = inst;
    this.instances.set(inst.id, inst);
    const sc = trialScale(kl, members.length);
    for (const pack of DUNGEON.packs) {
      pack.mobs.forEach((type, i) => {
        const a = i / pack.mobs.length * Math.PI * 2;
        this.spawnTrialMob(inst, type, ox + pack.x + Math.cos(a) * 2.4, oz + pack.z + Math.sin(a) * 2.4, sc);
      });
    }
    const boss = this.spawnTrialMob(inst, DUNGEON.boss.type, ox + DUNGEON.boss.x, oz + DUNGEON.boss.z, sc);
    boss.r = Math.PI;
    inst.bossId = boss.id;
    for (const q of members) {
      q.inst = inst.id;
      if (q.mounted) { q.mounted = false; this.recalc(q); q.vis++; }
      q.known.clear(); q.knownVis.clear();
      this.teleport(q, ox + DUNGEON.spawn[0] + rand(-2, 2), oz + DUNGEON.spawn[1] + rand(-1, 1));
      this.send(q, { t: 'dg_start', ox, oz, kl, affixes: inst.affixes });
      this.send(q, { t: 'notice', m: `${DUNGEON.trial} +${kl}: ${Math.round(DUNGEON.timeLimit / 60)} minuti. Buona fortuna!` });
    }
    this.sendTrialState(inst);
  }

  spawnTrialMob(inst, type, x, z, sc) {
    const m = this.spawnMob(type, x, z, null, false);
    const d = m.d;
    let hpMul = sc.hp, dmgMul = sc.dmg;
    if (inst.affixes.includes('pietra') && !d.boss) { hpMul *= 1.25; dmgMul *= 1.15; }
    if (inst.affixes.includes('tiranno') && d.boss) { hpMul *= 1.3; dmgMul *= 1.15; }
    m.maxHp = m.hp = Math.max(1, Math.round(d.hp * hpMul));
    m.atk = Math.round(d.atk * dmgMul);
    m.lvl = d.lvl + Math.max(0, inst.kl - 2);
    m.inst = inst.id;
    if (d.explode) { m.explodeAt = NOW() + d.explode.after * 1000; m.explodeDmg = Math.round(120 * sc.dmg * d.explode.mult); }
    inst.mobs.add(m.id);
    return m;
  }

  instMembers(inst) { return [...inst.members].map(id => this.ents.get(id)).filter(q => q && q.kind === 'player'); }
  instBroadcast(inst, obj) { for (const q of this.instMembers(inst)) this.send(q, obj); }

  trialBossLogic(m, t) {
    const inst = this.instances.get(m.inst);
    if (!inst) return;
    if (!m.ringAt) { m.ringAt = t + 8000; m.addsAt = t + 16000; }
    if (t >= m.ringAt) {
      m.ringAt = t + 14000;
      const x = m.x, z = m.z, r = 9;
      this.fx(m, { k: 'warn', x: r1(x), z: r1(z), r, ms: 2500 });
      this.instBroadcast(inst, { t: 'notice', m: 'Anello di fiamme: allontanati da Shen!' });
      inst.timers.push({ at: t + 2500, fn: () => {
        if (m.hp <= 0) return;
        this.fx(m, { k: 'slam', s: m.id, x: r1(x), z: r1(z), r });
        for (const q of this.instMembers(inst)) if (!q.dead && Math.hypot(q.x - x, q.z - z) < r) this.hit(m, q, m.atk * 2.5, {});
      } });
    }
    if (t >= m.addsAt) {
      m.addsAt = t + 24000;
      this.fx(m, { k: 'wave', s: m.id });
      this.instBroadcast(inst, { t: 'notice', m: 'Shen evoca le Lanterne Instabili: distruggetele prima che esplodano!' });
      const sc = trialScale(inst.kl, inst.players);
      for (let i = 0; i < 3; i++) {
        const a = Math.random() * Math.PI * 2;
        this.spawnTrialMob(inst, 'lanterna_instabile', inst.ox + 55 + Math.cos(a) * 15, inst.oz + 100 + Math.sin(a) * 12, sc);
      }
    }
    if (!m.enraged && m.hp / m.maxHp < 0.3) {
      m.enraged = true; m.aspdMul = 0.7; m.atk = Math.round(m.atk * 1.2);
      this.instBroadcast(inst, { t: 'notice', m: 'Shen è in furia!' });
    }
  }

  explodeLantern(m) {
    const inst = this.instances.get(m.inst);
    const r = m.d.explode.radius;
    this.fx(m, { k: 'slam', s: m.id, x: r1(m.x), z: r1(m.z), r });
    if (inst) for (const q of this.instMembers(inst)) if (!q.dead && Math.hypot(q.x - m.x, q.z - m.z) < r) this.hit(m, q, m.explodeDmg, {});
    m.hp = 0; this.touch(m);
    this.fx(m, { k: 'die', d: m.id });
    if (inst) inst.mobs.delete(m.id);
    m.removeAt = NOW() + 500;
  }

  trialMobDied(m) {
    const inst = this.instances.get(m.inst);
    if (!inst) return;
    inst.mobs.delete(m.id);
    if (inst.done) return;
    const d = m.d;
    inst.forces += DUNGEON.forces[m.type] || 0;
    if (d.dungeonBoss) {
      inst.bossDead = true;
      if (inst.forces < DUNGEON.forcesNeeded) this.instBroadcast(inst, { t: 'notice', m: `Shen è caduto! Mancano ancora forze nemiche (${Math.round(inst.forces)}%/${DUNGEON.forcesNeeded}%).` });
    }
    if (inst.affixes.includes('brace') && !d.boss && !d.explode) {
      inst.hazards.push({ x: m.x, z: m.z, r: 3, until: NOW() + 6000, dmg: Math.max(1, Math.round(m.atk * 0.35)) });
      this.fx(m, { k: 'hazard', x: r1(m.x), z: r1(m.z), r: 3, ms: 6000 });
    }
    if (inst.affixes.includes('eco') && !d.boss && !d.explode && m.type !== 'eco_spirito' && Math.random() < 0.25) {
      this.spawnTrialMob(inst, 'eco_spirito', m.x, m.z, trialScale(inst.kl, inst.players));
    }
    if (inst.bossDead && inst.forces >= DUNGEON.forcesNeeded) this.completeTrial(inst);
  }

  completeTrial(inst) {
    inst.done = true;
    const elapsed = (NOW() - inst.start) / 1000 + inst.deaths * DUNGEON.deathPenalty;
    const change = keyChange(elapsed, DUNGEON.timeLimit);
    const oldKl = inst.kl, newKl = clamp(oldKl + change, DUNGEON.startKey, DUNGEON.maxKey);
    if (inst.key) inst.key.kl = newKl;
    const owner = this.ents.get(inst.owner);
    if (owner) owner.invDirty = true;
    inst.result = { elapsed: Math.round(elapsed), change, oldKl, newKl, inTime: change > 0 };
    inst.closeAt = NOW() + 120000;
    for (const q of this.instMembers(inst)) {
      if (change > 0) q.ch.trialBest = Math.max(q.ch.trialBest || 0, oldKl);
      this.trialRewards(q, oldKl, change > 0);
    }
    const mm = Math.floor(elapsed / 60), ss = String(Math.round(elapsed % 60)).padStart(2, '0');
    this.instBroadcast(inst, { t: 'notice', m: change > 0 ? `Prova completata in ${mm}:${ss}! Sigillo +${oldKl} → +${newKl}` : `Prova completata fuori tempo (${mm}:${ss}). Sigillo +${oldKl} → +${newKl}` });
    const names = this.instMembers(inst).map(q => q.name);
    if (change >= 2) this.broadcast({ t: 'sys', m: `${names.join(', ')} ${names.length > 1 ? 'hanno' : 'ha'} completato la ${DUNGEON.trial} +${oldKl} in ${mm}:${ss}!` });
    this.sendTrialState(inst);
  }

  trialRewards(q, kl, inTime) {
    const got = [];
    const give = (id, n = 1, inst = null) => {
      const left = this.addItem(q, id, n, 0, inst);
      if (left) { if (inst) this.dropInstance(inst, q.x, q.z, q.id); else this.spawnDrop(id, left, q.x, q.z, q.id); }
    };
    const rolls = Math.min(6, 1 + Math.floor(kl / 2) + (inTime ? 1 : 0));
    const pool = GEAR_BY_TIER[4];
    for (let i = 0; i < rolls; i++) {
      let r = rollRarity('boss');
      if (kl >= 6) r = Math.max(r, 2);
      if (kl >= 10) r = Math.max(r, 3);
      const it = makeEquip(pool[randi(0, pool.length - 1)], r);
      give(it.id, 1, it);
      got.push(`${ITEMS[it.id].name} (${RARITIES[r].name})`);
    }
    const ess = Math.ceil(kl / 2);
    give('essenza_celeste', ess); got.push(`Essenza Celeste x${ess}`);
    const gems = Object.keys(GEM_TYPES);
    const gem = `gemma_${gems[randi(0, gems.length - 1)]}_${kl >= 8 ? 2 : 1}`;
    give(gem); got.push(ITEMS[gem].name);
    const stones = 1 + Math.floor(kl / 4);
    give('pietra_affinamento', stones); got.push(`Pietra dell'Affinamento x${stones}`);
    const tael = 1500 * kl * (inTime ? 1 : 0.5);
    q.ch.tael += tael; got.push(`${tael.toLocaleString('it-IT')} tael`);
    this.gainExp(q, Math.round(expToNext(q.lvl) * 0.05 * (1 + kl * 0.1) * (inTime ? 1 : 0.5)));
    q.selfDirty = true;
    this.send(q, { t: 'dg_reward', got });
  }

  sendTrialState(inst) {
    const boss = this.ents.get(inst.bossId);
    const elapsed = NOW() - inst.start;
    this.instBroadcast(inst, {
      t: 'dg', kl: inst.kl, affixes: inst.affixes, elapsed, limit: DUNGEON.timeLimit * 1000, penalty: inst.deaths * DUNGEON.deathPenalty * 1000,
      forces: Math.round(inst.forces * 10) / 10, need: DUNGEON.forcesNeeded, deaths: inst.deaths,
      boss: inst.bossDead ? 0 : boss ? Math.round(boss.hp / boss.maxHp * 1000) / 10 : 100, bossDead: inst.bossDead ? 1 : 0,
      done: inst.done ? 1 : 0, result: inst.result, closeIn: inst.closeAt ? Math.max(0, inst.closeAt - NOW()) : 0,
    });
  }

  updateTrial(inst, t, regen) {
    if (inst.timers.length) inst.timers = inst.timers.filter(tm => { if (t >= tm.at) { tm.fn(); return false; } return true; });
    if (regen && inst.hazards.length) {
      inst.hazards = inst.hazards.filter(h => h.until > t);
      const env = { kind: 'env', id: 0, name: 'Braci ardenti' };
      for (const h of inst.hazards) for (const q of this.instMembers(inst)) {
        if (q.dead || Math.hypot(q.x - h.x, q.z - h.z) > h.r) continue;
        this.fx(q, { k: 'hit', s: 0, d: q.id, v: h.dmg, dot: 1, sk: 'brace' });
        this.applyDamage(q, h.dmg, env);
      }
    }
    if (!inst.done && !inst.overtime && (t - inst.start) / 1000 + inst.deaths * DUNGEON.deathPenalty > DUNGEON.timeLimit) {
      inst.overtime = true;
      this.instBroadcast(inst, { t: 'notice', m: 'Tempo scaduto! Potete completare la prova, ma il sigillo scenderà.' });
    }
    if (t - inst.lastSend >= 1000) { inst.lastSend = t; this.sendTrialState(inst); }
    if (inst.closeAt && t >= inst.closeAt) this.closeTrial(inst);
  }

  leaveTrial(p, silent) {
    if (!p.inst) return;
    const inst = this.instances.get(p.inst);
    p.inst = null;
    if (inst) {
      inst.members.delete(p.id);
      if (!inst.done && p.id === inst.owner && inst.key) {
        inst.key.kl = Math.max(DUNGEON.startKey, inst.kl - 1);
        p.invDirty = true;
        inst.key = null;
        if (!silent) this.sys(p, `Hai abbandonato la prova: il sigillo scende a +${Math.max(DUNGEON.startKey, inst.kl - 1)}.`);
      }
      if (!inst.members.size) this.closeTrial(inst);
    }
    if (!silent) {
      const sp = villageSpawn(p.kingdom);
      if (p.dead) { p.dead = false; p.hp = p.maxHp; this.touch(p); p.selfDirty = true; }
      p.known.clear(); p.knownVis.clear();
      this.teleport(p, sp.x, sp.z);
      this.send(p, { t: 'dg_end' });
    }
  }

  closeTrial(inst) {
    for (const q of this.instMembers(inst)) this.leaveTrial(q);
    for (const id of inst.mobs) { const m = this.ents.get(id); if (m) this.remove(m); }
    for (const e of [...this.ents.values()]) {
      if (e.kind === 'mob' && e.inst === inst.id) this.remove(e);
      if (e.kind === 'drop' && e.x > inst.ox - 30 && e.x < inst.ox + 100) this.remove(e);
    }
    this.instSlots[inst.slot] = null;
    this.instances.delete(inst.id);
  }

  // ------------------------------------------------------------ gruppi
  playerByName(n) {
    const name = String(n || '').toLowerCase();
    return [...this.players].find(q => q.name.toLowerCase() === name) || null;
  }

  partyOf(p) { return p.party ? this.parties.get(p.party) : null; }

  partySys(party, m) { for (const id of party.members) { const q = this.ents.get(id); if (q) this.sys(q, m); } }

  onPartyInvite(p, q) {
    if (!q || q.kind !== 'player' || !q.online) return this.err(p, 'Giocatore non trovato');
    if (q === p) return;
    if (q.kingdom !== p.kingdom) return this.err(p, 'Puoi formare gruppi solo con il tuo regno');
    if (q.party) return this.err(p, `${q.name} è già in un gruppo`);
    const party = this.partyOf(p);
    if (party && party.leader !== p.id) return this.err(p, 'Solo il capogruppo può invitare');
    if (party && party.members.length >= 5) return this.err(p, 'Il gruppo è al completo');
    q.pendingInvite = { from: p.id, at: NOW() };
    this.send(q, { t: 'pinv', from: p.id, n: p.name });
    this.sys(p, `Invito inviato a ${q.name}.`);
  }

  onPartyReply(q, ok) {
    const inv = q.pendingInvite;
    q.pendingInvite = null;
    if (!inv || NOW() - inv.at > 60000) return;
    const p = this.ents.get(inv.from);
    if (!p || p.kind !== 'player' || !p.online) return this.err(q, "L'invito non è più valido");
    if (!ok) return this.sys(p, `${q.name} ha rifiutato l'invito.`);
    if (q.party) return;
    let party = this.partyOf(p);
    if (!party) {
      party = { id: this.nextParty++, leader: p.id, members: [p.id] };
      this.parties.set(party.id, party);
      p.party = party.id;
    }
    if (party.members.length >= 5) return this.err(q, 'Il gruppo è al completo');
    party.members.push(q.id);
    q.party = party.id;
    this.partySys(party, `${q.name} si è unito al gruppo.`);
  }

  leaveParty(p, silent) {
    const party = this.partyOf(p);
    if (!party) return;
    party.members = party.members.filter(id => id !== p.id);
    p.party = null;
    this.send(p, { t: 'party', none: 1 });
    if (!silent) this.sys(p, 'Hai lasciato il gruppo.');
    if (party.members.length <= 1) {
      for (const id of party.members) { const q = this.ents.get(id); if (q) { q.party = null; this.send(q, { t: 'party', none: 1 }); this.sys(q, 'Il gruppo si è sciolto.'); } }
      this.parties.delete(party.id);
      return;
    }
    if (party.leader === p.id) party.leader = party.members[0];
    party.last = '';
    this.partySys(party, `${p.name} ha lasciato il gruppo.`);
  }

  onPartyKick(p, id) {
    const party = this.partyOf(p);
    if (!party || party.leader !== p.id) return this.err(p, 'Solo il capogruppo può espellere');
    const q = this.ents.get(id);
    if (!q || !party.members.includes(q.id) || q === p) return;
    this.sys(q, 'Sei stato espulso dal gruppo.');
    this.leaveParty(q, true);
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
    if (msg[0] === '#') {
      const party = this.partyOf(p), m = msg.slice(1).trim();
      if (!party) return this.sys(p, 'Non sei in un gruppo.');
      if (!m) return;
      for (const id of party.members) { const q = this.ents.get(id); if (q) this.send(q, { t: 'chat', ch: 'party', n: p.name, kd: p.kingdom, m }); }
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
        sys('Comandi: /online, /pos, /invita nome, /lascia, /espelli nome, /aiuto. Chat: !testo = grido al regno, #testo = gruppo, @nome testo = sussurro.');
        if (p.gm) sys('GM: /item id [n] [+liv] [rarità 0-4], /level n, /exp n, /tael n, /tp x z | /tp nome | /tp fenice|tigre|drago, /spawn mostro [n] [raggio], /heal, /risorsa, /punti, /suprema, /uccidi, /via nome, /destriero livello, /sigillo livello, /rate exp|drop|tael valore, /items, /mobs, /save, /annuncio testo');
        return;
      case 'invita': return this.onPartyInvite(p, this.playerByName(a[0]));
      case 'lascia': return this.leaveParty(p);
      case 'espelli': { const q = this.playerByName(a[0]); return q ? this.onPartyKick(p, q.id) : sys('Giocatore non trovato.'); }
      case 'online': return sys(`In linea (${this.players.size}): ${[...this.players].map(q => `${q.name} [${q.lvl}]`).join(', ')}`);
      case 'pos': return sys(`Posizione: ${Math.round(p.x)}, ${Math.round(p.z)}`);
    }
    if (!p.gm) return sys('Comando sconosciuto. Scrivi /aiuto');
    switch (c) {
      case 'item': {
        const id = a[0];
        if (!ITEMS[id]) return sys('Oggetto inesistente. Scrivi /items per la lista.');
        const n = clamp(parseInt(a[1], 10) || 1, 1, STACK_MAX), up = clamp(parseInt(a[2], 10) || 0, 0, UPGRADE.max);
        const r = clamp(parseInt(a[3], 10) || 0, 0, 4);
        let left = 0;
        if (ITEMS[id].stack) left = this.addItem(p, id, n);
        else for (let k = 0; k < n; k++) left += this.addItem(p, id, 1, up, makeEquip(id, r, up));
        return sys(left ? 'Inventario pieno.' : `Ricevuto: ${ITEMS[id].name} x${n}${up ? ' +' + up : ''}${r ? ' (' + RARITIES[r].name + ')' : ''}`);
      }
      case 'level': {
        const L = clamp(parseInt(a[0], 10) || 1, 1, MAX_LEVEL), diff = L - p.lvl;
        p.lvl = L; p.ch.lvl = L; p.ch.exp = 0;
        if (diff > 0) { p.ch.statPts += diff * 3; p.ch.skillPts += diff; }
        this.recalc(p); p.hp = p.maxHp; if (p.rtype === 'mana') p.res = p.rmax; this.touch(p);
        this.autoQuickbar(p, false);
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
        // terzo parametro facoltativo: raggio della dispersione (predefinito 5), usato da tools/sim per gruppi compatti
        const n = clamp(parseInt(a[1], 10) || 1, 1, 30), rg = clamp(parseFloat(a[2]) || 5, 0.05, 30);
        for (let i = 0; i < n; i++) this.spawnMob(ty, p.x + rand(-rg, rg), p.z + rand(-rg, rg), null, true);
        return;
      }
      case 'heal': p.hp = p.maxHp; if (p.rtype !== 'ira') p.res = p.rmax; p.selfDirty = true; this.touch(p); return;
      case 'risorsa': p.res = p.rmax; p.selfDirty = true; return;
      case 'punti': p.pts = PTS_MAX; p.lastCombat = NOW(); p.selfDirty = true; return;                 // per le prove: punti combo/sfere/cariche al massimo
      case 'suprema': p.sup = SUPREMA.max; p.selfDirty = true; return;           // per le prove: barra Suprema piena
      case 'uccidi': {
        let best = null, bd = 20;
        for (const e of this.ents.values()) {
          if (e.kind !== 'mob' || e.hp <= 0 || e.d.dummy) continue;
          const dd = dist(e, p);
          if (dd < bd) { bd = dd; best = e; }
        }
        if (!best) return sys('Nessun nemico entro 20 metri.');
        best.aggro.set(p.id, (best.aggro.get(p.id) || 0) + best.hp);
        this.applyDamage(best, best.hp, p);
        return;
      }
      case 'sigillo': {
        const L = clamp(parseInt(a[0], 10) || DUNGEON.startKey, DUNGEON.startKey, DUNGEON.maxKey);
        const key = p.ch.inv.find(x => x && x.id === 'sigillo_prova');
        if (key) key.kl = L; else this.addItem(p, 'sigillo_prova', 1, 0, { id: 'sigillo_prova', n: 1, kl: L });
        p.invDirty = true;
        return sys(`Sigillo della Prova impostato a +${L}.`);
      }
      case 'destriero': {
        const L = clamp(parseInt(a[0], 10) || 1, 1, HORSE.maxLevel);
        p.ch.horse = { lvl: L, exp: 0 }; this.recalc(p); p.vis++; this.touch(p); p.selfDirty = true;
        return sys(`Destriero impostato al livello ${L}.`);
      }
      case 'via': {
        if (!CLASSES[p.cls].vie.includes(a[0])) return sys(`Vie disponibili: ${CLASSES[p.cls].vie.join(', ')}`);
        p.ch.via = a[0]; p.buffs = [];
        p.ch.qb = p.ch.qb.map(q => (q && q.k === 's' && SKILLS[q.id] && SKILLS[q.id].via && SKILLS[q.id].via !== a[0]) ? null : q);
        this.recalc(p); this.autoQuickbar(p, false);
        return sys(`Via impostata: ${VIE[a[0]].name}`);
      }
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
  addItem(p, id, n = 1, up = 0, inst = null) {
    const it = ITEMS[id], inv = p.ch.inv;
    if (it.stack) {
      for (let i = 0; i < INV_SIZE && n > 0; i++) {
        const s = inv[i];
        if (s && s.id === id && s.n < STACK_MAX) { const k = Math.min(n, STACK_MAX - s.n); s.n += k; n -= k; }
      }
      for (let i = 0; i < INV_SIZE && n > 0; i++) if (!inv[i]) { const k = Math.min(n, STACK_MAX); inv[i] = { id, n: k, up: 0 }; n -= k; }
    } else {
      for (let i = 0; i < INV_SIZE && n > 0; i++) if (!inv[i]) {
        inv[i] = inst ? normalizeEquip({ ...inst, n: 1, b: (inst.b || []).map(x => [...x]), s: [...(inst.s || [])] }) : makeEquip(id, 0, up);
        inst = null; n--;
      }
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
    if (ITEMS[s.id].type === 'key') return this.err(p, 'Il Sigillo della Prova non si può gettare');
    p.ch.inv[i] = null;
    p.invDirty = true;
    this.add({ kind: 'drop', item: { ...s }, x: p.x + rand(-1, 1), z: p.z + rand(-1, 1), owner: 0, ownerUntil: 0, expire: NOW() + 60000 });
  }

  onPickup(p, id) {
    const d = this.ents.get(id);
    if (!d || d.kind !== 'drop' || p.dead) return;
    if (dist(d, p) > 4) return;
    if (d.owner && d.owner !== p.id && !(d.ownerParty && d.ownerParty === p.party) && NOW() < d.ownerUntil) return this.err(p, 'Questo bottino appartiene a un altro giocatore');
    const it = ITEMS[d.item.id];
    if (!this.canAdd(p, d.item.id, d.item.n)) return this.err(p, 'Inventario pieno');
    this.addItem(p, d.item.id, d.item.n, d.item.up, it.stack ? null : d.item);
    this.remove(d);
    const r = d.item.r || 0;
    this.send(p, { t: 'gain', item: it.name, n: d.item.n, up: d.item.up, r });
    if (r >= 4) this.broadcast({ t: 'sys', m: `${p.name} ha trovato un oggetto Leggendario: ${it.name}!` });
  }

  onUse(p, i) {
    if (p.dead) return;
    const s = p.ch.inv[i];
    if (!s) return;
    const it = ITEMS[s.id];
    if (equipSlotOf(it)) return this.equip(p, i);
    if (it.type === 'potion') {
      if (it.hp && p.hp >= p.maxHp) return this.err(p, 'La vita è già al massimo');
      if (it.mpPct && p.rtype !== 'mana') return this.err(p, 'Non usi il Mana');
      if (it.mpPct && p.res >= p.rmax) return this.err(p, 'Il Mana è già al massimo');
      if (it.hp) this.heal(p, it.hp);
      if (it.mpPct) { p.res = Math.min(p.rmax, p.res + p.rmax * it.mpPct / 100); p.resDirty = true; }
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
    if (sk.via && p.ch.via !== sk.via) return this.err(p, "Questa abilità appartiene a un'altra Via");
    const cur = this.lvlOf(p, sid);
    if (!cur) return this.err(p, `Si sblocca al livello ${sk.lvl}`);
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
    p.ch.via = via;
    this.recalc(p);
    this.autoQuickbar(p, false);
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
    if (n.role === 'stalliere') return this.send(p, { t: 'stable', npc: n.id });
    if (n.role === 'custode') return this.sendTrialInfo(p, n.id);
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
    if (ITEMS[s.id].type === 'key') return this.err(p, 'Il Sigillo della Prova non si può vendere');
    const it = ITEMS[s.id];
    const val = Math.floor(it.price / 5 * (1 + (s.up || 0) * 0.5) * (1 + (s.r || 0) * 0.6)) * s.n;
    p.ch.inv[i] = null;
    p.ch.tael += val;
    p.invDirty = true; p.selfDirty = true;
    this.sys(p, `Venduto: ${it.name}${s.n > 1 ? ' x' + s.n : ''} per ${val} tael.`);
  }

  onUpgrade(p, npcId, i, useSeal) {
    if (!this.nearNpc(p, npcId, ['fabbro'])) return;
    const s = normalizeEquip(p.ch.inv[i]);
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
    const bonus = Math.min(UPGRADE.failBonusMax, (s.fs || 0) * UPGRADE.failBonus);
    const ok = Math.random() * 100 < UPGRADE.chance[lv] + bonus;
    let destroyed = false, sealUsed = false, down = false;
    if (ok) { s.up++; s.fs = 0; }
    else {
      s.fs = (s.fs || 0) + 1;
      if (risky) {
        if (useSeal) {
          this.takeItem(p, 'sigillo_fabbro', 1); sealUsed = true;
          if (lv >= UPGRADE.downgradeFrom) { s.up--; down = true; }
        } else { p.ch.inv[i] = null; destroyed = true; }
      }
    }
    p.invDirty = true; p.selfDirty = true;
    this.send(p, { t: 'smith_res', ok, destroyed, sealUsed, down, up: s.up, name: it.name, i, fs: s.fs });
    if (ok && s.up >= 10) this.broadcast({ t: 'sys', m: `${p.name} ha portato ${it.name} a +${s.up}!` });
  }

  // Smonta un oggetto in materiali (e restituisce le gemme incastonate).
  onSalvage(p, npcId, i) {
    if (!this.nearNpc(p, npcId, ['fabbro'])) return;
    const s = normalizeEquip(p.ch.inv[i]);
    if (!s || !equipSlotOf(ITEMS[s.id])) return this.err(p, 'Si possono smontare solo armi e armature');
    const t = ITEMS[s.id].tier || 1, r = s.r || 0, up = s.up || 0;
    const out = [['minerale_ferro', t + r]];
    if (r >= 2 || up >= 7) out.push(['frammento_obelisco', Math.max(r - 1, 0) + (up >= 7 ? Math.floor(up / 3) : 0)]);
    if (r >= 4 || up >= 10) out.push(['essenza_celeste', 1 + (up >= 12 ? 1 : 0)]);
    for (const gem of s.s) if (gem) out.push([gem, 1]);
    p.ch.inv[i] = null;
    const got = [];
    for (const [id, n] of out) {
      if (n <= 0) continue;
      const left = this.addItem(p, id, n);
      if (left) this.spawnDrop(id, left, p.x, p.z, p.id);
      got.push(`${ITEMS[id].name} x${n}`);
    }
    this.send(p, { t: 'smith_res', salvaged: 1, name: ITEMS[s.id].name, got });
    this.sys(p, `Smontato ${ITEMS[s.id].name}: ${got.join(', ')}.`);
  }

  // Applica un modificatore o una gemma a un oggetto (dall'inventario o equipaggiato).
  onApply(p, i, tgt) {
    const m = p.ch.inv[i];
    if (!m || !tgt) return;
    const mi = ITEMS[m.id];
    if (mi.type !== 'mod' && mi.type !== 'gem') return;
    const target = tgt.k === 'e' ? (EQUIP_SLOTS.includes(tgt.i) ? p.ch.equip[tgt.i] : null) : p.ch.inv[tgt.i | 0];
    if (!target || !equipSlotOf(ITEMS[target.id])) return this.err(p, 'Si applica solo ad armi e armature');
    normalizeEquip(target);
    const it = ITEMS[target.id], slot = equipSlotOf(it), tier = it.tier || 1;
    const consume = () => { m.n--; if (m.n <= 0) p.ch.inv[i] = null; };
    let msg = '';
    if (mi.type === 'gem') {
      const free = target.s.indexOf(null);
      if (free < 0) return this.err(p, target.s.length ? 'Nessun incavo libero (usa lo Scalpello per liberarli)' : 'Questo oggetto non ha incavi');
      target.s[free] = m.id; consume();
      msg = `${mi.name} incastonata in ${it.name}.`;
    } else if (mi.mod === 'refine') {
      if (!target.b.length) return this.err(p, 'Questo oggetto non ha bonus da affinare');
      target.b = target.b.map(([k]) => [k, rollValue(k, tier)]); consume();
      msg = `Bonus di ${it.name} affinati.`;
    } else if (mi.mod === 'reroll') {
      if (!target.b.length) return this.err(p, 'Questo oggetto non ha bonus da rimescolare');
      target.b = rollBonuses(slot, tier, target.b.length, []); consume();
      msg = `Bonus di ${it.name} rimescolati.`;
    } else if (mi.mod === 'ascend') {
      if (target.r >= 4) return this.err(p, "L'oggetto è già Leggendario");
      consume();
      if (Math.random() < 0.35) {
        target.r++;
        const R = RARITIES[target.r];
        target.b.push(...rollBonuses(slot, tier, R.bonuses - target.b.length, target.b.map(x => x[0])));
        while (target.s.length < R.sockets) target.s.push(null);
        msg = `Ascensione riuscita! ${it.name} è ora ${R.name}.`;
        if (target.r >= 4) this.broadcast({ t: 'sys', m: `${p.name} ha elevato ${it.name} a Leggendario!` });
      } else msg = "L'ascensione non è riuscita: il sigillo si è dissolto.";
    } else if (mi.mod === 'extract') {
      const gems = target.s.filter(Boolean);
      if (!gems.length) return this.err(p, 'Nessuna gemma da estrarre');
      consume();
      target.s = target.s.map(() => null);
      for (const gem of gems) { const left = this.addItem(p, gem, 1); if (left) this.spawnDrop(gem, 1, p.x, p.z, p.id); }
      msg = gems.length === 1 ? `Estratta 1 gemma da ${it.name}.` : `Estratte ${gems.length} gemme da ${it.name}.`;
    }
    if (tgt.k === 'e') this.recalc(p);
    p.invDirty = true; p.selfDirty = true;
    this.send(p, { t: 'applied', m: msg });
  }

  onCombine(p, i) {
    const s = p.ch.inv[i];
    if (!s) return;
    const it = ITEMS[s.id];
    if (it.type !== 'gem' || it.grade >= 2) return this.err(p, 'Questa gemma non si può fondere');
    if (this.countItem(p, s.id) < 3) return this.err(p, 'Servono 3 gemme uguali');
    const next = `gemma_${it.gem}_${it.grade + 1}`;
    this.takeItem(p, s.id, 3);
    const left = this.addItem(p, next, 1);
    if (left) this.spawnDrop(next, 1, p.x, p.z, p.id);
    this.send(p, { t: 'applied', m: `Fusione riuscita: ${ITEMS[next].name}.` });
  }
}
