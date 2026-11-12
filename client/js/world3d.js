// Costruzione del mondo 3D statico: cielo, terreno, acqua, vegetazione, villaggi, altopiano.
// Tutta la grafica è procedurale (nessun file esterno), stile low-poly anni 2000.
import * as THREE from 'three';
import { Sky } from 'three/addons/objects/Sky.js';
import { hasNature, buildNature, WIND } from './nature.js';
import { DUNGEON, dungeonWalkable } from '/shared/data.js';
import {
  heightAt, roadDistance, fbm, smoothstep, mulberry32, KINGDOMS, KINGDOM_IDS, CENTER, WALL_RADIUS,
  VILLAGE_LAYOUT, VILLAGE_HEIGHT, villageFrame, wallAngles, toWorld, ROADS,
} from '/shared/world.js';

const COLORS = {
  grass1: new THREE.Color(0x56772f), grass2: new THREE.Color(0x7c9a3c), grassDry: new THREE.Color(0xa09a55),
  forest: new THREE.Color(0x3e5f28), dirt: new THREE.Color(0x8d6c45), plaza: new THREE.Color(0xa69a84),
  sand: new THREE.Color(0xc4b17c), rock: new THREE.Color(0x7c766c), snow: new THREE.Color(0xeeeeec), mud: new THREE.Color(0x5b5233),
  arena: new THREE.Color(0x9a8a70),
};

const tmpC = new THREE.Color();
export function groundColor(x, z, h, out = new THREE.Color()) {
  const n = fbm(x * 0.035, z * 0.035, 3, 99);
  out.copy(COLORS.grass1).lerp(COLORS.grass2, n);
  const n2 = fbm(x * 0.008 + 50, z * 0.008, 2, 77);
  if (n2 > 0.55) out.lerp(COLORS.grassDry, Math.min(1, (n2 - 0.55) * 3));
  const forest = fbm(x * 0.018, z * 0.018, 3, 31);
  if (forest > 0.55) out.lerp(COLORS.forest, Math.min(0.7, (forest - 0.55) * 3));
  if (h < 1.3) out.lerp(COLORS.sand, smoothstep(1.3, 0.2, h));
  if (h < -0.5) out.lerp(COLORS.mud, smoothstep(-0.5, -3, h));
  const slope = Math.hypot(heightAt(x + 1, z) - heightAt(x - 1, z), heightAt(x, z + 1) - heightAt(x, z - 1)) / 2;
  if (slope > 0.55) out.lerp(COLORS.rock, smoothstep(0.55, 1.1, slope));
  if (h > 24) out.lerp(COLORS.rock, smoothstep(24, 32, h));
  if (h > 44) out.lerp(COLORS.snow, smoothstep(44, 52, h));
  const rd = roadDistance(x, z);
  if (rd < 4.5) out.lerp(COLORS.dirt, smoothstep(4.5, 2.2, rd) * 0.9);
  const dc = Math.hypot(x - CENTER.x, z - CENTER.z);
  if (dc < 34) out.lerp(COLORS.arena, smoothstep(34, 26, dc) * 0.85);
  for (const kid of KINGDOM_IDS) {
    const v = KINGDOMS[kid].village;
    const d = Math.hypot(x - v.x, z - v.z);
    if (d < WALL_RADIUS + 1) out.lerp(COLORS.plaza, smoothstep(WALL_RADIUS + 1, WALL_RADIUS - 5, d) * 0.85);
  }
  return out;
}

// ------------------------------------------------------------------ utilità geometrie
// Cel-shading: tre toni netti (ombra, mezzatinta, luce).
export const TOON_GRADIENT = (() => {
  const t = new THREE.DataTexture(new Uint8Array([90, 90, 90, 255, 170, 170, 170, 255, 255, 255, 255, 255]), 3, 1, THREE.RGBAFormat);
  t.minFilter = t.magFilter = THREE.NearestFilter;
  t.generateMipmaps = false;
  t.needsUpdate = true;
  return t;
})();
export function toon(opts) { return new THREE.MeshToonMaterial({ gradientMap: TOON_GRADIENT, ...opts }); }
// Ombreggiatura anime morbida per i personaggi: passaggi di luce sfumati invece di tre bande nette.
export const SOFT_GRADIENT = (() => {
  const v = [70, 120, 175, 225, 250, 255];
  const t = new THREE.DataTexture(new Uint8Array(v.flatMap(x => [x, x, x, 255])), v.length, 1, THREE.RGBAFormat);
  t.minFilter = t.magFilter = THREE.LinearFilter;
  t.generateMipmaps = false;
  t.needsUpdate = true;
  return t;
})();
// Materiale del mondo: opaco, con luce ambientale dal cielo.
export function soft(opts) { return new THREE.MeshStandardMaterial({ roughness: 0.85, metalness: 0, ...opts }); }

// Contorno "a scafo invertito": la stessa geometria, spinta lungo le normali e disegnata dal retro.
const outlineCache = new Map();
export function outlineMaterial(thickness = 0.035, cut = false) {
  const key = thickness + (cut ? 'c' : '');
  let m = outlineCache.get(key);
  if (!m) {
    m = new THREE.MeshBasicMaterial({ color: 0x1a1008, side: THREE.BackSide });
    m.onBeforeCompile = (sh) => { sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', `vec3 transformed = position + normal * ${thickness.toFixed(3)};`); };
    m.customProgramCacheKey = () => 'outline' + thickness;
    if (cut) cutaway(m, 'outline' + thickness);
    outlineCache.set(key, m);
  }
  return m;
}

// Dissolvenza retinata di ciò che sta tra la camera e il giocatore (alberi, case, bancarelle):
// solo dentro un cerchio sullo schermo attorno al personaggio e più vicino di lui alla camera.
export const CUTAWAY = { value: 0 };
const CUT_CENTER = { value: new THREE.Vector2() }, CUT_R = { value: 0.4 }, CUT_ASPECT = { value: 1.7 };
function cutaway(mat, key) {
  const prev = mat.onBeforeCompile;
  mat.onBeforeCompile = (sh, r) => {
    if (prev) prev.call(mat, sh, r);
    sh.uniforms.uCutNear = CUTAWAY; sh.uniforms.uCutCenter = CUT_CENTER; sh.uniforms.uCutR = CUT_R; sh.uniforms.uCutAspect = CUT_ASPECT;
    sh.vertexShader = 'varying float vCutDepth;\nvarying vec4 vCutClip;\n' + sh.vertexShader.replace('#include <project_vertex>', '#include <project_vertex>\n  vCutDepth = -mvPosition.z;\n  vCutClip = gl_Position;');
    sh.fragmentShader = 'uniform float uCutNear;\nuniform vec2 uCutCenter;\nuniform float uCutR;\nuniform float uCutAspect;\nvarying float vCutDepth;\nvarying vec4 vCutClip;\n' + sh.fragmentShader.replace('void main() {', `void main() {
      if (vCutDepth < uCutNear) {
        vec2 nd = vCutClip.xy / vCutClip.w - uCutCenter; nd.x *= uCutAspect;
        float hole = 1.0 - smoothstep(uCutR * 0.55, uCutR, length(nd));
        float fade = max(hole * (1.0 - smoothstep(uCutNear - 4.0, uCutNear + 0.5, vCutDepth)) * 0.92, 1.0 - smoothstep(3.0, 7.0, vCutDepth));
        const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
        ivec2 q = ivec2(mod(floor(gl_FragCoord.xy), 4.0));
        if (fade > (BAYER[q.x + q.y * 4] + 0.5) / 16.0) discard;
      }`);
  };
  mat.customProgramCacheKey = () => 'cut-' + key;
  return mat;
}
const _cutV = new THREE.Vector3();
function updateCutaway(camera, focus) {
  if (!camera) { CUTAWAY.value = 0; return; }
  const d = camera.position.distanceTo(focus);
  CUTAWAY.value = Math.max(0, d - 2);
  _cutV.copy(focus).project(camera);
  CUT_CENTER.value.set(_cutV.x, _cutV.y);
  CUT_ASPECT.value = camera.aspect;
  CUT_R.value = Math.min(0.8, Math.max(0.15, 3.6 / (d * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)))));
}

const matCache = new Map();
export function lam(color, extra = {}) {
  const key = color + '|' + JSON.stringify(extra);
  let m = matCache.get(key);
  if (!m) { m = soft({ color, ...extra }); matCache.set(key, m); }
  return m;
}
function M(geo, mat, x = 0, y = 0, z = 0, shadow = true) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = shadow; m.receiveShadow = true;
  return m;
}

