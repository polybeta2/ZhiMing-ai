#!/usr/bin/env python3
"""织命 App 图标生成器：深色渐变底 + 白色经纬织线（无第三方依赖，手写 PNG）"""
import zlib, struct, math

W = H = 1024

def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))

def lerp(a, b, t):
    return a + (b - a) * t

top = (0x4A, 0x58, 0x90)      # 蓝紫
bottom = (0x22, 0x29, 0x48)   # 深蓝

def band(d, half=13.0, soft=9.0):
    """距中心线 d 的柔和线宽笔触"""
    return clamp(1.0 - max(0.0, d - half) / soft)

rows = []
for y in range(H):
    t = y / (H - 1)
    br = lerp(top[0], bottom[0], t)
    bg = lerp(top[1], bottom[1], t)
    bb = lerp(top[2], bottom[2], t)
    row = bytearray([0])  # PNG filter: none
    for x in range(W):
        ink = 0.0
        # 三条纵向织线（正弦摆动）
        for i in (-1, 0, 1):
            cx = W / 2 + i * 200
            wave = 52 * math.sin((y / H) * math.pi * 2.1 + i * 1.7)
            ink = max(ink, band(abs(x - (cx + wave))))
        # 三条横向织线
        for j in (-1, 0, 1):
            cy = H / 2 + j * 200
            wave = 52 * math.sin((x / W) * math.pi * 2.1 + j * 1.7 + 1.3)
            ink = max(ink, band(abs(y - (cy + wave))))
        # 中央结环：命运之结
        dist = math.hypot(x - W / 2, y - H / 2)
        ink = max(ink, band(abs(dist - 104), half=15.0, soft=10.0) * 0.95)

        a = clamp(ink) * 0.96
        cr = lerp(br, 246, a)
        cg = lerp(bg, 247, a)
        cb = lerp(bb, 252, a)
        row += bytes((int(cr), int(cg), int(cb), 255))
    rows.append(bytes(row))

raw = b"".join(rows)

def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    c += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    return c

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw, 9))
png += chunk(b"IEND", b"")

out = "AppIcon.png"
with open(out, "wb") as f:
    f.write(png)
print("wrote", out, len(png), "bytes")
