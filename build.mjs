import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.dirname(fileURLToPath(import.meta.url));
export function build({ offline = false } = {}) {
  const asset = name => offline ? 'data:image/png;base64,' + readFileSync(path.join(root, 'assets', name)).toString('base64') : 'assets/' + name;
  const artwork = readFileSync(path.join(root, 'visuals.js'), 'utf8').replace('/* HERO_ASSETS */ null', () => JSON.stringify({
    portrait: asset('zhaoyun-reference.png'),
    hero: asset('zhaoyun-actions-v1.png'),
    units: asset('chibi-units-v1.png'),
    walk: asset('zhaoyun-walk-v2.png'),
    chapter: asset('chapter1-units-v2.png'),
    attack: asset('zhaoyun-attack-v3.png'),
  }));
  return readFileSync(path.join(root, 'shell.html'), 'utf8')
    .replace('/* GAME_STYLES */', readFileSync(path.join(root, 'styles.css'), 'utf8'))
    .replace('/* GAME_SCRIPT */', () => artwork + '\n' + ['scene-art.js', 'combat-art.js', 'stages.js', 'campaign.js', 'game.js'].map(name => readFileSync(path.join(root, name), 'utf8')).join('\n'));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const offline = process.argv.includes('--offline'), filename = offline ? 'longdan-offline.html' : 'index.html';
  writeFileSync(path.join(root, filename), build({ offline }));
  console.log('已生成' + (offline ? '可单独复制的离线游戏：' : '线上轻量入口：') + filename);
}
