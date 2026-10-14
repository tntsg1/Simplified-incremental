const {chromium}=require(process.argv[2]);
const fs=require('node:fs'),assert=require('node:assert/strict');
const live=process.argv[3]==='live';
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
  const page=await browser.newPage({locale:'zh-CN',reducedMotion:'reduce'});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  if(!live){
   await page.route('https://stellarascensiongame.com/skyguard/play/',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync('G:/CODE/stellar-web/public/stellar/skyguard/play/index.html')}));
   await page.route('**/skyguard/launcher.js?*',r=>r.fulfill({contentType:'text/javascript',body:fs.readFileSync('G:/CODE/stellar-web/public/stellar/skyguard/launcher.js')}));
  }
  await page.goto('https://stellarascensiongame.com/skyguard/play/');
  const results=[];
  for(const language of ['en','zh']){
   await page.locator('.nav [data-language="'+language+'"]').click();
   for(const width of [320,390,768]){
    await page.setViewportSize({width,height:844});
    await page.evaluate(()=>document.getElementById('game-toolbar').classList.remove('hidden'));
    const layout=await page.locator('.game-toolbar').evaluate(el=>({scroll:el.scrollWidth,width:innerWidth,buttons:[...el.querySelectorAll('button')].map(b=>{const r=b.getBoundingClientRect();return {left:r.left,right:r.right};})}));
    assert(layout.scroll<=width);assert(layout.buttons.every(b=>b.left>=0&&b.right<=width));
    await page.evaluate(()=>document.getElementById('game-toolbar').classList.add('hidden'));
    await page.locator('#settings-open').click();
    const overflow=await page.locator('#settings').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));
    assert(overflow.scroll<=overflow.width);
    await page.locator('[data-close="settings"]').click();results.push({language,width});
   }
  }
  assert.deepEqual(errors,[]);console.log('LANGUAGE_LAYOUT_PASS',JSON.stringify({live,results,errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
