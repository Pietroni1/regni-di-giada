// Animali con scheletro creati in Blender (tools/blender/animali.py): lupo, cinghiale, orso, tigre, cavallo.
// Colori da un atlante per variante, pelliccia dipinta nello shader, animazioni con AnimationMixer.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';
import { SOFT_GRADIENT } from './world3d.js';

let BASE = null;
const HEIGHT = { lupo: 1.25, cinghiale: 1.1, orso: 1.7, tigre: 1.35, cavallo: 2.4 };

export async function loadAnimalAssets() {
  const gltf = await new GLTFLoader().loadAsync('/assets/animali.glb');
  BASE = {};
  for (const node of gltf.scene.children) {
    const sp = node.name.replace('_scheletro', '');
    if (!HEIGHT[sp]) continue;
    const clips = {};
    for (const c of gltf.animations) if (c.name.startsWith(sp + ':')) { const k = c.name.slice(sp.length + 1); clips[k] = c.clone(); clips[k].name = k; }
    BASE[sp] = { node, clips };
  }
}
export const hasAnimals = () => !!BASE;

// ------------------------------------------------------------------ atlante e materiale
const SLOTS = ['pelo', 'pelo2', 'scuro', 'occhi', 'zanne', 'criniera', 'interno', 'sella', 'oro', 'stoffa'];
const css = (c) => '#' + ((c ?? 0x808080) >>> 0).toString(16).padStart(6, '0');
const texCache = new Map(), matCache = new Map();
function atlas(cols) {
  const key = JSON.stringify(cols);
  let t = texCache.get(key);
  if (t) return t;
  const cv = document.createElement('canvas'); cv.width = cv.height = 256;
  const g = cv.getContext('2d');
  g.fillStyle = css(cols.pelo); g.fillRect(0, 0, 256, 256);
  SLOTS.forEach((n, i) => { g.fillStyle = css(cols[n]); g.fillRect(i * 16, 0, 16, 16); });
  t = new THREE.CanvasTexture(cv);
  t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.generateMipmaps = false; t.minFilter = THREE.LinearFilter;
  texCache.set(key, t);
  return t;
}

const NOISE = `
  float ah(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
  float an(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(ah(i), ah(i + vec3(1,0,0)), f.x), mix(ah(i + vec3(0,1,0)), ah(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(ah(i + vec3(0,0,1)), ah(i + vec3(1,0,1)), f.x), mix(ah(i + vec3(0,1,1)), ah(i + vec3(1,1,1)), f.x), f.y), f.z); }
`;

function material(cols, mask, opts) {
  const key = JSON.stringify([cols, mask, opts]);
  let m = matCache.get(key);
  if (m) return m;
  m = new THREE.MeshToonMaterial({ map: atlas(cols), gradientMap: SOFT_GRADIENT });
  if (opts.ghost) { m.transparent = true; m.opacity = 0.82; m.emissive = new THREE.Color(opts.ghost); m.emissiveIntensity = 0.5; m.depthWrite = false; }
  const eye = new THREE.Color(opts.eyeGlow ?? 0x000000);
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uMask = { value: mask };
    sh.uniforms.uStripes = { value: new THREE.Color(opts.stripes ?? 0x000000) };
    sh.uniforms.uStripeOn = { value: opts.stripes ? 1 : 0 };
    sh.uniforms.uEye = { value: eye };
    sh.vertexShader = 'uniform int uMask;\nattribute vec2 uv1;\nattribute vec2 uv2;\nvarying float vShade;\nvarying vec3 vBind;\n' + sh.vertexShader
      .replace('#include <begin_vertex>', '#include <begin_vertex>\n  vBind = position;\n  vShade = uv2.x * uv2.y;')
      .replace('#include <project_vertex>', `#include <project_vertex>
        { int part = int(uv1.x + 0.5); if (((uMask >> part) & 1) == 0) gl_Position = vec4(2.0, 2.0, 2.0, 1.0); }`);
    sh.fragmentShader = 'uniform vec3 uStripes;\nuniform float uStripeOn;\nuniform vec3 uEye;\nvarying float vShade;\nvarying vec3 vBind;\n' + NOISE + sh.fragmentShader
      .replace('#include <map_fragment>', `#include <map_fragment>
        float slotI = floor(vMapUv.x * 16.0);
        vec3 bp = vBind;
        if (slotI <= 1.0 || slotI == 5.0) {   // pelliccia: ciuffi lungo il corpo, macchie morbide
          float fur = an(vec3(bp.x * 60.0, bp.y * 9.0, bp.z * 60.0));
          diffuseColor.rgb *= 0.82 + fur * 0.32 + (an(bp * 4.0) - 0.5) * 0.18;
          if (uStripeOn > 0.5 && slotI == 0.0) {
            float st = sin(bp.z * 26.0 + an(bp * 3.0) * 4.0 + bp.y * 3.0);
            diffuseColor.rgb = mix(diffuseColor.rgb, uStripes, smoothstep(0.55, 0.8, st) * 0.85);
          }
        }
        diffuseColor.rgb *= vShade * 1.1;`)
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        if (floor(vMapUv.x * 16.0) == 3.0) totalEmissiveRadiance += uEye * 1.6;`)
      .replace('#include <opaque_fragment>', `{ float rim = pow(1.0 - clamp(dot(normal, normalize(vViewPosition)), 0.0, 1.0), 3.0);
        outgoingLight += vec3(1.0, 0.86, 0.66) * rim * 0.25 * (0.6 + 0.4 * diffuseColor.rgb); }
        #include <opaque_fragment>`);
  };
  m.customProgramCacheKey = () => 'animale' + (opts.ghost ? 'g' : '');
  matCache.set(key, m);
  return m;
}