const withRot = (m, axis, v) => { m.rotation[axis] = v; return m; };
// Unisce più geometrie in una sola con colori per vertice (per instancing di alberi ecc.)
export function mergeParts(parts) {
  const withPat = parts.some(p => p.pat);
  const geos = parts.map(p => {
    let g = p.geo.index ? p.geo.toNonIndexed() : p.geo.clone();
    if (p.m) g.applyMatrix4(p.m);
    return [g, new THREE.Color(p.color), p.pat || 0];
  });
  const total = geos.reduce((s, [g]) => s + g.attributes.position.count, 0);
  const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3), col = new Float32Array(total * 3);
  const puv = withPat ? new Float32Array(total * 2) : null, pat = withPat ? new Float32Array(total) : null;
  let o = 0;
  for (const [g, c, pt] of geos) {
    const n = g.attributes.position.count;
    pos.set(g.attributes.position.array, o * 3);
    nor.set(g.attributes.normal.array, o * 3);
    for (let i = 0; i < n; i++) { col[(o + i) * 3] = c.r; col[(o + i) * 3 + 1] = c.g; col[(o + i) * 3 + 2] = c.b; }
    if (withPat && pt && g.attributes.puv) { puv.set(g.attributes.puv.array, o * 2); pat.fill(pt, o, o + n); }
    o += n;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  out.setAttribute('color', new THREE.BufferAttribute(col, 3));
  if (withPat) { out.setAttribute('puv', new THREE.BufferAttribute(puv, 2)); out.setAttribute('pat', new THREE.BufferAttribute(pat, 1)); }
  return out;
}

// Motivi dipinti nello shader (nessuna texture, nessuna draw call in più):
// 1 = tetto di coppi (sopra) e travetti dipinti dancheong (sotto); 2 = fascia dancheong sulle travi.
const PATTERN_FRAG = `
  if (vPat > 0.5 && vPat < 1.5) {
    if (gl_FrontFacing) {
      float cl = fract(vPuv.x * 2.1);
      float ridge = abs(cl - 0.5) * 2.0;
      float shade = 1.15 - 0.3 * ridge * ridge - 0.45 * smoothstep(0.72, 0.9, ridge);
      float row = fract(vPuv.y * 1.6);
      shade *= 1.0 - 0.35 * smoothstep(0.8, 0.9, row) + 0.12 * smoothstep(0.0, 0.3, row) * (1.0 - step(0.8, row));
      shade *= 1.0 + 0.3 * step(vPuv.y, 0.2) * step(0.2, abs(cl - 0.5));
      diffuseColor.rgb *= shade;
    } else {
      float r = fract(vPuv.x * 2.1);
      float raft = step(abs(r - 0.5), 0.27);
      vec3 board = pow(vec3(0.42, 0.12, 0.08), vec3(2.2));
      vec3 rc = pow(vec3(0.16, 0.5, 0.42), vec3(2.2));
      rc = mix(rc, pow(vec3(0.95, 0.78, 0.3), vec3(2.2)), step(vPuv.y, 0.14));
      rc = mix(rc, pow(vec3(0.75, 0.15, 0.1), vec3(2.2)), step(0.14, vPuv.y) * step(vPuv.y, 0.24));
      rc = mix(rc, pow(vec3(0.9, 0.86, 0.75), vec3(2.2)), step(0.24, vPuv.y) * step(vPuv.y, 0.29));
      diffuseColor.rgb = mix(board, rc, raft);
    }
  } else if (vPat > 1.5 && vPat < 2.5) {
    vec2 q = vec2(fract(vPuv.x / 1.3), vPuv.y);
    float dd = abs(q.x - 0.5) * 2.0 + abs(q.y - 0.5) * 1.5;
    vec3 c = vec3(0.16, 0.48, 0.42);
    c = mix(c, vec3(0.96, 0.92, 0.82), step(dd, 0.78));
    c = mix(c, vec3(0.78, 0.16, 0.1), step(dd, 0.62));
    c = mix(c, vec3(0.98, 0.78, 0.25), step(dd, 0.24));
    float edge = step(0.84, q.y) + step(q.y, 0.16);
    c = mix(c, vec3(0.62, 0.12, 0.08), clamp(edge, 0.0, 1.0));
    c = mix(c, vec3(0.2, 0.3, 0.55), step(abs(q.x - 0.0), 0.04) + step(0.96, q.x));
    diffuseColor.rgb = pow(c, vec3(2.2));
  }
`;
function patternToon(side) {
  const m = soft({ vertexColors: true, side });
  m.onBeforeCompile = (sh) => {
    sh.vertexShader = 'attribute vec2 puv;\nattribute float pat;\nvarying vec2 vPuv;\nvarying float vPat;\n' +
      sh.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\n  vPuv = puv; vPat = pat;');
    sh.fragmentShader = 'varying vec2 vPuv;\nvarying float vPat;\n' +
      sh.fragmentShader.replace('#include <color_fragment>', '#include <color_fragment>\n' + PATTERN_FRAG);
  };
  m.customProgramCacheKey = () => 'pattern' + side;
  return m;
}
// Trave con fascia dipinta: coordinate del motivo lungo il perimetro e in altezza.
function bandGeo(w, h, d) {
  const g = new THREE.BoxGeometry(w, h, d).toNonIndexed();
  const p = g.attributes.position, uv = new Float32Array(p.count * 2);
  for (let i = 0; i < p.count; i++) { uv[i * 2] = p.getX(i) + p.getZ(i); uv[i * 2 + 1] = p.getY(i) / h + 0.5; }
  g.setAttribute('puv', new THREE.BufferAttribute(uv, 2));
  g.userData.pat = 2;
  return g;
}

// Unisce tutte le mesh statiche semplici di un gruppo in poche mesh (meno draw call).
function mergeStatic(root) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = { front: [], double: [] };
  const remove = [];
  root.traverse(o => {
    if (!o.isMesh || o.isInstancedMesh || o.userData.keep) return;
    const m = o.material;
    if (!(m.isMeshLambertMaterial || m.isMeshToonMaterial) || m.emissive.getHex() !== 0 || m.transparent || m.map || m.vertexColors) return;
    const mat = new THREE.Matrix4().multiplyMatrices(inv, o.matrixWorld);
    (m.side === THREE.DoubleSide ? buckets.double : buckets.front).push({ geo: o.geometry, color: m.color.getHex(), m: mat, pat: o.geometry.userData.pat || 0 });
    remove.push(o);
  });
  for (const o of remove) o.parent.remove(o);
  for (const [k, parts] of Object.entries(buckets)) {
    if (!parts.length) continue;
    const geo = mergeParts(parts);
    const side = k === 'double' ? THREE.DoubleSide : THREE.FrontSide;
    const mesh = new THREE.Mesh(geo, cutaway(geo.attributes.pat ? patternToon(side) : soft({ vertexColors: true, side }), (geo.attributes.pat ? 'pat' : 'st') + side));
    mesh.castShadow = true; mesh.receiveShadow = true;
    root.add(mesh);
  }
}

const mtx = (x = 0, y = 0, z = 0, sx = 1, sy = 1, sz = 1, ry = 0, rx = 0, rz = 0) => {
  const m = new THREE.Matrix4();
  m.compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(sx, sy, sz));
  return m;
};

// Tetto curvo "a padiglione" con gronde rialzate agli angoli, tipico dell'architettura orientale.
export function curvedRoof(w, d, h, lift = 0.5, seg = 14) {
  const geo = new THREE.BufferGeometry();
  const pos = [], idx = [];
  const hw = w / 2, hd = d / 2, half = Math.min(hw, hd);
  for (let j = 0; j <= seg; j++) {
    for (let i = 0; i <= seg; i++) {
      const u = i / seg * 2 - 1, v = j / seg * 2 - 1;
      const x = u * hw, z = v * hd;
      const ax = (hw - Math.abs(x)) / half, az = (hd - Math.abs(z)) / half;
      const s = Math.min(1, ax, az);
      let y = h * Math.pow(s, 1.7);
      const corner = Math.pow(Math.abs(u) * Math.abs(v), 4);
      y += lift * corner * (1 - s) * 1.2 + lift * 0.25 * (1 - s) * (1 - s);
      pos.push(x, y, z);
    }
  }
  for (let j = 0; j < seg; j++) for (let i = 0; i < seg; i++) {
    const a = j * (seg + 1) + i, b = a + 1, c = a + seg + 1, e = c + 1;
    idx.push(a, c, b, b, c, e);
  }
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setIndex(idx);
  geo.computeVertexNormals();
  // per ogni triangolo: falda frontale/posteriore (coppi lungo z) o laterale (coppi lungo x)
  const out = geo.toNonIndexed();
  const P = out.attributes.position, uv = new Float32Array(P.count * 2);
  for (let t = 0; t < P.count; t += 3) {
    let cx = 0, cz = 0;
    for (let k = 0; k < 3; k++) { cx += P.getX(t + k) / 3; cz += P.getZ(t + k) / 3; }
    const side = (hw - Math.abs(cx)) < (hd - Math.abs(cz));
    for (let k = 0; k < 3; k++) {
      const x = P.getX(t + k), z = P.getZ(t + k);
      uv[(t + k) * 2] = side ? z : x;
      uv[(t + k) * 2 + 1] = side ? hw - Math.abs(x) : hd - Math.abs(z);
    }
  }
  out.setAttribute('puv', new THREE.BufferAttribute(uv, 2));
  out.userData.pat = 1;
  return out;
}

