import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { build } from './build.mjs';
const context = vm.createContext({ console });
for (const name of ['stages.js', 'campaign.js']) vm.runInContext(readFileSync(new URL(name, import.meta.url), 'utf8'), context);
const { Campaign, StageDefinition, AttackDefinition, attackHits, enemyThreat } = context.LongdanCore;
const fresh = (difficulty = 'normal') => { const g = new Campaign(difficulty); g.start(difficulty); g.chooseRoute('continue'); g.events = []; return g; };
const tick = (g, seconds, input = {}) => { for (let t = 0; t < seconds; t += .02) g.step(.02, input); };
const object = (g, id) => { const o = g.objects.find(o => o.id === id); assert(o, id); g.player.x = o.x; g.player.y = o.y; g.player.action = null; return o; };
const clear = (g, group = null) => { for (const e of [...g.enemies]) if (e.hp > 0 && (!group || e.group === group)) g.damageEnemy(e, 1e5, 0, 0, 'player', 0, true); };
const use = (g, id) => { object(g, id); return g.interact(); };
let g = fresh(); g.enemies = []; g.allies = []; g.rocks = []; g.huts = [];
const origin = { x: g.player.x, y: g.player.y }; tick(g, 1, { x: 1 }); assert(g.player.x > origin.x + 150); assert(g.player.walkDistance > 150);
g.mode = 'paused'; const x = g.player.x; tick(g, .5, { x: 1 }); assert.equal(g.player.x, x); g.mode = 'playing';
let e = g.spawnEnemy('spear', g.player.x + 95, g.player.y); e.cooldown = 99; g.player.dir = 0;
const hp = e.hp; assert(g.attack(0)); assert.equal(e.hp, hp, 'No damage before the actual weapon frames'); assert(!g.attack()); tick(g, .04); assert.equal(e.hp, hp); tick(g, .09); assert(e.hp < hp); const once = e.hp; tick(g, .1); assert.equal(e.hp, once, 'Active frames may not repeatedly damage the same enemy'); tick(g, .22);
g.attack(0); tick(g, .51); g.attack(0); assert.equal(g.player.combo, 3); tick(g, .8);
g = fresh(); g.enemies = []; g.allies = []; g.rocks = []; g.huts = []; g.player.invincible = 0; g.player.hp = 100;
assert(g.heal()); assert.equal(g.player.hp, 100, 'Medicine must have a use animation'); assert.equal(g.player.potions, 2); tick(g, .3); g.damageFriend(g.player, 10, 13); tick(g, 1); assert.equal(g.player.hp, 90, 'An interrupted medicine use may not heal later');
g.player.healCd = 0; assert(g.heal()); tick(g, 1.1); assert.equal(g.player.hp, 175);
g.player.invincible = 0; const qi = g.player.qi; g.dash(1, 0); g.damageFriend(g.player, 20, 800); assert.equal(g.precisionCount, 1); assert.equal(g.player.hp, 175); assert.equal(g.player.qi, qi - 16 + 12);
g.damageFriend(g.player, 20, 800); assert.equal(g.precisionCount, 1, 'One attack can credit only one precision dodge'); tick(g, .25); assert(g.attack(0)); assert.equal(g.player.action.key, 'counter'); tick(g, .5);
g.player.dashCd = 0; g.dash(1, 0); tick(g, .19); g.damageFriend(g.player, 10, 801); assert.equal(g.precisionCount, 1, 'Late invulnerability is not a precision dodge');
g = fresh(); g.enemies = []; g.allies = []; g.huts = []; g.rocks = []; g.player.invincible = 0;
e = g.spawnEnemy('sword', g.player.x + 70, g.player.y); e.action = g.newAction('enemy', { windup: .01, active: .13, recovery: .8, range: 145, arc: .7, damage: 25 }, Math.PI); e.attackDir = Math.PI;
g.dash(0, 1); tick(g, .02); assert.equal(g.precisionCount, 1, 'A real active weapon must trigger precision dodge on intersection'); tick(g, .12); assert.equal(g.precisionCount, 1);
g = fresh(); g.enemies = []; g.allies = []; g.huts = []; g.rocks = []; g.dash(1, 0); tick(g, .1); assert.equal(g.precisionCount, 0, 'An empty dodge must not produce a counter reward');
g = fresh(); g.enemies = []; g.allies = []; g.huts = []; g.rocks = []; g.player.invincible = 999;
for (let i = 0; i < 5; i++) g.spawnEnemy('sword', g.player.x + 45 + i * 5, g.player.y + i * 4);
for (let i = 0; i < 150; i++) { g.step(.02); assert(g.enemies.filter(e => e.action && e.action.t < e.action.def.windup + e.action.def.active).length <= 2, 'At most two melee attacks may pressure the player simultaneously'); }
g = fresh(); g.enemies = []; g.allies = []; g.player.invincible = 0;
e = g.spawnEnemy('shield', g.player.x + 65, g.player.y); e.dir = Math.PI; const shieldHp = e.hp;
g.damageEnemy(e, 40, 0, 0, 'player', 10); assert.equal(e.hp, shieldHp - 9.6); g.damageEnemy(e, 40, 0, 0, 'player', 10, true); assert(e.shieldBroken > 0); assert.equal(e.hp, shieldHp - 49.6);
g = fresh(); g.enterStage('bridge'); g.flags.adou = true; g.flags.house = true; g.flags.committed = true;
assert.equal(g.allies.length, 3); e = g.enemies[0]; for (let i = 0; i < 300; i++) g.damageEnemy(e, 3.5, 0, 0, 'ally', 0, true); assert.equal(e.hp, e.maxHp * .22, 'The squad must not win fights without player participation'); assert.equal(g.kills, 0); assert.equal(g.player.rage, 0);
g = fresh(); assert(!use(g, 'toVillage')); clear(g); assert(g.flags.mountain); use(g, 'campMountain'); assert.equal(g.checkpoint.stage, 'mountain'); assert(use(g, 'toVillage')); assert.equal(g.stage, 'village');
assert(!use(g, 'civilians')); clear(g, 'vRescue'); assert(use(g, 'civilians')); g.chooseRoute('continue'); assert(g.flags.healer && g.flags.civilians); const historyCount = g.history.length; assert(!use(g, 'civilians')); assert.equal(g.history.length, historyCount);
clear(g); use(g, 'toTemple'); assert.equal(g.stage, 'temple'); clear(g); use(g, 'xiahouGate'); assert.equal(g.mode, 'dialog'); g.chooseRoute('bossStart:xiahou'); assert.equal(g.activeBoss, 'xiahou'); assert.equal(g.enemies.filter(e => e.hp > 0).length, 1);
const firstBossHealth = g.boss.maxHp; g.player.hp = 0; g.mode = 'playing'; g.defeat('test', 'test'); assert(g.retry()); assert.equal(g.boss.hp, firstBossHealth); assert(g.flags.civilians); assert.equal(g.player.potions, 3); assert.equal(g.mode, 'playing');
clear(g); assert(g.flags.temple && g.flags.sword); assert.equal(g.mode, 'dialog'); g.chooseRoute('continue');
g.player.rage = 100; assert(g.ultimate()); assert.equal(g.player.rage, 0); tick(g, 1);
use(g, 'shortcut'); assert.equal(g.stage, 'village'); assert(g.flags.healer); assert.equal(g.enemies.filter(e => e.group === 'vRescue').length, 0); use(g, 'toTemple'); use(g, 'toHouse'); assert.equal(g.stage, 'house');
clear(g); use(g, 'adou'); assert(g.flags.adou); g.chooseRoute('rescue'); assert(g.rescue); assert(g.squadActive());
clear(g, 'rescue1'); tick(g, 1.6); assert.equal(g.rescue.wave, 2); g.rescue.healer.hp = 0; tick(g, .02); assert.equal(g.mode, 'defeat'); g.retry(); assert.equal(g.rescue.wave, 1); assert(g.flags.adou && g.flags.healer); assert(!g.flags.mother);
clear(g, 'rescue1'); tick(g, 1.6); clear(g, 'rescue2'); tick(g, 20); assert(g.flags.mother && g.flags.house); g.chooseRoute('continue');
use(g, 'toFork'); clear(g); use(g, 'supplies'); assert.equal(g.boss.type, 'elite'); g.damageEnemy(g.boss, 1e5, 0, 0, 'player', 0, true); use(g, 'supplies'); assert(g.flags.supplies && g.flags.elite);
use(g, 'toBridge'); assert.equal(g.mode, 'dialog'); g.chooseRoute('continue'); assert.equal(g.stage, 'fork'); assert(!g.flags.committed); use(g, 'toBridge'); g.chooseRoute('commit'); assert.equal(g.stage, 'bridge'); assert(g.flags.committed);
assert.equal(g.enemies.filter(e => e.type === 'archer').length, 0, 'Burning supplies must remove the real bridge archer formation'); assert(!g.blocking(1100, 900)); assert.equal(g.civilians.length, 4);
clear(g); use(g, 'zhangheGate'); g.chooseRoute('bossStart:zhanghe'); assert.equal(g.activeBoss, 'zhanghe'); assert(!g.squadActive()); const zhanghe = g.boss;
g.damageEnemy(zhanghe, zhanghe.maxHp * .51); tick(g, .02); assert(zhanghe.phase2); assert(zhanghe.phaseTime > 0); tick(g, 1.4);
const patterns = new Set(); for (let i = 0; i < 8; i++) { zhanghe.sequence = []; g.startEnemyAction(zhanghe, g.player); patterns.add(zhanghe.action.def.name); zhanghe.action = null; }
assert([...patterns].some(name => name.includes('回身'))); assert([...patterns].some(name => name.includes('迟势')));
clear(g); g.chooseRoute('continue'); use(g, 'exit'); assert.equal(g.mode, 'ending'); assert.equal(g.result.people, 3); assert(g.result.mother && g.result.supplies); assert.match(g.result.title, /母子同归/);
// A main-only run and a return-for-healer run must both remain playable.
g = fresh(); clear(g); use(g, 'toVillage'); clear(g); use(g, 'toTemple'); clear(g); use(g, 'xiahouGate'); g.chooseRoute('bossStart:xiahou'); clear(g); g.chooseRoute('continue'); use(g, 'toHouse'); clear(g); use(g, 'adou'); g.chooseRoute('findHealer'); assert.equal(g.getMission().target.id, 'backTemple');
use(g, 'backTemple'); assert.equal(g.getMission().target.id, 'shortcut'); use(g, 'shortcut'); assert.equal(g.getMission().target.id, 'civilians'); use(g, 'civilians'); g.chooseRoute('continue'); assert(g.flags.healer); use(g, 'toTemple'); use(g, 'toHouse'); use(g, 'adou'); g.chooseRoute('leaveMother'); use(g, 'toFork'); clear(g, 'f1'); use(g, 'toBridge'); g.chooseRoute('commit'); assert.equal(g.enemies.filter(e => e.type === 'archer').length, 2); assert(g.blocking(1100, 900)); clear(g); use(g, 'zhangheGate'); g.chooseRoute('bossStart:zhanghe'); clear(g); g.chooseRoute('continue'); use(g, 'exit'); assert(g.result.won && !g.result.mother && !g.result.supplies);
// Snapshots preserve progress, replay only the interrupted encounter, and reject bad data.
g = fresh(); clear(g); use(g, 'toVillage'); clear(g); const saved = JSON.parse(JSON.stringify(g.snapshot())); assert(Campaign.validSnapshot(saved)); const restored = new Campaign(); assert(restored.restore(saved)); assert.equal(restored.stage, 'village'); assert.equal(restored.enemies.length, 0); assert.equal(restored.kills, g.kills);
assert(!restored.restore({ ...saved, version: 7 })); assert(!restored.restore({ ...saved, checkpoint: { ...saved.checkpoint, x: 1e8 } }));
g = fresh(); g.enterStage('temple'); clear(g); use(g, 'xiahouGate'); g.chooseRoute('bossStart:xiahou'); const bossSave = JSON.parse(JSON.stringify(g.snapshot())); assert(new Campaign().restore(bossSave)); const resumedBoss = new Campaign(); resumedBoss.restore(bossSave); assert.equal(resumedBoss.activeBoss, 'xiahou'); assert.equal(resumedBoss.enemies.filter(e => e.hp > 0).length, 1);
g = fresh(); g.enterStage('village'); g.rocks = []; g.huts = [{ x: 800, y: 550, w: 180, h: 150 }]; const escort = { x: 580, y: 550, r: 12, moving: false }; const path = g.findPath(escort.x, escort.y, 1040, 550, 12); assert(path.length); assert(path.every(p => !g.blocking(p.x, p.y, 12)));
for (let i = 0; i < 700; i++) { g.time += .02; g.navigate(escort, 1040, 550, 180, .02); } assert(Math.hypot(escort.x - 1040, escort.y - 550) < 50, 'Escorts must go around hut corners');
g = fresh(); g.enterStage('bridge'); const walker = { x: 930, y: 420, r: 12 }; const bridgePath = g.findPath(walker.x, walker.y, 1270, 130, 12); assert(bridgePath.length); assert(bridgePath.filter(p => p.y < 285).every(p => p.x > 1170 && p.x < 1370));
// Lingering artwork may never extend the damaging frames or survive a region change.
g = fresh(); g.enemies = []; g.allies = []; g.rocks = []; g.huts = [];
g.player.dir = 0; assert(g.heavy()); tick(g, .12); assert(!g.effects.some(e => e.type === 'slash'));
tick(g, .28); assert(g.effects.some(e => e.type === 'slash'), 'The visual follow-through should still be visible');
e = g.spawnEnemy('sword', g.player.x + 70, g.player.y); e.cooldown = 99; const lateHp = e.hp;
tick(g, .17); assert.equal(e.hp, lateHp, 'Entering a lingering trail must not take damage');
g.player.action = null; assert(g.dash(1, 0)); tick(g, .1); assert(g.effects.some(e => e.type === 'dashGhost'));
tick(g, .6); assert(!g.effects.some(e => e.type === 'dashGhost'), 'Dash echoes must expire');
for (let i = 0; i < 360; i++) { if (i % 36 === 0) g.dash(0, 1); g.step(.02, { attack: true, aim: 0 }); assert(g.effects.length < 100, 'Effects must stay bounded during sustained inputs'); }
g.effects.push({ type: 'cast', life: 1 }); g.hitStop = .05; g.enterStage('village'); assert.equal(g.effects.length, 0); assert.equal(g.hitStop, 0);
// A short deliberate press near recovery is consumed once; early or stale inputs are discarded.
const empty = () => { const c = fresh(); c.enemies = []; c.allies = []; c.rocks = []; c.huts = []; c.props = []; return c; };
g = empty(); assert(g.requestAction('attack', { aim: 0 })); assert(!g.requestAction('attack', { aim: 0 }), 'Presses far from recovery may not queue an attack');
tick(g, .34); assert(g.requestAction('attack', { aim: 0 })); assert(g.actionBuffer); tick(g, .1); assert.equal(g.player.action.key, 'thrust2'); assert.equal(g.actionBuffer, null);
tick(g, .7); assert.equal(g.player.action, null); assert.equal(g.player.combo, 2, 'A released buffered press may not repeat');
g = empty(); g.attack(0); tick(g, .34); g.requestAction('attack', { aim: 0 }); g.player.action.t -= .2; tick(g, .3); assert.equal(g.actionBuffer, null); assert.equal(g.player.combo, 1, 'An expired input may not execute after a longer interruption');
g = empty(); g.player.dashCd = .1; assert(g.requestAction('dash', { x: 0, y: 1 })); tick(g, .12); assert(g.player.dashTime > 0); assert.equal(g.player.dashDir, Math.PI / 2); assert.equal(g.actionBuffer, null); tick(g, .5); assert.equal(g.player.dashTime, 0);
g = empty(); g.attack(0); tick(g, .34); g.requestAction('attack'); g.enterStage('village'); assert.equal(g.actionBuffer, null); assert.equal(g.player.combo, 0);
g = empty(); g.player.qi = 0; assert(!g.requestAction('dash')); assert.equal(g.actionBuffer, null); g.mode = 'paused'; assert(!g.requestAction('attack'));
// Keyboard combos keep a living target; explicit mouse aim still overrides it.
g = empty(); const held = g.spawnEnemy('spear', g.player.x + 95, g.player.y); held.cooldown = 99;
const other = g.spawnEnemy('spear', g.player.x + 170, g.player.y + 80); other.cooldown = 99;
g.attack(); tick(g, .44); other.x = g.player.x - 45; other.y = g.player.y;
assert(g.attack()); assert.equal(g.player.comboTarget, held.id); assert(Math.abs(g.player.action.dir) < .05); tick(g, .5);
assert(g.attack(Math.PI)); assert.equal(g.player.comboTarget, null); assert.equal(g.player.action.dir, Math.PI);
// The warning covers a lunge's entire path; movement integrates the active interval exactly.
for (const dt of [.02, .04]) {
  g = empty(); g.player.x = 850; g.player.y = 550; g.player.invincible = 0;
  e = g.spawnEnemy('boss', 500, 550, 'extra', 'zhanghe');
  e.action = g.newAction('enemy', { name: '冲枪', windup: .11, active: .23, recovery: .5, range: 195, arc: .45, lunge: 160, damage: 32 }, 0);
  const warning = enemyThreat(e, g.player.r); assert.equal(warning.radius + warning.travel, 371); assert(!attackHits(e, g.player, e.action.def, 0));
  for (let t = 0; t < .4; t += dt) g.updateEnemyAction(e, dt, g.player);
  assert(Math.abs(e.x - 660) < 1e-6, 'Lunge distance must not depend on frame size'); assert.equal(g.player.hp, g.player.maxHp - 32); assert.equal(e.action.hits.size, 1);
  assert(enemyThreat(e).opening); e.sequence = [{}]; assert(!enemyThreat(e).opening, 'A gap inside a combo is not a full counter opening');
}
g = empty(); g.player.x = 872; g.player.y = 550; g.player.invincible = 0; e = g.spawnEnemy('boss', 500, 550, 'extra', 'zhanghe');
e.action = g.newAction('enemy', { windup: .11, active: .23, recovery: .5, range: 195, arc: .45, lunge: 160, damage: 32 }, 0);
for (let i = 0; i < 10; i++) g.updateEnemyAction(e, .04, g.player); assert.equal(g.player.hp, g.player.maxHp, 'Standing beyond the full telegraph must be safe');
g = empty(); e = g.spawnEnemy('shield', g.player.x + 70, g.player.y); g.startEnemyAction(e, g.player); g.damageEnemy(e, 42, 0, 0, 'player', 34, true);
assert.equal(e.action, null); assert(e.stunned >= .8); assert.equal(enemyThreat(e), null, 'A broken shield must cancel its pending strike');
// Contextual mountain lessons advance with encounters and never gate progress on a technique.
g = fresh(); assert.equal(g.getTutorial().step, 1); tick(g, .5, { x: 1 }); assert(g.learned.has('move')); clear(g, 'm1'); assert.equal(g.getTutorial().step, 2); clear(g, 'm2'); assert.equal(g.getTutorial().step, 3); clear(g, 'm3'); assert.equal(g.getTutorial(), null);
// Oil carts arm only on real weapon frames, pause with the world, explode once and reset on retry.
g = fresh(); g.enemies = []; g.allies = []; g.rocks = []; g.huts = []; const oil = g.props[0];
g.player.x = oil.x - 90; g.player.y = oil.y; g.player.invincible = 0;
e = g.spawnEnemy('shield', oil.x + 50, oil.y, 'm3'); e.cooldown = 99;
const oilArcher = g.spawnEnemy('archer', oil.x + 60, oil.y + 90, 'm3'); oilArcher.cooldown = 99;
e.speed = oilArcher.speed = 0;
g.attack(0); tick(g, .04); assert.equal(oil.fuse, null); tick(g, .08); assert(oil.fuse > 0);
g.mode = 'paused'; const fuse = oil.fuse; tick(g, 2); assert.equal(oil.fuse, fuse); g.mode = 'playing'; g.player.x = oil.x - 190;
tick(g, 1); assert(oil.spent); assert.equal(e.hp, e.maxHp - 85); assert(e.shieldBroken > 0); assert.equal(oilArcher.hp, 0); assert.equal(g.player.hp, g.player.maxHp); assert(g.learned.has('cart')); assert(!g.blocking(oil.x, oil.y));
const explodedHp = e.hp; tick(g, .3); assert.equal(e.hp, explodedHp);
g.defeat('test', 'test'); g.retry(); assert(!g.props[0].spent); assert.equal(g.props[0].fuse, null); assert(g.blocking(g.props[0].x, g.props[0].y));
g = fresh(); g.allies = []; g.enemies = []; g.player.invincible = 0; g.player.x = g.props[0].x - 90; g.player.y = g.props[0].y; g.props[0].fuse = .01; g.updateProps(.02); assert.equal(g.player.hp, g.player.maxHp - 28, 'The blast warning applies to the player too');
g = fresh(); const oldSave = JSON.parse(JSON.stringify(g.snapshot())); delete oldSave.learned; assert(Campaign.validSnapshot(oldSave)); assert(new Campaign().restore(oldSave));
assert(!Campaign.validSnapshot({ ...oldSave, learned: ['unknown'] }));
// Arrow hints and actual projectiles both stop at cover, including an intact cart.
g = empty(); g.huts = [{ x: 400, y: 500, w: 80, h: 100 }]; g.player.x = 485; g.player.y = 500; g.player.invincible = 0;
e = g.spawnEnemy('archer', 300, 508); const arrowHint = enemyThreat({ ...e, action: g.newAction('enemy', AttackDefinition.arrow, 0) });
assert.equal(arrowHint.radius, 840); assert(g.projectileReach(e, 0, arrowHint.radius) < 100);
g.projectiles = [{ id: 555, x: 300, y: 500, vx: 400, vy: 0, damage: 14, life: 2.1 }]; for (let i = 0; i < 40; i++) g.updateProjectiles(.04);
assert.equal(g.player.hp, g.player.maxHp); assert.equal(g.projectiles.length, 0);
const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8'); assert(!html.includes('GAME_SCRIPT')); assert(!html.includes('GAME_STYLES')); assert(!/<script[^>]+src=/.test(html));
assert.equal(html, build(), 'Published entry must match the current source build');
assert(html.length < 250000, 'Online entry should allow images to be cached independently');
const offlineHtml = build({ offline: true }); assert.equal((offlineHtml.match(/data:image\/png;base64,/g) || []).length, 6);
assert(!/"assets\/[^"\n]+\.png"/.test(offlineHtml), 'Offline game must retain every embedded character image');
assert(!/data-device|touchControls|joystick|切换手机|选择你的游玩方式/.test(html), 'The desktop build must not retain a mobile control flow');
const script = readFileSync(new URL('./game.js', import.meta.url), 'utf8'), shell = readFileSync(new URL('./shell.html', import.meta.url), 'utf8');
for (const [, id] of script.matchAll(/\$\('([^']+)'\)/g)) assert(shell.includes('id="' + id + '"'), 'Missing desktop UI element: ' + id);
assert.equal(Object.keys(StageDefinition).length, 6); assert(AttackDefinition.thrust3.recovery > AttackDefinition.thrust1.recovery);
console.log('PASS: input buffering and expiry, stable combo targeting, lunge telegraph and frame-independent damage, contextual onboarding, oil-cart tactics and retry, arrow cover, legacy saves, plus movement, medicine, precision dodge, shield break, 6 regions, both story routes, bosses, escort navigation and offline assets.');
