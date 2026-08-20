# Bonus C9 - Embedding serving: regime bá»‹ giá»›i háº¡n bá»Ÿi prefill

So sÃ¡nh regime embedding (má»™t forward pass, khÃ´ng KV cache, khÃ´ng decode loop) vá»›i regime chat
(decode-bound) Ä‘Ã£ Ä‘o á»Ÿ track 02 trÃªn cÃ¹ng model Qwen3.5-0.8B Q4_K_M vÃ  cÃ¹ng mÃ¡y.

## Thiáº¿t láº­p

- **MÃ¡y:** i7-12700H Â· 15.7 GB RAM Â· RTX 3050 Ti 4 GB Â· Windows 11
- **Server:** llama.cpp b10488 (CUDA), `llama-server --embedding --pooling mean`, `-ngl 99`, port 18081
- **Model:** Qwen3.5-0.8B Q4_K_M (dÃ¹ng chat GGUF á»Ÿ pooling mode - khÃ´ng táº£i embedding model riÃªng)
- **Demo:** `bonus/serving-regimes/embedding-serving.py --base-url http://127.0.0.1:18081/v1`
  - 8 document corpus + 1 query, rank báº±ng cosine similarity
  - Throughput sweep batch 1/2/4/8/16 (texts/s)

> LÆ°u Ã½ Ä‘o lÆ°á»ng: trÃªn Windows, script gá»‘c táº¡o má»™t káº¿t ná»‘i HTTP má»›i cho má»—i request
> (`httpx.post` module-level) vÃ  Ä‘o Ä‘Æ°á»£c 2.7-3.2 s/request - khÃ´ng pháº£i server mÃ  lÃ  chi phÃ­
> thiáº¿t láº­p káº¿t ná»‘i phÃ­a client (Ä‘o láº¡i vá»›i káº¿t ná»‘i reuse: 46-513 ms). ÄÃ£ patch script reuse
> má»™t `httpx.Client` Ä‘á»ƒ con sá»‘ pháº£n Ã¡nh Ä‘Ãºng server. TÆ°Æ¡ng tá»±, `localhost` trÃªn mÃ¡y nÃ y giáº£i ra
> IPv6 trÆ°á»›c rá»“i fallback (~2 s/request); dÃ¹ng `127.0.0.1`.

## Sá»‘ liá»‡u

### Cháº¥t lÆ°á»£ng retrieval (mean-pooled chat model, dim 1024)

| Rank | Cosine | Document |
|--:|--:|:--|
| 1 | 0.892 | Embedding serving is prefill-bound: one forward pass, no KV cache, no decode loop. |
| 2 | 0.845 | RadixAttention reuses a shared prompt prefix across requests via a radix tree. |
| 3 | 0.815 | Speculative decoding drafts several tokens and verifies them in one forward pass. |

ÄÃºng document Ä‘á»©ng Ä‘áº§u, nhÆ°ng khoáº£ng cÃ¡ch vá»›i hÃ ng 2/3 chá»‰ ~0.05-0.08 - má»™t sentence
encoder yáº¿u (xem phÃ¢n tÃ­ch).

### Throughput theo batch size (chá»‰ cÃ³ prefill, khÃ´ng decode)

| Batch | Latency (ms) | texts/s | vs batch 1 |
|--:|--:|--:|--:|
| 1 | 55.2 | 18.1 | 1.00x |
| 2 | 51.4 | 38.9 | 2.15x |
| 4 | 106.1 | 37.7 | 2.08x |
| 8 | 204.1 | 39.2 | 2.17x |
| 16 | 385.6 | 41.5 | 2.29x |

Prefill thÃ nh throughput ~272 tok/s (batch 1) lÃªn ~622 tok/s (batch 16) - tháº¥p hÆ¡n llama-bench pp512
(~4861 tok/s) vÃ¬ mÃ´Ìƒi text lÃ  má»™t sequence riÃªng: matmul nhá», chi phÃ­ per-sequence (HTTP, slot
dispatch, CUDA launch) khÃ´ng Ä‘Æ°á»£c gá»™p.

### So vá»›i regime chat (track 02, cÃ¹ng model/mÃ¡y)