// ------------------------------------------------------------------ cielo
const SUN_DIR = new THREE.Vector3(-0.62, 0.42, 0.42).normalize();
function makeSky() {
  const sky = new Sky();
  sky.scale.setScalar(1300);
  const u = sky.material.uniforms;
  u.turbidity.value = 4.5; u.rayleigh.value = 1.4; u.mieCoefficient.value = 0.005; u.mieDirectionalG.value = 0.85;
  u.sunPosition.value.copy(SUN_DIR).multiplyScalar(1000);
  // il cielo fisico è molto luminoso: lo riportiamo alla scala della scena
  sky.material.fragmentShader = sky.material.fragmentShader.replace('gl_FragColor = vec4( retColor, 1.0 );', 'gl_FragColor = vec4( retColor * 0.42, 1.0 );');
  sky.material.fog = false;
  sky.renderOrder = -10;
  return sky;
}

function cloudTexture() {
  const cv = document.createElement('canvas'); cv.width = cv.height = 128;
  const g = cv.getContext('2d');
  const rnd = mulberry32(31);
  for (let i = 0; i < 22; i++) {
    const x = 30 + rnd() * 68, y = 44 + rnd() * 40, r = 14 + rnd() * 22;
    const grd = g.createRadialGradient(x, y - r * 0.2, r * 0.1, x, y, r);
    grd.addColorStop(0, 'rgba(255,255,255,0.55)'); grd.addColorStop(0.6, 'rgba(250,246,240,0.25)'); grd.addColorStop(1, 'rgba(240,236,230,0)');
    g.fillStyle = grd; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill();
  }
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
function makeClouds(group) {
  const tex = cloudTexture();
  const rnd = mulberry32(77);
  const clouds = [];
  for (let i = 0; i < 30; i++) {
    const c = new THREE.Group();
    const n = 3 + Math.floor(rnd() * 4);
    for (let k = 0; k < n; k++) {
      const m = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, color: 0xffffff, transparent: true, opacity: 0.75 + rnd() * 0.2, depthWrite: false, fog: false }));
      const s = 60 + rnd() * 70;
      m.scale.set(s * 1.6, s * 0.7, 1);
      m.position.set(k * 38 - n * 19, rnd() * 10, rnd() * 20 - 10);
      c.add(m);
    }
    c.position.set(rnd() * 1000 - 500, 150 + rnd() * 80, rnd() * 1000 - 500);
    group.add(c); clouds.push(c);
  }
  return clouds;
}

// ------------------------------------------------------------------ terreno e acqua
function makeDetailTexture() {
  const cv = document.createElement('canvas'); cv.width = cv.height = 128;
  const ctx = cv.getContext('2d');
  const img = ctx.createImageData(128, 128);
  const rnd = mulberry32(5);
  for (let i = 0; i < 128 * 128; i++) {
    const v = 205 + rnd() * 50;
    img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v; img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  ctx.globalAlpha = 0.25; ctx.strokeStyle = '#000';
  for (let i = 0; i < 60; i++) { ctx.beginPath(); const x = rnd() * 128, y = rnd() * 128; ctx.moveTo(x, y); ctx.lineTo(x + rnd() * 3 - 1.5, y - 2 - rnd() * 4); ctx.stroke(); }
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(150, 150);
  t.colorSpace = THREE.SRGBColorSpace;
  t.magFilter = THREE.NearestFilter;
  return t;
}

function makeTerrain() {
  const SEG = 240, SIZE = 600;
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const c = new THREE.Color();
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const h = heightAt(x, z);
    pos.setY(i, h);
    groundColor(x, z, h, c);
    const j = (fbm(x * 0.9, z * 0.9, 1, 3) - 0.5) * 0.08;
    colors[i * 3] = Math.max(0, c.r + j); colors[i * 3 + 1] = Math.max(0, c.g + j); colors[i * 3 + 2] = Math.max(0, c.b + j);
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, map: makeDetailTexture(), roughness: 0.95, metalness: 0 });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  return mesh;
}

// Mappa normale piastrellabile per l'acqua, generata da onde sinusoidali.
function waterNormalTexture() {
  const N = 128, cv = document.createElement('canvas'); cv.width = cv.height = N;
  const ctx = cv.getContext('2d'), img = ctx.createImageData(N, N);
  const h = (x, y) => {
    const u = x / N * Math.PI * 2, v = y / N * Math.PI * 2;
    return Math.sin(u * 3 + v * 2) * 0.5 + Math.sin(u * 5 - v * 3) * 0.3 + Math.sin(u * 2 + v * 7) * 0.2 + Math.sin(-u * 8 + v * 5) * 0.12;
  };
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const dx = h(x + 1, y) - h(x - 1, y), dy = h(x, y + 1) - h(x, y - 1);
    const l = Math.hypot(dx, dy, 1);
    const i = (y * N + x) * 4;
    img.data[i] = (-dx / l * 0.5 + 0.5) * 255; img.data[i + 1] = (-dy / l * 0.5 + 0.5) * 255; img.data[i + 2] = (1 / l * 0.5 + 0.5) * 255; img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(90, 90);
  return t;
}

function makeWater() {
  const geo = new THREE.PlaneGeometry(1400, 1400, 1, 1);
  geo.rotateX(-Math.PI / 2);
  const normalMap = waterNormalTexture();
  const mat = new THREE.MeshStandardMaterial({ color: 0x1f5a70, roughness: 0.08, metalness: 0.1, transparent: true, opacity: 0.86, normalMap, normalScale: new THREE.Vector2(0.4, 0.4), envMapIntensity: 1.4 });
  const m = new THREE.Mesh(geo, mat);
  m.position.y = -0.05;
  m.receiveShadow = true;
  m.userData.normalMap = normalMap;
  return m;
}

// Petali di ciliegio sospesi nell'aria attorno alla visuale.
function makePetals() {
  const N = 450, BOX = [70, 26, 70];
  const cv = document.createElement('canvas'); cv.width = cv.height = 32;
  const ctx = cv.getContext('2d');
  const grd = ctx.createRadialGradient(16, 14, 2, 16, 16, 14);
  grd.addColorStop(0, '#ffd6e4'); grd.addColorStop(0.6, '#f08cb0'); grd.addColorStop(1, 'rgba(240,160,190,0)');
  ctx.fillStyle = grd;
  ctx.beginPath(); ctx.ellipse(16, 16, 13, 8, 0.6, 0, Math.PI * 2); ctx.fill();
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  const pos = new Float32Array(N * 3), seed = new Float32Array(N);
  const rnd = mulberry32(808);
  for (let i = 0; i < N; i++) { pos[i * 3] = (rnd() - 0.5) * BOX[0]; pos[i * 3 + 1] = rnd() * BOX[1]; pos[i * 3 + 2] = (rnd() - 0.5) * BOX[2]; seed[i] = rnd() * 100; }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(geo, new THREE.PointsMaterial({ map: tex, size: 0.6, transparent: true, depthWrite: false, alphaTest: 0.05, color: 0xffffff }));
  pts.frustumCulled = false;
  let t = 0;
  pts.userData.update = (dt, focus) => {
    t += dt;
    const p = geo.attributes.position.array;
    for (let i = 0; i < N; i++) {
      const k = i * 3, sd = seed[i];
      p[k] += (Math.sin(t * 0.7 + sd) * 0.8 + 0.6) * dt;
      p[k + 1] -= (0.6 + (sd % 1) * 0.5) * dt;
      p[k + 2] += Math.cos(t * 0.5 + sd * 1.3) * 0.6 * dt;
      // riporta i petali nella scatola attorno alla visuale
      let rx = p[k] - focus.x, rz = p[k + 2] - focus.z;
      if (rx > BOX[0] / 2) p[k] -= BOX[0]; else if (rx < -BOX[0] / 2) p[k] += BOX[0];
      if (rz > BOX[2] / 2) p[k + 2] -= BOX[2]; else if (rz < -BOX[2] / 2) p[k + 2] += BOX[2];
      const ground = heightAt(p[k], p[k + 2]);
      if (p[k + 1] < ground || p[k + 1] > focus.y + BOX[1]) p[k + 1] = focus.y + BOX[1] * (0.5 + (sd % 1) * 0.5);
    }
    geo.attributes.position.needsUpdate = true;
  };
  return pts;
}

