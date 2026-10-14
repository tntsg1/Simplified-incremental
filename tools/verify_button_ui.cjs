const {chromium}=require(process.argv[2]);const fs=require('node:fs');const assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader']});try{
 const page=await browser.newPage({viewport:{width:1600,height:1000},reducedMotion:'reduce'});const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const local=process.argv[3]==='local';await page.goto(local?'http://127.0.0.1:5191/skyguard/play/':'https://stellarascensiongame.com/skyguard/play/');
 await page.evaluate(seed=>{localStorage.setItem('skyguard.campaign.v1',seed);localStorage.setItem('skyguard.settings.v1',JSON.stringify({sound:false,music_level:0,effects_level:0,ui_motion:true}));},fs.readFileSync('proofs/ultimate_loot_seed.json','utf8'));
 await page.reload();if(local)await page.locator('#game-frame').evaluate(el=>el.dataset.src='/game/20261005-skyguard-v1/index.html');await page.locator('#continue-game').click();await page.locator('#loading').waitFor({state:'hidden',timeout:90000});const frame=page.frames().find(f=>f.url().includes('/game/'));await frame.locator('canvas').focus();await page.keyboard.press('Escape');await page.mouse.move(4,4);await page.waitForTimeout(800);await page.screenshot({path:'proofs/button-ui-pause.png'});
 
 // Actual visible Godot buttons; exercise interrupted motion and press, then
 // toggle in-game, round-trip preferences to HTML, and reload/continue.
 await page.mouse.move(692,332);await page.waitForTimeout(40);await page.screenshot({path:'proofs/button-ui-enter.png'});
 await page.waitForTimeout(750);await page.screenshot({path:'proofs/button-ui-hover.png'});
 const textPixels=await page.screenshot({clip:{x:720,y:318,width:160,height:28}});
 const histogram=await page.evaluate(async b64=>{const img=await createImageBitmap(await (await fetch('data:image/png;base64,'+b64)).blob());const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const ctx=c.getContext('2d');ctx.drawImage(img,0,0);const pixels=ctx.getImageData(0,0,c.width,c.height).data;let dark=0,white=0;for(let i=0;i<pixels.length;i+=4){if(pixels[i]<100)dark++;if(pixels[i]>180)white++;}return {dark,white};},textPixels.toString('base64'));
 assert(histogram.dark>50 && histogram.white>3000,'Hovered text must remain readable: '+JSON.stringify(histogram));
 console.log('HOVER_TEXT_OK',JSON.stringify(histogram));
 for(let i=0;i<8;i++){await page.mouse.move(820,i%2?400:332);await page.waitForTimeout(35);}
 await page.mouse.move(820,696);await page.waitForTimeout(700);await page.mouse.down();await page.waitForTimeout(75);await page.screenshot({path:'proofs/button-ui-press.png'});await page.mouse.up();
 await page.waitForFunction(()=>JSON.parse(localStorage.getItem('skyguard.settings.v1')).ui_motion===false);
 assert.equal(await page.locator('#ui-motion').isChecked(),false);assert.equal(await page.evaluate(()=>window.sgUiMotion),false);
 await page.mouse.move(810,332);await page.waitForTimeout(700);await page.screenshot({path:'proofs/button-ui-static.png'});
 await page.mouse.click(810,696);await page.waitForFunction(()=>JSON.parse(localStorage.getItem('skyguard.settings.v1')).ui_motion===true);
 // Parent settings changes also reach the running game, without a reload.
 await frame.evaluate(()=>SkyguardBridge.commands.push({action:'settings',settings:{sound:false,ui_motion:false}}));
 await page.waitForFunction(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')).settings.ui_motion===false);
 await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
 await page.reload();if(local)await page.locator('#game-frame').evaluate(el=>el.dataset.src='/game/20261005-skyguard-v1/index.html');
 assert.equal(await page.locator('#ui-motion').isChecked(),false);
 await page.locator('#continue-game').click();await page.locator('#loading').waitFor({state:'hidden',timeout:90000});
 await page.locator('#return-home').click();await page.locator('#launcher').waitFor({state:'visible'});
 assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('skyguard.campaign.v1')).settings.ui_motion),false);

 assert.deepEqual(errors,[]);console.log('UI_BUTTON_BROWSER_OK');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
