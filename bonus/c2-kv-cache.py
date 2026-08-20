#!/usr/bin/env python3
"""BONUS C2 - KV cache quantization: f16 vs q8_0 on the same model.

The deck's "FP8 KV cache" idea, measured on a laptop with a 4 GB NVIDIA GPU.
llama-bench with `-ctk q8_0 -ctv q8_0` vs the default f16 cache, on the same
Qwen3.5-0.8B model.

KV cache memory is paged and committed lazily, so idle RSS/VRAM probes
undercount it. This script therefore soaks the cache with a long prefill and
samples memory DURING the run:
  - VRAM peak (nvidia-smi) with KV on the GPU (production path)
  - RSS peak (psutil) with KV forced to host RAM (`-nkvo 1`)
at prompt lengths 2048 and 16384, for f16 and q8_0 KV.

Quality is checked separately over HTTP on 10 auto-gradable prompts (both KV
types scored 20/20 in the lab run), and decode parity is cross-checked with
llama-bench `-ctk/-ctv` on CUDA (184 vs 183 tok/s on this machine).

    .venv/bin/python bonus/c2-kv-cache.py
"""
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "lib"))
import labkit  # noqa: E402

import psutil  # noqa: E402


def nvidia_used_mib() -> float:
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=20, check=False,
        ).stdout.strip()
        return float(out.splitlines()[0])
    except (OSError, ValueError, IndexError):
        return float("nan")


def bench_peak(prompt_len: int, kv: str, no_kv_offload: bool, measure_vram: bool,
               model: str, threads: int, ngl: int) -> float:
    bench = labkit.runtime_bin("llama-bench")
    cmd = [str(bench), "-m", model, "-t", str(threads), "-ngl", str(ngl),
           "-p", str(prompt_len), "-n", "0", "-r", "1",
           "-ctk", kv, "-ctv", kv]
    if no_kv_offload:
        cmd += ["-nkvo", "1"]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    peak = 0.0
    while proc.poll() is None:
        v = nvidia_used_mib() if measure_vram else \
            psutil.Process(proc.pid).memory_info().rss / 1024**2
        peak = max(peak, v)
        time.sleep(0.15)
    proc.wait(timeout=30)
    return peak


def main() -> int:
    ap = argparse.ArgumentParser(description="KV cache memory experiment (bonus C2).")
    ap.add_argument("--prompt-len", type=int, default=16384)
    args = ap.parse_args()

    active = labkit.load_active()
    model = str(labkit.repo_root() / active["primary_model"])
    hw = labkit.load_hardware()
    threads = labkit.threads(hw)
    ngl = labkit.n_gpu_layers(hw)

    results = {}
    for kv in ("f16", "q8_0"):
        tag = f"kv_{kv}"
        results[tag] = {}
        for plen in (2048, args.prompt_len):
            vram = bench_peak(plen, kv, no_kv_offload=False, measure_vram=True,
                              model=model, threads=threads, ngl=ngl)
            rss = bench_peak(plen, kv, no_kv_offload=True, measure_vram=False,
                             model=model, threads=threads, ngl=ngl)
            results[tag][str(plen)] = {"vram_peak_mib": round(vram, 1),
                                       "rss_peak_mib": round(rss, 1)}
            print(f"  {kv:5s} pp{plen:5d}: VRAM {vram:6.0f} MB | RSS(no-kv-offload) {rss:6.0f} MB",
                  flush=True)

    out = labkit.repo_root() / "benchmarks" / "bonus-c2-kv-cache.json"
    out.write_text(json.dumps(results, indent=2))
    print(f"\n==> Wrote {out.relative_to(labkit.repo_root())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
