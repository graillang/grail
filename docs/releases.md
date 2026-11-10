# Cutting a Grail release

A release is one annotated tag pushed to `main`. The tag workflow builds every
target that this tree can honestly produce, verifies what it can, and attaches
the artifacts, one `SHA256SUMS` file, `release.json` provenance and a generated
`RELEASE-README.md` to a GitHub release. Release builds start from the checked-in
bootstrap seed: no development compiler is downloaded, and `tools/release.mjs`
refuses `GRAIL_COMPILER` outright.

## Cut a release

1. Bump `VERSION` and add a `CHANGELOG.md` entry in the same commit; merge to `main`.
2. Check the seed and the release tool locally:

   ```sh
   bun tools/native.mjs build          # stage1 from compiler/bootstrap
   bun tools/test-cli.mjs
   bun tools/ci.mjs lint
   GRAIL_VERSION="$(cat VERSION)" bun tools/release.mjs dry-run --out dist/release
   ```

3. Tag the commit and push the tag:

   ```sh
   git tag -a "v$(cat VERSION)" -m "Grail $(cat VERSION)"
   git push origin "v$(cat VERSION)"
   ```

`.github/workflows/release.yml` then:

1. validates that the tag equals `VERSION`, runs `bun tools/ci.mjs lint` and the
   tooling unit tests;
2. builds each target from `compiler/bootstrap` with `bun tools/release.mjs build
   --platform ID`;
3. runs the target-appropriate checks (native suite on x86-64 and AArch64, a
   qemu smoke run plus compile-only ELF check on RISC-V 64, and the static
   COFF/PE and Mach-O checks);
4. merges the assets with `bun tools/release.mjs assemble`, recomputes every
   digest with `verify`, and runs `gh release create "vVERSION"` with the
   generated README as the release notes.

The workflow refuses a tag that disagrees with `VERSION`, so a release cannot be
mislabelled. Nothing is published if any build or verification job fails.

## Artifacts per target

Names follow `grail-VERSION-PLATFORM[-KIND].EXT` from `tools/platforms.mjs`.

| Target | Published assets | Runs on |
| --- | --- | --- |
| `linux-x86_64` | toolchain `.tar.gz` (bin/grail, runtime, std, installers, docs), raw `-compiler`, `-compiler.s.gz`, `-compiler.build.json` | **Linux x86-64**, static ELF; built and executed natively |
| `linux-aarch64` | same layout | **Linux AArch64**, static ELF; built and executed natively on the AArch64 release runner |
| `linux-riscv64` | same layout | **Linux RISC-V 64**, static ELF; cross-built on x86-64, smoke-run under `qemu-riscv64-static` |
| `windows-x86_64` | toolchain `.zip`, raw `-compiler.exe`, `-compiler.build.json`, `-objects.zip` | **Nothing yet.** PE32+ console image and COFF objects; cross-built on Linux and static-checked only. The Windows runtime is incomplete, so the `.exe` is not a runnable compiler |
| `windows-aarch64` | none — **not built** | ARM64 PE/COFF code generation is not implemented, so the lane is planned; no artifact is published |
| `macos-aarch64` | `-objects.tar.gz` | **Nothing.** Non-executable Mach-O objects, statically checked; no macOS execution is claimed |
| `macos-x86_64` | `-objects.tar.gz` | **Nothing.** Non-executable Mach-O objects, statically checked; no macOS execution is claimed |

The macOS and Windows object archives contain `objects/`, emitted assembly,
`share/grail/objects.json` and a build-only notice; `verify` rejects any archive
that unexpectedly contains `bin/grail`, a compiler or a dylib. The Windows
toolchain zip carries `share/doc/grail/WINDOWS-BUILD-ONLY.txt` and its
`package.json` records `tier: build-only`, `runnable: false`.

Every Linux toolchain archive installs with its bundled `install.sh`:
`./install.sh ~/.local` puts `bin/grail` and `lib/grail/` in place.

## What is verified where

