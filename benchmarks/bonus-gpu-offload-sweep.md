# Bonus - GPU offload sweep

Host `Windows-AMD64` � backend(s) `nvidia_cuda, vulkan` �
llama.cpp `b10488` � `threads=14` � metric `tg128`

| -ngl | tg128 (tok/s) | vs -ngl 0 | vs best |
|:--|--:|--:|--:|
| 0 | 55.6 | 1.00x | 29% |
| 8 | 82.7 | 1.49x | 43% |
| 16 | 108.3 | 1.95x | 56% |
| 24 | 171.1 | 3.08x | 89% |
| 32 | 192.5 | 3.46x | 100% |
| 99 | 192.7 | 3.47x | 100% |

Best: `-ngl 99` at 192.7 tok/s
-- 3.47x faster than CPU-only.

Where the curve flattens tells you the model ran out of layers to move. Where it
*peaks below* full offload tells you something did not fit and the accelerator
started paying to fetch weights it could not hold.

## Your finding

Full offload is best here, and the curve flattens for the right reason: Qwen3.5-0.8B has exactly 24 transformer blocks, and `-ngl 32` / `-ngl 99` tie at ~193 tok/s -- the machine ran out of tensors to move, not VRAM. The 0.5 GB Q4 model fits in the 4 GB RTX 3050 Ti with room to spare, so there is no point where the GPU starts paying to fetch weights it cannot hold.

Two details make this curve more useful than a single "use ngl 99" headline. First, the jump from `-ngl 24` (all 24 blocks) to `-ngl 32` (+21 tok/s, 171 -> 193) is the embedding/output tensors leaving the CPU, not another transformer block -- llama.cpp only moves those after every block is offloaded. Second, the partial-offload points are worth less than the layer counts suggest (+27/+26 tok/s per 8 blocks, then +63 for the last 8): decode is a serial dependency chain, and with part of the model on CPU every token still round-trips through host compute, so you pay PCIe transfer and CPU latency on top of GPU speed. That is the laptop-scale version of the deck's point that a partial offload split is a bandwidth/serialization trade-off, and it is why serving engines prefer whole-model placement (or op-level scheduling) once the model fits.

For this machine the practical ranking is clear: the accelerator knob (`-ngl`) is worth 3.47x, while the B1 compiler knob is worth ~1.06x -- VRAM is the biggest lever on a 4 GB laptop, not recompiling for the CPU.
