# polars-mojo

[![CodeQL](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Native Mojo bindings for the Polars query engine via the Apache Arrow C Data Interface.

`polars-mojo` (imported as `molars`) provides zero-copy ingestion, SQL execution, and SIMD-accelerated column operations without Python runtime overhead.

## Current Scope (v0.1.0)

- **Readers**: Multithreaded CSV and Parquet parsing (`DataFrame.read_csv`, `DataFrame.read_parquet`).
- **SQL Queries**: Polars `SQLContext` queries (`DataFrame.sql`) with filtering, joins, aggregations, and sorting before Arrow handoff.
- **Zero-Copy Arrow C ABI**: In-memory Arrow `StructArray` buffers with RAII release callbacks.
- **Data Types**: Float64 (`g`), Float32 (`f`), Int64 (`l`), Int32 (`i`), Utf8 (`u`), LargeUtf8 (`U`), and StringView (`vu`).
- **SIMD Operations**: Vectorized aggregations (`sum_float64`, `sum_int64`, `mean_float64`) using `std.algorithm.vectorize`.

## Roadmap

### Short-Term Priorities
- [ ] **Writers / Exporters**:
  - `DataFrame.write_parquet(path)`
  - `DataFrame.write_csv(path)`
- [ ] **Table Slicing & Projection**:
  - `df.head(n)` and `df.tail(n)`
  - `df.select(columns)` and `df.drop(columns)`
  - `df.rename(mapping)`
- [ ] **Additional SIMD Reductions**:
  - `min()` and `max()`
  - `std()` and `var()`
  - Element-wise series arithmetic (`col_a + col_b`, scalar broadcasting)

### Medium Priorities
- [ ] **In-Memory Table Operations**:
  - `df.filter(mask)` (Boolean mask filtering on existing DataFrames)
  - `df.sort(by, descending)`
  - `df.join(other, on, how)` between in-memory Mojo DataFrames
  - `df.group_by(by).agg(...)`
- [ ] **Null and Boolean Handling**:
  - High-level `BooleanSeries`
  - Bitmask inspection and filtering (`is_null()`, `is_not_null()`, `fill_null()`)
- [ ] **Temporal Types**:
  - `Date`, `Datetime`, and `Duration` support

### In a Long Time
- [ ] **Mojo Expression DSL**: Fluent chained expression syntax (`col(...)`) mapped to Polars AST.
- [ ] **Nested Data Types**: `List`, `Struct`, and `Map`.
- [ ] **Streaming Engine**: Streaming batches for datasets larger than available RAM.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Docs](https://ethqnol.github.com/polars-mojo)