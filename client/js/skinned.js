// Personaggi con scheletro: modello creato in Blender (tools/blender/personaggio.py), animazioni con
// AnimationMixer e colori da un piccolo atlante (tavolozza + viso) generato per ogni aspetto.
// Tutte le parti stanno in una sola mesh: la seconda UV dice a quale parte appartiene ogni vertice
// e lo shader nasconde quelle spente (capelli, hakama, armatura...). Una draw call per personaggio.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';
import { TOON_GRADIENT } from './world3d.js';

let BASE = null;
const UPPER = /^(spine|chest|neck|head|shoulder_|upper_arm_|forearm_|hand_)/;

export async function loadCharacterAssets() {
  const gltf = await new GLTFLoader().loadAsync('/assets/personaggio.glb');
  const clips = {};
  for (const c of gltf.animations) {
    clips[c.name] = {
      full: c,
      upper: new THREE.AnimationClip(c.name + '_alto', c.duration, c.tracks.filter(t => UPPER.test(t.name))),
      lower: new THREE.AnimationClip(c.name + '_basso', c.duration, c.tracks.filter(t => !UPPER.test(t.name))),
    };
  }
  BASE = { scene: gltf.scene, clips };
}
export const hasSkinned = () => !!BASE;
export const characterClips = () => BASE && BASE.clips;

// ------------------------------------------------------------------ parti e atlante
export const PARTS = { base: 0, hakama: 1, codino: 2, lunghi: 3, crocchia: 4, cappuccio: 5, barba: 6, armatura: 7, frangia: 8, mantello: 9, colletto: 10 };
const PAL = ['pelle', 'veste', 'bordo', 'pantaloni', 'fascia', 'scarpe', 'capelli', 'armatura', 'calze', 'sottoveste', 'oro', 'maniche', 'barba', 'mantello'];
const hexCss = (c) => '#' + ((c ?? 0x808080) >>> 0).toString(16).padStart(6, '0');

function maskFor(o) {
  let m = 1 << PARTS.base;
  const hair = { topknot: 'codino', long: 'lunghi', bun: 'crocchia' }[o.hairStyle];
  if (hair) m |= (1 << PARTS[hair]) | (1 << PARTS.frangia);
  if (o.hairStyle === 'hood') m |= 1 << PARTS.cappuccio;
  if (o.skirt !== false) m |= 1 << PARTS.hakama;
  if (o.armor) m |= 1 << PARTS.armatura; else m |= 1 << PARTS.colletto;
  if (o.beard) m |= 1 << PARTS.barba;
  if (o.cape) m |= 1 << PARTS.mantello;
  return m;
}

function lookFor(o) {
  return {
    pelle: o.faceless ? 0xe8e4dc : (o.skin ?? 0xe8bc94), veste: o.robe, bordo: o.trim ?? 0x8a6a3a, pantaloni: o.pants ?? 0x3a3a3a,
    fascia: o.sash ?? 0x8a2020, scarpe: o.shoes ?? 0x2a1f18, capelli: o.hair ?? 0x1a1210, armatura: o.armor ?? 0x6a5a48,
    calze: 0xe8e2d4, sottoveste: 0xf0ebdc, oro: 0xd8b048, maniche: o.sleeve ?? o.robe, barba: 0xe8e8e8, mantello: o.cape ?? o.robe,
    eye: o.eye ?? 0x4a2a18, faceless: !!o.faceless,
  };
}

