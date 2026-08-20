# 02 - Continuous batching under load (u50)

Host `Windows-AMD64` · `--parallel 4` · 10 samples over
60s at 2.0s intervals · raw CSV: `02-server-metrics-u50.csv`

| Gauge | Peak observed |
|:--|--:|
| `n_busy_slots_per_decode` (avg/decode) | 3.96 of 4 slots (99%) |
| `requests_processing` | 4 |
| `requests_deferred` | 46 |
| `kv_cache_usage_ratio` | n/a — not exported by llama.cpp `b10488` |
| `tokens_predicted_total` (final) | 17592 |

Highest sampled value was **3.96 of 4** slots. Note this gauge is llama.cpp's *average* busy slots per decode step, so the number below is the highest average we sampled, not an instantaneous maximum batch width. A peak near 1 means
requests were served one at a time -- either the load was too light to overlap, or
they arrived too far apart. A peak approaching `--parallel` means the scheduler was
genuinely packing concurrent requests into shared decode steps.
`requests_deferred` went above zero: more requests arrived than there were slots, so some waited. That wait is the queue time in your P95.

## Observation

The peak average batch width was 3.96/4 slots, so continuous batching used nearly
all configured decode capacity. It is lower than effective concurrency 42.3 because
the latter includes queued requests. I trust both for different questions: the native
gauge measures active slot utilization, while Little's Law measures total in-flight
occupancy and exposes the queue. The 46 deferred requests confirm that distinction.
