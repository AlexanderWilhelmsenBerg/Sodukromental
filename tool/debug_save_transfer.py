#!/usr/bin/env python3
"""Export and restore debuggable Android saves without device-side sqlite3."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import uuid


DATABASES = {
    "sodukromental_player.sqlite": {"snapshots"},
    "sodukromental_library.sqlite": {
        "catalog", "downloads", "progress", "jobs", "preferences",
    },
}
PACKAGE_PATTERN = re.compile(r"^[A-Za-z0-9_.]+$")


class TransferError(RuntimeError):
    pass


def _run(command: list[str], *, stdin=None, stdout=None) -> subprocess.CompletedProcess:
    result = subprocess.run(
        command,
        stdin=stdin,
        stdout=stdout if stdout is not None else subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace").strip()
        raise TransferError(
            f"command failed ({result.returncode}): {' '.join(command)}\n{detail}"
        )
    return result


class Device:
    def __init__(self, adb: str, serial: str, package: str) -> None:
        if not PACKAGE_PATTERN.fullmatch(package):
            raise TransferError(f"invalid package name: {package!r}")
        self.adb = adb
        self.serial = serial
        self.package = package
        self.data = f"/data/user/0/{package}"

    def command(self, *arguments: str) -> list[str]:
        return [self.adb, "-s", self.serial, *arguments]

    def verify(self) -> None:
        _run(self.command("get-state"))
        _run(self.command("shell", "run-as", self.package, "true"))

    def stop(self) -> None:
        _run(self.command("shell", "am", "force-stop", self.package))

    def exists(self, remote: str) -> bool:
        result = subprocess.run(
            self.command("shell", "run-as", self.package, "test", "-f", remote),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        return result.returncode == 0

    def pull_private(self, remote: str, local: Path) -> None:
        with local.open("xb") as output:
            _run(
                self.command("exec-out", "run-as", self.package, "cat", remote),
                stdout=output,
            )

    def push_private(self, local: Path, remote: str) -> None:
        with local.open("rb") as source:
            _run(
                self.command(
                    "shell", f"run-as {self.package} sh -c 'cat > {remote}'"
                ),
                stdin=source,
                stdout=subprocess.DEVNULL,
            )

    def remove(self, remote: str) -> None:
        _run(self.command("shell", "run-as", self.package, "rm", "-f", remote))

    def move(self, source: str, destination: str) -> None:
        _run(self.command("shell", "run-as", self.package, "mv", source, destination))

    def chmod_private(self, remote: str) -> None:
        _run(
            self.command("shell", "run-as", self.package, "chmod", "600", remote)
        )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _verify_database(path: Path, required_tables: set[str]) -> dict[str, object]:
    try:
        connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
        try:
            integrity = [row[0] for row in connection.execute("pragma integrity_check")]
            if integrity != ["ok"]:
                raise TransferError(f"SQLite integrity failure in {path}: {integrity}")
            tables = {
                row[0]
                for row in connection.execute(
                    "select name from sqlite_master where type='table'"
                )
            }
            missing = required_tables - tables
            if missing:
                raise TransferError(
                    f"{path} is missing required tables: {', '.join(sorted(missing))}"
                )
            counts = {
                table: connection.execute(f'select count(*) from "{table}"').fetchone()[0]
                for table in sorted(required_tables)
            }
            version = connection.execute("pragma user_version").fetchone()[0]
        finally:
            connection.close()
    except sqlite3.DatabaseError as error:
        raise TransferError(f"invalid SQLite database {path}: {error}") from error
    return {
        "sha256": _sha256(path),
        "bytes": path.stat().st_size,
        "user_version": version,
        "rows": counts,
    }


def _normalize(raw: Path, destination: Path, required_tables: set[str]) -> dict[str, object]:
    try:
        source = sqlite3.connect(raw.resolve().as_uri() + "?mode=ro", uri=True)
        target = sqlite3.connect(destination)
        try:
            source.backup(target)
        finally:
            target.close()
            source.close()
    except sqlite3.DatabaseError as error:
        raise TransferError(f"could not snapshot {raw}: {error}") from error
    return _verify_database(destination, required_tables)


def _create_output(output: Path, producer) -> dict[str, object]:
    output = output.expanduser().resolve()
    if output.exists():
        raise TransferError(f"refusing to overwrite existing directory: {output}")
    if not output.parent.is_dir():
        raise TransferError(f"parent directory does not exist: {output.parent}")
    staging = Path(tempfile.mkdtemp(prefix=f".{output.name}.tmp-", dir=output.parent))
    try:
        manifest = producer(staging)
        (staging / "manifest.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        staging.rename(output)
        return manifest
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def _snapshot_device(device: Device, destination: Path) -> dict[str, object]:
    device.verify()
    device.stop()
    details: dict[str, object] = {}
    with tempfile.TemporaryDirectory(prefix="sodukromental-raw-") as temporary:
        raw_root = Path(temporary)
        for name, tables in DATABASES.items():
            remote = f"{device.data}/app_flutter/{name}"
            if not device.exists(remote):
                raise TransferError(
                    f"missing {remote}; launch the app and open the Sudoku tab first"
                )
            raw = raw_root / name
            device.pull_private(remote, raw)
            sidecars = []
            for suffix in ("-wal", "-shm"):
                if device.exists(remote + suffix):
                    device.pull_private(remote + suffix, raw_root / (name + suffix))
                    sidecars.append(suffix)
            normalized = destination / name
            info = _normalize(raw, normalized, tables)
            info["captured_sidecars"] = sidecars
            details[name] = info
    return {
        "format": 1,
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "package": device.package,
        "device": device.serial,
        "databases": details,
    }


def export_device(device: Device, output: Path) -> dict[str, object]:
    return _create_output(output, lambda staging: _snapshot_device(device, staging))


def _load_backup(source: Path, package: str) -> dict[str, object]:
    source = source.expanduser().resolve()
    try:
        manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise TransferError(f"invalid backup manifest in {source}: {error}") from error
    if manifest.get("format") != 1 or manifest.get("package") != package:
        raise TransferError("backup format or package does not match this app")
    recorded = manifest.get("databases")
    if not isinstance(recorded, dict):
        raise TransferError("backup manifest has no database records")
    for name, tables in DATABASES.items():
        path = source / name
        if not path.is_file():
            raise TransferError(f"backup is missing {name}")
        actual = _verify_database(path, tables)
        expected = recorded.get(name)
        if not isinstance(expected, dict) or actual["sha256"] != expected.get("sha256"):
            raise TransferError(f"hash mismatch for {name}; backup may be corrupt")
    return manifest


def restore_device(
    device: Device, source: Path, target_backup: Path
) -> tuple[dict[str, object], dict[str, object]]:
    source = source.expanduser().resolve()
    incoming = _load_backup(source, device.package)
    target_backup = target_backup.expanduser().resolve()
    current = export_device(device, target_backup)
    device.stop()
    token = uuid.uuid4().hex
    staged: dict[str, str] = {}
    try:
        with tempfile.TemporaryDirectory(prefix="sodukromental-stage-check-") as temporary:
            check_root = Path(temporary)
            for name, tables in DATABASES.items():
                remote = f"{device.data}/app_flutter/.transfer-{token}-{name}"
                device.push_private(source / name, remote)
                staged[name] = remote
                round_trip = check_root / name
                device.pull_private(remote, round_trip)
                expected = incoming["databases"][name]["sha256"]
                if _sha256(round_trip) != expected:
                    raise TransferError(
                        f"device staging hash mismatch for {name} "
                        f"({round_trip.stat().st_size} bytes)"
                    )
                info = _verify_database(round_trip, tables)
                if info["sha256"] != expected:
                    raise TransferError(f"device staging hash mismatch for {name}")

        for name in DATABASES:
            final = f"{device.data}/app_flutter/{name}"
            device.remove(final + "-wal")
            device.remove(final + "-shm")
        for name in DATABASES:
            final = f"{device.data}/app_flutter/{name}"
            device.move(staged[name], final)
            device.chmod_private(final)
            del staged[name]

        with tempfile.TemporaryDirectory(prefix="sodukromental-restored-check-") as temporary:
            check_root = Path(temporary)
            for name, tables in DATABASES.items():
                restored = check_root / name
                device.pull_private(f"{device.data}/app_flutter/{name}", restored)
                info = _verify_database(restored, tables)
                expected = incoming["databases"][name]["sha256"]
                if info["sha256"] != expected:
                    raise TransferError(f"restored hash mismatch for {name}")
    finally:
        for remote in staged.values():
            try:
                device.remove(remote)
            except TransferError:
                pass
    return incoming, current


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb", help="adb executable (default: adb)")
    parser.add_argument("--device", required=True, help="adb device serial")
    parser.add_argument(
        "--package", default="org.sodukromental.debug", help="debug application id"
    )
    commands = parser.add_subparsers(dest="action", required=True)
    export = commands.add_parser("export", help="export and validate both stores")
    export.add_argument("--output", required=True, type=Path)
    restore = commands.add_parser("restore", help="validate and restore both stores")
    restore.add_argument("--input", required=True, type=Path)
    restore.add_argument("--target-backup", required=True, type=Path)
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    device = Device(arguments.adb, arguments.device, arguments.package)
    try:
        if arguments.action == "export":
            manifest = export_device(device, arguments.output)
            print(json.dumps(manifest["databases"], indent=2, sort_keys=True))
            print(f"Validated backup: {arguments.output.resolve()}")
        else:
            incoming, _ = restore_device(device, arguments.input, arguments.target_backup)
            print(json.dumps(incoming["databases"], indent=2, sort_keys=True))
            print(f"Validated pre-restore backup: {arguments.target_backup.resolve()}")
            print("Restore verified on device. Launch the app and check both saves.")
        return 0
    except (OSError, TransferError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
