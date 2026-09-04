# molars Documentation

`molars` provides Mojo bindings for Polars via the Apache Arrow C Data Interface. It allows Mojo programs to read CSV and Parquet files and execute SQL queries with zero memory copies between the Rust engine and Mojo.

## Features

- **Zero-Copy Arrow ABI**: Reads data directly into Arrow `StructArray` buffers without serialization or Python runtime overhead.
- **File Ingestion**: Multithreaded CSV and Parquet parsing backed by Polars.
- **SQL Queries**: Run SQL statements with joins, aggregations, and filters via the Polars `SQLContext` query engine.
- **SIMD Aggregations**: Vectorized column reductions (`sum_float64`, `sum_int64`, `mean_float64`) using Mojo's hardware vector primitives.
- **String Support**: Compatible with 32-bit Utf8 (`u`), 64-bit LargeUtf8 (`U`), and Arrow StringView (`vu`).

## Scope & Limitations (v0.1.0)

`molars` is currently focused on ingestion, SQL querying, and raw buffer compute:
- **Supported**: `DataFrame.read_csv`, `DataFrame.read_parquet`, `DataFrame.sql`, column views, SIMD aggregations, Arrow ABI structs.
- **Not yet supported**: Fluent expression API (`pl.col(...)`), in-memory table mutations (`df.filter()`, `df.join()` between existing Mojo tables), writing files back to disk, and temporal/nested types.

## Documentation Index

- [Getting Started](getting-started.md): Installation, compilation, and basic usage.
- [DataFrame API](dataframe.md): Loading files, inspecting dimensions, extracting columns, and pretty-printing.
- [Series API](series.md): Pointer access, scalar indexing, string reading, and SIMD reductions.
- [SQL Engine](sql.md): Querying CSV and Parquet files using Polars SQL.
- [Arrow C Data Interface](arrow-abi.md): Memory lifecycle, ABI structs, and type mappings.
