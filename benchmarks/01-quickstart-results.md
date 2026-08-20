# 01 - Measure: latency baseline

Model `Qwen3.5 0.8B` · host `Windows-AMD64` · llama.cpp `b10488`
Settings: `threads=20` `ngl=99` `ctx=2048`
`max_tokens=64` · warm-up discarded
Completed requests: `Q4_K_M` 10/10 · `UD-Q2_K_XL` 10/10

| Quantization | Size (GB) | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode (tok/s) |
|:--|--:|--:|--:|--:|--:|--:|
| Q4_K_M | 0.50 | 2130 | 1040 / 1105 | 5.9 / 6.3 | 1409 / 1451 / 1451 | 169.0 |
| UD-Q2_K_XL | 0.39 | 2999 | 1048 / 1225 | 5.9 / 6.4 | 1421 / 1607 / 1607 | 169.5 |

- **TTFT** = prefill. Short prompts keep it small; long-context RAG is where it explodes.
- **TPOT** = per-output-token decode cost, bounded by memory bandwidth. `decode tok/s = 1000 / TPOT_p50`.
- `UD-Q2_K_XL` and `Q4_K_M` decode within 2% of each other here, for 0.11 GB difference on disk.

## Observation

Q2 is 22% smaller (0.39 vs 0.50 GB), but decode throughput improves only 0.3%
(169.5 vs 169.0 tok/s); its TTFT P95 is 11% worse. With the same goodput question,
Q4 gave relevant latency/SLO reasoning while Q2 incorrectly described goodput as a
streaming library. On this CUDA setup, the small storage saving is not worth the
quality regression.
