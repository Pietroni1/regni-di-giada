// Modelli procedurali low-poly per personaggi, mostri, PNG e oggetti a terra, con animazioni semplici.
import * as THREE from 'three';
import { ITEMS, CLASSES, MOBS } from '/shared/data.js';
import { KINGDOMS } from '/shared/world.js';
import { lam } from './world3d.js';

const geoCache = new Map();
function G(key, make) { let g = geoCache.get(key); if (!g) { g = make(); geoCache.set(key, g); } return g; }
const box = (w, h, d) => G(`b${w},${h},${d}`, () => new THREE.BoxGeometry(w, h, d));
const cyl = (a, b, h, s = 8) => G(`c${a},${b},${h},${s}`, () => new THREE.CylinderGeometry(a, b, h, s));
const sph = (r, w = 10, h = 8) => G(`s${r},${w},${h}`, () => new THREE.SphereGeometry(r, w, h));
const cone = (r, h, s = 8) => G(`k${r},${h},${s}`, () => new THREE.ConeGeometry(r, h, s));
const cap = (r) => G(`cap${r}`, () => new THREE.SphereGeometry(r, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.55));

function mesh(geo, mat, x = 0, y = 0, z = 0) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}
const withRot = (m, axis, v) => { m.rotation[axis] = v; return m; };
const glow = (c, i = 1) => new THREE.MeshLambertMaterial({ color: c, emissive: c, emissiveIntensity: i, flatShading: true });

// ------------------------------------------------------------------ armi
function weaponMesh(id, up) {
  const it = ITEMS[id];
  const g = new THREE.Group();
  if (!it) return g;
  const tier = it.tier || 1;
  const metalC = [0xa8a8a8, 0xb89a5a, 0x7ad0a0, 0xd8e4f0][tier - 1];
  const metal = up >= 7 ? glow(up >= 9 ? 0xffd860 : 0x9ad8ff, 0.35 + (up - 7) * 0.2) : lam(metalC);
  const wood = lam(0x4a3220), wrap = lam(0x2a1a14);
  switch (it.wt) {
    case 'sword': {
      g.add(mesh(cyl(0.035, 0.035, 0.28, 6), wrap, 0, 0, 0));
      g.add(mesh(box(0.26, 0.05, 0.1), lam(0x8a6a2a), 0, -0.15, 0));
      g.add(mesh(box(0.07, 1.15 + tier * 0.08, 0.025), metal, 0, -0.75 - tier * 0.04, 0));
      g.rotation.x = -1.35;
      break;
    }
    case 'daggers': {
      g.add(mesh(cyl(0.03, 0.03, 0.18, 6), wrap, 0, 0, 0));
      g.add(mesh(box(0.06, 0.5, 0.02), metal, 0, -0.32, 0));
      g.rotation.x = -1.4;
      break;
    }
    case 'bow': {
      const arc = new THREE.Mesh(G('bow', () => new THREE.TorusGeometry(0.8, 0.035, 4, 14, Math.PI * 0.85)), up >= 7 ? metal : lam(tier >= 3 ? 0x5a3a6a : 0x6a4a28));
      arc.rotation.set(0, Math.PI / 2, Math.PI / 2 + Math.PI * 0.075);
      arc.position.z = -0.25;
      g.add(arc);
      const str = mesh(box(0.01, 1.5, 0.01), lam(0xe0e0d0), 0, 0, 0.3);
      g.add(str);
      break;
    }
    case 'fists': {
      g.add(mesh(sph(0.13, 6, 5), up >= 7 ? metal : lam(tier >= 2 ? metalC : 0xe8e0c8), 0, -0.02, 0));
      if (tier >= 2) for (let i = 0; i < 3; i++) g.add(withRot(mesh(cone(0.025, 0.2, 4), metal, -0.06 + i * 0.06, -0.1, 0.1), 'x', 1.2));
      break;
    }
    case 'staff': {
      g.add(mesh(cyl(0.04, 0.05, 2.1, 6), wood, 0, 0.35, 0));
      const orb = mesh(sph(0.13, 8, 6), glow([0xfff0a0, 0x9ad8ff, 0x9affc0, 0xffa0f0][tier - 1], 0.8), 0, 1.5, 0);
      g.add(orb);
      g.add(mesh(G('ring', () => new THREE.TorusGeometry(0.18, 0.025, 4, 10)), lam(0xb8902a), 0, 1.5, 0));
      g.rotation.x = -0.15;
      break;
    }
  }
  return g;
}

