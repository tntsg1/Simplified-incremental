// Run through G:/CODE/tools/run_limited.py; pass the installed Playwright module.
const { chromium } = require(process.argv[2]);
const { readFileSync, writeFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const seed = readFileSync('proofs/ultimate_loot_seed.json', 'utf8');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--enable-unsafe-swiftshader'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1600, height: 1000 } });
    const page = await context.newPage();
    const errors = [], warnings = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error') errors.push(message.text());
      if (message.type() === 'warning') warnings.push(message.text());
    });
    await page.goto('https://stellarascensiongame.com/skyguard/play/?verify=20261008-loot', { waitUntil: 'networkidle' });
    const prefix = await page.locator('#game-frame').getAttribute('data-src');
    assert(prefix.includes('20261008-skyguard-v1'));
    const head = await context.request.head('https://stellarascensiongame.com/game/20261008-skyguard-v1/index.pck');
    assert.equal(head.status(), 200);
    assert.equal(head.headers().etag.replaceAll('"', ''), 'ad2ba77d8d33ec4350870697a2f2f542');
    await page.evaluate(seed => {
      localStorage.setItem('skyguard.campaign.v1', seed);
      localStorage.setItem('skyguard.settings.v1', JSON.stringify({sound:false, music_level:0, effects_level:0}));
    }, seed);
    await page.reload();
    await page.locator('#continue-game').click();
    await page.locator('#loading').waitFor({ state: 'hidden', timeout: 90000 });
    const frame = page.frames().find(frame => frame.url().includes('/game/'));
    assert(frame);
    await frame.locator('canvas').focus();
    await page.mouse.move(5, 5);
    await page.keyboard.press('q');
    const phases = {};
    for (let tick = 0; tick < 180; tick++) {
      await frame.evaluate(() => window.SkyguardBridge.commands.push({action:'settings', settings:{sound:false}}));
      await page.waitForTimeout(100);
      const save = await page.evaluate(() => JSON.parse(localStorage.getItem('skyguard.campaign.v1')));
      const batch = save.reward_batches?.[0];
      let phase;
      if (save.kills === 240 && batch?.age > .5 && batch.age < .95) phase = 'hold';
      else if (batch?.age > 1.05 && batch.age < 1.25) phase = 'burst';
      else if (batch?.age > 1.45 && batch.age < 1.65) phase = 'pull';
      else if (save.money === 2400) phase = 'paid';
      if (phase && !phases[phase]) {
        assert.equal(save.money, phase === 'paid' ? 2400 : 0);
        phases[phase] = { money: save.money, kills: save.kills, age: batch?.age };
        await page.screenshot({ path: `proofs/ultimate_loot_live_${phase}.png` });
      }
      if (Object.keys(phases).length === 4) break;
    }
    assert.equal(Object.keys(phases).length, 4, JSON.stringify(phases));
    await page.locator('#return-home').click();
    await page.locator('#launcher').waitFor({ state:'visible' });
    await page.reload();
    await page.locator('#continue-game').click();
    await page.locator('#loading').waitFor({state:'hidden', timeout:90000});
    await page.locator('#return-home').click();
    await page.locator('#launcher').waitFor({state:'visible'});
    const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('skyguard.campaign.v1')));
    assert.equal(saved.money, 2400);
    assert.deepEqual(saved.reward_batches, []);
    assert.equal(errors.length, 0, JSON.stringify(errors));
    const result = { prefix, phases, restoredMoney:saved.money, errors, warnings };
    writeFileSync('proofs/ultimate-loot-live.json', JSON.stringify(result, null, 2));
    console.log('ULTIMATE_LOOT_LIVE_OK', JSON.stringify(result));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
