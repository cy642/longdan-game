import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
const pngData = name => 'data:image/png;base64,' + readFileSync(path.join(root, 'assets', name)).toString('base64');
const artwork = readFileSync(path.join(root, 'visuals.js'), 'utf8').replace('/* HERO_ASSETS */ null', () => JSON.stringify({
  portrait: pngData('zhaoyun-reference.png'),
  hero: pngData('zhaoyun-actions-v1.png'),
  units: pngData('chibi-units-v1.png'),
  walk: pngData('zhaoyun-walk-v2.png'),
  chapter: pngData('chapter1-units-v2.png'),
  attack: pngData('zhaoyun-attack-v3.png'),
}));
const html = readFileSync(path.join(root, 'shell.html'), 'utf8')
  .replace('/* GAME_STYLES */', readFileSync(path.join(root, 'styles.css'), 'utf8'))
  .replace('/* GAME_SCRIPT */', () => artwork + '\n' + ['stages.js', 'campaign.js', 'game.js'].map(name => readFileSync(path.join(root, name), 'utf8')).join('\n'));
writeFileSync(path.join(root, 'index.html'), html);
console.log('已生成可离线直接打开的 index.html');
