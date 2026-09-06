# API Reference (Auto-Generated)

*Generated from source docstrings via `mojo doc`.*

## Module `molars.arrow_abi`

### `struct ArrowArray`

**Implemented Traits**: `AnyType, Copyable, Deinitable, ImplicitlyCopyable, Movable`

C ABI layout for a data array in the Apache Arrow C Data Interface.

Traits:
    ImplicitlyCopyable: Can be copied implicitly by value.
    Copyable: Supports explicit copying.
    Movable: Supports move semantics.

Fields:
    length: Number of rows/elements in the array.
    null_count: Number of null values, or -1 if unknown.
    offset: Logical start offset within the buffers.
    n_buffers: Number of memory buffer pointers in buffers array.
    n_children: Number of child arrays (for struct/nested arrays).
    buffers: Array of raw pointers to data and validity bitmap buffers.
    children: Array of pointers to child ArrowArray structs.
    dictionary: Pointer to dictionary encoding array, or null.
    release: Function pointer to release callback for this array.
    private_data: Pointer to implementation-specific private data.

#### Methods

##### `def is_released(self) -> Bool`

Returns True if the release callback has been cleared to null.

**Returns:** `Bool`

---

### `struct ArrowSchema`

**Implemented Traits**: `AnyType, Copyable, Deinitable, ImplicitlyCopyable, Movable`

C ABI layout for schema metadata in the Apache Arrow C Data Interface.

Traits:
    ImplicitlyCopyable: Can be copied implicitly by value.
    Copyable: Supports explicit copying.
    Movable: Supports move semantics.

Fields:
    format: Format descriptor string pointer (e.g. 'g', 'l', 'vu').
    name: Column or field name pointer.
    metadata: Optional metadata string pointer.
    flags: Bit flags representing schema properties (e.g. dictionary ordered).
    n_children: Number of child schemas (for nested or struct schemas).
    children: Array of pointers to child ArrowSchema structs.
    dictionary: Pointer to dictionary encoding schema, or null.
    release: Function pointer to release callback for this schema.
    private_data: Pointer to implementation-specific private data.

#### Methods

##### `def is_released(self) -> Bool`

Returns True if the release callback has been cleared to null.

**Returns:** `Bool`

---

##### `def format_str(self) -> String`

Converts the format pointer into a Mojo String.

**Returns:** `String`

---

##### `def name_str(self) -> String`

Converts the name pointer into a Mojo String.

**Returns:** `String`

---

### `struct ManagedArrowTable`

**Implemented Traits**: `AnyType, Deinitable, Movable`

RAII memory manager for heap-allocated ArrowArray and ArrowSchema pointers.

Invokes the Arrow C release callbacks and frees pointer allocations
when the instance goes out of scope.

Traits:
    Movable: Supports move semantics to transfer ownership.

Fields:
    array_ptr: Pointer to heap-allocated root ArrowArray struct.
    schema_ptr: Pointer to heap-allocated root ArrowSchema struct.
    is_active: Flag indicating whether this instance owns active allocations.

#### Methods

##### `def __init__(out self, array_ptr: Pointer[ArrowArray, MutUntrackedOrigin], schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin])`

Initializes manager with active pointer ownership.

**Arguments:**

- `array_ptr` (`Pointer[ArrowArray, MutUntrackedOrigin]`): Pointer to allocated ArrowArray.
- `schema_ptr` (`Pointer[ArrowSchema, MutUntrackedOrigin]`): Pointer to allocated ArrowSchema.

**Returns:** `Self`

---

##### `def __init__(out self, *, deinit move: Self)`

Move constructor transferring ownership.

**Arguments:**

- `move` (`Self`): Source ManagedArrowTable being moved from.

**Returns:** `Self`

---

##### `def __deinit__(deinit self)`

Releases Arrow resources via FFI callbacks and deallocates pointers.

---

##### `def array(self) -> ArrowArray`

Returns a copy of the root ArrowArray struct.

