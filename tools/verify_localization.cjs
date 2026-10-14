const {chromium}=require(process.argv[2]);
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const live=process.argv[3]==='live';
const version=process.argv[4]||'20261010-skyguard-v4';
const out=path.resolve(`build/localization/${live?'live':'local'}`);fs.mkdirSync(out,{recursive:true});
const site=path.resolve('G:/CODE/stellar-web/public/stellar'),pack=path.resolve('build/web-en');
const cap=html=>html.replace("args:['--main-pack',pack]","args:['--main-pack',pack,'--max-fps','30']");
let server;
(async()=>{
 let origin='https://stellarascensiongame.com';
 if(!live){
  server=http.createServer((req,res)=>{
   const url=new URL(req.url,'http://localhost');let name=url.pathname.replace(/^\/stellar/,'');
   let file=name.startsWith('/game/')?path.join(pack,path.basename(name)):path.join(site,name.endsWith('/')?name+'index.html':name);
   if(!file.startsWith(site)&&!file.startsWith(pack)){res.writeHead(403).end();return;}
   if(!fs.existsSync(file)){res.writeHead(404).end();return;}
   const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.svg':'image/svg+xml','.png':'image/png'};
   res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
   if(path.extname(file)==='.html'){
    let html=fs.readFileSync(file,'utf8');
    if(name.includes('/game/'))html=cap(html);
    else html=html.replace(/20261010-skyguard-v\d+/g,version);
    res.end(html);
   }else fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));origin='http://127.0.0.1:'+server.address().port;
 }
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:1600,height:1000},locale:'zh-CN'});
  if(live)await context.route('**/game/**/index.html',async route=>{
   const response=await route.fetch();await route.fulfill({response,body:cap(await response.text())});
  });
  const page=await context.newPage(),errors=[],checks=[];
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log('BROWSER_ERROR',m.text());}});
  await page.goto(origin+'/skyguard/play/');
  await page.locator('.nav [data-language="en"]').click();
  await page.evaluate(()=>{const p=JSON.parse(localStorage.getItem('skyguard.settings.v1'));p.sound=false;localStorage.setItem('skyguard.settings.v1',JSON.stringify(p));});
  await page.reload();
  assert.equal(await page.locator('html').getAttribute('lang'),'en');
  assert.equal(await page.locator('#new-game .lbl').textContent(),'New Game');
  await page.locator('#guide-open').click();assert.equal(await page.locator('#guide h2').textContent(),'The First Defense');
  await page.locator('[data-close="guide"]').click();
  await page.setViewportSize({width:390,height:844});
  await page.waitForTimeout(1400);await page.screenshot({path:path.join(out,'launcher-mobile-en.png')});
  assert(await page.locator('.nav [data-language="en"]').isVisible());
  const overflow=await page.locator('.nav').evaluate(el=>el.scrollWidth>el.clientWidth+1);assert.equal(overflow,false);
  await page.setViewportSize({width:1600,height:1000});await page.waitForTimeout(350);
  await page.screenshot({path:path.join(out,'launcher-en.png')});checks.push('English launcher/manual, mobile navigation, persisted choice');
  async function start(button){
   await page.locator(button).click();await page.locator('#loading').waitFor({state:'hidden',timeout:90000});
   const frame=page.frames().find(f=>f.url().includes('/game/'));
   assert(frame.url().includes(version));await frame.waitForFunction(()=>window.SkyguardBridge.game_language==='en');
   await frame.locator('canvas').focus();return frame;
  }
  let frame=await start('#new-game');
  await frame.waitForFunction(()=>window.SkyguardBridge.hud_stage_text.includes('City'));
  await page.waitForTimeout(750);await page.screenshot({path:path.join(out,'battle-en.png')});
  const hud=await frame.evaluate(()=>({stage:SkyguardBridge.hud_stage_text,wave:SkyguardBridge.hud_wave_text,hint:SkyguardBridge.hud_hint_text}));
  assert(!/[\u4e00-\u9fff]/.test(JSON.stringify(hud)));checks.push({englishHud:hud});
  await page.keyboard.press('Escape');await frame.waitForFunction(()=>SkyguardBridge.game_menu==='pause');
  await page.waitForTimeout(750);await page.screenshot({path:path.join(out,'pause-en.png')});
  await page.locator('.game-toolbar [data-language="en"]').click();
  await page.waitForFunction(()=>!!localStorage.getItem('skyguard.campaign.v1'));
  const snapshot=()=>page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('skyguard.campaign.v1'));delete s.settings;return JSON.stringify(s);});
  const before=await snapshot();
  await page.locator('.game-toolbar [data-language="zh"]').click();await frame.waitForFunction(()=>SkyguardBridge.game_language==='zh');
  await page.waitForFunction(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')).settings.language==='zh');
  assert.equal(await snapshot(),before);assert.equal(await frame.evaluate(()=>SkyguardBridge.game_menu),'pause');
  await page.locator('.game-toolbar [data-language="en"]').click();await frame.waitForFunction(()=>SkyguardBridge.game_language==='en');
  await page.waitForTimeout(700);
  const button=await frame.evaluate(()=>({x:SkyguardBridge.language_button_x,y:SkyguardBridge.language_button_y,visible:SkyguardBridge.language_button_visible}));
  assert(button.visible);const canvas=await frame.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x+button.x,canvas.y+button.y);
  await frame.waitForFunction(()=>SkyguardBridge.game_language==='zh');
  await page.waitForFunction(()=>document.documentElement.lang==='zh-CN');
  assert.equal(await page.locator('.game-toolbar [data-language="zh"]').getAttribute('aria-pressed'),'true');
  await page.locator('.game-toolbar [data-language="en"]').click();await frame.waitForFunction(()=>SkyguardBridge.game_language==='en');
  checks.push('Host and actual pause-menu language buttons synchronize without changing paused campaign');
  await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
  const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')));assert.equal(saved.settings.language,'en');
  await page.reload();frame=await start('#continue-game');
  await frame.waitForFunction(()=>SkyguardBridge.hud_stage_text.includes('City'));
  await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
  const restored=await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')));
  assert.equal(restored.stage,saved.stage);assert.equal(restored.wave,saved.wave);assert.equal(restored.settings.language,'en');
  checks.push('Real save/refresh/continue retains English and campaign progress');
  // A deterministic final-boss fixture exercises actual English ending captions and skip/result.
  const seed=fs.readFileSync('proofs/ending_boss_seed.json','utf8');
  await page.evaluate(seed=>localStorage.setItem('skyguard.campaign.v1',seed),seed);await page.reload();frame=await start('#continue-game');
  await frame.waitForFunction(()=>SkyguardBridge.cinematic_kind==='ending'&&SkyguardBridge.cinematic_time>=1,{},{timeout:15000});
  await page.screenshot({path:path.join(out,'ending-silence-en.png')});
  await frame.waitForFunction(()=>SkyguardBridge.cinematic_time>=7);await page.screenshot({path:path.join(out,'ending-collapse-en.png')});
  await page.keyboard.press('Escape');await frame.waitForFunction(()=>SkyguardBridge.game_menu==='result');
  await page.waitForTimeout(850);await page.screenshot({path:path.join(out,'result-en.png')});
  await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')).mode),'victory');
  checks.push('Final boss defeat, English ending captions, skip and victory save');
  assert.deepEqual(errors,[]);const result={live,version,visualFpsCap:30,checks,errors};
  fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(result,null,2));console.log('LOCALIZATION_BROWSER_PASS',JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>server?.close());