// ------------------------------------------------------------------ istanza
export function buildSkinnedAnimal(sp, o = {}) {
  const base = BASE[sp];
  const model = cloneSkinned(base.node);
  model.position.set(0, 0, 0);
  let mesh = null;
  const bones = {};
  model.traverse((n) => { if (n.isSkinnedMesh) mesh = n; if (n.isBone) bones[n.name] = n; });
  const cols = {
    pelo: o.color ?? 0x8a7a68, pelo2: o.color2 ?? 0xd8cdb8, scuro: o.dark ?? 0x221a14, occhi: o.eyes ?? 0x1a1008, zanne: 0xf0e8d0,
    criniera: o.mane ?? 0x2a1a10, interno: 0xc88a7a, sella: o.saddle ?? 0x5a3a20, oro: 0xd0a040, stoffa: o.cloth ?? 0x8a2020,
  };
  const mask = 1 | (o.saddle ? 2 : 0) | (o.armor ? 4 : 0);
  mesh.material = material(cols, mask, { ghost: o.ghost, stripes: o.stripes, eyeGlow: o.eyes && o.glowEyes ? o.eyes : null });
  mesh.castShadow = true; mesh.receiveShadow = true;
  mesh.frustumCulled = false;
  const root = new THREE.Group();
  root.add(model);
  return { root, body: model, skinned: true, animal: sp, quad: true, mesh, bones, clips: base.clips, height: HEIGHT[sp] * (o.scale || 1) };
}

// ------------------------------------------------------------------ animazione
export class AnimalAnim {
  constructor(rig) {
    this.rig = rig;
    this.mixer = new THREE.AnimationMixer(rig.body);
    this.acts = {};
    this.cur = null; this.bases = [];
    this.os = null; this.dead = false; this.death = null;
    this.setBase('fermo');
    for (const b of this.bases) b.w = 1;
  }
  act(n) { let a = this.acts[n]; if (!a && this.rig.clips[n]) { a = this.mixer.clipAction(this.rig.clips[n]); this.acts[n] = a; } return a; }
  setBase(n) {
    if (this.cur === n) return;
    this.cur = n;
    if (!this.bases.find((b) => b.n === n)) { const a = this.act(n); a.reset().play(); a.time = Math.random() * a.getClip().duration; this.bases.push({ n, a, w: 0 }); }
  }
  oneShot(n, speed = 1) {
    if (this.dead) return;
    const a = this.act(n);
    if (!a) return;
    if (this.os && this.os.a !== a) this.os.a.stop();
    a.reset(); a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; a.timeScale = speed; a.play();
    this.os = { a, left: a.getClip().duration / speed };
  }
  attack() { this.oneShot('attacco', 1.2); }
  hit() { if (!this.os) this.oneShot('colpito', 1.3); }
  die(instant) {
    this.dead = true;
    if (this.os) { this.os.a.stop(); this.os = null; }
    const a = this.act('morte');
    a.reset(); a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; a.play();
    if (instant) a.time = a.getClip().duration;
    this.death = a;
  }
  revive() { this.dead = false; if (this.death) { this.death.stop(); this.death = null; } for (const b of this.bases) b.w = b.n === this.cur ? 1 : 0; }
  castSpell() { this.attack(); }
  update(dt, speed) {
    const runAt = this.rig.runAt || 4.5;
    if (!this.dead) this.setBase(speed > runAt ? 'corsa' : speed > 0.3 ? 'passo' : 'fermo');
    let sum = 0;
    const busy = this.os && this.os.left > 0.08;
    for (let i = this.bases.length - 1; i >= 0; i--) {
      const b = this.bases[i];
      const target = b.n === this.cur && !this.dead ? 1 : 0;
      b.w += (target - b.w) * Math.min(1, dt * 10);
      b.a.timeScale = b.n === 'corsa' ? Math.max(0.8, Math.min(2.2, speed / 6)) : b.n === 'passo' ? Math.max(0.6, Math.min(2, speed / 2.2)) : 1;
      if (target === 0 && b.w < 0.01) { b.a.stop(); this.bases.splice(i, 1); continue; }
      b.a.setEffectiveWeight(b.w * (busy ? 0.15 : 1));
      sum += b.w;
    }
    if (this.os) { this.os.left -= dt; this.os.a.setEffectiveWeight(busy ? 1 : Math.max(0, this.os.left / 0.08)); if (this.os.left <= 0) { this.os.a.stop(); this.os = null; } }
    if (this.death) this.death.setEffectiveWeight(Math.max(0, 1 - sum));
    this.mixer.update(dt);
  }
}
