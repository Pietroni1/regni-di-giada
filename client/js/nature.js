// Alberi, cespugli e rocce creati in Blender (tools/blender/natura.py), con texture dipinte a mano
// generate qui: chiome a "carte" di fiori, aghi e foglie che ondeggiano al vento, corteccia e roccia.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { mulberry32 } from '/shared/world.js';

let GEO = null;
export const WIND = { value: 0 };

export async function loadNatureAssets() {
  const gltf = await new GLTFLoader().loadAsync('/assets/natura.glb');
  GEO = {};
  gltf.scene.traverse((o) => { if (o.isMesh) GEO[o.name] = o.geometry; });
}
export const hasNature = () => !!GEO;

// ------------------------------------------------------------------ texture dipinte
const rand = mulberry32(9);
const R = (a, b) => a + rand() * (b - a);

function paintBlossoms(g, ox, oy) {
  for (let i = 0; i < 110; i++) {
    const a = R(0, Math.PI * 2), d = Math.sqrt(rand()) * 104;
    const x = ox + 128 + Math.cos(a) * d, y = oy + 128 + Math.sin(a) * d * 0.92;
    const shade = 1 - (y - oy) / 256 * 0.45, r = R(9, 14);
    if (rand() < 0.12) { // qualche foglia
      g.fillStyle = `rgb(${70 * shade | 0},${110 * shade | 0},${50 * shade | 0})`;
      g.beginPath(); g.ellipse(x, y, r * 0.5, r, R(0, 3), 0, Math.PI * 2); g.fill();
      continue;
    }
    for (let k = 0; k < 5; k++) {
      const pa = k / 5 * Math.PI * 2 + R(0, 1);
      const px = x + Math.cos(pa) * r * 0.55, py = y + Math.sin(pa) * r * 0.55;
      const grd = g.createRadialGradient(x, y, 1, px, py, r * 0.6);
      grd.addColorStop(0, `rgb(${226 * shade | 0},${110 * shade | 0},${150 * shade | 0})`);
      grd.addColorStop(1, `rgb(${255 * shade | 0},${222 * shade | 0},${234 * shade | 0})`);
      g.fillStyle = grd;
      g.beginPath(); g.ellipse(px, py, r * 0.5, r * 0.36, pa, 0, Math.PI * 2); g.fill();
    }
    g.fillStyle = '#f6d36a'; g.beginPath(); g.arc(x, y, 1.8, 0, Math.PI * 2); g.fill();
  }
}

function paintNeedles(g, ox, oy) {
  g.lineCap = 'round';
  for (let i = 0; i < 46; i++) {
    const a = R(0, Math.PI * 2), d = Math.sqrt(rand()) * 92;
    const x = ox + 128 + Math.cos(a) * d * 1.1, y = oy + 140 + Math.sin(a) * d * 0.7;
    const shade = 1.08 - (y - oy) / 256 * 0.55;
    for (let k = 0; k < 22; k++) {
      const na = -Math.PI / 2 + R(-1.35, 1.35), L = R(18, 34);
      const grd = g.createLinearGradient(x, y, x + Math.cos(na) * L, y + Math.sin(na) * L);
      grd.addColorStop(0, `rgb(${30 * shade | 0},${64 * shade | 0},${38 * shade | 0})`);
      grd.addColorStop(1, `rgb(${110 * shade | 0},${160 * shade | 0},${78 * shade | 0})`);
      g.strokeStyle = grd; g.lineWidth = R(2.2, 3.4);
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(na) * L, y + Math.sin(na) * L); g.stroke();
    }
  }
}

function paintMaple(g, ox, oy) {
  const cols = [[200, 64, 28], [224, 106, 32], [240, 160, 48], [168, 40, 24], [210, 80, 30]];
  for (let i = 0; i < 80; i++) {
    const a = R(0, Math.PI * 2), d = Math.sqrt(rand()) * 102;
    const x = ox + 128 + Math.cos(a) * d, y = oy + 128 + Math.sin(a) * d * 0.92;
    const shade = 1.05 - (y - oy) / 256 * 0.45, c = cols[i % cols.length], r = R(11, 17), rot = R(0, 6.3);
    g.fillStyle = `rgb(${c[0] * shade | 0},${c[1] * shade | 0},${c[2] * shade | 0})`;
    g.beginPath();
    for (let k = 0; k <= 10; k++) {
      const pa = rot + k / 10 * Math.PI * 2, rr = k % 2 ? r * 0.45 : r;
      g.lineTo(x + Math.cos(pa) * rr, y + Math.sin(pa) * rr);
    }
    g.fill();
  }
}

