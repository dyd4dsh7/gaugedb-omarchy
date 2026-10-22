import importlib.util, io, os, subprocess, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
sys.dont_write_bytecode = True
script = Path(__file__).parent.parent / "scripts/state-read.py"
spec = importlib.util.spec_from_file_location("state_reader", script)
reader = importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)

class StateReads(unittest.TestCase):
    def test_oversized_sparse_file_emits_nothing_and_preserves_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            with path.open("wb") as output:
                output.write(b"preserve me")
                output.truncate(64 * 1024 * 1024)
            before = path.stat()
            result = subprocess.run([sys.executable, "-B", str(script), directory], capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout + result.stderr, b"")
            self.assertEqual((path.stat().st_size, path.stat().st_mtime_ns), (before.st_size, before.st_mtime_ns))
            with path.open("rb") as source: self.assertEqual(source.read(11), b"preserve me")

    def test_actual_reads_are_bounded_even_if_file_grows_after_metadata_check(self):
        class GrowingStream:
            requested = []
            def read(self, amount):
                self.requested.append(amount)
                return b"x" * min(100000, amount)
        source = GrowingStream()
        with self.assertRaisesRegex(ValueError, "State too large"):
            reader.bounded_read(source)
        self.assertLessEqual(max(source.requested), reader.BYTE_LIMIT + 1)
        # An endless producer must exhaust a fixed byte budget, not wait for EOF.
        self.assertEqual(source.requested[-1], (reader.BYTE_LIMIT + 1) % 100000)

    def test_valid_utf8_above_one_megabyte_round_trips_without_rewriting(self):
        raw = ('{"value":"' + "雪" * 400000 + '"}').encode()
        self.assertGreater(len(raw), reader.TEXT_LIMIT)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"; path.write_bytes(raw)
            result = subprocess.run([sys.executable, "-B", str(script), directory], capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, raw)
            self.assertEqual(path.read_bytes(), raw)

    def test_utf16_limit_invalid_utf8_and_short_reads_fail_closed(self):
        self.assertEqual(reader.bounded_read(io.BytesIO(('"' + "😀" * 100 + '"').encode())), ('"' + "😀" * 100 + '"').encode())
        for raw in [b"x" * (reader.TEXT_LIMIT + 1), ("😀" * (reader.TEXT_LIMIT // 2 + 1)).encode(), b"\xff"]:
            with self.assertRaises((ValueError, UnicodeError)):
                reader.bounded_read(io.BytesIO(raw))
        class ShortReads(io.BytesIO):
            def read(self, amount): return super().read(min(amount, 3))
        self.assertEqual(reader.bounded_read(ShortReads(b'{"ok":true}')), b'{"ok":true}')

    def test_replaced_file_still_uses_the_checked_descriptor(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"; path.write_bytes(b'{"ok":true}')
            real = reader.os.fstat
            def swap(fd):
                info = real(fd)
                path.unlink()
                with path.open("wb") as output: output.truncate(reader.BYTE_LIMIT * 2)
                return info
            with patch.object(reader.os, "fstat", side_effect=swap):
                self.assertEqual(reader.read_state(directory), b'{"ok":true}')
            self.assertEqual(path.stat().st_size, reader.BYTE_LIMIT * 2)

    def test_symlink_directory_file_and_fifo_are_rejected_without_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); target = root / "target"; target.mkdir()
            canary = target / "state.json"; canary.write_bytes(b"keep")
            alias = root / "alias"; alias.symlink_to(target, target_is_directory=True)
            result = subprocess.run([sys.executable, "-B", str(script), str(alias)], capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout + result.stderr, b"")
            home = root / "home"; home.mkdir(); state = home / "state.json"
            for kind in ["symlink", "fifo"]:
                if kind == "symlink": state.symlink_to(canary)
                else: os.mkfifo(state)
                result = subprocess.run([sys.executable, "-B", str(script), str(home)], capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout + result.stderr, b"")
                state.unlink()
            self.assertEqual(canary.read_bytes(), b"keep")

if __name__ == "__main__": unittest.main()
