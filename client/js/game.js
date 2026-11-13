// Logica di gioco lato client: entità, input, visuale, movimento, combattimento, messaggi dal server.
import * as THREE from 'three';
import { heightAt, buildColliders, resolveCollisions, KINGDOMS, PLAY_LIMIT, safeZoneAt, DUNGEON_X } from '/shared/world.js';
import { SKILLS, ITEMS, MOBS, CLASSES, NPC_ROLES, VIE, BUFFS, RESOURCES, QB_SIZE, RARITIES, MOUNT_SKILLS, HORSE, DUNGEON, dungeonWalkable, supremaOf } from '/shared/data.js';
import { buildModel, disposeRig } from './models.js';
import { Fx } from './fx.js';
import { VFX } from './vfx.js';
import { UI } from './ui.js';

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const angLerp = (a, b, t) => { let d = b - a; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return a + d * t; };
const groundY = (x, z) => Math.max(heightAt(x, z), -0.7);

class CEnt {
  constructor(g, info, isSelf = false) {
    this.g = g; this.id = info.id; this.self = isSelf;
    this.x = info.x; this.z = info.z; this.r = info.r || 0;
    this.tx = this.x; this.tz = this.z; this.tr = this.r;
    this.y = groundY(this.x, this.z);
    this.speed = 0; this.bubble = null; this.bubbleUntil = 0;
    this.label = document.createElement('div');
    this.label.className = 'label';
    g.labelLayer.appendChild(this.label);
    this.setInfo(info);
  }

  setInfo(info) {
    const prev = this.info;
    this.info = info;
    this.hp = info.hp ?? 1; this.mhp = info.mhp ?? 1; this.lvl = info.lvl ?? 0;
    const d = info.k === 'm' ? MOBS[info.ty] : null;
    this.boss = !!d?.boss; this.stone = !!d?.stone; this.aggr = !!(d && d.aggro > 0);
    // Postura (solo élite, boss e fantoccio): po = % rimasta, sqOn = Squilibrato
    this.po = info.k === 'm' ? info.po : undefined; this.sqOn = info.k === 'm' && info.sq > 0;
    const needModel = !prev || prev.w !== info.w || prev.wu !== info.wu || prev.wr !== info.wr || prev.bu !== info.bu || prev.br !== info.br || prev.b !== info.b || prev.h !== info.h || prev.k !== info.k || (prev.mt || 0) !== (info.mt || 0);
    if (needModel) {
      if (this.rig) this.g.removeRig(this.rig);
      this.rig = buildModel(info);
      this.rig.pick.userData.ent = this;
      this.g.addRig(this.rig);
      this.radius = this.rig.radius;
      if (info.dead || (info.k === 'm' && info.hp <= 0)) { this.rig.anim.die(); this.rig.anim.deadT = 1; }
    }
    if (!this.self) { this.tx = info.x; this.tz = info.z; this.tr = info.r || 0; }
    this.labelKey = '';
  }

  applyUpdate(u) {
    this.tx = u[1]; this.tz = u[2]; this.tr = u[3];
    const wasDead = this.hp <= 0;
    this.hp = u[4]; this.mhp = u[5]; this.lvl = u[6];
    if (this.info.k === 'p') {
      const dead = u[7] === 1;
      if (dead && !this.rig.anim.dead) this.rig.anim.die();
      if (!dead && this.rig.anim.dead) this.rig.anim.revive();
    } else if (this.info.k === 'm' && wasDead && this.hp > 0) this.rig.anim.revive();
    if (u.length > 8) { this.po = u[8]; this.sqOn = u[9] === 1; }
  }

  update(dt) {
    if (!this.self) {
      const dx = this.tx - this.x, dz = this.tz - this.z, dd = Math.hypot(dx, dz);
      if (dd > 18) { this.x = this.tx; this.z = this.tz; this.speed = 0; }
      else {
        const k = Math.min(1, dt * 9);
        this.x += dx * k; this.z += dz * k;
        const inst = dt > 0 ? (dd * k) / dt : 0;
        this.speed += (inst - this.speed) * Math.min(1, dt * 8);
      }
      this.r = angLerp(this.r, this.tr, Math.min(1, dt * 10));
    }
    this.y = groundY(this.x, this.z);
    // contorni accesi solo vicino alla visuale (e se la qualità li prevede)
    const ol = this.rig.outlines;
    if (ol && ol.length) {
      const g = this.g, on = !!(g.post && g.post.q.outlines) && Math.hypot(this.x - g.camTarget.x, this.z - g.camTarget.z) < 45;
      if (on !== this.olOn) { this.olOn = on; for (const o of ol) o.visible = on; }
    }
    const root = this.rig.root;
    root.position.set(this.x, this.y, this.z);
    root.rotation.y = this.r;
    this.rig.anim.update(dt, this.speed);
  }

  face(o) { if (o) { this.tr = this.r = Math.atan2(o.x - this.x, o.z - this.z); } }

  destroy() { this.g.removeRig(this.rig); this.label.remove(); }
}

// Registra i danni inflitti, divisi per abilità (si azzera dopo 6 s senza danni).
class DpsMeter {
  constructor() { this.reset(); }
  reset() { this.seg = null; }
  add(sk, v, crit) {
    const now = performance.now();
    if (!this.seg || now - this.seg.last > 6000) this.seg = { start: now, last: now, total: 0, by: {} };
    const s = this.seg;
    s.last = now; s.total += v;
    const a = s.by[sk] || (s.by[sk] = { v: 0, n: 0, c: 0 });
    a.v += v; a.n++; if (crit) a.c++;
  }
}

export class Game {
  constructor(renderer, scene, camera, world, net) {
    this.renderer = renderer; this.scene = scene; this.camera = camera; this.world = world; this.net = net;
    this.ents = new Map();
    this.pickMeshes = [];
    this.labelLayer = document.getElementById('labels');
    this.fx = new Fx(scene, camera, document.getElementById('floaters'));
    this.vfx = new VFX(scene, camera, renderer);
    this.shake = 0;
    this.ui = new UI(this);
    this.colliders = buildColliders();
    this.keys = new Set();
    this.cds = {};
    this.localLock = {};
    this.yaw = 0; this.pitch = 0.5; this.dist = 15; this.camTarget = new THREE.Vector3();
    this.intent = null; this.target = null; this.nextAttack = 0; this.lastMoveSent = 0; this.lastSent = { x: 0, z: 0 };
    this.stunUntil = 0; this.slowUntil = 0;
    this.gcdUntil = 0; this.gcdTotal = 1000; this.casting = null; this.queued = null; this.queuedAt = 0;
    this.dots = {}; this.meter = new DpsMeter();
    this.raycaster = new THREE.Raycaster();
    this.active = false;
    this.ui.initMinimap(world.terrain);
    this.attachNet();
    this.attachInput();
  }