**Returns:** `ArrowArray`

---

##### `def schema(self) -> ArrowSchema`

Returns a copy of the root ArrowSchema struct.

**Returns:** `ArrowSchema`

---

##### `def num_rows(self) -> Int`

Returns the row count from the root ArrowArray.

**Returns:** `Int`

---

##### `def num_cols(self) -> Int`

Returns the column count from the root ArrowArray.

**Returns:** `Int`

---

##### `def get_column_array(self, col_idx: Int) -> ArrowArray`

Extracts the child ArrowArray for the specified column index.

**Arguments:**

- `col_idx` (`Int`): Zero-based column index.

**Returns:** `ArrowArray` - Child ArrowArray for the column.

**Raises:** Error: If col_idx is out of range.

---

##### `def get_column_schema(self, col_idx: Int) -> ArrowSchema`

Extracts the child ArrowSchema for the specified column index.

**Arguments:**

- `col_idx` (`Int`): Zero-based column index.

**Returns:** `ArrowSchema` - Child ArrowSchema for the column.

**Raises:** Error: If col_idx is out of range.

---

##### `def get_column_name(self, col_idx: Int) -> String`

Retrieves the name of the column at col_idx.

**Arguments:**

- `col_idx` (`Int`): Zero-based column index.

**Returns:** `String` - Column name string.

**Raises:** Error: If col_idx is out of range.

---

##### `def get_column_format(self, col_idx: Int) -> String`

Retrieves the Arrow format code of the column at col_idx.

**Arguments:**

- `col_idx` (`Int`): Zero-based column index.

**Returns:** `String` - Arrow format code (e.g. 'g', 'l', 'vu').

**Raises:** Error: If col_idx is out of range.

---

## Module `molars.bridge`

### `struct MolarsBridge`

**Implemented Traits**: `AnyType, Deinitable, Movable`

#### Methods

