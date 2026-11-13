// Terreno dipinto a mano: texture procedurali ripetibili (erba, terra, roccia, sabbia, selciato, neve,
// erba secca, sottobosco) miscelate nello shader con pesi per vertice e bordi spezzati dal rumore;
// la roccia sui pendii usa la proiezione su tre assi per non stirarsi.
import * as THREE from 'three';
import { heightAt, roadDistance, fbm, smoothstep, mulberry32, KINGDOMS, KINGDOM_IDS, CENTER, WALL_RADIUS } from '/shared/world.js';

const N = 512;
const rand = mulberry32(2024);
const R = (a, b) => a + rand() * (b - a);

// disegna una forma ripetendola oltre i bordi, così la texture si ripete senza cuciture
function tiled(g, x, y, r, draw) {
  for (const dx of [-N, 0, N]) for (const dy of [-N, 0, N]) {
    if (x + dx < -r || x + dx > N + r || y + dy < -r || y + dy > N + r) continue;
    draw(x + dx, y + dy);
  }
}
function base(g, c1, c2, blobs = 60, size = [40, 120]) {
  g.fillStyle = c1; g.fillRect(0, 0, N, N);
  for (let i = 0; i < blobs; i++) {
    const x = R(0, N), y = R(0, N), r = R(size[0], size[1]);
    tiled(g, x, y, r, (px, py) => {
      const gr = g.createRadialGradient(px, py, 0, px, py, r);
      gr.addColorStop(0, c2); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.beginPath(); g.arc(px, py, r, 0, Math.PI * 2); g.fill();
    });
  }
}
const rgba = (r, g, b, a = 1) => `rgba(${r | 0},${g | 0},${b | 0},${a})`;

