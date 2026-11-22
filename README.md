# polars-mojo

[![CodeQL](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/ethqnol/polars-mojo/actions/workflows/github-code-scanning/codeql) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Native Mojo bindings for the Polars query engine via the Apache Arrow C Data Interface.

`polars-mojo` (imported as `molars`) provides zero-copy ingestion, SQL execution, and SIMD-accelerated column operations without Python runtime overhead.

## Current Scope (v0.1.0)

- **Readers & Writers**: Multithreaded CSV (with optional `try_parse_dates`) and Parquet ingestion (`DataFrame.read_csv`, `DataFrame.read_parquet`) and serializing back to disk (`DataFrame.write_csv`, `DataFrame.write_parquet`).
- **Table Slicing, Filtering, Sorting & Joins**: Fast row slicing (`df.head(n)`, `df.tail(n)`), column manipulation (`df.select(cols)`, `df.drop(cols)`, `df.rename(old, new)`), boolean mask filtering (`df.filter(mask)`), single/multi-column sorting (`df.sort(by, descending, nulls_last)`), and in-memory joins (`df.join(other, on, how)` supporting `inner`, `left`, `right`, `full`, `semi`, `anti`, `cross`).
- **Null & Boolean Handling**: High-level `BooleanSeries` with logical operators (`&`, `|`, `^`, `~`) and reductions (`sum`, `any`, `all`), Series comparison operators (`>`, `>=`, `<`, `<=`, `==`, `!=`, `str_contains`, `str_starts_with`, `str_ends_with`), Arrow validity bitmap null checks (`is_null`, `is_not_null`, `has_nulls`, `count_nulls`), and null remediation (`drop_nulls`, `fill_null`, `fill_null_strategy`).
- **GroupBy & Parallel Aggregations**: Multithreaded groupby engine (`df.group_by(keys)`, `df.groupby(keys)`) supporting `agg(...)`, `sum(...)`, `mean(...)`, `count()`, and multi-column aliased operations (`col:op:alias`).
- **SQL Queries**: Polars `SQLContext` queries (`DataFrame.sql`) with filtering, joins, aggregations, and sorting before Arrow handoff.
- **SIMD Operations**: Vectorized column reductions (`sum`, `mean`, `min`, `max`, `var`, `std`) with dynamic dispatch and specialized Float64/Float32/Int64/Int32 routines using `std.algorithm.vectorize`.
- **Vectorized Arithmetic & Broadcasting**: Element-wise series arithmetic (`col_a + col_b`, `col_a - col_b`, `*`, `/`) and scalar broadcasting (`col * 2.0`, `col + 10.0`, etc.).
- **Zero-Cost UDF Closures**: Native Mojo functions and stateful closures executed element-wise over Arrow buffers (`apply`, `apply_float64`, `apply_int64`).
- **Zero-Copy Arrow C ABI**: In-memory Arrow `StructArray` buffers with RAII release callbacks and validity bitmaps.
- **Data Types**: Float64 (`g`), Float32 (`f`), Int64 (`l`), Int32 (`i`), Boolean (`b`), Utf8 (`u`), LargeUtf8 (`U`), StringView (`vu`), Date (`tdD`), Datetime (`tss:`/`tsm:`/`tsu:`/`tsn:`), and Duration (`tDs`/`tDm`/`tDu`/`tDn`).

## Roadmap

### Completed Features
- [x] **Writers / Exporters**:
  - `DataFrame.write_parquet(path)`
  - `DataFrame.write_csv(path)`
- [x] **Table Slicing & Projection**:
  - `df.head(n)` and `df.tail(n)`
  - `df.select(columns)` and `df.drop(columns)`
  - `df.rename(old_name, new_name)`
- [x] **In-Memory Table Operations**:
  - `df.filter(mask)` (Boolean mask filtering on existing DataFrames)
  - `df.sort(by, descending, nulls_last)`
  - `df.join(other, on, how)` between in-memory Mojo DataFrames
- [x] **Null and Boolean Handling**:
  - High-level `BooleanSeries` and comparison operators
  - Bitmask inspection and filtering (`is_null()`, `is_not_null()`, `drop_nulls()`, `fill_null()`, `fill_null_strategy()`)
- [x] **Temporal Types**:
  - `Date`, `Datetime`, and `Duration` support (`try_parse_dates`, ISO formatting, raw tick/day accessors)
- [x] **GroupBy & Aggregations**:
  - `df.group_by(by).agg(...)` (Multithreaded grouping, `agg()`, `sum()`, `mean()`, `count()`, custom aliasing)
- [x] **SIMD Reductions & Arithmetic**:
  - `min()` and `max()` (`min_float64`, `max_float64`, `min_int64`, `max_int64`, etc.)
  - `std()` and `var()` (`std_float64`, `var_float64`)
  - Element-wise series arithmetic (`col_a + col_b`, scalar broadcasting: `+`, `-`, `*`, `/`)
- [x] **Zero-Cost UDF Closures**:
  - `series.apply(fn)`, `series.apply_float64(fn)`, `series.apply_int64(fn)`

### In a Long Time
- [ ] **Mojo Expression DSL**: Fluent chained expression syntax (`col(...)`) mapped to Polars AST.
- [ ] **Nested Data Types**: `List`, `Struct`, and `Map`.
- [ ] **Streaming Engine**: Streaming batches for datasets larger than available RAM.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Docs](https://ethqnol.github.com/polars-mojo)