// ------------------------------------------------------------------ umanoide
function humanoid(o) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const skin = lam(o.skin ?? 0xe0b48a);
  const robe = lam(o.robe), trim = lam(o.trim ?? 0x8a6a3a);
  const mkLeg = (sx) => {
    const pv = new THREE.Group(); pv.position.set(sx, 0.95, 0);
    pv.add(mesh(cyl(0.11, 0.09, 0.9, 6), lam(o.pants ?? 0x3a3a3a), 0, -0.45, 0));
    pv.add(mesh(box(0.16, 0.1, 0.3), lam(o.shoes ?? 0x2a1f18), 0, -0.9, 0.06));
    body.add(pv); return pv;
  };
  const legL = mkLeg(0.15), legR = mkLeg(-0.15);
  const torso = new THREE.Group(); torso.position.y = 0.95; body.add(torso);
  torso.add(mesh(cyl(0.3, 0.25, 0.78, 8), robe, 0, 0.42, 0));
  if (o.skirt !== false) torso.add(mesh(cyl(0.27, 0.44, 0.6, 8), robe, 0, -0.18, 0));
  torso.add(mesh(cyl(0.29, 0.29, 0.12, 8), lam(o.sash ?? 0x8a2020), 0, 0.08, 0));
  const collar = trim;
  const c1 = mesh(box(0.07, 0.5, 0.03), collar, 0.07, 0.55, 0.27); c1.rotation.z = 0.35; torso.add(c1);
  const c2 = mesh(box(0.07, 0.5, 0.03), collar, -0.07, 0.55, 0.27); c2.rotation.z = -0.35; torso.add(c2);
  if (o.armor) {
    const am = lam(o.armor);
    torso.add(mesh(box(0.52, 0.42, 0.12), am, 0, 0.5, 0.22));
    for (const s of [-1, 1]) { const sp = mesh(box(0.26, 0.12, 0.34), am, s * 0.36, 0.78, 0); sp.rotation.z = s * -0.35; torso.add(sp); }
    torso.add(mesh(cyl(0.3, 0.46, 0.3, 8), am, 0, -0.1, 0));
  }
  if (o.cape) { const cp = mesh(box(0.6, 1.2, 0.04), lam(o.cape), 0, 0.15, -0.3); cp.rotation.x = 0.12; torso.add(cp); }
  const mkArm = (sx) => {
    const pv = new THREE.Group(); pv.position.set(sx, 0.72, 0); torso.add(pv);
    pv.add(mesh(cyl(0.1, 0.13, 0.62, 6), lam(o.sleeve ?? o.robe), 0, -0.3, 0));
    pv.add(mesh(sph(0.08, 6, 5), skin, 0, -0.66, 0));
    const grip = new THREE.Group(); grip.position.set(0, -0.7, 0); pv.add(grip);
    return { pv, grip };
  };
  const armR = mkArm(-0.39), armL = mkArm(0.39);
  const head = new THREE.Group(); head.position.y = 0.88; torso.add(head);
  head.add(mesh(cyl(0.07, 0.08, 0.12, 6), skin, 0, 0, 0));
  if (o.faceless) {
    head.add(mesh(sph(0.21, 10, 8), lam(0xe8e4dc), 0, 0.22, 0));
    for (const s of [-1, 1]) head.add(mesh(box(0.07, 0.02, 0.02), glow(0xff2a1a, 1.5), s * 0.07, 0.24, 0.19));
  } else {
    head.add(mesh(sph(0.2, 10, 8), skin, 0, 0.2, 0));
    for (const s of [-1, 1]) head.add(mesh(box(0.045, 0.03, 0.02), lam(0x1a1210), s * 0.07, 0.22, 0.185));
  }
  const hairC = o.hair != null ? lam(o.hair) : null;
  switch (o.hairStyle) {
    case 'topknot': head.add(mesh(cap(0.215), hairC, 0, 0.22, -0.02)); head.add(mesh(sph(0.09, 6, 5), hairC, 0, 0.45, -0.04)); break;
    case 'long': head.add(mesh(cap(0.215), hairC, 0, 0.22, -0.02)); head.add(mesh(box(0.34, 0.5, 0.1), hairC, 0, 0.05, -0.15)); break;
    case 'bun': head.add(mesh(cap(0.215), hairC, 0, 0.22, -0.02)); head.add(mesh(sph(0.1, 6, 5), hairC, 0, 0.32, -0.18)); break;
    case 'hood': head.add(mesh(cap(0.25), lam(o.robe), 0, 0.18, -0.03)); head.add(mesh(box(0.36, 0.1, 0.06), lam(o.trim ?? 0x6b1e1e), 0, 0.12, 0.19)); break;
    case 'bald': break;
  }
  if (o.beard) head.add(withRot(mesh(cone(0.12, 0.45, 6), lam(0xe8e8e8), 0, -0.05, 0.12), 'x', Math.PI));
  const hatGroup = new THREE.Group(); head.add(hatGroup);
  return { root, body, torso, head, hatGroup, legL, legR, armL, armR, height: 2.3 };
}

