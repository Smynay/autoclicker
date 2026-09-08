import { chromium } from 'playwright-core';
import { execSync } from 'child_process';
const wait = ms => new Promise(r => setTimeout(r, ms));
const STATE = () => execSync(`osascript -e 'tell application "System Events" to tell process "AutoClicker" to get name of menu item 1 of menu 1 of menu bar item 1 of menu bar 1'`).toString().trim();
const browser = await chromium.launch({ headless: false, chromiumSandbox: false, executablePath: process.env.CHROMIUM_PATH, args: ['--window-position=200,120','--window-size=1100,760'] });
const page = await browser.newPage({ viewport: { width: 1000, height: 620 } });
await page.goto('https://testmouse.com/cps-test', { waitUntil: 'domcontentloaded' });
await wait(2500);
const bbox = await page.evaluate(() => {
  for (const el of document.querySelectorAll('div')) {
    const c = String(el.className);
    if (c.includes('cursor-pointer') && !c.includes('pointer-events')) {
      const r = el.getBoundingClientRect();
      if (r.height > 300) { el.scrollIntoView({ block: 'center' });
        const btn = [...el.querySelectorAll('button')].find(x => /start/i.test(x.textContent||''));
        const br = btn.getBoundingClientRect();
        return { ax: Math.round(r.x + r.width/2), ay: Math.round(r.y + r.height/2), bx: Math.round(br.x + br.width/2), by: Math.round(br.y + br.height/2) };
      }
    }
  }
  return null;
});
const geo = await page.evaluate(() => ({ sx: window.screenX, sy: window.screenY, oh: window.outerHeight, ih: window.innerHeight }));
const mv = geo.oh - geo.ih;
const ax = geo.sx + bbox.ax, ay = geo.sy + mv + bbox.ay;
const stStart = geo.sx + bbox.bx, syStart = geo.sy + mv + bbox.by;

console.log('[initial state]:', STATE());
// step 1: click Start
execSync(`./mousectl click ${stStart} ${syStart}`);
await wait(1200);
console.log('[after Start click]:', JSON.stringify(await page.evaluate(() => document.body.innerText.match(/Click like crazy|Start Test/)?.[0])));
// step 2: cursor to area, toggle clicker ON, verify
execSync(`./mousectl warp ${ax} ${ay}`);
execSync(`osascript -e 'tell application "System Events" to tell process "AutoClicker" to click menu item 1 of menu 1 of menu bar item 1 of menu bar 1'`);
await wait(300);
console.log('[state after ON toggle]:', STATE());
const counts = [];
for (let i = 1; i <= 6; i++) {
  await wait(2000);
  counts.push(await page.evaluate(() => parseInt(document.body.innerText.match(/Total Clicks\s*(\d+)/)?.[1] || '-1')));
}
console.log('counts 8s:', counts.join(','));
// step 3: OFF
execSync(`osascript -e 'tell application "System Events" to tell process "AutoClicker" to click menu item 1 of menu 1 of menu bar item 1 of menu bar 1'`);
await wait(500);
console.log('[state after OFF toggle]:', STATE());
console.log('[final page]:', JSON.stringify(await page.evaluate(() => document.body.innerText.match(/Total Clicks\s*\d+[\s\S]{0,60}/)?.[0])));
await browser.close();
