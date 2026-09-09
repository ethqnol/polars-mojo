# Getting Started

## Installation

### Via Pixi / Modular Community (Prefix.dev)

Add `polars-mojo` to your project:

```bash
pixi add -c https://conda.modular.com/max -c conda-forge -c https://repo.prefix.dev/modular-community polars-mojo
```

In your `pixi.toml`:

```toml
[dependencies]
polars-mojo = ">=0.1.0"
```

### Local Development

Clone the repository and compile the native Rust FFI library:

```bash
git clone https://github.com/ethqnol/polars-mojo.git
cd polars-mojo
pixi run build-rust
```

Run the test suite:

```bash
pixi run tests
```

Run benchmarks:

```bash
pixi run benchmark
```

## Compiling Mojo Programs

When compiling an executable that imports `molars`, link `libpolars_ffi`:

```bash
mojo build my_app.mojo -Xlinker -lpolars_ffi
```

To run directly:

```bash
mojo run my_app.mojo -Xlinker -lpolars_ffi
```

If developing locally inside this repository without package installation, include the current directory:

```bash
mojo run -I . -Xlinker target/release/libpolars_ffi.a -Xlinker -lpthread -Xlinker -ldl -Xlinker -lm my_app.mojo
```

*(Alternatively, use `./build.sh my_app.mojo --run`)*.

## Minimal Example

Create a file named `main.mojo`:

```mojo
from molars import DataFrame

def main() raises:
    # 1. Ingest dataset (CSV or Parquet)
    var df = DataFrame.read_csv("tests/sample.csv")

    # 2. Inspect table dimensions and preview rows
    print("Shape:", df.shape())  # (rows, cols)
    print(df)

    # 3. Slice and project columns
    var top3 = df.head(3)
    var subset = df.select(["name", "score"])

    # 4. Zero-copy Series access and SIMD reductions
    var score_col = df["score"]
    print("Total score:", score_col.sum())
    print("Mean score:", score_col.mean())
    print("Min score:", score_col.min())
    print("Max score:", score_col.max())
    print("Std dev:", score_col.std())

    # 5. Vectorized arithmetic and broadcasting
    var adjusted = (score_col * 1.05) + 2.0
    print("Adjusted first score:", adjusted[0])

    # 6. Apply pure-Mojo closures zero-copy
    var multiplier = 1.10
    def tax_calc(x: Float64) raises {imm multiplier} -> Float64:
        return x * multiplier

    var taxed = score_col.apply(tax_calc)

    # 7. High-performance multithreaded GroupBy
    var grouped = df.group_by("name").agg("score:mean:avg_score,score:max:high_score")
    print(grouped)

    # 8. Export results to Parquet or CSV
    grouped.write_parquet("summary.parquet")
    grouped.write_csv("summary.csv")
```