function setHat(rig, id, color) {
  rig.hatGroup.clear();
  if (!id) return;
  const it = ITEMS[id];
  if (!it) return;
  if (id === 'cappello_paglia') {
    rig.hatGroup.add(mesh(cone(0.55, 0.32, 10), lam(0xc8a860), 0, 0.5, 0));
  } else {
    const c = [0, 0x9a7a4a, 0xa0a8b0, 0x6a8a7a, 0x8a3a3a][it.tier];
    rig.hatGroup.add(mesh(cap(0.24), lam(c), 0, 0.24, -0.01));
    rig.hatGroup.add(mesh(box(0.05, 0.22, 0.3), lam(color ?? 0xb02a1a), 0, 0.48, -0.02));
    if (it.tier >= 3) for (const s of [-1, 1]) { const h = mesh(cone(0.04, 0.35, 5), lam(0xd8c8a0), s * 0.2, 0.42, 0.05); h.rotation.z = s * -0.6; rig.hatGroup.add(h); }
  }
}

// ------------------------------------------------------------------ quadrupedi
function quadruped(o) {
  const root = new THREE.Group();
  const body = new THREE.Group(); root.add(body);
  const c = lam(o.color), c2 = lam(o.color2 ?? o.color);
  const L = o.len, H = o.legH;
  body.add(mesh(box(o.w, o.h, L), c, 0, H + o.h / 2, 0));
  if (o.hump) body.add(mesh(box(o.w * 0.9, o.h * 0.4, L * 0.4), c, 0, H + o.h, L * 0.15));
  const head = new THREE.Group(); head.position.set(0, H + o.h * 0.75, L / 2); body.add(head);
  head.add(mesh(box(o.hw, o.hh, o.hl), c, 0, 0, o.hl / 2));
  head.add(mesh(box(o.hw * 0.55, o.hh * 0.5, o.snout), c2, 0, -o.hh * 0.15, o.hl + o.snout / 2));
  head.add(mesh(box(o.hw * 0.25, o.hh * 0.2, 0.05), lam(0x111111), 0, -o.hh * 0.05, o.hl + o.snout));
  for (const s of [-1, 1]) {
    head.add(mesh(box(0.05, 0.05, 0.02), o.eyes ? glow(o.eyes, 1) : lam(0x111111), s * o.hw * 0.3, o.hh * 0.18, o.hl + 0.01));
    if (o.ears === 'point') head.add(mesh(cone(o.hw * 0.17, o.hh * 0.6, 4), c, s * o.hw * 0.32, o.hh * 0.65, o.hl * 0.3));
    if (o.ears === 'round') head.add(mesh(sph(o.hw * 0.16, 6, 5), c, s * o.hw * 0.42, o.hh * 0.5, o.hl * 0.2));
    if (o.tusks) { const t = mesh(cone(0.04, 0.25, 5), lam(0xf0e8d0), s * o.hw * 0.3, -o.hh * 0.1, o.hl + o.snout * 0.8); t.rotation.x = -0.6; head.add(t); }
  }
  const legs = [];
  for (const [sx, sz] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) {
    const pv = new THREE.Group(); pv.position.set(sx * o.w * 0.35, H, sz * L * 0.36);
    pv.add(mesh(box(o.legW, H, o.legW), c2, 0, -H / 2, 0));
    body.add(pv); legs.push(pv);
  }
  if (o.tail) { const t = mesh(box(0.1, 0.1, o.tail), c, 0, H + o.h * 0.8, -L / 2 - o.tail / 2 + 0.05); t.rotation.x = 0.5; body.add(t); }
  if (o.stripes) for (let i = 0; i < 5; i++) body.add(mesh(box(o.w + 0.02, o.h * 0.8, 0.08), lam(o.stripes), 0, H + o.h / 2 + 0.03, -L * 0.35 + i * L * 0.17));
  return { root, body, head, legs, quad: true, height: H + o.h + o.hh };
}

