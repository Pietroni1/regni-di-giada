// Comodità sociali: scambio fra giocatori, deposito condiviso dell'account, amici. Nessun import: lo importa data.js
// (che aggiunge il PNG alle NPC_ROLES). La logica è in server/sociale.js, la finestra in godot/script/sociale.gd.

export const NPC_SOCIALE = {
  magazziniere: { name: 'Cassiera Zhou', title: 'Magazziniere' },
};

export const DEPOSITO_SIZE = 48;      // caselle del deposito, uno per account (condiviso fra i personaggi)
export const SCAMBIO_CASELLE = 8;     // oggetti offerti al massimo da ciascuno
export const SCAMBIO_RAGGIO = 10;     // metri entro cui si può proporre uno scambio
export const SCAMBIO_RAGGIO_MAX = 16; // oltre questa distanza lo scambio si annulla
export const AMICI_MAX = 50;
