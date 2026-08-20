# Bonus B1 - Prebuilt vs source build

Host `Windows-AMD64` � CPU `12th Gen Intel(R) Core(TM) i7-12700H`
Vector extensions detected: AVX2
llama.cpp `b10488` both sides � `threads=14` �
**both pinned to `ngl=0 -nopo 1`** (CPU compute, op-offload off) so this
isolates the compiler �
metric `pp512`, 3 repetitions

> **Backend mismatch, handled.** The prebuilt binary sees
> `['CUDA0: NVIDIA GeForce RTX 3050 Ti Laptop GPU (4095 MiB, 3289 MiB free)']` and your source build sees `(no devices)`.
> Left at `-ngl 99` this comparison would have measured the accelerator and printed
> it under a compiler headline, so both sides were pinned to `-ngl 0`.

| Binary | Built for | pp512 (tok/s) | Relative |
|:--|--:|--:|--:|
| prebuilt release | runtime CPU dispatch | 263.7 | 1.00x |
| your source build | this CPU (`-DGGML_NATIVE=ON`) | 287.2 | 1.09x |

On this machine, the source build is **1.09x faster**.

before: 263.7 tok/s (prebuilt release)
after:  287.2 tok/s (source build, -DGGML_NATIVE=ON)
speedup: 1.09x

Same source revision, same model, same backend, same `-ngl` -- the only difference
is what the compiler was allowed to assume about the CPU.



## Your explanation

Prefill is a compute-bound workload (batched matmul at batch=512), so this is where the compiler's assumptions about the CPU should show up -- and they do, modestly: the source build compiled with `-DGGML_NATIVE=ON` beats the prebuilt's runtime dispatch by 1.09x (287 vs 264 tok/s).

Both sides compile to AVX2/FMA for the core dot-product kernels, so the gap is not a vector-width difference. The likely causes are: (1) `-DGGML_NATIVE=ON` lets MSVC assume the full Alder Lake feature set (FMA, F16C, BMI) across every translation unit instead of a conservative baseline, and (2) the source build ships one self-contained `ggml-cpu.dll`, while the prebuilt pays a small per-op dispatch indirection to its per-microarchitecture kernel. 9% is a real but small effect, and it only applies to the prefill phase.

The practical conclusion matches the tg128 finding: on this laptop the CPU compiler is a minor knob. CPU prefill at ~260-290 tok/s is several times slower than the CUDA path at `-ngl 99` (GPU sweep), so TTFT is dominated by where the model runs, not by which CPU build you compiled.
