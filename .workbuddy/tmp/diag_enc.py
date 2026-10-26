import sys
import collections

p = r'D:\11\carbon-master\docs\液态玻璃与深色模式方案.md'
raw = open(p, 'rb').read()
text = raw.decode('utf-8')
if text.startswith('\ufeff'):
    text = text[1:]

bad = collections.Counter()
for ch in text:
    try:
        ch.encode('gbk')
    except Exception:
        bad[ch] += 1

lines = ['unencodable chars in gbk: %d kinds, %d total' % (len(bad), sum(bad.values()))]
for ch, n in bad.most_common(20):
    lines.append('U+%04X  count=%d  utf8bytes=%s' % (ord(ch), n, ch.encode('utf-8').hex()))
open(r'D:\11\carbon-master\.workbuddy\tmp\bad_chars.txt', 'w', encoding='utf-8').write('\n'.join(lines))
print('\n'.join(lines).encode('ascii', 'replace').decode('ascii'))