##### `def read_csv(path: String, array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `path` (`String`)
- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def read_parquet(path: String, array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `path` (`String`)
- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def sql_query(query: String, table_name: String, file_path: String, array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `query` (`String`)
- `table_name` (`String`)
- `file_path` (`String`)
- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def write_csv(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], path: String) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `path` (`String`)

**Returns:** `Int32`

---

##### `def write_parquet(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], path: String) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `path` (`String`)

**Returns:** `Int32`

---

##### `def slice_df(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], offset: Int64, length: Int, out_array: Pointer[ArrowArray, MutUntrackedOrigin], out_schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `offset` (`Int64`)
- `length` (`Int`)
- `out_array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `out_schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def select_columns(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], col_names_csv: String, out_array: Pointer[ArrowArray, MutUntrackedOrigin], out_schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `col_names_csv` (`String`)
- `out_array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `out_schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def drop_columns(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], col_names_csv: String, out_array: Pointer[ArrowArray, MutUntrackedOrigin], out_schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `col_names_csv` (`String`)
- `out_array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `out_schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def rename_column(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], old_name: String, new_name: String, out_array: Pointer[ArrowArray, MutUntrackedOrigin], out_schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `old_name` (`String`)
- `new_name` (`String`)
- `out_array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `out_schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def groupby_agg(array: Pointer[ArrowArray, MutUntrackedOrigin], schema: Pointer[ArrowSchema, MutUntrackedOrigin], keys_csv: String, aggs_csv: String, out_array: Pointer[ArrowArray, MutUntrackedOrigin], out_schema: Pointer[ArrowSchema, MutUntrackedOrigin]) -> Int32`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)
- `keys_csv` (`String`)
- `aggs_csv` (`String`)
- `out_array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)
- `out_schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

**Returns:** `Int32`

---

##### `def release_array(array: Pointer[ArrowArray, MutUntrackedOrigin])`

**Arguments:**

- `array` (`Pointer[ArrowArray, MutUntrackedOrigin]`)

---

##### `def release_schema(schema: Pointer[ArrowSchema, MutUntrackedOrigin])`

**Arguments:**

- `schema` (`Pointer[ArrowSchema, MutUntrackedOrigin]`)

---

##### `def get_last_error() -> String`

**Returns:** `String`

---

## Module `molars.dataframe`

### `struct DataFrame`

**Implemented Traits**: `AnyType, Deinitable, Movable, Writable`

An in-memory columnar table backed by an Apache Arrow StructArray.

Traits:
    Movable: Supports move lifecycle semantics.
    Writable: Implements terminal pretty-printing via write_to.

Fields:
    _table: RAII manager for underlying ArrowArray and ArrowSchema pointers.
    _col_names: Ordered list of column names.
    _col_formats: Ordered list of Arrow format type codes for each column.

#### Methods

##### `def __init__(out self, *, deinit move: Self)`

**Arguments:**

- `move` (`Self`)

**Returns:** `Self`

---

##### `def __init__(out self, var table: ManagedArrowTable)`

**Arguments:**

- `table` (`ManagedArrowTable`)

**Returns:** `Self`

---

##### `def __getitem__(self, name: String) -> Series`

Subscript indexing operator to retrieve a column by name.

**Arguments:**

- `name` (`String`): Column name.

**Returns:** `Series` - Series view over the column's Arrow buffers.

**Raises:** Error: If the column name does not exist.

---

##### `def __getitem__(self, idx: Int) -> Series`

Subscript indexing operator to retrieve a column by index.

**Arguments:**

- `idx` (`Int`): Zero-based column index.

**Returns:** `Series` - Series view over the column's Arrow buffers.

**Raises:** Error: If index is out of bounds.

---

##### `def read_csv(path: String) -> Self`

Reads a CSV file into a DataFrame using the Polars multithreaded reader.

**Arguments:**

- `path` (`String`): Filesystem path to the CSV file.

**Returns:** `Self` - DataFrame populated with columns exported via the Arrow C Data Interface.

**Raises:** Error: If the file path is invalid, parsing fails, or allocation fails.

---

##### `def read_parquet(path: String) -> Self`

Reads an Apache Parquet file into a DataFrame using the Polars reader.

**Arguments:**

- `path` (`String`): Filesystem path to the Parquet file.

**Returns:** `Self` - DataFrame populated with columns exported via the Arrow C Data Interface.

**Raises:** Error: If the file cannot be opened, metadata is corrupted, or parsing fails.

---

##### `def sql(query: String, table_name: String, file_path: String) -> Self`

Executes a SQL query against a dataset using the Polars SQLContext engine.

Registers the dataset as a LazyFrame, applies query optimizations, and
collects the result into an Arrow table.

**Arguments:**

- `query` (`String`): SQL query string (e.g. "SELECT col_a, AVG(col_b) FROM tbl GROUP BY col_a").
- `table_name` (`String`): Table identifier to reference in the FROM clause.
- `file_path` (`String`): Filesystem path to the source CSV or Parquet file.

**Returns:** `Self` - DataFrame containing query results.

**Raises:** Error: On invalid SQL syntax, plan execution error, or read failure.

---

##### `def num_rows(self) -> Int`

Returns the number of rows in the table.

**Returns:** `Int` - Total row count as an Int.

---

##### `def height(self) -> Int`

Returns the number of rows in the table.

**Returns:** `Int` - Total row count as an Int.

---

##### `def num_cols(self) -> Int`

Returns the number of columns in the table.

**Returns:** `Int` - Total column count as an Int.

---

##### `def width(self) -> Int`

Returns the number of columns in the table.

**Returns:** `Int` - Total column count as an Int.

---

##### `def shape(self) -> Tuple[Int, Int]`

Returns table dimensions as a (height, width) tuple.

**Returns:** `Tuple[Int, Int]` - Tuple containing (num_rows, num_cols).

---

##### `def column_names(self) -> List[String]`

Returns the ordered list of column names in the table.

**Returns:** `List[String]` - List of column name strings.

---

##### `def column_index(self, name: String) -> Int`

Finds the zero-based column index for a given column name.

**Arguments:**

- `name` (`String`): Column name to search for.

**Returns:** `Int` - Zero-based integer column index.

**Raises:** Error: If no column matches the provided name.

---

##### `def column(self, name: String) -> Series`

Extracts a column Series by name with zero memory copies.

**Arguments:**

- `name` (`String`): Column name to look up.

**Returns:** `Series` - Series view over the column's Arrow buffers.

**Raises:** Error: If the column name is not found.

---

##### `def column(self, idx: Int) -> Series`

Extracts a column Series by index with zero memory copies.

**Arguments:**

- `idx` (`Int`): Zero-based column index.

**Returns:** `Series` - Series view over the column's Arrow buffers.

**Raises:** Error: If the index is out of range [0, num_cols - 1].

---

##### `def write_csv(self, path: String)`

Writes the DataFrame to a CSV file.

**Arguments:**

- `path` (`String`): Target filesystem path for the CSV output.

**Raises:** Error: If writing to the file fails.

---

##### `def write_parquet(self, path: String)`

Writes the DataFrame to an Apache Parquet file.

**Arguments:**

- `path` (`String`): Target filesystem path for the Parquet output.

**Raises:** Error: If writing to the file fails.

---

##### `def head(self, n: Int = Int(5)) -> Self`

Returns the first n rows of the DataFrame.

**Arguments:**

- `n` (`Int`): Number of rows to return (default 5).

**Returns:** `Self` - A new DataFrame containing the sliced rows.

---

##### `def tail(self, n: Int = Int(5)) -> Self`

Returns the last n rows of the DataFrame.

**Arguments:**

- `n` (`Int`): Number of rows to return (default 5).

**Returns:** `Self` - A new DataFrame containing the sliced rows.

---

##### `def select(self, columns: List[String]) -> Self`

Projects a subset of columns from the DataFrame.

**Arguments:**

- `columns` (`List[String]`): List of column names to select.

**Returns:** `Self` - A new DataFrame containing only the selected columns.

---

##### `def drop(self, columns: List[String]) -> Self`

Returns a DataFrame without the specified columns.

**Arguments:**

- `columns` (`List[String]`): List of column names to exclude.

**Returns:** `Self` - A new DataFrame without the specified columns.

---

##### `def rename(self, old_name: String, new_name: String) -> Self`

Renames a column in the DataFrame.

**Arguments:**

- `old_name` (`String`): Existing column name.
- `new_name` (`String`): New column name.

**Returns:** `Self` - A new DataFrame with the column renamed.

---

##### `def group_by(self, keys: List[String]) -> GroupBy`

Groups the DataFrame by the specified column names.

**Arguments:**

- `keys` (`List[String]`): List of column names to group by.

**Returns:** `GroupBy` - A GroupBy object to perform aggregations.

---

##### `def group_by(self, key: String) -> GroupBy`

Groups the DataFrame by a single column name or comma-separated column names.

**Arguments:**

- `key` (`String`): Column name or comma-separated column names to group by.

**Returns:** `GroupBy` - A GroupBy object to perform aggregations.

---

##### `def group_by(self, keys: String, aggs: String) -> Self`

Directly groups and aggregates the DataFrame.

**Arguments:**

- `keys` (`String`): Grouping column names (comma-separated).
- `aggs` (`String`): Aggregation specifications (comma-separated, e.g. 'sales:sum,rating:mean').

**Returns:** `Self` - An aggregated DataFrame.

---

##### `def groupby(self, keys: List[String]) -> GroupBy`

Alias for group_by.

**Arguments:**

- `keys` (`List[String]`)

**Returns:** `GroupBy`

---

##### `def groupby(self, key: String) -> GroupBy`

Alias for group_by.

**Arguments:**

- `key` (`String`)

**Returns:** `GroupBy`

---

##### `def groupby(self, keys: String, aggs: String) -> Self`

Alias for group_by.

**Arguments:**

- `keys` (`String`)
- `aggs` (`String`)

**Returns:** `Self`

---

##### `def write_to(self, mut writer: T)`

Formats the DataFrame as an aligned ASCII preview table for terminal output.

**Arguments:**

- `writer` (`T`): Output stream receiving formatted characters.

---

### `struct GroupBy`

**Implemented Traits**: `AnyType, Copyable, Deinitable, Movable`

An intermediate groupby grouping object.

Allows executing aggregations over grouped columns using Polars' multithreaded engine.

#### Methods

##### `def agg(self, aggs_csv: String) -> DataFrame`

Applies aggregations to the grouped DataFrame.

**Arguments:**

- `aggs_csv` (`String`): Comma-separated list of aggregations in 'col:op' or 'col:op:alias' format.
         Supported operations: 'sum', 'mean', 'avg', 'min', 'max', 'count', 'std', 'var', 'first', 'last'.

**Returns:** `DataFrame` - An aggregated DataFrame.

---

##### `def sum(self, cols_csv: String) -> DataFrame`

Computes sum for specified columns in the group.

**Arguments:**

- `cols_csv` (`String`)

**Returns:** `DataFrame`

---

##### `def mean(self, cols_csv: String) -> DataFrame`

Computes mean for specified columns in the group.

**Arguments:**

- `cols_csv` (`String`)

**Returns:** `DataFrame`

---

##### `def count(self) -> DataFrame`

Counts rows per group using the first key column.

**Returns:** `DataFrame`

---

### `struct Series`

**Implemented Traits**: `AnyType, Copyable, Deinitable, Movable`

A zero-copy typed view over a single Apache Arrow array.

Provides direct buffer pointer access and hardware-accelerated SIMD
reductions over numeric and string Arrow columns.

Traits:
    Copyable: Supports deep copying of Series metadata.
    Movable: Supports move semantics.

Fields:
    name: Name of the column.
    format: Arrow format string descriptor (e.g. 'g' for f64, 'l' for i64, 'vu' for StringView).
    length: Number of rows in the series.
    null_count: Number of null values in the column.
    n_buffers: Number of backing memory buffers.
    buffers: Pointer array to underlying Arrow buffers.

#### Methods

##### `def __add__(self, other: Self) -> List[Float64]`

Element-wise addition with another Series.

**Arguments:**

- `other` (`Self`)

**Returns:** `List[Float64]`

---

##### `def __add__(self, scalar: Float64) -> List[Float64]`

Scalar addition broadcasting across the Series.

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def __sub__(self, other: Self) -> List[Float64]`

