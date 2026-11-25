// Migrate only the stock npm sources. Preserve user pins, resource filters and all other settings.
import { existsSync, readFileSync, writeFileSync, renameSync } from 'node:fs';

const file = process.argv[2];
if (!file) throw new Error('Settings path required');
if (existsSync(file)) {
  const settings = JSON.parse(readFileSync(file, 'utf8'));
  const replacements = new Map([
    ['npm:pi-vim', '~/.local/share/dotfiles/pi/current/node_modules/pi-vim'],
    ['npm:pi-vim@0.14.2', '~/.local/share/dotfiles/pi/current/node_modules/pi-vim'],
    ['npm:pi-subagents', '~/.local/share/dotfiles/pi/current/node_modules/pi-subagents'],
    ['npm:pi-subagents@0.66.0', '~/.local/share/dotfiles/pi/current/node_modules/pi-subagents'],
  ]);
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
