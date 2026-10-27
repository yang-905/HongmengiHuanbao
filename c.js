const fs = require('fs');
const p = 'D:/11/HongmengiHuanbao/app/entry/src/main/ets/pages/Index.ets';
const s = fs.readFileSync(p,'utf8');
console.log(s.split(/\r?\n/).length);
