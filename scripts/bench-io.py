#!/usr/bin/env python3
"""Usage: bench-io.py <dir>. Sequential write+read of 256 MB with the OS cache bypassed; removes what it creates."""
import os, sys, time, fcntl
d = os.path.join(sys.argv[1], "bench-tmp"); os.makedirs(d, exist_ok=True)
p = os.path.join(d, "f.bin"); MB = 256; buf = os.urandom(1 << 20)
try:
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_TRUNC); fcntl.fcntl(fd, 48, 1)
    t = time.time()
    for _ in range(MB): os.write(fd, buf)
    os.fsync(fd); os.close(fd); w = MB / (time.time() - t)
    fd = os.open(p, os.O_RDONLY); fcntl.fcntl(fd, 48, 1)
    t = time.time(); n = 0
    while (b := os.read(fd, 1 << 20)): n += len(b)
    os.close(fd); r = n / 1e6 / (time.time() - t)
    print(f"write {w:6.1f} MB/s   read {r:6.1f} MB/s")
finally:
    if os.path.exists(p): os.remove(p)
    os.rmdir(d)