// ------------------------------------------------------------------ mostri speciali
function lanternSpirit(color) {
  const root = new THREE.Group(); const body = new THREE.Group(); root.add(body);
  const shell = mesh(cyl(0.55, 0.55, 1.0, 10), new THREE.MeshLambertMaterial({ color, emissive: color, emissiveIntensity: 0.6, transparent: true, opacity: 0.92 }), 0, 1.8, 0);
  body.add(shell);
  for (let i = 0; i < 4; i++) body.add(withRot(mesh(G('lr', () => new THREE.TorusGeometry(0.56, 0.02, 4, 12)), lam(0x2a1a10), 0, 1.4 + i * 0.27, 0), 'x', Math.PI / 2));
  body.add(mesh(cyl(0.3, 0.45, 0.15, 10), lam(0x1a1a1a), 0, 2.37, 0));
  body.add(mesh(cyl(0.45, 0.3, 0.15, 10), lam(0x1a1a1a), 0, 1.23, 0));
  for (const s of [-1, 1]) body.add(mesh(box(0.12, 0.16, 0.05), lam(0x1a0a05), s * 0.18, 1.95, 0.53));
  body.add(mesh(box(0.3, 0.08, 0.05), lam(0x1a0a05), 0, 1.68, 0.53));
  body.add(mesh(cone(0.12, 0.35, 6), glow(0xffe060, 1.2), 0, 2.6, 0));
  body.add(mesh(box(0.04, 0.5, 0.04), lam(0xb02020), 0, 0.92, 0));
  return { root, body, float: true, height: 2.8 };
}

// Fantoccio d'addestramento: palo di legno, corpo di paglia, testa di tela con bersaglio dipinto.
function trainingDummy() {
  const root = new THREE.Group(); const body = new THREE.Group(); root.add(body);
  const wood = lam(0x6a4a2a), straw = lam(0xc8a860), rope = lam(0x8a6a3a), cloth = lam(0xd8c8a0);
  root.add(mesh(cyl(0.6, 0.7, 0.25, 8), lam(0x5a4a3a), 0, 0.12, 0));
  body.add(mesh(cyl(0.09, 0.11, 2.0, 6), wood, 0, 1.0, 0));
  body.add(mesh(cyl(0.34, 0.3, 0.95, 8), straw, 0, 1.45, 0));
  for (const y of [1.12, 1.45, 1.78]) body.add(mesh(cyl(0.35, 0.35, 0.06, 8), rope, 0, y, 0));
  const arms = mesh(cyl(0.06, 0.06, 1.6, 6), wood, 0, 1.68, 0); arms.rotation.z = Math.PI / 2; body.add(arms);
  for (const s of [-1, 1]) body.add(withRot(mesh(cyl(0.12, 0.1, 0.35, 6), straw, s * 0.72, 1.68, 0), 'z', Math.PI / 2));
  body.add(mesh(sph(0.24, 8, 6), cloth, 0, 2.15, 0));
  body.add(withRot(mesh(cyl(0.12, 0.12, 0.02, 12), lam(0xa82a1a), 0, 2.16, 0.235), 'x', Math.PI / 2));
  body.add(withRot(mesh(cyl(0.05, 0.05, 0.025, 10), cloth, 0, 2.16, 0.245), 'x', Math.PI / 2));
  body.add(mesh(cone(0.08, 0.2, 5), straw, 0, 2.42, 0));
  return { root, body, dummy: true, height: 2.5 };
}

