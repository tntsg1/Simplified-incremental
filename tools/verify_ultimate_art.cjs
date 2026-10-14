const {chromium}=require(process.argv[2]);
const fs=require('node:fs');
const assert=require('node:assert/strict');
const local=process.argv[3]==='local';
const review=process.argv[4]==='review';
const light=process.argv[4]==='light';
const kinds={2:'foil',3:'prime',4:'lightspeed',5:'pi'};
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader']});
 try {
  const page=await browser.newPage({viewport:{width:1600,height:1000},...(review?{recordVideo:{dir:'proofs/ultimate-v13-video',size:{width:1600,height:1000}}}:{})});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const results=[];
  const cases=light?[[4,false,24],[4,true,24],[4,false,720]]:review?[[2,false,24],[3,false,24],[4,false,24]]:local?[[2,false,24],[3,false,24],[4,false,24],[5,false,24],[2,true,24],[4,true,24],[2,false,720],[4,false,720]]:[[2,false,24],[3,false,24],[4,false,24],[5,false,24]];
  for(const [stage,soft,count] of cases){
   const seed=JSON.parse(fs.readFileSync(`proofs/ultimate_art_seed_${stage}.json`,'utf8'));
   const originals=seed.enemies;
   if(count>24){seed.enemies=Array.from({length:count},(_,i)=>({...originals[i%24],id:i+1}));seed.serial=count;}
   await page.goto(local?'http://127.0.0.1:5191/skyguard/play/':'https://stellarascensiongame.com/skyguard/play/');
   await page.evaluate(({seed,soft})=>{localStorage.setItem('skyguard.campaign.v1',JSON.stringify(seed));localStorage.setItem('skyguard.settings.v1',JSON.stringify({sound:false,ui_motion:true,game_speed:1,reduced_effects:soft}));},{seed,soft});
   await page.reload();
   if(local)await page.locator('#game-frame').evaluate(el=>el.dataset.src='/game/20261005-skyguard-v1/index.html');
   else assert((await page.locator('#game-frame').getAttribute('data-src')).includes('20261009-skyguard-v13'));
   await page.locator('#continue-game').click();
   await page.locator('#loading').waitFor({state:'hidden',timeout:90000});
   const frame=page.frames().find(f=>f.url().includes('/game/'));
   await frame.locator('canvas').focus();await page.mouse.move(800,550);await page.waitForTimeout(100);
   const timing=frame.evaluate(()=>new Promise(resolve=>{const samples=[];let last=performance.now(),seen=false;function tick(now){const b=window.SkyguardBridge;samples.push({delta:now-last,kind:b.ultimate_kind,age:b.ultimate_age,draw:b.render_ms});last=now;if(b.ultimate_kind)seen=true;if(seen&&!b.ultimate_kind)resolve(samples);else requestAnimationFrame(tick);}requestAnimationFrame(tick);}));
   await page.keyboard.press('q');
   await frame.waitForFunction(k=>window.SkyguardBridge.ultimate_kind===k,kinds[stage],{timeout:10000});
   const phases=[];
   for(const t of review?[.5,1,1.7,2.35,3.25]:[1,2.35,3.25]){
    await frame.waitForFunction(t=>window.SkyguardBridge.ultimate_age>=t,t,{timeout:15000});
    const phase=await frame.evaluate(()=>({age:window.SkyguardBridge.ultimate_age,kind:window.SkyguardBridge.ultimate_kind}));
    assert.equal(phase.kind,kinds[stage]);phases.push(phase);
    await page.screenshot({path:`proofs/ultimate-v13-${local?'local':'live'}-${stage}-${soft?'soft':'full'}-${count}-${t}.png`});
    if(stage===4&&t===1&&!soft&&count===24){
     await page.keyboard.press('Escape');await frame.waitForFunction(()=>window.SkyguardBridge.game_menu==='pause');
     const held=await frame.evaluate(()=>window.SkyguardBridge.ultimate_age);await page.waitForTimeout(250);
     assert.equal(await frame.evaluate(()=>window.SkyguardBridge.ultimate_age),held,'Pause must hold deployment time');
     await page.keyboard.press('Escape');await frame.waitForFunction(()=>window.SkyguardBridge.game_menu==='');
    }
   }
   await frame.waitForFunction(()=>!window.SkyguardBridge.ultimate_kind,{},{timeout:15000});
   const samples=(await timing).filter(s=>s.kind);const delta=samples.map(s=>s.delta).sort((a,b)=>a-b);const draw=samples.map(s=>s.draw).sort((a,b)=>a-b);
   const metrics={stage,soft,count,phases,p95:delta[Math.floor(delta.length*.95)],max:delta.at(-1),drawP95:draw[Math.floor(draw.length*.95)]};
   assert(metrics.max<1000,`Ultimate froze browser: ${JSON.stringify(metrics)}`);
   await page.waitForTimeout(3400);
   await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
   const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')));
   assert.equal(saved.stage,stage);assert.equal(saved.health,100);assert(saved.money>0);assert.deepEqual(saved.reward_batches,[]);
   if(count===24){const expected=seed.enemies.reduce((sum,e)=>sum+e.members,0);if(stage===2)assert(saved.kills>=expected);else assert.equal(saved.kills,expected);}
   if(!local || count===24&&!soft){
    await page.reload();if(local)await page.locator('#game-frame').evaluate(el=>el.dataset.src='/game/20261005-skyguard-v1/index.html');
    await page.locator('#continue-game').click();await page.locator('#loading').waitFor({state:'hidden',timeout:90000});
    await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
    const restored=await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')));
    assert.equal(restored.money,saved.money);assert.equal(restored.kills,saved.kills);
   }
   metrics.money=saved.money;metrics.kills=saved.kills;results.push(metrics);console.log('ULTIMATE_BROWSER_CASE',JSON.stringify(metrics));
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(`build/ultimate-v13-${light?'light':review?'review':local?'local':'live'}-metrics.json`,JSON.stringify({results,errors},null,2));console.log('ULTIMATE_ART_BROWSER_OK',JSON.stringify({cases:results.length,errors}));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
