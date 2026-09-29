// Usage: npm i -D playwright && node tool/render_icon.js && dart run flutter_launcher_icons
// Renders the app icon from an isometric room SVG (same geometry language as the game).
const { chromium } = require('playwright');
const OUT = require('path').join(__dirname, '..', 'assets', 'icon') + '/';

function svg({ W, bg, size = 1024 }) {
  const N = 3, WH = W * 1.05, cx = size / 2;
  const oy = size / 2 - (N * W / 4) + WH / 2 - W * .08;
  const P = (i, j, z = 0) => [cx + (i - j) * W / 2, oy + (i + j) * W / 4 - z];
  const pts = a => a.map(p => p.map(v => v.toFixed(1)).join(',')).join(' ');
  const poly = (a, attrs) => `<polygon points="${pts(a)}" ${attrs}/>`;
  const ink = '#EDEAE3';
  const d0 = 1.55, d1 = 2.45, dh = WH * .64;
  const pl = P(1.2, 1.35);
  const g = W * .06; // red glitch ghost offset
  const s = W / 48 * .72; // player scale relative to the in-game 48px tile
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
<defs>
 <radialGradient id="fl" gradientUnits="userSpaceOnUse" cx="${P(1.6,.9)[0]}" cy="${P(1.6,.9)[1]}" r="${W*2.2}">
  <stop offset="0" stop-color="${ink}" stop-opacity=".16"/><stop offset=".6" stop-color="${ink}" stop-opacity=".03"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></radialGradient>
 <linearGradient id="sp" gradientUnits="userSpaceOnUse" x1="${P(2,0)[0]}" y1="${P(2,0)[1]}" x2="${P(2,1.9)[0]}" y2="${P(2,1.9)[1]}">
  <stop offset="0" stop-color="${ink}" stop-opacity=".42"/><stop offset="1" stop-color="${ink}" stop-opacity="0"/></linearGradient>
 <linearGradient id="wg" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="${ink}" stop-opacity=".07"/><stop offset="1" stop-color="${ink}" stop-opacity="0"/></linearGradient>
 <linearGradient id="pg" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#F4F1EA"/><stop offset="1" stop-color="#ABA79F"/></linearGradient>
</defs>
${bg ? `<rect width="${size}" height="${size}" fill="${bg}"/>` : ''}
${poly([P(N,0),P(N,N),P(N,N,-W*.12),P(N,0,-W*.12)], 'fill="#111113"')}
${poly([P(0,N),P(N,N),P(N,N,-W*.12),P(0,N,-W*.12)], 'fill="#0D0D0F"')}
${poly([P(0,0),P(0,N),P(0,N,WH),P(0,0,WH)], 'fill="#17171A"')}
${poly([P(0,0),P(N,0),P(N,0,WH),P(0,0,WH)], 'fill="#1F1F22"')}
${poly([P(0,0),P(0,N),P(0,N,WH),P(0,0,WH)], 'fill="url(#wg)"')}
${poly([P(0,0),P(N,0),P(N,0,WH),P(0,0,WH)], 'fill="url(#wg)"')}
${poly([P(0,0),P(N,0),P(N,N),P(0,N)], 'fill="#1A1A1D"')}
${poly([P(0,0),P(N,0),P(N,N),P(0,N)], 'fill="url(#fl)"')}
<polyline points="${pts([P(0,N),P(0,0),P(N,0)])}" fill="none" stroke="${ink}" stroke-opacity=".12" stroke-width="${W*.02}"/>
${poly([P(d0,0),P(d1,0),P(d1+.35,1.9),P(d0-.35,1.9)], 'fill="url(#sp)"')}
${poly([P(d0-.14,0),P(d1+.14,0),P(d1+.14,0,dh+W*.08),P(d0-.14,0,dh+W*.08)], 'fill="#2A2A2E"')}
<g transform="translate(${-g},0)">${poly([P(d0,0),P(d1,0),P(d1,0,dh),P(d0,0,dh)], 'fill="#E5484D" opacity=".85"')}</g>
${poly([P(d0,0),P(d1,0),P(d1,0,dh),P(d0,0,dh)], `fill="${ink}"`)}
<g transform="translate(${g*.8},0)"><clipPath id="sl"><rect x="0" y="${(P(d0,0,dh*.55)[1]).toFixed(1)}" width="1024" height="${(W*.07).toFixed(1)}"/></clipPath>${poly([P(d0,0),P(d1,0),P(d1,0,dh),P(d0,0,dh)], `fill="${ink}" clip-path="url(#sl)"`)}</g>
<g transform="translate(${pl[0].toFixed(1)},${pl[1].toFixed(1)}) scale(${s.toFixed(3)})">
 <ellipse cx="0" cy="0" rx="10" ry="5" fill="#000" opacity=".55"/>
 <rect x="-6.5" y="-25" width="13" height="21" rx="6.5" fill="url(#pg)"/>
 <circle cx="0" cy="-31" r="5.5" fill="#F1EEE7"/>
</g>
</svg>`;
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  const shots = [
    ['icon.png', { W: 265, bg: '#0B0B0C' }],          // iOS / legacy / web: full-bleed
    ['icon_foreground.png', { W: 255, bg: null }],    // Android adaptive foreground (safe zone)
  ];
  for (const [name, o] of shots) {
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg(o)}</body></html>`);
    await p.screenshot({ path: OUT + name, omitBackground: !o.bg, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  await b.close();
})();
