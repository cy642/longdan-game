/* Short, bounded effects. Their geometry follows the real attack range/direction. */
(() => {
  'use strict';
  const TAU = Math.PI * 2, clamp = n => Math.max(0, Math.min(1, n));
  const colors = { thrust1: '#83dce9', thrust2: '#a6edf3', thrust3: '#f7d990', counter: '#c0fbff', sweep: '#f2ca75', sword: '#65e4dd' };
  function line(g, pts, color, width = 1) { g.beginPath(); pts.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.strokeStyle = color; g.lineWidth = width; g.stroke(); }
  function poly(g, pts, color) { g.beginPath(); pts.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); g.fillStyle = color; g.fill(); }
  function glow(g, x, y, radius, color, opacity = .5) {
    const light = g.createRadialGradient(x, y, 0, x, y, radius); light.addColorStop(0, color); light.addColorStop(1, color + '00');
    g.save(); g.globalAlpha *= opacity; g.fillStyle = light; g.fillRect(x - radius, y - radius, radius * 2, radius * 2); g.restore();
  }
  function arc(g, radius, start, end, color, width) { g.beginPath(); g.arc(0, 0, radius, start, end); g.strokeStyle = color; g.lineWidth = width; g.stroke(); }
  function crescent(g, radius, start, end, color, thickness) {
    g.beginPath(); g.arc(0, 0, radius, start, end); g.arc(0, 0, Math.max(1, radius - thickness), end, start, true); g.closePath(); g.fillStyle = color; g.fill();
  }
  function charge(g, p, reduced) {
    const a = p.action; if (!a || !['sweep', 'sword', 'counter', 'thrust3'].includes(a.key) || a.t >= a.def.windup) return;
    const t = clamp(a.t / a.def.windup), color = colors[a.key], radius = a.key === 'sword' ? 62 : 38;
    g.save(); g.translate(p.x, p.y - 29); g.globalAlpha = .24 + t * .5;
    glow(g, 0, 0, radius, color, reduced ? .16 : .32);
    for (let i = 0; i < (reduced ? 3 : 7); i++) {
      const angle = i * TAU / 7 + t * 1.4, r = radius * (1 - t * .6);
      line(g, [[Math.cos(angle) * r, Math.sin(angle) * r * .6], [Math.cos(angle) * (r + 9), Math.sin(angle) * (r + 9) * .6]], color, 1.5);
    }
    g.rotate(a.dir); line(g, [[17, -4], [35 + t * 35, -4]], '#e6ffff', 1 + t * 2); g.restore();
  }
  function dragon(g, radius, t, color) {
    // A flowing dragon-shaped energy spine, horns and whiskers, all inside range.
    const nose = radius * (.62 + t * .32), wave = Math.sin(t * Math.PI);
    for (const [width, opacity] of [[24, .08], [12, .16], [5, .65], [1.5, .9]]) {
      g.save(); g.globalAlpha *= opacity; g.beginPath(); g.moveTo(12, 22);
      g.bezierCurveTo(radius * .23, -68 * wave, radius * .4, 47 * wave, radius * .6, -7);
      g.bezierCurveTo(radius * .72, -26, nose - 22, -13, nose, -8);
      g.strokeStyle = color; g.lineWidth = width; g.stroke(); g.restore();
    }
    poly(g, [[nose + 7, -8], [nose - 5, -18], [nose - 20, -22], [nose - 14, -8], [nose - 23, 3], [nose - 6, -1]], '#ceffff');
    line(g, [[nose - 17, -16], [nose - 29, -37], [nose - 22, -29]], color, 2);
    line(g, [[nose - 9, -17], [nose - 14, -33], [nose - 8, -28]], color, 2);
    g.beginPath(); g.moveTo(nose, -4); g.quadraticCurveTo(nose + 14, 12, nose - 18, 23); g.strokeStyle = '#c5ffff'; g.lineWidth = 1; g.stroke();
    g.fillStyle = '#1c9794'; g.fillRect(nose - 8, -13, 3, 2);
  }
  function threatPath(g, radius, angle, travel) {
    g.beginPath(); g.moveTo(0, 0);
    g.lineTo(Math.cos(-angle) * radius, Math.sin(-angle) * radius);
    if (travel > 0) g.lineTo(travel + Math.cos(-angle) * radius, Math.sin(-angle) * radius);
    g.arc(travel, 0, radius, -angle, angle);
    if (travel > 0) g.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
    g.closePath();
  }
  function warning(g, enemy, threat) {
    if (!threat) return;
    const a = enemy.action, active = threat.state === 'active';
    g.save(); g.translate(enemy.x, enemy.y);
    if (threat.state === 'recovery') {
      if (threat.opening && enemy.type !== 'archer') {
        g.strokeStyle = '#a5dec4'; g.lineWidth = 1.5; g.beginPath(); g.ellipse(0, 3, 23, 8, 0, 0, TAU); g.stroke();
        g.font = '11px Microsoft YaHei'; g.textAlign = 'center'; g.fillStyle = '#d0ecd2'; g.fillText('收招 · 可反击', 0, 25);
      }
      g.restore(); return;
    }
    g.save(); if (enemy.type === 'archer') g.translate(0, -8); g.rotate(a.dir);
    const fill = active ? '#d0524040' : threat.imminent ? '#d9724a40' : '#a943352a';
    const stroke = active ? '#f4a086' : threat.imminent ? '#ffd395' : '#dd8b6cc0';
    if (enemy.type === 'archer') {
      g.fillStyle = fill; g.fillRect(0, -threat.laneWidth, threat.radius, threat.laneWidth * 2);
      if (threat.tracking) g.setLineDash([6, 5]);
      line(g, [[0, 0], [threat.radius, 0]], stroke, 1.5);
      g.setLineDash([8, 8]); line(g, [[0, -threat.laneWidth], [threat.radius, -threat.laneWidth]], '#d48c6866');
      line(g, [[0, threat.laneWidth], [threat.radius, threat.laneWidth]], '#d48c6866');
    } else {
      threatPath(g, threat.radius, threat.arc, threat.travel); g.fillStyle = fill; g.fill();
      g.strokeStyle = stroke; g.lineWidth = active || threat.imminent ? 2 : 1;
      if (threat.tracking) g.setLineDash([6, 5]); g.stroke();
      g.setLineDash([]);
      if (threat.travel > 0) {
        line(g, [[20, 0], [threat.travel + 28, 0]], '#e5ac8670', 1.5);
        poly(g, [[threat.travel + 30, 0], [threat.travel + 20, -5], [threat.travel + 20, 5]], '#e5ac86aa');
      }
    }
    g.restore();
    g.fillStyle = '#192c26ee'; g.fillRect(-22, 10, 44, 3); g.fillStyle = stroke; g.fillRect(-22, 10, 44 * threat.progress, 3);
    if (enemy.type !== 'boss') { g.fillStyle = '#f2c6a2'; g.font = '10px Microsoft YaHei'; g.textAlign = 'center'; g.fillText(active ? '出手' : enemy.type === 'archer' ? '弓射 · 留意箭路' : threat.imminent ? '将出手' : '蓄力', 0, 27); }
    g.restore();
  }
  function propWarning(g, prop, playerRadius) {
    if (prop.spent || prop.fuse == null) return;
    const radius = prop.blastRadius + playerRadius, progress = 1 - prop.fuse / prop.fuseTime;
    g.save(); g.translate(prop.x, prop.y); g.fillStyle = '#b84b362f'; g.strokeStyle = '#f1a578'; g.lineWidth = 2;
    g.beginPath(); g.arc(0, 0, radius, 0, TAU); g.fill(); g.stroke();
    arc(g, radius - 4, -Math.PI / 2, -Math.PI / 2 + TAU * progress, '#ffd293', 3);
    g.textAlign = 'center'; g.font = 'bold 12px Microsoft YaHei'; g.fillStyle = '#ffe0a8'; g.fillText('油车将爆 · 闪开红圈', 0, -75); g.restore();
  }
  function prop(g, item, time) {
    g.save(); g.translate(item.x, item.y);
    g.fillStyle = '#1e302653'; g.beginPath(); g.ellipse(0, 5, 40, 13, 0, 0, TAU); g.fill();
    if (item.spent) {
      for (let i = 0; i < 6; i++) { g.save(); g.translate((i - 2.5) * 9, i % 2 * 9); g.rotate(i * 1.7); g.fillStyle = i % 2 ? '#524638' : '#302e28'; g.fillRect(-12, -2, 23, 4); g.restore(); }
      g.strokeStyle = '#564939'; g.lineWidth = 4; g.beginPath(); g.arc(20, 5, 11, .4, 5.1); g.stroke(); g.restore(); return;
    }
    for (const x of [-29, 29]) {
      g.fillStyle = '#3c3329'; g.beginPath(); g.ellipse(x, 0, 9, 16, 0, 0, TAU); g.fill();
      g.strokeStyle = '#94784f'; g.lineWidth = 2; g.stroke(); line(g, [[x - 5, -10], [x + 5, 10]], '#806d48', 2);
    }
    poly(g, [[-32, -29], [22, -34], [33, -8], [-25, 0]], '#79613e');
    poly(g, [[-25, 0], [33, -8], [33, 4], [-25, 11]], '#5a472e');
    line(g, [[-30, -26], [24, -31]], '#b19460', 2); line(g, [[-25, 1], [33, -7]], '#b19460', 2);
    for (const [x, y] of [[-13, -28], [10, -34]]) {
      g.fillStyle = '#7d4435'; g.beginPath(); g.ellipse(x, y, 13, 16, -.1, 0, TAU); g.fill();
      line(g, [[x - 11, y], [x + 11, y - 2]], '#b29062', 3); g.fillStyle = '#35372b'; g.fillRect(x - 5, y - 16, 10, 5);
      g.textAlign = 'center'; g.fillStyle = '#edd2a3'; g.font = '11px KaiTi,serif'; g.fillText('油', x, y + 3);
    }
    if (item.fuse != null) {
      glow(g, 0, -35, 40, '#ffd291', .23);
      for (let i = 0; i < 3; i++) { const sway = Math.sin(time * 16 + i) * 4, x = (i - 1) * 10;
        poly(g, [[x - 8, -28], [x + sway, -56 - i % 2 * 8], [x + 8, -28]], '#efad62');
        poly(g, [[x - 4, -28], [x + sway * .5, -46], [x + 4, -28]], '#fff0aa'); }
    } else { g.textAlign = 'center'; g.font = '11px Microsoft YaHei'; g.fillStyle = '#efcc9e'; g.fillText('油车 · 出枪引爆', 0, -59); }
    g.restore();
  }
  function effect(g, e, reduced, art, time) {
    const t = clamp(1 - e.life / e.maxLife), fade = 1 - t;
    if (!['slash', 'impact', 'shockwave', 'dashGhost', 'cast', 'perfect', 'shatter', 'explosion'].includes(e.type)) return false;
    g.save(); g.translate(e.x, e.y); g.lineCap = 'round'; g.lineJoin = 'round';
    if (e.type === 'dashGhost') {
      g.globalAlpha = fade * (reduced ? .13 : .3);
      art.hero(g, { ...e.pose, x: 0, y: 0, hurtFlash: 0, invincible: 0 }, time, 1.08, e.adou);
      g.rotate(e.dir); g.globalAlpha = fade * .65;
      for (let i = -1; i <= 1; i++) line(g, [[-10, i * 11 - 15], [-29 - t * 18, i * 13 - 15]], '#a9e7e9', 1.5);
    } else if (e.type === 'slash') {
      const key = e.key || 'thrust1', color = colors[key], radius = e.radius;
      g.translate(0, -30); g.rotate(e.dir); g.globalAlpha = Math.pow(fade, .65);
      if (key === 'sweep' || key === 'thrust3') {
        const progress = 1 - Math.pow(1 - t, 2), head = -e.arc + e.arc * 2 * Math.min(1, .32 + progress);
        const tail = Math.max(-e.arc, head - (key === 'sweep' ? 3.3 : 1.7));
        if (!reduced) crescent(g, radius * .96, tail, head, color + '30', 27);
        crescent(g, radius * .92, tail + .1, head, color + 'a8', 9 * fade + 3);
        arc(g, radius * .94, tail + .22, head, '#fff6d5', 2.6);
        arc(g, radius * .7, tail + .16, head - .1, color + '80', 1.5);
        const x = Math.cos(head) * radius * .92, y = Math.sin(head) * radius * .92;
        if (!reduced) glow(g, x, y, 30, color, .65);
        for (let i = 0; i < (reduced ? 3 : 9); i++) {
          const a = tail + (head - tail) * i / 9, r = radius * (.66 + .24 * t);
          line(g, [[Math.cos(a) * r, Math.sin(a) * r], [Math.cos(a + .08) * (r - 14), Math.sin(a + .08) * (r - 14)]], '#ffedb9', 1.4);
        }
      } else if (key === 'sword') {
        if (!reduced) glow(g, radius * .4, 0, radius * .65, color, .24);
        for (let i = 0; i < (reduced ? 2 : 4); i++) {
          const angle = (i - 1.5) * .19; g.save(); g.rotate(angle);
          poly(g, [[17, 0], [radius * .55, -8 - i], [radius * (.94 - i * .06), -2], [radius * .5, 6]], color + (i % 2 ? '88' : '44')); g.restore();
        }
        crescent(g, radius * (.74 + t * .25), -e.arc + t * .6, e.arc, '#b9fff559', 14 * fade + 2);
        arc(g, radius * (.74 + t * .25), -e.arc + t * .6, e.arc, '#d9ffea', 2);
        dragon(g, radius, t, color);
      } else {
        const end = radius * (.64 + Math.min(1, t * 2) * .34), wide = key === 'counter' ? 13 : key === 'thrust2' ? 10 : 7;
        if (!reduced) poly(g, [[8, 0], [end - 28, -wide * 1.6], [end + 2, 0], [end - 28, wide * 1.6]], color + '35');
        poly(g, [[13, 0], [end - 25, -wide * .55], [end, 0], [end - 25, wide * .55]], color + 'd0');
        line(g, [[25, 0], [end, 0]], '#edffff', key === 'counter' ? 3.5 : 2);
        for (const side of [-1, 1]) line(g, [[end * .35, side * 9], [end * .8, side * 5]], color + 'c0', 1);
        if (!reduced) glow(g, end - 10, 0, 24, color, .65);
      }
    } else if (e.type === 'impact' || e.type === 'shatter') {
      g.translate(0, -21); g.rotate(e.dir || 0); const color = e.color || '#fff0ba';
      g.globalAlpha = fade; if (!reduced) glow(g, 0, 0, 35 + t * 12, color, .65 * fade);
      for (let i = 0; i < (reduced ? 4 : e.type === 'shatter' ? 12 : 7); i++) {
        const angle = i * 2.399 + (e.seed || 0), distance = (8 + i % 4 * 4) + t * (20 + i % 3 * 16);
        const x = Math.cos(angle) * distance, y = Math.sin(angle) * distance * .8;
        line(g, [[x, y], [x + Math.cos(angle) * (6 + fade * 9), y + Math.sin(angle) * (6 + fade * 9)]], i % 2 ? '#fffce5' : color, i % 2 ? 1.2 : 2.4);
      }
      if (t < .35) { g.globalAlpha *= 1 - t / .35; poly(g, [[-18, 0], [-3, -3], [0, -24], [3, -3], [22, 0], [3, 3], [0, 18], [-3, 3]], '#fffcea'); }
    } else if (e.type === 'shockwave' || e.type === 'perfect') {
      const color = e.color || '#a9f0ee', radius = e.radius * (.2 + .8 * (1 - Math.pow(fade, 2)));
      g.globalAlpha = fade * (reduced ? .4 : .7); g.scale(1, .6);
      for (let i = 0; i < 2; i++) arc(g, Math.max(1, radius - i * 9), 0, TAU, color, i ? 1 : 3 * fade + .5);
      if (e.type === 'perfect') for (let i = 0; i < 8; i++) { const angle = i * TAU / 8; line(g, [[Math.cos(angle) * radius, Math.sin(angle) * radius], [Math.cos(angle) * (radius + 8), Math.sin(angle) * (radius + 8)]], '#efffff', 2); }
    } else if (e.type === 'explosion') {
      const radius = e.radius * (.2 + .8 * (1 - Math.pow(fade, 3)));
      g.globalAlpha = fade * .7; if (!reduced) glow(g, 0, -15, radius * .7, '#ffd193', .34 * fade);
      arc(g, radius, 0, TAU, '#f9c083', 7 * fade + 1);
      for (let i = 0; i < (reduced ? 6 : 15); i++) {
        const angle = i * 2.399, distance = radius * (.45 + i % 4 * .15), x = Math.cos(angle) * distance, y = Math.sin(angle) * distance;
        line(g, [[x, y], [x + Math.cos(angle) * (10 + fade * 12), y + Math.sin(angle) * (10 + fade * 12)]], i % 2 ? '#f8c08a' : '#fff2ba', 2 * fade + 1);
      }
    } else if (e.type === 'cast') {
      // Local calligraphy avoids a full-screen flash or obscuring enemy telegraphs.
      g.globalAlpha = Math.min(1, t * 10) * Math.min(1, fade * 3); g.translate(0, -102 - t * 14);
      g.textAlign = 'center'; g.font = 'bold 22px KaiTi, STKaiti, serif'; g.shadowColor = '#103b3b'; g.shadowBlur = 5; g.fillStyle = e.color;
      g.fillText(e.text, 0, 0); g.shadowBlur = 0; line(g, [[-44, 9], [44, 9]], e.color + '88');
    }
    g.restore(); return true;
  }
  globalThis.LongdanCombatArt = { charge, effect, colors, warning, propWarning, prop, threatPath };
})();
