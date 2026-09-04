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
    # 1. Load CSV file
    var df = DataFrame.read_csv("data.csv")

    # 2. Print table shape and top rows
    print(df)

    # 3. Extract a numeric column and calculate sum via SIMD
    var col = df["price"]
    print("Row count:", col.len())
    print("Total price:", col.sum_float64())
    print("Average price:", col.mean_float64())

    # 4. Access strings zero-copy
    var names = df["name"]
    print("First item:", names.get_string(0))
```
