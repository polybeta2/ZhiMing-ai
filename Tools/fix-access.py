#!/usr/bin/env python
# 解析 xtool 构建日志中的跨 target 可访问性错误，按编译器 note 定位声明行加 public。
# 用法: python Tools/fix-access.py <构建日志文件>
import io, re, sys

log = io.open(sys.argv[1], encoding='utf-8', errors='replace').read()
PREFIX = '/mnt/d/iOS/ZhiMing/'
ACC = re.compile(r'error: [^:\n]*(inaccessible due to .internal. protection level|must be declared public because)')
NOTE = re.compile(r'^%s(Sources/ZhiMingCore/[^\s:]+\.swift):(\d+):(\d+): note: ' % re.escape(PREFIX))

# 收集"declaration"行：可访问性错误的 note（真实文件路径）以及错误本身的声明行
lines_by_file = {}
for m in re.finditer(r'^%s(Sources/ZhiMingCore/[^\s:]+\.swift):(\d+):(\d+): note: ' % re.escape(PREFIX), log, re.M):
    lines_by_file.setdefault(m.group(1), set()).add(int(m.group(2)))
for m in re.finditer(r'^%s(Sources/ZhiMingCore/[^\s:]+\.swift):(\d+):(\d+): error: [^\n]*(must be declared public because)[^\n]*$' % re.escape(PREFIX), log, re.M):
    lines_by_file.setdefault(m.group(1), set()).add(int(m.group(2)))

if not lines_by_file:
    print('NO-FIX')
else:
    for f, lns in sorted(lines_by_file.items()):
        with io.open(f, encoding='utf-8') as fh:
            src = fh.readlines()
        n = 0
        for ln in sorted(lns):
            i = ln - 1
            s = src[i].rstrip('\n')
            st = s.lstrip()
            if st.startswith(('public', 'private', 'fileprivate', '@')):
                if st.startswith('@Published') and 'public' not in st:
                    src[i] = s.replace('@Published', '@Published public', 1) + '\n'; n += 1
                continue
            if not st:
                continue
            src[i] = s.replace(st, 'public ' + st, 1) + '\n'; n += 1
        with io.open(f, 'w', encoding='utf-8', newline='') as fh:
            fh.writelines(src)
        print(f'publicized {n:3d} in {f}')