function paintLeaves(g, ox, oy) {
  for (let i = 0; i < 95; i++) {
    const a = R(0, Math.PI * 2), d = Math.sqrt(rand()) * 104;
    const x = ox + 128 + Math.cos(a) * d, y = oy + 128 + Math.sin(a) * d * 0.9;
    const shade = 1.08 - (y - oy) / 256 * 0.5, L = R(14, 22), rot = R(0, 6.3);
    const gr = R(0.85, 1.15);
    g.fillStyle = `rgb(${62 * shade * gr | 0},${120 * shade | 0},${44 * shade | 0})`;
    g.save(); g.translate(x, y); g.rotate(rot);
    g.beginPath(); g.moveTo(-L, 0); g.quadraticCurveTo(0, -L * 0.42, L, 0); g.quadraticCurveTo(0, L * 0.42, -L, 0); g.fill();
    g.strokeStyle = `rgba(190,230,140,${0.35 * shade})`; g.lineWidth = 1.2;
    g.beginPath(); g.moveTo(-L * 0.8, 0); g.lineTo(L * 0.8, 0); g.stroke();
    g.restore();
  }
}

function foliageAtlas() {
  const cv = document.createElement('canvas'); cv.width = cv.height = 512;
  const g = cv.getContext('2d');
  paintBlossoms(g, 0, 0); paintNeedles(g, 256, 0); paintMaple(g, 0, 256); paintLeaves(g, 256, 256);
  const t = new THREE.CanvasTexture(cv);
  t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return t;
}

function barkAtlas() {
  const cv = document.createElement('canvas'); cv.width = cv.height = 256;
  const g = cv.getContext('2d');
  const cols = [['#4a3428', '#2a1c14', '#6e5038'], ['#5e2e26', '#3a1a14', '#8a4a3a'], ['#5e5244', '#3a3228', '#857664'], ['#5f8f36', '#3f6a24', '#a6cc66']];
  cols.forEach(([base, dark, light], c) => {
    const x0 = c * 64;
    g.fillStyle = base; g.fillRect(x0, 0, 64, 256);
    for (let i = 0; i < 60; i++) {
      const x = x0 + R(2, 62), y = R(0, 256), L = R(20, 70);
      g.strokeStyle = rand() < 0.6 ? dark : light; g.globalAlpha = c === 3 ? 0.35 : 0.55; g.lineWidth = R(1.5, 3.5);
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + R(-3, 3), y + L); g.stroke();
    }
    if (c === 1) for (let i = 0; i < 26; i++) { g.strokeStyle = dark; g.globalAlpha = 0.7; g.lineWidth = 2; const y = R(0, 256); g.beginPath(); g.moveTo(x0 + R(4, 30), y); g.lineTo(x0 + R(34, 60), y); g.stroke(); }
    if (c === 3) { g.globalAlpha = 0.5; g.fillStyle = light; g.fillRect(x0 + 20, 0, 9, 256); }
    g.globalAlpha = 1;
  });
  const t = new THREE.CanvasTexture(cv);
  t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.wrapT = THREE.RepeatWrapping;
  return t;
}

// ------------------------------------------------------------------ materiali
function windShader(sh) {
  sh.uniforms.uWind = WIND;
  sh.vertexShader = 'uniform float uWind;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
    #ifdef USE_INSTANCING
      vec3 ip = vec3(instanceMatrix[3]);
    #else
      vec3 ip = vec3(0.0);
    #endif
    float hh = max(0.0, position.y) / 6.0;
    float sw = sin(uWind * 1.2 + ip.x * 0.21 + ip.z * 0.17) * 0.16 + sin(uWind * 3.3 + position.x * 1.7 + position.z * 1.3) * 0.05;
    transformed.x += sw * hh; transformed.z += sw * 0.6 * hh;`);
  // le carte sono a doppia faccia: niente normale capovolta sul retro (luce morbida uniforme)
  // da lontano le carte restano piene (il filtraggio delle mipmap altrimenti le dirada)
  sh.fragmentShader = sh.fragmentShader.replace('#include <map_fragment>', `#include <map_fragment>
    diffuseColor.a = clamp(diffuseColor.a * (1.0 + 1.6 * smoothstep(12.0, 110.0, abs(vViewPosition.z))), 0.0, 1.0);`);
  sh.fragmentShader = sh.fragmentShader.replace('#include <normal_fragment_begin>',
    THREE.ShaderChunk.normal_fragment_begin.replace('gl_FrontFacing ? 1.0 : - 1.0', '1.0'));
}

function rockShader(sh) {
  sh.vertexShader = 'varying vec3 vRockP;\nvarying vec3 vRockN;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
    #ifdef USE_INSTANCING
      mat4 rm = modelMatrix * instanceMatrix;
    #else
      mat4 rm = modelMatrix;
    #endif
    vRockP = (rm * vec4(position, 1.0)).xyz; vRockN = normalize(mat3(rm) * normal);`);
  sh.fragmentShader = `varying vec3 vRockP;\nvarying vec3 vRockN;
    float rh(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
    float rn(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
      return mix(mix(mix(rh(i), rh(i + vec3(1,0,0)), f.x), mix(rh(i + vec3(0,1,0)), rh(i + vec3(1,1,0)), f.x), f.y),
                 mix(mix(rh(i + vec3(0,0,1)), rh(i + vec3(1,0,1)), f.x), mix(rh(i + vec3(0,1,1)), rh(i + vec3(1,1,1)), f.x), f.y), f.z); }
    ` + sh.fragmentShader.replace('#include <color_fragment>', `#include <color_fragment>
    {
      float n = rn(vRockP * 1.4) * 0.55 + rn(vRockP * 4.1) * 0.3 + rn(vRockP * 11.0) * 0.15;
      vec3 c = mix(vec3(0.16, 0.15, 0.14), vec3(0.42, 0.40, 0.36), n);
      c *= 0.8 + 0.35 * clamp(vRockN.y, 0.0, 1.0);
      float moss = smoothstep(0.45, 0.85, vRockN.y) * smoothstep(0.35, 0.65, rn(vRockP * 0.9));
      diffuseColor.rgb = mix(c, vec3(0.13, 0.24, 0.06), moss * 0.85);
    }`);
}

