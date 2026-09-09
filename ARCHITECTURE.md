# Architecture

`polars-mojo` provides native Mojo bindings to the Polars query engine without going through Python. It exchanges data using the Apache Arrow C Data Interface.

## Overview

```
Mojo Application
  │
  ▼
molars.dataframe (DataFrame, Series, GroupBy)
  │ (zero-copy pointer views, SIMD kernels, UDF closures)
  ▼
molars.arrow_abi (ArrowArray, ArrowSchema, ManagedArrowTable)
  │ (C ABI structs, RAII release callbacks)
  ▼
libpolars_ffi (Rust C ABI)
  │
  ▼
Polars Engine (Readers, Writers, SQLContext, Slicing, GroupBy, LazyFrame)
```

## Data Transfer & Memory Ownership

Data flows between Rust and Mojo zero-copy via the Arrow C Data Interface:

1. **Ingestion & Query Execution**: Rust reads an input file (CSV or Parquet) or evaluates a SQL query via Polars' `LazyFrame` engine.
2. **Arrow Struct Export**: The resulting `DataFrame` is aligned into a single contiguous chunk and exported as an Arrow `StructArray`, where each field corresponds to a column.
3. **C ABI Handoff**: `ffi::export_array_to_c` and `ffi::export_field_to_c` populate caller-provided `ArrowArray` and `ArrowSchema` structs. The underlying data buffers remain owned by Rust's allocator.
4. **Mojo Wrapper**: Mojo wraps the pointers in `ManagedArrowTable` and exposes high-level abstractions via `DataFrame` and `Series`.
5. **Two-Way Bridge Operations**: For operations like slicing (`molars_slice`), column projection (`molars_select_columns`, `molars_drop_columns`), renaming (`molars_rename_column`), table export (`molars_write_csv`, `molars_write_parquet`), and grouped aggregations (`molars_groupby_agg`), Mojo passes the active `ArrowArray` and `ArrowSchema` pointers directly back to Rust FFI without serialization.
6. **Reclamation (RAII)**: When `ManagedArrowTable` goes out of scope, its `__deinit__` calls `molars_release_array` and `molars_release_schema`. These invoke the Arrow C `release` callbacks, allowing Rust to safely deallocate the column buffers.

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
| `+s` | Struct | Root `DataFrame` | Nested child arrays representing table columns |

## SIMD Vectorization & Closures

### Reductions
`Series` aggregations (`sum`, `mean`, `min`, `max`, `var`, `std` and their type-specific variants like `sum_float64`, `min_int64`) access the column's contiguous memory buffer via typed pointers (`as_float64_ptr()`, `as_int64_ptr()`).

Loop execution uses `std.algorithm.vectorize` with hardware vector loads:

```mojo
def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
    var v = ptr.unsafe_load[width=simd_width](idx)
    total += v.reduce_add()

vectorize[simd_w](n, add_chunk)
```

This compiles to target-native SIMD instructions (AVX2/AVX-512 on x86_64, NEON on ARM).

### Vectorized Arithmetic
Overloaded operators (`+`, `-`, `*`, `/`) between Series and with scalar floats execute SIMD chunks with `unsafe_load` and `unsafe_store`:

```mojo
def chunk[simd_width: Int](idx: Int) {imm p1, imm p2, mut res_ptr}:
    var v1 = p1.unsafe_load[width=simd_width](idx)
    var v2 = p2.unsafe_load[width=simd_width](idx)
    res_ptr.unsafe_store[width=simd_width](idx, v1 + v2)

vectorize[simd_w](n, chunk)
```

### Pure-Mojo Closures (`apply`)
`.apply()`, `.apply_float64()`, and `.apply_int64()` accept pure Mojo functions and stateful closures (`{imm capture}`, `{var capture}`). Closures execute with zero FFI overhead directly across the contiguous native Arrow memory buffers.

## FFI Boundary

`libpolars_ffi` exports the following C ABI symbols:

### File I/O & Queries
- `molars_read_csv(path, out_array, out_schema) -> i32`: Ingests CSV files multithreaded.
- `molars_read_parquet(path, out_array, out_schema) -> i32`: Ingests Parquet files.
- `molars_sql_query(query, table_name, file_path, out_array, out_schema) -> i32`: Runs SQL queries with pushdown optimization.
- `molars_write_csv(array, schema, path) -> i32`: Serializes DataFrame buffers to CSV on disk.
- `molars_write_parquet(array, schema, path) -> i32`: Serializes DataFrame buffers to Parquet on disk.

### Table Transformations & GroupBy
- `molars_slice(array, schema, offset, length, out_array, out_schema) -> i32`: Slices rows (used by `head` and `tail`).
- `molars_select_columns(array, schema, col_names_csv, out_array, out_schema) -> i32`: Projects subset of columns.
- `molars_drop_columns(array, schema, col_names_csv, out_array, out_schema) -> i32`: Drops specified columns.
- `molars_rename_column(array, schema, old_name, new_name, out_array, out_schema) -> i32`: Renames a column.
- `molars_groupby_agg(array, schema, keys_csv, aggs_csv, out_array, out_schema) -> i32`: Executes parallel multithreaded groupby aggregations.

### Lifecycle & Diagnostics
- `molars_release_array(array)`: Invokes the Arrow array release callback.
- `molars_release_schema(schema)`: Invokes the Arrow schema release callback.
- `molars_get_last_error(buf, buf_len) -> i32`: Retrieves the most recent thread-safe error message.

Return codes follow standard Unix conventions: `0` for success, negative integers for failures. Errors are recorded in a thread-safe static buffer retrievable via `molars_get_last_error`.