  addRig(rig) { this.scene.add(rig.root); this.pickMeshes.push(rig.pick); }
  removeRig(rig) {
    this.scene.remove(rig.root);
    disposeRig(rig);
    const i = this.pickMeshes.indexOf(rig.pick);
    if (i >= 0) this.pickMeshes.splice(i, 1);
  }

  // ------------------------------------------------------------ avvio
  start(m) {
    this.myId = m.id; this.name = m.name; this.cls = m.cls; this.kd = m.kd; this.gm = !!m.gm;
    this.pvp = !!m.pvp; this.pvpMin = m.pvpMin;
    this.self = new CEnt(this, { id: m.id, k: 'p', n: m.name, cls: m.cls, kd: m.kd, sx: m.sx === 'f' ? 'f' : 'm', lvl: 1, x: m.x, z: m.z, r: 0, hp: 1, mhp: 1, w: null, wu: 0, b: null, h: null }, true);
    this.self.label.style.display = 'none';
    this.ents.set(m.id, this.self);
    this.lastSent = { x: m.x, z: m.z };
    const f = KINGDOMS[m.kd].village;
    this.yaw = Math.atan2(f.x - 0, f.z - 10);
    this.camTarget.set(m.x, groundY(m.x, m.z) + 1.8, m.z);
    this.active = true;
    document.getElementById('game-ui').classList.remove('hidden');
    this.ui.chat('sys', `Benvenuto nei Regni di Giada, <b>${esc(m.name)}</b>. Premi <b>H</b> per la guida rapida.`);
    if (this.gm) this.ui.chat('sys', 'Sei un Game Master: scrivi /aiuto per i comandi.');
  }

  // ------------------------------------------------------------ rete
  attachNet() {
    const n = this.net, ui = this.ui;
    n.on('v', (m) => {
      for (const info of m.a) {
        const e = this.ents.get(info.id);
        if (e && !e.self) e.setInfo(info);
        else if (!e) this.ents.set(info.id, new CEnt(this, info));
      }
      for (const u of m.u) { const e = this.ents.get(u[0]); if (e && !e.self) e.applyUpdate(u); }
      for (const id of m.r) {
        const e = this.ents.get(id);
        if (e && !e.self) { e.destroy(); this.ents.delete(id); if (this.target === e) this.setTarget(null); }
      }
    });
    n.on('me', (m) => {
      const first = !this.me;
      this.me = m;
      if (this.self) {
        const mt = m.mounted && m.horse ? HORSE.tierOf(m.horse.lvl) : 0;
        if ((this.self.info.mt || 0) !== mt) this.self.setInfo({ ...this.self.info, mt, x: this.self.x, z: this.self.z, r: this.self.r });
        this.self.hp = m.hp; this.self.mhp = m.mhp; this.self.lvl = m.lvl; this.self.info.lvl = m.lvl;
        if (m.dead && !this.self.rig.anim.dead) this.self.rig.anim.die();
        if (!m.dead && this.self.rig.anim.dead) { this.self.rig.anim.revive(); ui.hideDeath(); }
      }
      ui.onMe();
      if (first) this.ui.renderQuickbar();
    });
    n.on('r', (m) => {
      if (!this.me) return;
      this.me.hp = m.hp; this.me.res = m.res; this.me.pts = m.pts; this.me.sl = m.sl || 0; this.me.su = m.su || 0;
      if (this.self) this.self.hp = m.hp;
      ui.onRes();
    });
    n.on('cast', (m) => {
      const now = performance.now();
      this.casting = { sid: m.s, until: now + m.ms, total: m.ms };
      if (m.gcd) { this.gcdUntil = now + m.gcd; this.gcdTotal = m.gcd; }
      if (this.self) this.self.rig.anim.channel = m.ms / 1000;
    });
    n.on('castend', () => { this.casting = null; if (this.self) this.self.rig.anim.channel = 0; });
    n.on('skfail', (m) => {
      this.localLock[m.s] = 0;
      if (this.optimistic && this.optimistic.sid === m.s) { this.gcdUntil = this.optimistic.prev; this.optimistic = null; }
    });
    n.on('dot', (m) => {
      (this.dots[m.d] || (this.dots[m.d] = {}))[m.s] = performance.now() + m.ms;
      if (this.target && this.target.id === m.d) this.ui.renderTargetDots(performance.now());
    });
    n.on('inv', (m) => {
      this.inv = m.inv; this.eq = m.eq;
      if (this.self) {
        const i = this.self.info;
        const w = m.eq.weapon?.id || null, wu = m.eq.weapon?.up || 0, b = m.eq.body?.id || null, h = m.eq.head?.id || null;
        if (i.w !== w || i.wu !== wu || i.b !== b || i.h !== h) {
          this.self.setInfo({ ...i, w, wu, b, h, x: this.self.x, z: this.self.z, r: this.self.r, lvl: this.me?.lvl || i.lvl });
        }
      }
      ui.onInv();
    });
    n.on('fx', (m) => this.onFx(m));
    n.on('cd', (m) => {
      const now = performance.now();
      if (m.ms) this.cds[m.s] = { until: now + m.ms, total: m.ms };
      if (m.gcd) { this.gcdUntil = now + m.gcd; this.gcdTotal = m.gcd; }
      this.optimistic = null;
    });
    n.on('pos', (m) => {
      if (!this.self) return;
      const from = { x: this.self.x, y: this.self.y, z: this.self.z };
      this.self.x = m.x; this.self.z = m.z;
      if (m.r !== undefined) this.self.r = m.r;
      this.lastSent = { x: m.x, z: m.z };
      const jump = Math.hypot(from.x - m.x, from.z - m.z);
      if (jump > 3 && jump < 30) this.fx.dash(from, { x: m.x, y: groundY(m.x, m.z), z: m.z }, 0x9ad8ff);
      if (m.alive) { this.intent = null; ui.hideDeath(); }
    });
    n.on('st', (m) => {
      const now = performance.now();
      if (m.stun) { this.stunUntil = now + m.stun; this.ui.notice('Stordito!', true); }
      if (m.slow) this.slowUntil = now + m.slow;
    });
    n.on('chat', (m) => {
      ui.chatMsg(m);
      if (m.ch === 'say') { const e = this.ents.get(m.id); if (e) { e.bubble = m.m; e.bubbleUntil = performance.now() + 6000; e.labelKey = ''; } }
    });
    n.on('sys', (m) => ui.chat('sys', esc(m.m)));
    n.on('err', (m) => { ui.notice(m.m, true); });
    n.on('notice', (m) => { ui.notice(m.m); ui.chat('sys', esc(m.m)); });
    n.on('gain', (m) => {
      const s = this.self;
      if (m.exp) this.fx.number(new THREE.Vector3(s.x, s.y + 2.8, s.z), `+${m.exp} esp`, 'gain');
      if (m.tael) { ui.chat('gain', `+${m.tael} tael`); this.sound('coin'); }
      if (m.item) {
        const R = RARITIES[m.r || 0];
        ui.chat('gain', `Hai raccolto: <b style="color:${R.color}">${esc(m.item)}</b>${m.n > 1 ? ' x' + m.n : ''}${m.up ? ' +' + m.up : ''}${m.r ? ` (${R.name})` : ''}`);
        if (m.r >= 3) { ui.notice(`${R.name}: ${m.item}!`); this.sound('lvl'); } else this.sound('coin');
      }
    });
    n.on('dead', (m) => { this.intent = null; ui.showDeath(m.by, m.lost); this.sound('die'); });
    n.on('party', (m) => {
      const was = this.party;
      this.party = m.none ? null : m;
      if (!this.party && was) ui.notice('Non sei più in un gruppo');
      ui.renderParty();
      for (const e of this.ents.values()) e.labelKey = '';
      if (this.target) ui.updateTarget(this.target);
    });
    n.on('pinv', (m) => {
      this.sound('proc');
      ui.confirm(`<b>${esc(m.n)}</b> ti invita nel suo gruppo. Accetti?`, () => this.net.send({ t: 'preply', ok: 1 }));
      const no = document.getElementById('confirm-no');
      const prev = no.onclick;
      no.onclick = () => { this.net.send({ t: 'preply', ok: 0 }); prev && prev(); };
    });
    n.on('applied', (m) => { ui.chat('sys', esc(m.m)); ui.notice(m.m); this.sound(m.m.includes('non') ? 'die' : 'ok'); });
    n.on('stable', (m) => ui.openStable(m));
    n.on('trial', (m) => ui.openTrial(m));
    n.on('dg_start', (m) => {
      this.dg = { ox: m.ox, oz: m.oz, kl: m.kl, affixes: m.affixes };
      this.dgState = null;
      this.world.buildDungeon(m.ox, m.oz);
      this.dots = {};
      ui.closeAll();
      ui.renderDungeonHud();
    });
    n.on('dg', (m) => { this.dgState = m; this.dgStateAt = performance.now(); ui.renderDungeonHud(); });
    n.on('dg_end', () => { this.dg = null; this.dgState = null; ui.renderDungeonHud(); });
    n.on('dg_reward', (m) => {
      ui.chat('gain', `<b>Ricompense della Prova:</b> ${m.got.map(esc).join(' · ')}`);
      this.sound('lvl');
    });
    n.on('shop', (m) => ui.openShop(m));
    n.on('smith', (m) => ui.openSmith(m));
    n.on('smith_res', (m) => ui.onSmithResult(m));
    n.on('dialog', (m) => ui.openDialog(m));
  }