Element-wise subtraction with another Series.

**Arguments:**

- `other` (`Self`)

**Returns:** `List[Float64]`

---

##### `def __sub__(self, scalar: Float64) -> List[Float64]`

Scalar subtraction broadcasting across the Series.

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def __mul__(self, other: Self) -> List[Float64]`

Element-wise multiplication with another Series.

**Arguments:**

- `other` (`Self`)

**Returns:** `List[Float64]`

---

##### `def __mul__(self, scalar: Float64) -> List[Float64]`

Scalar multiplication broadcasting across the Series.

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def __truediv__(self, other: Self) -> List[Float64]`

Element-wise division with another Series.

**Arguments:**

- `other` (`Self`)

**Returns:** `List[Float64]`

---

##### `def __truediv__(self, scalar: Float64) -> List[Float64]`

Scalar division broadcasting across the Series.

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def __radd__(self, scalar: Float64) -> List[Float64]`

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def __rmul__(self, scalar: Float64) -> List[Float64]`

**Arguments:**

- `scalar` (`Float64`)

**Returns:** `List[Float64]`

---

##### `def len(self) -> Int`

Returns the number of elements in the series.

**Returns:** `Int` - Row count as an Int.

---

##### `def as_float64_ptr(self) -> Pointer[Float64, MutUntrackedOrigin]`