// ------------------------------------------------------------------ vegetazione
function makeVegetation(group) {
  const rnd = mulberry32(4242);
  const lists = { pine: [], cherry: [], bamboo: [], maple: [], rock: [], bush: [] };
  for (let x = -292; x < 292; x += 5.5) for (let z = -292; z < 292; z += 5.5) {
    const px = x + (rnd() - 0.5) * 5, pz = z + (rnd() - 0.5) * 5;
    const r = rnd(), r2 = rnd();
    const h = heightAt(px, pz);
    if (h < 0.9) continue;
    let skip = false;
    for (const kid of KINGDOM_IDS) { const v = KINGDOMS[kid].village; if (Math.hypot(px - v.x, pz - v.z) < 52) skip = true; }
    if (skip || Math.hypot(px - CENTER.x, pz - CENTER.z) < 40 || roadDistance(px, pz) < 5) continue;
    const dens = fbm(px * 0.018, pz * 0.018, 3, 31);
    const s = 0.8 + rnd() * 0.5, rot = rnd() * Math.PI * 2;
    const item = [px, h - 0.2, pz, s, rot];
    if (dens > 0.53 && r < (dens - 0.5) * 2.6) {
      const west = px < -60 && pz > -60, south = pz < -90, east = px > 60 && pz > -60;
      if (h > 16) lists.pine.push(item);
      else if (west && r2 < 0.45) lists.bamboo.push(item);
      else if (south && r2 < 0.35) lists.cherry.push(item);
      else if (east && r2 < 0.3) lists.maple.push(item);
      else if (r2 < 0.12) lists.cherry.push(item);
      else lists.pine.push(item);
    } else if (r < 0.018) lists.rock.push(item);
    else if (r < 0.04 && h < 20) lists.bush.push(item);
    else if (r < 0.047 && h < 14) (rnd() < 0.5 ? lists.cherry : lists.maple).push(item);
  }
  // alberi decorativi nei villaggi
  for (const kid of KINGDOM_IDS) {
    const f = villageFrame(kid);
    for (const [lx, lz] of VILLAGE_LAYOUT.trees) {
      const x = f.x + lx * f.cos + lz * f.sin, z = f.z - lx * f.sin + lz * f.cos;
      lists.cherry.push([x, VILLAGE_HEIGHT - 0.1, z, 1.1, rnd() * 6]);
    }
  }

  if (hasNature()) { buildNature(group, lists, cutaway); return; }
  const trunk = 0x5a3e28, darkTrunk = 0x3e2a1c;
  const geos = {
    pine: mergeParts([
      { geo: new THREE.CylinderGeometry(0.22, 0.35, 2.6, 6), color: darkTrunk, m: mtx(0, 1.3, 0) },
      { geo: new THREE.ConeGeometry(2.3, 3.0, 7), color: 0x2c4a28, m: mtx(0, 3.4, 0) },
      { geo: new THREE.ConeGeometry(1.8, 2.6, 7), color: 0x335530, m: mtx(0, 4.9, 0, 1, 1, 1, 0.4) },
      { geo: new THREE.ConeGeometry(1.15, 2.2, 7), color: 0x3a5e34, m: mtx(0, 6.3, 0, 1, 1, 1, 0.9) },
    ]),
    cherry: mergeParts([
      { geo: new THREE.CylinderGeometry(0.22, 0.38, 3.0, 6), color: trunk, m: mtx(0, 1.5, 0, 1, 1, 1, 0, 0.08) },
      { geo: new THREE.CylinderGeometry(0.1, 0.16, 1.8, 5), color: trunk, m: mtx(0.7, 3.0, 0, 1, 1, 1, 0, 0, -0.7) },
      { geo: new THREE.IcosahedronGeometry(1.9, 0), color: 0xeaa2bc, m: mtx(0, 4.0, 0, 1.2, 0.8, 1.1) },
      { geo: new THREE.IcosahedronGeometry(1.4, 0), color: 0xf2b8cc, m: mtx(1.5, 3.7, 0.4, 1, 0.8, 1) },
      { geo: new THREE.IcosahedronGeometry(1.3, 0), color: 0xdc94b0, m: mtx(-1.2, 3.5, -0.6, 1, 0.8, 1) },
    ]),
    maple: mergeParts([
      { geo: new THREE.CylinderGeometry(0.2, 0.34, 2.8, 6), color: darkTrunk, m: mtx(0, 1.4, 0) },
      { geo: new THREE.IcosahedronGeometry(1.8, 0), color: 0xb8462a, m: mtx(0, 3.8, 0, 1.2, 0.85, 1.2) },
      { geo: new THREE.IcosahedronGeometry(1.3, 0), color: 0xd06a2c, m: mtx(1.2, 3.4, 0.5, 1, 0.8, 1) },
      { geo: new THREE.IcosahedronGeometry(1.2, 0), color: 0xa8382a, m: mtx(-1.0, 3.3, -0.4, 1, 0.8, 1) },
    ]),
    bamboo: mergeParts([
      ...[[0, 0, 7.5], [0.6, 0.3, 6.5], [-0.5, 0.4, 7], [0.2, -0.6, 8], [-0.4, -0.4, 6], [0.8, -0.4, 7.2]].map(([x, z, hh]) =>
        ({ geo: new THREE.CylinderGeometry(0.09, 0.11, hh, 5), color: 0x7aa24a, m: mtx(x, hh / 2, z, 1, 1, 1, 0, x * 0.05, z * 0.05) })),
      { geo: new THREE.IcosahedronGeometry(1.2, 0), color: 0x5c8a34, m: mtx(0, 6.6, 0, 1.3, 0.5, 1.3) },
      { geo: new THREE.IcosahedronGeometry(0.9, 0), color: 0x6a9a3c, m: mtx(0.6, 5.8, 0.2, 1.2, 0.5, 1.2) },
    ]),
    rock: mergeParts([
      { geo: new THREE.DodecahedronGeometry(1.1, 0), color: 0x85807a, m: mtx(0, 0.4, 0, 1.3, 0.8, 1) },
      { geo: new THREE.DodecahedronGeometry(0.6, 0), color: 0x77726c, m: mtx(0.9, 0.2, 0.4, 1, 0.8, 1) },
    ]),
    bush: mergeParts([
      { geo: new THREE.IcosahedronGeometry(0.9, 0), color: 0x4a7030, m: mtx(0, 0.5, 0, 1.3, 0.8, 1.1) },
      { geo: new THREE.IcosahedronGeometry(0.6, 0), color: 0x557a36, m: mtx(0.7, 0.4, 0.3) },
    ]),
  };
  const mat = cutaway(soft({ vertexColors: true }), 'veg');
  const dummy = new THREE.Object3D();
  const col = new THREE.Color();
  for (const k in lists) {
    const arr = lists[k];
    if (!arr.length) continue;
    const im = new THREE.InstancedMesh(geos[k], mat, arr.length);
    arr.forEach(([x, y, z, s, r], i) => {
      dummy.position.set(x, y, z); dummy.rotation.set(0, r, 0); dummy.scale.set(s, s * (0.9 + (i % 5) * 0.05), s);
      dummy.updateMatrix(); im.setMatrixAt(i, dummy.matrix);
      const v = 0.85 + ((i * 7919) % 100) / 100 * 0.3;
      im.setColorAt(i, col.setRGB(v, v, v));
    });
    im.castShadow = k !== 'bush'; im.receiveShadow = true;
    group.add(im);

  }
}

