// Migrate only the stock npm sources. Preserve user pins, resource filters and all other settings.
import { existsSync, readFileSync, writeFileSync, renameSync } from 'node:fs';

const file = process.argv[2];
if (!file) throw new Error('Settings path required');
if (existsSync(file)) {
  const settings = JSON.parse(readFileSync(file, 'utf8'));
  const defaults = JSON.parse(readFileSync(new URL('../../pi-settings.example.json', import.meta.url), 'utf8'));
  const replacements = new Map();
  for (const source of defaults.packages) {
    const name = source.slice(4, source.lastIndexOf('@'));
    replacements.set('npm:' + name, source);
    replacements.set('~/.local/share/dotfiles/pi/current/node_modules/' + name, source);
  }
  let changed = false;
  const replace = (source) => {
    if (!replacements.has(source)) return source;
    changed = true;
    return replacements.get(source);
  };
  if (Array.isArray(settings.packages)) {
    settings.packages = settings.packages.map((entry) => typeof entry === 'string'
      ? replace(entry)
      : entry && typeof entry === 'object' ? { ...entry, source: replace(entry.source) } : entry);
  }
  if (changed) {
    const temporary = `${file}.dotfiles-${process.pid}.tmp`;
    writeFileSync(temporary, `${JSON.stringify(settings, null, 2)}\n`, {mode: 0o600, flag: 'wx'});
    renameSync(temporary, file);
  }
}
