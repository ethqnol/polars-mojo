# Series API Reference

`Series` represents a zero-copy column view over an Apache Arrow array. It provides direct memory pointer access, scalar getters, and SIMD vector aggregations.

```mojo
from molars import Series
```

## Definition

```mojo
@fieldwise_init
struct Series(Copyable, Movable):
    var name: String
    var format: String
    var length: Int
    var null_count: Int
    var n_buffers: Int
    var buffers: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin]
```

### Traits

- **`Copyable`**: Copies metadata and pointer references without cloning raw buffer memory.
- **`Movable`**: Supports move semantics.

### Fields

- `name`: Column name.
- `format`: Arrow C format string code (`"g"`, `"f"`, `"l"`, `"i"`, `"u"`, `"U"`, `"vu"`).
- `length`: Number of elements in the column.
- `null_count`: Number of nulls in the column.
- `n_buffers`: Number of backing Arrow buffers.
- `buffers`: Array of pointers to data, offset, and validity bitmap buffers.

---

## Buffer Pointer Access

For maximum performance, you can retrieve a typed pointer to the contiguous memory buffer. This enables custom loops, GPU transfers, or low-level SIMD operations without overhead.

### `as_float64_ptr`

```mojo
def as_float64_ptr(self) raises -> Pointer[Float64, MutUntrackedOrigin]
```

Returns a direct pointer to the `Float64` array. Raises `Error` if the column format is not `"g"`.

```mojo
var ptr = series.as_float64_ptr()
for i in range(series.len()):
    var val = ptr[unsafe_offset=i]
```

### `as_float32_ptr`

```mojo
def as_float32_ptr(self) raises -> Pointer[Float32, MutUntrackedOrigin]
```

Returns a direct pointer to the `Float32` array. Raises `Error` if format is not `"f"`.

### `as_int64_ptr`

```mojo
def as_int64_ptr(self) raises -> Pointer[Int64, MutUntrackedOrigin]
```

Returns a direct pointer to the `Int64` array. Raises `Error` if format is not `"l"`.

### `as_int32_ptr`

```mojo
def as_int32_ptr(self) raises -> Pointer[Int32, MutUntrackedOrigin]
```

Returns a direct pointer to the `Int32` array. Raises `Error` if format is not `"i"`.

---

## Scalar Element Access

### Numeric Getters

```mojo
def get_float64(self, idx: Int) raises -> Float64
def get_float32(self, idx: Int) raises -> Float32
def get_int64(self, idx: Int) raises -> Int64
def get_int32(self, idx: Int) raises -> Int32
```

Returns the scalar at `idx`. Raises `Error` if the column type does not match the requested type.

### String Getters

```mojo
def get_string(self, idx: Int) raises -> String
```

Extracts and decodes the string at `idx`. Supports three Arrow string layouts:
1. **Utf8 (`"u"`)**: 32-bit offsets in `buffers[1]` + raw byte data in `buffers[2]`.
2. **LargeUtf8 (`"U"`)**: 64-bit offsets in `buffers[1]` + raw byte data in `buffers[2]`.
3. **Utf8View / StringView (`"vu"`)**: 16-byte view descriptors in `buffers[1]`. Strings $\le 12$ bytes are inlined directly in the descriptor; strings $> 12$ bytes reference variadic heap buffers in `buffers[2..]`.

```mojo
def get_as_string(self, idx: Int) -> String
```

Formats any element as a `String` regardless of underlying column format (used by table formatters).

---

## SIMD Vector Reductions

`Series` implements hardware-vectorized reductions via `std.algorithm.vectorize` and `unsafe_load`:

```mojo
def sum_float64(self) raises -> Float64
def sum_int64(self) raises -> Int64
def mean_float64(self) raises -> Float64
def mean_int64(self) raises -> Float64
```

### Example

```mojo
var price_col = df["price"]
var total = price_col.sum_float64()
var average = price_col.mean_float64()
```