// ------------------------------------------------------------------ architettura
function houseModel(w, d, roofColor, opt = {}) {
  const g = new THREE.Group();
  const wallH = opt.wallH || 2.8;
  g.add(M(new THREE.BoxGeometry(w + 1, 0.6, d + 1), lam(0x8a8478), 0, 0.3, 0));
  g.add(M(new THREE.BoxGeometry(w, wallH, d), lam(0xe6dcc2), 0, 0.6 + wallH / 2, 0));
  const pillar = new THREE.CylinderGeometry(0.17, 0.19, wallH + 0.2, 8);
  const red = lam(0x8c2a1c);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) g.add(M(pillar, red, sx * w / 2, 0.6 + wallH / 2, sz * d / 2));
  for (const sx of [-0.33, 0.33]) for (const sz of [-1, 1]) g.add(M(pillar, red, sx * w, 0.6 + wallH / 2, sz * d / 2));
  g.add(M(bandGeo(w + 0.3, 0.5, d + 0.3), lam(0x6a1e14), 0, 0.5 + wallH, 0));
  g.add(M(new THREE.BoxGeometry(w + 0.06, 0.16, d + 0.06), lam(0x4a2a18), 0, 0.6 + wallH * 0.42, 0));
  g.add(M(new THREE.BoxGeometry(w + 0.2, 0.18, d + 0.2), lam(0x4a3a2a), 0, 0.7, 0));
  // porta e finestre a grata sul lato frontale (+z)
  g.add(M(new THREE.BoxGeometry(1.5, 2.1, 0.12), lam(0x4a2a18), 0, 0.6 + 1.05, d / 2 + 0.03, false));
  const lattice = lam(0x3a2414);
  for (const sx of [-1, 1]) {
    g.add(M(new THREE.BoxGeometry(1.2, 1.0, 0.1), lam(0xf4ecd0), sx * w * 0.3, 2.2, d / 2 + 0.03, false));
    for (let i = -1; i <= 1; i++) g.add(M(new THREE.BoxGeometry(0.05, 1.0, 0.12), lattice, sx * w * 0.3 + i * 0.35, 2.2, d / 2 + 0.05, false));
    g.add(M(new THREE.BoxGeometry(1.2, 0.05, 0.12), lattice, sx * w * 0.3, 2.2, d / 2 + 0.05, false));
  }
  const roof = M(curvedRoof(w + 2.6, d + 2.4, opt.roofH || 2.4, 0.7), lam(roofColor, { side: THREE.DoubleSide }), 0, 0.6 + wallH + 0.15, 0);
  g.add(roof);
  const ridgeY = 0.6 + wallH + 0.15 + (opt.roofH || 2.4) + 0.05, ridgeL = Math.max(0.3, Math.abs(w - d)) + 0.6;
  g.add(M(new THREE.BoxGeometry(ridgeL, 0.3, 0.35), lam(0x2a2a2a), 0, ridgeY, 0));
  // ornamenti a coda di pesce alle estremità del colmo
  for (const sx of [-1, 1]) g.add(withRot(M(new THREE.BoxGeometry(0.24, 0.8, 0.42), lam(0x2a2a2a), sx * ridgeL / 2, ridgeY + 0.35, 0), 'z', -sx * 0.4));
  return g;
}

function pagodaModel(size, roofColor, accent) {
  const g = new THREE.Group();
  g.add(M(new THREE.BoxGeometry(size + 2, 0.5, size + 2), lam(0x8a8478), 0, 0.25, 0));
  g.add(M(new THREE.BoxGeometry(size + 1, 0.5, size + 1), lam(0x9a9488), 0, 0.75, 0));
  let y = 1.0, s = size;
  const red = lam(0x8c2a1c);
  for (let tier = 0; tier < 4; tier++) {
    const h = tier === 0 ? 3.0 : 2.0;
    g.add(M(new THREE.BoxGeometry(s, h, s), lam(tier === 0 ? 0xe6dcc2 : 0xb83a26), 0, y + h / 2, 0));
    const pg = new THREE.CylinderGeometry(0.16, 0.16, h, 8);
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) g.add(M(pg, red, sx * s / 2, y + h / 2, sz * s / 2));
    y += h;
    g.add(M(bandGeo(s + 0.3, 0.45, s + 0.3), lam(0x5a1a10), 0, y, 0));
    g.add(M(curvedRoof(s + 3.2, s + 3.2, 1.5, 0.9), lam(roofColor, { side: THREE.DoubleSide }), 0, y + 0.1, 0));
    y += 1.2;
    s *= 0.74;
  }
  const gold = lam(0xd8b048, { emissive: 0x3a2a00 });
  g.add(M(new THREE.CylinderGeometry(0.12, 0.2, 2.6, 6), gold, 0, y + 1.0, 0));
  for (let i = 0; i < 4; i++) g.add(withRot(M(new THREE.TorusGeometry(0.35 - i * 0.06, 0.06, 4, 10), gold, 0, y + 0.5 + i * 0.45, 0), 'x', Math.PI / 2));
  g.add(M(new THREE.SphereGeometry(0.28, 8, 6), gold, 0, y + 2.5, 0));
  // targa del regno sopra l'ingresso
  g.add(M(new THREE.BoxGeometry(2.2, 0.8, 0.12), lam(accent), 0, 3.3, size / 2 + 0.08, false));
  g.add(M(new THREE.BoxGeometry(1.4, 2.4, 0.12), lam(0x4a2a18), 0, 2.2, size / 2 + 0.05, false));
  return g;
}

function forgeModel(w, d, roofColor) {
  const g = new THREE.Group();
  g.add(M(new THREE.BoxGeometry(w + 0.6, 0.5, d + 0.6), lam(0x6a6460), 0, 0.25, 0));
  const post = new THREE.CylinderGeometry(0.2, 0.22, 3.2, 8);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) g.add(M(post, lam(0x5a3a24), sx * (w / 2 - 0.3), 2.1, sz * (d / 2 - 0.3)));
  g.add(M(new THREE.BoxGeometry(w, 2.6, 0.4), lam(0x7a6a5a), 0, 1.8, -d / 2 + 0.3));
  g.add(M(curvedRoof(w + 1.6, d + 1.6, 1.6, 0.6), lam(roofColor, { side: THREE.DoubleSide }), 0, 3.7, 0));
  // fornace
  g.add(M(new THREE.BoxGeometry(2.2, 2.0, 1.6), lam(0x5a4a40), -1.5, 1.5, -d / 2 + 1.3));
  g.add(M(new THREE.BoxGeometry(0.9, 0.7, 0.1), new THREE.MeshBasicMaterial({ color: 0xff7a20 }), -1.5, 1.2, -d / 2 + 2.12, false));
  g.add(M(new THREE.CylinderGeometry(0.35, 0.45, 2.5, 6), lam(0x4a3a30), -1.5, 3.6, -d / 2 + 1.1));
  // incudine
  g.add(M(new THREE.BoxGeometry(0.5, 0.7, 0.5), lam(0x3a3a3a), 1.6, 0.85, 1.4));
  g.add(M(new THREE.BoxGeometry(1.1, 0.3, 0.45), lam(0x4a4a50), 1.6, 1.35, 1.4));
  const light = new THREE.PointLight(0xff8a30, 6, 12, 1.6);
  light.position.set(-1.5, 1.4, -d / 2 + 2.6);
  g.add(light);
  g.userData.flicker = light;
  return g;
}

function stallModel(cloth) {
  const g = new THREE.Group();
  g.add(M(new THREE.BoxGeometry(4.2, 1.0, 1.6), lam(0x6a4a2c), 0, 0.5, 0));
  g.add(M(new THREE.BoxGeometry(4.4, 0.12, 1.8), lam(0x8a6a44), 0, 1.06, 0));
  const post = new THREE.CylinderGeometry(0.08, 0.08, 2.6, 6);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) g.add(M(post, lam(0x4a3220), sx * 2.0, 1.3, sz * 0.8 - 0.4));
  const canopy = M(new THREE.BoxGeometry(4.8, 0.1, 2.8), lam(cloth), 0, 2.6, -0.3);
  canopy.rotation.x = 0.18;
  g.add(canopy);
  const rnd = mulberry32(cloth);
  for (let i = 0; i < 7; i++) {
    const c = [0xc0a060, 0x8a3a2a, 0x5a7a3a, 0xd0d0c0, 0x3a5a8a][i % 5];
    g.add(M(new THREE.BoxGeometry(0.35, 0.3, 0.35), lam(c), -1.7 + i * 0.55, 1.28, (rnd() - 0.5) * 0.6));
  }
  return g;
}