  onFx(m) {
    const s = this.ents.get(m.s), d = this.ents.get(m.d);
    const near = (e) => e && this.self && Math.hypot(e.x - this.self.x, e.z - this.self.z) < 70;
    switch (m.k) {
      case 'hit': {
        if (m.s === this.myId && m.v > 0) this.meter.add(m.sk || 'auto', m.v, m.c);
        if (m.a && s) {
          if (d) s.face(d);
          if (!s.self || m.a !== 1) s.rig.anim.attack();
          if (m.a === 2 && d) this.vfx.arrowShot(s, d, 0xffe8b0);
          if (m.a === 3 && d) this.vfx.projectile(s, d, s.info.k === 'm' ? 0xff8a3a : 0xfff0b0, { size: 0.35, trail: 4, dur: 0.25 });
        }
        if (!d) return;
        if (m.v > 0) d.rig.anim.hit();
        if (m.v > 0 && !m.dot && near(d)) {
          const gt = s && s.rig.gear && s.rig.gear.tier;
          this.vfx.impact(new THREE.Vector3(d.x, d.y + (d.rig.height || 2) * 0.55, d.z), gt ? gt.c1 : m.c ? 0xffd070 : 0xffe8c0, !!m.c);
          if (m.c && ((s && s.self) || d.self)) this.shake = Math.max(this.shake, 0.18);
          // Impatto: i colpi pesanti (tecniche che consumano, critici, colpi grossi) fermano il tempo per un istante
          if (s && s.self) {
            const sk = SKILLS[m.sk], peso = m.v / Math.max(1, d.mhp || m.v);
            const forte = (sk && (sk.cost >= 20 || sk.spend)) || peso > 0.12;
            if (forte || m.c) {
              this.hitStop = Math.max(this.hitStop || 0, forte && m.c ? 0.085 : forte ? 0.06 : 0.035);
              this.shake = Math.max(this.shake, forte && m.c ? 0.32 : forte ? 0.22 : 0.18);
            }
          }
        }
        const pos = new THREE.Vector3(d.x, d.y + (d.rig.height || 2) + 0.3, d.z);
        if (m.miss) { if (d.self || (s && s.self)) this.fx.number(pos, 'Schivato', 'miss'); return; }
        if (d.self) { this.fx.number(pos, m.ab ? `-${m.v} (${m.ab} assorbiti)` : `-${m.v}`, m.dot ? 'dot' : 'hurt'); }
        else if (s && s.self) { this.fx.number(pos, m.c ? `${m.v}!` : `${m.v}`, m.dot ? 'dot' : m.c ? 'crit' : 'mine'); if (!m.dot) this.sound(m.c ? 'crit' : 'hit'); }
        else if (m.dot && near(d)) this.fx.number(pos, `${m.v}`, 'dot');
        if (d.info.k === 'm' || d.info.k === 'p') { d.hp = Math.max(0, d.hp - m.v); d.labelKey = ''; }
        return;
      }
      case 'sk': {
        if (!s) return;
        const sk = SKILLS[m.sk];
        const tgt = d || s;
        if (d && d !== s) s.face(d);
        const melee = ['spin', 'quake', 'slash', 'dash'].includes(sk.fx);
        if (!m.ally) { if (melee) s.rig.anim.attack(); else s.rig.anim.castSpell(); }
        const at = m.x !== undefined ? { x: m.x, y: groundY(m.x, m.z), z: m.z } : tgt;
        this.vfx.skill(m.sk, sk, s, d, at);
        if (sk.sup && (s.self || near(s))) {      // Tecnica Suprema: rallentatore, lampo a schermo e scossa lunga
          this.slowT = 0.45;
          this.shake = Math.max(this.shake, 0.55);
          const lampo = document.createElement('div');
          lampo.className = 'lampo-suprema';
          lampo.style.setProperty('--c', '#' + (sk.color ?? 0xffffff).toString(16).padStart(6, '0'));
          document.body.appendChild(lampo);
          setTimeout(() => lampo.remove(), 900);
        }
        if (s.self) this.sound('skill');
        return;
      }
      case 'heal': {
        if (!d) return;
        if (d.self || near(d)) this.fx.number(new THREE.Vector3(d.x, d.y + 2.6, d.z), `+${m.v}`, 'heal');
        if (!m.q) this.vfx.rise(d, 0x7fff9f, 14, { to: 0xffffff, radius: 0.6 });
        return;
      }
      case 'die': if (d) { d.rig.anim.die(); if (d.info.k === 'm') d.hp = 0; if (this.target === d && !d.self) setTimeout(() => { if (this.target === d) this.setTarget(null); }, 600); } return;
      case 'lvl': if (s) { this.vfx.levelUp(s); if (s.self) this.sound('lvl'); } return;
      case 'stun': if (d) { d.rig.anim.stun = m.ms / 1000; this.fx.ring(d, 0xffff80, 1.5, 0.5, (d.rig.height || 2) + 0.2); } return;
      case 'post': {      // la Postura si spezza: il nemico è Squilibrato (stordito e vulnerabile) per m.ms
        if (!d) return;
        d.po = 0; d.sqOn = true; d.labelKey = '';
        d.rig.anim.stun = m.ms / 1000;
        const h = d.rig.height || 2, rr = (d.radius || 1) + 3.5;
        const centro = new THREE.Vector3(d.x, d.y + h * 0.6, d.z);
        if (near(d)) {
          this.vfx.flash(centro, 0xffe08a, 2.2 + h * 0.5, 0.22);
          this.vfx.burst(centro, 0xffd060, 46, 9, 0.22, 0.7, { to: 0xff8030, grav: 6 });
          this.vfx.shockwave(d, 0xffe08a, rr, 0.5);
          this.vfx.shockwave(d, 0xff9040, rr * 1.6, 0.8, 0.25);
          this.fx.ring(d, 0xffe08a, 2.2, 0.6, h + 0.2);
          this.fx.number(new THREE.Vector3(d.x, d.y + h + 0.9, d.z), 'Squilibrato!', 'post');
          this.shake = Math.max(this.shake, d === this.target ? 0.35 : 0.2);
          if (d === this.target) { this.hitStop = Math.max(this.hitStop || 0, 0.07); this.sound('crit'); }
        }
        return;
      }
      case 'slam': this.vfx.skill('scossa', { color: 0xff4020, radius: m.r, type: 'aoe_self' }, { x: m.x, y: groundY(m.x, m.z), z: m.z, r: 0 }, null, null); if (s) s.rig.anim.attack(); return;
      case 'wave': if (s) { this.vfx.shockwave(s, 0xc060ff, 10, 0.9); this.vfx.swirl(s, 0xd080ff, 0.8, 80, { radius: 2, height: 4 }); this.vfx.smokePuff({ x: s.x, y: groundY(s.x, s.z), z: s.z }, 0x4a2a6a, 24, 1.5, 1.2, { speed: 8 }); } return;
      case 'tp': if (s) { this.vfx.pillar(s, 0x8ad0ff, 1.2, 14, 1.0); this.vfx.swirl(s, 0xc0e8ff, 0.8, 60); } return;
      case 'cast': if (s && !s.self) s.rig.anim.channel = m.ms / 1000; return;
      case 'castend': if (s && !s.self) s.rig.anim.channel = 0; return;
      case 'warn': this.fx.warn({ x: m.x, z: m.z }, m.r, m.ms); this.sound('proc'); return;
      case 'hazard': this.fx.hazard({ x: m.x, z: m.z }, m.r, m.ms); return;
      case 'proc': {
        const b = BUFFS[m.b];
        if (s && s.self && b) { this.sound('proc'); this.fx.ring(s, 0xffd060, 1.8, 0.4, 1.2); this.ui.chat('gain', `Effetto attivo: <b>${esc(b.name)}</b>`); }
        return;
      }
    }
  }