// Il viso dipinto: occhi grandi con riflessi, sopracciglia, naso, bocca e guance.
function drawFace(g, L) {
  const U = (x) => 32 + (x / 0.25 + 1) * 96, V = (z) => 40 + (2.2125 - z) / 0.525 * 192;
  const ell = (x, y, rx, ry) => { g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); g.fill(); };
  if (L.faceless) {
    g.fillStyle = '#d82a14';
    for (const s of [-1, 1]) { g.save(); g.translate(U(0.08 * s), V(1.95)); g.rotate(-0.22 * s); g.fillRect(-15, -3, 30, 6); g.restore(); }
    return;
  }
  for (const s of [-1, 1]) {
    const cx = U(0.083 * s), cy = V(1.932);
    g.fillStyle = '#fbf7ef'; ell(cx, cy, 13, 16);
    g.fillStyle = hexCss(L.eye); ell(cx - 1.5 * s, cy + 2, 9, 12.5);
    g.fillStyle = '#120a08'; ell(cx - 1.5 * s, cy + 3, 4.5, 7);
    g.fillStyle = '#ffffff'; ell(cx + 2.5 * s, cy - 4, 3.6, 3.6); ell(cx - 4 * s, cy + 7, 1.8, 1.8);
    g.strokeStyle = '#1a1210'; g.lineCap = 'round'; g.lineWidth = 3.4;
    g.beginPath(); g.ellipse(cx, cy + 2, 15, 17.5, 0, Math.PI * 1.06, Math.PI * 1.94); g.stroke();
    g.lineWidth = 3.5; g.beginPath(); g.moveTo(cx + 13 * s, cy - 6); g.lineTo(cx + 19 * s, cy - 11); g.stroke();
    g.strokeStyle = hexCss(L.capelli); g.lineWidth = 3.6;
    g.beginPath(); g.moveTo(cx - 12 * s, V(1.995) + 3); g.quadraticCurveTo(cx, V(1.995) - 4, cx + 13 * s, V(1.995)); g.stroke();
  }
  g.strokeStyle = 'rgba(120,60,40,0.4)'; g.lineWidth = 2;
  g.beginPath(); g.moveTo(U(0.004), V(1.885)); g.lineTo(U(-0.006), V(1.868)); g.stroke();
  g.strokeStyle = '#8a3e2e'; g.lineWidth = 2.6;
  g.beginPath(); g.moveTo(U(-0.03), V(1.835)); g.quadraticCurveTo(U(0), V(1.828), U(0.03), V(1.835)); g.stroke();
  g.fillStyle = 'rgba(240,110,100,0.16)';
  for (const s of [-1, 1]) ell(U(0.135 * s), V(1.875), 13, 6);
}

const atlasCache = new Map();
function atlas(L) {
  const key = JSON.stringify(L);
  let t = atlasCache.get(key);
  if (t) return t;
  const cv = document.createElement('canvas');
  cv.width = cv.height = 256;
  const g = cv.getContext('2d');
  g.fillStyle = hexCss(L.pelle); g.fillRect(0, 0, 256, 256);
  PAL.forEach((n, i) => { g.fillStyle = hexCss(L[n]); g.fillRect(i * 16, 0, 16, 16); });
  drawFace(g, L);
  t = new THREE.CanvasTexture(cv);
  t.flipY = false; t.colorSpace = THREE.SRGBColorSpace;
  t.generateMipmaps = false; t.minFilter = THREE.LinearFilter;
  atlasCache.set(key, t);
  return t;
}

// ------------------------------------------------------------------ materiali con maschera delle parti
function withMask(m, mask, tag, pre) {
  m.onBeforeCompile = (sh) => {
    if (pre) pre(sh);
    sh.uniforms.uMask = { value: mask };
    sh.vertexShader = 'uniform int uMask;\nattribute vec2 uv1;\n' + sh.vertexShader.replace('#include <project_vertex>', `#include <project_vertex>
      { int part = int(uv1.x + 0.5); if (((uMask >> part) & 1) == 0) gl_Position = vec4(2.0, 2.0, 2.0, 1.0); }`);
  };
  m.customProgramCacheKey = () => 'pg-' + tag;
  return m;
}
const matCache = new Map();
function cached(key, make) { let m = matCache.get(key); if (!m) { m = make(); matCache.set(key, m); } return m; }
const bodyMat = (tex, mask, ghost) => cached(`b${tex.id}|${mask}|${ghost ? JSON.stringify(ghost) : ''}`, () => {
  const m = new THREE.MeshToonMaterial({ map: tex, gradientMap: TOON_GRADIENT });
  if (ghost) { m.transparent = true; m.opacity = ghost.opacity; m.emissive = new THREE.Color(ghost.emissive); m.emissiveIntensity = ghost.intensity ?? 0.6; m.depthWrite = false; }
  return withMask(m, mask, ghost ? 'ghost' : 'body');
});
const lineMat = (mask) => cached(`o${mask}`, () => withMask(new THREE.MeshBasicMaterial({ color: 0x1a1008, side: THREE.BackSide }), mask, 'line',
  (sh) => { sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * 0.022;'); }));
const depthMat = (mask) => cached(`d${mask}`, () => withMask(new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking }), mask, 'depth'));

// ------------------------------------------------------------------ istanza
const _m = new THREE.Matrix4();
function attach(bone, pos, quat) {
  const g = new THREE.Group();
  _m.copy(bone.matrixWorld).invert().multiply(new THREE.Matrix4().compose(pos, quat, new THREE.Vector3(1, 1, 1)));
  _m.decompose(g.position, g.quaternion, g.scale);
  bone.add(g);
  return g;
}
// Impugnatura: -Y lungo la mano (verso le dita), Z in avanti, come nei modelli delle armi.
function gripFrame(k) {
  const dir = new THREE.Vector3(0.05 * k, -0.10, 0.01).normalize();
  const y = dir.clone().negate();
  const z = new THREE.Vector3(0, 0, 1);
  z.sub(y.clone().multiplyScalar(z.dot(y))).normalize();
  const x = new THREE.Vector3().crossVectors(y, z);
  return new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(x, y, z));
}

