const fs = require('fs');
const s = fs.readFileSync('D:/11/HongmengiHuanbao/app/entry/src/main/ets/pages/Index.ets','utf8');
console.log(s.substring(0,80));
console.log('---');
console.log(s.match(/^(@Entry|export default)/m));
