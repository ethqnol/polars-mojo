from std.time import perf_counter_ns
from molars import DataFrame, Series

def main() raises:
    var t0 = perf_counter_ns()
    var df = DataFrame.read_csv("scratch/bench_1m.csv")
    var load_ms = Float64(perf_counter_ns() - t0) / 1_000_000.0

    var col = df["val_f64"]
    var ptr = col.as_float64_ptr()
    var n = col.len()

    var t_start = perf_counter_ns()
    var scalar_sum = Float64(0.0)
    for i in range(n):
        scalar_sum += ptr[unsafe_offset=i]
    var scalar_ms = Float64(perf_counter_ns() - t_start) / 1_000_000.0

    t_start = perf_counter_ns()
    var simd_sum = col.sum_float64()
    var simd_ms = Float64(perf_counter_ns() - t_start) / 1_000_000.0

    var diff = simd_sum - scalar_sum
    if diff < 0.0:
        diff = -diff
    if diff > 0.01:
        raise Error("simd and scalar sums diverge")

    var speedup = scalar_ms / simd_ms
    print("benchmark (1M rows):")
    print("  read_csv:   ", load_ms, "ms")
    print("  scalar_sum: ", scalar_ms, "ms")
    print("  simd_sum:   ", simd_ms, "ms (", speedup, "x)")
    _ = df
