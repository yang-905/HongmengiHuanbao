const fs = require('fs');
const p = 'D:/11/HongmengiHuanbao/app/entry/src/main/ets/pages/Index.ets';
const s = fs.readFileSync(p,'utf8');
console.log(s.split(/\n/).length);
console.log(s.includes('@Entry'));
console.log(s.includes('struct Index'));
console.log(s.match(/export\s+default\s+class|export\s+default\s+struct/) ? 'has_export' : 'no_export');
