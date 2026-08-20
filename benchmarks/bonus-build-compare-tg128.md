# Bonus B1 - Prebuilt vs source build

Host `Windows-AMD64` � CPU `12th Gen Intel(R) Core(TM) i7-12700H`
Vector extensions detected: AVX2
llama.cpp `b10488` both sides � `threads=14` �
**both pinned to `ngl=0 -nopo 1`** (CPU compute, op-offload off) so this
isolates the compiler �
metric `tg128`, 3 repetitions

> **Backend mismatch, handled.** The prebuilt binary sees
> `['CUDA0: NVIDIA GeForce RTX 3050 Ti Laptop GPU (4095 MiB, 3289 MiB free)']` and your source build sees `(no devices)`.
> Left at `-ngl 99` this comparison would have measured the accelerator and printed
> it under a compiler headline, so both sides were pinned to `-ngl 0`.

| Binary | Built for | tg128 (tok/s) | Relative |
|:--|--:|--:|--:|
| prebuilt release | runtime CPU dispatch | 56.7 | 1.00x |
| your source build | this CPU (`-DGGML_NATIVE=ON`) | 53.5 | 0.94x |

On this machine, the prebuilt binary is **1.06x faster**.

before: 56.7 tok/s (prebuilt release)
after:  53.5 tok/s (source build, -DGGML_NATIVE=ON)
speedup: 0.94x

Same source revision, same model, same backend, same `-ngl` -- the only difference
is what the compiler was allowed to assume about the CPU.



## Your explanation

This is a decode (token-generation) workload, and on this CPU it is memory-bound, not instruction-bound. A 0.8B Q4_K_M model streams roughly 0.5 GB of weights from DRAM for every token; at 14 threads the i7-12700H is limited by its dual-channel DDR4 bandwidth, which is why both binaries land in the same ~53-57 tok/s band instead of scaling with vector width.

The small edge to the prebuilt (1.06x) is a runtime-dispatch artifact: the release ships one `ggml-cpu-*.dll` per microarchitecture and picks `ggml-cpu-alderlake.dll` on this chip at startup, so it already runs kernels compiled for Alder Lake (AVX2 + AVX-VNNI). The source build with `-DGGML_NATIVE=ON` under MSVC compiles to AVX2+FMA+F16C but cannot emit AVX-VNNI (MSVC has no corresponding `/arch:` flag), so the prebuilt keeps a small dot-product advantage on the quantized matmuls. At ~50 tok/s the 6% gap is also within run-to-run variance, so the honest reading is: for decode, compiling it yourself buys nothing on this machine -- the prebuilt binary already contains the right CPU kernels, and the workload is starved by memory bandwidth either way.

The much bigger lever here is the accelerator: the same model decodes several times faster with `-ngl 99` on the RTX 3050 Ti (see the GPU-offload sweep), which is why the B1 compiler question matters less on this laptop than on a CPU-only machine.
