# Reference: https://github.com/ChristopherHX/gitea-actions-runner
# Modified version of actions-runner-worker.py (https://github.com/ChristopherHX/gitea-actions-runner/blob/main/actions-runner-worker.py)

import sys
import subprocess
import os
import threading
import codecs

_, wdw = os.pipe()
rdr, rdw = os.pipe()


def pipe_read_full(fd: int, content_len: int):
    b = bytes()
    while len(b) < content_len:
        r = os.read(fd, content_len - len(b))
        if len(r) <= 0:
            raise RuntimeError("unexpected read len: {}".format(len(r)))
        b += r
    if len(b) != content_len:
        raise RuntimeError("read {} bytes expected {} bytes".format(len(b), content_len))
    return b


def pipe_write_full(fd: int, buf: bytes):
    written: int = 0
    while written < len(buf):
        w = os.write(fd, buf[written:])
        if w <= 0:
            raise RuntimeError("unexpected write result: {}".format(w))
        written += w
    if written != len(buf):
        raise RuntimeError("written {} bytes expected {}".format(written, len(buf)))
    return written


def redirect_io():
    while True:
        stdin = sys.stdin.fileno()
        message_type = int.from_bytes(pipe_read_full(stdin, 4), "big", signed=False)
        pipe_write_full(rdw, message_type.to_bytes(4, sys.byteorder, signed=False))
        message_len = int.from_bytes(pipe_read_full(stdin, 4), "big", signed=False)
        raw_message = pipe_read_full(stdin, message_len)
        message = codecs.decode(raw_message, "utf-8")
        if os.getenv("ACTIONS_RUNNER_WORKER_DEBUG", "0") != "0":
            print("Message Received")
            print("Type:", message_type)
            print("================")
            print(message)
            print("================")
        encoded = message.encode("utf_16")[2:]
        pipe_write_full(rdw, len(encoded).to_bytes(4, sys.byteorder, signed=False))
        pipe_write_full(rdw, encoded)


threading.Thread(target=redirect_io, daemon=True).start()

_user = sys.argv[1]
_group = sys.argv[2]
_worker = sys.argv[3]

interpreter = []
if _worker.endswith(".dll"):
    interpreter = ["dotnet"]

code = subprocess.call(interpreter + [_worker, "spawnclient", format(rdr), format(wdw)],
                       pass_fds=(rdr, wdw), user=_user, group=_group)
print(code)
# https://github.com/actions/runner/blob/af6ed41bcb47019cce2a7035bad76c97ac97b92a/src/Runner.Common/Util/TaskResultUtil.cs#L13-L14
if 100 <= code <= 105:
    exit(0)
else:
    exit(1)
