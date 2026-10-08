(() => {
  'use strict';
  const { Campaign, StageDefinition, W, H, dist, clamp, angleDiff, enemyThreat } = globalThis.LongdanCore;
  const art = globalThis.LongdanArt, sceneArt = globalThis.LongdanScene, combatArt = globalThis.LongdanCombatArt, $ = id => document.getElementById(id), TAU = Math.PI * 2;
  const campaign = new Campaign('normal');
  const canvas = $('battlefield'), ctx = canvas.getContext('2d', { alpha: false });
  const mini = $('minimap').getContext('2d'), bigmap = $('bigmap').getContext('2d');
  const SAVE_KEY = 'longdan.changban.v2';
  let viewW = innerWidth, viewH = innerHeight, dpr = 1;
  const zoom = 1;
  let terrain, scenery = [], menuDifficulty = 'normal', lastFrame = performance.now(), hudClock = 0;
  let toastTimer = 0, commandTimer = 0, stageTimer = 0, encounterTimer = 0, audioContext = null, muted = false, saveAvailable = true;
  let pendingStart = null;
  let mouseAttack = false, mouse = { x: 0, y: 0 }, aimUntil = 0;
  let reducedEffects = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches || false;
  try { const saved = localStorage.getItem('longdan.effects'); if (saved) reducedEffects = saved === 'soft'; } catch {}
  document.body.classList.toggle('soft-effects', reducedEffects);
  const keys = new Set(), camera = { x: 650, y: 750 };
  const overlays = ['menu', 'dialog', 'pause', 'map', 'defeat', 'ending', 'restart'];
  const desktopHelp = 'WASD / 方向键 移动\nJ / 鼠标左键 龙枪三式　空格 / K 闪避\nQ / 右键 横扫破阵　R 青釭断势（夺剑后）\nF 行军药（可被打断）　E 互动 / 休整 / 前进\n1 集合　2 守点　3 冲阵　M 军图　Esc 暂停\n精准闪避后，1.2秒内出枪可接回马枪。';
  function readSave() { try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); return Campaign.validSnapshot(s) ? s : null; } catch { return null; } }
  function writeSave() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(campaign.snapshot())); saveAvailable = true; } catch { saveAvailable = false; } }
  function refreshSaveMenu() {
    const saved = readSave(); $('continueButton').classList.toggle('hidden', !saved || saved.complete); $('reportButton').classList.toggle('hidden', !saved?.complete);
    $('saveInfo').textContent = !saveAvailable ? '此浏览器无法保存进度，本次仍可游玩。' : saved ? saved.complete ? '长坂已通关。战报已保存，可回看，也可重新改写命运。' : '最近进度：' + StageDefinition[saved.checkpoint.stage].name + ' · ' + (saved.difficulty === 'story' ? '初入战场' : '龙胆') : '营火、战斗入口与完成的救援会自动保存。';
  }
  function clearInput() { keys.clear(); mouseAttack = false; aimUntil = 0; campaign.clearActionBuffer(); }
  function hideOverlays() { overlays.forEach(id => $(id).classList.add('hidden')); }
  function resize() {
    viewW = innerWidth; viewH = innerHeight; dpr = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(viewW * dpr); canvas.height = Math.round(viewH * dpr); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (campaign.mode === 'map') renderBigMap();
  }
  function inputState() {
    const x = (keys.has('d') || keys.has('arrowright') ? 1 : 0) - (keys.has('a') || keys.has('arrowleft') ? 1 : 0);
    const y = (keys.has('s') || keys.has('arrowdown') ? 1 : 0) - (keys.has('w') || keys.has('arrowup') ? 1 : 0);
    const p = campaign.player;
    const aim = mouseAttack || performance.now() < aimUntil ? Math.atan2((mouse.y - viewH / 2) / zoom + camera.y - p.y, (mouse.x - viewW / 2) / zoom + camera.x - p.x) : undefined;
    return { x, y, aim, attack: keys.has('j') || mouseAttack };
  }
  function unlockAudio() { try { if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)(); if (audioContext.state === 'suspended') audioContext.resume().catch(() => {}); } catch {} }
  function sound(name) {
    if (muted || !audioContext) return;
    const notes = { swing: [180, 70, .09, 'triangle', .025], heavy: [120, 40, .18, 'sawtooth', .045],
      hit: [150, 50, .07, 'square', .02], hurt: [95, 55, .14, 'square', .035], dash: [460, 190, .08, 'triangle', .025],
      kill: [260, 110, .12, 'triangle', .025], heal: [400, 700, .25, 'sine', .04], victory: [330, 660, .65, 'sine', .055],
      defeat: [160, 70, .6, 'triangle', .04], command: [240, 180, .12, 'triangle', .03], ultimate: [100, 510, .48, 'sawtooth', .04],
      step: [75, 50, .035, 'triangle', .013], enemy: [160, 90, .1, 'triangle', .016], perfect: [520, 950, .16, 'sine', .045],
      enemyReady: [620, 780, .045, 'triangle', .014], enemyHeavy: [115, 45, .16, 'sawtooth', .026],
      ignite: [360, 145, .13, 'sawtooth', .025], explosion: [95, 32, .28, 'sawtooth', .055],
      break: [190, 580, .18, 'square', .025], phase: [110, 280, .65, 'triangle', .045] }[name];
    if (!notes) return;
    try { const [from, to, duration, type, volume] = notes, now = audioContext.currentTime;
      const osc = audioContext.createOscillator(), gain = audioContext.createGain(); osc.type = type;
      osc.frequency.setValueAtTime(from, now); osc.frequency.exponentialRampToValueAtTime(to, now + duration);
      gain.gain.setValueAtTime(volume, now); gain.gain.exponentialRampToValueAtTime(.001, now + duration);
      osc.connect(gain); gain.connect(audioContext.destination); osc.start(now); osc.stop(now + duration);
      if (['swing', 'heavy', 'hit', 'ultimate', 'break', 'dash', 'explosion'].includes(name)) {
        const length = name === 'ultimate' ? .28 : name === 'heavy' ? .16 : .085;
        const buffer = audioContext.createBuffer(1, Math.ceil(audioContext.sampleRate * length), audioContext.sampleRate), data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / data.length, 1.8);
        const noise = audioContext.createBufferSource(), filter = audioContext.createBiquadFilter(), volumeNode = audioContext.createGain();
        noise.buffer = buffer; filter.type = 'bandpass'; filter.frequency.setValueAtTime(name === 'hit' || name === 'break' ? 1900 : 900, now);
        filter.frequency.exponentialRampToValueAtTime(170, now + length); volumeNode.gain.value = name === 'ultimate' ? .055 : .028;
        noise.connect(filter); filter.connect(volumeNode); volumeNode.connect(audioContext.destination); noise.start(now); noise.stop(now + length);
      }
    } catch {}
  }
  function formatTime(t) { return Math.floor(t / 60).toString().padStart(2, '0') + ':' + Math.floor(t % 60).toString().padStart(2, '0'); }
  function showToast(text) { $('toast').textContent = text; $('toast').classList.remove('hidden'); toastTimer = 5; }
  function togglePause() {
    if (campaign.mode === 'playing') { campaign.mode = 'paused'; $('checkpointInfo').textContent = '最近的落脚点：' + StageDefinition[campaign.checkpoint.stage].name; $('pause').classList.remove('hidden'); writeSave(); }
    else if (campaign.mode === 'paused') { campaign.mode = 'playing'; $('pause').classList.add('hidden'); }
    clearInput();
  }
  function toggleMap() {
    if (campaign.mode === 'playing') { campaign.mode = 'map'; $('map').classList.remove('hidden'); updateMemory(); renderBigMap(); }
    else if (campaign.mode === 'map') { campaign.mode = 'playing'; $('map').classList.add('hidden'); }
    clearInput();
  }
  function start(difficulty = menuDifficulty) { pendingStart = null; unlockAudio(); clearInput(); hideOverlays(); $('hud').classList.remove('hidden'); campaign.start(difficulty); processEvents(); writeSave(); updateHud(); }
  function requestStart(difficulty) {
    if (!readSave()) { start(difficulty); return; }
    pendingStart = { difficulty, mode: campaign.mode }; clearInput(); hideOverlays();
    $('restartText').textContent = '新征程将替换本浏览器的当前进度与战报。\n战斗难度：' + (difficulty === 'story' ? '初入战场' : '龙胆') + '。确定重新从山道出发吗？';
    $('restart').classList.remove('hidden'); $('cancelRestartButton').focus();
  }
  function cancelStart() {
    if (!pendingStart) return;
    const source = pendingStart.mode === 'paused' ? 'pause' : pendingStart.mode; pendingStart = null;
    $('restart').classList.add('hidden'); $(source).classList.remove('hidden');
    $(source === 'menu' ? 'startButton' : source === 'ending' ? 'playAgainButton' : 'restartButton').focus();
  }
  function continueGame() {
    const saved = readSave(); if (!saved || !campaign.restore(saved)) { refreshSaveMenu(); showToast('没有可继续的进度，可开始新的征程。'); return; }
    unlockAudio(); clearInput(); hideOverlays(); $('hud').classList.toggle('hidden', campaign.mode === 'ending'); processEvents(); updateHud();
  }
  function returnMenu() { clearInput(); hideOverlays(); campaign.mode = 'menu'; $('hud').classList.add('hidden'); $('menu').classList.remove('hidden'); refreshSaveMenu(); }
  function processEvents() {
    let pendingSave = false;
    while (campaign.events.length) {
      const e = campaign.events.shift();
      if (e.kind === 'toast') showToast(e.text);
      else if (e.kind === 'save') pendingSave = true;
      else if (e.kind === 'sound') sound(e.sound);
      else if (e.kind === 'stage') { buildTerrain(); camera.x = campaign.player.x; camera.y = campaign.player.y; $('encounterBanner').classList.add('hidden'); encounterTimer = 0; $('stageName').textContent = campaign.definition.name; $('stageChapter').textContent = campaign.definition.chapter; $('stageBanner').classList.toggle('hidden', campaign.mode === 'menu' || campaign.mode === 'ending'); stageTimer = 2.5; }
      else if (e.kind === 'encounter' && campaign.mode === 'playing') {
        $('encounterTitle').textContent = '此处敌阵已破'; $('encounterNext').textContent = '下一步 · ' + campaign.getMission().title;
        $('encounterBanner').classList.remove('hidden'); encounterTimer = 2.4;
      }
      else if (e.kind === 'command') { document.querySelectorAll('[data-command]').forEach(b => b.classList.toggle('selected', b.dataset.command === e.command)); $('commandBanner').textContent = { follow: '集合 · 随行掩护', hold: '守点 · 稳住阵线', charge: '冲阵 · 牵制敌军' }[e.command]; $('commandBanner').classList.add('show'); commandTimer = 2.2; sound('command'); }
      else if (e.kind === 'dialog') {
        clearInput(); $('dialogTitle').textContent = e.title; $('dialogText').textContent = e.text; $('dialogEyebrow').textContent = e.speaker;
        $('dialogPortrait').src = art.portraitFor(e.speaker); $('dialogPortrait').alt = e.speaker;
        $('dialogChoices').replaceChildren();
        for (const choice of e.choices) {
          const button = document.createElement('button'), label = document.createElement('strong'), detail = document.createElement('small');
          button.type = 'button'; label.textContent = choice.text; detail.textContent = choice.detail; button.append(label, detail);
          button.addEventListener('click', () => { $('dialog').classList.add('hidden'); campaign.chooseRoute(choice.route); processEvents(); updateHud(); }); $('dialogChoices').append(button);
        }
        $('dialog').classList.remove('hidden');
      } else if (e.kind === 'defeat') { clearInput(); $('defeatTitle').textContent = e.title; $('defeatText').textContent = e.text; $('defeat').classList.remove('hidden'); }
      else if (e.kind === 'ending') {
        clearInput(); $('hud').classList.add('hidden'); $('endingTitle').textContent = e.result.title; $('endingText').textContent = e.result.text;
        $('endingOutcomes').innerHTML = `<span class="${e.result.mother ? 'changed' : ''}">糜夫人 ${e.result.mother ? '存活' : '未获救'}</span><span class="${e.result.people ? 'changed' : ''}">百姓 ${e.result.people} 人获救</span><span class="${e.result.supplies ? 'changed' : ''}">粮道 ${e.result.supplies ? '截断' : '未截断'}</span>`;
        $('endingStats').innerHTML = `<div><b>${e.result.kills}</b><span>亲手击破</span></div><div><b>3</b><span>随军归队</span></div><div><b>${e.result.precisionCount}</b><span>精准闪避</span></div><div><b>${formatTime(e.result.time)}</b><span>出征用时</span></div>`;
        $('endingCompletion').textContent = '第一章主线完成 · 支线逆命 ' + e.result.changes + ' / 3 · ' + (e.result.difficulty === 'story' ? '初入战场' : '龙胆');
        $('endingHints').replaceChildren();
        for (const line of e.result.hints) { const hint = document.createElement('p'); hint.textContent = line; $('endingHints').append(hint); }
        $('endingHintTitle').textContent = e.result.hints.length ? '下一次，可以再改写这些命运' : '三项支线命运均已改写';
        $('endingHistory').replaceChildren(); for (const line of e.result.history) { const note = document.createElement('div'); note.textContent = '· ' + line; $('endingHistory').append(note); } $('ending').classList.remove('hidden'); $('ending').scrollTop = 0;
      }
    }
    if (pendingSave) writeSave();
  }
  function updateHud() {
    const p = campaign.player, mission = campaign.getMission(), tutorial = campaign.getTutorial();
    $('hpLabel').textContent = Math.ceil(p.hp) + ' / ' + p.maxHp; $('hpFill').style.width = p.hp / p.maxHp * 100 + '%';
    $('qiLabel').textContent = Math.floor(p.qi); $('qiFill').style.width = p.qi + '%';
    $('regionLabel').textContent = '长坂逆命 · ' + campaign.definition.name; $('minimapCaption').textContent = campaign.definition.name + ' · 北 ↑';
    $('troopLabel').textContent = '随军 ' + campaign.allies.filter(a => a.hp > 0).length + ' / 3 · ' + (campaign.activeBoss ? '护送中' : campaign.squadActive() ? '掩护中' : '待命');
    $('pressureLabel').textContent = campaign.rescue ? '医者施救 ' + Math.floor(campaign.rescue.progress / 20 * 100) + '%' : p.action?.key === 'heal' ? '服药中 · 留意敌军' : '观察 · 闪避 · 反击';
    $('missionTitle').textContent = mission.title; $('missionText').textContent = mission.text; $('timeLabel').textContent = formatTime(campaign.time);
    $('objectiveList').innerHTML = [['temple', '破庙夺剑'], ['adou', '寻回阿斗'], ['mother', '救下糜夫人（可选）'], ['supplies', '焚毁粮草（可选）'], ['boss', '击退张郃']].map(([id, label]) => `<div class="${campaign.flags[id] ? 'done' : 'todo'}">${label}</div>`).join('');
    $('objectiveList').classList.toggle('hidden', !!tutorial);
    $('tutorialHint').classList.toggle('hidden', !tutorial); $('tutorialHint').classList.toggle('learned', !!tutorial?.done);
    if (tutorial) {
      $('tutorialStep').textContent = '实战引导 ' + tutorial.step + ' / 3' + (tutorial.done ? ' · 已尝试' : '');
      $('tutorialTitle').textContent = tutorial.title; $('tutorialText').textContent = tutorial.text;
    }
    $('heavyState').textContent = p.heavyCd > 0 ? p.heavyCd.toFixed(1) + '秒后可用' : '消耗30气力';
    $('dashState').textContent = p.dashCd > 0 ? '整步再出' : '消耗16气力';
    $('rageState').textContent = !campaign.flags.sword ? '夺剑后习得' : '战意 ' + Math.floor(p.rage) + ' / 100';
    document.querySelector('.ultimate').classList.toggle('ready', campaign.flags.sword && p.rage >= 100);
    $('potionState').textContent = '剩余' + p.potions + '份';
    for (const el of document.querySelectorAll('[data-skill]')) {
      const key = el.dataset.skill, active = key === 'dash' ? p.dashTime > 0 : key === 'attack' ? p.action?.key.startsWith('thrust') || p.action?.key === 'counter' : p.action?.key === key;
      const progress = key === 'sweep' ? 1 - p.heavyCd / 3.6 : key === 'dash' ? 1 - p.dashCd / .61 : key === 'sword' ? campaign.flags.sword ? p.rage / 100 : 0 : 1;
      el.style.setProperty('--charge', clamp(progress, 0, 1) * 100 + '%'); el.classList.toggle('casting', !!active);
      el.classList.toggle('guided', tutorial?.skill === key && !tutorial.done);
      el.classList.toggle('unavailable', key === 'sweep' ? p.heavyCd > 0 || p.qi < 30 : key === 'dash' ? p.dashCd > 0 || p.qi < 16 : key === 'sword' ? !campaign.flags.sword || p.rage < 100 : false);
    }
    const o = campaign.nearestObject(); $('interaction').classList.toggle('hidden', !o || campaign.mode !== 'playing');
    if (o) { $('interaction').replaceChildren(); const key = document.createElement('kbd'); key.textContent = 'E'; $('interaction').append(key, document.createTextNode(campaign.interactionText(o))); }
    $('counterHint').classList.toggle('hidden', p.counterWindow <= 0 || campaign.mode !== 'playing');
    const boss = campaign.boss, visible = boss && boss.hp > 0 && dist(boss, p) < 650;
    $('bossHud').classList.toggle('hidden', !visible);
    document.body.classList.toggle('has-boss', !!visible);
    if (visible) { $('bossName').textContent = boss.name + (boss.phase2 ? ' · 二势' : ''); $('bossHpFill').style.width = boss.hp / boss.maxHp * 100 + '%'; $('bossHpLabel').textContent = Math.ceil(boss.hp); $('staggerFill').style.width = boss.stagger / boss.staggerMax * 100 + '%'; $('bossMove').textContent = boss.stunned > .3 ? '破势 · 趁机出枪' : boss.action ? boss.action.t < boss.action.def.windup ? boss.action.def.name + (boss.action.t < boss.action.def.windup * .45 ? ' · 尚在追踪' : ' · 方向已定') : boss.action.t < boss.action.def.windup + boss.action.def.active ? '锋芒已出' : boss.sequence.length ? '连招未完 · 留意下一式' : '收招 · 可反击' : '观察起手'; }
    canvas.dataset.state = campaign.mode; canvas.dataset.stage = campaign.stage; canvas.dataset.mission = mission.title; canvas.dataset.x = Math.round(p.x); canvas.dataset.y = Math.round(p.y); canvas.dataset.combo = p.combo; canvas.dataset.action = p.dashTime > 0 ? 'dash' : p.action?.key || 'idle';
    document.querySelectorAll('[data-command]').forEach(b => b.classList.toggle('inactive', !campaign.squadActive()));
    drawMap(mini, 176, 128, false);
  }
  function updateMemory() {
    const f = campaign.flags;
    $('regionRoute').innerHTML = Object.entries(StageDefinition).map(([id, d]) => `<span class="${id === campaign.stage ? 'current' : campaign.visited.has(id) ? 'visited' : ''}">${campaign.visited.has(id) ? d.name : '未探明'}</span>`).join('<i>›</i>');
    const cards = [ { title: '荒村的医者', changed: f.civilians, text: f.civilians ? '医者与三名百姓已获救。医者能救井畔重伤的糜夫人。' : '荒村西巷传来求救声。救出医者，会打开井畔的新选择。' },
      { title: '井畔的旧命', changed: f.mother, text: f.mother ? '糜夫人活下来了。重逢时，刘备会看见母子同归。' : '记忆里的诀别可以改写：找医者，守住两波追兵。进入北桥后无法回头。' },
      { title: '粮营与弓阵', changed: f.supplies, text: f.supplies ? '粮营已毁，北桥弓手撤走，东侧道已开放。' : '粮道东营由盾阵校尉把守。焚粮会改变北桥普通敌军部署。' } ];
    $('memoryCards').innerHTML = cards.map(c => `<div class="memory-card${c.changed ? ' changed' : ''}"><strong>${c.title}</strong><p>${c.text}</p></div>`).join('');
  }
  function renderBigMap() { const c = $('bigmap'), width = Math.max(250, Math.round(c.getBoundingClientRect().width)); c.width = width; c.height = Math.round(width * H / W); drawMap(bigmap, width, c.height, true); }
  function act(action) {
    if (campaign.mode !== 'playing') return; unlockAudio();
    if (['attack', 'heavy', 'dash', 'ultimate'].includes(action)) campaign.requestAction(action, inputState());
    else if (action === 'heal') campaign.heal(); else if (action === 'interact') campaign.interact();
    processEvents(); updateHud();
  }
  document.addEventListener('keydown', e => {
    const key = e.key.toLowerCase();
    if (pendingStart) {
      if (key === 'escape') { e.preventDefault(); cancelStart(); }
      else if (key === 'tab') { e.preventDefault(); (document.activeElement === $('cancelRestartButton') ? $('confirmRestartButton') : $('cancelRestartButton')).focus(); }
      return;
    }
    if (campaign.mode === 'playing' && [' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'tab'].includes(key) || campaign.mode === 'map' && key === 'tab') e.preventDefault();
    if (e.repeat) return;
    if (key === 'escape') { campaign.mode === 'map' ? toggleMap() : togglePause(); return; }
    if ((key === 'm' || key === 'tab') && ['playing', 'map'].includes(campaign.mode)) { toggleMap(); return; }
    if (campaign.mode !== 'playing') return; keys.add(key);
    if (key === 'j') act('attack');
    else if (key === 'e') act('interact'); else if (key === 'q') act('heavy'); else if (key === 'r') act('ultimate'); else if (key === 'f') act('heal'); else if (key === ' ' || key === 'k') act('dash');
    else if (['1', '2', '3'].includes(key)) { campaign.setCommand({ 1: 'follow', 2: 'hold', 3: 'charge' }[key]); processEvents(); }
  });
  document.addEventListener('keyup', e => keys.delete(e.key.toLowerCase()));
  window.addEventListener('blur', () => { clearInput(); if (campaign.mode === 'playing') togglePause(); });
  document.addEventListener('visibilitychange', () => { if (document.hidden) { clearInput(); if (campaign.mode === 'playing') togglePause(); } });
  canvas.addEventListener('pointermove', e => { if (e.pointerType === 'touch') return; const rect = canvas.getBoundingClientRect(); mouse = { x: e.clientX - rect.left, y: e.clientY - rect.top }; aimUntil = performance.now() + 1400; });
  canvas.addEventListener('pointerdown', e => { if (campaign.mode !== 'playing' || e.pointerType === 'touch') return; unlockAudio(); const rect = canvas.getBoundingClientRect(); mouse = { x: e.clientX - rect.left, y: e.clientY - rect.top }; aimUntil = performance.now() + 1400; if (e.button === 0) { mouseAttack = true; act('attack'); canvas.setPointerCapture(e.pointerId); } else if (e.button === 2) act('heavy'); });
  window.addEventListener('pointerup', () => { mouseAttack = false; });
  window.addEventListener('pointercancel', () => { mouseAttack = false; }); canvas.addEventListener('contextmenu', e => e.preventDefault());
  $('startButton').addEventListener('click', () => requestStart(menuDifficulty)); $('continueButton').addEventListener('click', continueGame); $('reportButton').addEventListener('click', continueGame);
  $('restartButton').addEventListener('click', () => requestStart(campaign.difficulty)); $('playAgainButton').addEventListener('click', () => requestStart(campaign.difficulty));
  $('confirmRestartButton').addEventListener('click', () => { if (pendingStart) start(pendingStart.difficulty); }); $('cancelRestartButton').addEventListener('click', cancelStart);
  $('pauseButton').addEventListener('click', togglePause); $('resumeButton').addEventListener('click', togglePause);
  $('mapButton').addEventListener('click', toggleMap); $('quickMapButton').addEventListener('click', toggleMap); $('closeMapButton').addEventListener('click', toggleMap);
  $('healButton').addEventListener('click', () => act('heal'));
  $('soundButton').addEventListener('click', () => { muted = !muted; unlockAudio(); $('soundButton').textContent = '声音 ' + (muted ? '关' : '开'); });
  $('effectsButton').addEventListener('click', () => {
    reducedEffects = !reducedEffects; document.body.classList.toggle('soft-effects', reducedEffects);
    $('effectsButton').textContent = '技能特效：' + (reducedEffects ? '柔和（减弱光效与震屏）' : '完整');
    try { localStorage.setItem('longdan.effects', reducedEffects ? 'soft' : 'full'); } catch {}
  });
  for (const id of ['backMenuButton', 'pauseMenuButton', 'defeatMenuButton']) $(id).addEventListener('click', returnMenu);
  $('retryButton').addEventListener('click', () => { clearInput(); $('defeat').classList.add('hidden'); campaign.retry(); processEvents(); updateHud(); });
  $('fullscreenButton').addEventListener('click', async () => { try { if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen(); else showToast('可使用浏览器的全屏模式。'); } catch { showToast('可使用浏览器的全屏模式。'); } });
  document.querySelectorAll('[data-difficulty]').forEach(b => b.addEventListener('click', () => { menuDifficulty = b.dataset.difficulty; document.querySelectorAll('[data-difficulty]').forEach(o => o.classList.toggle('selected', o === b)); }));
  document.querySelectorAll('[data-command]').forEach(b => b.addEventListener('click', () => { campaign.setCommand(b.dataset.command); processEvents(); updateHud(); }));
  function ellipse(g, x, y, rx, ry, color) { g.fillStyle = color; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill(); }
  function polygon(g, points, color) { g.fillStyle = color; g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); g.fill(); }
  function buildTerrain() {
    const ratio = Math.min(dpr, 1.25); terrain = sceneArt.landscape(campaign, W, H, ratio);
    scenery = terrain.scenery;
  }
  function onScreen(x, y, margin = 120) { return Math.abs(x - camera.x) < viewW / zoom / 2 + margin && Math.abs(y - camera.y) < viewH / zoom / 2 + margin; }
  function drawScenery(g, item) { const p = campaign.player, behind = p.y < item.y + 8 && p.y > item.y - item.height + 20 && Math.abs(p.x - item.x) < item.width * .38; g.save(); if (behind && campaign.mode !== 'menu') g.globalAlpha = item.kind === 'tree' ? .42 : .65; g.drawImage(item.canvas, item.x - item.anchorX, item.y - item.anchorY, item.width, item.height); g.restore(); }
  function drawFlag(g, x, y, text, color, time) {
    ellipse(g, x + 5, y, 13, 4, '#203c3138'); g.strokeStyle = '#53462f'; g.lineWidth = 3; g.beginPath(); g.moveTo(x, y); g.lineTo(x, y - 75); g.stroke();
    const wave = Math.sin(time * 2.3 + x) * 4; polygon(g, [[x + 2, y - 73], [x + 37, y - 68 + wave], [x + 34, y - 30 + wave], [x + 2, y - 36]], color);
    g.fillStyle = '#e8d9b1'; g.font = '20px KaiTi, SimSun, serif'; g.textAlign = 'center'; g.fillText(text, x + 18, y - 45 + wave * .5);
  }
  function drawFire(g, x, y, time, count = 3) {
    const radius = 57 + Math.sin(time * 8 + x) * 4, halo = g.createRadialGradient(x, y - 12, 3, x, y - 12, radius);
    halo.addColorStop(0, '#ffc86932'); halo.addColorStop(1, '#ffb35700'); g.fillStyle = halo; g.fillRect(x - radius, y - radius - 12, radius * 2, radius * 2);
    ellipse(g, x, y + 2, 29, 9, '#392e254b');
    for (let i = 0; i < count; i++) { const px = x + (i - (count - 1) / 2) * 12, sway = Math.sin(time * 6 + i) * 4; polygon(g, [[px - 10, y], [px - 7 + sway, y - 16], [px + 2, y - 37 - sway], [px + 9, y - 14], [px + 11, y]], '#d07745cc'); polygon(g, [[px - 5, y], [px + sway, y - 26], [px + 5, y]], '#eed891dc'); ellipse(g, px + Math.sin(time + i) * 9, y - 55 - (time * 14 + i * 20) % 50, 13, 21, '#46504b20'); }
  }
  function objectDone(o) { return o.id === 'civilians' ? campaign.flags.civilians : o.id === 'adou' ? campaign.flags.mother : o.id === 'supplies' ? campaign.flags.supplies : o.id === 'xiahouGate' ? campaign.flags.temple : o.id === 'zhangheGate' ? campaign.flags.boss : false; }
  function drawObjects(g, time) {
    const mission = campaign.getMission();
    for (const o of campaign.objects) {
      if (!onScreen(o.x, o.y)) continue;
      if (o.id === 'supplies' && campaign.flags.supplies) { drawFire(g, o.x, o.y, time, 7); continue; }
      if (o.kind === 'camp') { drawFire(g, o.x, o.y, time); drawFlag(g, o.x - 35, o.y + 12, '休', '#3d6258', time); }
      if (o.id === 'civilians') drawFlag(g, o.x - 54, o.y + 6, '医', '#467367', time);
      if (o.id === 'adou') {
        ellipse(g, o.x - 25, o.y, 22, 12, '#56645760'); g.strokeStyle = '#857651'; g.lineWidth = 7; g.beginPath(); g.ellipse(o.x - 25, o.y - 9, 21, 12, 0, 0, TAU); g.stroke();
        if (!campaign.flags.adou) { ellipse(g, o.x + 15, o.y - 6, 8, 11, '#eee0bb'); ellipse(g, o.x + 15, o.y - 15, 4, 4, '#edc5a0'); }
      }
      if (o.kind === 'exit' || o.kind === 'finish') drawFlag(g, o.x + 35, o.y + 7, o.to === 'bridge' ? '北' : o.kind === 'finish' ? '归' : '路', '#496b54', time);
      if (o.kind === 'boss' && !objectDone(o)) drawFlag(g, o.x - 38, o.y, '战', '#8c493d', time);
      const done = objectDone(o), main = mission.target && dist(o, mission.target) < 10;
      g.strokeStyle = done ? '#95bc95' : main ? '#e9d599' : '#d2d3b09c'; g.lineWidth = main ? 2 : 1;
      g.beginPath(); g.ellipse(o.x, o.y + 3, 28 + Math.sin(time * 2) * 2, 11, 0, 0, TAU); g.stroke();
      g.fillStyle = done ? '#adcda8' : '#f2e2b6'; g.textAlign = 'center'; g.font = '12px Microsoft YaHei'; g.shadowColor = '#153d2a'; g.shadowBlur = 5; g.fillText((done ? '✓ ' : '') + o.label, o.x, o.y - (o.kind === 'camp' ? 60 : 44)); g.shadowBlur = 0;
    }
    if (campaign.stage === 'village') { drawFire(g, 375, 780, time, 4); drawFire(g, 1150, 430, time, 3); }
    if (campaign.activeBoss) { const a = campaign.definition.arena; g.strokeStyle = '#dac08d99'; g.lineWidth = 2; g.setLineDash([12, 10]); g.strokeRect(a.x - a.rx, a.y - a.ry, a.rx * 2, a.ry * 2); g.setLineDash([]); }
  }
  function drawWarnings(g) {
    for (const prop of campaign.props) if (onScreen(prop.x, prop.y, 230)) combatArt.propWarning(g, prop, campaign.player.r);
    for (const e of campaign.enemies) {
      if (e.hp <= 0 || !e.action || !onScreen(e.x, e.y, 240)) continue;
      const threat = enemyThreat(e, campaign.player.r);
      if (threat && e.type === 'archer') threat.radius = campaign.projectileReach(e, e.action.dir, threat.radius);
      combatArt.warning(g, e, threat);
    }
  }
  function drawEffects(g) {
    for (const e of campaign.effects) {
      if (e.type === 'dashGhost') continue;
      if (!onScreen(e.x, e.y, 230)) continue; const t = 1 - e.life / e.maxLife;
      g.save(); g.globalAlpha = clamp(e.life / e.maxLife, 0, 1);
      if (combatArt.effect(g, e, reducedEffects, art, campaign.time)) { g.restore(); continue; }
      if (e.type === 'particle') ellipse(g, e.x, e.y, e.size, e.size * .6, e.color);
      else if (e.type === 'dust') { ellipse(g, e.x, e.y + 1, 4 + t * 8, 2 + t * 2, '#ddd0a17a'); }
      else if (e.type === 'slash' || e.type === 'enemySlash') {
        g.translate(e.x, e.y); g.rotate(e.dir); g.lineCap = 'round';
        if (e.arc < 1) { const end = e.radius * (.55 + t * .45); g.strokeStyle = e.type === 'slash' ? '#a9dce3b0' : '#d98969a0'; g.lineWidth = e.heavy ? 10 : 6; g.beginPath(); g.moveTo(22, -5); g.lineTo(end, -5); g.stroke(); polygon(g, [[end + 8, -5], [end - 6, -10], [end - 6, 0]], '#ede8d5'); }
        else { g.strokeStyle = e.type === 'enemySlash' ? '#de986c' : e.heavy ? '#f2dda1' : '#bfe0e6'; g.lineWidth = e.heavy ? 12 : 7; g.beginPath(); g.arc(0, -5, e.radius * (.75 + t * .25), -e.arc + t * e.arc, e.arc); g.stroke(); g.strokeStyle = '#faf0d2'; g.lineWidth = 2; g.beginPath(); g.arc(0, -5, e.radius, -e.arc + t * e.arc, e.arc); g.stroke(); }
      } else if (e.type === 'ring') { g.strokeStyle = e.color; g.lineWidth = 3 * (1 - t) + 1; g.beginPath(); g.ellipse(e.x, e.y, e.radius * (.4 + t * .6), e.radius * (.2 + t * .32), 0, 0, TAU); g.stroke(); }
      else if (e.type === 'allyStrike') { g.strokeStyle = '#b9ccbb'; g.lineWidth = 2; g.beginPath(); g.moveTo(e.x, e.y - 10); g.lineTo(e.x + Math.cos(e.dir) * 50, e.y - 10 + Math.sin(e.dir) * 50); g.stroke(); }
      g.restore();
    }
    for (const f of campaign.floaters) { g.save(); g.globalAlpha = clamp(f.life * 2, 0, 1); g.fillStyle = f.color; g.font = f.text.length > 5 ? '12px Microsoft YaHei' : 'bold 15px Microsoft YaHei'; g.textAlign = 'center'; g.shadowColor = '#15392a'; g.shadowBlur = 4; g.fillText(f.text, f.x, f.y); g.restore(); }
  }
  function drawMap(g, width, height, detailed) {
    const sx = width / W, sy = height / H; g.clearRect(0, 0, width, height); g.fillStyle = '#344d40'; g.fillRect(0, 0, width, height);
    if (terrain?.map) { g.drawImage(terrain.map, 0, 0, width, height); g.fillStyle = '#15362d45'; g.fillRect(0, 0, width, height); }
    if (campaign.stage === 'bridge') { g.fillStyle = '#52766d'; g.fillRect(0, 70 * sy, width, 210 * sy); g.fillStyle = '#ac996c'; g.fillRect(1170 * sx, 60 * sy, 200 * sx, 240 * sy); }
    for (const road of campaign.definition.roads) { g.beginPath(); road.forEach(([x, y], i) => i ? g.lineTo(x * sx, y * sy) : g.moveTo(x * sx, y * sy)); g.strokeStyle = '#d6c49566'; g.lineWidth = detailed ? 9 : 2; g.stroke(); }
    for (const h of campaign.huts) { g.fillStyle = '#a8b69840'; g.fillRect((h.x - h.w / 2) * sx, (h.y - h.h / 2) * sy, h.w * sx, h.h * sy); }
    for (const prop of campaign.props) if (!prop.spent) { g.fillStyle = '#e5ae71'; g.fillRect(prop.x * sx - 2, prop.y * sy - 2, 4, 4); }
    for (const o of campaign.objects) {
      const color = objectDone(o) ? '#95ba94' : o.kind === 'boss' || o.kind === 'supplies' ? '#d59476' : o.kind === 'camp' || o.kind === 'rescue' ? '#91c4ba' : '#e7cf99';
      g.fillStyle = color; g.beginPath(); g.arc(o.x * sx, o.y * sy, detailed ? 6 : 3, 0, TAU); g.fill();
      if (detailed) { g.textAlign = 'center'; g.font = '11px Microsoft YaHei'; g.fillStyle = '#e6dec1'; const offset = o.y < 150 ? 20 : -12; g.fillText(o.label, clamp(o.x * sx, 65, width - 65), o.y * sy + offset); }
    }
    for (const e of campaign.enemies) if (e.hp > 0 && dist(e, campaign.player) < 430) { g.fillStyle = '#cf886688'; g.beginPath(); g.arc(e.x * sx, e.y * sy, e.type === 'boss' ? 5 : 2, 0, TAU); g.fill(); }
    const target = campaign.getMission().target;
    if (target) { g.strokeStyle = '#ffe1a2'; g.lineWidth = 1.5; g.beginPath(); g.arc(target.x * sx, target.y * sy, detailed ? 10 : 5, 0, TAU); g.stroke(); }
    if (!detailed) { g.strokeStyle = '#e2edc566'; g.lineWidth = .7; g.strokeRect(clamp(camera.x - viewW / zoom / 2, 0, W) * sx, clamp(camera.y - viewH / zoom / 2, 0, H) * sy, (Math.min(W, camera.x + viewW / zoom / 2) - Math.max(0, camera.x - viewW / zoom / 2)) * sx, (Math.min(H, camera.y + viewH / zoom / 2) - Math.max(0, camera.y - viewH / zoom / 2)) * sy); }
    g.save(); g.translate(campaign.player.x * sx, campaign.player.y * sy); g.rotate(campaign.player.dir); const size = detailed ? 7 : 5;
    polygon(g, [[size, 0], [-size * .6, -size * .6], [-size * .3, 0], [-size * .6, size * .6]], '#fff4d7'); g.restore();
  }
  function drawNavigation(g, time) {
    if (!['playing', 'paused', 'map'].includes(campaign.mode)) return;
    const target = campaign.getMission().target; if (!target || dist(target, campaign.player) < 150) return;
    let x = (target.x - camera.x) * zoom + viewW / 2, y = (target.y - camera.y) * zoom + viewH / 2;
    if (x > 80 && x < viewW - 80 && y > 100 && y < viewH - 155) return;
    const dx = x - viewW / 2, dy = y - viewH / 2, f = Math.min((viewW / 2 - 48) / Math.max(Math.abs(dx), 1), (viewH / 2 - 110) / Math.max(Math.abs(dy), 1));
    x = viewW / 2 + dx * f; y = viewH / 2 + dy * f; g.save(); g.translate(x, y); g.rotate(Math.atan2(dy, dx)); polygon(g, [[12 + Math.sin(time * 2) * 2, 0], [-6, -7], [-2, 0], [-6, 7]], '#e9d398'); g.restore();
  }
  function render(now, dt) {
    const g = ctx, time = now / 1000, p = campaign.player, halfW = viewW / zoom / 2, halfH = viewH / zoom / 2;
    g.setTransform(dpr, 0, 0, dpr, 0, 0); g.fillStyle = '#657d67'; g.fillRect(0, 0, viewW, viewH);
    if (campaign.mode !== 'menu') { const follow = 1 - Math.exp(-8.36 * dt); camera.x += (p.x - camera.x) * follow; camera.y += (p.y - camera.y) * follow; }
    const shake = reducedEffects ? 0 : campaign.screenShake;
    const sx = Math.sin(time * 61) * shake, sy = Math.cos(time * 73) * shake * .65;
    g.save(); g.translate(viewW / 2 + sx, viewH / 2 + sy); g.scale(zoom, zoom); g.translate(-camera.x, -camera.y);
    if (terrain) g.drawImage(terrain.canvas, -terrain.pad, -terrain.pad, W + terrain.pad * 2, H + terrain.pad * 2);
    sceneArt.groundMotion(g, campaign, reducedEffects ? time * .4 : time, onScreen);
    drawObjects(g, time); drawWarnings(g);
    combatArt.charge(g, p, reducedEffects);
    for (const e of campaign.effects) if (e.type === 'dashGhost' && onScreen(e.x, e.y)) combatArt.effect(g, e, reducedEffects, art, time);
    for (const item of campaign.loot) if (onScreen(item.x, item.y)) { ellipse(g, item.x, item.y, 8, 3, '#274d3c50'); g.fillStyle = '#d4d0b0'; g.fillRect(item.x - 5, item.y - 10, 10, 9); g.fillStyle = '#6d9b79'; g.fillRect(item.x - 2, item.y - 8, 4, 6); }
    const actors = [...campaign.enemies.map(a => [a, 'enemy']), ...campaign.allies.map(a => [a, 'ally']), ...campaign.civilians.map(a => [a, 'civil']), [p, 'hero']];
    if (campaign.stage === 'village' && !campaign.flags.civilians) for (let i = 0; i < 3; i++) actors.push([{ id: 1000 + i, x: 290 + i * 28, y: 405 + i % 2 * 15, r: 11, hp: 85, maxHp: 85, dir: .5, moving: false }, 'civil']);
    if (campaign.stage === 'village' && !campaign.flags.civilians) actors.push([{ id: 7, x: 380, y: 375, hp: 100, maxHp: 100, dir: 1.5, moving: false }, 'civil']);
    if (campaign.stage === 'house' && !campaign.flags.mother) actors.push([{ id: 1001, x: 1117, y: 462, hp: 80, maxHp: 80, dir: 2.3, moving: false, injured: true }, 'civil']);
    if (campaign.stage === 'house' && campaign.flags.healer && !campaign.flags.mother && !campaign.rescue) actors.push([{ id: 7, x: 1180, y: 475, hp: 100, maxHp: 100, dir: 2.5, moving: false }, 'civil']);
    if (campaign.rescue) actors.push([campaign.rescue.healer, 'civil']);
    const depth = [...actors.filter(([a]) => onScreen(a.x, a.y)).map(([a, role]) => ({ y: a.y, actor: a, role })), ...scenery.filter(a => onScreen(a.x, a.y, 180)).map(a => ({ y: a.y, scenery: a })), ...campaign.props.filter(a => onScreen(a.x, a.y)).map(a => ({ y: a.y, prop: a }))].sort((a, b) => a.y - b.y);
    for (const item of depth) if (item.scenery) drawScenery(g, item.scenery); else if (item.prop) combatArt.prop(g, item.prop, time); else {
      if (item.role === 'hero') art.hero(g, item.actor, time, 1.08, campaign.flags.adou);
      else {
        art.unit(g, item.actor, item.role, time);
        if (item.role === 'enemy') combatArt.enemyCharge(g, item.actor, reducedEffects, time);
      }
    }
    for (const arrow of campaign.projectiles) combatArt.projectile(g, arrow);
    if (campaign.rescue) { const h = campaign.rescue.healer; g.fillStyle = '#22372d'; g.fillRect(h.x - 24, h.y - 62, 48, 4); g.fillStyle = '#bcdbb0'; g.fillRect(h.x - 24, h.y - 62, 48 * h.hp / h.maxHp, 4); }
    drawEffects(g);
    if (campaign.mode === 'menu') { const x = camera.x + halfW * .48, y = camera.y + 68; drawFlag(g, x + 80, y - 30, '赵', '#335c51', time); art.hero(g, { ...p, x, y, dir: -.4, moving: false }, time, 2.9); }
    sceneArt.atmosphere(g, camera, viewW / zoom, viewH / zoom, time, campaign.definition.mood, reducedEffects); g.restore();
    const vignette = g.createRadialGradient(viewW / 2, viewH / 2, viewH * .25, viewW / 2, viewH / 2, Math.max(viewW, viewH) * .67); vignette.addColorStop(0, '#10261900'); vignette.addColorStop(1, '#0b24195d'); g.fillStyle = vignette; g.fillRect(0, 0, viewW, viewH); drawNavigation(g, time);
  }
  function frame(now) {
    const dt = Math.min((now - lastFrame) / 1000, .04); lastFrame = now;
    let simDt = dt;
    if (campaign.mode === 'playing' && campaign.hitStop > 0) { const held = Math.min(dt, campaign.hitStop); campaign.hitStop -= held; if (!reducedEffects) simDt -= held; }
    if (simDt > 0) campaign.step(simDt, inputState()); processEvents(); render(now, dt);
    toastTimer -= dt; commandTimer -= dt; stageTimer -= dt; if (campaign.mode === 'playing') encounterTimer -= dt;
    if (toastTimer <= 0) $('toast').classList.add('hidden'); if (commandTimer <= 0) $('commandBanner').classList.remove('show'); if (stageTimer <= 0) $('stageBanner').classList.add('hidden');
    if (encounterTimer <= 0) $('encounterBanner').classList.add('hidden');
    hudClock += dt; if (hudClock >= .1) { hudClock = 0; if (campaign.mode !== 'menu') updateHud(); } requestAnimationFrame(frame);
  }
  window.addEventListener('resize', resize);
  async function boot() {
    resize(); buildTerrain(); refreshSaveMenu();
    $('menuControls').textContent = 'WASD 移动 · J / 左键出枪 · 空格闪避 · E 互动\nQ / 右键破阵 · R 青釭 · M 军图 · Esc 暂停'; $('pauseControls').textContent = desktopHelp;
    $('effectsButton').textContent = '技能特效：' + (reducedEffects ? '柔和（减弱光效与震屏）' : '完整');
    try { await art.loadCharacters(); } catch (error) { $('loading').textContent = '角色素材未能载入，请重新打开游戏。'; console.error(error); return; }
    // Discard construction events; show the region only after entering gameplay.
    campaign.events = []; $('loading').classList.add('hidden'); lastFrame = performance.now(); requestAnimationFrame(frame);
  }
  boot();
})();
