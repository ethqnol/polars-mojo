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
    var offset: Int
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
- `offset`: Slice offset into the underlying Arrow buffer (0 for un-sliced series).
- `null_count`: Number of nulls in the column.
- `n_buffers`: Number of backing Arrow buffers.
- `buffers`: Array of pointers to data, offset, and validity bitmap buffers.

---

## Buffer Pointer Access

For maximum performance, you can retrieve a typed pointer to the contiguous memory buffer. This accounts for any slice offset and enables custom loops, GPU transfers, or low-level SIMD operations without overhead.

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

### Generic Numeric Getter

```mojo
def get_float(self, idx: Int) raises -> Float64
```

Convenience getter converting any numeric column element (`Float64`, `Float32`, `Int64`, `Int32`) to `Float64`.

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

## Dynamic Dispatch Reductions

`Series` provides ergonomic reduction methods that dynamically inspect the column format and execute optimized SIMD kernels:

```mojo
def sum(self) raises -> Float64
def mean(self) raises -> Float64
def min(self) raises -> Float64
def max(self) raises -> Float64
def var(self, ddof: Int = 1) raises -> Float64
def std(self, ddof: Int = 1) raises -> Float64
```

### Example

```mojo
var price = df["price"]
print("Sum:", price.sum())
print("Mean:", price.mean())
print("Min:", price.min())
print("Max:", price.max())
print("Std Dev:", price.std())
```

---

## Type-Specific SIMD Reductions

When the exact data type is known at compile time, type-specific reductions avoid dynamic format checking and execute SIMD loops directly via `std.algorithm.vectorize` and `unsafe_load`:

### 64-bit Numeric Reductions

```mojo
def sum_float64(self) raises -> Float64
def sum_int64(self) raises -> Int64
def mean_float64(self) raises -> Float64
def mean_int64(self) raises -> Float64
def min_float64(self) raises -> Float64
def min_int64(self) raises -> Int64
def max_float64(self) raises -> Float64
def max_int64(self) raises -> Int64
def var_float64(self, ddof: Int = 1) raises -> Float64
def std_float64(self, ddof: Int = 1) raises -> Float64
```

### 32-bit Numeric Reductions

```mojo
def sum_float32(self) raises -> Float32
def sum_int32(self) raises -> Int32
def mean_float32(self) raises -> Float32
def mean_int32(self) raises -> Float64
def min_float32(self) raises -> Float32
def min_int32(self) raises -> Int32
def max_float32(self) raises -> Float32
def max_int32(self) raises -> Int32
```

---

## Vectorized Arithmetic & Broadcasting

`Series` overloads standard arithmetic operators (`+`, `-`, `*`, `/`) to perform element-wise calculations powered by SIMD vectorization:

### Series-Series Operations

```mojo
def __add__(self, other: Series) raises -> List[Float64]
def __sub__(self, other: Series) raises -> List[Float64]
def __mul__(self, other: Series) raises -> List[Float64]
def __truediv__(self, other: Series) raises -> List[Float64]
```

### Scalar Broadcasting

```mojo
def __add__(self, scalar: Float64) raises -> List[Float64]
def __radd__(self, scalar: Float64) raises -> List[Float64]
def __sub__(self, scalar: Float64) raises -> List[Float64]
def __mul__(self, scalar: Float64) raises -> List[Float64]
def __rmul__(self, scalar: Float64) raises -> List[Float64]
def __truediv__(self, scalar: Float64) raises -> List[Float64]
```

### Example

```mojo
var a = df["col_a"]
var b = df["col_b"]

# Series + Series
var added = a + b

# Scalar multiplication broadcasting
var scaled = a * 10.0

# Complex expression
var normalized = (a - 5.0) / 2.0
```

---

## Element-Wise Functions (`apply`)

`Series` provides `.apply()` methods allowing you to execute arbitrary pure-Mojo closures or user-defined functions (UDFs) over Arrow data with **zero FFI overhead**:

### Methods

```mojo
def apply_float64[Func: def(Float64) raises -> Float64](self, func: Func) raises -> List[Float64]
def apply_int64[Func: def(Int64) raises -> Int64](self, func: Func) raises -> List[Int64]
def apply[Func: def(Float64) raises -> Float64](self, func: Func) raises -> List[Float64]
```

### Features
- **Zero FFI Cost**: Evaluates directly across contiguous native Arrow memory buffers.
- **Unified Closures**: Supports stateful captures (`{imm x}`, `{var y}`), raising and non-raising functions.
- **Dynamic Dispatch**: `.apply()` dynamically converts any numeric column elements to `Float64`.

### Example

```mojo
var price = df["price"]

# 1. Custom mathematical function
def square_fn(x: Float64) -> Float64:
    return x * x

var squared = price.apply_float64(square_fn)

# 2. Stateful closure capturing variables
var multiplier = 1.15
def vat_fn(x: Float64) raises {imm multiplier} -> Float64:
    return x * multiplier

var taxed = price.apply(vat_fn)
```
