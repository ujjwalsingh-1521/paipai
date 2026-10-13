// Run: npm i @resvg/resvg-js@2 && node branding/generate_icons.js
// Generates PaiPai launcher and notification icons from one vector design (108x108 adaptive-icon grid).
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const PROJECT = path.resolve(__dirname, '..');
const RES = `${PROJECT}/android/app/src/main/res`;
const BRAND = `${PROJECT}/branding`;

const C = { background: '#2563EB', front: '#FFFFFF', back: '#BFDBFE', dot: '#FBBF24' };

// Lowercase "p" from Fredoka SemiBold (SIL OFL), font units (1000/em, y up, baseline 0). Outlined so
// the icons don't depend on the font being installed. See README.md for how it was extracted.
const LETTER_P = 'M302.5 0Q253.5 0 216.2 19.2Q179 38.5 154.2 72.4Q129.5 106.2 117.1 150.2Q104.8 194.2 105.5 244.5Q106.2 294 119 338.6Q131.8 383.2 156.5 417.4Q181.2 451.5 217.8 471.1Q254.2 490.8 302.5 490.8Q347.2 490.8 388.4 470.8Q429.5 450.8 461.8 416.1Q494 381.5 512.5 336.6Q531 291.8 531 242.2Q531 191.5 512.5 147.2Q494 103 462.1 70Q430.2 37 389.1 18.5Q348 0 302.5 0ZM110 -216.2Q74.2 -216.2 58.4 -205.8Q42.5 -195.2 39.1 -178.6Q35.8 -162 35.8 -142.8V416.2Q35.8 435.8 39 452.4Q42.2 469 57.8 479.9Q73.2 490.8 109 490.8Q139.5 490.8 158.4 482Q177.2 473.2 184.8 454V-141.8Q186.2 -161 182.2 -178.1Q178.2 -195.2 162.4 -205.8Q146.5 -216.2 110 -216.2ZM282.2 140.8Q309.8 140.8 332 154.1Q354.2 167.5 367.5 190.5Q380.8 213.5 380.8 241.5Q380.8 270.5 367.9 293.2Q355 316 332.8 328.9Q310.5 341.8 283 341.8Q255.8 341.8 233.5 328.4Q211.2 315 198.4 292.6Q185.5 270.2 185.5 241.5Q185.5 213.5 198.8 190.5Q212 167.5 233.9 154.1Q255.8 140.8 282.2 140.8Z';

// Twin "p" (the doubled "Pai Pai") + gold dot, centred on the grid. 48-unit letters (0.048 per font unit).
const SCALE = 0.048;
const BASELINE = 61;
const FRONT_X = 26.75;   // left edge of the front p's advance box
const BACK_X = 45.75;
const DOT = { cx: 76, cy: 59, r: 3.8 };
const GAP = 5;           // clear space cut around the front p where it overlaps the back one

const letter = (x, attrs) =>
  `<path transform="translate(${x} ${BASELINE}) scale(${SCALE} ${-SCALE})" d="${LETTER_P}" ${attrs}/>`;

// The back p is masked by the front p plus a GAP-wide outline, so the two read as separate letters.
const mark = (backFill, frontFill, dotFill) => `
  <defs><mask id="gap"><rect width="108" height="108" fill="#fff"/>
    ${letter(FRONT_X, `fill="#000" stroke="#000" stroke-width="${GAP / SCALE}" stroke-linejoin="round"`)}</mask></defs>
  <g mask="url(#gap)">${letter(BACK_X, `fill="${backFill}"`)}</g>
  ${letter(FRONT_X, `fill="${frontFill}"`)}
  <circle cx="${DOT.cx}" cy="${DOT.cy}" r="${DOT.r}" fill="${dotFill}"/>`;

const svg = (body, viewBox = '0 0 108 108') =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">${body}</svg>`;

const COLOUR_MARK = mark(C.back, C.front, C.dot);
const FULL_SQUARE = svg(`<rect width="108" height="108" fill="${C.background}"/>${COLOUR_MARK}`);
const FOREGROUND = svg(COLOUR_MARK);
// Themed-icon layer (Android 13+): single colour, the system tints it.
const MONOCHROME = svg(mark('#fff', '#fff', '#fff'));
// Pre-Android-8 icon: inner 72x72 of the grid on a rounded square.
const LEGACY = svg(`<rect x="18" y="18" width="72" height="72" rx="16" fill="${C.background}"/>${COLOUR_MARK}`, '18 18 72 72');
// Status-bar icon: white mark cropped close (the system draws it at 24dp and tints it).
const STATUS_BAR = svg(mark('#fff', '#fff', '#fff'), '25 25.4 58 58');

const render = (svgText, size, outFile) => {
  const png = new Resvg(svgText, { fitTo: { mode: 'width', value: size } }).render().asPng();
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, png);
};

const DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [name, scale] of Object.entries(DENSITIES)) {
  render(LEGACY, 48 * scale, `${RES}/mipmap-${name}/ic_launcher.png`);
  render(FOREGROUND, 108 * scale, `${RES}/mipmap-${name}/ic_launcher_foreground.png`);
  render(MONOCHROME, 108 * scale, `${RES}/mipmap-${name}/ic_launcher_monochrome.png`);
  render(STATUS_BAR, 24 * scale, `${RES}/drawable-${name}/ic_stat_paipai.png`);
}
// The status-bar icon used to be a vector; the PNGs above replace it (two resources can't share a name).
fs.rmSync(`${RES}/drawable/ic_stat_paipai.xml`, { force: true });

fs.mkdirSync(`${RES}/mipmap-anydpi-v26`, { recursive: true });
fs.writeFileSync(`${RES}/mipmap-anydpi-v26/ic_launcher.xml`, `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
`);
fs.writeFileSync(`${RES}/drawable/ic_launcher_background.xml`, `<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="${C.background}"/>
</shape>
`);

fs.mkdirSync(BRAND, { recursive: true });
fs.writeFileSync(`${BRAND}/paipai_icon.svg`, FULL_SQUARE);
fs.writeFileSync(`${BRAND}/paipai_foreground.svg`, FOREGROUND);
fs.writeFileSync(`${BRAND}/paipai_monochrome.svg`, MONOCHROME);
render(FULL_SQUARE, 512, `${BRAND}/paipai_icon_512.png`);
render(STATUS_BAR, 96, `${BRAND}/paipai_status_96.png`);

console.log('done');
