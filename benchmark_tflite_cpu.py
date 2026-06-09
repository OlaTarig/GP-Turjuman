"""
TFLite CPU Benchmark — Turjuman model_good.tflite
Uses Google AI Edge LiteRT (ai-edge-litert)

Install:  pip install ai-edge-litert psutil
Run:      python benchmark_tflite_cpu.py
"""

import math
import os
import random
import time

import numpy as np
import psutil
from ai_edge_litert.interpreter import Interpreter

MODEL_PATH  = "assets/models/model_good.tflite"
WARMUP_RUNS = 5
BENCH_RUNS  = 50

# ── Memory helpers ─────────────────────────────────────────────────────────────

def _process_rss_kb() -> float:
    """Resident Set Size of this process in KB."""
    return psutil.Process(os.getpid()).memory_info().rss / 1024

# ── Core benchmark ─────────────────────────────────────────────────────────────

def run_benchmark():
    # Measure baseline memory BEFORE loading the model
    mem_before_kb = _process_rss_kb()

    interpreter = Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()

    # Measure memory AFTER model is loaded + tensors allocated
    mem_after_kb  = _process_rss_kb()
    model_size_kb = os.path.getsize(MODEL_PATH) / 1024

    input_details  = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    input_shape    = input_details[0]["shape"]      # [1, 48, 126]
    input_idx      = input_details[0]["index"]
    output_idx     = output_details[0]["index"]
    output_shape   = output_details[0]["shape"]

    print("=" * 52)
    print("  TFLite CPU Benchmark — Turjuman Sign Model")
    print("=" * 52)
    print(f"  Model file   : {MODEL_PATH}")
    print(f"  Model size   : {model_size_kb:.1f} KB")
    print(f"  Input shape  : {list(input_shape)}")
    print(f"  Output shape : {list(output_shape)}")
    print(f"  Warmup runs  : {WARMUP_RUNS}")
    print(f"  Bench runs   : {BENCH_RUNS}")
    print("-" * 52)

    # Warmup
    for _ in range(WARMUP_RUNS):
        inp = np.random.uniform(-1, 1, input_shape).astype(np.float32)
        interpreter.set_tensor(input_idx, inp)
        interpreter.invoke()

    # Benchmark
    times_ms = []
    for _ in range(BENCH_RUNS):
        inp = np.random.uniform(-1, 1, input_shape).astype(np.float32)
        interpreter.set_tensor(input_idx, inp)
        t0 = time.perf_counter()
        interpreter.invoke()
        times_ms.append((time.perf_counter() - t0) * 1000.0)

    # Memory AFTER all inferences (peak working set)
    mem_peak_kb = _process_rss_kb()

    # Stats
    avg  = sum(times_ms) / len(times_ms)
    mn   = min(times_ms)
    mx   = max(times_ms)
    p95  = sorted(times_ms)[int((BENCH_RUNS - 1) * 0.95)]
    std  = math.sqrt(sum((t - avg) ** 2 for t in times_ms) / len(times_ms))
    tput = 1000.0 / avg

    mem_model_kb   = mem_after_kb - mem_before_kb   # cost of loading model
    mem_runtime_kb = mem_peak_kb  - mem_before_kb   # peak runtime footprint

    print(f"  Avg latency  : {avg:.2f} ms")
    print(f"  Min latency  : {mn:.2f} ms")
    print(f"  Max latency  : {mx:.2f} ms")
    print(f"  P95 latency  : {p95:.2f} ms")
    print(f"  Std dev      : {std:.2f} ms")
    print(f"  Throughput   : {tput:.1f} inf/sec")
    print("-" * 52)
    print(f"  Model size   : {model_size_kb:.1f} KB  (on disk)")
    print(f"  RAM at load  : +{mem_model_kb:.1f} KB  (after interpreter.allocate_tensors)")
    print(f"  RAM at peak  : +{mem_runtime_kb:.1f} KB  (after {BENCH_RUNS} inferences)")
    print("-" * 52)
    print("=" * 52)


if __name__ == "__main__":
    run_benchmark()