export function buildSkinnedHumanoid(o) {
  const model = cloneSkinned(BASE.scene);
  let mesh = null;
  const bones = {};
  model.traverse((n) => { if (n.isSkinnedMesh) mesh = n; if (n.isBone) bones[n.name] = n; });
  const mask = maskFor(o);
  mesh.material = bodyMat(atlas(lookFor(o)), mask, o.ghost);
  mesh.customDepthMaterial = depthMat(mask);
  mesh.castShadow = true; mesh.receiveShadow = true;
  mesh.userData.skinnedBody = true;
  const line = mesh.clone();
  line.material = lineMat(mask);
  line.castShadow = false; line.receiveShadow = false;
  line.userData.outline = true;
  mesh.parent.add(line);
  model.updateMatrixWorld(true);
  const head = attach(bones.head, new THREE.Vector3(0, 1.71, 0), new THREE.Quaternion());
  const hatGroup = new THREE.Group(); hatGroup.scale.setScalar(1.15); hatGroup.position.y = 0.02; head.add(hatGroup);
  const gripR = attach(bones.hand_R, new THREE.Vector3(-0.515, 1.035, 0.01), gripFrame(-1));
  const gripL = attach(bones.hand_L, new THREE.Vector3(0.515, 1.035, 0.01), gripFrame(1));
  const root = new THREE.Group();
  root.add(model);
  const dummy = () => new THREE.Object3D();
  return {
    root, body: model, skinned: true, mesh, outlineMesh: line, bones, head, hatGroup, extraPose: {},
    armR: { grip: gripR, pv: dummy() }, armL: { grip: gripL, pv: dummy() }, torso: dummy(), legL: dummy(), legR: dummy(),
    height: 2.35,
  };
}

// ------------------------------------------------------------------ animazione
const SETS = { sword: ['spada_1', 'spada_2', 'spada_3'], daggers: ['pugnali_1', 'pugnali_2'], fists: ['pugni_1', 'pugni_2', 'pugni_3'], bow: ['arco'], staff: ['bastone'] };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const _q = new THREE.Quaternion(), _e = new THREE.Euler();

export class SkinAnim {
  constructor(rig) {
    this.rig = rig;
    this.mixer = new THREE.AnimationMixer(rig.body);
    this.acts = {};
    this.bases = [];
    this.cur = null;
    this.wU = 1; this.wL = 1;
    this.os = null; this.n = 0; this.t = Math.random() * 10;
    this.dead = false; this.death = null;
    this.setBase('fermo', true);
  }

  act(name, part) {
    const k = name + '|' + part;
    let a = this.acts[k];
    if (!a) { a = this.mixer.clipAction(BASE.clips[name][part]); this.acts[k] = a; }
    return a;
  }

  setBase(name, instant) {
    if (this.cur === name) return;
    this.cur = name;
    let b = this.bases.find((x) => x.name === name);
    if (!b) {
      const u = this.act(name, 'upper'), l = this.act(name, 'lower');
      u.reset().play(); l.reset().play();
      u.time = l.time = Math.random() * u.getClip().duration;
      b = { name, w: instant ? 1 : 0, u, l };
      this.bases.push(b);
    }
  }

