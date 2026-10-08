import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Run the real UI handlers without images or a rendering loop. Browser smoke
// testing still covers layout, pointer capture and asset loading separately.
function harness({ blockedStorage = false } = {}) {
  const elements = new Map(), storage = new Map();
  let document;
  class Element {
    constructor() {
      this.listeners = new Map(); this.children = []; this.dataset = {}; this.textContent = '';
      this.classes = new Set(); this.classList = {
        add: (...names) => names.forEach(n => this.classes.add(n)), remove: (...names) => names.forEach(n => this.classes.delete(n)),
        toggle: (name, enabled = !this.classes.has(name)) => { enabled ? this.classes.add(name) : this.classes.delete(name); return enabled; },
      };
      this.style = { setProperty: (key, value) => { this.style[key] = value; } };
    }
    addEventListener(name, fn) { if (!this.listeners.has(name)) this.listeners.set(name, []); this.listeners.get(name).push(fn); }
    emit(name, detail = {}) { const e = { button: 0, clientX: 900, clientY: 360, pointerType: 'mouse', pointerId: 1, preventDefault() { this.defaultPrevented = true; }, ...detail }; for (const fn of this.listeners.get(name) || []) fn(e); return e; }
    append(...children) { this.children.push(...children); }
    replaceChildren(...children) { this.children = children; }
    focus() { document.activeElement = this; }
    setPointerCapture(id) { this.capture = id; }
    getBoundingClientRect() { return { left: 0, top: 0, width: 1280, height: 720 }; }
    getContext() { return new Proxy({}, { get: (target, key) => target[key] || (() => {}), set: (target, key, value) => { target[key] = value; return true; } }); }
  }
  const el = id => { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); };
  document = new Element(); Object.assign(document, { body: el('body'), hidden: false,
    getElementById: el, querySelector: el, querySelectorAll: () => [], createElement: () => new Element(), createTextNode: text => text });
  const window = new Element(); window.matchMedia = () => ({ matches: false });
  const context = vm.createContext({ console, document, window, innerWidth: 1280, innerHeight: 720, devicePixelRatio: 1,
    performance: { now: () => 2000 }, requestAnimationFrame: () => {},
    localStorage: { getItem(key) { if (blockedStorage) throw new Error('Storage unavailable'); return storage.get(key) || null; },
      setItem(key, value) { if (blockedStorage) throw new Error('Storage unavailable'); storage.set(key, value); } },
    LongdanArt: { portraitFor: () => '' }, LongdanScene: { landscape: () => ({ scenery: [] }) }, LongdanCombatArt: {} });
  for (const file of ['stages.js', 'campaign.js']) vm.runInContext(readFileSync(new URL(file, import.meta.url), 'utf8'), context);
  const source = readFileSync(new URL('game.js', import.meta.url), 'utf8'); assert(source.includes('  boot();'));
  vm.runInContext(source.replace('  boot();', '  globalThis.ui = { campaign, inputState, start, requestStart, cancelStart, togglePause, returnMenu, continueGame, updateHud, processEvents, readSave, get pendingStart() { return pendingStart; } };'), context);
  const ui = context.ui, g = ui.campaign, canvas = el('battlefield');
  const fresh = () => { g.reset(); g.mode = 'playing'; g.enemies = []; g.allies = []; g.events = []; g.huts = []; g.rocks = []; g.props = []; };
  fresh(); return { ui, g, canvas, document, window, el, fresh };
}

let h = harness();
h.canvas.emit('pointerdown'); assert.equal(h.g.player.action, null, 'Pointer capture may not duplicate the mouse action');
h.canvas.emit('mousedown', { button: 0 }); assert.equal(h.g.player.action.key, 'thrust1');
h.g.updatePlayerAction(.33); h.canvas.emit('mousedown', { button: 2 });
assert.equal(h.g.actionBuffer?.kind, 'heavy', 'Right-click during held left-click must reach the action buffer');
h.window.emit('mouseup', { button: 2 }); assert(h.ui.inputState().attack, 'Releasing right-click must preserve held left-click');
for (let i = 0; i < 3; i++) h.g.step(.04, h.ui.inputState());
assert.equal(h.g.player.action.key, 'sweep'); h.window.emit('mouseup', { button: 0 }); assert(!h.ui.inputState().attack);

h = harness(); h.canvas.emit('mousedown', { button: 2 }); h.canvas.emit('mousedown', { button: 0 });
assert(h.ui.inputState().attack); assert.equal(h.g.player.action.key, 'sweep');
for (let i = 0; i < 22; i++) h.g.step(.04, h.ui.inputState());
assert(h.g.player.action?.key.startsWith('thrust'), 'Held left-click starts the combo after the right-click move');
h.window.emit('pointercancel'); assert(!h.ui.inputState().attack);
h.canvas.emit('mousedown'); h.canvas.emit('lostpointercapture'); assert(!h.ui.inputState().attack);
h.canvas.emit('mousedown'); h.document.emit('keydown', { key: 'w' }); h.window.emit('blur');
assert.equal(h.g.mode, 'paused'); assert(!h.ui.inputState().attack); assert.equal(h.ui.inputState().y, 0);
h.g.player.action = null; h.canvas.emit('mousedown', { button: 2 }); assert.equal(h.g.player.action, null, 'Paused mouse clicks may not attack');

h = harness({ blockedStorage: true }); h.ui.start('story'); h.g.chooseRoute('continue');
h.g.flags.mountain = true; h.g.enterStage('village'); h.ui.processEvents(); h.ui.togglePause();
assert.match(h.el('saveStatus').textContent, /仅本次/); h.ui.requestStart('story');
assert(h.ui.pendingStart, 'A storage failure must not skip restart confirmation'); assert.equal(h.g.mode, 'paused');
h.document.emit('keydown', { key: 'Tab' }); assert.equal(h.document.activeElement, h.el('confirmRestartButton'));
h.document.emit('keydown', { key: 'Tab', shiftKey: true }); assert.equal(h.document.activeElement, h.el('cancelRestartButton'));
h.document.emit('keydown', { key: 'Escape' }); assert.equal(h.ui.pendingStart, null); assert.equal(h.g.mode, 'paused'); assert(h.g.flags.mountain);
h.ui.returnMenu(); assert(h.ui.readSave()); assert.match(h.el('saveInfo').textContent, /刷新或关闭/);
h.ui.continueGame(); assert.equal(h.g.mode, 'playing'); assert.equal(h.g.stage, 'village'); assert.equal(h.g.difficulty, 'story'); assert.equal(h.g.player.maxHp, 240);

h = harness(); h.g.flags.healer = h.g.flags.adou = true; h.g.enterStage('house'); h.g.startRescue(); h.g.rescue.progress = 20;
h.ui.processEvents(); h.ui.updateHud(); assert.match(h.el('pressureLabel').textContent, /还需击退追兵/); assert.match(h.g.getMission().text, /还剩 3 名追兵/);
for (const e of h.g.enemies) e.hp = 0; assert.match(h.g.getMission().text, /第二波追兵即将/);
h = harness(); h.g.player.hp = 100; assert(h.g.heal()); h.ui.updateHud(); assert.match(h.el('potionState').textContent, /服药/);
h.g.updatePlayerAction(.94); h.g.updatePlayerAction(.04); h.ui.updateHud(); assert.equal(h.el('potionState').textContent, '体力已恢复'); assert.equal(h.el('healButton').style['--charge'], '100%');

console.log('PASS: chorded mouse buttons and release, input cleanup, paused input, session-only saving, restart cancellation and keyboard controls, rescue readiness and medicine progress.');
