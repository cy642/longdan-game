(() => {
  'use strict';
  const { StageDefinition, AttackDefinition, W, H } = globalThis.LongdanDefinitions;
  const TAU = Math.PI * 2, clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const angleDiff = (a, b) => Math.atan2(Math.sin(a - b), Math.cos(a - b));
  const total = a => a.windup + a.active + a.recovery;
  const flagKeys = ['mountain', 'civilians', 'healer', 'temple', 'sword', 'adou', 'house', 'mother', 'motherDecision', 'supplies', 'elite', 'boss', 'committed'];
  const bossMoves = {
    xiahou: [
      [{ name: '双剑 · 起手', windup: .68, active: .13, recovery: .22, range: 142, arc: .8, damage: 22 }, { name: '双剑 · 第二剑', windup: .32, active: .13, recovery: 1.35, range: 152, arc: 1.1, damage: 24 }],
      [{ name: '蓄势重斩', windup: 1.14, active: .18, recovery: 1.5, range: 168, arc: .65, damage: 33, lunge: 55 }],
      [{ name: '转身横斩', windup: .85, active: .18, recovery: 1.4, range: 158, arc: 2.7, damage: 27 }],
    ],
    zhanghe: [
      [{ name: '三连突 · 一', windup: .7, active: .12, recovery: .2, range: 190, arc: .42, damage: 21 }, { name: '三连突 · 二', windup: .34, active: .12, recovery: .2, range: 200, arc: .42, damage: 23 }, { name: '三连突 · 三', windup: .42, active: .16, recovery: 1.45, range: 215, arc: .55, damage: 27 }],
      [{ name: '直线冲枪', windup: .96, active: .23, recovery: 1.55, range: 195, arc: .45, damage: 32, lunge: 160 }],
      [{ name: '长枪横扫', windup: 1.02, active: .18, recovery: 1.4, range: 198, arc: 2.45, damage: 29 }],
      [{ name: '回身枪', windup: .9, active: .17, recovery: .25, range: 198, arc: 2.45, damage: 25 }, { name: '回马反刺', windup: .45, active: .13, recovery: 1.4, range: 228, arc: .45, damage: 30 }],
      [{ name: '迟势追枪', windup: 1.18, active: .15, recovery: .27, range: 198, arc: .45, damage: 25, lunge: 90 }, { name: '追枪 · 二', windup: .5, active: .14, recovery: .24, range: 208, arc: .5, damage: 26 }, { name: '追枪 · 断势', windup: .68, active: .18, recovery: 1.5, range: 230, arc: .7, damage: 34 }],
    ],
  };
  class Campaign {
    constructor(difficulty = 'normal') { this.reset(difficulty); }
    random() { this.seed = (Math.imul(this.seed, 1664525) + 1013904223) >>> 0; return this.seed / 4294967296; }
    reset(difficulty = 'normal') {
      this.difficulty = difficulty === 'story' ? 'story' : 'normal'; this.seed = 82713; this.mode = 'menu';
      this.events = []; this.effects = []; this.projectiles = []; this.floaters = []; this.loot = []; this.history = [];
      this.flags = Object.fromEntries(flagKeys.map(k => [k, false])); this.cleared = new Set(); this.visited = new Set(); this.seen = new Set();
      this.time = 0; this.kills = 0; this.precisionCount = 0; this.nextId = 10; this.attackId = 1;
      this.screenShake = 0; this.hitStop = 0; this.command = 'follow'; this.rescue = null; this.activeBoss = null; this.boss = null;
      this.checkpoint = { stage: 'mountain', x: 190, y: 910, encounter: null }; this.selectedRoute = 'bridge';
      const maxHp = this.difficulty === 'story' ? 240 : 200;
      this.player = { id: 1, x: 190, y: 910, r: 16, hp: maxHp, maxHp, qi: 100, rage: 0, dir: -.6, speed: 177,
        attackCd: 0, attackTimer: 0, combo: 0, comboWindow: 0, heavyCd: 0, dashCd: 0, dashTime: 0, dashAge: 9,
        invincible: 0, hurtFlash: 0, dashDir: 0, potions: 3, healCd: 0, counterWindow: 0, action: null,
        moving: false, walkDistance: 0, footStep: 0, vx: 0, vy: 0, lastCombat: -20 };
      this.allies = Array.from({ length: 3 }, (_, i) => ({ id: i + 2, x: 130 + i * 26, y: 950, r: 12, hp: 140, maxHp: 140,
        dir: -.6, hurtFlash: 0, attackCd: 0, moving: false, walkDistance: 0, home: { x: 130 + i * 26, y: 950 } }));
      this.civilians = []; this.enterStage('mountain', [190, 910], false);
    }
    start(difficulty = this.difficulty) {
      this.reset(difficulty); this.mode = 'playing';
      this.dialog('长坂 · 记忆醒来', '战鼓将你唤醒。你成了赵子龙，醒在长坂溃军之间。\n\n你记得自己会带着阿斗独骑归来，也记得有人永远留在了这片火里。\n\n这一回，长枪在你手中。', [{ text: '握枪起身', detail: '先学会移动、三式连击和闪避。', route: 'continue' }], '赵云 · 心声');
    }
    say(text) { this.events.push({ kind: 'toast', text }); }
    record(text) { if (!this.history.includes(text)) this.history.push(text); }
    dialog(title, text, choices, speaker = '未来记忆') { this.mode = 'dialog'; this.events.push({ kind: 'dialog', title, text, choices, speaker }); }
    save() { this.events.push({ kind: 'save' }); }
    groupDone(id) { return !id || this.cleared.has(this.stage + ':' + id); }
    groupAlive(id) { return this.enemies.some(e => e.hp > 0 && (!id || e.group === id)); }
    roadDistance(x, y) {
      let best = Infinity;
      for (const line of this.definition.roads) for (let i = 1; i < line.length; i++) {
        const a = line[i - 1], b = line[i], dx = b[0] - a[0], dy = b[1] - a[1];
        const t = clamp(((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy), 0, 1);
        best = Math.min(best, Math.hypot(x - a[0] - t * dx, y - a[1] - t * dy));
      }
      return best;
    }
    enterStage(id, position = null, checkpoint = true) {
      this.stage = id; this.definition = StageDefinition[id]; this.visited.add(id);
      const point = position || this.definition.spawn; this.player.x = point[0]; this.player.y = point[1]; this.player.action = null;
      this.player.attackTimer = 0; this.player.dashTime = 0; this.player.moving = false; this.player.invincible = .7;
      this.objects = this.definition.objects.map(o => ({ ...o }));
      this.huts = this.definition.huts.map(([x, y, w, h, type]) => ({ x, y, w, h, type }));
      this.trees = []; this.rocks = []; this.seed = this.definition.seed;
      for (let i = 0; i < 150; i++) {
        const x = 45 + this.random() * (W - 90), y = 65 + this.random() * (H - 120);
        if (this.roadDistance(x, y) < 105 || this.objects.some(o => Math.hypot(x - o.x, y - o.y) < 140) ||
          this.huts.some(o => Math.hypot(x - o.x, y - o.y) < 140) || this.inArena({ x, y }, 80)) continue;
        this.trees.push({ x, y, size: 24 + this.random() * 19, shade: this.random(), seed: this.random() });
      }
      for (let i = 0; i < 24; i++) {
        const x = 85 + this.random() * (W - 170), y = 90 + this.random() * (H - 180);
        if (this.roadDistance(x, y) < 80 || this.objects.some(o => Math.hypot(x - o.x, y - o.y) < 120) || this.inArena({ x, y }, 40)) continue;
        this.rocks.push({ x, y, r: 12 + this.random() * 12 });
      }
      this.enemies = []; this.boss = null; this.activeBoss = null; this.rescue = null;
      this.effects = []; this.projectiles = []; this.loot = []; this.floaters = [];
      for (const group of this.definition.groups) {
        if (this.groupDone(group.id) || (group.unless && this.flags[group.unless])) continue;
        group.units.forEach(([type, x, y]) => this.spawnEnemy(type, x, y, group.id));
      }
      this.allies.forEach((a, i) => { a.x = this.player.x - 38 + i * 33; a.y = this.player.y + 42; a.hp = a.maxHp; a.home = { x: a.x, y: a.y }; a.moving = false; });
      this.civilians = [];
      if (id === 'bridge' && this.flags.civilians) for (let i = 0; i < 3; i++) this.civilians.push({ id: 1000 + i, x: point[0] - 45 + i * 25, y: point[1] + 60, r: 11, hp: 1000, maxHp: 1000, dir: -.7, moving: false, walkDistance: 0 });
      if (id === 'bridge' && this.flags.mother) this.civilians.push({ id: 1013, x: point[0] - 50, y: point[1] + 90, r: 14, hp: 1000, maxHp: 1000, dir: -.7, injured: true, moving: false, walkDistance: 0 });
      if (checkpoint) { this.checkpoint = { stage: id, x: this.player.x, y: this.player.y, encounter: null }; this.save(); }
      this.events.push({ kind: 'stage', stage: id });
      if (this.mode !== 'menu') this.say(this.definition.tutorial);
    }
    spawnEnemy(type, x, y, group = 'extra', bossId = null) {
      const hp = { sword: 72, spear: 91, archer: 58, shield: 115, elite: 285, boss: bossId === 'zhanghe' ? 1350 : 830 }[type];
      const health = hp * (this.difficulty === 'story' ? .84 : 1);
      const e = { id: this.nextId++, type, bossId, name: bossId === 'xiahou' ? '夏侯恩' : bossId === 'zhanghe' ? '张郃' : type === 'elite' ? '盾阵校尉' : '',
        x, y, r: type === 'boss' ? 22 : 14, hp: health, maxHp: health, dir: 1, speed: type === 'boss' ? 105 : type === 'archer' ? 84 : 100,
        group, homeX: x, homeY: y, action: null, sequence: [], attackCount: 0, attackDir: 0, windup: 0, windupMax: 1,
        cooldown: .5 + this.random(), stunned: 0, hurtFlash: 0, knockX: 0, knockY: 0, moving: false, alerted: false,
        stagger: 0, staggerMax: type === 'boss' ? 125 : type === 'elite' ? 90 : 65, staggerShield: 0, phase2: false, phaseTime: 0, deadTime: 0, shieldBroken: 0 };
      this.enemies.push(e); return e;
    }
    inArena(entity, margin = 0) { const a = this.definition?.arena; return a && Math.abs(entity.x - a.x) < a.rx + margin && Math.abs(entity.y - a.y) < a.ry + margin; }
    blocking(x, y, radius = 14) {
      if (x < radius + 18 || y < radius + 25 || x > W - radius - 18 || y > H - radius - 25) return true;
      if (this.stage === 'bridge' && y < 285 && (x < 1170 + radius || x > 1370 - radius)) return true;
      if (this.stage === 'bridge' && !this.flags.supplies && x > 1070 - radius && x < 1150 + radius && y > 725 - radius) return true;
      return this.huts.some(h => x > h.x - h.w / 2 - radius && x < h.x + h.w / 2 + radius && y > h.y - h.h / 2 + 15 - radius && y < h.y + h.h / 2 + radius) ||
        this.rocks.some(r => Math.hypot(x - r.x, y - r.y) < r.r * .7 + radius);
    }
    move(a, dx, dy) {
      const beforeX = a.x, beforeY = a.y, radius = a.r || 14;
      if (!this.blocking(a.x + dx, a.y, radius)) a.x += dx;
      if (!this.blocking(a.x, a.y + dy, radius)) a.y += dy;
      if (this.activeBoss && (a === this.player || a === this.boss)) {
        const b = this.definition.arena; a.x = clamp(a.x, b.x - b.rx + 22, b.x + b.rx - 22); a.y = clamp(a.y, b.y - b.ry + 25, b.y + b.ry - 25);
      }
      const travelled = Math.hypot(a.x - beforeX, a.y - beforeY);
      a.walkDistance = (a.walkDistance || 0) + travelled; a.moving = travelled > .1;
      return travelled;
    }
    // Deterministic grid navigation prevents escorts from pushing endlessly into a hut.
    navigate(a, tx, ty, speed, dt) {
      if (Math.hypot(tx - a.x, ty - a.y) < 18) { a.moving = false; return; }
      if (this.stage === 'bridge' && ty < 285 && a.y > 285 && (a.x < 1190 || a.x > 1350)) { tx = 1270; ty = 330; }
      const nowCell = `${Math.round(tx / 40)},${Math.round(ty / 40)}`;
      if (!a.path || a.pathTarget !== nowCell || a.pathAge <= this.time) {
        a.path = this.findPath(a.x, a.y, tx, ty, a.r || 12); a.pathTarget = nowCell; a.pathAge = this.time + .65;
      }
      let point = a.path?.[0] || { x: tx, y: ty };
      if (Math.hypot(point.x - a.x, point.y - a.y) < 25 && a.path?.length) { a.path.shift(); point = a.path[0] || { x: tx, y: ty }; }
      a.dir = Math.atan2(point.y - a.y, point.x - a.x); this.move(a, Math.cos(a.dir) * speed * dt, Math.sin(a.dir) * speed * dt);
    }
    findPath(sx, sy, tx, ty, radius) {
      const size = 40, cols = W / size, rows = Math.ceil(H / size), start = [clamp(Math.floor(sx / size), 0, cols - 1), clamp(Math.floor(sy / size), 0, rows - 1)], end = [clamp(Math.floor(tx / size), 0, cols - 1), clamp(Math.floor(ty / size), 0, rows - 1)];
      const key = (x, y) => y * cols + x, queue = [start], parent = new Map([[key(...start), -1]]);
      let found = null;
      for (let i = 0; i < queue.length && i < 1100; i++) {
        const [x, y] = queue[i]; if (Math.abs(x - end[0]) + Math.abs(y - end[1]) <= 1) { found = key(x, y); break; }
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = x + dx, ny = y + dy, id = key(nx, ny);
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows || parent.has(id) || this.blocking(nx * size + 20, ny * size + 20, radius + 3)) continue;
          parent.set(id, key(x, y)); queue.push([nx, ny]);
        }
      }
      if (found == null) return [];
      const path = []; while (parent.get(found) !== -1) { path.push({ x: found % cols * size + 20, y: Math.floor(found / cols) * size + 20 }); found = parent.get(found); }
      return path.reverse();
    }
    nearbyEnemy(a, radius, friends = false) {
      let best = radius, target = null;
      for (const other of friends ? [this.player, ...(this.squadActive() ? this.allies : [])] : this.enemies) {
        if (other.hp <= 0 || (!friends && this.activeBoss && other !== this.boss)) continue;
        const d = dist(a, other); if (d < best) { target = other; best = d; }
      }
      return target;
    }
    burst(x, y, color, count = 10) { for (let i = 0; i < count; i++) { const angle = this.random() * TAU, s = 35 + this.random() * 85; this.effects.push({ type: 'particle', x, y, vx: Math.cos(angle) * s, vy: Math.sin(angle) * s, color, size: 1 + this.random() * 3, life: .35, maxLife: .35 }); } }
    floater(x, y, text, color = '#f7e1a4') { this.floaters.push({ x, y: y - 33, text, color, life: .85 }); }
    damageEnemy(e, damage, dir = 0, knock = 0, source = 'player', stagger = 0, breakShield = false) {
      if (e.hp <= 0 || e.phaseTime > 0 || (this.activeBoss && e !== this.boss)) return;
      const armored = (e.type === 'shield' || e.type === 'elite') && e.shieldBroken <= 0;
      if (armored && Math.abs(angleDiff(dir + Math.PI, e.dir)) < 1.15 && !breakShield) { damage *= .24; stagger *= .45; this.floater(e.x, e.y, '盾挡', '#b9cdd4'); }
      if (breakShield && armored) { e.shieldBroken = 2.8; e.stunned = .8; this.floater(e.x, e.y, '破盾'); }
      const floor = source === 'ally' ? e.maxHp * .22 : 0;
      const actual = Math.min(Math.max(0, e.hp - floor), damage); if (actual <= 0) return;
      e.hp = Math.max(floor, e.hp - actual); e.hurtFlash = .16; e.alerted = true;
      if (source === 'player') { this.player.rage = Math.min(100, this.player.rage + 4); this.player.lastCombat = this.time; }
      if (e.type !== 'boss') { e.knockX += Math.cos(dir) * knock; e.knockY += Math.sin(dir) * knock; if (source === 'player' && e.type !== 'elite') { e.stunned = .12; e.action = null; } }
      if (e.staggerShield <= 0) {
        e.stagger += stagger;
        if (e.stagger >= e.staggerMax) { e.stagger = 0; e.stunned = e.type === 'boss' ? 2.1 : 1.3; e.staggerShield = 4.4; e.action = null; e.sequence = []; e.cooldown = 1.2; this.floater(e.x, e.y, '破势 · 反击'); this.events.push({ kind: 'sound', sound: 'break' }); }
      }
      this.floater(e.x, e.y, String(Math.round(actual)), source === 'ally' ? '#a7c6b0' : '#fff0bb');
      if (e.hp <= 0) {
        this.kills++; this.player.rage = Math.min(100, this.player.rage + 8); e.action = null; e.sequence = []; this.burst(e.x, e.y, '#d5bb83', 12);
        if (e.type === 'boss') this.bossDefeated(e);
        else if (e.type === 'elite') { this.flags.elite = true; this.record('粮营盾阵校尉败退，粮草失去最后的守卫。'); this.say('盾阵已破，靠近粮草点火。'); this.save(); }
        else if (this.random() < .22) this.loot.push({ x: e.x, y: e.y, life: 35 });
        this.events.push({ kind: 'sound', sound: 'kill' });
        this.checkGroups();
      } else this.events.push({ kind: 'sound', sound: 'hit' });
    }
    damageFriend(target, damage, attackId = null) {
      if (target.hp <= 0) return false;
      const p = this.player;
      if (target === p && p.invincible > 0) {
        const window = this.difficulty === 'story' ? .18 : .12;
        if (attackId != null && p.dashTime > 0 && p.dashAge <= window && p.lastPrecisionAttack !== attackId) {
          p.lastPrecisionAttack = attackId; p.counterWindow = 1.2; p.qi = Math.min(100, p.qi + 12); p.rage = Math.min(100, p.rage + 8); this.precisionCount++;
          this.floater(p.x, p.y, '精准闪避 · 回马枪', '#b6e9ee'); this.effects.push({ type: 'ring', x: p.x, y: p.y, radius: 47, color: '#ade1e4', life: .38, maxLife: .38 }); this.events.push({ kind: 'sound', sound: 'perfect' });
        }
        return false;
      }
      damage *= this.difficulty === 'story' ? .64 : 1;
      target.hp = Math.max(0, target.hp - damage); target.hurtFlash = .22;
      this.floater(target.x, target.y, '-' + Math.round(damage), '#efa18a');
      if (target === p) {
        p.invincible = .26; p.lastCombat = this.time; this.screenShake = 4;
        if (p.action?.key === 'heal') { p.action = null; p.attackTimer = 0; this.say('服药被打断。拉开距离再使用行军药。'); }
        this.events.push({ kind: 'sound', sound: 'hurt' });
        if (p.hp <= 0) this.defeat('长枪落尘', '记住敌将的收招，这一回还能重新来过。');
      }
      return true;
    }
    newAction(key, definition, dir) { return { id: this.attackId++, key, def: definition, t: 0, dir, hits: new Set(), fired: false }; }
    attack(aim) {
      const p = this.player; if (this.mode !== 'playing' || p.action || p.dashTime > 0 || p.attackCd > 0) return false;
      const target = this.nearbyEnemy(p, 205);
      if (Number.isFinite(aim)) p.dir = aim; else if (target) p.dir = Math.atan2(target.y - p.y, target.x - p.x);
      p.combo = p.comboWindow > 0 ? p.combo % 3 + 1 : 1;
      const key = p.counterWindow > 0 ? 'counter' : 'thrust' + p.combo; p.counterWindow = 0;
      p.action = this.newAction(key, AttackDefinition[key], p.dir); p.comboWindow = 1.2; p.attackPose = 'normal'; return true;
    }
    heavy() {
      const p = this.player; if (this.mode !== 'playing' || p.action || p.dashTime > 0 || p.heavyCd > 0) return false;
      if (p.qi < 30) { this.say('气力不足，游走回气。'); return false; }
      p.qi -= 30; p.heavyCd = 3.6; p.action = this.newAction('sweep', AttackDefinition.sweep, p.dir); p.attackPose = 'heavy'; return true;
    }
    dash(dx = 0, dy = 0) {
      const p = this.player; if (this.mode !== 'playing' || p.dashCd > 0 || p.qi < 16 || p.dashTime > 0) return false;
      p.action = null; p.attackTimer = 0; p.attackCd = 0; p.qi -= 16; p.dashCd = .61; p.dashTime = .22; p.dashAge = 0; p.invincible = .24;
      p.dashDir = Math.hypot(dx, dy) > .1 ? Math.atan2(dy, dx) : p.dir;
      this.events.push({ kind: 'sound', sound: 'dash' }); return true;
    }
    ultimate() {
      const p = this.player; if (this.mode !== 'playing' || p.action || p.dashTime > 0) return false;
      if (!this.flags.sword) { this.say('击败夏侯恩，才能夺得青釭剑。'); return false; }
      if (p.rage < 100) { this.say('命中敌人积累战意，满时可使青釭断势。'); return false; }
      p.rage = 0; p.action = this.newAction('sword', AttackDefinition.sword, p.dir); p.attackPose = 'heavy'; return true;
    }
    heal() {
      const p = this.player; if (this.mode !== 'playing' || p.action || p.dashTime > 0 || p.healCd > 0) return false;
      if (p.hp >= p.maxHp) { this.say('体力充足，先留住行军药。'); return false; }
      if (p.potions <= 0) { this.say('药已用尽，在营火处补满三份。'); return false; }
      p.potions--; p.healCd = 1.4; p.action = this.newAction('heal', AttackDefinition.heal, p.dir); return true;
    }
    updatePlayerAction(dt) {
      const p = this.player, a = p.action; if (!a) { p.attackTimer = 0; return; }
      a.t += dt; p.dir = a.dir; p.attackTimer = Math.max(0, total(a.def) - a.t);
      if (a.t >= a.def.windup && a.t < a.def.windup + a.def.active) {
        if (!a.fired) {
          a.fired = true;
          if (a.key === 'heal') { p.hp = Math.min(p.maxHp, p.hp + 85); this.events.push({ kind: 'sound', sound: 'heal' }); this.effects.push({ type: 'ring', x: p.x, y: p.y, radius: 50, color: '#a7d5a6', life: .55, maxLife: .55 }); }
          else { this.effects.push({ type: 'slash', x: p.x, y: p.y, dir: a.dir, radius: a.def.range, arc: a.def.arc, heavy: ['sweep', 'sword', 'thrust3'].includes(a.key), life: a.def.active + .09, maxLife: a.def.active + .09 }); this.events.push({ kind: 'sound', sound: a.key === 'sword' ? 'ultimate' : a.key === 'sweep' || a.key === 'thrust3' ? 'heavy' : 'swing' }); }
        }
        if (a.key !== 'heal') for (const e of this.enemies) {
          if (e.hp <= 0 || a.hits.has(e.id) || dist(p, e) > a.def.range + e.r || Math.abs(angleDiff(Math.atan2(e.y - p.y, e.x - p.x), a.dir)) > a.def.arc) continue;
          a.hits.add(e.id); this.damageEnemy(e, a.def.damage, a.dir, a.key === 'sweep' ? 200 : 50, 'player', a.def.stagger, ['sweep', 'sword'].includes(a.key)); this.screenShake = a.key === 'thrust3' ? 3 : 1.8;
        }
      }
      if (a.t >= total(a.def)) { p.action = null; p.attackTimer = 0; }
    }
    checkGroups() {
      for (const group of this.definition.groups) {
        if (!this.groupDone(group.id) && !this.groupAlive(group.id)) { this.cleared.add(this.stage + ':' + group.id); this.save(); }
      }
      if (this.stage === 'mountain' && this.definition.groups.every(g => this.groupDone(g.id)) && !this.flags.mountain) {
        this.flags.mountain = true; this.say('山道已清。到前方营火补药，再进荒村。'); this.save();
      }
      if (this.squadActive() && !this.groupAlive() && !this.rescue) this.allies.forEach(a => { a.hp = a.maxHp; });
    }
    squadActive() { return !this.activeBoss && (this.rescue != null || this.stage === 'bridge' && !this.flags.boss); }
    setCommand(command) {
      if (this.mode !== 'playing' || !['follow', 'hold', 'charge'].includes(command)) return;
      this.command = command; this.allies.forEach(a => { a.home = { x: a.x, y: a.y }; a.path = null; });
      this.events.push({ kind: 'command', command });
      if (!this.squadActive()) this.say('随军待命。救援与桥头突围时，他们会掩护你。');
    }
    nearestObject() {
      if (this.activeBoss || this.rescue || this.mode !== 'playing') return null;
      let target = null, best = 92;
      for (const o of this.objects) {
        if (o.id === 'civilians' && this.flags.civilians || o.id === 'xiahouGate' && this.flags.temple || o.id === 'zhangheGate' && this.flags.boss || o.id === 'adou' && this.flags.house && (this.flags.mother || this.flags.committed)) continue;
        const d = dist(this.player, o); if (d < best) { best = d; target = o; }
      }
      return target;
    }
    blockedObject(o) {
      if (o.need && !this.flags[o.need]) return true;
      if (o.group && this.groupAlive(o.group)) return true;
      if (o.id === 'toTemple' && this.enemies.some(e => e.hp > 0 && e.group !== 'vRescue')) return true;
      if (o.id === 'zhangheGate' && this.groupAlive()) return true;
      return false;
    }
    interactionText(o) {
      if (!o) return '';
      if (o.kind === 'camp') return this.enemies.some(e => e.hp > 0 && e.alerted && dist(e, o) < 350) ? '先击退附近敌军，再休整' : '休整 · 补满体力与三份行军药';
      if (this.blockedObject(o)) return o.need && !this.flags[o.need] ? { mountain: '先清开山道', temple: '先击败夏侯恩', house: '先安置阿斗与糜夫人', boss: '先击退张郃' }[o.need] : '先击退附近守军 · ' + o.label;
      if (o.id === 'supplies') return this.flags.supplies ? '粮营已毁 · 北桥弓阵撤走' : this.flags.elite ? '点燃粮草 · 改变北桥部署' : '挑战盾阵校尉';
      if (o.id === 'adou' && this.flags.adou) return this.flags.healer ? '召来医者，救下糜夫人' : '糜夫人仍在井边 · 去荒村寻找医者';
      return o.label;
    }
    interact() {
      if (this.mode !== 'playing') return false;
      const o = this.nearestObject(); if (!o) return false;
      if (o.kind === 'camp') {
        if (this.enemies.some(e => e.hp > 0 && e.alerted && dist(e, o) < 350)) { this.say(this.interactionText(o)); return false; }
        Object.assign(this.player, { hp: this.player.maxHp, qi: 100, potions: 3, action: null, invincible: .5 });
        this.allies.forEach(a => { a.hp = a.maxHp; }); this.checkpoint = { stage: this.stage, x: o.x, y: o.y + 35, encounter: null };
        this.say('营火已记住你的来路。体力、气力、行军药已补满。'); this.events.push({ kind: 'sound', sound: 'heal' }); this.save(); return true;
      }
      if (this.blockedObject(o)) { this.say(this.interactionText(o)); return false; }
      if (o.kind === 'exit') {
        if (o.to === 'bridge' && !this.flags.committed) {
          this.dialog('渡桥前 · 最后的回望', `前往北桥后，曹军会截断返回旧宅的路。\n\n${this.flags.mother ? '糜夫人已安置妥当。' : '糜夫人仍留在井畔，你还可以回去尝试救她。'}\n${this.flags.supplies ? '粮营已毁，桥头弓阵将被撤走。' : '曹军粮草尚在，桥头弓阵仍会阻拦队伍。'}`, [
            { text: '整军渡桥', detail: '随军掩护突围，赵云断后单挑张郃。', route: 'commit' },
            { text: '再回头看一眼', detail: '留在粮道，可以补完救援和焚粮。', route: 'continue' },
          ], '赵云 · 军令');
        } else {
          let position = null;
          if (o.id === 'shortcut') position = [1325, 215];
          else if (o.id.startsWith('back')) {
            const target = StageDefinition[o.to].objects.find(v => v.to === this.stage && !v.id.startsWith('back'));
            if (target) position = [target.x - 55, target.y + 70];
          }
          this.enterStage(o.to, position);
        }
        return true;
      }
      if (o.id === 'civilians') {
        this.flags.civilians = this.flags.healer = true; this.selectedRoute = 'bridge';
        this.record('荒村医者与三名百姓获救，随军护送他们先行撤往北桥。');
        this.dialog('荒村 · 悬壶未尽', '医者：将军若还要找人，我随你走。伤重之人，也不该只剩下等死。\n\n赵云：三位乡亲随军先走。医者，待我寻到夫人，再请你救命。', [{ text: '请医者随行', detail: '解锁井畔营救糜夫人的机会。百姓由随军安置。', route: 'continue' }], '医者');
        this.save(); return true;
      }
      if (o.kind === 'boss') { this.prepareBoss(o.id === 'xiahouGate' ? 'xiahou' : 'zhanghe'); return true; }
      if (o.id === 'adou') {
        this.flags.adou = true;
        this.dialog('井畔 · 这一次不必赴死', `你抱起阿斗，糜夫人倚在井边。\n\n糜夫人：子龙，带着孩子走吧，莫让我们误了你。\n\n你记得，记忆中的她没有走出长坂。${this.flags.healer ? '\n身后的医者已经赶来：让我试试，尚有一线生机。' : '\n若能找到荒村医者，或许还能救她。'}`, [
          { text: this.flags.healer ? '护住井畔，请医者救人' : '回荒村寻找医者', detail: this.flags.healer ? '两波追兵将到，发布军令保护医者。' : '走破庙侧门可快速返回荒村，回来后再救夫人。', route: this.flags.healer ? 'rescue' : 'findHealer' },
          { text: '先护阿斗撤离', detail: '完成主线，渡桥前仍可以回头。', route: 'leaveMother' },
        ], '糜夫人'); this.save(); return true;
      }
      if (o.id === 'supplies') {
        if (this.flags.supplies) return false;
        if (!this.flags.elite) {
          if (!this.enemies.some(e => e.type === 'elite' && e.hp > 0)) { this.boss = this.spawnEnemy('elite', 1280, 765, 'elite'); this.say('盾阵校尉：粮营重地，休想再进！横扫能破盾，绕后也能出枪。'); }
          return true;
        }
        this.flags.supplies = true; this.record('曹军粮营被焚，北桥弓阵撤回救火，侧道得以打开。');
        this.say('粮营起火！北桥弓阵撤走，侧道已开。'); this.events.push({ kind: 'sound', sound: 'victory' }); this.save(); return true;
      }
      if (o.kind === 'finish') { this.finish(); return true; }
      return false;
    }
    chooseRoute(route) {
      if (this.mode !== 'dialog') return;
      this.mode = 'playing';
      if (route === 'commit') { this.flags.committed = true; this.enterStage('bridge'); }
      else if (route === 'rescue') this.startRescue();
      else if (route === 'findHealer') { this.selectedRoute = 'healer'; this.say('沿原路回破庙，从侧门返回荒村。救出医者后再来井畔。'); }
      else if (route === 'leaveMother') { this.flags.house = this.flags.motherDecision = true; this.selectedRoute = 'bridge'; this.record('你先护住阿斗，井畔仍留下一个未尽的承诺。'); }
      else if (route.startsWith('bossStart:')) this.beginBoss(route.split(':')[1]);
      this.save();
    }
    prepareBoss(id) {
      this.checkpoint = { stage: this.stage, x: this.player.x, y: this.player.y, encounter: id };
      if (this.seen.has(id)) { this.beginBoss(id); return; }
      this.seen.add(id);
      const title = id === 'xiahou' ? '破庙 · 青釭在谁手' : '北桥 · 谁来断后';
      const text = id === 'xiahou' ? '夏侯恩：这柄青釭，专斩来将。\n\n赵云：剑是好剑。只是今日，我要借它开一条生路。\n\n随军守在庙外。快剑有第二招，重斩则须晚一点避。' : `随军接过 wounded 的担架，百姓先上木桥。\n\n张郃：赵子龙！你能救几人，便能挡几枪？\n\n赵云：他们走得多远，我便守到多远。${this.flags.supplies ? '\n张郃：粮营的火……竟也是你！' : ''}\n\n随军撤往桥北，赵云独自断后。`;
      this.dialog(title, text.replace('wounded', this.flags.mother ? '糜夫人' : '伤者'), [{ text: '入阵', detail: '单挑中随军负责护送，留意敌将连招结束后的破绽。', route: 'bossStart:' + id }], id === 'xiahou' ? '夏侯恩' : '张郃');
      this.save();
    }
    beginBoss(id) {
      this.activeBoss = id; this.enemies = this.enemies.filter(e => e.hp <= 0); this.projectiles = [];
      const arena = this.definition.arena;
      this.player.x = arena.x - 145; this.player.y = arena.y + 90; this.player.action = null; this.player.invincible = .8;
      this.boss = this.spawnEnemy('boss', arena.x + 90, arena.y - 35, 'boss', id); this.boss.cooldown = 1.1;
      this.allies.forEach((a, i) => { a.x = id === 'zhanghe' ? 1270 + (i - 1) * 22 : 400 + i * 26; a.y = id === 'zhanghe' ? 165 + i * 20 : 850; });
      if (id === 'zhanghe') this.civilians.forEach((a, i) => { a.x = 1270 + (i % 2 ? 20 : -20); a.y = 270 - i * 28; });
      this.say(id === 'xiahou' ? '夏侯恩 · 单挑开始。等第二剑收招，再出枪。' : '张郃 · 三连突后才有长破绽。'); this.save();
    }
    bossDefeated(e) {
      this.activeBoss = null; this.projectiles = []; this.player.action = null; this.player.invincible = 1;
      this.allies.forEach(a => { a.hp = a.maxHp; });
      if (e.bossId === 'xiahou') {
        this.flags.temple = this.flags.sword = true; this.player.rage = 100;
        this.checkpoint = { stage: 'temple', x: 1090, y: 550, encounter: null };
        this.record('夏侯恩败于破庙，赵云夺得青釭剑，荒村侧门随之打开。');
        this.dialog('青釭入手 · 路已不同', '你收起青釭剑，重新握紧长枪。\n\n新招「青釭断势」已习得：战意满时，拔剑打出高破势一击。\n\n破庙侧门已开，回荒村不必再走长路。井畔还有人在等你。', [{ text: '持剑前行', detail: 'R 或手机青釭键发动；接下来前往井畔旧宅。', route: 'continue' }], '赵云');
      } else {
        this.flags.boss = true; this.checkpoint = { stage: 'bridge', x: 1100, y: 340, encounter: null };
        this.record('北桥枪阵被破，张郃退去，赵云守住了队伍的撤离。');
        this.dialog('张郃退兵 · 生路在前', '张郃收枪：今日一战，来日再讨。\n\n木桥上，随军挥旗示意。阿斗平安，前方就是刘备的队伍。\n\n沿木桥向北，在桥头会合。', [{ text: '收枪渡桥', detail: '你这一回救下的人，都在桥北等你。', route: 'continue' }], '张郃');
      }
      this.events.push({ kind: 'sound', sound: 'victory' }); this.save();
    }
    startRescue() {
      if (!this.flags.healer || this.flags.mother) return;
      this.flags.adou = true; this.flags.house = false;
      this.checkpoint = { stage: 'house', x: 1030, y: 570, encounter: 'rescue' };
      this.rescue = { wave: 1, progress: 0, gap: 0, healer: { id: 7, x: 1090, y: 465, r: 12, hp: 100, maxHp: 100, dir: 0, hurtFlash: 0 } };
      this.command = 'hold'; this.allies.forEach((a, i) => { a.hp = a.maxHp; a.x = 1000 + i * 75; a.y = 530; a.home = { x: a.x, y: a.y }; a.path = null; });
      this.spawnRescueWave(); this.say('保护医者！两波追兵会从井畔两侧赶来。随军守点，你来切断敌军。'); this.events.push({ kind: 'command', command: 'hold' }); this.save();
    }
    spawnRescueWave() {
      const n = this.rescue.wave;
      [['sword', 765, 505], ['spear', 1330, 550], [n === 1 ? 'sword' : 'archer', 1170, 705]].forEach(([type, x, y]) => { const e = this.spawnEnemy(type, x, y, 'rescue' + n); e.alerted = true; });
    }
    updateRescue(dt) {
      const r = this.rescue; if (!r) return;
      r.progress = Math.min(20, r.progress + dt); r.healer.hurtFlash = Math.max(0, r.healer.hurtFlash - dt);
      if (r.healer.hp <= 0) { this.defeat('井畔营救受阻', '医者没能完成施救。重试会保留已救出的阿斗与荒村百姓。'); return; }
      if (!this.enemies.some(e => e.hp > 0 && e.group.startsWith('rescue'))) {
        r.gap += dt;
        if (r.wave === 1 && r.gap > 1.5) { r.wave = 2; r.gap = 0; this.spawnRescueWave(); this.say('第二波追兵来了，护住井畔！'); }
        else if (r.wave === 2 && r.progress >= 20) {
          this.flags.mother = this.flags.house = this.flags.motherDecision = true; this.rescue = null;
          this.checkpoint = { stage: 'house', x: 1090, y: 540, encounter: null }; this.allies.forEach(a => { a.hp = a.maxHp; });
          this.record('你护住井畔医者，糜夫人被救上担架，记忆中的诀别被改写。');
          this.dialog('井畔逆命 · 她活下来了', '医者：血止住了。快，抬她走。\n\n糜夫人：子龙……孩子呢？\n\n赵云：孩子在，夫人也在。这回，一个都不会落下。\n\n随军护送担架先行，你带着阿斗继续断后。', [{ text: '向粮道出发', detail: '糜夫人存活将改变重逢对白与长坂战报。', route: 'continue' }], '糜夫人'); this.save();
        }
      }
    }
    getMission() {
      const o = id => this.objects.find(p => p.id === id), targetEnemy = () => this.enemies.find(e => e.hp > 0) || this.player;
      if (this.activeBoss) return { title: this.boss.name + ' · 单挑', text: this.boss.phase2 ? '新的追枪加入了连招。不要抢出枪，等收招，再抓破绽。' : '观察蓄力，闪避后出枪。精准闪避可接回马枪，破势后可打连续重击。', target: this.boss };
      if (this.rescue) return { title: '守住井畔', text: `第 ${this.rescue.wave} / 2 波 · 医者体力 ${Math.ceil(this.rescue.healer.hp)}。用军令牵制敌人，你亲自清掉追兵。`, target: this.rescue.healer };
      switch (this.stage) {
        case 'mountain': return { title: this.flags.mountain ? '营火与前路' : '枪起长坂', text: this.flags.mountain ? '前方营火可补药并保存进度，之后继续进入荒村。' : '沿山道清开敌军。连击第三式收招较慢，别站着硬换血。', target: this.flags.mountain ? o('toVillage') : targetEnemy() };
        case 'village': return { title: this.selectedRoute === 'healer' && !this.flags.healer ? '寻访医者' : '穿过荒村', text: '西巷有被困医者与百姓；北面破庙有曹将守路。救援是可选的，也会打开新的结局。', target: this.selectedRoute === 'healer' && !this.flags.healer ? o('civilians') : o('toTemple') };
        case 'temple': return { title: this.flags.temple ? '侧门已开' : '破庙夺剑', text: this.flags.temple ? '东路通向井畔旧宅，西侧门直回荒村。' : '清开庙外守军，在营火休整，随后独自挑战夏侯恩。', target: this.flags.temple ? this.selectedRoute === 'healer' && !this.flags.healer ? o('shortcut') : o('toHouse') : o('xiahouGate') };
        case 'house': return { title: this.flags.house ? '护主向北' : this.flags.adou ? '井畔还有一人' : '寻回阿斗', text: this.flags.house ? '糜夫人' + (this.flags.mother ? '已获救。' : '仍可营救。') + '前往粮道岔口，也可以回头寻找医者。' : this.flags.adou ? '保护医者救下糜夫人，或先护阿斗撤离。渡桥前还可以回头。' : '击退守军后，靠近井畔旧宅，寻回阿斗与糜夫人。', target: this.selectedRoute === 'healer' && !this.flags.healer ? o('backTemple') : this.flags.house ? o('toFork') : o('adou') };
        case 'fork': return { title: '粮道抉择', text: '北面进入北桥；东面的粮营可挑战盾阵校尉。焚粮会撤掉桥头弓阵。入桥前仍能返回旧宅。', target: o('toBridge') };
        default: return { title: this.flags.boss ? '渡桥重逢' : '一枪断后', text: this.flags.boss ? '沿木桥向北，与刘备会合，看看你改写了哪些命运。' : this.flags.supplies ? '弓阵已撤，东侧道已打开。清开盾阵，让随军先走，再独自接下张郃的枪。' : '随军协助牵制盾兵，赵云先破弓阵。清开桥头后，单挑张郃。', target: this.flags.boss ? o('exit') : this.groupAlive() ? targetEnemy() : o('zhangheGate') };
      }
    }
    defeat(title, text) { if (this.mode !== 'playing') return; this.mode = 'defeat'; this.events.push({ kind: 'defeat', title, text }); this.events.push({ kind: 'sound', sound: 'defeat' }); this.save(); }
    retry() {
      if (this.mode !== 'defeat') return false;
      const cp = { ...this.checkpoint }; this.mode = 'playing'; this.enterStage(cp.stage, [cp.x, cp.y], false); this.checkpoint = cp;
      Object.assign(this.player, { hp: this.player.maxHp, qi: 100, rage: 0, potions: 3, invincible: 1, dashCd: 0, dashTime: 0, attackCd: 0, heavyCd: 0, counterWindow: 0, comboWindow: 0 });
      if (cp.encounter === 'rescue') this.startRescue(); else if (['xiahou', 'zhanghe'].includes(cp.encounter)) this.beginBoss(cp.encounter);
      this.say('重新握枪。已完成的救援与夺剑仍在，当前战斗重新开始。'); this.save(); return true;
    }
    finish() {
      this.mode = 'ending';
      const title = this.flags.mother ? '长坂逆命 · 母子同归' : this.flags.civilians ? '一骑护众 · 仁心归来' : '孤胆归来 · 命有未竟';
      const text = this.flags.mother ? '刘备先接过阿斗，随后看见担架上的糜夫人。\n「子龙……你竟把她也带回来了。」\n\n记忆里的诀别没有发生。你改写的第一件事，是让一个人活下来。' : '刘备接过阿斗，伸手扶起浑身尘土的你。\n「子龙，今日全赖你了。」\n\n你护住了孩子，也记住了井畔未能兑现的承诺。长坂的命运，还有另一种写法。';
      this.result = { won: true, title, text, people: this.flags.civilians ? 3 : 0, soldiers: 3, kills: this.kills, time: this.time, mother: this.flags.mother, supplies: this.flags.supplies, history: [...this.history] };
      this.events.push({ kind: 'ending', result: this.result }); this.events.push({ kind: 'sound', sound: 'victory' }); this.save();
    }
    snapshot() {
      return { version: 1, difficulty: this.difficulty, stage: this.stage, checkpoint: { ...this.checkpoint }, flags: { ...this.flags }, cleared: [...this.cleared],
        visited: [...this.visited], seen: [...this.seen], history: [...this.history], time: this.time, kills: this.kills, precisionCount: this.precisionCount,
        route: this.selectedRoute, complete: this.mode === 'ending' };
    }
    static validSnapshot(s) {
      if (!s || s.version !== 1 || !StageDefinition[s.stage] || !s.checkpoint || !StageDefinition[s.checkpoint.stage] || !['normal', 'story'].includes(s.difficulty)) return false;
      if (!Number.isFinite(s.checkpoint.x) || !Number.isFinite(s.checkpoint.y) || s.checkpoint.x < 0 || s.checkpoint.x > W || s.checkpoint.y < 0 || s.checkpoint.y > H) return false;
      if (!flagKeys.every(k => typeof s.flags?.[k] === 'boolean') || !Array.isArray(s.cleared) || !Array.isArray(s.visited) || !Array.isArray(s.history) || !Array.isArray(s.seen)) return false;
      const groups = new Set(Object.entries(StageDefinition).flatMap(([stage, def]) => def.groups.map(g => stage + ':' + g.id)));
      if (s.cleared.some(k => !groups.has(k)) || s.visited.some(k => !StageDefinition[k]) || s.history.length > 30 || s.history.some(t => typeof t !== 'string' || t.length > 300)) return false;
      if (s.seen.some(k => !['xiahou', 'zhanghe'].includes(k)) || ![null, 'xiahou', 'zhanghe', 'rescue'].includes(s.checkpoint.encounter)) return false;
      if (s.flags.sword !== s.flags.temple || s.flags.mother && (!s.flags.adou || !s.flags.healer) || s.flags.boss && !s.flags.adou || s.flags.committed && !s.flags.adou) return false;
      return [s.time, s.kills, s.precisionCount].every(v => Number.isFinite(v) && v >= 0 && v < 1e7);
    }
    restore(s) {
      if (!Campaign.validSnapshot(s) || s.complete) return false;
      this.reset(s.difficulty); this.flags = { ...s.flags }; this.cleared = new Set(s.cleared); this.visited = new Set(s.visited); this.seen = new Set(s.seen);
      this.history = [...s.history]; this.time = s.time; this.kills = s.kills; this.precisionCount = s.precisionCount; this.selectedRoute = s.route === 'healer' ? 'healer' : 'bridge';
      this.checkpoint = { ...s.checkpoint }; this.mode = 'playing'; this.enterStage(s.checkpoint.stage, [s.checkpoint.x, s.checkpoint.y], false);
      if (s.checkpoint.encounter === 'rescue' && !this.flags.mother) this.startRescue();
      else if (s.checkpoint.encounter === 'xiahou' && !this.flags.temple || s.checkpoint.encounter === 'zhanghe' && !this.flags.boss) this.beginBoss(s.checkpoint.encounter);
      this.say('已从最近营火或战斗入口继续。已完成的命运选择都还在。'); return true;
    }
    updateFriends(dt) {
      const p = this.player, active = this.squadActive();
      for (let i = 0; i < this.allies.length; i++) {
        const a = this.allies[i]; a.hurtFlash = Math.max(0, a.hurtFlash - dt); a.attackCd = Math.max(0, a.attackCd - dt); a.moving = false;
        if (a.hp <= 0 || this.activeBoss) continue;
        const target = active ? this.nearbyEnemy(a, this.command === 'charge' ? 260 : 165) : null;
        let tx = p.x - 55 + (i - 1) * 36, ty = p.y + 60 + (i % 2) * 18;
        if (active && this.command === 'hold') { tx = a.home.x; ty = a.home.y; }
        if (target && (this.command !== 'hold' || dist(a, a.home) < 140)) {
          tx = target.x; ty = target.y;
          if (dist(a, target) < 60 && a.attackCd <= 0) {
            a.dir = Math.atan2(target.y - a.y, target.x - a.x); a.attackCd = 1.8;
            this.damageEnemy(target, 3.5, a.dir, 8, 'ally', 2);
            this.effects.push({ type: 'allyStrike', x: a.x, y: a.y, dir: a.dir, life: .16, maxLife: .16 });
          }
        }
        if (Math.hypot(tx - a.x, ty - a.y) > (target ? 44 : 28)) this.navigate(a, tx, ty, dist(a, p) > 340 ? 215 : 165, dt);
      }
      for (let i = 0; i < this.civilians.length; i++) {
        const c = this.civilians[i]; c.moving = false;
        const tx = this.activeBoss || this.flags.boss ? 1270 + (i % 2 ? 18 : -18) : p.x - 80 + (i % 3 - 1) * 24;
        const ty = this.activeBoss || this.flags.boss ? 135 + i * 17 : p.y + 85 + Math.floor(i / 3) * 30;
        if (dist(c, { x: tx, y: ty }) > 28) this.navigate(c, tx, ty, 158, dt);
      }
    }
    startEnemyAction(e, target) {
      let definition;
      if (e.type === 'boss') {
        if (!e.sequence.length) {
          const pool = bossMoves[e.bossId], count = e.bossId === 'zhanghe' && !e.phase2 ? 3 : pool.length;
          e.sequence = pool[e.attackCount++ % count].map(m => ({ ...m }));
        }
        definition = e.sequence.shift();
      } else definition = AttackDefinition[e.type === 'archer' ? 'arrow' : e.type === 'spear' ? 'spear' : e.type === 'shield' || e.type === 'elite' ? 'shield' : 'cut'];
      e.attackDir = Math.atan2(target.y - e.y, target.x - e.x); e.dir = e.attackDir;
      e.action = this.newAction('enemy', definition, e.attackDir); e.windupMax = definition.windup; e.windup = definition.windup;
    }
    updateEnemyAction(e, dt, target) {
      const a = e.action; a.t += dt;
      if (target && a.t < a.def.windup * .45) { a.dir = Math.atan2(target.y - e.y, target.x - e.x); e.attackDir = e.dir = a.dir; }
      e.windup = Math.max(0, a.def.windup - a.t);
      if (a.t >= a.def.windup && a.t < a.def.windup + a.def.active) {
        if (!a.fired) {
          a.fired = true;
          if (e.type === 'archer') this.projectiles.push({ id: a.id, x: e.x, y: e.y - 8, vx: Math.cos(a.dir) * 400, vy: Math.sin(a.dir) * 400, dir: a.dir, damage: a.def.damage, life: 2.1 });
          else this.effects.push({ type: 'enemySlash', x: e.x, y: e.y, dir: a.dir, radius: a.def.range, arc: a.def.arc, life: a.def.active + .06, maxLife: a.def.active + .06 });
          this.events.push({ kind: 'sound', sound: 'enemy' });
        }
        if (a.def.lunge) this.move(e, Math.cos(a.dir) * a.def.lunge / a.def.active * dt, Math.sin(a.dir) * a.def.lunge / a.def.active * dt);
        if (e.type !== 'archer') {
          const targets = this.activeBoss ? [this.player] : [this.player, ...(this.squadActive() ? this.allies : []), ...(this.rescue ? [this.rescue.healer] : [])];
          for (const friend of targets) {
            if (friend.hp <= 0 || a.hits.has(friend.id) || dist(e, friend) > a.def.range + friend.r || Math.abs(angleDiff(Math.atan2(friend.y - e.y, friend.x - e.x), a.dir)) > a.def.arc) continue;
            a.hits.add(friend.id); this.damageFriend(friend, a.def.damage, a.id);
          }
        }
      }
      if (a.t >= total(a.def)) { e.action = null; e.windup = 0; e.cooldown = e.sequence.length ? .01 : e.type === 'boss' ? .15 : .25; }
    }
    updateEnemies(dt) {
      const p = this.player;
      for (const e of this.enemies) {
        if (this.mode !== 'playing') break;
        e.moving = false;
        if (e.hp <= 0) { e.deadTime += dt; continue; }
        if (this.activeBoss && e !== this.boss) continue;
        for (const key of ['cooldown', 'hurtFlash', 'stunned', 'staggerShield', 'shieldBroken', 'phaseTime']) e[key] = Math.max(0, e[key] - dt);
        e.stagger = Math.max(0, e.stagger - dt * 1.6);
        if (Math.abs(e.knockX) + Math.abs(e.knockY) > 1) { this.move(e, e.knockX * dt, e.knockY * dt); const decay = Math.exp(-12 * dt); e.knockX *= decay; e.knockY *= decay; }
        if (e.stunned > 0 || e.phaseTime > 0) { e.windup = 0; continue; }
        if (e.bossId === 'zhanghe' && !e.phase2 && e.hp <= e.maxHp * .5) {
          e.phase2 = true; e.phaseTime = 1.35; e.action = null; e.sequence = []; e.windup = 0;
          this.say('张郃变招：回身反刺与迟势追枪。仍要等连招收完。'); this.floater(e.x, e.y, '张郃 · 枪势再起', '#f4c994'); this.events.push({ kind: 'sound', sound: 'phase' }); continue;
        }
        let target = this.activeBoss ? p : this.nearbyEnemy(e, e.alerted ? 540 : e.type === 'archer' ? 400 : 260, true);
        if (this.rescue && e.group.startsWith('rescue') && (!target || dist(e, this.rescue.healer) < dist(e, target) * .8)) target = this.rescue.healer;
        if (e.action) { this.updateEnemyAction(e, dt, target); continue; }
        if (!target) { e.alerted = false; continue; }
        e.alerted = true; e.dir = Math.atan2(target.y - e.y, target.x - e.x);
        const d = dist(e, target), reach = e.type === 'boss' ? 225 : e.type === 'archer' ? 445 : e.type === 'spear' ? 138 : 78;
        const simultaneous = this.enemies.filter(other => other.hp > 0 && other.type !== 'archer' && other.action && other.action.t < other.action.def.windup + other.action.def.active).length;
        if (d < reach && e.cooldown <= 0 && (e.type === 'archer' || e.type === 'boss' || simultaneous < 2)) { this.startEnemyAction(e, target); continue; }
        if (e.type === 'archer' && d < 145) this.move(e, -Math.cos(e.dir) * e.speed * dt, -Math.sin(e.dir) * e.speed * dt);
        else if (d > reach * .68) {
          const moved = this.move(e, Math.cos(e.dir) * e.speed * dt, Math.sin(e.dir) * e.speed * dt);
          if (moved < .3 && !this.activeBoss) this.navigate(e, target.x, target.y, e.speed, dt);
        }
        for (const other of this.enemies) if (other !== e && other.hp > 0) {
          const sep = dist(e, other); if (sep < e.r + other.r && sep > .1) this.move(e, (e.x - other.x) / sep * dt * 24, (e.y - other.y) / sep * dt * 24);
        }
      }
    }
    updateProjectiles(dt) {
      for (let i = this.projectiles.length - 1; i >= 0; i--) {
        const a = this.projectiles[i]; a.life -= dt; a.x += a.vx * dt; a.y += a.vy * dt;
        let hit = false;
        for (const target of [this.player, ...(this.squadActive() ? this.allies : []), ...(this.rescue ? [this.rescue.healer] : [])]) if (target.hp > 0 && dist(a, target) < target.r + 8) { this.damageFriend(target, a.damage, a.id); hit = true; break; }
        if (hit || a.life <= 0 || this.blocking(a.x, a.y, 2)) this.projectiles.splice(i, 1);
      }
    }
    step(dt, input = {}) {
      if (this.mode !== 'playing') return;
      dt = clamp(dt, 0, .04); this.time += dt;
      const p = this.player; this.screenShake = Math.max(0, this.screenShake - dt * 20);
      for (const key of ['attackCd', 'comboWindow', 'heavyCd', 'dashCd', 'dashTime', 'invincible', 'hurtFlash', 'healCd', 'counterWindow']) p[key] = Math.max(0, p[key] - dt);
      p.dashAge += dt; p.qi = Math.min(100, p.qi + dt * (p.dashTime > 0 ? 0 : 18));
      let dx = input.x || 0, dy = input.y || 0; const magnitude = Math.hypot(dx, dy); if (magnitude > 1) { dx /= magnitude; dy /= magnitude; }
      p.moving = false; p.vx = dx; p.vy = dy;
      if (!p.action) { if (Number.isFinite(input.aim)) p.dir = input.aim; else if (magnitude > .06) p.dir = Math.atan2(dy, dx); }
      if (p.dashTime > 0) { this.move(p, Math.cos(p.dashDir) * 505 * dt, Math.sin(p.dashDir) * 505 * dt); }
      else {
        const slow = p.action ? p.action.key === 'heal' ? .12 : p.action.t < p.action.def.windup ? .4 : .65 : 1;
        this.move(p, dx * p.speed * slow * dt, dy * p.speed * slow * dt);
        if (p.moving && Math.floor(p.walkDistance / 37) !== p.footStep) {
          p.footStep = Math.floor(p.walkDistance / 37); this.events.push({ kind: 'sound', sound: 'step' });
          this.effects.push({ type: 'dust', x: p.x + Math.sin(p.dir) * (p.footStep % 2 ? 7 : -7), y: p.y, radius: 6, life: .28, maxLife: .28 });
        }
      }
      if (input.attack) this.attack(input.aim);
      this.updatePlayerAction(dt); if (this.mode !== 'playing') return;
      this.updateFriends(dt); this.updateEnemies(dt); if (this.mode !== 'playing') return;
      this.updateProjectiles(dt); this.updateRescue(dt);
      for (let i = this.loot.length - 1; i >= 0; i--) { const item = this.loot[i]; item.life -= dt; if (dist(p, item) < 35) { p.hp = Math.min(p.maxHp, p.hp + 18); this.loot.splice(i, 1); } else if (item.life <= 0) this.loot.splice(i, 1); }
      for (const e of this.effects) { e.life -= dt; if (e.vx != null) { e.x += e.vx * dt; e.y += e.vy * dt; } }
      this.effects = this.effects.filter(e => e.life > 0);
      for (const f of this.floaters) { f.life -= dt; f.y -= dt * 22; } this.floaters = this.floaters.filter(f => f.life > 0);
    }
  }
  globalThis.LongdanCore = { Campaign, StageDefinition, AttackDefinition, W, H, dist, clamp, angleDiff };
})();
