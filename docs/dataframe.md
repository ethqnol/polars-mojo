# DataFrame API Reference

`DataFrame` represents an in-memory tabular dataset backed by an Apache Arrow `StructArray`. Memory buffers are owned by Rust and managed in Mojo via RAII release callbacks.

```mojo
from molars import DataFrame
```

## Definition

```mojo
struct DataFrame(Movable, Writable):
    var _table: ManagedArrowTable
    var _col_names: List[String]
    var _col_formats: List[String]
```

### Traits

- **`Movable`**: Enables move constructor semantics without copying underlying memory.
- **`Writable`**: Formats the table for terminal output via `print(df)` or custom writers.

---

## Constructors

### `read_csv`

```mojo
@staticmethod
def read_csv(path: String) raises -> DataFrame
```

Reads a CSV file into a `DataFrame` using the Polars multithreaded reader.

- **Parameters**:
  - `path` (`String`): Path to the CSV file.
- **Returns**: `DataFrame` containing the parsed columns.
- **Raises**: `Error` if the file cannot be opened, contains invalid UTF-8 in the path, or cannot be parsed.

```mojo
var df = DataFrame.read_csv("data.csv")
```

---

### `read_parquet`

```mojo
@staticmethod
def read_parquet(path: String) raises -> DataFrame
```

Reads an Apache Parquet file into a `DataFrame`.

- **Parameters**:
  - `path` (`String`): Path to the Parquet file.
- **Returns**: `DataFrame` containing the parsed columns.
- **Raises**: `Error` if the file is missing or Parquet metadata is corrupt.

```mojo
var df = DataFrame.read_parquet("data.parquet")
```

---

### `sql`

```mojo
@staticmethod
def sql(query: String, table_name: String, file_path: String) raises -> DataFrame
```

Executes a SQL query against a dataset using the Polars `SQLContext` query engine. Supports joins, aggregations, filtering, and sorting before ingesting results into Mojo.

- **Parameters**:
  - `query` (`String`): SQL query string (e.g. `"SELECT id, AVG(val) FROM t GROUP BY id"`).
  - `table_name` (`String`): Identifier used in the `FROM` clause.
  - `file_path` (`String`): Path to the backing CSV or Parquet file.
- **Returns**: `DataFrame` containing query results.
- **Raises**: `Error` on syntax error, query planner failure, or file read error.

```mojo
var df = DataFrame.sql(
    "SELECT name, score FROM students WHERE score >= 80 ORDER BY score DESC",
    "students",
    "tests/sample.csv"
)
```

---

## Dimensions and Metadata

### `num_rows` / `height`

```mojo
def num_rows(self) -> Int
def height(self) -> Int
```

Returns the number of rows in the table.

### `num_cols` / `width`

```mojo
def num_cols(self) -> Int
def width(self) -> Int
```

Returns the number of columns in the table.

### `shape`

```mojo
def shape(self) -> Tuple[Int, Int]
```

Returns table dimensions as a `(rows, columns)` tuple.

```mojo
var shape = df.shape()
print("Rows:", shape[0], "Columns:", shape[1])
```

### `column_names`

```mojo
def column_names(self) -> List[String]
```

Returns an ordered list of column names.

### `column_index`

```mojo
def column_index(self, name: String) raises -> Int
```

Returns the zero-based index of a column. Raises `Error` if the column name does not exist.

---

## Column Access

Columns can be retrieved by name or index. Both methods return a zero-copy `Series` view over the Arrow buffers.

### `column`

```mojo
def column(self, name: String) raises -> Series
def column(self, idx: Int) raises -> Series
```

### Subscript Operator (`__getitem__`)

```mojo
def __getitem__(self, name: String) raises -> Series
def __getitem__(self, idx: Int) raises -> Series
```

```mojo
var by_name = df["price"]
var by_idx = df[0]
```

---

## Display & Terminal Output

`DataFrame` implements Mojo's `Writable` trait. Calling `print(df)` outputs the shape, column names, Arrow data types, and a preview of up to 5 rows:

```
shape: (5, 4)
id | name | score | count
i64 | str | f64 | i64
---+---+---+---
1 | Alice | 95.5 | 10
2 | Bob | 82.0 | 20
3 | Charlie | 88.5 | 30
4 | David | 79.0 | 40
5 | Eve | 90.5 | 50
```
