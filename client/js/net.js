// Connessione WebSocket con il server di gioco.
export class Net {
  constructor() { this.handlers = {}; this.ws = null; this.onclose = null; }

  connect() {
    return new Promise((resolve, reject) => {
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      this.ws = new WebSocket(`${proto}://${location.host}/ws`);
      this.ws.onopen = () => resolve();
      this.ws.onerror = (e) => reject(e);
      this.ws.onclose = () => this.onclose && this.onclose();
      this.ws.onmessage = (ev) => {
        let m;
        try { m = JSON.parse(ev.data); } catch { return; }
        const h = this.handlers[m.t];
        if (h) h(m);
      };
    });
  }

  on(t, fn) { this.handlers[t] = fn; }
  send(obj) { if (this.ws && this.ws.readyState === 1) this.ws.send(JSON.stringify(obj)); }
}