| Check | Where |
| --- | --- |
| ELF machine type, PE/COFF static checks, Mach-O static checks, archive layout, every file SHA-256 | `tools/release.mjs build` / `assemble` / `verify`, on every build |
| Native compiler test suite and CLI regressions on x86-64 | release workflow `linux-native` job (and the required local commands above) |
| Native compiler test suite on AArch64 | release workflow `linux-native` job on `ubuntu-24.04-arm` |
| RISC-V 64 qemu smoke run + compile-only ELF check | release workflow `linux-riscv64` job |
| Windows COFF/PE static checks | release workflow `windows-x86_64` job; no Windows execution |
| Mach-O object/executable static checks | release workflow `macos-objects` job; no execution |
| Full qemu suites, Wine execution, ABI, LLVM, self-host, LSP, DWARF | the regular `.github/workflows/ci.yml` lanes, not duplicated in the release lane |

## Local dry run

The dry run builds every target this host can build, then assembles and verifies
the release exactly as the workflow does. It writes only under `dist/` and never
publishes:

```sh
GRAIL_VERSION=0.1.0 bun tools/release.mjs dry-run --out dist/release
```

On a Linux x86-64 host it cross-builds `linux-aarch64`, `linux-riscv64`,
`windows-x86_64`, `macos-aarch64` and `macos-x86_64`, so all seven targets are
exercised. Per-target commands are the same ones the workflow uses:

```sh
bun tools/release.mjs build --platform linux-x86_64 --out dist/release/linux-x86_64
bun tools/release.mjs assemble --dir dist/release --out dist/release/upload
bun tools/release.mjs verify --dir dist/release/upload
sha256sum -c dist/release/upload/SHA256SUMS
```

`dry-run` does not run the execution suites; those run on the release runners.
Its transcript (the `verify` JSON is elided) is recorded below.

```text
$ GRAIL_VERSION=0.1.0 bun tools/release.mjs dry-run --out dist/release
release: linux-x86_64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building native
release: linux-x86_64: 4 assets in dist/release/linux-x86_64
release: linux-aarch64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building cross
release: linux-aarch64: 4 assets in dist/release/linux-aarch64
release: linux-riscv64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building cross
release: linux-riscv64: 4 assets in dist/release/linux-riscv64
release: windows-x86_64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building cross
release: windows-x86_64: 5 assets in dist/release/windows-x86_64
release: windows-aarch64: skipped (PE/COFF output exists only for windows-x86_64; ARM64 PE code generation is not implemented, so this lane is distribution scaffolding)
release: macos-aarch64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building cross
release: macos-aarch64: 1 assets in dist/release/macos-aarch64
release: macos-x86_64: stage0 .work/native/f2fac8450c9d2f6cb048717c/grail (ad21f97a6fce81e6…), building cross
release: macos-x86_64: 1 assets in dist/release/macos-x86_64
release: assembled 19 assets for 0.1.0 in dist/release/upload

release: dry run complete for 0.1.0: 19 assets, 6 targets, verification passed
release: execution suites are not run by dry-run; the tag workflow runs them on the release runners.

$ cd dist/release/upload && sha256sum -c SHA256SUMS
...
grail-0.1.0-windows-x86_64-objects.zip: OK
grail-0.1.0-windows-x86_64.zip: OK
```

## Honest gaps

- `windows-aarch64` is **not built**: ARM64 PE/COFF code generation does not
  exist, the lane is `planned`, and the workflow deliberately omits it. No
  placeholder artifact is published.
- Windows x86-64 is **cross-built and not runnable**: argv recovery, worker
  threads, file/directory services and `.pdata`/unwind data are missing. The
  `.exe` is published for inspection and static verification, not as a
  toolchain; nothing executes it on Windows in the release lane.
- macOS has **no compiler executable**: the release publishes static-checked
  Mach-O object bundles only, and nothing runs on macOS.
- RISC-V 64 is cross-built and smoke-run under qemu; the release lane does not
  execute it on RISC-V hardware. The full qemu suite stays in `ci.yml`.
- Artifacts are **unsigned by default**. `bun tools/ci.mjs sign` prints the GPG,
  Authenticode and codesign/notary commands; signing executes only when
  credentials and `RELEASE_SIGNING=true` are configured.
- Release builds require the checked-in seed to be intact and able to compile
  the tree. If the seed's source manifest predates the compiler sources,
  `release.json` records that (and the changed files) and `preflight` reports it
  as stale; refresh it with `bun tools/bootstrap.mjs update all` on a host where
  all three seeds execute. A stale source manifest does not by itself block a
  release, because every build proves the seed accepts the tagged sources.