Returns a typed pointer to the underlying Float64 buffer.

**Returns:** `Pointer[Float64, MutUntrackedOrigin]` - Pointer to contiguous 64-bit float array.

**Raises:** Error: If the series format is not 'g' (Float64).

---

##### `def as_float32_ptr(self) -> Pointer[Float32, MutUntrackedOrigin]`

Returns a typed pointer to the underlying Float32 buffer.

**Returns:** `Pointer[Float32, MutUntrackedOrigin]` - Pointer to contiguous 32-bit float array.

**Raises:** Error: If the series format is not 'f' (Float32).

---

##### `def as_int64_ptr(self) -> Pointer[Int64, MutUntrackedOrigin]`

Returns a typed pointer to the underlying Int64 buffer.

**Returns:** `Pointer[Int64, MutUntrackedOrigin]` - Pointer to contiguous 64-bit signed integer array.

**Raises:** Error: If the series format is not 'l' (Int64).

---

##### `def as_int32_ptr(self) -> Pointer[Int32, MutUntrackedOrigin]`

Returns a typed pointer to the underlying Int32 buffer.

**Returns:** `Pointer[Int32, MutUntrackedOrigin]` - Pointer to contiguous 32-bit signed integer array.

**Raises:** Error: If the series format is not 'i' (Int32).