function lanternModel() {
  const g = new THREE.Group();
  g.add(M(new THREE.CylinderGeometry(0.07, 0.09, 2.6, 6), lam(0x3a2a1c), 0, 1.3, 0));
  g.add(M(new THREE.BoxGeometry(0.9, 0.08, 0.08), lam(0x3a2a1c), 0.4, 2.55, 0));
  const lantern = M(new THREE.SphereGeometry(0.28, 8, 6), new THREE.MeshLambertMaterial({ color: 0xd8401c, emissive: 0xff4a10, emissiveIntensity: 0.7 }), 0.75, 2.1, 0, false);
  lantern.scale.y = 1.3;
  g.add(lantern);
  g.add(M(new THREE.CylinderGeometry(0.12, 0.12, 0.08, 8), lam(0x1a1a1a), 0.75, 2.47, 0, false));
  g.add(M(new THREE.CylinderGeometry(0.12, 0.12, 0.08, 8), lam(0x1a1a1a), 0.75, 1.73, 0, false));
  return g;
}

function gateModel(accent, roofColor) {
  const g = new THREE.Group();
  const red = lam(0xa22a1a);
  for (const s of [-1, 1]) {
    g.add(M(new THREE.CylinderGeometry(0.38, 0.42, 6.2, 10), red, s * 5, 3.1, 0));
    g.add(M(new THREE.BoxGeometry(1.1, 0.6, 1.1), lam(0x6a6460), s * 5, 0.3, 0));
  }
  g.add(M(bandGeo(12.5, 0.6, 0.6), red, 0, 5.0, 0));
  g.add(M(new THREE.BoxGeometry(11.5, 0.45, 0.55), red, 0, 5.9, 0));
  g.add(M(curvedRoof(13.5, 2.4, 0.9, 0.7), lam(roofColor, { side: THREE.DoubleSide }), 0, 6.15, 0));
  g.add(M(new THREE.BoxGeometry(2.4, 0.85, 0.2), lam(accent), 0, 5.45, 0.3, false));
  return g;
}

function flagModel(accent) {
  const g = new THREE.Group();
  g.add(M(new THREE.CylinderGeometry(0.08, 0.1, 8, 6), lam(0x3a2a1c), 0, 4, 0));
  const flag = M(new THREE.PlaneGeometry(1.4, 3.0, 1, 6), lam(accent, { side: THREE.DoubleSide }), 0.72, 6.3, 0);
  flag.userData.keep = true;
  g.add(flag);
  g.add(M(new THREE.SphereGeometry(0.14, 6, 5), lam(0xd8b048), 0, 8.05, 0));
  g.userData.flag = flag;
  return g;
}

function wellModel() {
  const g = new THREE.Group();
  g.add(M(new THREE.CylinderGeometry(1.1, 1.2, 0.9, 10, 1, true), lam(0x8a8478, { side: THREE.DoubleSide }), 0, 0.45, 0));
  g.add(M(new THREE.CircleGeometry(1.05, 10).rotateX(-Math.PI / 2), lam(0x24485a), 0, 0.5, 0, false));
  for (const s of [-1, 1]) g.add(M(new THREE.BoxGeometry(0.15, 2.3, 0.15), lam(0x4a3220), s * 0.95, 1.15, 0));
  g.add(M(curvedRoof(2.8, 1.8, 0.7, 0.3), lam(0x3a3f45, { side: THREE.DoubleSide }), 0, 2.3, 0));
  return g;
}

function buildVillage(kid, scene, animated) {
  const k = KINGDOMS[kid];
  const f = villageFrame(kid);
  const vg = new THREE.Group();
  vg.position.set(f.x, VILLAGE_HEIGHT, f.z);
  vg.rotation.y = f.a;
  scene.add(vg);
  const place = (obj, x, z, rot = 0, y = 0) => { obj.position.set(x, y, z); obj.rotation.y = rot; vg.add(obj); return obj; };

  for (const b of VILLAGE_LAYOUT.buildings) {
    let m;
    const rw = b.face && Math.abs(Math.sin(b.face)) > 0.5;
    if (b.kind === 'pagoda') m = pagodaModel(b.w - 1, k.roof, k.hex);
    else if (b.kind === 'forge') { m = forgeModel(b.w, b.d, k.roof); animated.lights.push(m.userData.flicker); }
    else if (b.kind === 'hall') m = houseModel(b.w, b.d, k.roof, { wallH: 3.2, roofH: 2.8 });
    else m = rw ? houseModel(b.d, b.w, k.roof) : houseModel(b.w, b.d, k.roof);
    place(m, b.x, b.z, b.face || 0);
  }
  for (const s of VILLAGE_LAYOUT.stalls) place(stallModel(s.role === 'armi' ? 0x8a2a24 : 0x3a6a4a), s.x, s.z, 0);
  for (const [x, z] of VILLAGE_LAYOUT.lanterns) place(lanternModel(), x, z, x < 0 ? 0 : Math.PI);
  place(wellModel(), VILLAGE_LAYOUT.well.x, VILLAGE_LAYOUT.well.z);
  for (const [x, z] of [[-6, 33], [6, 33], [-30, -10], [30, -10]]) {
    const fl = place(flagModel(k.hex), x, z);
    animated.flags.push(fl.userData.flag);
  }
  // mura
  const angles = wallAngles();
  const segLen = 2 * Math.PI * WALL_RADIUS / 64 + 0.25;
  const wallIm = new THREE.InstancedMesh(new THREE.BoxGeometry(segLen, 3.4, 1.0), lam(0xd8cfbc), angles.length);
  const capIm = new THREE.InstancedMesh(new THREE.BoxGeometry(segLen + 0.1, 0.4, 1.7), lam(k.roof), angles.length);
  const baseIm = new THREE.InstancedMesh(new THREE.BoxGeometry(segLen, 0.9, 1.3), lam(0x7a746a), angles.length);
  const d = new THREE.Object3D();
  angles.forEach((a, i) => {
    d.rotation.set(0, a, 0);
    d.position.set(Math.sin(a) * WALL_RADIUS, 1.7, Math.cos(a) * WALL_RADIUS); d.updateMatrix(); wallIm.setMatrixAt(i, d.matrix);
    d.position.y = 3.55; d.updateMatrix(); capIm.setMatrixAt(i, d.matrix);
    d.position.y = 0.3; d.updateMatrix(); baseIm.setMatrixAt(i, d.matrix);
  });
  for (const im of [wallIm, capIm, baseIm]) { im.castShadow = true; im.receiveShadow = true; vg.add(im); }
  for (const ga of VILLAGE_LAYOUT.gates) {
    const gm = gateModel(k.hex, k.roof);
    gm.position.set(Math.sin(ga) * WALL_RADIUS, 0, Math.cos(ga) * WALL_RADIUS);
    gm.rotation.y = ga;
    vg.add(gm);
  }
  const plazaLight = new THREE.PointLight(0xffc080, 4, 28, 1.5);
  plazaLight.position.set(0, 6, 4);
  vg.add(plazaLight);
  mergeStatic(vg);
}