function paintGrass(g) {
  base(g, '#4f7a2c', 'rgba(110,150,56,0.35)', 50);
  base(g, 'rgba(0,0,0,0)', 'rgba(40,70,22,0.3)', 40, [30, 80]);
  g.lineCap = 'round';
  for (let i = 0; i < 5200; i++) {
    const x = R(0, N), y = R(0, N), L = R(6, 15), a = -Math.PI / 2 + R(-0.6, 0.6), k = R(0.6, 1.25);
    tiled(g, x, y, L, (px, py) => {
      g.strokeStyle = rgba(70 * k, 118 * k, 40 * k, 0.85); g.lineWidth = R(1.2, 2.4);
      g.beginPath(); g.moveTo(px, py); g.lineTo(px + Math.cos(a) * L, py + Math.sin(a) * L); g.stroke();
    });
  }
  for (let i = 0; i < 70; i++) {
    const x = R(0, N), y = R(0, N), c = [[250, 240, 210], [250, 220, 90], [240, 160, 190]][i % 3];
    tiled(g, x, y, 4, (px, py) => { g.fillStyle = rgba(...c); g.beginPath(); g.arc(px, py, R(1.5, 3), 0, Math.PI * 2); g.fill(); });
  }
}
function paintDirt(g) {
  base(g, '#7a5a3a', 'rgba(150,115,75,0.4)', 60);
  base(g, 'rgba(0,0,0,0)', 'rgba(70,48,30,0.35)', 50, [20, 60]);
  for (let i = 0; i < 420; i++) {
    const x = R(0, N), y = R(0, N), rx = R(3, 9), ry = rx * R(0.6, 0.9), k = R(0.8, 1.2);
    tiled(g, x, y, rx + 2, (px, py) => {
      g.fillStyle = rgba(60 * k, 44 * k, 30 * k, 0.6); g.beginPath(); g.ellipse(px + 1.5, py + 2, rx, ry, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = rgba(150 * k, 128 * k, 100 * k); g.beginPath(); g.ellipse(px, py, rx, ry, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = rgba(200 * k, 180 * k, 150 * k, 0.6); g.beginPath(); g.ellipse(px - rx * 0.25, py - ry * 0.35, rx * 0.45, ry * 0.35, 0, 0, Math.PI * 2); g.fill();
    });
  }
}
function paintRock(g) {
  base(g, '#6e6a62', 'rgba(150,145,135,0.35)', 50);
  for (let i = 0; i < 260; i++) {
    const x = R(0, N), y = R(0, N), w = R(20, 60), h = R(8, 22), k = R(0.8, 1.2);
    tiled(g, x, y, w, (px, py) => {
      g.fillStyle = rgba(120 * k, 116 * k, 108 * k, 0.75);
      g.beginPath(); g.moveTo(px, py); g.lineTo(px + w, py + R(-4, 4)); g.lineTo(px + w * 0.8, py + h); g.lineTo(px + w * 0.1, py + h * 0.9); g.fill();
      g.strokeStyle = rgba(180 * k, 176 * k, 168 * k, 0.6); g.lineWidth = 2; g.beginPath(); g.moveTo(px, py); g.lineTo(px + w, py); g.stroke();
      g.strokeStyle = rgba(50, 46, 42, 0.55); g.lineWidth = 1.6; g.beginPath(); g.moveTo(px + w * 0.1, py + h * 0.95); g.lineTo(px + w * 0.8, py + h); g.stroke();
    });
  }
}
function paintSand(g) {
  base(g, '#c8b282', 'rgba(230,214,170,0.4)', 50);
  g.lineCap = 'round';
  for (let i = 0; i < 260; i++) {
    const x = R(0, N), y = R(0, N), L = R(20, 50);
    tiled(g, x, y, L, (px, py) => { g.strokeStyle = 'rgba(150,128,90,0.3)'; g.lineWidth = 2; g.beginPath(); g.moveTo(px, py); g.quadraticCurveTo(px + L / 2, py - 4, px + L, py); g.stroke(); });
  }
  for (let i = 0; i < 1500; i++) { const x = R(0, N), y = R(0, N); g.fillStyle = rand() < 0.5 ? 'rgba(120,100,70,0.4)' : 'rgba(250,240,220,0.5)'; g.fillRect(x, y, 1.5, 1.5); }
}
function paintPlaza(g) {
  g.fillStyle = '#5e564a'; g.fillRect(0, 0, N, N);
  const cell = 32;
  for (let j = 0; j < N / cell; j++) for (let i = 0; i < N / cell; i++) {
    const ox = (j % 2) * cell / 2, x = i * cell + ox + R(-3, 3), y = j * cell + R(-3, 3), w = cell - R(4, 7), h = cell - R(4, 7), k = R(0.82, 1.15);
    tiled(g, x, y, cell, (px, py) => {
      g.fillStyle = rgba(150 * k, 140 * k, 122 * k);
      g.beginPath(); g.roundRect(px + 2, py + 2, w, h, 7); g.fill();
      g.fillStyle = rgba(190 * k, 182 * k, 164 * k, 0.55); g.beginPath(); g.roundRect(px + 4, py + 3, w * 0.7, h * 0.35, 5); g.fill();
      g.fillStyle = rgba(70, 64, 56, 0.35); g.beginPath(); g.roundRect(px + 3, py + h * 0.7, w - 2, h * 0.3, 5); g.fill();
    });
  }
  base(g, 'rgba(0,0,0,0)', 'rgba(90,110,60,0.18)', 30, [20, 50]);
}
function paintSnow(g) {
  base(g, '#e8eef4', 'rgba(255,255,255,0.6)', 40);
  base(g, 'rgba(0,0,0,0)', 'rgba(170,190,215,0.35)', 40, [20, 70]);
}
function paintDry(g) {
  base(g, '#9a9050', 'rgba(190,170,90,0.4)', 50);
  g.lineCap = 'round';
  for (let i = 0; i < 3500; i++) {
    const x = R(0, N), y = R(0, N), L = R(6, 14), a = -Math.PI / 2 + R(-0.8, 0.8), k = R(0.7, 1.2);
    tiled(g, x, y, L, (px, py) => { g.strokeStyle = rgba(170 * k, 150 * k, 80 * k, 0.8); g.lineWidth = R(1, 2); g.beginPath(); g.moveTo(px, py); g.lineTo(px + Math.cos(a) * L, py + Math.sin(a) * L); g.stroke(); });
  }
}
function paintForest(g) {
  base(g, '#3a4a24', 'rgba(80,70,40,0.4)', 50);
  for (let i = 0; i < 700; i++) {
    const x = R(0, N), y = R(0, N), r = R(4, 9), c = [[120, 80, 40], [90, 110, 40], [140, 100, 50], [70, 90, 36]][i % 4], k = R(0.7, 1.1);
    tiled(g, x, y, r, (px, py) => { g.fillStyle = rgba(c[0] * k, c[1] * k, c[2] * k, 0.85); g.beginPath(); g.ellipse(px, py, r, r * 0.55, R(0, 3), 0, Math.PI * 2); g.fill(); });
  }
}

function makeTex(paint) {
  const cv = document.createElement('canvas'); cv.width = cv.height = N;
  paint(cv.getContext('2d'));
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

// ------------------------------------------------------------------ pesi dei materiali per vertice
function weights(x, z, h) {
  const w = { grass: 1, dirt: 0, rock: 0, sand: 0, plaza: 0, snow: 0, dry: 0, forest: 0 };
  const lerpTo = (k, f) => { if (f <= 0) return; f = Math.min(1, f); for (const n in w) w[n] *= 1 - f; w[k] += f; };
  const n2 = fbm(x * 0.008 + 50, z * 0.008, 2, 77);
  if (n2 > 0.55) lerpTo('dry', (n2 - 0.55) * 3);
  const forest = fbm(x * 0.018, z * 0.018, 3, 31);
  if (forest > 0.55) lerpTo('forest', Math.min(0.85, (forest - 0.55) * 3.2));
  if (h < 1.3) lerpTo('sand', smoothstep(1.3, 0.2, h));
  if (h < -0.5) lerpTo('dirt', smoothstep(-0.5, -3, h));
  const slope = Math.hypot(heightAt(x + 1, z) - heightAt(x - 1, z), heightAt(x, z + 1) - heightAt(x, z - 1)) / 2;
  if (slope > 0.5) lerpTo('rock', smoothstep(0.5, 1.0, slope));
  if (h > 24) lerpTo('rock', smoothstep(24, 32, h));
  if (h > 44) lerpTo('snow', smoothstep(44, 52, h));
  const rd = roadDistance(x, z);
  if (rd < 4.8) lerpTo('dirt', smoothstep(4.8, 2.4, rd) * 0.95);
  const dc = Math.hypot(x - CENTER.x, z - CENTER.z);
  if (dc < 34) lerpTo('plaza', smoothstep(34, 26, dc) * 0.9);
  for (const kid of KINGDOM_IDS) {
    const v = KINGDOMS[kid].village;
    const d = Math.hypot(x - v.x, z - v.z);
    if (d < WALL_RADIUS + 1) lerpTo('plaza', smoothstep(WALL_RADIUS + 1, WALL_RADIUS - 5, d) * 0.95);
  }
  return w;
}

// ------------------------------------------------------------------ materiale
const VERT = `attribute vec4 splatA; attribute vec4 splatB; varying vec4 vSA; varying vec4 vSB; varying vec3 vWP; varying vec3 vWN;`;
const FRAG = `uniform sampler2D tGrass, tDirt, tRock, tSand, tPlaza, tSnow, tDry, tForest;
  varying vec4 vSA; varying vec4 vSB; varying vec3 vWP; varying vec3 vWN;
  float th(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
  float tn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(th(i), th(i + vec2(1, 0)), f.x), mix(th(i + vec2(0, 1)), th(i + vec2(1, 1)), f.x), f.y); }
  vec3 anti(sampler2D t, vec2 uv, float m) { return mix(texture2D(t, uv).rgb, texture2D(t, uv * 0.43 + vec2(0.31, 0.17)).rgb, m); }`;
const BODY = `
  {
    float big = tn(vWP.xz * 0.05), mid = tn(vWP.xz * 0.23);
    vec2 uv = vWP.xz * 0.16;
    vec3 grass = anti(tGrass, uv, big) * (0.88 + 0.24 * mid);
    vec3 dirt = anti(tDirt, uv * 1.2, big);
    vec3 sand = anti(tSand, uv, big);
    vec3 plaza = texture2D(tPlaza, vWP.xz * 0.14).rgb;
    vec3 snow = texture2D(tSnow, uv * 0.6).rgb;
    vec3 dry = anti(tDry, uv, big);
    vec3 forest = anti(tForest, uv * 1.1, big);
    vec3 bw = pow(abs(vWN), vec3(4.0)); bw /= (bw.x + bw.y + bw.z);
    vec3 rock = texture2D(tRock, vWP.zy * 0.11).rgb * bw.x + texture2D(tRock, vWP.xz * 0.11).rgb * bw.y + texture2D(tRock, vWP.xy * 0.11).rgb * bw.z;
    // bordi spezzati: il rumore e la luminosità della texture spostano il confine tra i materiali
    float edge = tn(vWP.xz * 0.9) * 0.6 + tn(vWP.xz * 3.1) * 0.4;
    vec4 a = vSA, b = vSB;
    a = max(vec4(0.0), a + (vec4(edge, 1.0 - edge, edge * 0.7, 1.0 - edge) - 0.5) * 0.45 * step(0.02, a));
    b = max(vec4(0.0), b + (vec4(1.0 - edge, edge, edge, 1.0 - edge) - 0.5) * 0.45 * step(0.02, b));
    a = pow(a, vec4(2.0)); b = pow(b, vec4(2.0));
    float s = a.x + a.y + a.z + a.w + b.x + b.y + b.z + b.w + 1e-4;
    vec3 col = (grass * a.x + dirt * a.y + rock * a.z + sand * a.w + plaza * b.x + snow * b.y + dry * b.z + forest * b.w) / s;
    diffuseColor.rgb = col;
  }`;

export function makeTerrainPainted() {
  const SEG = 300, SIZE = 600;
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEG, SEG);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const A = new Float32Array(pos.count * 4), B = new Float32Array(pos.count * 4);
  const colors = new Float32Array(pos.count * 3);
  const C = { grass: [0.09, 0.2, 0.03], dirt: [0.25, 0.13, 0.05], rock: [0.18, 0.17, 0.14], sand: [0.55, 0.43, 0.2], plaza: [0.38, 0.33, 0.25], snow: [0.85, 0.87, 0.9], dry: [0.33, 0.29, 0.08], forest: [0.05, 0.1, 0.02] };
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i), h = heightAt(x, z);
    pos.setY(i, h);
    const w = weights(x, z, h);
    A.set([w.grass, w.dirt, w.rock, w.sand], i * 4);
    B.set([w.plaza, w.snow, w.dry, w.forest], i * 4);
    for (let k = 0; k < 3; k++) { let c = 0; for (const n in w) c += w[n] * C[n][k]; colors[i * 3 + k] = c; }
  }
  geo.setAttribute('splatA', new THREE.BufferAttribute(A, 4));
  geo.setAttribute('splatB', new THREE.BufferAttribute(B, 4));
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3)); // per la minimappa
  geo.computeVertexNormals();
  const tex = {
    tGrass: makeTex(paintGrass), tDirt: makeTex(paintDirt), tRock: makeTex(paintRock), tSand: makeTex(paintSand),
    tPlaza: makeTex(paintPlaza), tSnow: makeTex(paintSnow), tDry: makeTex(paintDry), tForest: makeTex(paintForest),
  };
  const mat = new THREE.MeshStandardMaterial({ roughness: 0.95, metalness: 0 });
  mat.onBeforeCompile = (sh) => {
    for (const [k, t] of Object.entries(tex)) sh.uniforms[k] = { value: t };
    sh.vertexShader = VERT + '\n' + sh.vertexShader.replace('#include <worldpos_vertex>', `#include <worldpos_vertex>
      vSA = splatA; vSB = splatB; vWP = (modelMatrix * vec4(transformed, 1.0)).xyz; vWN = normalize(mat3(modelMatrix) * objectNormal);`);
    sh.fragmentShader = FRAG + '\n' + sh.fragmentShader.replace('#include <map_fragment>', '#include <map_fragment>\n' + BODY);
  };
  mat.customProgramCacheKey = () => 'terreno-dipinto';
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  return mesh;
}
