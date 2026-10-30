"""Run bounded experiments without network or access to the user's home files."""

from __future__ import annotations

import argparse
import resource
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def command(
    args: list[str],
    *,
    source: Path | None = None,
    work: Path | None = None,
    rust: bool = True,
    inputs: Path | None = None,
) -> list[str]:
    """Return a minimal read-only-toolchain bubblewrap command."""
    target = (work or HERE / ".work").resolve()
    target.mkdir(parents=True, exist_ok=True)
    cmd = [
        "bwrap",
        "--unshare-all",
        "--die-with-parent",
        "--new-session",
        "--clearenv",
        "--ro-bind",
        "/usr",
        "/usr",
        "--symlink",
        "usr/bin",
        "/bin",
        "--symlink",
        "usr/lib",
        "/lib",
        "--symlink",
        "usr/lib",
        "/lib64",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--tmpfs",
        "/tmp",
        "--dir",
        "/tmp/home",
        "--dir",
        "/etc",
    ]
    cache = Path("/etc/ld.so.cache")
    if cache.exists():
        cmd += ["--ro-bind", str(cache), str(cache)]
    path = "/usr/bin:/bin"
    if rust:
        compiler = Path(
            subprocess.check_output(["rustup", "which", "rustc"], text=True).strip()
        )
        toolchain = compiler.parent.parent
        cmd += ["--ro-bind", str(toolchain), str(toolchain)]
        path = str(compiler.parent) + ":" + path
    cmd += [
        "--ro-bind",
        str((inputs or HERE).resolve()),
        "/experiment",
        "--bind",
        str(target),
        "/work",
    ]
    if source is not None:
        cmd += ["--ro-bind", str(source.resolve()), "/src"]
    cmd += [
        "--setenv",
        "PATH",
        path,
        "--setenv",
        "HOME",
        "/tmp/home",
        "--setenv",
        "LANG",
        "C.UTF-8",
        "--setenv",
        "SOURCE_DATE_EPOCH",
        "0",
        "--setenv",
        "CARGO_HOME",
        "/tmp/cargo",
        "--setenv",
        "TMPDIR",
        "/tmp",
        "--chdir",
        "/work",
        "--",
    ]
    return cmd + args


def limits() -> None:
    """Bound CPU and file sizes; no address-space cap (Goose reserves sparse stacks)."""
    resource.setrlimit(resource.RLIMIT_CPU, (300, 300))
    resource.setrlimit(resource.RLIMIT_FSIZE, (1024**3, 1024**3))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def run(
    args: list[str],
    *,
    source: Path | None = None,
    work: Path | None = None,
    timeout: int = 180,
    rust: bool = True,
    inputs: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command(args, source=source, work=work, rust=rust, inputs=inputs),
        capture_output=True,
        text=True,
        timeout=timeout,
        preexec_fn=limits,
        check=False,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--work", type=Path)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    opts = parser.parse_args()
    argv = opts.args[1:] if opts.args[:1] == ["--"] else opts.args
    completed = run(argv, source=opts.source, work=opts.work, timeout=300)
    print(completed.stdout, end="")
    print(completed.stderr, end="", file=__import__("sys").stderr)
    raise SystemExit(completed.returncode)
