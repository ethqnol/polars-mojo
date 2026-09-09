# polars-mojo

[![CodeQL](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Native Mojo bindings for the Polars query engine via the Apache Arrow C Data Interface.

`polars-mojo` (imported as `molars`) provides zero-copy ingestion, SQL execution, and SIMD-accelerated column operations without Python runtime overhead.

## Current Scope (v0.1.0)

- **Readers & Writers**: Multithreaded CSV and Parquet ingestion (`DataFrame.read_csv`, `DataFrame.read_parquet`) and serializing back to disk (`DataFrame.write_csv`, `DataFrame.write_parquet`).
- **Table Slicing & Projection**: Fast row slicing (`df.head(n)`, `df.tail(n)`) and column manipulation (`df.select(cols)`, `df.drop(cols)`, `df.rename(old, new)`).
- **GroupBy & Parallel Aggregations**: Multithreaded groupby engine (`df.group_by(keys)`, `df.groupby(keys)`) supporting `agg(...)`, `sum(...)`, `mean(...)`, `count()`, and multi-column aliased operations (`col:op:alias`).
- **SQL Queries**: Polars `SQLContext` queries (`DataFrame.sql`) with filtering, joins, aggregations, and sorting before Arrow handoff.
- **SIMD Operations**: Vectorized column reductions (`sum`, `mean`, `min`, `max`, `var`, `std`) with dynamic dispatch and specialized Float64/Float32/Int64/Int32 routines using `std.algorithm.vectorize`.
- **Vectorized Arithmetic & Broadcasting**: Element-wise series arithmetic (`col_a + col_b`, `col_a - col_b`, `*`, `/`) and scalar broadcasting (`col * 2.0`, `col + 10.0`, etc.).
- **Zero-Cost UDF Closures**: Native Mojo functions and stateful closures executed element-wise over Arrow buffers (`apply`, `apply_float64`, `apply_int64`).
- **Zero-Copy Arrow C ABI**: In-memory Arrow `StructArray` buffers with RAII release callbacks.
- **Data Types**: Float64 (`g`), Float32 (`f`), Int64 (`l`), Int32 (`i`), Utf8 (`u`), LargeUtf8 (`U`), and StringView (`vu`).

## Roadmap

### Completed Features
- [x] **Writers / Exporters**:
  - `DataFrame.write_parquet(path)`
  - `DataFrame.write_csv(path)`
- [x] **Table Slicing & Projection**:
  - `df.head(n)` and `df.tail(n)`
  - `df.select(columns)` and `df.drop(columns)`
  - `df.rename(old_name, new_name)`
- [x] **GroupBy & Aggregations**:
  - `df.group_by(by).agg(...)` (Multithreaded grouping, `agg()`, `sum()`, `mean()`, `count()`, custom aliasing)
- [x] **SIMD Reductions & Arithmetic**:
  - `min()` and `max()` (`min_float64`, `max_float64`, `min_int64`, `max_int64`, etc.)
  - `std()` and `var()` (`std_float64`, `var_float64`)
  - Element-wise series arithmetic (`col_a + col_b`, scalar broadcasting: `+`, `-`, `*`, `/`)
- [x] **Zero-Cost UDF Closures**:
  - `series.apply(fn)`, `series.apply_float64(fn)`, `series.apply_int64(fn)`

### Medium Priorities
- [ ] **In-Memory Table Operations**:
  - `df.filter(mask)` (Boolean mask filtering on existing DataFrames)
  - `df.sort(by, descending)`
  - `df.join(other, on, how)` between in-memory Mojo DataFrames
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