| | Embedding (prefill-bound) | Chat (decode-bound) |
|:--|:--|:--|
| Má»™t request | ~25 ms/text (batch 16) | ~1.4 s E2E single-stream (169-193 tok/s decode) |
| Throughput tá»« | Static batch lá»›n + token sorting | Continuous batching, nhiá»u slot song song |
| KV cache | KhÃ´ng dÃ¹ng | DÃ¹ng (paged, per-slot) |
| Thá»i gian chiáº¿m server | ms - bursty, ngáº¯n | giÃ¢y - má»—i slot giá»¯ lÃ¢u |

## PhÃ¢n tÃ­ch

Embedding serving lÃ  má»™t regime khÃ¡c háº³n, vÃ  con sá»‘ trÃªn cho tháº¥y lÃ½ do pháº£i Ä‘á»‘i xá»­ khÃ¡c:

1. **Batch nhá» bá»‹ chi phá»‘i bá»Ÿi overhead, khÃ´ng pháº£i compute.** Batch 1 máº¥t 55 ms cho ~15 token
   (~272 tok/s), trong khi batch 16 chá»‰ máº¥t 386 ms cho ~240 token (~622 tok/s). Throughput tÄƒng 2.3x
   chá»‰ nhá» gá»™p request - chi phÃ­ per-request Ä‘Æ°á»£c amortize, cÃ²n chi phÃ­ per-token thÃ¬ khÃ´ng Ä‘á»•i.
   VÃ¬ tháº¿ chiáº¿n lÆ°á»£c Ä‘Ãºng lÃ  **static batching + token-sort**, khÃ´ng pháº£i continuous batching:
   khÃ´ng cÃ³ vÃ²ng decode nÃ o Ä‘á»ƒ "chÃ¨n" vÃ o giá»¯a, nÃªn hÃ  hÃ ng Ä‘á»™ng khÃ´ng mang láº¡i gÃ¬.
2. **Chat thÃ¬ ngÆ°á»£c láº¡i.** Decode-bound nghÄ©a lÃ  má»—i request chiáº¿m slot hÃ ng giÃ¢y vÃ  throughput
   Ä‘áº¿n tá»« viá»‡c Ä‘á»• Ä‘áº§y khoáº£ng trá»‘ng decode giá»¯a cÃ¡c slot (continuous batching Ä‘o ÄÆ°á»£c á»Ÿ base:
   RPS chá»‰ tÄƒng 1.34x khi users tÄƒng 5x vÃ¬ 4 slot Ä‘Ã£ bÃ£o hÃ²a). Embedding request káº¿t thÃºc trong ms,
   nÃªn batch tÄ©nh gá»™p nhiá»u text vÃ o má»™t forward pass lá»›n hiá»‡u quáº£ hÆ¡n.
3. **Há»‡ quáº£ cho autoscaler.** Má»™t autoscaler Ä‘áº¿m request hoáº·c concurrency sáº½ sai cho cáº£ hai:
   chat sinh concurrency cao kÃ©o dÃ i (slot giá»¯ lÃ¢u), embedding sinh burst request nhá» hoÃ n thÃ nh ngay.
   Scaling chung theo "sá»‘ request" sáº½ over-provision cho embedding vÃ  under-provision cho chat; pháº£i tÃ¡ch
   queue/pool vÃ  scale theo GPU-seconds hoáº·c queue depth, khÃ´ng theo request count. ÄÃ³ lÃ  lÃ½ do cÃ¡c
   serving stack tÃ¡ch riÃªng prefill/disaggregated serving cho hai regime.
4. **Giá»›i háº¡n cá»§a demo.** Mean-pooled chat model lÃ  sentence encoder yáº¿u: nÃ³ match theo phÃ¢n phá»‘i
   token chung, khÃ´ng hiá»ƒu paraphrase lexical khÃ¡c nhau (vÃ­ dá»¥ "TTFT" vs "time to first token").
   Retrieval thá»±c táº¿ cáº§n embedding model chuyÃªn dá»¥ng (Qwen3-Embedding, BGE-M3); bÃ i nÃ y chá»‰ dÃ¹ng
   chat GGUF Ä‘á»ƒ khÃ´ng táº£i thÃªm vÃ  giá»¯ nguyÃªn cÃ¹ng pháº§n cá»©ng.