---

##### `def get_float64(self, idx: Int) -> Float64`

Returns the Float64 scalar at the specified row index.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `Float64` - Float64 value at index.

**Raises:** Error: If the series is not Float64 or index is invalid.

---

##### `def get_float32(self, idx: Int) -> Float32`

Returns the Float32 scalar at the specified row index.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `Float32` - Float32 value at index.

**Raises:** Error: If the series is not Float32 or index is invalid.

---

##### `def get_int64(self, idx: Int) -> Int64`

Returns the Int64 scalar at the specified row index.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `Int64` - Int64 value at index.

**Raises:** Error: If the series is not Int64 or index is invalid.

---

##### `def get_int32(self, idx: Int) -> Int32`

Returns the Int32 scalar at the specified row index.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `Int32` - Int32 value at index.

**Raises:** Error: If the series is not Int32 or index is invalid.

---

##### `def get_string(self, idx: Int) -> String`

Returns the string at the specified row index.

Supports Utf8 ('u'), LargeUtf8 ('U'), and Arrow StringView ('vu').

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `String` - Decoded UTF-8 string.

**Raises:** Error: If the series is not a string column format.

---

##### `def get_as_string(self, idx: Int) -> String`

Formats the value at index as a string across all supported data types.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `String` - String representation of the element.

---

##### `def sum_float64(self) -> Float64`

Computes the sum of all elements using SIMD vector loads.

**Returns:** `Float64` - Total sum as Float64.

**Raises:** Error: If the series format is not Float64 ('g').

---

##### `def sum_int64(self) -> Int64`

Computes the sum of all elements using SIMD vector loads.

**Returns:** `Int64` - Total sum as Int64.

**Raises:** Error: If the series format is not Int64 ('l').

---

##### `def mean_float64(self) -> Float64`

Computes the arithmetic mean of the series.

**Returns:** `Float64` - Arithmetic mean as Float64, or 0.0 if empty.

**Raises:** Error: If the series format is not Float64 ('g').

---

##### `def mean_int64(self) -> Float64`

Computes the arithmetic mean of the series.

**Returns:** `Float64` - Arithmetic mean as Float64, or 0.0 if empty.

**Raises:** Error: If the series format is not Int64 ('l').

---

##### `def get_float(self, idx: Int) -> Float64`

Returns the element at idx as a Float64 scalar.

**Arguments:**

- `idx` (`Int`): Zero-based row index.

**Returns:** `Float64` - Float64 scalar.

**Raises:** Error: If the format is not convertible to Float64.

---

##### `def sum_float32(self) -> Float32`

Computes the sum of all elements using SIMD vector loads for Float32.

**Returns:** `Float32`

---