  // ------------------------------------------------------------ input
  attachInput() {
    const canvas = this.renderer.domElement;
    const chatInput = document.getElementById('chat-input');
    addEventListener('keydown', (e) => {
      if (!this.active) return;
      if (document.activeElement === chatInput) {
        if (e.key === 'Enter') {
          const v = chatInput.value.trim();
          if (v) this.net.send({ t: 'chat', m: v });
          chatInput.value = ''; chatInput.blur();
        } else if (e.key === 'Escape') chatInput.blur();
        return;
      }
      if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
      if (e.key === 'Enter') { chatInput.focus(); e.preventDefault(); return; }
      if (e.key === 'Alt') e.preventDefault();
      if (e.code === 'Tab') { e.preventDefault(); this.cycleTarget(); return; }
      if (e.code === 'Space') { e.preventDefault(); this.attackKey(); return; }
      if (e.code.startsWith('Digit')) { const n = +e.code.slice(5); const i = n === 0 ? 9 : n - 1; if (i < QB_SIZE) this.useQuickbar(i); return; }
      switch (e.code) {
        case 'KeyI': this.ui.toggle('win-inventory'); return;
        case 'KeyC': this.ui.toggle('win-character'); return;
        case 'KeyK': this.ui.toggle('win-skills'); return;
        case 'KeyP': this.ui.toggle('win-dps'); return;
        case 'KeyR': this.toggleMount(); return;
        case 'KeyV': this.useSuprema(); return;
        case 'KeyH': case 'F1': e.preventDefault(); this.ui.toggle('win-help'); return;
        case 'KeyZ': this.pickupNear(); return;
        case 'Escape': if (!this.ui.closeAll()) { this.setTarget(null); this.intent = null; } return;
      }
      this.keys.add(e.code);
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('blur', () => this.keys.clear());

    let down = null, rot = null;
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    canvas.addEventListener('mousedown', (e) => {
      if (!this.active) return;
      if (document.activeElement === chatInput) chatInput.blur();
      if (e.button === 0) down = { x: e.clientX, y: e.clientY };
      if (e.button === 2) rot = { x: e.clientX, y: e.clientY };
    });
    addEventListener('mousemove', (e) => {
      this.mouse = { x: e.clientX, y: e.clientY };
      if (rot) {
        this.yaw -= (e.clientX - rot.x) * 0.006;
        this.pitch = Math.max(0.12, Math.min(1.35, this.pitch + (e.clientY - rot.y) * 0.005));
        rot = { x: e.clientX, y: e.clientY };
      }
    });
    addEventListener('mouseup', (e) => {
      if (e.button === 2) rot = null;
      if (e.button === 0 && down) {
        const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
        down = null;
        if (moved < 6 && e.target === canvas) this.click(e.clientX, e.clientY);
      }
    });
    canvas.addEventListener('wheel', (e) => { this.dist = Math.max(5, Math.min(32, this.dist * (e.deltaY > 0 ? 1.1 : 0.9))); e.preventDefault(); }, { passive: false });
  }

  pickAt(cx, cy) {
    const ndc = new THREE.Vector2(cx / innerWidth * 2 - 1, -(cy / innerHeight) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const hits = this.raycaster.intersectObjects(this.pickMeshes, false);
    for (const h of hits) { const e = h.object.userData.ent; if (e && !e.self) return { ent: e }; }
    const ray = this.raycaster.ray, p = new THREE.Vector3();
    let t = 0;
    for (let i = 0; i < 500; i++) {
      t += 0.5;
      p.copy(ray.origin).addScaledVector(ray.direction, t);
      if (p.y < heightAt(p.x, p.z)) return { ground: p };
    }
    return {};
  }

  click(cx, cy) {
    if (!this.self || this.me?.dead) return;
    const r = this.pickAt(cx, cy);
    if (r.ent) {
      const e = r.ent, k = e.info.k;
      this.setTarget(e);
      if (k === 'n') this.intent = { type: 'npc', id: e.id };
      else if (k === 'd') this.intent = { type: 'pick', id: e.id };
      else if (this.isHostile(e)) this.intent = { type: 'attack', id: e.id };
      return;
    }
    if (r.ground) {
      this.intent = { type: 'move', x: r.ground.x, z: r.ground.z };
      this.fx.ring({ x: r.ground.x, z: r.ground.z }, 0xffe08a, 1.2, 0.4);
    }
  }

  hoverUpdate() {
    if (!this.mouse || this.ui.drag) return;
    const el = document.elementFromPoint(this.mouse.x, this.mouse.y);
    const canvas = this.renderer.domElement;
    if (el !== canvas) return;
    const r = this.pickAt(this.mouse.x, this.mouse.y);
    let cur = 'default';
    if (r.ent) cur = this.isHostile(r.ent) ? 'crosshair' : 'pointer';
    if (canvas.style.cursor !== cur) canvas.style.cursor = cur;
  }

  inParty(id) { return !!(this.party && this.party.members.some(m => m.id === id)); }

  isHostile(e) {
    if (!e || e === this.self) return false;
    if (e.info.k === 'm') return e.hp > 0;
    if (e.info.k === 'p') {
      if (!this.pvp || e.info.kd === this.kd || e.hp <= 0 || !this.me) return false;
      if (this.me.lvl < this.pvpMin || e.lvl < this.pvpMin) return false;
      if (safeZoneAt(this.self.x, this.self.z) || safeZoneAt(e.x, e.z)) return false;
      return true;
    }
    return false;
  }

  setTarget(e) {
    if (this.target) this.target.labelKey = '';
    this.target = e;
    if (e) e.labelKey = '';
    this.ui.updateTarget(e);
  }

  nearestHostile(maxD = 22, skip) {
    let best = null, bd = maxD;
    for (const e of this.ents.values()) {
      if (e === skip || !this.isHostile(e)) continue;
      const d = Math.hypot(e.x - this.self.x, e.z - this.self.z);
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  cycleTarget() {
    const list = [...this.ents.values()].filter(e => this.isHostile(e) && Math.hypot(e.x - this.self.x, e.z - this.self.z) < 25)
      .sort((a, b) => Math.hypot(a.x - this.self.x, a.z - this.self.z) - Math.hypot(b.x - this.self.x, b.z - this.self.z));
    if (!list.length) return;
    const i = list.indexOf(this.target);
    this.setTarget(list[(i + 1) % list.length]);
  }

  attackKey() {
    if (!this.self || this.me?.dead) return;
    let t = this.target && this.isHostile(this.target) ? this.target : this.nearestHostile();
    if (!t) return;
    this.setTarget(t);
    this.intent = { type: 'attack', id: t.id };
  }

  pickupNear() {
    let best = null, bd = 8;
    for (const e of this.ents.values()) {
      if (e.info.k !== 'd') continue;
      if (e.info.own && e.info.own !== this.myId && !(e.info.op && this.party && e.info.op === this.party.id)) continue;
      const d = Math.hypot(e.x - this.self.x, e.z - this.self.z);
      if (d < bd) { bd = d; best = e; }
    }
    if (best) this.intent = { type: 'pick', id: best.id, chain: true };
  }

  toggleMount() {
    if (!this.me || this.me.dead) return;
    if (!this.me.horse) return this.ui.notice('Non hai un destriero: parla con lo Stalliere del villaggio', true);
    this.net.send({ t: 'mount' });
  }

  // Barra rapida effettiva: in sella le prime quattro caselle diventano le tecniche a cavallo.
  qbView() {
    const me = this.me;
    if (!me) return [];
    if (!me.mounted) return me.qb;
    const v = Array(QB_SIZE).fill(null);
    MOUNT_SKILLS.forEach((s, i) => { v[i] = { k: 's', id: s }; });
    v[QB_SIZE - 2] = me.qb[QB_SIZE - 2]; v[QB_SIZE - 1] = me.qb[QB_SIZE - 1];
    return v;
  }

  useQuickbar(i) {
    const q = this.qbView()[i];
    if (!q) return;
    if (q.k === 's') this.useSkill(q.id);
    else {
      const slot = (this.inv || []).findIndex(s => s && s.id === q.id);
      if (slot >= 0) this.net.send({ t: 'use', i: slot });
      else this.ui.notice('Non ne hai più', true);
    }
  }

  // ------------------------------------------------------------ abilità
  lvlOf(sid) {
    const sk = SKILLS[sid], me = this.me;
    if (sk && sk.mount) return me && me.mounted && me.horse && me.horse.lvl >= sk.hlvl ? Math.min(20, me.horse.lvl) : 0;
    if (!sk || !me || sk.cls !== this.cls || me.lvl < sk.lvl) return 0;
    if (sk.via && sk.via !== me.via) return 0;
    return Math.max(1, me.sk[sid] || 0);
  }

  chainList() {
    const me = this.me;
    if (!me) return null;
    const v = me.via && VIE[me.via].passive.chain;
    return v || CLASSES[this.cls].chain || null;
  }

  hasBuffWith(key, sid) { return (this.me.buffs || []).some(b => { const d = BUFFS[b.b]; return d && d[key] && d[key].includes(sid); }); }

  costOf(sk) {
    const me = this.me;
    if (!sk.cost || this.hasBuffWith('free', sk.id)) return 0;
    let c = sk.cost;
    for (const b of me.buffs || []) { const cm = BUFFS[b.b] && BUFFS[b.b].costMod; if (cm && cm[sk.id]) c += cm[sk.id]; }
    c = Math.max(0, c);
    return me.rt === 'mana' ? Math.round(me.rmax * c / 100) : c;
  }

  // Stato del tasto nella barra rapida: '' pronto, 'proc' potenziato, 'nores' risorsa insufficiente, 'unusable'.
  skillState(sid) {
    const sk = SKILLS[sid], me = this.me;
    if (!this.lvlOf(sid)) return 'unusable';
    if (sk.req && (!this.eq || !this.eq.weapon || ITEMS[this.eq.weapon.id].wt !== sk.req)) return 'unusable';
    const proc = this.hasBuffWith('free', sid) || this.hasBuffWith('instant', sid) || (me.buffs || []).some(b => {
      const d = BUFFS[b.b];
      return d && ((d.skillDmg && d.skillDmg[sid]) || (sk.spend && d.spenderDmg) || (d.behind && d.consume && d.consume.includes(sid)));
    });
    if (this.costOf(sk) > me.res) return 'nores';
    if (sk.spend && sk.type !== 'heal_aoe' && me.pts < (sk.minPts || 1)) return 'unusable';
    if (sk.execute) { const t = this.target; return t && t.mhp && t.hp / t.mhp <= sk.execute ? 'proc' : 'unusable'; }
    if (sk.spend && sk.type !== 'heal_aoe' && me.pts >= 5) return 'proc';
    return proc ? 'proc' : '';
  }

  useSkill(sid) {
    const sk = SKILLS[sid], me = this.me;
    if (!sk || !me || me.dead) return;
    if (me.mounted && !sk.mount) return this.ui.notice('Scendi da cavallo (R) per usare le tecniche della tua classe', true);
    if (!this.lvlOf(sid)) return this.ui.notice(sk.mount ? (me.mounted ? `Serve un destriero di livello ${sk.hlvl}` : 'Le tecniche a cavallo si usano in sella (R)') : sk.via && me.via !== sk.via ? "Appartiene a un'altra Via" : `Si sblocca al livello ${sk.lvl}`, true);
    const now = performance.now();
    const busyUntil = Math.max(sk.offgcd ? 0 : this.gcdUntil, sk.offgcd ? 0 : (this.casting ? this.casting.until : 0), this.cds[sid] ? this.cds[sid].until : 0);
    if (busyUntil > now + 30) {
      if (busyUntil - now < 450) { this.queued = sid; this.queuedAt = now; }
      else if (this.cds[sid] && this.cds[sid].until > now + 450) this.ui.notice('Abilità in ricarica', true);
      return;
    }
    if ((this.localLock[sid] || 0) > now) return;
    const st = this.skillState(sid);
    if (st === 'nores') return this.ui.notice(`${RESOURCES[me.rt].name} insufficiente`, true);
    if (st === 'unusable') {
      if (sk.req) return this.ui.notice(sk.req === 'bow' ? 'Serve un arco equipaggiato' : 'Servono dei pugnali equipaggiati', true);
      if (sk.execute) return this.ui.notice(`Il bersaglio deve essere sotto il ${Math.round(sk.execute * 100)}% di vita`, true);
      return this.ui.notice(`Servono almeno ${sk.minPts || 1} ${(CLASSES[this.cls].pts || {}).name || 'punti'}`, true);
    }
    if (['strike', 'aoe_target', 'debuff', 'taunt'].includes(sk.type)) {
      const t = this.target && this.isHostile(this.target) ? this.target : this.nearestHostile();
      if (!t) return this.ui.notice('Nessun bersaglio', true);
      this.setTarget(t);
      const d = Math.hypot(t.x - this.self.x, t.z - this.self.z) - (t.radius || 0.5);
      if (d > this.skillRange(sk) - 0.25) { this.intent = { type: 'skill', sid, id: t.id }; return; }
      this.self.face(t);
      this.castSkill(sid, t.id);
      if (!this.intent || this.intent.id !== t.id) this.intent = { type: 'attack', id: t.id };
      return;
    }
    let id = null;
    if (['heal_target', 'hot_target', 'shield', 'heal_aoe'].includes(sk.type) && this.target && this.target.info.k === 'p' && this.target.info.kd === this.kd) id = this.target.id;
    this.castSkill(sid, id);
  }

  castSkill(sid, id) {
    const sk = SKILLS[sid], now = performance.now();
    this.localLock[sid] = now + 300;
    if (!sk.offgcd) {
      this.optimistic = { sid, prev: this.gcdUntil };
      this.gcdUntil = now + (this.me.gcd || 1000); this.gcdTotal = this.me.gcd || 1000;
    }
    if (this.queued === sid) this.queued = null;
    this.net.send({ t: 'skill', s: sid, id });
  }

  skillRange(sk) { return sk.range === 'weapon' ? this.me.range : (sk.range || 2.5); }

  processQueue(now) {
    if (!this.queued) return;
    if (now - this.queuedAt > 700) { this.queued = null; return; }
    const sk = SKILLS[this.queued];
    const busy = Math.max(sk.offgcd ? 0 : this.gcdUntil, sk.offgcd ? 0 : (this.casting ? this.casting.until : 0), this.cds[this.queued] ? this.cds[this.queued].until : 0);
    if (busy <= now + 20) { const q = this.queued; this.queued = null; this.useSkill(q); }
  }

  useSuprema() {
    const sk = supremaOf(this.cls);
    if (sk) this.useSkill(sk.id);
  }

  // ------------------------------------------------------------ aggiornamento
  update(dt) {
    if (!this.active || !this.self) return;
    const now = performance.now();
    this.processQueue(now);
    if (this.hitStop > 0) { this.hitStop -= dt; dt *= 0.06; }
    else if (this.slowT > 0) { this.slowT -= dt; dt *= 0.32; }
    this.updateSelf(dt, now);
    for (const e of this.ents.values()) e.update(dt);
    this.updateCamera(dt);
    this.world.setIndoor(this.self.x > DUNGEON_X);
    this.updateLabels(now);
    if (this.target) {
      if (!this.ents.has(this.target.id)) this.setTarget(null);
      else this.ui.updateTarget(this.target);
    }
    this.fx.update(dt);
    this.vfx.update(dt);
    this.ui.updateCooldowns(now);
    this.ui.updateDeath(now);
    this.mmT = (this.mmT || 0) + dt;
    if (this.mmT > 0.1) { this.mmT = 0; this.ui.drawMinimap(this.self, this.ents, this.target); this.hoverUpdate(); this.ui.renderParty(); }
  }

  updateSelf(dt, now) {
    const s = this.self, me = this.me;
    if (!me) return;
    let mx = 0, mz = 0;
    const blocked = me.dead || this.stunUntil > now;
    if (!blocked) {
      const fwd = (this.keys.has('KeyW') || this.keys.has('ArrowUp') ? 1 : 0) - (this.keys.has('KeyS') || this.keys.has('ArrowDown') ? 1 : 0);
      const side = (this.keys.has('KeyD') || this.keys.has('ArrowRight') ? 1 : 0) - (this.keys.has('KeyA') || this.keys.has('ArrowLeft') ? 1 : 0);
      if (this.keys.has('KeyQ')) this.yaw += dt * 2.2;
      if (this.keys.has('KeyE')) this.yaw -= dt * 2.2;
      if (fwd || side) {
        this.intent = null;
        const sy = Math.sin(this.yaw), cy = Math.cos(this.yaw);
        mx = -sy * fwd + cy * side; mz = -cy * fwd - sy * side;
        const l = Math.hypot(mx, mz); mx /= l; mz /= l;
      } else {
        const dir = this.updateIntent(now);
        if (dir) { mx = dir[0]; mz = dir[1]; }
      }
    }
    const spd = me.spd * (this.slowUntil > now ? 0.5 : 1);
    if ((mx || mz) && this.casting) { this.net.send({ t: 'cancel' }); this.casting = null; s.rig.anim.channel = 0; }
    if (mx || mz) {
      let nx = s.x + mx * spd * dt, nz = s.z + mz * spd * dt;
      if (this.dg && s.x > DUNGEON_X) {
        // dentro la cripta: si cammina solo nelle stanze e nei corridoi (scivolando lungo i muri)
        const ok = (x, z) => dungeonWalkable(x - this.dg.ox, z - this.dg.oz, 0.5);
        if (!ok(nx, nz)) { if (ok(nx, s.z)) nz = s.z; else if (ok(s.x, nz)) nx = s.x; else { nx = s.x; nz = s.z; } }
      } else {
        [nx, nz] = resolveCollisions(nx, nz, 0.5, this.colliders);
        nx = Math.max(-PLAY_LIMIT, Math.min(PLAY_LIMIT, nx));
        nz = Math.max(-PLAY_LIMIT, Math.min(PLAY_LIMIT, nz));
      }
      const moved = Math.hypot(nx - s.x, nz - s.z);
      s.x = nx; s.z = nz;
      s.r = angLerp(s.r, Math.atan2(mx, mz), Math.min(1, dt * 14));
      s.speed = moved / Math.max(dt, 1e-4);
    } else s.speed = 0;
    if (now - this.lastMoveSent > 100) {
      if (Math.hypot(s.x - this.lastSent.x, s.z - this.lastSent.z) > 0.05 || Math.abs(s.r - (this.lastSent.r || 0)) > 0.1) {
        this.net.send({ t: 'move', x: Math.round(s.x * 100) / 100, z: Math.round(s.z * 100) / 100, r: Math.round(s.r * 100) / 100 });
        this.lastSent = { x: s.x, z: s.z, r: s.r };
      }
      this.lastMoveSent = now;
    }
  }

  // Restituisce la direzione di movimento per raggiungere l'obiettivo corrente, oppure null.
  updateIntent(now) {
    const it = this.intent, s = this.self;
    if (!it) return null;
    const toward = (x, z, stop) => {
      const dx = x - s.x, dz = z - s.z, d = Math.hypot(dx, dz);
      if (d <= stop) return null;
      return [dx / d, dz / d];
    };
    if (it.type === 'move') {
      const dir = toward(it.x, it.z, 0.4);
      if (!dir) this.intent = null;
      return dir;
    }
    const e = this.ents.get(it.id);
    if (!e) { this.intent = null; return null; }
    if (this.casting) return null;
    const d = Math.hypot(e.x - s.x, e.z - s.z) - (e.radius || 0.5);
    if (it.type === 'attack') {
      if (!this.isHostile(e)) { this.intent = null; return null; }
      const range = this.me.range;
      if (d > range - 0.25) return toward(e.x, e.z, 0);
      s.face(e);
      if (now >= this.nextAttack && !(this.casting && CLASSES[this.cls].autoMagic)) {
        this.net.send({ t: 'atk', id: e.id });
        this.nextAttack = now + this.me.aspd;
        s.rig.anim.attack();
      }
      return null;
    }
    if (it.type === 'skill') {
      if (!this.isHostile(e)) { this.intent = null; return null; }
      const sk = SKILLS[it.sid];
      if (d > this.skillRange(sk) - 0.25) return toward(e.x, e.z, 0);
      s.face(e);
      this.intent = { type: 'attack', id: e.id };
      this.useSkill(it.sid);
      return null;
    }
    if (it.type === 'npc') {
      if (d > 2.5) return toward(e.x, e.z, 0);
      s.face(e);
      this.net.send({ t: 'npc', id: e.id });
      this.intent = null;
      return null;
    }
    if (it.type === 'pick') {
      if (d > 0.6) return toward(e.x, e.z, 0);
      this.net.send({ t: 'pick', id: e.id });
      this.intent = null;
      if (it.chain) setTimeout(() => this.pickupNear(), 250);
      return null;
    }
    return null;
  }

  updateCamera(dt) {
    const s = this.self;
    const want = new THREE.Vector3(s.x, s.y + 1.8 + (this.me && this.me.mounted ? 1.1 : 0), s.z);
    this.camTarget.lerp(want, Math.min(1, dt * 12));
    const cp = Math.cos(this.pitch), sp = Math.sin(this.pitch);
    const cam = this.camera;
    cam.position.set(
      this.camTarget.x + Math.sin(this.yaw) * cp * this.dist,
      this.camTarget.y + sp * this.dist,
      this.camTarget.z + Math.cos(this.yaw) * cp * this.dist,
    );
    const gh = heightAt(cam.position.x, cam.position.z) + 0.8;
    if (cam.position.y < gh) cam.position.y = gh;
    cam.lookAt(this.camTarget);
    if (this.vfx.shake > 0) { this.shake = Math.max(this.shake, this.vfx.shake); this.vfx.shake = 0; }
    if (this.shake > 0) {
      this.shake = Math.max(0, this.shake - dt);
      const k = this.shake * 0.6;
      cam.position.x += (Math.random() - 0.5) * k; cam.position.y += (Math.random() - 0.5) * k;
    }
  }

  updateLabels(now) {
    const v = new THREE.Vector3();
    const s = this.self;
    for (const e of this.ents.values()) {
      if (e.self) continue;
      const lbl = e.label;
      const dist = Math.hypot(e.x - s.x, e.z - s.z);
      const k = e.info.k;
      const maxD = k === 'd' ? 25 : 55;
      const dropHidden = k === 'd' && !(e.info.r >= 1 || dist < 2.2 || this.keys.has('AltLeft') || this.keys.has('AltRight'));
      if (dist > maxD || dropHidden || (k === 'm' && e.hp <= 0 && e.rig.anim.deadT >= 1)) { if (lbl.style.display !== 'none') lbl.style.display = 'none'; continue; }
      v.set(e.x, e.y + (e.rig.height || 2) + 0.35, e.z).project(this.camera);
      if (v.z > 1) { if (lbl.style.display !== 'none') lbl.style.display = 'none'; continue; }
      if (lbl.style.display === 'none') lbl.style.display = '';
      lbl.style.left = ((v.x * 0.5 + 0.5) * innerWidth).toFixed(1) + 'px';
      lbl.style.top = ((-v.y * 0.5 + 0.5) * innerHeight).toFixed(1) + 'px';
      const showHp = (k === 'm' || k === 'p') && (e === this.target || (e.hp < e.mhp && e.hp > 0));
      const bubble = e.bubble && e.bubbleUntil > now ? e.bubble : null;
      const showPo = showHp && k === 'm' && e.po !== undefined;
      const key = `${e.info.n}|${e.lvl}|${showHp ? Math.round(e.hp / Math.max(1, e.mhp) * 50) : -1}|${e === this.target}|${bubble}|${showPo ? Math.round(e.po / 4) : -1}|${e.sqOn && e.hp > 0 ? 1 : 0}`;
      if (key === e.labelKey) continue;
      e.labelKey = key;
      let cls = 'label', html = '';
      if (bubble) html += `<div class="bubble">${esc(bubble)}</div>`;
      if (k === 'm') {
        if (e.sqOn && e.hp > 0) html += '<div class="lsq">Squilibrato!</div>';
        cls += ' mob' + (e.aggr ? ' aggr' : '');
        html += `<div class="ln">${e.boss ? '☠ ' : ''}${esc(e.info.n)} <span style="color:#d8c8a0">Lv.${e.lvl}</span></div>`;
      } else if (k === 'p') {
        const kd = KINGDOMS[e.info.kd];
        html += `<div class="ln" style="color:${this.inParty(e.id) ? '#8aff9a' : kd.color}">${e.info.gm ? '[GM] ' : ''}${esc(e.info.n)} <span style="color:#d8c8a0">Lv.${e.lvl}</span></div>`;
      } else if (k === 'n') {
        cls += ' npc';
        html += `<div class="lt">${esc(NPC_ROLES[e.info.role].title)}</div><div class="ln">${esc(e.info.n)}</div>`;
      } else if (k === 'd') {
        const it = ITEMS[e.info.it];
        cls += ' drop' + (e.info.own && e.info.own !== this.myId && !(e.info.op && this.party && e.info.op === this.party.id) ? ' own' : '');
        const rc = e.info.r ? RARITIES[e.info.r].color : null;
        html += `<div class="ln"${rc ? ` style="color:${rc}"` : ''}>${esc(it ? it.name : '?')}${e.info.n > 1 ? ' x' + e.info.n : ''}${e.info.up ? ' +' + e.info.up : ''}</div>`;
      }
      if (e === this.target) cls += ' target';
      if (showHp) html += `<div class="lhp"><div style="width:${Math.max(0, e.hp / Math.max(1, e.mhp) * 100)}%"></div></div>`;
      if (showPo) html += `<div class="lpo${e.sqOn ? ' squil' : ''}"><div style="width:${Math.max(0, Math.min(100, e.po))}%"></div></div>`;
      lbl.className = cls;
      lbl.innerHTML = html;
    }
  }

  // ------------------------------------------------------------ suoni minimi (WebAudio)
  sound(kind) {
    try {
      if (!this.ac) this.ac = new (window.AudioContext || window.webkitAudioContext)();
      const ac = this.ac, t = ac.currentTime;
      const tone = (f, d, type = 'square', vol = 0.05, f2) => {
        const o = ac.createOscillator(), g = ac.createGain();
        o.type = type; o.frequency.setValueAtTime(f, t);
        if (f2) o.frequency.exponentialRampToValueAtTime(f2, t + d);
        g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + d);
        o.connect(g); g.connect(ac.destination); o.start(t); o.stop(t + d);
      };
      if (kind === 'hit') tone(180, 0.08, 'square', 0.035, 90);
      else if (kind === 'crit') { tone(260, 0.12, 'sawtooth', 0.05, 110); }
      else if (kind === 'skill') tone(520, 0.18, 'triangle', 0.05, 880);
      else if (kind === 'coin') { tone(1320, 0.07, 'square', 0.025); setTimeout(() => tone(1760, 0.09, 'square', 0.025), 60); }
      else if (kind === 'lvl') { [523, 659, 784, 1047].forEach((f, i) => setTimeout(() => tone(f, 0.25, 'triangle', 0.06), i * 110)); }
      else if (kind === 'ok') { tone(784, 0.12, 'triangle', 0.06); setTimeout(() => tone(1175, 0.2, 'triangle', 0.06), 100); }
      else if (kind === 'die') tone(220, 0.8, 'sawtooth', 0.05, 55);
      else if (kind === 'proc') { tone(880, 0.1, 'triangle', 0.05, 1320); setTimeout(() => tone(1320, 0.14, 'triangle', 0.04, 1760), 70); }
    } catch { /* audio non disponibile */ }
  }
}