// Lanterne di pietra lungo le strade, davanti alla pagoda e alle porte: il fuoco interno brilla col bloom.
function buildStoneLanterns(scene) {
  const spots = [];
  for (const kid of KINGDOM_IDS) {
    const f = villageFrame(kid);
    const loc = [[-4.5, -16.8], [4.5, -16.8], [-6.5, WALL_RADIUS + 4], [6.5, WALL_RADIUS + 4]];
    for (const sx of [-1, 1]) loc.push([sx * (WALL_RADIUS + 4), -4.5], [sx * (WALL_RADIUS + 4), 5.5]);
    for (const [lx, lz] of loc) { const w = toWorld(f, lx, lz); spots.push([w.x, w.z, f.a]); }
  }
  const villages = KINGDOM_IDS.map(k => KINGDOMS[k].village);
  let acc = 12, side = 1;
  for (const [x0, z0, x1, z1] of ROADS) {
    const len = Math.hypot(x1 - x0, z1 - z0);
    if (len < 0.01) continue;
    const nx = -(z1 - z0) / len, nz = (x1 - x0) / len;
    for (let d = acc; d < len; d += 26) {
      const t = d / len, x = x0 + (x1 - x0) * t + nx * 4.4 * side, z = z0 + (z1 - z0) * t + nz * 4.4 * side;
      side = -side;
      if (villages.some(v => Math.hypot(x - v.x, z - v.z) < WALL_RADIUS + 9)) continue;
      if (Math.hypot(x - CENTER.x, z - CENTER.z) < 34 || heightAt(x, z) < 0.6 || roadDistance(x, z) < 3.4) continue;
      spots.push([x, z, Math.atan2(x1 - x0, z1 - z0)]);
    }
    acc = 26 - ((len - acc) % 26);
  }
  const stone = 0x9a948a, dark = 0x7a756d;
  const parts = [
    { geo: new THREE.CylinderGeometry(0.5, 0.58, 0.28, 6), color: dark, m: mtx(0, 0.14, 0) },
    { geo: new THREE.CylinderGeometry(0.17, 0.2, 1.0, 8), color: stone, m: mtx(0, 0.78, 0) },
    { geo: new THREE.CylinderGeometry(0.48, 0.4, 0.18, 6), color: stone, m: mtx(0, 1.36, 0) },
    { geo: new THREE.ConeGeometry(0.78, 0.42, 6), color: dark, m: mtx(0, 2.18, 0) },
    { geo: new THREE.SphereGeometry(0.11, 6, 4), color: stone, m: mtx(0, 2.46, 0) },
  ];
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) parts.push({ geo: new THREE.BoxGeometry(0.1, 0.52, 0.1), color: stone, m: mtx(sx * 0.24, 1.71, sz * 0.24) });
  const geo = mergeParts(parts);
  const n = spots.length;
  const body = new THREE.InstancedMesh(geo, soft({ vertexColors: true }), n);
  const fireMat = new THREE.MeshBasicMaterial();
  fireMat.color.setRGB(2.4, 1.35, 0.5);
  const fire = new THREE.InstancedMesh(new THREE.BoxGeometry(0.34, 0.4, 0.34), fireMat, n);
  const d = new THREE.Object3D();
  spots.forEach(([x, z, r], i) => {
    d.position.set(x, heightAt(x, z) - 0.05, z); d.rotation.set(0, r, 0); d.scale.setScalar(1.15); d.updateMatrix();
    body.setMatrixAt(i, d.matrix);
    d.position.y += 1.71 * 1.15; d.updateMatrix();
    fire.setMatrixAt(i, d.matrix);
  });
  body.castShadow = true; body.receiveShadow = true;
  scene.add(body); scene.add(fire);
  return spots.length;
}

// Altopiano centrale: rovine e spade gigantesche conficcate nel terreno.
function buildArena(scene) {
  const g = new THREE.Group();
  g.position.set(CENTER.x, 4, CENTER.z);
  scene.add(g);
  const stone = lam(0x8c8579), dark = lam(0x5a554e);
  const rnd = mulberry32(99);
  for (let i = 0; i < 14; i++) {
    const a = i / 14 * Math.PI * 2;
    const h = 2 + rnd() * 5;
    const p = M(new THREE.CylinderGeometry(0.7, 0.85, h, 8), stone, Math.sin(a) * 26, h / 2, Math.cos(a) * 26);
    p.rotation.z = (rnd() - 0.5) * 0.2;
    g.add(p);
    if (rnd() < 0.5) g.add(M(new THREE.BoxGeometry(1.4, 0.6, 1.4), dark, Math.sin(a) * 26, h + 0.3, Math.cos(a) * 26));
  }
  for (let i = 0; i < 4; i++) {
    const a = i / 4 * Math.PI * 2 + 0.4;
    g.add(M(new THREE.BoxGeometry(5, 0.5, 5), stone, Math.sin(a) * 12, 0.25, Math.cos(a) * 12));
  }
  const sword = (x, z, rx, rz, s) => {
    const sw = new THREE.Group();
    sw.add(M(new THREE.BoxGeometry(1.0 * s, 9 * s, 0.25 * s), lam(0x9aa0a6), 0, 0, 0));
    sw.add(M(new THREE.BoxGeometry(3.2 * s, 0.6 * s, 0.7 * s), lam(0x6a5a3a), 0, 4.6 * s, 0));
    sw.add(M(new THREE.CylinderGeometry(0.3 * s, 0.3 * s, 2.6 * s, 6), lam(0x3a2a1c), 0, 6.2 * s, 0));
    sw.add(M(new THREE.SphereGeometry(0.45 * s, 6, 5), lam(0xb8902a), 0, 7.6 * s, 0));
    sw.position.set(x, 2.5 * s, z);
    sw.rotation.set(rx, rnd() * 3, rz);
    g.add(sw);
  };
  sword(-18, 6, 0.25, 0.1, 1.3); sword(17, -9, -0.2, 0.3, 1.1); sword(5, 20, 0.1, -0.35, 1.0); sword(-9, -19, -0.3, -0.15, 1.2);
  mergeStatic(g);
}

// Piccoli santuari di pietra lungo le strade
function buildShrines(scene) {
  const rnd = mulberry32(31337);
  const all = new THREE.Group();
  let placed = 0;
  for (let i = 0; i < 400 && placed < 18; i++) {
    const x = rnd() * 460 - 230, z = rnd() * 460 - 230;
    const rd = roadDistance(x, z);
    if (rd < 6 || rd > 9) continue;
    const h = heightAt(x, z);
    if (h < 1) continue;
    let near = false;
    for (const kid of KINGDOM_IDS) { const v = KINGDOMS[kid].village; if (Math.hypot(x - v.x, z - v.z) < 55) near = true; }
    if (near || Math.hypot(x - CENTER.x, z - CENTER.z) < 45) continue;
    const g = new THREE.Group();
    const st = lam(0x8c8579);
    g.add(M(new THREE.BoxGeometry(0.9, 0.3, 0.9), st, 0, 0.15, 0));
    g.add(M(new THREE.CylinderGeometry(0.18, 0.22, 1.0, 6), st, 0, 0.8, 0));
    g.add(M(new THREE.BoxGeometry(0.8, 0.55, 0.8), st, 0, 1.55, 0));
    g.add(M(new THREE.BoxGeometry(0.3, 0.3, 0.82), new THREE.MeshBasicMaterial({ color: 0xffb060 }), 0, 1.55, 0, false));
    g.add(withRot(M(new THREE.ConeGeometry(0.75, 0.55, 4), st, 0, 2.1, 0), 'y', Math.PI / 4));
    g.position.set(x, h - 0.05, z);
    g.rotation.y = rnd() * 6;
    all.add(g);
    placed++;
  }
  scene.add(all);
  mergeStatic(all);
}

// ------------------------------------------------------------------ assemblaggio
// ------------------------------------------------------------------ Cripta delle Mille Lanterne
function stoneTileTexture(repX, repZ) {
  const cv = document.createElement('canvas'); cv.width = cv.height = 128;
  const ctx = cv.getContext('2d');
  const rnd = mulberry32(17);
  for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) {
    const v = 105 + rnd() * 30;
    ctx.fillStyle = `rgb(${v + 8},${v},${v - 6})`;
    ctx.fillRect(x * 32 + 1, y * 32 + 1, 30, 30);
  }
  ctx.strokeStyle = '#1a1410'; ctx.lineWidth = 2;
  for (let i = 0; i <= 4; i++) { ctx.beginPath(); ctx.moveTo(i * 32, 0); ctx.lineTo(i * 32, 128); ctx.stroke(); ctx.beginPath(); ctx.moveTo(0, i * 32); ctx.lineTo(128, i * 32); ctx.stroke(); }
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repX, repZ);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

