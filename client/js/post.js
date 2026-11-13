// Post-elaborazione: bloom selettivo (lanterne, magie, armi potenziate), antialiasing e vignettatura.
// La qualità grafica si sceglie nella guida (H) ed è salvata nel browser.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { VignetteShader } from 'three/addons/shaders/VignetteShader.js';
import { GTAOPass } from 'three/addons/postprocessing/GTAOPass.js';

// Correzione colore finale (dopo il tone mapping): contrasto morbido, saturazione, ombre fredde e luci calde.
const GradeShader = {
  uniforms: { tDiffuse: { value: null }, sat: { value: 1.14 }, contrast: { value: 1.07 }, split: { value: 0.045 } },
  vertexShader: 'varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float sat, contrast, split; varying vec2 vUv;
    void main() {
      vec4 c = texture2D(tDiffuse, vUv);
      float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
      vec3 col = mix(vec3(l), c.rgb, sat);
      col = (col - 0.5) * contrast + 0.5;
      col += mix(vec3(-0.6, 0.0, 1.0), vec3(1.0, 0.45, -0.6), smoothstep(0.15, 0.85, l)) * split;   // ombre verso il blu, luci verso l'oro
      gl_FragColor = vec4(clamp(col, 0.0, 1.0), c.a);
    }`,
};

export const QUALITIES = {
  alta: { name: 'Alta', composer: true, samples: 4, bloom: true, ao: true, shadows: 2048, ratio: 1.5, outlines: true, petals: true },
  media: { name: 'Media', composer: true, samples: 2, bloom: true, shadows: 1024, ratio: 1.25, outlines: true, petals: true },
  bassa: { name: 'Bassa', composer: false, samples: 0, bloom: false, shadows: 0, ratio: 1, outlines: false, petals: false },
};

function savedQuality() {
  try { const q = localStorage.getItem('rdg-gfx'); if (QUALITIES[q]) return q; } catch { /* ignora */ }
  return 'alta';
}

export class Post {
  constructor(renderer, scene, camera) {
    this.renderer = renderer; this.scene = scene; this.camera = camera;
    this.listeners = [];
    this.set(savedQuality());
  }

  onChange(fn) { this.listeners.push(fn); }

  set(q) {
    this.quality = q;
    this.q = QUALITIES[q];
    try { localStorage.setItem('rdg-gfx', q); } catch { /* ignora */ }
    const r = this.renderer;
    r.setPixelRatio(Math.min(devicePixelRatio, this.q.ratio));
    r.shadowMap.enabled = this.q.shadows > 0;
    if (this.composer) { this.composer.dispose(); this.composer = null; }
    if (this.q.composer) {
      const size = r.getDrawingBufferSize(new THREE.Vector2());
      const rt = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: this.q.samples });
      const c = new EffectComposer(r, rt);
      c.addPass(new RenderPass(this.scene, this.camera));
      if (this.q.ao) {
        // occlusione ambientale: ombre di contatto sotto tetti, alberi e personaggi
        const ao = new GTAOPass(this.scene, this.camera, size.x, size.y);
        ao.updateGtaoMaterial({ radius: 0.9, distanceExponent: 1.4, thickness: 1.2, scale: 1.15, samples: 12 });
        ao.updatePdMaterial({ lumaPhi: 10, depthPhi: 2, normalPhi: 3, radius: 6, rings: 2, samples: 12 });
        ao.blendIntensity = 0.85;
        // particelle, sprite e superfici trasparenti non devono proiettare occlusione
        const vis = ao.overrideVisibility.bind(ao);
        ao.overrideVisibility = function () {
          vis();
          const cache = this._visibilityCache;
          this.scene.traverse((o) => {
            const m = o.material;
            if (o.isSprite || (o.isMesh && m && !Array.isArray(m) && (m.transparent || m.depthWrite === false))) { if (!cache.has(o)) cache.set(o, o.visible); o.visible = false; }
          });
        };
        c.addPass(ao);
        this.ao = ao;
      }
      if (this.q.bloom) {
        this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x, size.y), 0.55, 0.45, 0.82);
        c.addPass(this.bloom);
      }
      const vig = new ShaderPass(VignetteShader);
      vig.uniforms.offset.value = 0.95; vig.uniforms.darkness.value = 1.1;
      c.addPass(vig);
      c.addPass(new OutputPass());
      c.addPass(new ShaderPass(GradeShader));
      this.composer = c;
    }
    for (const fn of this.listeners) fn(this.q);
  }

  resize(w, h) {
    this.renderer.setSize(w, h);
    if (this.composer) this.composer.setSize(w, h);
  }

  render() {
    if (this.composer) this.composer.render();
    else this.renderer.render(this.scene, this.camera);
  }
}