function obelisk(color, scale) {
  const root = new THREE.Group(); const body = new THREE.Group(); root.add(body);
  const stone = lam(0x2a2630);
  body.add(withRot(mesh(cyl(0.9, 1.5, 6.5, 4), stone, 0, 3.25, 0), 'y', Math.PI / 4));
  body.add(withRot(mesh(cone(0.95, 1.2, 4), stone, 0, 7.1, 0), 'y', Math.PI / 4));
  const rune = glow(color, 1.2);
  for (let i = 0; i < 4; i++) {
    const a = i * Math.PI / 2;
    for (let j = 0; j < 3; j++) {
      const r = mesh(box(0.12, 0.7, 0.05), rune, Math.sin(a) * (1.25 - j * 0.15), 1.4 + j * 1.6, Math.cos(a) * (1.25 - j * 0.15));
      r.rotation.y = a; body.add(r);
    }
  }
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * Math.PI * 2;
    const rk = mesh(G('rub', () => new THREE.DodecahedronGeometry(0.5, 0)), lam(0x3a3640), Math.cos(a) * 1.9, 0.2, Math.sin(a) * 1.9);
    rk.rotation.set(a, a * 2, 0); body.add(rk);
  }
  const shards = new THREE.Group(); body.add(shards);
  for (let i = 0; i < 5; i++) {
    const a = i / 5 * Math.PI * 2;
    shards.add(mesh(G('sh', () => new THREE.OctahedronGeometry(0.28, 0)), rune, Math.cos(a) * 2.4, 4 + Math.sin(i) * 0.8, Math.sin(a) * 2.4));
  }
  root.scale.setScalar(scale);
  return { root, body, shards, stone: true, height: 8 * scale };
}

// ------------------------------------------------------------------ fabbriche di modelli
function finish(rig, radius) {
  const pickH = rig.height;
  const pick = new THREE.Mesh(G(`pick${radius},${pickH}`, () => new THREE.CylinderGeometry(radius, radius, pickH, 8)), new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false }));
  pick.position.y = pickH / 2;
  rig.root.add(pick);
  rig.pick = pick;
  rig.radius = radius;
  rig.anim = new Anim(rig);
  return rig;
}

export function buildPlayerModel(info) {
  const c = CLASSES[info.cls];
  const k = KINGDOMS[info.kd];
  const look = c.look;
  const tier = info.b ? (ITEMS[info.b]?.tier || 1) : 0;
  const armor = tier >= 2 ? [0, 0, 0x7a6a50, 0x5a8a74, 0xb8c0c8][tier] : look.armor;
  const rig = humanoid({ robe: look.robe, trim: look.trim, pants: look.pants, hair: look.hair, hairStyle: look.hairStyle, sash: k.hex, armor, skirt: info.cls !== 'ombra' });
  applyWeapon(rig, info.w, info.wu);
  setHat(rig, info.h, k.hex);
  rig.weaponType = info.w ? ITEMS[info.w]?.wt : 'fists';
  return finish(rig, 0.6);
}

export function applyWeapon(rig, wid, up) {
  for (const g of [rig.armR.grip, rig.armL.grip]) g.clear();
  if (!wid) return;
  const it = ITEMS[wid];
  if (!it) return;
  if (it.wt === 'daggers' || it.wt === 'fists') {
    rig.armR.grip.add(weaponMesh(wid, up));
    rig.armL.grip.add(weaponMesh(wid, up));
  } else if (it.wt === 'bow') {
    rig.armL.grip.add(weaponMesh(wid, up));
  } else {
    rig.armR.grip.add(weaponMesh(wid, up));
  }
  rig.weaponType = it.wt;
}

const NPC_LOOKS = {
  armi: { robe: 0x6a4a2a, trim: 0x3a2a1a, pants: 0x3a2a1a, hair: 0x1a1210, hairStyle: 'topknot', armor: 0x5a4a3a, weapon: 'sciabola_bronzo' },
  erbe: { robe: 0x5a7a4a, trim: 0xd8d0a0, pants: 0x4a5a3a, hair: 0xd8d8d8, hairStyle: 'bun', skin: 0xd8a880 },
  fabbro: { robe: 0x3a3430, trim: 0x8a5a2a, pants: 0x2a2420, hair: null, hairStyle: 'bald', armor: 0x4a3a2a, skin: 0xc89870 },
  maestro: { robe: 0xe8e4d8, trim: 0x8a2a2a, pants: 0xc8c4b8, hair: 0xe8e8e8, hairStyle: 'topknot', beard: true, weapon: 'bastone_cielo' },
  guardia: { robe: 0x3a3a40, trim: 0x8a8a8a, pants: 0x2a2a2e, hair: 0x1a1210, hairStyle: 'topknot', helm: 'elmo_bronzo' },
};

