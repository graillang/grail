# Dependency and toolchain requirements

Two separate builds are involved, with different requirements: the **host** (C/C++) that
implements the ABI and runs the GPU, and the **offline shader build**. Grail itself needs
neither today, which is the subject of `first-renderer-port.md`.

## Host build

| Dependency | Version | Needed by | Present on this host |
| --- | --- | --- | --- |
| C11 compiler | any | the ABI implementation and tests | `cc`/`gcc`/`clang` |
| SDL3 | 3.2+, headers + library | window, input, surface creation | **3.4.18** (pkg-config) |
| Vulkan headers | 1.3+ | Vulkan backend | **1.4.363** |
| Vulkan loader + ICD | 1.3+ | Vulkan backend at run time | driver-provided |
| `VK_LAYER_KHRONOS_validation` | matching SDK | validation runs | optional |
| Vulkan Memory Allocator | 3.x | Vulkan allocation | vendored by Abundance |
| DirectX 12 Agility SDK | 1.7+, SM 6.6 | D3D12 backend | Windows only |
| Metal / Xcode CLT | macOS 13 SDK | Metal backend | macOS only |

The tests need **only a C compiler**: `make -C graphics test` has no graphics dependency at
all, which is what keeps the ABI checkable in CI.

## Offline shader build

| Dependency | Version | Why exactly this |
| --- | --- | --- |
| DXC | **1.9.2609** | the version Abundance pins (`dxc\|1.9.2609` in `abundance/engine/tools/fetch.sh`); shader model 6.6 and the flags in `shader-flow.md` are verified against it |
| `dxil.dll` | same release as DXC | DXIL is signed at compile time; without it beside `dxc`, the DXIL target is refused (Windows) |
| SPIRV-Cross | 2023+ with `--msl-version 30000` | HLSL → MSL for Metal. **Not installed on this host** |
| `spirv-val` | from the Vulkan SDK | validates emitted SPIR-V. Present (1.4.363) |
| `xcrun metal` | Xcode 15+ | optional: pre-compiles MSL into `.metallib` |

DXC is not on `PATH` on this host, but a working 1.9.2609 build is in the shared tools cache:

```
~/.cache/abundance/engine-tools/dxc-1.9.2609/bin/dxc    # 1.9.2609.5, verified
```

Abundance fetches and SHA-256-pins these tools with `engine/tools/fetch.sh`, and installs
without sudo into `${AB_ENGINE_TOOLS:-$HOME/.cache/abundance/engine-tools}/<tool>-<version>/`.
Grail's shader tool should reuse that cache rather than a second pin, so the two engines
cannot compile the same HLSL with different compilers. It resolves `$DXC`, then the Abundance
cache, then `PATH`, and fails with the exact version it needs.

## Verified

- DXC 1.9.2609.5 emits valid SPIR-V 1.3 and DXIL for shader model 6.6 with the flag set in
  `shader-flow.md`.
- All three shaders in `graphics/shaders/core/` compile and pass
  `spirv-val --target-env vulkan1.3`.
- `register(xN, spaceM)` maps to `DescriptorSet M` / `Binding N`; all bindings are unique per
  set across descriptor classes.
- `[[vk::push_constant]]` produces a SPIR-V `PushConstant` block and is ignored (warning
  only) by the DXIL path.
