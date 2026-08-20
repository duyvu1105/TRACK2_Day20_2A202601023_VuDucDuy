# Bonus C2 - Quantization cho KV cache (f16 vs q8_0)

Kiá»ƒm tra Ã½ tÆ°á»Ÿng "FP8 KV cache" cá»§a deck trÃªn laptop cÃ³ GPU NVIDIA: cháº¡y cÃ¹ng
model vá»›i `--cache-type-k f16 --cache-type-v f16` (máº·c Ä‘á»‹nh) rá»“i Ä‘á»•i sang
`q8_0` cho cáº£ K vÃ  V, Ä‘o ba yáº¿u tá»‘: bá»™ nhá»›, latency, cháº¥t lÆ°á»£ng.

## Thiáº¿t láº­p

- **MÃ¡y:** Intel i7-12700H (14P/20L) Â· 15.7 GB RAM Â· RTX 3050 Ti Laptop 4 GB Â· Windows 11
- **Model:** Qwen3.5-0.8B Q4_K_M - 24 layers, GQA 2 KV heads, head_dim 128
- **Runtime:** llama.cpp b10488 (prebuilt CUDA) - `llama-server --parallel 1 --cont-batching`, `-ngl 99`
- **Thay Ä‘á»•i:** chá»‰ khÃ¡c `--cache-type-k/-v` (f16 â†’ q8_0)
- **CÃ¡ch Ä‘o:** KV cache cá»§a llama.cpp Ä‘Æ°á»£c paged vÃ  commit lazy, nÃªn probe RSS/VRAM lÃºc idle
  thiáº¿u sÃ³t. Thay vÃ o Ä‘Ã³, script `bonus/c2-kv-cache.py` "soak" cache báº±ng prefill 2048/16384
  token (llama-bench) vÃ  sample peak VRAM (nvidia-smi) / peak RSS (psutil) **trong lÃºc cháº¡y**.
  Cháº¥t lÆ°á»£ng Ä‘Æ°á»£c cháº¥m báº±ng 10 prompt tá»± Ä‘á»™ng (sá»‘ há»c, JSON-ish, fact), temp 0, 2 vÃ²ng.

## Sá»‘ liá»‡u

### Bá»™ nhá»› (peak trong lÃºc prefill, MB)

| KV type | VRAM @2048 | VRAM @16384 | RSS (no-kv-offload) @2048 | RSS @16384 |
|:--|--:|--:|--:|--:|
| f16 | 1123 | 1291 | 985 | 1169 |
| q8_0 | 1113 | 1201 | 978 | 1083 |

- Tiáº¿t kiá»‡m táº¡i ctx 16384: **90 MB VRAM** (1291 â†’ 1201) vÃ  **86 MB RSS** khi Ã©p KV xuá»‘ng RAM.
- KV growth 2048 â†’ 16384 (14,336 token): f16 +168 MB VRAM / +184 MB RSS; q8_0 +88 / +105 MB.

### Latency (llama-bench tg128, -ngl 99, 3 reps, cháº¡y tuáº§n tá»±)

| KV type | tg128 (tok/s) |
|:--|--:|
| f16 | 184.08 Â± 6.66 |
| q8_0 | 182.99 Â± 6.71 |

ChÃªnh lá»‡ch ~0.6% - khÃ´ng Ä‘Ã¡ng ká»ƒ. (Äo E2E qua HTTP cÅ©ng Ä‘Æ°á»£c thá»­ nhÆ°ng ráº¥t nhiá»…u giá»¯a cÃ¡c
lÆ°á»£t cháº¡y - GPU clock ramp - nÃªn dÃ¹ng llama-bench lÃ m báº±ng chá»©ng latency chÃ­nh.)

### Cháº¥t lÆ°á»£ng (10 prompt tá»± cháº¥m, 2 vÃ²ng = 20 láº§n, temp 0)

| KV type | Accuracy | E2E P50/P95 (HTTP, tham kháº£o) |
|:--|:--|--:|
| f16 | 20/20 | 2955 / 3278 ms |
| q8_0 | 20/20 | 3115 / 3368 ms |

## PhÃ¢n tÃ­ch

q8_0 KV cáº¯t gáº§n má»™t ná»­a dung lÆ°á»£ng KV cache Ä‘o Ä‘Æ°á»£c (90 MB VRAM / 86 MB RSS á»Ÿ 16K ctx) mÃ 
decode speed vÃ  accuracy trÃªn eval ngáº¯n gáº§n nhÆ° khÃ´ng Ä‘á»•i. ÄÃ³ lÃ  káº¿t quáº£ Ä‘Ãºng hÆ°á»›ng cá»§a deck,
nhÆ°ng cÃ³ hai chi tiáº¿t Ä‘Ã¡ng chÃº Ã½:

1. **Tiáº¿t kiá»‡m Ä‘o Ä‘Æ°á»£c chá»‰ báº±ng ~ná»­a lÃ½ thuyáº¿t.** Vá»›i model nÃ y (24 layers, 2 KV heads,
   head_dim 128), KV lÃ½ thuyáº¿t lÃ  12,288 element/token â†’ f16 = 24 KB/token, q8_0 = 13.5 KB/token,
   tiáº¿t kiá»‡m ká»³ vá»ng ~10.75 KB/token (â‰ˆ154 MB cho 14,336 token). Äo Ä‘Æ°á»£c chá»‰ ~5.6 KB/token
   effective. NguyÃªn nhÃ¢n: llama.cpp phÃ¢n bá»• KV theo page vÃ  commit lazy, vÃ  trÃªn CUDA cache cÃ³
   thá»ƒ chia hybrid giá»¯a VRAM/RAM - vÃ¬ váº­y con sá»‘ peak pháº£n Ã¡nh pháº§n cache thá»±c sá»± Ä‘Æ°á»£c
   dÃ¹ng, khÃ´ng pháº£i dung lÆ°á»£ng Ä‘Æ°á»£c reserve.
2. **TrÃªn model 0.8B, KV quant gáº§n nhÆ° vÃ´ nghÄ©a vá» máº·t sá»‘ tuyá»‡t Ä‘á»‘i.** 90 MB trÃªn 15.7 GB RAM /
   4 GB VRAM lÃ  khÃ´ng Ä‘Ã¡ng ká»ƒ so vá»›i weights. FP8/INT4 KV chá»‰ trá»Ÿ nÃªn quan trá»ng khi KV lÃ
   thÃ nh pháº§n chi phá»‘i: ctx dÃ i (RAG), nhiá»u slot song song (`--parallel N` nhÃ¢n KV lÃªn N láº§n -
   vá»›i 4 slot á»Ÿ 16K ctx, tiáº¿t kiá»‡m Æ°á»›c tÃ­nh ~360 MB), hoáº·c model lá»›n hÆ¡n (KV scale theo
   `n_layers Ã— n_kv_heads Ã— head_dim Ã— ctx`). ÄÃ¢y lÃ  báº£n laptop cá»§a cÃ¹ng quyáº¿t Äá»‹nh mÃ  datacenter
   Ä‘Æ°a ra khi chá»n FP8 KV cho KV-heavy workload.

**Giá»›i háº¡n:** eval 10 prompt ngáº¯n khÃ´ng báº¯t Ä‘Æ°á»£c suy giáº£m long-context retrieval mÃ  q8_0 cÃ³ thá»ƒ
gÃ¢y ra á»Ÿ vÃ¹ng xa cá»§a context. TrÆ°á»›c khi báº­t KV quant trong production, pháº£i validate báº±ng eval
context dÃ i, khÃ´ng pháº£i eval prompt ngáº¯n.