export function buildNpcModel(info) {
  const look = NPC_LOOKS[info.role] || NPC_LOOKS.guardia;
  const k = KINGDOMS[info.kd];
  const rig = humanoid({ ...look, sash: k.hex, armor: info.role === 'guardia' ? k.hex : look.armor });
  if (look.weapon) applyWeapon(rig, look.weapon, 0);
  if (info.role === 'guardia') {
    const spear = new THREE.Group();
    spear.add(mesh(cyl(0.035, 0.04, 3.2, 6), lam(0x4a3220), 0, 0.6, 0));
    spear.add(mesh(cone(0.08, 0.45, 4), lam(0xb8b8b8), 0, 2.4, 0));
    spear.add(mesh(box(0.2, 0.15, 0.05), lam(k.hex), 0, 2.05, 0));
    rig.armR.grip.add(spear);
    rig.armR.pv.rotation.x = -0.35;
    setHat(rig, look.helm, k.hex);
  }
  if (info.role === 'fabbro') {
    const hammer = new THREE.Group();
    hammer.add(mesh(cyl(0.03, 0.03, 0.6, 6), lam(0x4a3220), 0, -0.2, 0));
    hammer.add(mesh(box(0.25, 0.14, 0.14), lam(0x3a3a3a), 0, -0.5, 0));
    rig.armR.grip.add(hammer);
  }
  if (info.role === 'erbe') rig.torso.rotation.x = 0.18;
  rig.npc = true;
  return finish(rig, 0.7);
}

export function buildMobModel(info) {
  const d = MOBS[info.ty];
  let rig;
  switch (d.model) {
    case 'wolf': rig = quadruped({ color: d.color, color2: 0x5a5652, w: 0.55, h: 0.55, len: 1.45, legH: 0.6, legW: 0.15, hw: 0.42, hh: 0.4, hl: 0.4, snout: 0.32, ears: 'point', tail: 0.6, eyes: info.ty === 'lupo_alfa' ? 0xffc030 : null }); break;
    case 'boar': rig = quadruped({ color: d.color, color2: 0x3a2a1c, w: 0.8, h: 0.75, len: 1.5, legH: 0.42, legW: 0.18, hw: 0.55, hh: 0.5, hl: 0.4, snout: 0.25, ears: 'point', tusks: true, hump: true, tail: 0.2 }); break;
    case 'bear': rig = quadruped({ color: d.color, color2: 0x1a1612, w: 1.15, h: 1.05, len: 1.9, legH: 0.7, legW: 0.32, hw: 0.7, hh: 0.6, hl: 0.5, snout: 0.3, ears: 'round', hump: true }); break;
    case 'tiger': {
      rig = quadruped({ color: d.color, color2: 0xa0a8d0, w: 0.65, h: 0.62, len: 1.9, legH: 0.65, legW: 0.18, hw: 0.55, hh: 0.45, hl: 0.42, snout: 0.25, ears: 'round', tail: 0.9, stripes: 0x4a4a7a, eyes: 0x8ad0ff });
      rig.root.traverse(m => { if (m.isMesh) { m.material = m.material.clone(); m.material.transparent = true; m.material.opacity = 0.82; m.material.emissive = new THREE.Color(0x3a4a8a); m.material.emissiveIntensity = 0.5; } });
      break;
    }
    case 'monkey': {
      rig = humanoid({ robe: d.color, sleeve: d.color, pants: d.color, skin: 0xd8b088, hair: d.color, hairStyle: 'topknot', skirt: false, sash: 0x8a2a1a });
      const tail = mesh(cyl(0.04, 0.05, 1.0, 5), lam(d.color), 0, 0.9, -0.4); tail.rotation.x = -0.9; rig.body.add(tail);
      rig.root.scale.setScalar(0.68);
      rig.height *= 0.68;
      break;
    }
    case 'bandit': rig = humanoid({ robe: 0x3b2f2f, trim: 0x6a1e1e, pants: 0x2a2424, hair: 0x101010, hairStyle: 'hood', sash: 0x6a1e1e }); applyWeapon(rig, 'sciabola_bronzo', 0); break;
    case 'bandit_archer': rig = humanoid({ robe: 0x3b3a2f, trim: 0x6a5a2a, pants: 0x2a2a24, hair: 0x101010, hairStyle: 'topknot', sash: 0x6a5a2a }); applyWeapon(rig, 'arco_corno', 0); setHat(rig, 'cappello_paglia'); break;
    case 'terracotta': {
      rig = humanoid({ robe: d.color, sleeve: d.color, pants: 0x8a5a3a, skin: 0xb07a52, hair: 0x7a4a2a, hairStyle: 'topknot', armor: 0x8a5a38, sash: 0x6a3a22 });
      applyWeapon(rig, 'spada_ferro', 0);
      rig.root.traverse(m => { if (m.isMesh && m.material.color) { m.material = lam(new THREE.Color(m.material.color).lerp(new THREE.Color(0xb07a52), 0.6).getHex()); } });
      break;
    }
    case 'general': {
      rig = humanoid({ robe: 0x2a1a1a, sleeve: 0x2a1a1a, pants: 0x1a1414, faceless: true, hairStyle: 'bald', armor: 0x3a2a2a, cape: 0x6a1010, sash: 0x8a1010 });
      const pole = new THREE.Group();
      pole.add(mesh(cyl(0.04, 0.05, 2.6, 6), lam(0x2a1a10), 0, -0.4, 0));
      const blade = mesh(box(0.08, 0.9, 0.3), glow(0xb04030, 0.3), 0, -1.95, 0.1);
      pole.add(blade);
      pole.rotation.x = -1.3;
      rig.armR.grip.add(pole);
      setHat(rig, 'elmo_drago', 0x8a1010);
      rig.weaponType = 'sword';
      break;
    }
    case 'lantern': rig = lanternSpirit(d.color); break;
    case 'obelisk': rig = obelisk(d.color, d.scale || 1); break;
    case 'dummy': rig = trainingDummy(); break;
    default: rig = quadruped({ color: 0x888888, w: 0.6, h: 0.6, len: 1.2, legH: 0.5, legW: 0.15, hw: 0.4, hh: 0.4, hl: 0.4, snout: 0.2 });
  }
  if (d.scale && d.model !== 'obelisk') { rig.root.scale.multiplyScalar(d.scale); rig.height *= d.scale; }
  const radius = d.stone ? 1.8 * (d.scale || 1) : 0.6 * (d.scale || 1) * (rig.quad ? 1.3 : 1);
  return finish(rig, radius);
}

