// Orologio accelerato per il server di prova (caricato con `node --import` da simula.mjs quando --velocita > 1).
// Moltiplica il tempo visto dal server: Date.now() corre SIM_VELOCITA volte più in fretta e i timer durano in proporzione meno.
// Il motore usa solo Date.now(), setInterval e setTimeout, quindi ricariche, GCD, rigenerazioni e danni nel tempo restano coerenti.
import { performance } from 'node:perf_hooks';

const k = Number(process.env.SIM_VELOCITA) || 1;
if (k !== 1) {
  const t0 = Date.now(), p0 = performance.now();
  Date.now = () => Math.floor(t0 + (performance.now() - p0) * k);
  const si = globalThis.setInterval, st = globalThis.setTimeout;
  globalThis.setInterval = (f, ms, ...a) => si(f, Math.max(1, (ms || 0) / k), ...a);
  globalThis.setTimeout = (f, ms, ...a) => st(f, Math.max(0, (ms || 0) / k), ...a);
}
