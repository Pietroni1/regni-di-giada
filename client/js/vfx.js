// Effetti visivi delle abilità e dei colpi: particelle a migliaia (scintille, fumo, petali) e mesh
// con texture dipinte (archi dei fendenti, onde d'urto, crepe, rune, colonne di luce, fulmini, scudi).
// Ogni abilità ha la sua resa, intonata alla Via del personaggio.
import * as THREE from 'three';
import { heightAt } from '/shared/world.js';

const TAU = Math.PI * 2;
// densità e dimensione globali delle particelle (effetti "pieni")
const DENS = 2.0, SIZE = 1.6;
const rnd = (a, b) => a + Math.random() * (b - a);

// ------------------------------------------------------------------ texture dipinte
function canvasTex(w, h, draw, opts = {}) {
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
  draw(cv.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(cv);
  if (opts.srgb) t.colorSpace = THREE.SRGBColorSpace;
  if (opts.wrap) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}
const TEX = {
  glow: canvasTex(64, 64, (g) => {
    const r = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(0.2, 'rgba(255,255,255,0.8)'); r.addColorStop(0.55, 'rgba(255,255,255,0.2)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, 64, 64);
  }),
  star: canvasTex(64, 64, (g) => {
    const r = g.createRadialGradient(32, 32, 0, 32, 32, 10);
    r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, 64, 64);
    g.globalCompositeOperation = 'lighter';
    for (const [w, h] of [[64, 4], [4, 64]]) { const l = g.createRadialGradient(32, 32, 0, 32, 32, 32); l.addColorStop(0, 'rgba(255,255,255,0.9)'); l.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = l; g.fillRect(32 - w / 2, 32 - h / 2, w, h); }
  }),
  smoke: canvasTex(64, 64, (g) => {
    for (let i = 0; i < 9; i++) {
      const x = rnd(18, 46), y = rnd(18, 46), rr = rnd(10, 20);
      const r = g.createRadialGradient(x, y, 0, x, y, rr);
      r.addColorStop(0, 'rgba(255,255,255,0.35)'); r.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = r; g.fillRect(0, 0, 64, 64);
    }
  }),
  petal: canvasTex(32, 32, (g) => {
    const r = g.createRadialGradient(16, 13, 1, 16, 16, 13);
    r.addColorStop(0, '#fff2f6'); r.addColorStop(0.65, '#f4a2c0'); r.addColorStop(1, 'rgba(236,140,180,0)');
    g.fillStyle = r; g.beginPath(); g.ellipse(16, 16, 12, 7, 0.5, 0, TAU); g.fill();
  }),
  ring: canvasTex(128, 128, (g) => {
    const r = g.createRadialGradient(64, 64, 30, 64, 64, 64);
    r.addColorStop(0, 'rgba(255,255,255,0)'); r.addColorStop(0.6, 'rgba(255,255,255,0.15)'); r.addColorStop(0.86, 'rgba(255,255,255,1)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, 128, 128);
  }),
  slash: canvasTex(256, 64, (g, w, h) => {
    // u: dalla testa (0) alla coda (1); v: dal bordo interno (0) a quello esterno (1)
    const img = g.createImageData(w, h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const u = x / (w - 1), v = 1 - y / (h - 1);
      const edge = Math.pow(v, 3.2) * (1 - Math.pow(Math.max(0, v - 0.92) / 0.08, 2));
      const tail = Math.pow(1 - u, 1.6) * Math.min(1, u * 25);
      const a = Math.max(0, Math.min(1, edge * tail * 1.4 + Math.pow(v, 8) * tail));
      const i = (y * w + x) * 4;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = 255; img.data[i + 3] = a * 255;
    }
    g.putImageData(img, 0, 0);
  }),
  beam: canvasTex(64, 128, (g, w, h) => {
    const r = g.createLinearGradient(0, 0, w, 0);
    r.addColorStop(0, 'rgba(255,255,255,0)'); r.addColorStop(0.35, 'rgba(255,255,255,0.5)'); r.addColorStop(0.5, 'rgba(255,255,255,1)'); r.addColorStop(0.65, 'rgba(255,255,255,0.5)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, w, h);
    g.globalCompositeOperation = 'destination-out';
    for (let i = 0; i < 14; i++) { g.fillStyle = `rgba(0,0,0,${rnd(0.1, 0.5)})`; g.fillRect(rnd(0, w), rnd(0, h), rnd(2, 6), rnd(10, 40)); }
  }, { wrap: true }),
  line: canvasTex(8, 32, (g, w, h) => {
    const r = g.createLinearGradient(0, 0, 0, h);
    r.addColorStop(0, 'rgba(255,255,255,0)'); r.addColorStop(0.42, 'rgba(255,255,255,0.6)'); r.addColorStop(0.5, 'rgba(255,255,255,1)'); r.addColorStop(0.58, 'rgba(255,255,255,0.6)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, w, h);
  }),
  crack: canvasTex(256, 256, (g) => {
    g.translate(128, 128); g.strokeStyle = 'rgba(30,20,12,0.95)'; g.lineCap = 'round';
    const branch = (x, y, a, len, w) => {
      if (len < 8 || w < 0.6) return;
      const nx = x + Math.cos(a) * len, ny = y + Math.sin(a) * len;
      g.lineWidth = w; g.beginPath(); g.moveTo(x, y); g.lineTo(nx, ny); g.stroke();
      branch(nx, ny, a + rnd(-0.5, 0.5), len * 0.75, w * 0.7);
      if (Math.random() < 0.45) branch(nx, ny, a + rnd(-1.2, 1.2), len * 0.5, w * 0.5);
    };
    for (let i = 0; i < 9; i++) branch(0, 0, i / 9 * TAU + rnd(-0.2, 0.2), rnd(26, 40), 5);
    const r = g.createRadialGradient(0, 0, 0, 0, 0, 40); r.addColorStop(0, 'rgba(30,20,12,0.6)'); r.addColorStop(1, 'rgba(30,20,12,0)');
    g.fillStyle = r; g.beginPath(); g.arc(0, 0, 40, 0, TAU); g.fill();
  }),
  rune: canvasTex(256, 256, (g) => {
    g.translate(128, 128); g.strokeStyle = '#fff'; g.fillStyle = '#fff';
    for (const [r, w] of [[120, 5], [108, 2], [76, 3], [66, 1.5], [30, 2]]) { g.lineWidth = w; g.beginPath(); g.arc(0, 0, r, 0, TAU); g.stroke(); }
    g.font = 'bold 21px serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    const glyphs = '天地風雷火水山澤龍虎鳳龜';
    for (let i = 0; i < 12; i++) { g.save(); g.rotate(i / 12 * TAU); g.fillText(glyphs[i], 0, -92); g.restore(); }
    g.lineWidth = 2.5;
    for (let k = 0; k < 2; k++) { g.beginPath(); for (let i = 0; i <= 3; i++) { const a = (i / 3) * TAU + k * Math.PI / 3 - Math.PI / 2; g.lineTo(Math.cos(a) * 66, Math.sin(a) * 66); } g.stroke(); }
  }),
  hex: canvasTex(256, 128, (g, w, h) => {
    g.strokeStyle = 'rgba(255,255,255,0.9)'; g.lineWidth = 2.5;
    const R = 14, dx = R * 1.5, dy = R * Math.sqrt(3);
    for (let i = -1; i < w / dx + 1; i++) for (let j = -1; j < h / dy + 1; j++) {
      const cx = i * dx, cy = j * dy + (i % 2 ? dy / 2 : 0);
      g.beginPath(); for (let k = 0; k <= 6; k++) { const a = k / 6 * TAU; g.lineTo(cx + Math.cos(a) * R, cy + Math.sin(a) * R); } g.stroke();
    }
  }, { wrap: true }),
};

// ------------------------------------------------------------------ particelle
const PVERT = `attribute float size; attribute float alpha; attribute vec3 color; attribute float rot; uniform float uScale;
  varying vec3 vC; varying float vA; varying float vR;
  void main() { vC = color; vA = alpha; vR = rot; vec4 mv = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * uScale / max(0.1, -mv.z); gl_Position = projectionMatrix * mv; }`;
const PFRAG = `uniform sampler2D map; uniform float uAdd; varying vec3 vC; varying float vA; varying float vR;
  void main() { vec2 p = gl_PointCoord - 0.5; float c = cos(vR), s = sin(vR); p = mat2(c, -s, s, c) * p + 0.5;
    vec4 t = texture2D(map, p);
    if (uAdd > 0.5) gl_FragColor = vec4(vC * t.rgb * t.a * vA, 1.0); else gl_FragColor = vec4(vC * t.rgb, t.a * vA); }`;

class Pool {
  constructor(scene, max, tex, additive, scaleU) {
    this.max = max; this.n = 0;
    const F = (k) => new Float32Array(max * k);
    Object.assign(this, { pos: F(3), vel: F(3), c0: F(3), c1: F(3), col: F(3), size: F(1), alpha: F(1), rot: F(1), spin: F(1), s0: F(1), s1: F(1), life: F(1), age: F(1), grav: F(1), drag: F(1) });
    const g = new THREE.BufferGeometry();
    for (const [n, a, k] of [['position', this.pos, 3], ['color', this.col, 3], ['size', this.size, 1], ['alpha', this.alpha, 1], ['rot', this.rot, 1]]) g.setAttribute(n, new THREE.BufferAttribute(a, k).setUsage(THREE.DynamicDrawUsage));
    this.geo = g;
    this.points = new THREE.Points(g, new THREE.ShaderMaterial({
      uniforms: { map: { value: tex }, uAdd: { value: additive ? 1 : 0 }, uScale: scaleU }, vertexShader: PVERT, fragmentShader: PFRAG,
      transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
    }));
    this.points.frustumCulled = false;
    this.points.renderOrder = additive ? 5 : 4;
    scene.add(this.points);
  }
  emit(p, v, c0, c1, s0, s1, life, grav = 0, drag = 0.9) {
    if (this.n >= this.max) return;
    const i = this.n++, k = i * 3;
    this.pos[k] = p.x; this.pos[k + 1] = p.y; this.pos[k + 2] = p.z;
    this.vel[k] = v.x; this.vel[k + 1] = v.y; this.vel[k + 2] = v.z;
    this.c0[k] = c0.r; this.c0[k + 1] = c0.g; this.c0[k + 2] = c0.b;
    this.c1[k] = c1.r; this.c1[k + 1] = c1.g; this.c1[k + 2] = c1.b;
    this.s0[i] = s0; this.s1[i] = s1; this.life[i] = life; this.age[i] = 0; this.grav[i] = grav; this.drag[i] = drag;
    this.rot[i] = Math.random() * TAU; this.spin[i] = (Math.random() - 0.5) * 6;
  }
  update(dt) {
    for (let i = 0; i < this.n; i++) {
      this.age[i] += dt;
      if (this.age[i] >= this.life[i]) { this.kill(i); i--; continue; }
      const k = i * 3, f = Math.pow(this.drag[i], dt * 10);
      this.vel[k] *= f; this.vel[k + 1] = this.vel[k + 1] * f - this.grav[i] * dt; this.vel[k + 2] *= f;
      this.pos[k] += this.vel[k] * dt; this.pos[k + 1] += this.vel[k + 1] * dt; this.pos[k + 2] += this.vel[k + 2] * dt;
      const p = this.age[i] / this.life[i];
      this.alpha[i] = p < 0.1 ? p / 0.1 : 1 - (p - 0.1) / 0.9;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * p;
      this.rot[i] += this.spin[i] * dt;
      for (let j = 0; j < 3; j++) this.col[k + j] = this.c0[k + j] + (this.c1[k + j] - this.c0[k + j]) * p;
    }
    this.geo.setDrawRange(0, this.n);
    for (const a of ['position', 'color', 'size', 'alpha', 'rot']) this.geo.attributes[a].needsUpdate = true;
  }
  kill(i) {
    const j = --this.n;
    if (i === j) return;
    for (const a of ['pos', 'vel', 'c0', 'c1', 'col']) this[a].copyWithin(i * 3, j * 3, j * 3 + 3);
    for (const a of ['size', 'alpha', 'rot', 'spin', 's0', 's1', 'life', 'age', 'grav', 'drag']) this[a][i] = this[a][j];
  }
}

// ------------------------------------------------------------------ motore
const V = () => new THREE.Vector3();
const _v = V(), _p = V(), _c = new THREE.Color(), _c2 = new THREE.Color();
const WHITE = new THREE.Color(1, 1, 1);

export class VFX {
  constructor(scene, camera, renderer) {
    this.scene = scene; this.camera = camera; this.renderer = renderer;
    this.scaleU = { value: 600 };
    this.glow = new Pool(scene, 9000, TEX.glow, true, this.scaleU);
    this.stars = new Pool(scene, 2500, TEX.star, true, this.scaleU);
    this.smoke = new Pool(scene, 2500, TEX.smoke, false, this.scaleU);
    this.petals = new Pool(scene, 1500, TEX.petal, false, this.scaleU);
    this.items = [];
    this.timers = [];
    this.shake = 0;
    this._db = new THREE.Vector2();
  }

  // ---------------------------------------------------------------- base
  add(obj, dur, fn, onEnd) { if (obj) this.scene.add(obj); this.items.push({ obj, t: 0, dur, fn, onEnd }); return obj; }
  later(sec, fn) { this.timers.push({ t: sec, fn }); }
  update(dt) {
    this.renderer.getDrawingBufferSize(this._db);
    this.scaleU.value = this._db.y / (2 * Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2)));
    for (let i = this.timers.length - 1; i >= 0; i--) { const t = this.timers[i]; t.t -= dt; if (t.t <= 0) { this.timers.splice(i, 1); t.fn(); } }
    for (let i = this.items.length - 1; i >= 0; i--) {
      const e = this.items[i];
      e.t += dt;
      const p = Math.min(1, e.t / e.dur);
      if (e.fn) e.fn(p, dt, e);
      if (p >= 1) {
        if (e.obj) { this.scene.remove(e.obj); e.obj.traverse((m) => { if (m.geometry) m.geometry.dispose(); if (m.material && !m.material.userData.shared) m.material.dispose(); if (m.isLight) m.dispose?.(); }); }
        if (e.onEnd) e.onEnd();
        this.items.splice(i, 1);
      }
    }
    for (const pool of [this.glow, this.stars, this.smoke, this.petals]) pool.update(dt);
  }
  pos(e, h = 1.1) { return V().set(e.x, (e.y ?? heightAt(e.x, e.z)) + h, e.z); }
  ground(e) { return heightAt(e.x, e.z); }
  add2(color) { return new THREE.MeshBasicMaterial({ color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }); }

  // ---------------------------------------------------------------- primitive
  burst(p, color, n = 20, speed = 4, size = 0.18, life = 0.5, o = {}) {
    _c.set(color); _c2.set(o.to ?? color);
    n = Math.round(n * DENS); size *= SIZE;
    const pool = o.pool || this.glow;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU, e = o.flat ? rnd(-0.15, 0.25) : rnd(-1, 1.2), s = speed * rnd(0.35, 1);
      _v.set(Math.cos(a) * Math.cos(e) * s, Math.sin(e) * s + (o.up || 0), Math.sin(a) * Math.cos(e) * s);
      _p.set(p.x + rnd(-1, 1) * (o.spread || 0), p.y + rnd(-1, 1) * (o.spread || 0) * 0.5, p.z + rnd(-1, 1) * (o.spread || 0));
      pool.emit(_p, _v, Math.random() < (o.white ?? 0.25) ? WHITE : _c, _c2, size * rnd(0.6, 1.3), size * (o.grow ?? 0.3), life * rnd(0.6, 1.2), o.grav ?? 4, o.drag ?? 0.75);
    }
  }
  flash(p, color, size = 2, life = 0.16) { _c.set(color); this.glow.emit(p, _v.set(0, 0, 0), WHITE, _c, size, size * 1.4, life, 0, 1); this.glow.emit(p, _v, _c, _c, size * 2.2, size * 2.6, life * 1.4, 0, 1); }
  light(p, color, intensity = 25, dist = 14, dur = 0.3) {
    const l = new THREE.PointLight(color, intensity, dist, 1.6);
    l.position.copy(p);
    this.add(l, dur, (q) => { l.intensity = intensity * (1 - q) * (1 - q); });
  }
  smokePuff(p, color, n = 10, size = 1.2, life = 1.0, o = {}) {
    _c.set(color); _c2.set(o.to ?? color);
    n = Math.round(n * 1.5);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU, s = rnd(0.3, 1) * (o.speed ?? 1.5);
      _v.set(Math.cos(a) * s, rnd(0.2, 1) * (o.up ?? 0.8), Math.sin(a) * s);
      _p.set(p.x + rnd(-0.3, 0.3) * (o.spread || 1), p.y + rnd(0, 0.3), p.z + rnd(-0.3, 0.3) * (o.spread || 1));
      this.smoke.emit(_p, _v, _c, _c2, size * rnd(0.6, 1.1), size * rnd(1.6, 2.4), life * rnd(0.7, 1.3), o.grav ?? -0.3, 0.85);
    }
  }
  decal(p, tex, size, color, dur, o = {}) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({
      map: tex, color, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4,
      blending: o.normal ? THREE.NormalBlending : THREE.AdditiveBlending }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(p.x, heightAt(p.x, p.z) + 0.06 + (o.lift || 0), p.z);
    const s0 = o.from ?? size, s1 = size, op = o.opacity ?? 1;
    this.add(m, dur, (q) => {
      const k = o.ease ? 1 - Math.pow(1 - Math.min(1, q / (o.ease)), 3) : q;
      m.scale.setScalar(s0 + (s1 - s0) * Math.min(1, k));
      m.rotation.z += (o.spin || 0) * 0.016;
      m.material.opacity = op * (q < 0.15 ? q / 0.15 : q > 0.6 ? (1 - q) / 0.4 : 1);
    });
    return m;
  }
  shockwave(p, color, radius, dur = 0.45, h = 0.15) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: TEX.ring, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(p.x, heightAt(p.x, p.z) + h, p.z);
    this.add(m, dur, (q) => { const k = 1 - Math.pow(1 - q, 3); m.scale.setScalar(0.4 + radius * 2 * k); m.material.opacity = 1 - q; });
  }
  verticalRing(p, color, radius, dur, dir) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: TEX.ring, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    m.position.copy(p);
    if (dir) m.lookAt(p.clone().add(dir));
    this.add(m, dur, (q) => { const k = 1 - Math.pow(1 - q, 2); m.scale.setScalar(0.3 + radius * 2 * k); m.material.opacity = 1 - q; });
  }
  // Arco del fendente: banda curva con texture sfumata (testa luminosa, coda che svanisce)
  slashArc(ent, color, o = {}) {
    const N = 28, r1 = o.radius ?? 1.5, r0 = r1 - (o.width ?? 0.7), sweep = o.sweep ?? 2.4;
    const pos = [], uv = [], idx = [];
    for (let i = 0; i <= N; i++) {
      const a = -sweep / 2 + sweep * (i / N);
      for (const [r, v] of [[r0, 0], [r1, 1]]) { pos.push(Math.sin(a) * r, 0, Math.cos(a) * r); uv.push(1 - i / N, v); }
      if (i < N) { const k = i * 2; idx.push(k, k + 1, k + 2, k + 1, k + 3, k + 2); }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setIndex(idx);
    const mat = new THREE.MeshBasicMaterial({ map: TEX.slash, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide });
    const inner = new THREE.Mesh(g, mat);
    const pivot = new THREE.Group();
    pivot.add(inner);
    const core = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: TEX.slash, color: 0xffffff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    core.scale.setScalar(0.97); pivot.add(core);
    const dur = o.dur ?? 0.24, dirSign = o.reverse ? -1 : 1, h = o.h ?? 1.15, spin = o.spin ?? 2.6;
    this.add(pivot, dur, (q) => {
      pivot.position.set(ent.x, (ent.y ?? 0) + h, ent.z);
      pivot.rotation.set(o.tilt ?? 0, (ent.r ?? 0) + (o.yaw ?? 0) + dirSign * (q - 0.5) * spin, o.roll ?? 0, 'YXZ');
      const s = (o.grow ?? 1) * (0.85 + q * 0.3);
      pivot.scale.set(s * dirSign, s, s);
      const f = q < 0.2 ? q / 0.2 : 1 - (q - 0.2) / 0.8;
      mat.opacity = f; core.material.opacity = f * 0.7;
    });
  }
  // Fulmine ramificato fatto di nastri rivolti alla camera
  bolt(from, to, color, o = {}) {
    const pts = [from.clone(), to.clone()];
    const segs = [];
    const jag = (a, b, d, depth, list) => {
      if (depth === 0) { list.push([a, b]); return; }
      const m = a.clone().lerp(b, 0.5);
      m.x += rnd(-d, d); m.y += rnd(-d, d) * 0.5; m.z += rnd(-d, d);
      jag(a, m, d / 2, depth - 1, list); jag(m, b, d / 2, depth - 1, list);
      if (depth >= 3 && Math.random() < (o.branch ?? 0.5)) {
        const end = m.clone().add(V().set(rnd(-1, 1), rnd(-0.8, 0.2), rnd(-1, 1)).multiplyScalar(a.distanceTo(b) * 0.45));
        jag(m, end, d / 2, depth - 2, segs);
      }
    };
    const main = [];
    jag(pts[0], pts[1], (o.jag ?? 0.12) * pts[0].distanceTo(pts[1]), 5, main);
    const cam = this.camera.position;
    const build = (list, w) => {
      const pos = [], uv = [], idx = [];
      list.forEach(([a, b], i) => {
        const dir = b.clone().sub(a), mid = a.clone().add(b).multiplyScalar(0.5);
        const side = dir.clone().cross(cam.clone().sub(mid)).normalize().multiplyScalar(w);
        const k = i * 4;
        pos.push(...a.clone().add(side).toArray(), ...a.clone().sub(side).toArray(), ...b.clone().add(side).toArray(), ...b.clone().sub(side).toArray());
        uv.push(0, 0, 0, 1, 1, 0, 1, 1);
        idx.push(k, k + 1, k + 2, k + 1, k + 3, k + 2);
      });
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
      g.setIndex(idx);
      return g;
    };
    const grp = new THREE.Group();
    const w = o.width ?? 0.22;
    const glow = new THREE.Mesh(build(main, w * 1.7), new THREE.MeshBasicMaterial({ map: TEX.line, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    const core = new THREE.Mesh(build(main, w * 0.6), new THREE.MeshBasicMaterial({ map: TEX.line, color: 0xffffff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    grp.add(glow, core);
    if (segs.length) grp.add(new THREE.Mesh(build(segs, w * 0.9), new THREE.MeshBasicMaterial({ map: TEX.line, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide })));
    this.add(grp, o.dur ?? 0.32, (q) => {
      const f = (q < 0.5 ? 1 : 1 - (q - 0.5) / 0.5) * (Math.random() < 0.25 ? 0.4 : 1);
      grp.children.forEach((m, i) => { m.material.opacity = f * (i === 1 ? 1 : 0.85); });
    });
    // scintille lungo il fulmine
    for (const [a, b] of main) if (Math.random() < 0.5) this.burst(a.clone().lerp(b, Math.random()), color, 2, 2.5, 0.12, 0.45, { grav: 0, white: 0.5 });
  }
  pillar(p, color, radius = 1, height = 12, dur = 1.0, o = {}) {
    const geo = new THREE.CylinderGeometry(radius, radius * (o.taper ?? 1), height, 24, 1, true);
    geo.translate(0, height / 2, 0);
    const mat = new THREE.MeshBasicMaterial({ map: TEX.beam, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide });
    mat.map = TEX.beam.clone(); mat.map.needsUpdate = true; mat.map.repeat.set(2, 1);
    const m = new THREE.Mesh(geo, mat);
    m.position.set(p.x, heightAt(p.x, p.z), p.z);
    this.add(m, dur, (q, dt) => {
      mat.map.offset.y -= dt * (o.scroll ?? 1.6); mat.map.offset.x += dt * 0.3;
      const s = q < 0.15 ? q / 0.15 : 1 - (q - 0.15) / 0.85 * 0.6;
      m.scale.set(s, 1, s);
      mat.opacity = q < 0.1 ? q / 0.1 : 1 - Math.pow((q - 0.1) / 0.9, 2);
    });
  }
  swirl(ent, color, dur = 1.0, n = 60, o = {}) {
    _c.set(color); _c2.set(o.to ?? color);
    const radius = o.radius ?? 0.9, h = o.height ?? 2.6;
    n = Math.round(n * DENS);
    for (let i = 0; i < n; i++) {
      const delay = Math.random() * dur * 0.6;
      this.later(delay, () => {
        const a = Math.random() * TAU, y = Math.random() * 0.4;
        _p.set(ent.x + Math.cos(a) * radius, (ent.y ?? 0) + y, ent.z + Math.sin(a) * radius);
        _v.set(-Math.sin(a) * 2.5, h * rnd(0.6, 1.1), Math.cos(a) * 2.5);
        (o.pool || this.glow).emit(_p, _v, _c, _c2, (o.size ?? 0.18) * SIZE * rnd(0.7, 1.3), 0.05, rnd(0.6, 1.0), 0, 0.85);
      });
    }
  }
  rise(ent, color, n = 30, o = {}) {
    _c.set(color); _c2.set(o.to ?? color);
    n = Math.round(n * DENS);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU, d = Math.sqrt(Math.random()) * (o.radius ?? 0.8);
      _p.set(ent.x + Math.cos(a) * d, (ent.y ?? 0) + rnd(0, o.from ?? 1.6), ent.z + Math.sin(a) * d);
      _v.set(0, rnd(0.8, 2.2) * (o.speed ?? 1), 0);
      (o.pool || this.glow).emit(_p, _v, _c, _c2, (o.size ?? 0.14) * SIZE * rnd(0.7, 1.4), 0.03, rnd(0.6, 1.2) * (o.life ?? 1), 0, 0.95);
    }
  }
  bubble(ent, color, dur = 1.4) {
    const mat = new THREE.ShaderMaterial({
      uniforms: { uC: { value: new THREE.Color(color) }, uT: { value: 0 }, uO: { value: 1 }, map: { value: TEX.hex } },
      vertexShader: `varying vec3 vN; varying vec3 vV; varying vec2 vUv; void main(){ vUv = uv; vN = normalize(normalMatrix * normal); vec4 mv = modelViewMatrix * vec4(position,1.0); vV = normalize(-mv.xyz); gl_Position = projectionMatrix * mv; }`,
      fragmentShader: `uniform vec3 uC; uniform float uT; uniform float uO; uniform sampler2D map; varying vec3 vN; varying vec3 vV; varying vec2 vUv;
        void main(){ float f = pow(1.0 - abs(dot(vN, vV)), 2.2); float h = texture2D(map, vUv * vec2(4.0, 2.0) + vec2(0.0, uT * 0.1)).a;
          gl_FragColor = vec4(uC * (f * 1.4 + h * (0.35 + f) + 0.05) * uO, 1.0); }`,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    const m = new THREE.Mesh(new THREE.SphereGeometry(1.25, 32, 20), mat);
    this.add(m, dur, (q, dt) => {
      m.position.set(ent.x, (ent.y ?? 0) + 1.1, ent.z);
      const s = q < 0.2 ? 0.6 + q * 2 : 1;
      m.scale.set(s * 0.95, s * 1.15, s * 0.95);
      mat.uniforms.uT.value += dt; mat.uniforms.uO.value = q > 0.7 ? (1 - q) / 0.3 : 1;
    });
  }
  projectile(from, to, color, o = {}, onHit) {
    const head = new THREE.Group();
    const core = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.glow, color: 0xffffff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
    const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.glow, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
    const sz = o.size ?? 0.5;
    core.scale.setScalar(sz); halo.scale.setScalar(sz * 2.8);
    head.add(halo, core);
    const a = this.pos(from, o.fromH ?? 1.5);
    const dur = o.dur ?? 0.32;
    _c.set(color);
    const trailCol = _c.clone(), trailTo = new THREE.Color(o.trailTo ?? color);
    this.add(head, dur, (q, dt) => {
      const b = this.pos(to, o.toH ?? 1.2);
      const arc = Math.sin(q * Math.PI) * (o.arc ?? 0.3);
      head.position.copy(a).lerp(b, q); head.position.y += arc;
      halo.material.rotation += dt * 6;
      for (let i = 0; i < (o.trail ?? 6) * 2; i++) {
        _v.set(rnd(-0.6, 0.6), rnd(-0.3, 0.6), rnd(-0.6, 0.6));
        (o.trailPool || this.glow).emit(head.position, _v, trailCol, trailTo, sz * rnd(0.35, 0.7), 0.02, rnd(0.25, 0.5), 0, 0.8);
      }
    }, onHit);
  }
  arrowShot(from, to, color, o = {}) {
    const g = new THREE.Group();
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.1, 5), new THREE.MeshBasicMaterial({ color: 0xe8dcc0 }));
    shaft.rotation.x = Math.PI / 2; g.add(shaft);
    const tip = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.18, 5), this.add2(color)); tip.rotation.x = Math.PI / 2; tip.position.z = 0.6; g.add(tip);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.glow, color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending })); glow.scale.setScalar(0.7); glow.position.z = 0.55; g.add(glow);
    const a = this.pos(from, 1.5);
    _c.set(color); const tc = _c.clone();
    this.add(g, o.dur ?? 0.2, (q) => {
      const b = this.pos(to, 1.2);
      g.position.copy(a).lerp(b, q); g.lookAt(b);
      for (let i = 0; i < 5; i++) this.glow.emit(g.position, _v.set(0, 0, 0), tc, tc, 0.22, 0.02, 0.22, 0, 1);
    }, () => { const b = this.pos(to, 1.2); this.burst(b, color, o.big ? 24 : 12, o.big ? 6 : 3.5, 0.16, 0.4); this.flash(b, color, o.big ? 1.6 : 1); });
  }

  // ---------------------------------------------------------------- colpi a segno
  impact(pos, color, crit, kind) {
    this.burst(pos, color, crit ? 30 : 14, crit ? 6.5 : 4, crit ? 0.2 : 0.15, 0.4, { white: 0.4, grav: 6 });
    this.stars.emit(pos, _v.set(0, 0, 0), WHITE, _c.set(color), crit ? 1.4 : 0.8, crit ? 2.2 : 1.2, 0.14, 0, 1);
    if (crit) { this.flash(pos, color, 1.6, 0.16); this.verticalRing(pos, color, 1.2, 0.25, this.camera.position.clone().sub(pos)); }
  }

  // ---------------------------------------------------------------- abilità
  skill(id, sk, s, d, at) {
    const C = sk.color ?? 0xffffff;
    const tgt = d || s;
    const sp = this.pos(s, 1.1), tp = this.pos(tgt, 1.1);
    const near = (e) => Math.hypot(e.x - this.camera.position.x, e.z - this.camera.position.z) < 40;
    switch (id) {
      // ---------------- Lama
      case 'fendente': case 'fendente_corsa':
        this.slashArc(s, C, { sweep: TAU, radius: 3.0, width: 1.1, spin: 4, dur: 0.32, h: 0.9 });
        this.slashArc(s, 0xffffff, { sweep: TAU, radius: 2.3, width: 0.5, spin: 5, dur: 0.26, h: 1.2, tilt: 0.12 });
        this.shockwave(s, C, 3.2, 0.45);
        this.smokePuff({ x: s.x, y: this.ground(s), z: s.z }, 0xc8b89a, 12, 0.9, 0.7, { speed: 4, up: 0.3, spread: 2 });
        this.burst(sp, C, 30, 7, 0.14, 0.4, { flat: true, grav: 2 });
        return;
      case 'squarcio':
        this.slashArc(s, C, { radius: 1.9, width: 0.9, tilt: -0.5, roll: 0.5, dur: 0.22 });
        this.slashArc(s, 0xffffff, { radius: 1.6, width: 0.35, tilt: -0.5, roll: 0.5, dur: 0.18 });
        this.burst(tp, C, 18, 5, 0.15, 0.35);
        return;
      case 'grido':
        for (let i = 0; i < 3; i++) this.later(i * 0.12, () => this.shockwave(s, 0xff7a2a, 4 + i * 1.5, 0.6, 0.3 + i * 0.5));
        this.rise(s, 0xff9a3a, 50, { to: 0xff3a10, radius: 1.2, speed: 1.6 });
        this.smokePuff({ x: s.x, y: this.ground(s), z: s.z }, 0x8a6a4a, 14, 1.2, 0.9, { speed: 5, up: 0.4, spread: 1.5 });
        this.decal(s, TEX.rune, 4.5, 0xff7a2a, 1.2, { from: 2, ease: 0.3, spin: 1 });
        return;
      case 'lama_tuono': case 'colpo_grazia': {
        const red = id === 'colpo_grazia';
        this.slashArc(s, C, { radius: 2.0, width: 1.0, tilt: 0.4, roll: -0.4, dur: 0.24, grow: red ? 1.3 : 1 });
        const sky = tp.clone().add(V().set(rnd(-1.5, 1.5), 16, rnd(-1.5, 1.5)));
        this.bolt(sky, this.pos(tgt, 0.2), C, { width: red ? 0.35 : 0.24, dur: 0.38 });
        this.later(0.05, () => this.bolt(sky.clone().add(V().set(rnd(-2, 2), 0, rnd(-2, 2))), this.pos(tgt, 0.4), C, { width: 0.14, dur: 0.25 }));
        this.flash(this.pos(tgt, 0.5), C, red ? 3 : 2.2, 0.2);
        this.light(tp, C, red ? 60 : 40, 16, 0.35);
        this.burst(this.pos(tgt, 0.3), C, red ? 50 : 30, red ? 9 : 6, 0.16, 0.5, { white: 0.5 });
        this.decal(tgt, TEX.crack, red ? 4 : 3, 0x222222, 2.5, { normal: true, opacity: 0.8 });
        if (red && near(tgt)) this.shake = Math.max(this.shake, 0.25);
        return;
      }
      case 'ferita_aperta':
        this.slashArc(s, C, { radius: 1.8, width: 0.8, tilt: 0.6, roll: 0.3, dur: 0.22, reverse: true });
        this.burst(tp, 0xb01010, 26, 4, 0.13, 0.7, { to: 0x400000, grav: 9, white: 0 });
        this.smokePuff(tp, 0x801818, 6, 0.5, 0.6, { speed: 1, up: 0.2 });
        return;
      case 'carica': case 'carica_destriero': {
        const end = this.pos(tgt, 1.0);
        const lightning = id === 'carica';
        if (lightning) { this.bolt(sp, end, C, { width: 0.18, jag: 0.06, branch: 0.2, dur: 0.35 }); this.light(end, C, 30, 12, 0.3); }
        for (let i = 0; i < 24; i++) { const q = i / 24; this.later(q * 0.12, () => this.smokePuff({ x: s.x + (tgt.x - s.x) * q, y: heightAt(s.x + (tgt.x - s.x) * q, s.z + (tgt.z - s.z) * q), z: s.z + (tgt.z - s.z) * q }, 0xc8b89a, 1, 0.8, 0.6, { speed: 0.6, up: 0.4 })); }
        this.later(0.12, () => { this.shockwave(tgt, C, 2.5, 0.4); this.burst(end, C, 30, 6, 0.16, 0.45, { white: 0.5 }); this.flash(end, C, 1.8); });
        return;
      }
      case 'furia_tempesta':
        this.pillar(s, C, 1.1, 9, 1.0, { taper: 0.5 });
        this.swirl(s, C, 1.0, 90, { to: 0xffffff, radius: 1.1 });
        for (let i = 0; i < 4; i++) this.later(i * 0.15, () => this.bolt(this.pos(s, rnd(1.5, 2.6)).add(V().set(rnd(-1, 1), 0, rnd(-1, 1))), this.pos(s, rnd(0, 1)).add(V().set(rnd(-1, 1), 0, rnd(-1, 1))), C, { width: 0.07, dur: 0.18 }));
        this.decal(s, TEX.rune, 4, C, 1.4, { from: 1.5, ease: 0.25, spin: 2 });
        return;
      case 'martello_monte': case 'scossa': case 'zoccoli_tuono': case 'colpo_vuoto': case 'ascesa_drago': {
        const at2 = sk.type === 'strike' ? tgt : s;
        const r = sk.radius ?? 3.5;
        const void_ = id === 'colpo_vuoto', dragon = id === 'ascesa_drago';
        if (void_) {
          const c = this.pos(at2, 1.1);
          for (let i = 0; i < 40; i++) { const dir = V().randomDirection().multiplyScalar(2.5); this.glow.emit(c.clone().add(dir), dir.multiplyScalar(-3.5), _c.set(0xe0f0ff), _c2.set(0x6080ff), 0.2, 0.05, 0.3, 0, 1); }
          this.later(0.28, () => { this.flash(c, 0xc0d8ff, 2.6, 0.22); this.shockwave(at2, 0xa0c0ff, r, 0.5); this.burst(c, 0xc0d8ff, 40, 8, 0.15, 0.5); });
          return;
        }
        this.decal(at2, TEX.crack, r * 1.8, 0x000000, 3.0, { normal: true, opacity: 0.85, from: r * 0.6, ease: 0.15 });
        this.shockwave(at2, dragon ? 0xff6a1a : C, r, 0.5);
        this.later(0.08, () => this.shockwave(at2, 0xffffff, r * 0.7, 0.35));
        this.smokePuff({ x: at2.x, y: this.ground(at2), z: at2.z }, 0xa89070, 26, 1.3, 1.1, { speed: r * 1.6, up: 0.6, spread: 1.5 });
        // detriti di roccia
        for (let i = 0; i < 26; i++) {
          const a = Math.random() * TAU;
          _v.set(Math.cos(a) * rnd(2, 6), rnd(4, 9), Math.sin(a) * rnd(2, 6));
          this.smoke.emit(_p.set(at2.x, this.ground(at2) + 0.2, at2.z), _v, _c.set(0x6a5a48), _c2.set(0x4a3e30), rnd(0.12, 0.25), 0.1, rnd(0.6, 1), 18, 0.98);
        }
        if (dragon) {
          this.pillar(at2, 0xff6a1a, 1.4, 8, 0.9, { taper: 0.3, scroll: 3 });
          this.swirl(at2, 0xffa040, 0.8, 120, { to: 0xff2a00, radius: 1.4, height: 4, size: 0.25 });
          this.light(this.pos(at2, 2), 0xff7a2a, 50, 18, 0.6);
        }
        if (near(at2)) this.shake = Math.max(this.shake, dragon ? 0.3 : 0.2);
        return;
      }
      case 'sfida':
        this.shockwave(s, C, 6, 0.6, 0.4);
        this.verticalRing(this.pos(tgt, (tgt.rig?.height || 2) + 0.4), C, 0.8, 0.6, this.camera.position.clone().sub(tp));
        this.rise(s, C, 30, { radius: 1, speed: 1.4 });
        this.decal(s, TEX.rune, 5, C, 1.0, { from: 2, ease: 0.2 });
        return;
      case 'pelle_pietra': case 'pelle_bronzo':
        this.decal(s, TEX.rune, 4, C, 1.6, { from: 1, ease: 0.3, spin: 1.5 });
        this.swirl(s, C, 1.0, 60, { pool: id === 'pelle_pietra' ? this.smoke : this.glow, size: 0.25 });
        this.rise(s, 0xffffff, 20, { radius: 0.7 });
        this.bubble(s, C, 1.0);
        return;
      case 'respiro_monte': case 'meditazione':
        this.decal(s, TEX.rune, 3.6, C, 1.6, { from: 1, ease: 0.3, spin: 0.8 });
        this.rise(s, C, 50, { to: 0xffffff, radius: 1.0, speed: 0.9, life: 1.3 });
        if (id === 'meditazione') this.lotusPetals(s, 30);
        return;
      // ---------------- Ombra
      case 'colpo_rapido': case 'pugnalata':
        this.slashArc(s, C, { radius: 1.4, width: 0.5, tilt: -0.6, roll: 0.6, dur: 0.16, spin: 3.2 });
        this.later(0.08, () => this.slashArc(s, C, { radius: 1.4, width: 0.5, tilt: 0.6, roll: -0.6, dur: 0.16, spin: 3.2, reverse: true }));
        this.burst(tp, C, 14, 4, 0.12, 0.3);
        if (id === 'pugnalata') this.smokePuff(tp, 0x3a2050, 6, 0.6, 0.6, { speed: 1 });
        return;
      case 'taglio_finale':
        this.slashArc(s, C, { radius: 2.0, width: 0.9, tilt: 0.78, dur: 0.24, grow: 1.1 });
        this.slashArc(s, C, { radius: 2.0, width: 0.9, tilt: -0.78, dur: 0.24, grow: 1.1, reverse: true });
        this.later(0.1, () => { this.burst(tp, C, 40, 7, 0.16, 0.5, { white: 0.4 }); this.flash(tp, C, 2.2); this.verticalRing(tp, C, 1.4, 0.3, this.camera.position.clone().sub(tp)); });
        if (near(tgt)) this.shake = Math.max(this.shake, 0.15);
        return;
      case 'lama_veleno':
        this.slashArc(s, C, { radius: 1.6, width: 0.6, tilt: 0.5, dur: 0.2 });
        this.smokePuff(tp, 0x4a9a2a, 14, 0.8, 1.2, { to: 0x1a3a10, speed: 1.2, up: 0.5 });
        this.burst(tp, 0x8aff4a, 20, 2.5, 0.12, 0.9, { to: 0x2a6a10, grav: 5, white: 0 });
        return;
      case 'passo_ombra':
        this.smokePuff(sp, 0x2a1a3a, 22, 1.1, 0.9, { to: 0x120a1a, speed: 2.2, up: 0.4, spread: 0.6 });
        this.burst(sp, C, 24, 4, 0.13, 0.5);
        this.later(0.12, () => { this.smokePuff(tp, 0x2a1a3a, 22, 1.1, 0.9, { speed: 2.2, up: 0.4 }); this.slashArc(tgt, C, { radius: 1.5, width: 0.6, dur: 0.2, yaw: Math.PI }); this.burst(tp, C, 20, 5, 0.14, 0.4); });
        return;
      case 'danza_lame':
        for (let i = 0; i < 4; i++) this.later(i * 0.08, () => this.slashArc(s, i % 2 ? 0xffffff : C, { sweep: TAU, radius: 2.0 + i * 0.35, width: 0.45, spin: 6, dur: 0.24, h: 0.7 + i * 0.3, tilt: rnd(-0.25, 0.25), reverse: i % 2 === 1 }));
        this.burst(sp, C, 50, 8, 0.12, 0.45, { flat: true, grav: 1 });
        this.shockwave(s, C, 3.5, 0.4);
        return;
      case 'marchio_morte': case 'marchio_tuono': {
        const above = this.pos(tgt, (tgt.rig?.height || 2) + 0.9);
        const m = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.rune, color: C, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
        this.add(m, 1.4, (q) => { m.position.copy(above); m.position.x = tgt.x; m.position.z = tgt.z; m.material.rotation += 0.06; const k = q < 0.2 ? q / 0.2 : 1; m.scale.setScalar(1.3 * k); m.material.opacity = q > 0.7 ? (1 - q) / 0.3 : 1; });
        if (id === 'marchio_morte') this.smokePuff(tp, 0x3a0a1a, 16, 0.9, 1.1, { speed: 0.8, up: 0.6 });
        else for (let i = 0; i < 3; i++) this.later(i * 0.1, () => this.bolt(above.clone(), this.pos(tgt, 0.8), C, { width: 0.08, dur: 0.2 }));
        this.burst(tp, C, 20, 3, 0.13, 0.6);
        return;
      }
      case 'tiro_mirato': case 'freccia_perforante': case 'freccia_inchiodante': {
        const big = id !== 'freccia_inchiodante';
        this.arrowShot(s, tgt, C, { big, dur: id === 'freccia_perforante' ? 0.14 : 0.2 });
        if (id === 'freccia_perforante') { const b = this.pos(tgt, 1.2); const dir = b.clone().sub(sp).normalize(); this.later(0.14, () => this.bolt(b, b.clone().add(dir.multiplyScalar(8)), C, { width: 0.12, jag: 0.01, branch: 0, dur: 0.25 })); }
        if (id === 'freccia_inchiodante') this.later(0.2, () => this.shockwave(tgt, 0xffffff, 1.6, 0.4));
        this.burst(sp, C, 10, 2, 0.1, 0.3);
        return;
      }
      case 'pioggia_frecce': {
        const r = sk.radius ?? 5, c = at;
        this.decal(c, TEX.rune, r * 2.2, C, 1.2, { from: r, ease: 0.2, spin: 0.6 });
        for (let i = 0; i < 26; i++) {
          this.later(rnd(0, 0.6), () => {
            const a = Math.random() * TAU, d = Math.sqrt(Math.random()) * r;
            const g = { x: c.x + Math.cos(a) * d, z: c.z + Math.sin(a) * d };
            const from = { x: g.x - 2, y: heightAt(g.x, g.z) + 14, z: g.z - 2 }, to = { x: g.x, y: heightAt(g.x, g.z) - 1.2, z: g.z };
            this.arrowShot({ x: from.x, y: from.y - 1.5, z: from.z }, { x: to.x, y: to.y, z: to.z }, C, { dur: 0.25 });
            this.later(0.25, () => this.smokePuff({ x: g.x, y: heightAt(g.x, g.z), z: g.z }, 0xb0a080, 3, 0.6, 0.6, { speed: 1.2, up: 0.3 }));
          });
        }
        return;
      }
      case 'occhio_falco':
        this.swirl(s, C, 0.9, 60, { radius: 0.8 });
        this.decal(s, TEX.rune, 3.6, C, 1.3, { from: 1.2, ease: 0.25, spin: 1.2 });
        this.stars.emit(this.pos(s, 2.8), _v.set(0, 0, 0), WHITE, _c.set(C), 2.5, 0.2, 0.9, 0, 1);
        return;
      // ---------------- Monaco
      case 'pugno_ferro': case 'raffica': {
        const n = id === 'raffica' ? 4 : 1;
        for (let i = 0; i < n; i++) this.later(i * 0.08, () => {
          const p = this.pos(tgt, 1.1 + rnd(-0.3, 0.3));
          const dir = this.camera.position.clone().sub(p);
          this.verticalRing(p, C, 0.9, 0.22, dir);
          this.burst(p, C, 14, 5, 0.14, 0.3, { to: 0xff4a10 });
          this.flash(p, C, 1.0, 0.1);
        });
        return;
      }
      case 'calcio_gru':
        this.slashArc(s, C, { sweep: TAU, radius: 2.6, width: 0.9, spin: 5, dur: 0.3, h: 0.6, tilt: 0.15 });
        this.swirl(s, 0xfff0d0, 0.4, 40, { radius: 1.6, height: 1, size: 0.14 });
        this.shockwave(s, C, 3, 0.4);
        return;
      case 'palmo_chi': case 'dardo_luce': case 'onda_chi': case 'fiore_loto': case 'vortice_interiore': {
        const lotus = id === 'fiore_loto';
        const big = id === 'onda_chi' || id === 'vortice_interiore';
        this.projectile(s, tgt, C, { size: big ? 0.8 : 0.55, trail: big ? 10 : 6, trailTo: lotus ? 0xff80c0 : id === 'dardo_luce' ? 0xffffff : 0xff5a10, dur: 0.3, trailPool: lotus ? this.petals : this.glow }, () => {
          const p = this.pos(at || tgt, 1.1);
          this.flash(p, C, big ? 2.4 : 1.4, 0.18);
          this.burst(p, C, big ? 50 : 24, big ? 7 : 4.5, 0.16, 0.5, { white: 0.4 });
          if (sk.radius) { this.shockwave(at || tgt, C, sk.radius, 0.5); this.decal(at || tgt, TEX.rune, sk.radius * 2, C, 0.9, { from: 1, ease: 0.2 }); }
          if (lotus) this.lotusPetals(tgt, 26);
          if (id === 'vortice_interiore') this.swirl(tgt, C, 0.6, 60, { radius: 1.2 });
          this.light(p, C, 25, 10, 0.3);
        });
        return;
      }
      case 'spirito_tigre': case 'sigillo_interiore':
        this.pillar(s, C, 1.0, 7, 0.9, { taper: 0.4, scroll: 2.5 });
        this.swirl(s, C, 0.9, 100, { to: id === 'spirito_tigre' ? 0xff3a00 : 0xffffff, radius: 1.0, size: 0.22 });
        this.decal(s, TEX.rune, 4, C, 1.4, { from: 1.5, ease: 0.25, spin: 1.5 });
        if (id === 'sigillo_interiore') this.lotusPetals(s, 20);
        return;
      // ---------------- Mistico
      case 'fulmine_celeste': case 'giudizio_cielo': {
        const holy = id === 'giudizio_cielo';
        const top = tp.clone().add(V().set(0, 22, 0));
        this.smokePuff(top.clone().add(V().set(0, -6, 0)), holy ? 0xffffff : 0x404858, 14, 3, 1.2, { speed: 1, up: 0, grav: 0 });
        if (holy) { this.pillar(tgt, 0xfff6d0, 1.6, 22, 0.9, { scroll: 4 }); this.decal(tgt, TEX.rune, 6, 0xfff0a0, 1.4, { from: 2, ease: 0.2, spin: 2 }); }
        this.bolt(top, this.pos(tgt, 0.1), holy ? 0xffffff : C, { width: 0.32, dur: 0.42 });
        this.later(0.07, () => this.bolt(top.clone().add(V().set(rnd(-3, 3), 0, rnd(-3, 3))), this.pos(tgt, 0.3), C, { width: 0.18, dur: 0.3 }));
        this.flash(this.pos(tgt, 0.6), C, 3.2, 0.22);
        this.light(tp, C, 70, 20, 0.4);
        this.shockwave(tgt, C, 3, 0.45);
        this.burst(this.pos(tgt, 0.3), C, 50, 8, 0.15, 0.55, { white: 0.5 });
        this.decal(tgt, TEX.crack, 3.5, 0x111111, 3, { normal: true, opacity: 0.8 });
        if (near(tgt)) this.shake = Math.max(this.shake, 0.22);
        return;
      }
      case 'tempesta_saette': {
        const r = sk.radius ?? 5, c = at;
        this.smokePuff({ x: c.x, y: heightAt(c.x, c.z) + 14, z: c.z }, 0x3a4050, 22, 4, 1.6, { speed: 2, up: 0, grav: 0, spread: 3 });
        this.decal(c, TEX.rune, r * 2.2, C, 1.6, { from: r, ease: 0.2, spin: 1 });
        for (let i = 0; i < 9; i++) this.later(i * 0.09, () => {
          const a = Math.random() * TAU, d = Math.sqrt(Math.random()) * r;
          const g = { x: c.x + Math.cos(a) * d, y: 0, z: c.z + Math.sin(a) * d };
          g.y = heightAt(g.x, g.z);
          this.bolt(V().set(g.x + rnd(-2, 2), g.y + 15, g.z + rnd(-2, 2)), V().set(g.x, g.y + 0.1, g.z), C, { width: 0.2, dur: 0.3 });
          this.burst(V().set(g.x, g.y + 0.3, g.z), C, 16, 5, 0.13, 0.4);
          this.flash(V().set(g.x, g.y + 0.5, g.z), C, 1.8, 0.15);
        });
        this.light(this.pos(c, 2), C, 60, 22, 1.0);
        return;
      }
      case 'occhio_ciclone': case 'turbine_galoppo': {
        const r = sk.radius ?? 5;
        for (let k = 0; k < 3; k++) this.slashArc(s, C, { sweep: TAU, radius: r * (0.45 + k * 0.22), width: 0.5, spin: 7 + k, dur: 0.6, h: 0.4 + k * 0.7, tilt: rnd(-0.1, 0.1) });
        this.swirl(s, 0xffffff, 0.8, 80, { radius: r * 0.6, height: 3, size: 0.16 });
        this.smokePuff({ x: s.x, y: this.ground(s), z: s.z }, 0xd0d8e0, 18, 1.2, 1.0, { speed: r, up: 1.2, spread: 1.5 });
        return;
      }
      case 'tocco_curativo': case 'loto_rigenerante': case 'pioggia_petali': case 'preghiera_antenati': case 'benedizione': {
        const area = sk.type === 'heal_aoe' || sk.type === 'buff_allies';
        const c = area ? s : tgt;
        if (id === 'pioggia_petali') {
          for (let i = 0; i < 90; i++) {
            const a = Math.random() * TAU, d = Math.sqrt(Math.random()) * (sk.radius ?? 8);
            _p.set(c.x + Math.cos(a) * d, (c.y ?? 0) + rnd(4, 8), c.z + Math.sin(a) * d);
            this.petals.emit(_p, _v.set(rnd(-0.6, 0.6), rnd(-2.5, -1.4), rnd(-0.6, 0.6)), WHITE, _c.set(0xffd0e0), rnd(0.25, 0.4), 0.2, rnd(2, 3), 0, 0.98);
          }
        }
        if (id === 'preghiera_antenati' || id === 'benedizione') this.pillar(c, C, area ? 3 : 1.2, 14, 1.2, { scroll: 1.2 });
        this.decal(c, TEX.rune, area ? 8 : 3.4, C, 1.6, { from: area ? 3 : 1, ease: 0.25, spin: 0.8 });
        this.rise(c, C, area ? 70 : 40, { to: 0xffffff, radius: area ? 4 : 0.9, speed: 1, life: 1.2 });
        if (id === 'loto_rigenerante') this.lotusPetals(tgt, 24);
        this.flash(this.pos(c, 1.2), C, 1.6, 0.25);
        return;
      }
      case 'scudo_giada':
        this.bubble(tgt, C, 1.6);
        this.rise(tgt, C, 30, { radius: 1.1, speed: 1.2 });
        this.decal(tgt, TEX.rune, 3.2, C, 1.6, { from: 1, ease: 0.25, spin: 1 });
        return;
    }
    // ---------------- predefiniti per tipo di effetto
    switch (sk.fx) {
      case 'spin': this.slashArc(s, C, { sweep: TAU, radius: sk.radius || 3, width: 0.9, spin: 5, dur: 0.3 }); this.shockwave(s, C, sk.radius || 3); break;
      case 'quake': this.shockwave(s, C, sk.radius || 5); this.smokePuff({ x: s.x, y: this.ground(s), z: s.z }, 0xa89070, 18, 1.2, 1, { speed: 6 }); break;
      case 'aura': this.swirl(s, C, 0.9, 60); this.decal(s, TEX.rune, 4, C, 1.2, { from: 1.5, ease: 0.25, spin: 1 }); break;
      case 'heal': this.rise(tgt, C, 40, { to: 0xffffff }); break;
      case 'bolt': this.projectile(s, tgt, C, {}, () => this.burst(this.pos(tgt), C, 24, 4.5, 0.16, 0.5)); break;
      case 'arrow': this.arrowShot(s, tgt, C); break;
      case 'lightning': this.bolt(tp.clone().add(V().set(0, 16, 0)), this.pos(tgt, 0.2), C); this.burst(tp, C, 30, 6, 0.15, 0.5); break;
      case 'dash': this.burst(tp, C, 24, 5, 0.15, 0.4); this.shockwave(tgt, C, 2.4); break;
      case 'wind': this.slashArc(s, C, { sweep: TAU, radius: sk.radius || 5, width: 0.6, spin: 7, dur: 0.5 }); break;
      case 'shield': this.bubble(tgt, C); break;
      default: this.slashArc(s, C, { radius: 1.7, width: 0.8, tilt: rnd(-0.6, 0.6), dur: 0.22 }); this.burst(tp, C, 14, 4, 0.14, 0.35);
    }
  }

  lotusPetals(ent, n) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * TAU;
      _p.set(ent.x + Math.cos(a) * 0.3, (ent.y ?? 0) + 1.2, ent.z + Math.sin(a) * 0.3);
      this.petals.emit(_p, _v.set(Math.cos(a) * rnd(1.5, 3), rnd(1, 3), Math.sin(a) * rnd(1.5, 3)), WHITE, _c.set(0xff9ac8), rnd(0.25, 0.4), 0.15, rnd(1.2, 2), 2.5, 0.9);
    }
  }

  levelUp(ent) {
    this.pillar(ent, 0xffd860, 1.5, 20, 1.6, { scroll: 2 });
    this.decal(ent, TEX.rune, 6, 0xffd860, 2.0, { from: 2, ease: 0.3, spin: 1.5 });
    this.swirl(ent, 0xffe8a0, 1.4, 160, { to: 0xffffff, radius: 1.4, height: 5, size: 0.22 });
    this.shockwave(ent, 0xffd860, 5, 0.8);
  }
}