  oneShot(name, upperOnly = false, speed = 1) {
    if (this.dead) return;
    const full = !upperOnly && this.cur === 'fermo';
    const a = this.act(name, full ? 'full' : 'upper');
    if (this.os && this.os.a !== a) this.os.a.stop();
    a.reset(); a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; a.timeScale = speed; a.play();
    this.os = { a, left: a.getClip().duration / speed, full };
  }

  attack() { const set = SETS[this.rig.weaponType] || SETS.fists; this.oneShot(set[this.n++ % set.length]); }
  castSpell() { this.oneShot('magia'); }
  hit() { if (!this.os) this.oneShot('colpito', true, 1.2); }

  die(instant) {
    this.dead = true;
    if (this.os) { this.os.a.stop(); this.os = null; }
    const a = this.act('morte', 'full');
    a.reset(); a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; a.play();
    if (instant) a.time = a.getClip().duration;
    this.death = a;
  }

  revive() {
    this.dead = false;
    if (this.death) { this.death.stop(); this.death = null; }
    for (const b of this.bases) { b.w = b.name === this.cur ? 1 : 0; }
  }

  // Incanalamento: posa della magia tenuta finché dura il lancio.
  channel(on) {
    const os = this.os;
    if (on) {
      if (!os || !os.hold) { this.oneShot('magia'); if (this.os) this.os.hold = true; }
      const h = this.os;
      if (h && h.a.time > 0.3) h.a.timeScale = 0;
      if (h) h.left = Math.max(h.left, 0.3);
    } else if (os && os.hold) { os.hold = false; os.a.timeScale = 1; os.left = Math.min(os.left, 0.25); }
  }

  update(dt, speed, mounted, stun, channel) {
    this.t += dt;
    if (!this.dead) this.channel(channel > 0);
    if (!this.dead) this.setBase(mounted ? 'sella' : speed > 4.2 ? 'corsa' : speed > 0.3 ? 'camminata' : 'fermo');
    let sum = 0;
    for (let i = this.bases.length - 1; i >= 0; i--) {
      const b = this.bases[i];
      const target = b.name === this.cur && !this.dead ? 1 : 0;
      b.w += (target - b.w) * Math.min(1, dt * 10);
      const ts = b.name === 'corsa' ? clamp(speed / 4.6, 0.8, 2.2) : b.name === 'camminata' ? clamp(speed / 1.7, 0.6, 1.8) : 1;
      b.u.timeScale = b.l.timeScale = ts;
      if (target === 0 && b.w < 0.01) { b.u.stop(); b.l.stop(); this.bases.splice(i, 1); continue; }
      sum += b.w;
    }
    const os = this.os;
    let busyU = false, busyL = false;
    if (os) { os.left -= dt; if (os.left > 0.08) { busyU = true; busyL = os.full; } }
    const k = Math.min(1, dt * 18);
    this.wU += ((busyU ? 0 : 1) - this.wU) * k;
    this.wL += ((busyL ? 0 : 1) - this.wL) * k;
    for (const b of this.bases) { b.u.setEffectiveWeight(b.w * this.wU); b.l.setEffectiveWeight(b.w * this.wL); }
    if (os) {
      os.a.setEffectiveWeight(os.full ? 1 - Math.min(this.wU, this.wL) : 1 - this.wU);
      if (os.left <= 0 && this.wU > 0.98 && this.wL > 0.98) { os.a.stop(); this.os = null; }
    }
    if (this.death) this.death.setEffectiveWeight(Math.max(0, 1 - sum));
    this.mixer.update(dt);
    const bones = this.rig.bones;
    for (const [name, r] of Object.entries(this.rig.extraPose)) {
      const b = bones[name];
      if (b) b.quaternion.multiply(_q.setFromEuler(_e.set(r[0], r[1], r[2])));
    }
    if (stun > 0) bones.head.quaternion.multiply(_q.setFromEuler(_e.set(0, 0, Math.sin(this.t * 8) * 0.25)));
  }
}
