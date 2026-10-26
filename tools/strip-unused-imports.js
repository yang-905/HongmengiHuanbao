// 删除 .ets 文件中未使用的 import 符号
// 安全策略：符号在 import 行之外的全文（含注释）零出现才删除
const fs = require('fs');
const path = require('path');

const ROOT = 'D:/11/carbon-master/app/entry/src/main/ets';

function walk(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(walk(p));
    else if (e.name.endsWith('.ets')) out.push(p);
  }
  return out;
}

const files = walk(ROOT);
let removedCount = 0;
const report = [];

for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  const lines = src.split('\n');

  // 1. 找出所有 import 语句占据的行范围（支持多行 import { \n A, \n B \n } from '...'）
  const importRanges = [];
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (/^import\s/.test(t)) {
      // 从 i 开始找闭合（含 from '...' 的行）
      let j = i;
      while (j < lines.length && !/from\s+['"]/.test(lines[j])) j++;
      importRanges.push([i, j]);
    }
  }
  if (importRanges.length === 0) continue;

  // 2. 全文去掉 import 行后的「使用区」
  const usageLines = lines.filter((_, idx) =>
    !importRanges.some(([a, b]) => idx >= a && idx <= b));
  const usageText = usageLines.join('\n');

  // 3. 逐 import 语句处理
  let dirty = false;
  const fileRemoved = [];
  const newLines = lines.slice();

  // 从后往前改，避免行号偏移
  for (let k = importRanges.length - 1; k >= 0; k--) {
    const [a, b] = importRanges[k];
    const block = lines.slice(a, b + 1).join('\n');
    const m = block.match(/import\s*\{([\s\S]*?)\}\s*from\s*(['"][^'"]+['"])/);
    if (!m) continue;
    const syms = m[1].split(',').map(s => s.trim()).filter(Boolean);
    const kept = [];
    const dropped = [];
    for (const s of syms) {
      // 去掉 as 别名情况：原样整体判断太复杂，本项目无 import 别名，跳过含 ' as ' 的
      if (s.includes(' as ')) { kept.push(s); continue; }
      const re = new RegExp('\\b' + s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b');
      if (re.test(usageText)) kept.push(s);
      else dropped.push(s);
    }
    if (dropped.length === 0) continue;
    fileRemoved.push(...dropped.map(d => `${d} (${file.replace(ROOT + '/', '')})`));
    dirty = true;
    removedCount += dropped.length;

    if (kept.length === 0) {
      // 整条删除
      newLines.splice(a, b - a + 1);
    } else {
      const fromPart = m[2];
      const single = `import { ${kept.join(', ')} } from ${fromPart};`;
      newLines.splice(a, b - a + 1, single);
    }
  }

  if (dirty) {
    fs.writeFileSync(file, newLines.join('\n'));
    report.push(...fileRemoved);
  }
}

console.log(`共删除 ${removedCount} 个未使用符号，涉及 ${report.length} 处：`);
report.sort().forEach(r => console.log('  - ' + r));
