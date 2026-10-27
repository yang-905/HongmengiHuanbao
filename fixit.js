const fs = require('fs');
const p = './app/entry/src/main/ets/ui/GlassDialog.ets';
let s = fs.readFileSync(p, 'utf8');
const start = s.indexOf('Column({ space: Space.SM }) {');
const trees = s.indexOf('ForEach(this.trees', start);
const row = s.indexOf('Row({ space: Space.MD })', trees);
if (start === -1 || trees === -1 || row === -1) { console.log('bad'); process.exit(1); }
const colStart = s.lastIndexOf('\n', start) + 1;
const rep = `          Column({ space: Space.SM }) {
            ForEach(this.trees, (t: TreeItem, idx: number) => {
              if (idx % 2 === 0) {
                Row({ space: Space.SM }) {
                  this.TreeCell(this.trees[idx])
                  if (idx + 1 < this.trees.length) {
                    this.TreeCell(this.trees[idx + 1])
                  } else {
                    Column().layoutWeight(1)
                  }
                }
                .width('100%')
              }
            }, (t: TreeItem): string => t.key)
          }
          .width('100%')

`;
s = s.slice(0, colStart) + rep + s.slice(row);
fs.writeFileSync(p, s);
console.log('ok');
