#!/usr/bin/env python3
"""Read existing state through a bounded descriptor, without changing the file."""
import os, stat, sys

TEXT_LIMIT = 1048576
# Preserve existing Unicode state: Store.read limits UTF-16 units, not UTF-8 bytes.
BYTE_LIMIT = 4 * TEXT_LIMIT

def bounded_read(stream):
    chunks, remaining = [], BYTE_LIMIT + 1
    while remaining:
        chunk = stream.read(remaining)
        if not chunk: break
        chunks.append(chunk)
        remaining -= len(chunk)
    raw = b"".join(chunks)
    if len(raw) > BYTE_LIMIT: raise ValueError("State too large")
    text = raw.decode("utf-8")
    if len(text.encode("utf-16-le")) // 2 > TEXT_LIMIT:
        raise ValueError("State text too large")
    return raw

def read_state(directory):
    # Relative open against the directory descriptor avoids checking one path
    # and then reading a replaced one. Nonblocking open also rejects FIFOs safely.
    parent = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        fd = os.open("state.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        with os.fdopen(fd, "rb", buffering=0) as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size > BYTE_LIMIT:
                raise ValueError("Invalid state file")
            return bounded_read(stream)
    finally:
        os.close(parent)

if __name__ == "__main__":
    try:
        if len(sys.argv) != 2: raise ValueError("Expected state directory")
        value = read_state(sys.argv[1])
        sys.stdout.buffer.write(value)
    except Exception:
        sys.exit(1)