const builtDungeons = new Map();
export function buildDungeon(scene, ox, oz) {
  const key = ox + ',' + oz;
  if (builtDungeons.has(key)) return builtDungeons.get(key);
  const g = new THREE.Group();
  g.position.set(ox, 0, oz);
  for (const [x1, z1, x2, z2] of DUNGEON.rooms) {
    const w = x2 - x1, d = z2 - z1;
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(w, d), new THREE.MeshLambertMaterial({ map: stoneTileTexture(w / 4, d / 4) }));
    floor.rotation.x = -Math.PI / 2;
    floor.position.set((x1 + x2) / 2, 0.02, (z1 + z2) / 2);
    floor.receiveShadow = true;
    g.add(floor);
  }
  const wallM = lam(0x5e5248), capM = lam(0x2e2620), baseM = lam(0x6a5e52), red = lam(0x8a2a1a);
  const lanternMat = new THREE.MeshLambertMaterial({ color: 0xd8401c, emissive: 0xff4a10, emissiveIntensity: 0.9 });
  for (const [x1, z1, x2, z2] of DUNGEON.walls) {
    const horiz = z1 === z2, len = Math.hypot(x2 - x1, z2 - z1);
    const cx = (x1 + x2) / 2, cz = (z1 + z2) / 2;
    const sx = horiz ? len + 1.2 : 1.2, sz = horiz ? 1.2 : len + 1.2;
    g.add(M(new THREE.BoxGeometry(sx, 6, sz), wallM, cx, 3, cz));
    g.add(M(new THREE.BoxGeometry(sx + 0.3, 0.5, sz + 0.3), capM, cx, 6.2, cz));
    g.add(M(new THREE.BoxGeometry(sx + 0.2, 0.6, sz + 0.2), baseM, cx, 0.3, cz));
    g.add(M(new THREE.BoxGeometry(horiz ? len : 1.25, 0.25, horiz ? 1.25 : len), red, cx, 4.6, cz, false));
    // lanterne di carta sul lato interno del muro
    const n = Math.floor(len / 8);
    for (let i = 0; i < n; i++) {
      const tpos = (i + 0.5) / n;
      const px = x1 + (x2 - x1) * tpos, pz = z1 + (z2 - z1) * tpos;
      for (const sgn of [-1, 1]) {
        const lx = px + (horiz ? 0 : sgn * 1.1), lz = pz + (horiz ? sgn * 1.1 : 0);
        if (!dungeonWalkable(lx, lz, 0)) continue;
        const l = new THREE.Mesh(new THREE.SphereGeometry(0.32, 8, 6), lanternMat);
        l.scale.y = 1.3; l.position.set(lx, 3.6, lz);
        g.add(l);
        g.add(M(new THREE.CylinderGeometry(0.14, 0.14, 0.1, 8), capM, lx, 4.05, lz, false));
      }
    }
  }
  // bracieri con luce calda
  const brazier = (x, z) => {
    g.add(M(new THREE.CylinderGeometry(0.7, 0.5, 1.0, 8), lam(0x3a2a1a), x, 0.5, z));
    g.add(M(new THREE.ConeGeometry(0.5, 0.9, 6), new THREE.MeshBasicMaterial({ color: 0xffa040 }), x, 1.4, z, false));
    const pl = new THREE.PointLight(0xffa850, 32, 36, 1.4);
    pl.position.set(x, 2.5, z);
    g.add(pl);
  };
  brazier(0, 2); brazier(0, 21); brazier(-8, 38); brazier(8, 38); brazier(27, 45); brazier(55, 45); brazier(55, 70); brazier(42, 100); brazier(68, 100);
  // arena di Shen: lanterne di pietra a fuoco azzurro e altare
  const ghost = new THREE.MeshLambertMaterial({ color: 0x9ad8ff, emissive: 0x6ab8ff, emissiveIntensity: 1.2 });
  for (let i = 0; i < 10; i++) {
    const a = i / 10 * Math.PI * 2, x = 55 + Math.cos(a) * 17, z = 100 + Math.sin(a) * 15;
    if (!dungeonWalkable(x, z, 1)) continue;
    g.add(M(new THREE.BoxGeometry(0.9, 0.3, 0.9), baseM, x, 0.15, z));
    g.add(M(new THREE.CylinderGeometry(0.18, 0.24, 1.3, 6), baseM, x, 0.95, z));
    g.add(M(new THREE.BoxGeometry(0.8, 0.6, 0.8), baseM, x, 1.9, z));
    g.add(M(new THREE.BoxGeometry(0.35, 0.35, 0.82), ghost, x, 1.9, z, false));
    g.add(withRot(M(new THREE.ConeGeometry(0.7, 0.5, 4), baseM, x, 2.45, z), 'y', Math.PI / 4));
  }
  g.add(M(new THREE.CylinderGeometry(7, 7.6, 0.4, 24), lam(0x2e2824), 55, 0.2, 106));
  g.add(M(new THREE.CylinderGeometry(5, 5, 0.06, 24), lam(0x4a2a5a), 55, 0.42, 106, false));
  const blue = new THREE.PointLight(0x7ab8ff, 22, 34, 1.5);
  blue.position.set(55, 4, 106);
  g.add(blue);
  // portale d'ingresso
  for (const sx of [-1, 1]) g.add(M(new THREE.CylinderGeometry(0.4, 0.45, 6, 10), lam(0xa22a1a), sx * 4, 3, -9));
  g.add(M(new THREE.BoxGeometry(10, 0.5, 0.6), lam(0xa22a1a), 0, 5.6, -9));
  mergeStatic(g);
  scene.add(g);
  builtDungeons.set(key, g);
  return g;
}

export function buildWorld(scene, post) {
  scene.background = new THREE.Color(0xb8cde0);
  scene.fog = new THREE.Fog(0xc8d4dc, 110, 420);
  const sky = makeSky();
  scene.add(sky);
  const cloudGroup = new THREE.Group();
  scene.add(cloudGroup);
  const clouds = makeClouds(cloudGroup);

  const hemi = new THREE.HemisphereLight(0xb8ccff, 0x6a5a40, 0.6);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight(0xffdcae, 4.2);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const sc = sun.shadow.camera;
  sc.left = -55; sc.right = 55; sc.top = 55; sc.bottom = -55; sc.near = 1; sc.far = 260;
  sun.shadow.bias = -0.0008;
  sun.shadow.normalBias = 0.6;
  scene.add(sun); scene.add(sun.target);
  const sunDir = SUN_DIR;

  const terrain = makeTerrain();
  scene.add(terrain);
  const water = makeWater();
  scene.add(water);
  const petals = makePetals();
  scene.add(petals);
  const applyQuality = (q) => {
    const size = q.shadows || 512;
    sun.shadow.mapSize.set(size, size);
    if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
    petals.visible = q.petals;
    scene.traverse(o => { if (o.userData.outline && !o.parent?.userData?.ent) o.visible = q.outlines; });
  };

  const veg = new THREE.Group();
  makeVegetation(veg);
  scene.add(veg);

  const animated = { flags: [], lights: [] };
  for (const kid of KINGDOM_IDS) buildVillage(kid, scene, animated);
  buildArena(scene);
  buildShrines(scene);
  buildStoneLanterns(scene);

  if (post) { applyQuality(post.q); post.onChange(applyQuality); }
  // luce ambientale e riflessi presi dal cielo
  if (post) {
    const pmrem = new THREE.PMREMGenerator(post.renderer);
    const envScene = new THREE.Scene();
    envScene.add(makeSky());
    scene.environment = pmrem.fromScene(envScene, 0, 1, 3000).texture;
    scene.environmentIntensity = 0.65;
    pmrem.dispose();
  }
  let t = 0, indoor = false;
  const outdoorFog = scene.fog, indoorFog = new THREE.Fog(0x161010, 28, 120);
  const outdoorBg = scene.background, indoorBg = new THREE.Color(0x161010);
  return {
    terrain, sun, sky,
    // Atmosfera della cripta: buio, nebbia scura, luci calde.
    setIndoor(on) {
      if (on === indoor) return;
      indoor = on;
      scene.fog = on ? indoorFog : outdoorFog;
      scene.background = on ? indoorBg : outdoorBg;
      sky.visible = !on; cloudGroup.visible = !on;
      hemi.intensity = on ? 1.15 : 0.6;
      hemi.color.set(on ? 0xffd8b8 : 0xb8ccff);
      sun.intensity = on ? 0.5 : 4.2;
      scene.environmentIntensity = on ? 0.15 : 0.65;
      petals.visible = !on && (!post || post.q.petals);
    },
    buildDungeon: (ox, oz) => { const r = buildDungeon(scene, ox, oz); if (post) applyQuality(post.q); return r; },
    update(dt, focus, camera) {
      t += dt;
      updateCutaway(camera, focus);
      sky.position.copy(focus);
      sun.position.set(focus.x + sunDir.x * 120, focus.y + sunDir.y * 120, focus.z + sunDir.z * 120);
      sun.target.position.copy(focus);
      for (const c of clouds) { c.position.x += dt * 2.5; if (c.position.x > 480) c.position.x = -480; }
      for (const fl of animated.flags) fl.rotation.y = Math.sin(t * 1.7 + fl.id) * 0.25;
      for (const l of animated.lights) l.intensity = 5 + Math.sin(t * 9) * 0.8 + Math.sin(t * 23) * 0.5;
      water.userData.normalMap.offset.set(t * 0.012, t * 0.007);
      WIND.value = t;
      if (petals.visible) petals.userData.update(dt, focus);
    },
  };
}
