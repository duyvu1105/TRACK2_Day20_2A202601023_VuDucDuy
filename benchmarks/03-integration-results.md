# 03 - Integrate: RAG pipeline run

Host `Windows-AMD64` · llama.cpp `b10488` ·
retrieval backend: **keyword overlap** · 3 queries

| Query | Contexts retrieved | embed (ms) | retrieve (ms) | llm (ms) | total (ms) |
|:--|--:|--:|--:|--:|--:|
| Why is goodput more useful than raw throughp... | goodput, paged, radix | 0.0 | 0.0 | 4704.8 | 4704.9 |
| What problem does PagedAttention actually so... | paged, radix, disagg | 0.0 | 0.0 | 3933.2 | 3933.3 |
| When does splitting prefill and decode help?... | disagg, radix, batching | 0.0 | 0.0 | 4015.9 | 4016.0 |

Mean per stage (ms): embed **0.0** · retrieve **0.0** ·
llm **4218.0** · total **4218.1**
Dominant stage: **llm** (100% of total)

## Answers returned

**Why is goodput more useful than raw throughput?**

> Based on the context provided, **Goodput** is more useful than raw throughput because it explicitly accounts for **SLOs (Service Level Objects)** and **TPOT (Throughput at Saturation)**.

Here is the breakdown of why this makes it superior:

1.  **SLOs (Service Level Objects):**
    *   **Raw Throughput:** Measures total requests per second (TPS) without regard for the specific constraints or dead

**What problem does PagedAttention actually solve?**

> PagedAttention solves the problem of **internal fragmentation in GPU memory** caused by storing the Key-Value (KV) cache in non-contiguous pages.

By shifting the cache from contiguous memory to non-contiguous pages, it eliminates the wasted space that would otherwise be consumed by the internal fragmentation of the contiguous cache. This optimization is particularly beneficial for GPU memory, whe

**When does splitting prefill and decode help?**

> Splitting prefill and decode helps when **prefill is compute-bound and decode is memory-bandwidth-bound**.

This is because the context explicitly states that prefill is compute-bound and decode is memory-bandwidth-bound. By splitting these operations into separate pools, the system can utilize different resources (compute vs. memory) to optimize performance. Specifically, the `[radix]` context ex


## Which N16-N19 pieces are real

- N16 Cloud/IaC: stubbed by localhost.
- N17 Data pipeline: stubbed by an in-memory list.
- N18 Lakehouse: stubbed by the toy document dictionary.
- N19 Vector + features: stubbed by keyword-overlap retrieval.
- N20 Serving: real `llama-server` with an OpenAI-compatible endpoint.

The LLM accounts for effectively 100% of the measured 4218.1 ms mean, as expected
with in-memory retrieval and no embedder. To halve latency I would attack LLM decode:
reduce output budget, test a faster model/runtime setting, and then increase parallel
capacity for loaded operation. Optimizing the ~0 ms stubs cannot yield a material gain.
