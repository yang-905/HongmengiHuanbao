import sys
p = r'D:\11\HongmengiHuanbao\app\entry\src\main\ets\pages\Index.ets'
with open(p, encoding='utf-8') as f:
    s = f.read()
print(len(s.splitlines()))
print('ENTRY' if '@Entry' in s else 'NO_ENTRY')
print('COMPONENT' if 'struct Index' in s else 'NO_STRUCT')
