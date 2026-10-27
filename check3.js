const fs = require('fs');
const p = 'D:/11/HongmengiHuanbao/app/entry/src/main/ets/pages/Index.ets';
const s = fs.readFileSync(p,'utf8');
console.log(s.length);
console.log(s.indexOf('struct'));
console.log(s.indexOf('@Entry'));
console.log(s.indexOf('export'));
