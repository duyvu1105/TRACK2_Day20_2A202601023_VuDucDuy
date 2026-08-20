# Reflection — Day 20 Lab (Personal Report)

**Họ Tên:** Vũ Đức Duy
**Cohort:** Track 2 — 2A202601023
**Ngày submit:** 2026-08-20

---

## 1. Hardware & runtime *(rubric 1, 2 — 10 điểm)*

- **OS:** Windows 11 (AMD64)
- **CPU:** 12th Gen Intel Core i7-12700H
- **Cores:** 14 physical / 20 logical
- **CPU extensions:** AVX2
- **RAM:** 15.7 GB
- **Accelerator:** NVIDIA GeForce RTX 3050 Ti Laptop GPU, CUDA, 4096 MiB
- **llama.cpp asset đã tải:** `llama-b10488-bin-win-cuda-12.4-x64.zip`
- **Model đã dùng:** Qwen3.5 0.8B (`LAB_MODEL=qwen35-0.8b`)
- **Quantization:** `Q4_K_M` + `UD-Q2_K_XL`

**Chạy ở đâu:** laptop cá nhân.

**Setup story:** Windows PowerShell 5 đọc sai file UTF-8 của runner, nên tôi chạy trực
tiếp các Python entry point. Hugging Face tải quá chậm nên tôi dùng mirror được
`MANUAL-DOWNLOAD.md` đề xuất. Tôi cũng sửa hardware probe để CIM lỗi không bị diễn giải
thành 1 PB RAM. Cổng 8080 đã bị Apache chiếm nên server lab chạy ở 18080.

---

## 2. Đo lường *(rubric 3, 4, 5 — 20 điểm)*

| Quantization | Size (GB) | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode (tok/s) |
|---|--:|--:|--:|--:|--:|--:|
| Q4_K_M | 0.50 | 2130 | 1040 / 1105 | 5.9 / 6.3 | 1409 / 1451 / 1451 | 169.0 |
| UD-Q2_K_XL | 0.39 | 2999 | 1048 / 1225 | 5.9 / 6.4 | 1421 / 1607 / 1607 | 169.5 |

**Quan sát:** Q2 nhỏ hơn 22% nhưng decode chỉ nhanh hơn 0.3%, còn TTFT P95 kém hơn
11%. Với cùng câu hỏi goodput, Q4 lập luận đúng về latency/SLO; Q2 gọi goodput là một
“streaming library”. Trên cấu hình CUDA này, tiết kiệm 0.11 GB không đáng với suy giảm
chất lượng.

---

## 3. Serving under load *(rubric 8, 9, 10 — 20 điểm)*

| Users | RPS | P50 (ms) | P95 (ms) | P99 (ms) | Eff. concurrency | Failures |
|--:|--:|--:|--:|--:|--:|--:|
| 10 | 2.42 | 2900 | 4600 | 6100 | 7.6 | 0.0% |
| 50 | 3.25 | 14000 | 17000 | 18000 | 42.3 | 0.0% |

- **Offered load tăng 5×, throughput thực tăng:** 1.34×
- **P95 tăng:** 3.70×
- **Effective concurrency ở 50 users:** 42.3 so với `--parallel=4` slots
- **Peak `llamacpp:n_busy_slots_per_decode`:** 3.96 / 4 slots

**Saturation reading:** Server đã có queue ở 10 users (7.6 > 4 slots) và bão hòa sâu
ở 50: offered load 5× chỉ cho RPS 1.34×, nhưng P95 tăng 3.70×. Busy slots 3.96/4 và
46 request deferred chứng minh phần latency thêm là queue time. Với SLO P95 5 giây,
tôi sẽ tăng `--parallel` trước vì nó trực tiếp mở rộng decode capacity, rồi đo lại.

---

## 4. Integration *(rubric 12, 13 — 15 điểm)*

| Day | Piece | Real hay stub? |
|---|---|---|
| N16 Cloud/IaC | localhost | stub |
| N17 Data pipeline | in-memory list | stub |
| N18 Lakehouse | toy document dictionary | stub |
| N19 Vector + features | keyword-overlap retrieval | stub |
| N20 Serving | `llama-server` | real |

**Latency split** (mean của 3 query):

- embed: 0.0 ms
- retrieve: 0.0 ms
- llm: 4218.0 ms
- total: 4218.1 ms
- **stage chiếm nhiều nhất:** llm (100% total)

**Reflection:** LLM là bottleneck đúng như kỳ vọng vì embed/retrieval đều là stub
trong bộ nhớ. Muốn giảm latency 2×, tôi sẽ giảm output budget và thử model/runtime
nhanh hơn ở decode; khi có tải đồng thời, tôi cũng đo lại `--parallel`. Tối ưu hai
stage gần 0 ms không thể tạo cải thiện đáng kể.

---

## 5. The single change that mattered most *(rubric 11 — 10 điểm)*

**Change:** tăng `-t` từ 1 lên 14 trong sweep `tg128`.

```text
before:  188.8 tok/s (-t 1)
after:   191.0 tok/s (-t 14)
speedup: 1.012×
```

