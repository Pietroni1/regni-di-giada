// Post-elaborazione: bloom selettivo (lanterne, magie, armi potenziate), antialiasing e vignettatura.
// La qualità grafica si sceglie nella guida (H) ed è salvata nel browser.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { VignetteShader } from 'three/addons/shaders/VignetteShader.js';

export const QUALITIES = {
  alta: { name: 'Alta', composer: true, samples: 4, bloom: true, shadows: 2048, ratio: 1.5, outlines: true, petals: true },
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
      if (this.q.bloom) {
        this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x, size.y), 0.55, 0.45, 0.82);
        c.addPass(this.bloom);
      }
      const vig = new ShaderPass(VignetteShader);
      vig.uniforms.offset.value = 0.95; vig.uniforms.darkness.value = 1.1;
      c.addPass(vig);
      c.addPass(new OutputPass());
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
