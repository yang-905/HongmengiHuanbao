import sys

p = r'D:\11\carbon-master\docs\液态玻璃与深色模式方案.md'
raw = open(p, 'rb').read()
text = raw.decode('utf-8')
if text.startswith('\ufeff'):
    text = text[1:]
# The file was produced by: original_utf8_bytes --(decoded as cp936)--> text --> utf8
# so reverse: text.encode(cp936) should give back the original utf-8 bytes.
try:
    recovered = text.encode('cp936').decode('utf-8')
except Exception as e:
    print('REVERSE FAILED:', e)
    sys.exit(1)

ok_marks = ['# 一触青绿', '## 0. 一句话结论', '## 7. 数据自动刷新链路', '光照模型', '深色模式']
report = []
for m in ok_marks:
    report.append('%s -> %s' % (m, 'OK' if m in recovered else 'MISSING'))
out = '\n'.join(report)
open(r'D:\11\carbon-master\.workbuddy\tmp\recover_report.txt', 'w', encoding='utf-8').write(out)
open(r'D:\11\carbon-master\.workbuddy\tmp\recovered_doc.md', 'w', encoding='utf-8').write(recovered)
print(out.encode('ascii', 'replace').decode('ascii'))
print('recovered bytes:', len(recovered.encode('utf-8')))