**Tại sao nó work:** Mức tăng chỉ 1.2%, nhưng chính đường cong phẳng là kết quả quan
trọng. Cả 99 layer đã được offload lên CUDA, nên GPU execution và VRAM bandwidth chi
phối decode; host thread count không còn là nút thắt như trong phép đo CPU-only. Tăng
từ một thread lên 14 chỉ giảm phần overhead chuẩn bị/cấp việc trên CPU.

Từ 14 lên 20 hoặc 40 threads, throughput giảm nhẹ còn 190.2 và 189.7 tok/s. Các thread
thừa không tạo thêm bandwidth hay GPU compute; chúng chỉ thêm scheduling contention.
Vì vậy 14 physical cores là knee hợp lý, nhưng knob thread gần như không có leverage
trên cấu hình GPU-offload này.

---

## 6. Bonus *(optional)*

**B1 - Build từ source so với prebuilt (cùng revision b10488, cùng model, cùng backend - cả hai ép
CPU thuần `-ngl 0 -nopo 1`)**

```text
Change:  compile llama.cpp từ source với -DGGML_NATIVE=ON (MSVC/AVX2)
decode  tg128:  prebuilt 56.7 -> source 53.5 tok/s  (0.94x)
prefill pp512:  prebuilt 263.7 -> source 287.2 tok/s (1.09x)
```

Với decode, prebuilt nhanh hơn 1.06x; với prefill, source build nhanh hơn 1.09x. Lý do: decode là
memory-bound - prebuilt đã dispatch sẵn kernel Alder Lake (`ggml-cpu-alderlake.dll`, AVX2 + AVX-VNNI)
qua CPUID nên bản native không có lợi thế vector; còn prefill compute-bound nên bản compile native cho
AVX2 thắng nhẹ. Kết luận: trên máy này compiler knob chỉ ~1x - không phải chỗ tối ưu chính.

**B2 - GPU offload sweep - before/after chính của bonus**

```text
Change:  offload 0 -> 32/99 layers lên RTX 3050 Ti (-ngl)
Before:  55.6 tok/s (-ngl 0, CPU decode)
After:   192.7 tok/s (-ngl 32/99, GPU decode)
Speedup: 3.47x
```

Cơ chế: model 0.8B Q4 (~0.5 GB) fit hoàn toàn trong 4 GB VRAM nên full offload là tối ưu; curve phẳng
ở ngl 32 vì model chỉ có 24 blocks (+ embedding/output tensors). Partial offload (-ngl 8/16) kém hơn
tổng các phần vì decode là dependency chain: token phải round-trip qua phần CPU còn lại và PCIe. Knob
accelerator (3.47x) lớn hơn nhiều so với compiler knob (1.06x) - đúng hướng "chọn đúng knob trước".

**B4 - Challenge C2 (KV cache quantization)** - chi tiết `bonus/c2-kv-cache.md`

`--cache-type-k/v q8_0` giảm ~90 MB VRAM / ~86 MB RSS ở ctx 16384, decode speed gần như không đổi
(184.1 vs 183.0 tok/s), accuracy 20/20 trên eval 10 prompt tự chấm. Trên model nhỏ này KV chiếm ít nên
tiết kiệm tuyệt đối nhỏ; FP8/INT4 KV chỉ đáng khi ctx dài + nhiều slot song song.

**B5 - C9 (embedding serving)** - chi tiết `bonus/c9-embedding-serving.md`

Regime embedding prefill-bound: batch 1->16 tăng throughput 18.1 -> 41.5 texts/s (2.3x), ranking đúng
document; ngược lại chat decode-bound cần continuous batching. Một autoscaler chung đếm request/concurrency
sẽ sai cho cả hai regime - cần tách queue và scale theo GPU-seconds/queue depth.

---

## 7. Điều làm tôi ngạc nhiên nhất *(optional)*

Q2 nhỏ hơn đáng kể nhưng không nhanh hơn Q4 trên GPU, trong khi chất lượng câu trả lời
giảm rõ. Đồng thời thread sweep gần như phẳng vì phần decode đã chuyển sang CUDA.
Bonus B1 cũng đi ngược kỳ vọng: build từ source với `-DGGML_NATIVE=ON` không thắng
được prebuilt trên decode vì release đã dispatch kernel đúng microarchitecture sẵn.

---

## 8. Self-check

- [x] Hardware và model manifest
- [x] Benchmark hai quantization và thread sweep
- [x] Load test 10/50 users và continuous-batching metrics
- [x] Ba integration query với provenance và latency split
- [x] Các nhận xét bắt buộc đã được thay thế
- [x] Bonus B1: build llama.cpp từ source + `compare-builds` (tg128 + pp512)
- [x] Bonus B2: GPU offload sweep (`-ngl` 0..99)
- [x] Bonus B3: before/after bonus rõ ràng trong §6
- [x] Bonus B4: challenge C2 - KV cache quantization
- [x] Bonus B5: C9 - embedding serving (prefill-bound regime)
