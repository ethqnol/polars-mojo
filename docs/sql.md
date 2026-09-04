# SQL Engine

`molars` integrates with Polars' built-in `SQLContext` to allow running standard SQL queries directly against CSV and Parquet files.

```mojo
from molars import DataFrame
```

## How It Works

When you execute `DataFrame.sql(...)`:

```
User SQL Query
      │
      ▼
Polars LazyFrame (scans CSV/Parquet)
      │
      ▼
Polars SQLContext (parses SQL, builds logical plan)
      │
      ▼
Polars Query Optimizer (predicate pushdown, projection pushdown)
      │
      ▼
Arrow StructArray Export (C Data Interface)
      │
      ▼
Mojo DataFrame (zero-copy handoff)
```

Because the query runs inside Polars before the data enters Mojo, full optimization (filtering rows before reading, reading only requested columns) applies automatically.

---

## Syntax and Examples

### Basic Filtering and Column Selection

```mojo
var df = DataFrame.sql(
    "SELECT name, score FROM students WHERE score >= 85",
    "students",
    "tests/sample.csv"
)
```

### Aggregations and Grouping

```mojo
var df = DataFrame.sql(
    "SELECT department, AVG(salary) as avg_sal, COUNT(*) as cnt "
    + "FROM employees "
    + "GROUP BY department "
    + "HAVING cnt > 5",
    "employees",
    "data/employees.parquet"
)
```

### Sorting and Limits

```mojo
var df = DataFrame.sql(
    "SELECT id, product_name, price "
    + "FROM inventory "
    + "ORDER BY price DESC "
    + "LIMIT 10",
    "inventory",
    "data/inventory.parquet"
)
```

---

## Supported File Types

- **Parquet**: Scanned via `LazyFrame::scan_parquet`. Enables columnar projection and row-group pruning.
- **CSV**: Scanned via `LazyCsvReader`. Multithreaded parsing with schema inference.
