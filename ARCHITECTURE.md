# Architecture

`polars-mojo` provides native Mojo bindings to the Polars query engine without going through Python. It exchanges data using the Apache Arrow C Data Interface.

## Overview

```
Mojo Application
  │
  ▼
molars.dataframe (DataFrame, Series)
  │ (zero-copy pointer views, SIMD kernels)
  ▼
molars.arrow_abi (ArrowArray, ArrowSchema, ManagedArrowTable)
  │ (C ABI structs, RAII release callbacks)
  ▼
libpolars_ffi (Rust C ABI)
  │
  ▼
Polars Engine (CSV/Parquet readers, SQLContext, LazyFrame)
```

## Data Transfer & Memory Ownership

Data flows from Rust to Mojo zero-copy via the Arrow C Data Interface:

1. **Query Execution**: Rust reads the input file (CSV or Parquet) or evaluates a SQL query via Polars' `LazyFrame` engine.
2. **Arrow Struct Export**: The resulting `DataFrame` is aligned into a single chunk and converted to an Arrow `StructArray`, where each field corresponds to a column.
3. **C ABI Handoff**: `ffi::export_array_to_c` and `ffi::export_field_to_c` populate caller-provided `ArrowArray` and `ArrowSchema` structs. The underlying data buffers remain owned by Rust's allocator.
4. **Mojo Wrapper**: Mojo wraps the pointers in `ManagedArrowTable`.
5. **Reclamation (RAII)**: When `ManagedArrowTable` goes out of scope, its `__deinit__` calls `molars_release_array` and `molars_release_schema`. These invoke the Arrow C `release` callbacks, allowing Rust to deallocate the column buffers.

## Type Mappings

Arrow format strings (`ArrowSchema.format`) map to Mojo types as follows:

| Format Code | Arrow Type | Mojo Accessor | Storage Layout |
|-------------|------------|---------------|----------------|
| `g` | Float64 | `as_float64_ptr()`, `get_float64()` | 64-bit IEEE 754 floats |
| `f` | Float32 | `as_float32_ptr()`, `get_float32()` | 32-bit IEEE 754 floats |
| `l` | Int64 | `as_int64_ptr()`, `get_int64()` | 64-bit signed integers |
| `i` | Int32 | `as_int32_ptr()`, `get_int32()` | 32-bit signed integers |
| `u` | Utf8 | `get_string()` | 32-bit offsets + UTF-8 byte buffer |
| `U` | LargeUtf8 | `get_string()` | 64-bit offsets + UTF-8 byte buffer |
| `vu` | Utf8View (StringView) | `get_string()` | 16-byte descriptors (inlined <=12B or buffer offset/len) + variadic buffers |

## SIMD Vectorization

`Series` aggregations (`sum_float64`, `sum_int64`, `mean_float64`) access the column's contiguous memory buffer via `as_float64_ptr()` / `as_int64_ptr()`. 

Loop execution uses `std.algorithm.vectorize` with vector loads:

```mojo
def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
    var v = ptr.unsafe_load[width=simd_width](idx)
    total += v.reduce_add()

vectorize[simd_w](n, add_chunk)
```

This compiles to target-native SIMD instructions (AVX2/AVX-512 on x86_64, NEON on ARM).

## FFI Boundary

`libpolars_ffi` exports the following C ABI symbols:

- `molars_read_csv(path, out_array, out_schema) -> i32`
- `molars_read_parquet(path, out_array, out_schema) -> i32`
- `molars_sql_query(query, table_name, file_path, out_array, out_schema) -> i32`
- `molars_release_array(array)`
- `molars_release_schema(schema)`
- `molars_get_last_error(buf, buf_len) -> i32`

Return codes follow standard Unix conventions: `0` for success, negative integers for failures. Errors are recorded in a thread-safe static buffer retrievable via `molars_get_last_error`.
