const { chromium } = require('/opt/node-tools/node_modules/playwright');
(async()=>{const b=await chromium.launch({proxy:{server:process.env.HTTPS_PROXY}}).catch(()=>chromium.launch());
const p=await b.newPage({ignoreHTTPSErrors:true,viewport:{width:1080,height:1350}});
await p.goto('file://'+__dirname+'/slides.html',{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);await p.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>setTimeout(r,500));await document.fonts.ready});await p.waitForLoadState('networkidle');await p.waitForTimeout(1500);console.log(await p.evaluate(()=>document.fonts.check('900 40px "Noto Sans TC"')));
const s=await p.$$('.slide');for(let i=0;i<s.length;i++)await s[i].screenshot({path:`slide-${String(i+1).padStart(2,'0')}.png`});
await b.close();console.log(s.length)})();
