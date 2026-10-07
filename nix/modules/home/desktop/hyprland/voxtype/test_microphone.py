"""Run with python test_microphone.py; uses fake audio commands, no real mic."""

import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def check(initial_mute, ending):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        runtime = root / "voxtype"
        runtime.mkdir()
        (runtime / "state").write_text("recording")
        (runtime / "pid").write_text(str(os.getpid()))
        log = root / "calls"
        log.touch()
        pactl = root / "pactl"
        pactl.write_text('''#!/bin/sh
case "$1" in
  get-default-source) echo original-mic ;;
  get-source-mute) echo "Mute: $INITIAL_MUTE" ;;
  set-source-mute) echo "$2 $3" >> "$CALLS" ;;
esac
''')
        pactl.chmod(0o755)
        notify = root / "notify-send"
        notify.write_text("#!/bin/sh\nexit 0\n")
        notify.chmod(0o755)
        env = dict(os.environ, XDG_RUNTIME_DIR=directory,
                   PATH=f"{root}:{os.environ['PATH']}",
                   INITIAL_MUTE=initial_mute, CALLS=str(log))
        process = subprocess.Popen(
            ["bash", "-euo", "pipefail", str(Path(__file__).with_name("microphone.sh")),
             "0" if ending == "timeout" else "600"], env=env)
        try:
            if initial_mute == "yes":
                deadline = time.monotonic() + 3
                while not log.read_text() and time.monotonic() < deadline:
                    time.sleep(0.01)
                assert log.read_text() == "original-mic 0\n"
                if ending == "signal":
                    process.send_signal(signal.SIGTERM)
                elif ending == "daemon-exit":
                    (runtime / "state").unlink()
                elif ending != "timeout":
                    (runtime / "state").write_text(ending)
            assert process.wait(timeout=4) == 0
            expected = "original-mic 0\noriginal-mic 1\n" if initial_mute == "yes" else ""
            assert log.read_text() == expected, (ending, log.read_text())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    for ending in ("transcribing", "idle", "signal", "daemon-exit", "timeout"):
        check("yes", ending)
    check("no", "idle")
    print("PASS: stop, cancel, termination, missing state, timeout, already unmuted")
