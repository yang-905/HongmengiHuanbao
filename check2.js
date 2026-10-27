const fs = require('fs');
const p = 'D:/11/HongmengiHuanbao/app/entry/src/main/ets/pages/SplashPage.ets';
const s = fs.readFileSync(p,'utf8');
console.log(s.indexOf('struct'));
console.log(s.indexOf('export'));
console.log(s.slice(0,120));
