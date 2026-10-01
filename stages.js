(() => {
  'use strict';
  const W = 1600, H = 1100;
  // Each region owns its scenery, encounters, exits and persistent event IDs.
  // Add a new definition and exit to extend the campaign without changing input.
  const StageDefinition = {
    mountain: {
      name: '溃军山道', chapter: '一 · 记忆醒来', seed: 13, mood: 'forest', spawn: [190, 910],
      roads: [[[160, 940], [550, 840], [700, 590], [1080, 410], [1190, 210]]], huts: [],
      objects: [{ id: 'campMountain', kind: 'camp', x: 1180, y: 230, label: '山道营火' },
        { id: 'toVillage', kind: 'exit', x: 1350, y: 180, label: '前往荒村', to: 'village', need: 'mountain' }],
      groups: [
        { id: 'm1', units: [['sword', 545, 835]] },
        { id: 'm2', units: [['sword', 765, 595], ['spear', 830, 530]] },
        { id: 'm3', units: [['spear', 1070, 395], ['archer', 1150, 330]] },
      ], tutorial: '移动接近敌人，出枪可接三式。红色蓄力结束时闪避，抓住收招出枪。',
    },
    village: {
      name: '荒村小巷', chapter: '二 · 人间烟火', seed: 31, mood: 'village', spawn: [180, 940],
      roads: [[[140, 960], [530, 860], [830, 680], [1080, 380], [1380, 190]], [[600, 800], [430, 550], [310, 330]]],
      huts: [[405, 810, 140, 100, 'hut'], [690, 845, 130, 95, 'hut'], [880, 435, 142, 100, 'hut'], [1180, 470, 120, 95, 'ruin'], [220, 265, 125, 98, 'ruin']],
      objects: [{ id: 'civilians', kind: 'rescue', x: 330, y: 405, label: '被困医者与百姓', group: 'vRescue' },
        { id: 'toTemple', kind: 'exit', x: 1390, y: 190, label: '前往破庙', to: 'temple', group: 'v3' },
        { id: 'backMountain', kind: 'exit', x: 110, y: 970, label: '返回山道', to: 'mountain' }],
      groups: [
        { id: 'v1', units: [['sword', 525, 855], ['archer', 655, 730], ['shield', 730, 785]] },
        { id: 'v2', units: [['spear', 890, 625], ['sword', 1050, 580], ['archer', 1100, 650]] },
        { id: 'v3', units: [['shield', 1220, 295], ['sword', 1300, 275]] },
        { id: 'vRescue', units: [['sword', 390, 485], ['shield', 450, 430], ['archer', 450, 330]] },
      ], tutorial: '弓手会被房屋遮挡。先绕开盾兵，再切进弓手身侧。西巷传来求救声。',
    },
    temple: {
      name: '破庙夺剑', chapter: '三 · 青釭初鸣', seed: 77, mood: 'temple', spawn: [230, 930],
      roads: [[[180, 960], [420, 820], [720, 670], [1040, 560]], [[1080, 450], [1380, 240]]],
      huts: [[300, 610, 155, 120, 'ruin'], [1330, 635, 165, 130, 'ruin']],
      arena: { x: 960, y: 480, rx: 380, ry: 270 }, boss: 'xiahou',
      objects: [{ id: 'campTemple', kind: 'camp', x: 410, y: 850, label: '破庙营火' },
        { id: 'xiahouGate', kind: 'boss', x: 605, y: 660, label: '夏侯恩 · 入阵单挑', group: 't1' },
        { id: 'toHouse', kind: 'exit', x: 1410, y: 245, label: '前往井畔旧宅', to: 'house', need: 'temple' },
        { id: 'shortcut', kind: 'exit', x: 315, y: 440, label: '荒村侧门捷径', to: 'village', need: 'temple' },
        { id: 'backVillage', kind: 'exit', x: 145, y: 980, label: '返回荒村', to: 'village' }],
      groups: [{ id: 't1', units: [['sword', 500, 765], ['spear', 570, 725]] }],
      tutorial: '营火补满药与体力。夏侯恩出剑有快有慢，看清第二剑再反击。',
    },
    house: {
      name: '井畔旧宅', chapter: '四 · 井边逆命', seed: 52, mood: 'house', spawn: [200, 930],
      roads: [[[170, 960], [570, 800], [830, 520], [1060, 410], [1400, 200]], [[680, 630], [550, 430], [420, 300]]],
      huts: [[1110, 275, 170, 132, 'ruin'], [940, 370, 135, 105, 'hut'], [410, 610, 130, 90, 'ruin']],
      objects: [{ id: 'adou', kind: 'story', x: 1090, y: 470, label: '阿斗与糜夫人', group: 'h2' },
        { id: 'toFork', kind: 'exit', x: 1400, y: 205, label: '前往粮道岔口', to: 'fork', need: 'house' },
        { id: 'backTemple', kind: 'exit', x: 140, y: 985, label: '返回破庙', to: 'temple' }],
      groups: [{ id: 'h1', units: [['sword', 565, 785], ['spear', 700, 655], ['archer', 740, 770]] },
        { id: 'h2', units: [['shield', 900, 535], ['sword', 1140, 535], ['archer', 1210, 395]] }],
      tutorial: '旧宅里有你记得的哭声。若在荒村救出医者，这次就能多救一个人。',
    },
    fork: {
      name: '粮道岔口', chapter: '五 · 断粮破阵', seed: 94, mood: 'camp', spawn: [210, 920],
      roads: [[[160, 970], [610, 780], [800, 580], [950, 300], [1330, 180]], [[710, 660], [1070, 730], [1310, 750]]],
      huts: [[1190, 900, 130, 90, 'tent'], [1420, 695, 120, 95, 'tent']],
      objects: [{ id: 'supplies', kind: 'supplies', x: 1280, y: 775, label: '粮营 · 盾阵校尉', group: 'fSupply' },
        { id: 'toBridge', kind: 'exit', x: 1330, y: 180, label: '整军前往北桥', to: 'bridge', group: 'f1', need: 'house' },
        { id: 'backHouse', kind: 'exit', x: 145, y: 980, label: '返回旧宅', to: 'house' }],
      groups: [{ id: 'f1', units: [['spear', 750, 555], ['sword', 940, 425], ['archer', 960, 345]] },
        { id: 'fSupply', units: [['shield', 1090, 780], ['sword', 1190, 700], ['archer', 1360, 850]] }],
      tutorial: '北面是退路，东面是粮营。焚粮会撤走北桥弓阵，并打开侧道。',
    },
    bridge: {
      name: '北桥决战', chapter: '六 · 一枪开生路', seed: 125, mood: 'river', spawn: [240, 930],
      roads: [[[185, 980], [500, 790], [700, 665], [920, 485], [1220, 290], [1280, 105]]],
      huts: [[200, 585, 145, 100, 'tent']], arena: { x: 925, y: 480, rx: 340, ry: 245 }, boss: 'zhanghe',
      objects: [{ id: 'campBridge', kind: 'camp', x: 300, y: 940, label: '桥前营火' },
        { id: 'zhangheGate', kind: 'boss', x: 630, y: 680, label: '张郃 · 断后单挑', group: 'b1' },
        { id: 'exit', kind: 'finish', x: 1280, y: 105, label: '渡桥与刘备会合', need: 'boss' }],
      groups: [{ id: 'b1', units: [['sword', 470, 790], ['spear', 520, 740], ['shield', 600, 735]] },
        { id: 'bArchers', unless: 'supplies', units: [['archer', 665, 750], ['archer', 540, 600]] }],
      tutorial: '发布军令，让三名随军牵住敌人。清开桥头后，独自接下张郃的长枪。',
    },
  };
  const AttackDefinition = {
    thrust1: { name: '龙枪一式', windup: .09, active: .11, recovery: .22, range: 123, arc: .68, damage: 25, stagger: 10 },
    thrust2: { name: '龙枪二式', windup: .12, active: .13, recovery: .24, range: 132, arc: .95, damage: 28, stagger: 12 },
    thrust3: { name: '龙枪三式', windup: .2, active: .16, recovery: .4, range: 145, arc: 1.35, damage: 40, stagger: 22 },
    counter: { name: '回马枪', windup: .06, active: .15, recovery: .23, range: 166, arc: .95, damage: 48, stagger: 32 },
    sweep: { name: '横扫破阵', windup: .18, active: .18, recovery: .4, range: 170, arc: Math.PI, damage: 42, stagger: 34 },
    sword: { name: '青釭断势', windup: .24, active: .17, recovery: .42, range: 200, arc: 1.7, damage: 100, stagger: 66 },
    heal: { name: '行军药', windup: .95, active: .02, recovery: .18, range: 0, arc: 0, damage: 0, stagger: 0 },
    cut: { name: '斩击', windup: .56, active: .12, recovery: .65, range: 87, arc: 1, damage: 15 },
    spear: { name: '突刺', windup: .7, active: .14, recovery: .8, range: 145, arc: .45, damage: 18 },
    arrow: { name: '弓射', windup: .9, active: .04, recovery: 1.5, range: 470, arc: .05, damage: 14 },
    shield: { name: '盾击', windup: .85, active: .16, recovery: .95, range: 95, arc: 1.1, damage: 19 },
  };
  globalThis.LongdanDefinitions = { StageDefinition, AttackDefinition, W, H };
})();