export function buildDropModel(info) {
  const it = ITEMS[info.it];
  const root = new THREE.Group();
  const body = new THREE.Group(); root.add(body);
  const col = it && it.color ? new THREE.Color(it.color).getHex() : ({ 1: 0xc8c0b0, 2: 0x8ac0e0, 3: 0x8ae0a0, 4: 0xffc860 }[it?.tier] || 0xd8c890);
  const bag = mesh(G('drop', () => new THREE.OctahedronGeometry(0.28, 0)), glow(col, 0.5), 0, 0.5, 0);
  body.add(bag);
  const beam = new THREE.Mesh(G('beam', () => new THREE.CylinderGeometry(0.05, 0.12, 2.2, 6, 1, true)), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending }));
  beam.position.y = 1.1;
  body.add(beam);
  const rig = { root, body, height: 1.0, drop: true };
  return finish(rig, 0.8);
}

// ------------------------------------------------------------------ animazioni
export class Anim {
  constructor(rig) {
    this.rig = rig; this.phase = Math.random() * 6; this.t = Math.random() * 10;
    this.atk = 0; this.atkDur = 0.32; this.cast = 0; this.dead = false; this.deadT = 0; this.hurt = 0; this.stun = 0;
  }
  attack(style) { this.atk = this.atkDur; this.style = style; this.side = !this.side; }
  castSpell() { this.cast = 0.55; }
  hit() { this.hurt = 0.18; }
  die() { this.dead = true; this.deadT = 0; }
  revive() { this.dead = false; this.deadT = 0; const r = this.rig; r.body.rotation.set(0, 0, 0); r.body.position.set(0, 0, 0); r.root.visible = true; if (r.stone) r.body.scale.set(1, 1, 1); }

