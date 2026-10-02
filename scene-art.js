/* Region artwork is cached at entry. Animated details use world coordinates. */
(() => {
  'use strict';
  const TAU = Math.PI * 2;
  const palettes = {
    forest: { top: '#84966b', bottom: '#456e59', path: '#c5b68b', edge: '#53694d', light: '#e7dca8', grass: '#2d5a43', mist: '#c6ddbc' },
    village: { top: '#ad9c75', bottom: '#727b56', path: '#c7ae81', edge: '#766b49', light: '#eed3a1', grass: '#536443', mist: '#dfc49b' },
    temple: { top: '#829b90', bottom: '#4d746c', path: '#a5b2a0', edge: '#506c60', light: '#d5e6cd', grass: '#345e51', mist: '#bad9d7' },
    house: { top: '#9eac84', bottom: '#587b64', path: '#c6be96', edge: '#66734f', light: '#efdfb3', grass: '#3c654d', mist: '#d9dfbf' },
    camp: { top: '#b39a6c', bottom: '#81764f', path: '#ceb185', edge: '#806746', light: '#f4d899', grass: '#64673e', mist: '#e4c192' },
    river: { top: '#819b94', bottom: '#4f756a', path: '#b6b493', edge: '#5c7260', light: '#d5e3c3', grass: '#375e52', mist: '#c3dcdb' },
  };
  function seeded(seed) { return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }; }
  function oval(g, x, y, rx, ry, color) { g.fillStyle = color; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill(); }
  function stroke(g, points, color, width = 1) { g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.strokeStyle = color; g.lineWidth = width; g.stroke(); }
  function poly(g, points, color) { g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); g.fillStyle = color; g.fill(); }
  function wash(g, x, y, radius, color) {
    const gradient = g.createRadialGradient(x, y, 0, x, y, radius); gradient.addColorStop(0, color); gradient.addColorStop(1, color.slice(0, 7) + '00');
    g.fillStyle = gradient; g.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }
  function slab(g, x, y, w, h, rnd, mood) {
    const colors = mood === 'temple' ? ['#9cae9f', '#94a69b', '#a3b0a0', '#93a699'] : ['#adb093', '#aaa98e', '#b5b89b', '#a2ab91'];
    g.fillStyle = '#354f493a'; g.fillRect(x + 2, y + 3, w, h);
    poly(g, [[x + .7, y], [x + w - .8, y + .5], [x + w, y + h - .7], [x + .8, y + h]], colors[Math.floor(rnd() * colors.length)]);
    stroke(g, [[x + 4, y + 2], [x + w - 5, y + 2]], '#e3e6c53b');
    if (rnd() < .26) stroke(g, [[x + w * .7, y + 1], [x + w * .5, y + h * .45], [x + w * .6, y + h]], '#405e514f');
    if (rnd() < .2) oval(g, x + 3, y + h - 2, 5, 2, '#5b806a80');
  }
  function paving(g, x, y, w, h, rnd, mood) {
    g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip(); g.fillStyle = '#758d7f'; g.fillRect(x, y, w, h);
    for (let row = 0; row < h / 29; row++) for (let col = -1; col < w / 52; col++) {
      slab(g, x + col * 52 + row % 2 * 26, y + row * 29, 50.5, 27.5, rnd, mood);
    }
    g.restore();
  }
  function wheel(g, x, y, radius) {
    oval(g, x + 3, y + 5, radius + 3, radius * .55, '#253e363e');
    g.save(); g.translate(x, y); g.scale(1, .57); g.strokeStyle = '#5c513b'; g.lineWidth = 4;
    g.beginPath(); g.arc(0, 0, radius, 0, TAU); g.stroke();
    for (let i = 0; i < 6; i++) stroke(g, [[0, 0], [Math.cos(i * TAU / 6) * radius, Math.sin(i * TAU / 6) * radius]], '#b09b6d', 2);
    oval(g, 0, 0, 3, 3, '#6a6248'); g.restore();
  }
  function rubble(g, x, y, rnd) {
    for (let i = 0; i < 18; i++) {
      const px = x + (rnd() - .5) * 85, py = y + (rnd() - .5) * 40, r = 3 + rnd() * 7;
      poly(g, [[px - r, py], [px - r * .5, py - r * .55], [px + r, py - r * .25], [px + r * .8, py + 3]], i % 2 ? '#697a6e' : '#b2b79b');
    }
  }
  function landscape(scene, W, H, ratio) {
    const pad = 600, canvas = document.createElement('canvas');
    canvas.width = Math.round((W + pad * 2) * ratio); canvas.height = Math.round((H + pad * 2) * ratio);
    const g = canvas.getContext('2d'); g.scale(ratio, ratio); g.translate(pad, pad);
    const rnd = seeded(scene.definition.seed * 971), mood = scene.definition.mood, p = palettes[mood];
    const base = g.createLinearGradient(0, 0, W * .6, H); base.addColorStop(0, p.top); base.addColorStop(1, p.bottom);
    g.fillStyle = base; g.fillRect(-pad, -pad, W + pad * 2, H + pad * 2);
    // Broad landforms, leaf litter and a grain tile keep the floor from feeling flat.
    for (let i = 0; i < 150; i++) wash(g, rnd() * (W + 600) - 300, rnd() * (H + 600) - 300, 45 + rnd() * 170, i % 3 ? p.grass + '29' : p.light + '21');
    const grain = document.createElement('canvas'); grain.width = grain.height = 192; const gg = grain.getContext('2d');
    for (let i = 0; i < 1250; i++) { gg.fillStyle = i % 3 ? '#152f2419' : '#f1eaca19'; gg.fillRect(rnd() * 192, rnd() * 192, 1 + rnd() * 2, 1); }
    g.fillStyle = g.createPattern(grain, 'repeat'); g.fillRect(-pad, -pad, W + pad * 2, H + pad * 2);
    for (const t of scene.trees) {
      wash(g, t.x, t.y, t.size * 1.8, '#254f3c37');
      oval(g, t.x + 15, t.y + 7, t.size * 1.2, t.size * .38, '#163d3625');
      for (let i = 0; i < 16; i++) oval(g, t.x + (rnd() - .5) * t.size * 2.6, t.y + (rnd() - .5) * t.size * 1.3, 2 + rnd() * 3, .9, i % 3 ? p.light + '55' : '#3d553e88');
    }
    const roads = [...scene.definition.roads];
    if (scene.stage === 'bridge' && scene.flags.supplies) roads.push([[300, 950], [850, 890], [1260, 730], [1270, 330]]);
    g.lineCap = 'round'; g.lineJoin = 'round';
    for (const road of roads) {
      for (const [width, color] of [[120, p.edge + '35'], [100, p.edge + '60'], [87, p.path], [64, p.light + '35'], [36, p.light + '17']]) stroke(g, road, color, width);
      for (let j = 1; j < road.length; j++) {
        const a = road[j - 1], b = road[j], dx = b[0] - a[0], dy = b[1] - a[1], length = Math.hypot(dx, dy), nx = -dy / length, ny = dx / length;
        for (const side of [-1, 1]) stroke(g, [[a[0] + nx * 21 * side, a[1] + ny * 21 * side], [b[0] + nx * 21 * side, b[1] + ny * 21 * side]], '#806d4931', 2);
        for (let t = 0; t < length; t += 9) {
          const x = a[0] + dx * t / length, y = a[1] + dy * t / length;
          for (const side of [-1, 1]) {
            const edge = (41 + rnd() * 9) * side;
            oval(g, x + nx * edge, y + ny * edge, 2 + rnd() * 4, 1 + rnd() * 2, p.path + '65');
          }
        }
        for (let t = 16; t < length; t += 23) {
          const x = a[0] + dx * t / length, y = a[1] + dy * t / length;
          oval(g, x + nx * (t % 46 ? 6 : -6), y + ny * (t % 46 ? 6 : -6), 2.4, 1.1, '#675b3e39');
          if (mood === 'temple' && t % 3 < 1) slab(g, x - 19, y - 9, 38, 18, rnd, mood);
        }
      }
    }
    for (const h of scene.huts) {
      oval(g, h.x, h.y + h.h * .3, h.w * .8, h.h * .65, '#7c78582e');
      if (mood !== 'camp') paving(g, h.x - h.w * .54, h.y + h.h * .38, h.w * 1.08, 35, rnd, mood);
    }
    if (scene.definition.arena) {
      const a = scene.definition.arena;
      if (mood === 'temple') {
        paving(g, a.x - a.rx, a.y - a.ry, a.rx * 2, a.ry * 2, rnd, mood);
        g.strokeStyle = '#dde1bd70'; g.lineWidth = 3; g.strokeRect(a.x - a.rx + 13, a.y - a.ry + 13, a.rx * 2 - 26, a.ry * 2 - 26);
        for (const radius of [76, 84, 142, 147]) { g.beginPath(); g.ellipse(a.x, a.y, radius, radius * .78, 0, 0, TAU); g.strokeStyle = '#43696355'; g.lineWidth = radius === 84 ? 4 : 1.5; g.stroke(); }
        for (let i = 0; i < 8; i++) {
          const angle = i * TAU / 8, x = a.x + Math.cos(angle) * 111, y = a.y + Math.sin(angle) * 86;
          g.save(); g.translate(x, y); g.rotate(angle); for (let k = -1; k <= 1; k++) stroke(g, [[-7, k * 5], [7, k * 5]], '#456d6359', 2); g.restore();
        }
        for (const [x, y] of [[a.x - a.rx + 30, a.y - a.ry + 35], [a.x + a.rx - 35, a.y + a.ry - 30]]) rubble(g, x, y, rnd);
        for (let i = 0; i < 24; i++) {
          const x = a.x - a.rx + rnd() * a.rx * 2, y = i % 2 ? a.y - a.ry + 12 : a.y + a.ry - 12;
          wash(g, x, y, 15 + rnd() * 35, '#4b775243');
        }
      } else {
        g.save(); g.translate(a.x, a.y); g.scale(1, a.ry / a.rx); wash(g, 0, 0, a.rx, '#c4bc9970'); g.restore();
        for (let i = 0; i < 125; i++) {
          const angle = rnd() * TAU, r = Math.sqrt(rnd());
          stroke(g, [[a.x + Math.cos(angle) * a.rx * r, a.y + Math.sin(angle) * a.ry * r], [a.x + Math.cos(angle) * a.rx * r + 14, a.y + Math.sin(angle) * a.ry * r - 3]], '#716d4c32');
        }
      }
    }
    // Sparse clumps are kept outside the roads, interaction points and boss floors.
    for (let i = 0; i < 2500; i++) {
      const x = rnd() * (W + 800) - 400, y = rnd() * (H + 800) - 400;
      if (scene.roadDistance(x, y) < 48 || scene.inArena({ x, y }) || scene.huts.some(h => Math.abs(x - h.x) < h.w * .6 && Math.abs(y - h.y) < h.h * .8)) continue;
      const h = 3 + rnd() * 9; stroke(g, [[x - 4, y - h * .6], [x, y], [x + 2, y - h], [x + 3, y]], i % 4 ? p.grass + '80' : p.light + '88');
      if (i % 17 === 0 && mood !== 'camp') { oval(g, x - 2, y - h, 1.6, 1.4, '#e6dec5b0'); oval(g, x + 3, y - h + 3, 1, 1, '#dacc94'); }
    }
    for (const r of scene.rocks) {
      oval(g, r.x + 6, r.y + 6, r.r * 1.25, r.r * .47, '#183e354e');
      poly(g, [[r.x - r.r, r.y], [r.x - r.r * .5, r.y - r.r], [r.x + r.r * .45, r.y - r.r * .83], [r.x + r.r, r.y + 1], [r.x + r.r * .4, r.y + r.r * .35]], '#61776c');
      poly(g, [[r.x - r.r, r.y], [r.x - r.r * .5, r.y - r.r], [r.x + r.r * .45, r.y - r.r * .83], [r.x - 1, r.y - 2]], '#b3b8a0');
      stroke(g, [[r.x + r.r * .45, r.y - r.r * .8], [r.x, r.y - 1], [r.x + r.r * .35, r.y + r.r * .3]], '#394f455f');
      oval(g, r.x - r.r * .4, r.y - 2, r.r * .55, 3, '#739062');
    }
    if (scene.stage === 'mountain') {
      // Fallen equipment is ground decoration, so it creates no invisible blockers.
      for (const [x, y] of [[395, 916], [760, 702], [1130, 520]]) {
        stroke(g, [[x - 32, y - 11], [x + 34, y + 10]], '#69553d', 4);
        poly(g, [[x - 22, y - 8], [x - 15, y + 18], [x + 9, y + 24], [x + 5, y + 2]], '#797761');
        stroke(g, [[x - 13, y], [x - 7, y + 12]], '#d0b98a', 2); wheel(g, x + 24, y + 19, 17);
      }
    }
    if (['village', 'house'].includes(scene.stage)) {
      for (const h of scene.huts.filter(h => h.type === 'ruin')) { wash(g, h.x, h.y + h.h * .4, 83, '#343d3248'); rubble(g, h.x - h.w * .48, h.y + h.h * .52, rnd); wheel(g, h.x + h.w * .55, h.y + h.h * .5, 16); }
      if (scene.stage === 'house') { paving(g, 1020, 410, 185, 120, rnd, mood); for (let i = 0; i < 35; i++) oval(g, 1100 + (rnd() - .5) * 230, 455 + (rnd() - .5) * 160, 2, 1, '#e0bfb394'); }
    }
    if (scene.stage === 'fork') {
      for (let i = 0; i < 10; i++) {
        const x = 1220 + i % 4 * 27, y = 750 + Math.floor(i / 4) * 28;
        oval(g, x + 3, y + 7, 15, 6, '#353d304d'); g.fillStyle = '#967445'; g.fillRect(x - 10, y - 12, 20, 24); oval(g, x, y - 12, 10, 4, '#d3b77e');
        for (const sy of [-5, 6]) stroke(g, [[x - 10, y + sy], [x + 10, y + sy]], '#5d573d', 2);
      }
      for (const [x, y] of [[1165, 830], [1375, 802]]) { wheel(g, x, y, 21); stroke(g, [[x - 30, y - 18], [x + 27, y - 9]], '#755536', 7); }
    }
    if (scene.stage === 'bridge') {
      const water = g.createLinearGradient(0, 20, 0, 285); water.addColorStop(0, '#315d64'); water.addColorStop(.6, '#477f81'); water.addColorStop(1, '#6e9e90');
      g.fillStyle = water; g.fillRect(-pad, -pad, W + pad * 2, pad + 285);
      for (let i = 0; i < 160; i++) { const x = rnd() * (W + pad * 2) - pad, y = rnd() * (pad + 280) - pad; stroke(g, [[x, y], [x + 15 + rnd() * 80, y - 2]], '#bde2cf23'); }
      for (const color of ['#345a4a', '#9dac89', '#d1d3af']) { stroke(g, [[-pad, 287], [W + pad, 287]], color, color === '#345a4a' ? 13 : color === '#9dac89' ? 6 : 1); }
      g.fillStyle = '#43574b'; g.fillRect(1170, 25, 200, 272);
      for (let y = 29; y < 297; y += 14) {
        g.fillStyle = Math.floor(y / 14) % 2 ? '#a89570' : '#958260'; g.fillRect(1176, y, 188, 11);
        stroke(g, [[1180, y + 2], [1358, y + 2]], '#eddcb572');
        for (const x of [1183, 1355]) oval(g, x, y + 6, 1.5, 1.5, '#4a4d3a');
      }
      for (const x of [1170, 1366]) { stroke(g, [[x, 28], [x, 298]], '#56624b', 5); for (let y = 35; y < 300; y += 39) { stroke(g, [[x, y], [x, y - 20]], '#554d36', 7); stroke(g, [[x - 2, y - 19], [x - 2, y - 4]], '#c7b27e', 2); } }
      if (!scene.flags.supplies) for (let y = 745; y < H; y += 32) { stroke(g, [[1080, y - 10], [1140, y + 10]], '#695338', 7); stroke(g, [[1080, y + 10], [1140, y - 10]], '#9c855b', 6); }
    }
    // Terrain beyond the playable border suggests depth without hiding the edge.
    for (let i = 0; i < 72; i++) {
      const side = i % 4, x = side === 0 ? -55 - rnd() * 360 : side === 1 ? W + 55 + rnd() * 360 : rnd() * W;
      const y = side === 2 ? -50 - rnd() * 340 : side === 3 ? H + 70 + rnd() * 340 : rnd() * H;
      if (scene.stage === 'bridge' && y < 310) continue;
      const sprite = globalThis.LongdanArt.scenerySprite('tree', { x, y, size: 36 + rnd() * 22, shade: rnd(), seed: rnd() }, ratio);
      g.globalAlpha = .75; g.drawImage(sprite.canvas, x - sprite.anchorX, y - sprite.anchorY, sprite.width, sprite.height); g.globalAlpha = 1;
    }
    // A low stone lip marks actual world limits; entrances remain visually open.
    g.strokeStyle = '#385e4b38'; g.lineWidth = 3; g.strokeRect(20, 27, W - 40, H - 54);
    const map = document.createElement('canvas'); map.width = 480; map.height = Math.round(480 * H / W);
    const mg = map.getContext('2d'); mg.drawImage(canvas, pad * ratio, pad * ratio, W * ratio, H * ratio, 0, 0, map.width, map.height);
    const scenery = [...scene.trees.filter(t => scene.stage !== 'bridge' || t.y > 325).map(t => globalThis.LongdanArt.scenerySprite('tree', t, ratio)), ...scene.huts.map(h => globalThis.LongdanArt.scenerySprite('hut', h, ratio))].sort((a, b) => a.y - b.y);
    mg.save(); mg.scale(map.width / W, map.height / H);
    for (const s of scenery) mg.drawImage(s.canvas, s.x - s.anchorX, s.y - s.anchorY, s.width, s.height);
    mg.restore();
    return { canvas, ratio, pad, map, scenery };
  }
  function groundMotion(g, scene, time, visible) {
    if (scene.stage !== 'bridge') return;
    g.save(); g.beginPath(); g.rect(-600, -600, 1770, 885); g.rect(1370, -600, 830, 885); g.clip();
    for (let i = 0; i < 60; i++) {
      const x = (i * 137 + time * (12 + i % 3)) % 2000 - 200, y = 35 + i * 41 % 248;
      if (!visible(x, y, 90)) continue;
      stroke(g, [[x, y], [x + 15, y - 1.5], [x + 38 + i % 20, y]], '#d7ede359', i % 3 ? 1 : 1.7);
    }
    g.restore();
  }
  function atmosphere(g, camera, width, height, time, mood, reduced) {
    const p = palettes[mood], count = reduced ? 7 : 24;
    // Transparent light shafts remain behind the combat readability threshold.
    g.save(); g.globalAlpha = mood === 'temple' || mood === 'river' ? .055 : .07;
    for (let i = 0; i < 3; i++) {
      const x = camera.x - width * .6 + i * width * .53 + Math.sin(time * .12 + i) * 22;
      const gradient = g.createLinearGradient(x, camera.y - height * .6, x + 160, camera.y + height * .6);
      gradient.addColorStop(0, p.light); gradient.addColorStop(1, p.light + '00');
      poly(g, [[x, camera.y - height], [x + 90, camera.y - height], [x + 500, camera.y + height], [x + 280, camera.y + height]], gradient);
    }
    g.restore();
    for (let i = 0; i < count; i++) {
      const spanX = 2200, spanY = 1600;
      const x = ((i * 173.3 + time * (8 + i % 5)) % spanX + spanX) % spanX - 300;
      const y = ((i * 97.7 + time * (3 + i % 3)) % spanY + spanY) % spanY - 250;
      if (Math.abs(x - camera.x) > width * .55 || Math.abs(y - camera.y) > height * .55) continue;
      g.save(); g.translate(x, y); g.rotate(time * .45 + i);
      oval(g, 0, 0, mood === 'camp' ? 1.4 : 3, 1.1, mood === 'camp' ? '#f8c06aa0' : mood === 'house' ? '#eed0bbb0' : p.light + '8a'); g.restore();
    }
  }
  globalThis.LongdanScene = { landscape, groundMotion, atmosphere, palettes };
})();
