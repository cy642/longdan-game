/* Canvas scenery and character sprite rendering, bundled into the offline build. */
(() => {
  'use strict';
  const TAU = Math.PI * 2;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const oval = (g, x, y, rx, ry, color) => {
    g.fillStyle = color; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill();
  };
  const poly = (g, points, color) => {
    g.fillStyle = color; g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); g.fill();
  };
  const line = (g, points, color, width = 1) => {
    g.strokeStyle = color; g.lineWidth = width; g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.stroke();
  };
  function randomFor(seed) {
    return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  }
  function leafCloud(g, x, y, rx, ry, color, rnd) {
    g.fillStyle = color; g.beginPath();
    for (let i = 0; i <= 22; i++) {
      const angle = i / 22 * TAU, rag = 0.84 + rnd() * 0.22;
      const px = x + Math.cos(angle) * rx * rag, py = y + Math.sin(angle) * ry * rag;
      if (i) g.lineTo(px, py); else g.moveTo(px, py);
    }
    g.closePath(); g.fill();
  }
  function tree(g, t) {
    const s = t.size, rnd = randomFor(Math.floor(t.seed * 100000) + 19);
    g.save(); g.translate(t.x, t.y);
    oval(g, 20, 11, s * 1.05, s * 0.32, '#253e3424');
    oval(g, 3, 4, s * 0.35, s * 0.18, '#162f3540');
    const bark = g.createLinearGradient(-5, 0, 6, 0); bark.addColorStop(0, '#273b36'); bark.addColorStop(0.65, '#7a7960'); bark.addColorStop(1, '#34473c');
    poly(g, [[-8, 8], [-3, -s * 1.6], [1, -s * 1.7], [7, 7], [14, 11], [0, 9]], bark);
    line(g, [[0, -s * 0.55], [-s * 0.42, -s * 1.27], [-s * 0.62, -s * 1.31]], '#34443a', 3);
    line(g, [[1, -s * 0.8], [s * 0.38, -s * 1.53]], '#34443a', 3);
    if (t.shade < 0.32) {
      const colors = ['#274841', '#355d50', '#477463', '#628976', '#789582'];
      for (let level = 0; level < 5; level++) {
        const y = -s * 0.22 - level * s * 0.34, width = s * (1.16 - level * 0.2);
        const pts = [[-width, y + 5], [-width * 0.43, y - s * 0.25], [-width * 0.61, y - s * 0.25], [1, y - s * 0.76], [width * 0.59, y - s * 0.22], [width * 0.43, y - s * 0.2], [width, y + 3], [width * 0.3, y + 9], [-width * 0.22, y + 12]];
        poly(g, pts, colors[level]);
        line(g, [[-width * 0.8, y + 2], [-width * 0.22, y - s * 0.1], [1, y - s * 0.65]], '#a4b79755', 1.3);
        for (let j = 0; j < 20; j++) {
          const px = (rnd() - 0.5) * width * 1.5, py = y - rnd() * s * 0.22;
          line(g, [[px - 3, py], [px + 2, py - 3]], j % 3 ? '#a2b99426' : '#193e3b36');
        }
      }
    } else {
      const colors = ['#2d5147', '#3c6452', '#527c61', '#688f6b', '#809c75'];
      for (let i = 0; i < 10; i++) {
        const angle = i * 2.4 + t.seed * 4;
        const x = Math.cos(angle) * s * (i < 5 ? 0.5 : 0.32);
        const y = -s * 1.45 + Math.sin(angle) * s * 0.37 - (i > 6 ? s * 0.24 : 0);
        leafCloud(g, x, y, s * (0.66 - i * 0.014), s * 0.46, colors[Math.min(4, Math.floor(i / 2))], rnd);
        for (let j = 0; j < 15; j++) {
          const px = x + (rnd() - 0.5) * s * 0.85, py = y + (rnd() - 0.5) * s * 0.58;
          oval(g, px, py, 1.5 + rnd() * 3, 0.8 + rnd(), j % 3 ? '#c9cd982b' : '#193b3530');
        }
      }
    }
    g.restore();
  }
  function hut(g, h) {
    const { x, y, w, h: height, type } = h;
    const rnd = randomFor(Math.round(x + y));
    g.save(); g.translate(x, y); g.lineJoin = 'round';
    oval(g, 17, height * 0.28, w * 0.64, height * 0.4, '#243d3d30');
    if (type === 'tent') {
      poly(g, [[-w / 2 - 4, height / 2], [-w / 2 + 8, -height / 2], [0, -height / 2 - 28], [w / 2 + 5, height / 2]], '#b3a37c');
      poly(g, [[0, -height / 2 - 28], [0, height / 2], [w / 2 + 5, height / 2]], '#84765d');
      for (let i = 0; i < 5; i++) line(g, [[-w / 2 + 14 + i * 9, height / 2 - 3], [-5 + i * 2, -height / 2 - 20]], '#e6d7ad48');
      poly(g, [[-13, height / 2], [2, -5], [20, height / 2]], '#253a35');
      line(g, [[0, -height / 2 - 32], [0, height / 2 + 8]], '#4c4e3a', 3);
      for (const side of [-1, 1]) line(g, [[side * w / 2, height / 2 - 7], [side * (w / 2 + 18), height / 2 + 14]], '#b5a88a');
      g.restore(); return;
    }
    const wall = g.createLinearGradient(0, -height / 2, 0, height / 2); wall.addColorStop(0, '#d5c7a0'); wall.addColorStop(1, '#afa884');
    poly(g, [[-w / 2, -height / 2], [w / 2, -height / 2], [w / 2, height / 2], [-w / 2, height / 2]], wall);
    poly(g, [[w * 0.17, -height / 2], [w / 2, -height / 2], [w / 2, height / 2], [w * 0.17, height / 2]], '#8d917480');
    for (let i = 0; i < 42; i++) {
      const px = (rnd() - 0.5) * (w - 4), py = (rnd() - 0.5) * (height - 6);
      line(g, [[px, py], [px + 3 + rnd() * 7, py - 1]], i % 4 ? '#6b786c16' : '#f4e4b724');
    }
    poly(g, [[-14, height / 2], [-14, height / 2 - 35], [13, height / 2 - 35], [13, height / 2]], '#374943');
    g.fillStyle = '#635d48'; g.fillRect(-11, height / 2 - 32, 10, 31);
    line(g, [[-14, height / 2], [-14, height / 2 - 35], [13, height / 2 - 35]], '#dfcea358', 2);
    g.fillStyle = '#596453'; g.fillRect(-w / 2 + 12, height / 2 - 35, 19, 16);
    for (let i = 0; i < 4; i++) line(g, [[-w / 2 + 15 + i * 4, height / 2 - 34], [-w / 2 + 15 + i * 4, height / 2 - 20]], '#c0b88e');
    line(g, [[-w / 2, height / 2], [w / 2, height / 2]], '#718370', 4);
    if (type === 'ruin') {
      poly(g, [[-w / 2 - 10, -3], [-8, -height / 2 - 35], [14, -height / 2 - 20], [-w / 2 + 18, 5]], '#596b63');
      for (let i = 0; i < 5; i++) line(g, [[12 + i * 13, -height / 2 + i % 2 * 13], [14 + i * 13, -height / 2 - 21 + i % 2 * 18]], '#524d39', 4);
      poly(g, [[-15, height / 2 - 6], [4, -9], [18, 3], [34, height / 2]], '#9d9c7b');
    } else {
      const roof = g.createLinearGradient(0, -height / 2 - 36, 0, 14); roof.addColorStop(0, '#819386'); roof.addColorStop(1, '#3e5750');
      poly(g, [[-w / 2 - 14, -1], [-6, -height / 2 - 37], [w / 2 + 16, -1], [4, 12]], roof);
      poly(g, [[-6, -height / 2 - 37], [w / 2 + 16, -1], [4, 12], [-6, -height / 2 - 12]], '#2d4c4666');
      for (let i = 0; i <= 13; i++) {
        const px = -w / 2 - 9 + i * (w + 20) / 13;
        line(g, [[px, 0], [-6 + (px + 6) * 0.12, -height / 2 - 29]], '#a5b7a25b', 1.5);
        for (let j = 0; j < 5; j++) {
          const t = 0.1 + j * 0.17;
          oval(g, px * (1 - t) - 6 * t, (-height / 2 - 29) * t + 1, 2, 0.8, '#253f422d');
        }
      }
      line(g, [[-w / 2 - 14, -1], [4, 12], [w / 2 + 16, -1]], '#233e3c', 4);
      line(g, [[-11, -height / 2 - 35], [-6, -height / 2 - 39], [7, -height / 2 - 31]], '#bdc1a5', 2);
    }
    g.restore();
  }
  function landscape(scene, roads, isRoad, W, H, pixelRatio) {
    const canvas = document.createElement('canvas'), ratio = Math.min(pixelRatio, 1.5);
    canvas.width = Math.round(W * ratio); canvas.height = Math.round(H * ratio);
    const g = canvas.getContext('2d'); g.scale(ratio, ratio);
    const rnd = randomFor(37595);
    const soil = g.createLinearGradient(0, 0, W, H); soil.addColorStop(0, '#a3ad8a'); soil.addColorStop(0.48, '#9d9e76'); soil.addColorStop(1, '#71866c');
    g.fillStyle = soil; g.fillRect(0, 0, W, H);
    for (let i = 0; i < 1000; i++) {
      const x = rnd() * W, y = rnd() * H, radius = 20 + rnd() * 125;
      const wash = g.createRadialGradient(x, y, 0, x, y, radius);
      wash.addColorStop(0, i % 3 ? '#d8cfa216' : '#345d4420'); wash.addColorStop(1, '#a9b38700');
      g.fillStyle = wash; g.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }
    // Forest floor darkens toward the trunks; the navigable paths stay bright.
    for (const t of scene.trees) {
      oval(g, t.x + 6, t.y - 5, t.size * 1.45, t.size * 0.6, '#3e6a4b18');
      for (let j = 0; j < 9; j++) oval(g, t.x + (rnd() - 0.5) * t.size * 2.7, t.y + (rnd() - 0.5) * t.size, 1 + rnd() * 3, 1, '#ced39850');
    }
    const water = g.createLinearGradient(0, 120, 0, 285); water.addColorStop(0, '#537d76'); water.addColorStop(0.5, '#376663'); water.addColorStop(1, '#698b77');
    g.fillStyle = water; g.fillRect(0, 120, W, 165);
    for (let i = 0; i < 145; i++) {
      const x = rnd() * W, y = 125 + rnd() * 158;
      line(g, [[x, y], [x + 17 + rnd() * 80, y - 1]], '#b8d2bd30');
    }
    poly(g, [[0, 120], [0, 45], [140, 10], [260, 67], [420, 23], [650, 67], [910, 10], [1080, 120]], '#829887');
    poly(g, [[0, 120], [0, 75], [190, 34], [310, 102], [510, 51], [730, 113], [870, 67], [1080, 120]], '#536f67');
    poly(g, [[1310, 120], [1410, 30], [1600, 60], [1750, 10], [1880, 70], [2130, 25], [W, 120]], '#7d9680');
    line(g, [[0, 299], [W, 299]], '#4566515c', 13);
    g.beginPath(); g.moveTo(2460, 300); g.bezierCurveTo(2290, 700, 2520, 980, 2420, 1340); g.bezierCurveTo(2290, 1570, 2510, 1770, 2440, 1950);
    g.strokeStyle = '#426e63'; g.lineWidth = 181; g.stroke(); g.strokeStyle = '#86aa8d60'; g.lineWidth = 122; g.stroke();
    for (const road of roads) {
      g.beginPath(); road.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.lineJoin = 'round'; g.lineCap = 'round';
      g.strokeStyle = '#706d4820'; g.lineWidth = 111; g.stroke(); g.strokeStyle = '#bfad7a'; g.lineWidth = 82; g.stroke();
      g.strokeStyle = '#d9c7954d'; g.lineWidth = 55; g.stroke(); g.strokeStyle = '#ece1b32d'; g.lineWidth = 25; g.stroke();
    }
    for (let i = 0; i < 9800; i++) {
      const x = rnd() * W, y = 320 + rnd() * (H - 320); if (x > 2310) continue;
      if (isRoad(x, y, 43)) {
        oval(g, x, y, 0.8 + rnd() * 2.1, 0.4 + rnd() * 0.9, i % 3 ? '#77644630' : '#f1dfaf55');
        if (i % 14 === 0) line(g, [[x, y], [x + 8, y - 3]], '#8871452c');
      } else {
        const tall = 3 + rnd() * 7;
        line(g, [[x - 3, y - tall * 0.7], [x, y], [x + 2, y - tall]], i % 3 ? '#3f674641' : '#d4d79c73');
        if (i % 29 === 0) { oval(g, x, y - tall, 1.5, 1.5, '#ece1aa'); oval(g, x + 3, y - tall + 2, 1.2, 1.2, '#eee9c0'); }
      }
    }
    for (const r of scene.rocks) {
      oval(g, r.x + 7, r.y + 7, r.r * 1.13, r.r * 0.44, '#294d3c26');
      poly(g, [[r.x - r.r, r.y], [r.x - r.r * 0.45, r.y - r.r * 0.76], [r.x + r.r * 0.3, r.y - r.r * 0.8], [r.x + r.r, r.y], [r.x + r.r * 0.5, r.y + r.r * 0.37]], '#6d8173');
      poly(g, [[r.x - r.r, r.y], [r.x - r.r * 0.45, r.y - r.r * 0.76], [r.x + r.r * 0.3, r.y - r.r * 0.8], [r.x + r.r * 0.15, r.y - 2]], '#b5bca0');
      line(g, [[r.x + r.r * 0.3, r.y - r.r * 0.72], [r.x + r.r * 0.15, r.y - 2], [r.x + r.r * 0.49, r.y + r.r * 0.31]], '#3b615744');
      oval(g, r.x - 5, r.y - 1, r.r * 0.4, 3, '#718a5850');
    }
    g.fillStyle = '#645941'; g.fillRect(1130, 105, 180, 205);
    for (let y = 108; y < 310; y += 13) {
      g.fillStyle = Math.floor(y / 13) % 2 ? '#a28e63' : '#8d7b56'; g.fillRect(1136, y, 169, 10);
      line(g, [[1141, y + 2], [1298, y + 2]], '#dfc79147');
      for (const x of [1141, 1298]) oval(g, x, y + 5, 1, 1, '#3e4431');
    }
    for (const x of [1130, 1304]) { g.fillStyle = '#3b4e3a'; g.fillRect(x, 101, 7, 210); for (let y = 110; y <= 311; y += 37) g.fillRect(x - 2, y - 8, 10, 14); }
    const fences = [[600, 1190, 73], [805, 1455, 72], [1750, 720, 70], [2145, 1205, 84]];
    for (const [x, y, length] of fences) {
      line(g, [[x, y - 4], [x + length, y - 4]], '#5f6d47', 3); line(g, [[x, y + 4], [x + length, y + 4]], '#8b9367', 2);
      for (let i = 0; i < length; i += 14) { line(g, [[x + i, y + 11], [x + i + 1, y - 16]], '#536349', 3); line(g, [[x + i, y - 5], [x + i + 3, y - 5]], '#c7ba86'); }
    }
    for (let i = 0; i < 7; i++) {
      const x = 1990 + i % 3 * 35, y = 1268 + Math.floor(i / 3) * 25;
      oval(g, x + 3, y + 10, 16, 7, '#314e3d50'); g.fillStyle = '#a68a59'; g.fillRect(x - 11, y - 10, 22, 20); oval(g, x, y - 10, 11, 5, '#d0b17a');
      for (const sy of [-4, 5]) line(g, [[x - 11, y + sy], [x + 11, y + sy]], '#655b3c', 2);
      for (let j = -7; j <= 7; j += 7) line(g, [[x + j, y - 6], [x + j, y + 8]], '#78674150');
    }
    g.fillStyle = '#8a7853'; g.fillRect(655, 1305, 56, 25); g.strokeStyle = '#4c5941'; g.lineWidth = 4; g.strokeRect(658, 1308, 50, 17);
    for (const x of [665, 702]) { oval(g, x, 1333, 9, 9, '#384d3e'); oval(g, x, 1333, 6, 6, '#b3a476'); line(g, [[x - 5, 1328], [x + 5, 1338]], '#566447'); line(g, [[x + 5, 1328], [x - 5, 1338]], '#566447'); }
    g.font = '22px KaiTi, SimSun, serif'; g.textAlign = 'center'; g.fillStyle = '#254c3938'; g.fillText('长 坂 坡', 1450, 1490);
    return { canvas, ratio };
  }
  function stageLandscape(scene, W, H, ratio) {
    const pad = 600, canvas = document.createElement('canvas'); canvas.width = Math.round((W + pad * 2) * ratio); canvas.height = Math.round((H + pad * 2) * ratio);
    const g = canvas.getContext('2d'); g.scale(ratio, ratio); g.translate(pad, pad); const rnd = randomFor(scene.definition.seed * 773);
    const mood = scene.definition.mood, palette = { forest: ['#abb88c', '#7d9877'], village: ['#bcb083', '#8e9672'], temple: ['#a9afa1', '#788c7e'], house: ['#b4b092', '#809784'], camp: ['#b7a37b', '#829478'], river: ['#a9b292', '#809e84'] }[mood];
    const base = g.createLinearGradient(0, 0, W, H); base.addColorStop(0, palette[0]); base.addColorStop(1, palette[1]); g.fillStyle = base; g.fillRect(-pad, -pad, W + pad * 2, H + pad * 2);
    for (let i = 0; i < 280; i++) { const x = rnd() * W, y = rnd() * H, r = 25 + rnd() * 100; const wash = g.createRadialGradient(x, y, 0, x, y, r); wash.addColorStop(0, i % 3 ? '#e4d5a51a' : '#3659421e'); wash.addColorStop(1, '#91a27c00'); g.fillStyle = wash; g.fillRect(x - r, y - r, r * 2, r * 2); }
    const roads = [...scene.definition.roads];
    if (scene.stage === 'bridge' && scene.flags.supplies) roads.push([[300, 950], [850, 890], [1260, 730], [1270, 330]]);
    for (const road of roads) { g.beginPath(); road.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.lineCap = 'round'; g.lineJoin = 'round'; g.strokeStyle = '#746c4525'; g.lineWidth = 104; g.stroke(); g.strokeStyle = '#c6b585'; g.lineWidth = 77; g.stroke(); g.strokeStyle = '#dfcda045'; g.lineWidth = 42; g.stroke(); }
    if (scene.definition.arena) { const a = scene.definition.arena; oval(g, a.x, a.y, a.rx + 20, a.ry + 15, mood === 'temple' ? '#aaa997' : '#b8af8a'); for (let i = 0; i < 260; i++) { const x = a.x + (rnd() - .5) * a.rx * 2, y = a.y + (rnd() - .5) * a.ry * 2; if (Math.hypot((x - a.x) / a.rx, (y - a.y) / a.ry) > 1) continue; line(g, [[x, y], [x + 12 + rnd() * 24, y + rnd() * 4]], '#5f73523a'); } if (mood === 'temple') { g.strokeStyle = '#566f642a'; g.lineWidth = 2; for (let r = 45; r < 270; r += 50) { g.beginPath(); g.ellipse(a.x, a.y, r * 1.2, r * .7, 0, 0, Math.PI * 2); g.stroke(); } } }
    for (let i = 0; i < 8500; i++) { const x = rnd() * (W + pad * 2) - pad, y = rnd() * (H + pad * 2) - pad; if (scene.roadDistance(x, y) < 42 || scene.inArena({ x, y })) { oval(g, x, y, .6 + rnd() * 1.6, .5, '#7567442f'); } else { const h = 3 + rnd() * 5; line(g, [[x - 2, y - h], [x, y], [x + 2, y - h * .8]], i % 4 ? '#4c74433e' : '#d7d59c76'); } }
    for (let i = 0; i < 70; i++) { const x = rnd() * (W + pad * 2) - pad, y = rnd() * (H + pad * 2) - pad; if (x > 20 && x < W - 20 && y > 20 && y < H - 20) continue; tree(g, { x, y, size: 30 + rnd() * 18, shade: rnd(), seed: rnd() }); }
    for (const r of scene.rocks) { oval(g, r.x + 5, r.y + 3, r.r * 1.1, r.r * .4, '#25493928'); poly(g, [[r.x - r.r, r.y], [r.x - r.r * .4, r.y - r.r * .9], [r.x + r.r * .4, r.y - r.r * .7], [r.x + r.r, r.y], [r.x + 4, r.y + 4]], '#839489'); poly(g, [[r.x - r.r, r.y], [r.x - r.r * .4, r.y - r.r * .9], [r.x + r.r * .4, r.y - r.r * .7], [r.x - 3, r.y - 1]], '#c0c5aa'); }
    if (scene.stage === 'fork') { for (let i = 0; i < 10; i++) { const x = 1220 + i % 4 * 27, y = 755 + Math.floor(i / 4) * 28; oval(g, x + 3, y + 7, 15, 6, '#29493740'); g.fillStyle = '#a18758'; g.fillRect(x - 10, y - 12, 20, 24); oval(g, x, y - 12, 10, 4, '#d3b77e'); for (const sy of [-5, 6]) line(g, [[x - 10, y + sy], [x + 10, y + sy]], '#665b3c', 2); } }
    if (scene.stage === 'village') { for (const [x, y] of [[505, 820], [1140, 475], [300, 290]]) { oval(g, x, y, 40, 18, '#4a524929'); line(g, [[x - 20, y - 10], [x + 28, y + 10]], '#6d6350', 6); line(g, [[x - 10, y + 15], [x + 9, y - 17]], '#867357', 5); } }
    if (scene.stage === 'bridge') {
      const water = g.createLinearGradient(0, 70, 0, 285); water.addColorStop(0, '#6c9889'); water.addColorStop(.55, '#4a7d77'); water.addColorStop(1, '#809b85'); g.fillStyle = water; g.fillRect(0, 60, W, 220);
      for (let i = 0; i < 110; i++) { const x = rnd() * W, y = 75 + rnd() * 190; line(g, [[x, y], [x + 20 + rnd() * 90, y - 2]], '#c1d8bf47'); }
      line(g, [[0, 288], [W, 288]], '#56795d7a', 9); g.fillStyle = '#645941'; g.fillRect(1170, 60, 200, 235);
      for (let y = 65; y < 296; y += 14) { g.fillStyle = Math.floor(y / 14) % 2 ? '#b19c72' : '#a08d66'; g.fillRect(1177, y, 186, 11); line(g, [[1180, y + 2], [1358, y + 2]], '#e4d0a15e'); }
      for (const x of [1170, 1363]) { line(g, [[x, 65], [x, 295]], '#42563d', 6); for (let y = 70; y < 290; y += 40) line(g, [[x, y - 9], [x, y + 12]], '#566f46', 9); }
      if (!scene.flags.supplies) { for (let y = 745; y < H; y += 32) { line(g, [[1080, y - 10], [1140, y + 10]], '#715c3d', 7); line(g, [[1080, y + 10], [1140, y - 10]], '#87744c', 6); } }
    }
    g.font = '24px KaiTi, SimSun, serif'; g.fillStyle = '#34543b35'; g.textAlign = 'center'; g.fillText(scene.definition.name.split('').join(' '), W * .55, H * .94);
    return { canvas, ratio, pad };
  }
  const characterAssets = /* HERO_ASSETS */ null;
  let portraitImage, heroFrames = [], unitFrames = [], walkFrames = [], chapterFrames = [], attackFrames = [];
  const HERO_HEAD_HEIGHT = 22;
  // Atlas directions follow the actual artwork, including mirrored preparatory poses.
  const walkDirections = [
    { frame: 12 }, { frame: 2, flip: -1 }, { frame: 0 }, { frame: 2 },
    { frame: 4 }, { frame: 6 }, { frame: 8 }, { frame: 10 },
  ];
  const attackDirections = [
    [{ frame: 12 }, { frame: 5 }], [{ frame: 2, flip: -1 }, { frame: 3 }],
    [{ frame: 0 }, { frame: 1 }], [{ frame: 2 }, { frame: 3, flip: -1 }],
    [{ frame: 12, flip: -1 }, { frame: 5, flip: -1 }],
    [{ frame: 10, flip: -1 }, { frame: 7, flip: -1 }],
    [{ frame: 8 }, { frame: 9 }], [{ frame: 10 }, { frame: 7 }],
  ];
  function loadImage(url) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error('角色素材未能载入'));
      image.src = url;
    });
  }
  function splitAtlas(image, count = 8, rows = 2) {
    // Select each disconnected character from the transparent atlas. This also
    // keeps long scarves and spears intact when they extend past a nominal cell.
    const width = image.naturalWidth, height = image.naturalHeight;
    const surface = document.createElement('canvas'); surface.width = width; surface.height = height;
    const context = surface.getContext('2d', { willReadFrequently: true }); context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, width, height).data;
    const labels = new Int32Array(width * height), queue = new Int32Array(width * height), components = [];
    let next = 0;
    for (let index = 0; index < labels.length; index++) {
      if (labels[index] || pixels[index * 4 + 3] < 28) continue;
      const id = ++next; let first = 0, last = 1; queue[0] = index; labels[index] = id;
      let x0 = width, x1 = 0, y0 = height, y1 = 0;
      while (first < last) {
        const pixel = queue[first++], x = pixel % width, y = Math.floor(pixel / width);
        x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          const neighbour = ny * width + nx;
          if (!labels[neighbour] && pixels[neighbour * 4 + 3] >= 28) { labels[neighbour] = id; queue[last++] = neighbour; }
        }
      }
      if (last > 1000) components.push({ id, count: last, x0, x1, y0, y1 });
    }
    const characters = components.sort((a, b) => b.count - a.count).slice(0, count);
    if (characters.length !== count || characters.some(c => c.x1 - c.x0 > width * 0.42 || c.y1 - c.y0 > height * .7 / rows * 2)) throw new Error('角色动作图集布局不完整');
    const row = c => Math.min(rows - 1, Math.floor((c.y0 + c.y1) / 2 / (height / rows)));
    if (Array.from({ length: rows }, (_, i) => characters.filter(c => row(c) === i).length).some(n => n !== 4)) throw new Error('角色动作图集行列不完整');
    characters.sort((a, b) => row(a) - row(b) || a.x0 - b.x0);
    return characters.map(c => {
      const sx = Math.max(0, c.x0 - 2), sy = Math.max(0, c.y0 - 2);
      const sw = Math.min(width - sx, c.x1 - sx + 3), sh = Math.min(height - sy, c.y1 - sy + 3);
      const canvas = document.createElement('canvas'); canvas.width = sw; canvas.height = sh;
      const g = canvas.getContext('2d'); g.drawImage(image, sx, sy, sw, sh, 0, 0, sw, sh);
      const cut = g.getImageData(0, 0, sw, sh);
      let headX = 0, headWeight = 0, hairX = 0, hairWeight = 0, hairTop = sh;
      const hairRows = new Float64Array(sh);
      for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
        const global = (sy + y) * width + sx + x, alpha = pixels[global * 4 + 3];
        if (labels[global] === c.id) {
          if (y < sh * .38) { headX += x * alpha; headWeight += alpha; }
          const r = pixels[global * 4], green = pixels[global * 4 + 1], b = pixels[global * 4 + 2];
          // Brown hair gives a scale reference independent of spear length, scarf
          // width or a crouching pose. Inspect the whole sprite: northern spears
          // can extend well above the head.
          if (r > 65 && r > green * 1.18 && b < green * .72) {
            hairX += x * alpha; hairWeight += alpha; hairTop = Math.min(hairTop, y); hairRows[y] += alpha;
          }
        }
        if (labels[global] === c.id) continue;
        let edge = false;
        if (alpha > 0 && alpha < 28) {
          for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1; dx++) {
            const nx = sx + x + dx, ny = sy + y + dy;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height && labels[ny * width + nx] === c.id) { edge = true; break; }
          }
        }
        if (!edge) cut.data[(y * sw + x) * 4 + 3] = 0;
      }
      g.putImageData(cut, 0, 0);
      let headTop = 0, headBottom = sh, weight = 0;
      for (let y = 0; y < sh; y++) { weight += hairRows[y]; if (weight < hairWeight * .02) headTop = y + 1; if (weight >= hairWeight * .96) { headBottom = y; break; } }
      return { canvas, width: sw, height: sh, ax: hairWeight > headWeight * .04 ? hairX / hairWeight : headX / Math.max(1, headWeight), ay: c.y1 - sy + 1, headHeight: hairWeight > 0 ? Math.max(1, headBottom - headTop) : sh * .4, bodyHeight: sh - (hairTop < sh ? hairTop : 0) };
    });
  }
  async function loadCharacters() {
    if (!characterAssets) throw new Error('请先生成离线游戏文件');
    const images = await Promise.all([loadImage(characterAssets.portrait), loadImage(characterAssets.hero), loadImage(characterAssets.units), loadImage(characterAssets.walk), loadImage(characterAssets.chapter), loadImage(characterAssets.attack)]);
    portraitImage = images[0]; heroFrames = splitAtlas(images[1]); unitFrames = splitAtlas(images[2]); walkFrames = splitAtlas(images[3], 16, 4); chapterFrames = splitAtlas(images[4]); attackFrames = splitAtlas(images[5], 16, 4);
    for (const frame of [...heroFrames, ...walkFrames, ...attackFrames]) frame.heroFactor = HERO_HEAD_HEIGHT / frame.headHeight;
    // These downward spear tips extend below the boots; anchor to the planted
    // feet rather than the lowest opaque weapon pixel.
    attackFrames[1].ay -= 35;
    attackFrames[3].ay -= 22;
  }
  function paintFrame(g, frame, x, y, factor, facing, tilt = 0) {
    g.save(); g.translate(x, y); g.scale(facing * factor, factor); g.rotate(tilt);
    g.drawImage(frame.canvas, -frame.ax, -frame.ay); g.restore();
  }
  function heroPose(a) {
    const dir = Number.isFinite(a.action?.dir) && a.action.key !== 'heal' ? a.action.dir : Number.isFinite(a.dir) ? a.dir : 0;
    const direction = (Math.round(dir / (Math.PI / 4)) + 8) % 8;
    const walk = walkDirections[direction];
    if (a.hp <= 0) return { frame: heroFrames[7], flip: Math.cos(dir) >= 0 ? -1 : 1, x: 0, y: 0, tilt: -.08 };
    if (a.action && a.action.key !== 'heal') {
      const { windup, active, recovery } = a.action.def, t = a.action.t;
      const activePose = t >= windup && t < windup + active + recovery * .45;
      const pose = attackDirections[direction][activePose ? 1 : 0];
      const progress = clamp((t - windup) / Math.max(.01, active), 0, 1);
      const settle = t > windup + active ? 1 - clamp((t - windup - active) / recovery, 0, 1) : 1;
      const surge = activePose ? Math.sin(progress * Math.PI * .5) * 4 * settle : 0;
      const sweep = ['sweep', 'sword', 'thrust2'].includes(a.action.key);
      const tilt = sweep ? Math.sin(clamp(t / (windup + active + recovery), 0, 1) * Math.PI * 2) * .09 : 0;
      const lateralSweep = sweep && (direction === 0 || direction === 4);
      return { frame: lateralSweep ? heroFrames[activePose ? 5 : 3] : attackFrames[pose.frame], flip: lateralSweep ? direction === 0 ? -1 : 1 : pose.flip || 1, x: Math.cos(dir) * surge, y: Math.sin(dir) * surge, tilt };
    }
    const step = a.moving ? Math.floor((a.walkDistance || 0) / 37) % 2 : 0;
    return { frame: walkFrames[walk.frame + step], flip: walk.flip || 1, x: 0, y: 0, tilt: a.dashTime > 0 ? -.1 : a.action?.key === 'heal' ? .03 : 0 };
  }
  function hero(g, a, time, scale = 1, carriesAdou = false) {
    if (!heroFrames.length) return;
    const dir = Number.isFinite(a.dir) ? a.dir : 0;
    const facing = Math.cos(dir) >= 0 ? -1 : 1;
    g.save(); g.translate(a.x, a.y); g.scale(scale, scale); g.imageSmoothingEnabled = true;
    oval(g, 0, 1, 18, 4.8, '#193d3c5c');
    if (a.invincible > 0) oval(g, 0, 1, 22, 6, '#dcebc72e');
    if (scale > 1.8 && portraitImage) {
      const factor = 132 / portraitImage.naturalWidth;
      g.drawImage(portraitImage, -320 * factor, -530 * factor, portraitImage.naturalWidth * factor, portraitImage.naturalHeight * factor);
      g.restore(); return;
    }
    const pose = heroPose(a), bob = 0;
    if (a.hurtFlash > 0) g.globalAlpha *= 0.65 + Math.abs(Math.sin(a.hurtFlash * 35)) * 0.35;
    paintFrame(g, pose.frame, pose.x, pose.y, pose.frame.heroFactor, pose.flip, pose.tilt);
    if (carriesAdou) {
      oval(g, -facing * 14, -29 + bob, 5, 7, '#eee0bd');
      line(g, [[-facing * 17, -26 + bob], [-facing * 10, -31 + bob]], '#aa9472', 1.5);
      oval(g, -facing * 14, -34 + bob, 3, 3, '#f0caaa');
    }
    g.restore();
  }
  function unit(g, a, role, time, scale = 1) {
    if (!unitFrames.length) return;
    const boss = a.type === 'boss' || a.type === 'elite', civil = role === 'civil';
    const index = civil ? 5 + (a.id || 0) % 3 : role === 'ally' ? 0 : boss ? 4 : a.type === 'archer' ? 3 : a.type === 'spear' ? 2 : 1;
    let frame = unitFrames[index];
    if (chapterFrames.length) {
      if (a.type === 'shield') frame = chapterFrames[0]; else if (a.type === 'elite') frame = chapterFrames[1];
      else if (a.bossId === 'zhanghe') frame = chapterFrames[2]; else if (a.bossId === 'xiahou') frame = chapterFrames[7];
      else if (role === 'ally') frame = chapterFrames[5 + (a.moving ? Math.floor((a.walkDistance || 0) / 37) % 2 : 0)];
      else if (civil && a.injured) frame = chapterFrames[4]; else if (civil && a.id === 7) frame = chapterFrames[3];
    }
    const facing = Math.cos(a.dir || 0) >= 0 ? -1 : 1;
    g.save(); g.translate(a.x, a.y); g.scale(scale, scale);
    if (a.hp <= 0) {
      const opacity = clamp(1 - (a.deadTime || 0) / 20, 0, 1) * 0.3;
      g.globalAlpha *= opacity; paintFrame(g, frame, 0, 4, 43 / frame.height, facing, -0.95); g.restore(); return;
    }
    const bob = 0;
    oval(g, 0, 1, boss ? 21 : 14, boss ? 5 : 4, '#193d3c55');
    if (a.hurtFlash > 0) g.globalAlpha *= 0.58 + Math.abs(Math.sin(a.hurtFlash * 36)) * 0.42;
    const lean = a.windup > 0 ? -0.05 : a.moving ? Math.sin((a.walkDistance || 0) / 12) * .018 : 0;
    paintFrame(g, frame, 0, bob, (boss ? 73 : civil ? 44 : 53) / frame.height, facing, lean);
    if (!boss && a.hp < a.maxHp) {
      const bar = civil ? 26 : 31, y = civil ? -49 : -59;
      g.fillStyle = '#233b2dc7'; g.fillRect(-bar / 2, y, bar, 3);
      g.fillStyle = role === 'enemy' ? '#d07a60' : '#a8d5a2'; g.fillRect(-bar / 2, y, bar * a.hp / a.maxHp, 3);
    }
    g.restore();
  }
  function atmosphere(g, camera, width, height, time) {
    // Ground-level light and a few leaves move independently of the battle.
    for (let i = 0; i < 3; i++) {
      const x = camera.x - width * 0.35 + i * width * 0.4, y = camera.y - height * 0.2 + i * 80;
      const light = g.createRadialGradient(x, y, 0, x, y, 170); light.addColorStop(0, '#f5e4ae09'); light.addColorStop(1, '#f5e4ae00');
      g.fillStyle = light; g.fillRect(x - 170, y - 170, 340, 340);
    }
    for (let i = 0; i < 15; i++) {
      const x = camera.x - width / 2 + ((time * (9 + i % 4) + i * 151) % (width + 70)) - 35;
      const y = camera.y - height / 2 + ((time * (4 + i % 3) + i * 89) % (height + 30)) - 15;
      g.save(); g.translate(x, y); g.rotate(Math.sin(time + i) + time * 0.3); oval(g, 0, 0, 2.7, 1, '#ded2a85c'); g.restore();
    }
  }
  function scenerySprite(kind, item, ratio) {
    const width = kind === 'tree' ? Math.ceil(item.size * 3.5 + 35) : item.w + 70;
    const height = kind === 'tree' ? Math.ceil(item.size * 2.6 + 40) : item.h + 110;
    const canvas = document.createElement('canvas'); canvas.width = Math.ceil(width * ratio); canvas.height = Math.ceil(height * ratio);
    const g = canvas.getContext('2d'); g.scale(ratio, ratio);
    const anchorX = width / 2, anchorY = kind === 'tree' ? height - 22 : height - item.h / 2 - 20;
    (kind === 'tree' ? tree : hut)(g, { ...item, x: anchorX, y: anchorY });
    return { canvas, width, height, anchorX, anchorY, x: item.x, y: item.y, kind };
  }
  function portraitFor(speaker) {
    const index = speaker.includes('张郃') ? 2 : speaker.includes('夏侯恩') ? 7 : speaker.includes('糜夫人') ? 4 : speaker.includes('医者') ? 3 : -1;
    return index >= 0 && chapterFrames.length ? chapterFrames[index].canvas.toDataURL() : characterAssets.portrait;
  }
  globalThis.LongdanArt = { landscape, hero, unit, atmosphere, scenerySprite, loadCharacters, portraitFor, stageLandscape };
})();