##### `def sum_int32(self) -> Int32`

Computes the sum of all elements using SIMD vector loads for Int32.

**Returns:** `Int32`

---

##### `def mean_float32(self) -> Float32`

Computes the arithmetic mean for Float32 series.

**Returns:** `Float32`

---

##### `def mean_int32(self) -> Float64`

Computes the arithmetic mean for Int32 series.

**Returns:** `Float64`

---

##### `def min_float64(self) -> Float64`

Computes the minimum value in the Series using SIMD.

**Returns:** `Float64`

---

##### `def max_float64(self) -> Float64`

Computes the maximum value in the Series using SIMD.

**Returns:** `Float64`

---

##### `def min_int64(self) -> Int64`

Computes the minimum value in the Series using SIMD.

**Returns:** `Int64`

---

##### `def max_int64(self) -> Int64`

Computes the maximum value in the Series using SIMD.

**Returns:** `Int64`

---

##### `def min_float32(self) -> Float32`

Computes the minimum value in the Float32 Series using SIMD.

**Returns:** `Float32`

---

##### `def max_float32(self) -> Float32`

Computes the maximum value in the Float32 Series using SIMD.

**Returns:** `Float32`

---

##### `def min_int32(self) -> Int32`

Computes the minimum value in the Int32 Series using SIMD.

**Returns:** `Int32`

---

##### `def max_int32(self) -> Int32`

Computes the maximum value in the Int32 Series using SIMD.

**Returns:** `Int32`

---

##### `def var_float64(self, ddof: Int = Int(1)) -> Float64`

Computes sample variance of the Float64 Series using SIMD.

**Arguments:**

- `ddof` (`Int`)

**Returns:** `Float64`

---

##### `def std_float64(self, ddof: Int = Int(1)) -> Float64`

Computes standard deviation of the Float64 Series using SIMD.

**Arguments:**

- `ddof` (`Int`)

**Returns:** `Float64`

---

##### `def sum(self) -> Float64`

Dynamically computes the sum across any numeric Series type.

**Returns:** `Float64`

---

##### `def mean(self) -> Float64`

Dynamically computes the mean across any numeric Series type.

**Returns:** `Float64`

---

##### `def min(self) -> Float64`

Dynamically computes the min across any numeric Series type.

**Returns:** `Float64`

---

##### `def max(self) -> Float64`

Dynamically computes the max across any numeric Series type.

**Returns:** `Float64`

---

##### `def var(self, ddof: Int = Int(1)) -> Float64`

Dynamically computes variance across Float64 series.

**Arguments:**

- `ddof` (`Int`)

**Returns:** `Float64`

---

##### `def std(self, ddof: Int = Int(1)) -> Float64`

Dynamically computes standard deviation across Float64 series.

**Arguments:**

- `ddof` (`Int`)

**Returns:** `Float64`

---

##### `def apply_float64[Func: def(Float64) raises -> Float64](self, func: Func) -> List[Float64]`

Applies a function or closure element-wise over the Float64 Series.

**Arguments:**

- `func` (`Func`): A function or closure mapping Float64 -> Float64 (can raise).

**Returns:** `List[Float64]` - A List[Float64] containing the transformed values.

---

##### `def apply_int64[Func: def(Int64) raises -> Int64](self, func: Func) -> List[Int64]`

Applies a function or closure element-wise over the Int64 Series.

**Arguments:**

- `func` (`Func`): A function or closure mapping Int64 -> Int64 (can raise).

**Returns:** `List[Int64]` - A List[Int64] containing the transformed values.

---

##### `def apply[Func: def(Float64) raises -> Float64](self, func: Func) -> List[Float64]`

Dynamically applies a function or closure element-wise over numeric column values.

Converts non-Float64 numeric types to Float64 dynamically.

**Arguments:**

- `func` (`Func`): A function or closure mapping Float64 -> Float64 (can raise).

**Returns:** `List[Float64]` - A List[Float64] containing the transformed values.

---
