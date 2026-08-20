# 02 - Serve: load test + saturation reading

Host `Windows-AMD64` · llama.cpp `b10488` ·
`--parallel 4` · `ctx=2048` · `threads=20` ·
`ngl=99`

| Users | Reqs | RPS | P50 (ms) | P95 (ms) | P99 (ms) | Eff. concurrency | Failures |
|:--|--:|--:|--:|--:|--:|--:|--:|
| 10 | 121 | 2.42 | 2900 | 4600 | 6100 | 7.6 | 0.0% |
| 50 | 177 | 3.25 | 14000 | 17000 | 18000 | 42.3 | 0.0% |

*Effective concurrency = RPS x average latency (Little's Law) -- how many requests were
really in flight, regardless of how many users locust simulated. It counts queued requests
too, so the occupancy/slot ratio can legitimately exceed 1.0; it is occupancy, not
utilisation. For true slot utilisation use the server's own gauges (`make metrics`).*

## What these two runs say

| Going from 10 to 50 users | |
|:--|--:|
| Offered load | 5x |
| Throughput actually delivered | **1.34x** (27% of linear) |
| P95 latency | **3.70x** |
| Effective concurrency at 50 users | 42.3 vs `--parallel 4` slots (occupancy/slot ratio 10.57) |

**Saturated.** Throughput delivered only 1.34x for 5x the offered load, and effective concurrency (42.3) is at or above all 4 decode slots. Saturation sets in somewhere at or below 50 users; the load you added beyond that point became queue time rather than throughput.

Throughput moved 1.34x while P95 moved 3.70x. That gap is the goodput argument: past saturation you buy throughput by spending latency, and if your SLO is a P95 target then the requests you added are no longer being served within it. (This lab does not fix an SLO number for you -- pick one in your write-up and state how much goodput you keep at it.)

## Saturation reading

The server is already queuing at 10 users (effective concurrency 7.6 exceeds four
slots) and is deeply saturated by 50. A 5x offered load yields only 1.34x throughput,
while P95 grows 3.70x to 17 s and occupancy reaches 42.3. The extra latency is queue
time: compute capacity stays at four slots while deferred requests reach 46. For a
5 s P95 SLO, I would raise `--parallel` first, then remeasure; it directly expands
admission/decode capacity, whereas more CPU threads cannot fix this CUDA-bound curve.
