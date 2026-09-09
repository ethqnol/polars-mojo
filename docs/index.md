# molars Documentation

`molars` provides high-performance, native Mojo bindings for Polars via the Apache Arrow C Data Interface. It enables Mojo applications to ingest CSV and Parquet files, execute optimized SQL queries, perform parallel multithreaded group-bys, evaluate vectorized SIMD calculations, and export tabular data with zero memory copies between the Rust engine and Mojo.

## Features

- **Zero-Copy Arrow ABI**: Reads data directly into Arrow `StructArray` buffers without serialization or Python runtime overhead.
- **File Ingestion & Export**: Multithreaded CSV and Parquet ingestion (`read_csv`, `read_parquet`) and serializing back to disk (`write_csv`, `write_parquet`) powered by Polars.
- **Table Slicing & Projections**: Fast row slicing (`head`, `tail`) and column projection, deletion, and renaming (`select`, `drop`, `rename`).
- **Parallel GroupBy & Aggregations**: Multithreaded grouping engine (`group_by`, `groupby`) supporting `agg`, `sum`, `mean`, `count`, and multi-aggregation strings with column aliasing (`col:op:alias`).
- **SQL Queries**: Run SQL statements with joins, aggregations, and filters via the Polars `SQLContext` query engine.
- **SIMD Reductions**: Vectorized column reductions (`sum`, `mean`, `min`, `max`, `var`, `std`) dynamically dispatched or specialized for Float64, Float32, Int64, and Int32 using Mojo's hardware vector primitives.
- **Vectorized Arithmetic & Broadcasting**: Element-wise series operations (`+`, `-`, `*`, `/`) and scalar broadcasting accelerated by SIMD vectorization.
- **Zero-Cost UDF Closures (`apply`)**: Apply arbitrary pure Mojo functions and stateful closures element-wise directly across contiguous Arrow buffers without FFI overhead.
- **String Support**: Comprehensive zero-copy decoding for 32-bit Utf8 (`u`), 64-bit LargeUtf8 (`U`), and Arrow StringView (`vu`).

## Scope & Limitations (v0.1.0)

`molars` provides an extensive foundation for high-performance tabular compute in Mojo:
- **Supported**: `DataFrame.read_csv`, `DataFrame.read_parquet`, `DataFrame.write_csv`, `DataFrame.write_parquet`, `DataFrame.sql`, row slicing (`head`, `tail`), column projections (`select`, `drop`, `rename`), parallel groupby aggregations (`group_by`, `groupby`, `agg`, `sum`, `mean`, `count`), dynamic & type-specific SIMD reductions, SIMD element-wise arithmetic & scalar broadcasting, element-wise UDF closures (`apply`, `apply_float64`, `apply_int64`), and low-level Arrow C ABI structs.
- **Not yet supported**: Fluent expression DSL (`pl.col(...)`), in-memory Boolean mask filtering (`df.filter(mask)`), in-memory sorting (`df.sort()`), in-memory table joins (`df.join()` between existing Mojo tables), and temporal/nested types.

## Documentation Index

- [Getting Started](getting-started.md): Installation, compilation, and an end-to-end tutorial.
- [DataFrame API](dataframe.md): Loading files, table slicing, column projections, writers, GroupBy aggregations, and terminal display.
- [Series API & SIMD](series.md): Pointer access, scalar indexing, string reading, SIMD reductions, arithmetic operators, and UDF closures.
- [SQL Engine](sql.md): Querying CSV and Parquet files using Polars SQL.
- [Arrow C Data Interface](arrow-abi.md): Memory lifecycle, ABI structs, and type mappings.
- [Architecture & Memory](../ARCHITECTURE.md): System design, FFI boundary, and zero-copy data flow.