function makeMaterials(cutaway) {
  const leaves = new THREE.MeshStandardMaterial({ map: foliageAtlas(), alphaTest: 0.4, alphaToCoverage: true, side: THREE.DoubleSide, roughness: 0.9, metalness: 0 });
  leaves.onBeforeCompile = windShader;
  leaves.customProgramCacheKey = () => 'foglie';
  const bark = new THREE.MeshStandardMaterial({ map: barkAtlas(), roughness: 0.95, metalness: 0 });
  const rock = new THREE.MeshStandardMaterial({ roughness: 0.9, metalness: 0 });
  rock.onBeforeCompile = rockShader;
  rock.customProgramCacheKey = () => 'roccia';
  return { leaves: cutaway(leaves, 'foglie'), bark: cutaway(bark, 'corteccia'), rock };
}

// ------------------------------------------------------------------ bosco a settori (per il ritaglio fuori inquadratura)
const SPECIES = { pine: 'pino', cherry: 'ciliegio', maple: 'acero', bamboo: 'bambu', bush: 'cespuglio' };
const TINTS = {
  pine: [[0.85, 1.0, 0.85], [1.0, 1.05, 0.9], [0.9, 1.0, 1.0]],
  cherry: [[1, 1, 1], [1.05, 0.95, 1], [0.95, 0.92, 0.98]],
  maple: [[1, 1, 1], [1.1, 1.0, 0.8], [0.9, 0.85, 0.85]],
  bamboo: [[1, 1, 1], [0.9, 1.05, 0.9]],
  bush: [[1, 1, 1], [1.1, 1.05, 0.85], [0.85, 1, 0.95]],
};
const CHUNK = 96;

export function buildNature(group, lists, cutaway) {
  const mats = makeMaterials(cutaway);
  const dummy = new THREE.Object3D(), col = new THREE.Color();
  const chunked = (arr) => {
    const m = new Map();
    for (const it of arr) {
      const k = Math.floor(it[0] / CHUNK) + ',' + Math.floor(it[2] / CHUNK);
      if (!m.has(k)) m.set(k, []);
      m.get(k).push(it);
    }
    return [...m.values()];
  };
  const place = (geo, mat, arr, opts = {}) => {
    const im = new THREE.InstancedMesh(geo, mat, arr.length);
    arr.forEach(([x, y, z, s, r], i) => {
      dummy.position.set(x, y, z); dummy.rotation.set(0, r, 0); dummy.scale.setScalar(s * (opts.scale || 1));
      dummy.updateMatrix(); im.setMatrixAt(i, dummy.matrix);
      if (opts.tints) { const t = opts.tints[i % opts.tints.length]; im.setColorAt(i, col.setRGB(t[0], t[1], t[2])); }
    });
    im.castShadow = opts.shadow !== false; im.receiveShadow = true;
    im.computeBoundingSphere();
    group.add(im);
    return im;
  };
  for (const [k, name] of Object.entries(SPECIES)) {
    for (const arr of chunked(lists[k] || [])) {
      place(GEO[name + '_tronco'], mats.bark, arr, { shadow: k !== 'bush' });
      place(GEO[name + '_chioma'], mats.leaves, arr, { tints: TINTS[k] });
    }
  }
  const rocks = lists.rock || [];
  for (let v = 0; v < 3; v++) {
    const arr = rocks.filter((_, i) => i % 3 === v);
    if (arr.length) place(GEO['roccia_' + (v + 1)], mats.rock, arr.map(([x, y, z, s, r]) => [x, y + 0.15, z, s, r]), { scale: 1.1 });
  }
}
