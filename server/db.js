// Archivio su file JSON: account (password con scrypt) e personaggi.
// Per un gruppo di amici è più che sufficiente e non richiede installare un database.
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

export class DB {
  constructor(file) {
    this.file = file;
    this.data = { accounts: {}, chars: {}, nextChar: 1 };
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (fs.existsSync(file)) {
      this.data = JSON.parse(fs.readFileSync(file, 'utf8'));
    }
  }

  save() {
    const tmp = this.file + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(this.data));
    fs.renameSync(tmp, this.file);
  }

  static hash(pass, salt) {
    return crypto.scryptSync(pass, salt, 64).toString('hex');
  }

  account(user) {
    return this.data.accounts[String(user).toLowerCase()] || null;
  }

  createAccount(user, pass) {
    const key = user.toLowerCase();
    if (this.data.accounts[key]) return false;
    const salt = crypto.randomBytes(16).toString('hex');
    this.data.accounts[key] = { user, salt, hash: DB.hash(pass, salt), chars: [], created: Date.now() };
    this.save();
    return true;
  }

  verify(user, pass) {
    const acc = this.account(user);
    if (!acc) return false;
    const a = Buffer.from(DB.hash(pass, acc.salt), 'hex');
    const b = Buffer.from(acc.hash, 'hex');
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  }

  charsOf(user) {
    const acc = this.account(user);
    return acc ? acc.chars.map(id => this.data.chars[id]).filter(Boolean) : [];
  }

  nameTaken(name) {
    const n = name.toLowerCase();
    return Object.values(this.data.chars).some(c => c.name.toLowerCase() === n);
  }

  createChar(user, ch) {
    const acc = this.account(user);
    ch.id = this.data.nextChar++;
    ch.owner = acc.user.toLowerCase();
    this.data.chars[ch.id] = ch;
    acc.chars.push(ch.id);
    this.save();
    return ch;
  }

  deleteChar(user, id) {
    const acc = this.account(user);
    if (!acc || !acc.chars.includes(id)) return false;
    acc.chars = acc.chars.filter(c => c !== id);
    delete this.data.chars[id];
    this.save();
    return true;
  }
}