  update(dt, speed) {
    const r = this.rig;
    this.t += dt;
    if (this.dead) {
      this.deadT = Math.min(1, this.deadT + dt * 2.2);
      const e = this.deadT;
      if (r.stone) { r.body.scale.y = 1 - e * 0.65; r.body.position.y = -e * 0.5; }
      else if (r.float) { r.body.position.y = -e * 1.4; r.body.rotation.z = e * 1.2; }
      else if (r.quad) { r.body.rotation.z = e * Math.PI / 2; r.body.position.y = e * 0.2; }
      else { r.body.rotation.x = -e * Math.PI / 2; r.body.position.y = e * 0.25; }
      return;
    }
    if (r.drop) { r.body.rotation.y += dt * 1.6; r.body.position.y = Math.sin(this.t * 2.5) * 0.08; return; }
    if (r.dummy) {
      if (this.hurt > 0) this.wob = 0.22;
      this.hurt = Math.max(0, this.hurt - dt);
      this.wob = (this.wob || 0) * Math.max(0, 1 - dt * 4);
      r.body.rotation.x = Math.sin(this.t * 18) * this.wob;
      return;
    }
    if (r.stone) {
      r.shards.rotation.y += dt * 0.6;
      r.shards.children.forEach((s, i) => { s.position.y = 4 + Math.sin(this.t * 1.5 + i) * 0.6; s.rotation.y += dt * 2; });
      const k = 1 + (this.hurt > 0 ? 0.04 : 0);
      r.body.scale.set(k, 1, k);
      this.hurt = Math.max(0, this.hurt - dt);
      return;
    }
    if (r.float) {
      r.body.position.y = Math.sin(this.t * 2) * 0.25;
      r.body.rotation.z = Math.sin(this.t * 1.3) * 0.08;
      if (this.atk > 0) { this.atk -= dt; const s = 1 + Math.sin((1 - this.atk / this.atkDur) * Math.PI) * 0.25; r.body.scale.setScalar(s); } else r.body.scale.setScalar(1);
      return;
    }
    const moving = speed > 0.3;
    this.phase += dt * (moving ? Math.min(speed, 9) * 1.5 : 0);
    const sw = moving ? Math.sin(this.phase) : 0;
    if (r.quad) {
      r.legs.forEach((l, i) => { l.rotation.x = sw * 0.7 * ((i === 0 || i === 3) ? 1 : -1); });
      r.head.rotation.x = moving ? Math.sin(this.phase * 2) * 0.05 : Math.sin(this.t * 1.5) * 0.05;
      let lunge = 0;
      if (this.atk > 0) { this.atk -= dt; lunge = Math.sin((1 - this.atk / this.atkDur) * Math.PI); }
      r.body.position.z = lunge * 0.4;
      r.head.rotation.x -= lunge * 0.4;
      r.body.position.y = moving ? Math.abs(Math.sin(this.phase)) * 0.05 : 0;
      return;
    }
    // umanoide
    r.legL.rotation.x = sw * 0.65;
    r.legR.rotation.x = -sw * 0.65;
    r.body.position.y = moving ? Math.abs(Math.sin(this.phase)) * 0.06 : Math.sin(this.t * 2) * 0.01;
    let aR = -sw * 0.5, aL = sw * 0.5;
    if (r.weaponType === 'staff' && !moving) aR = -0.3;
    if (r.npc && r.armR.pv.rotation.x !== 0 && !moving && this.atk <= 0) aR = r.armR.pv.rotation.x;
    let twist = 0;
    if (this.atk > 0) {
      this.atk -= dt;
      const p = 1 - this.atk / this.atkDur;
      const wt = r.weaponType;
      if (wt === 'bow') { aL = -1.55; aR = -1.4 + p * 0.3; twist = 0.3; }
      else if (wt === 'staff') { aR = -1.8 + Math.sin(p * Math.PI) * 0.8; }
      else if (wt === 'fists' || wt === 'daggers') { if (this.side) aR = -1.6 * Math.sin(p * Math.PI); else aL = -1.6 * Math.sin(p * Math.PI); twist = (this.side ? 0.3 : -0.3) * Math.sin(p * Math.PI); }
      else { aR = -2.6 + p * 2.4; twist = -0.4 + p * 0.8; }
    }
    if (this.cast > 0) {
      this.cast -= dt;
      const p = Math.sin((1 - this.cast / 0.55) * Math.PI);
      aR = -2.4 * p; aL = -2.4 * p;
    }
    if (this.channel > 0) {
      this.channel -= dt;
      aR = -1.75 + Math.sin(this.t * 7) * 0.12; aL = -1.75 - Math.sin(this.t * 7) * 0.12;
    }
    if (this.stun > 0) { this.stun -= dt; r.head.rotation.z = Math.sin(this.t * 8) * 0.2; } else r.head.rotation.z = 0;
    r.armR.pv.rotation.x = aR;
    r.armL.pv.rotation.x = aL;
    r.torso.rotation.y = twist;
  }
}

export function buildModel(info) {
  switch (info.k) {
    case 'p': return buildPlayerModel(info);
    case 'n': return buildNpcModel(info);
    case 'm': return buildMobModel(info);
    case 'd': return buildDropModel(info);
  }
  return null;
}
