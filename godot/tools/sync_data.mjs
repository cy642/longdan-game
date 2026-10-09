// Reuse the web chapter definitions. The Godot game never executes JavaScript.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const sandbox = { Math };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(root, 'stages.js'), 'utf8'), sandbox);
mkdirSync(path.join(root, 'godot/data'), { recursive: true });
writeFileSync(path.join(root, 'godot/data/chapter1.json'), JSON.stringify(sandbox.LongdanDefinitions, null, 2) + '\n');
console.log('Godot chapter data synchronized: six regions and combat timings.');
