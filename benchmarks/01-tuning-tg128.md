# 01 - Tune: thread-count sweep

Model `Qwen3.5-0.8B-Q4_K_M.gguf` · host `Windows-AMD64` · llama.cpp `b10488`
CPU: **14 physical · 20 logical** cores · `ngl=99` · metric `tg128`

| threads (-t) | tg128 (tok/s) | vs best |
|:--|--:|--:|
| 1 | 188.8 | 99% |
| 7 | 189.6 | 99% |
| 14 | 191.0 | 100% |
| 20 | 190.2 | 100% |
| 40 | 189.7 | 99% |

**Best**: `-t 14` at 191.0 tok/s
**Slowest tested**: `-t 1` at 188.8 tok/s (1.01x spread)
**Against the physical-core default** (`-t 14`, 191.0 tok/s): 1.00x

Use this in your run:

```bash
LAB_N_THREADS=14 make bench
```

## Explanation

The curve is essentially flat: `-t 1` to `-t 14` gains only 1.2%, and doubling to
40 threads loses 0.7% from the peak. This differs from a CPU-only sweep because all
99 model layers are offloaded to CUDA. GPU execution and VRAM bandwidth dominate
decode, so host thread count is no longer the main limiter. Fourteen threads is a
safe knee; additional threads add scheduling overhead without creating GPU bandwidth.
