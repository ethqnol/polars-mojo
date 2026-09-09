# Apache Arrow C Data Interface

`molars` transfers tabular data between Rust and Mojo using the official [Apache Arrow C Data Interface](https://arrow.apache.org/docs/format/CDataInterface.html).

```mojo
from molars.arrow_abi import ArrowArray, ArrowSchema, ManagedArrowTable
```

## Architecture

The C Data Interface uses standard, C-compatible structs (`ArrowArray` and `ArrowSchema`) to pass columnar data across language boundaries without copying memory or serializing through disk/IPC.

```
┌─────────────────────────────────┐
│     Rust (polars_arrow::ffi)    │
│  - Allocates column data arrays │
│  - Exports to Arrow C structs   │
└────────────────┬────────────────┘
                 │ raw pointers
                 ▼
┌─────────────────────────────────┐
│       Mojo (ManagedArrowTable)  │
│  - Inspects buffers and schemas │
│  - Owns pointer lifecycle (RAII)│
│  - Invokes release callback     │
└─────────────────────────────────┘
```

---

## Memory Ownership & Lifecycle

1. **Allocation**:
   Rust reads files, builds a Polars `DataFrame`, and packs it into an Arrow `StructArray`. The underlying buffers are allocated on Rust's heap.
2. **Export**:
   `ffi::export_array_to_c` and `ffi::export_field_to_c` write the memory addresses into caller-supplied `ArrowArray` and `ArrowSchema` pointer blocks.
3. **Mojo Management**:
   Mojo wraps these pointers in `ManagedArrowTable`.
4. **Deallocation (RAII)**:
   When `ManagedArrowTable` is destroyed (`__deinit__`), Mojo calls the `release` callbacks on the C structs:
   ```mojo
   def __deinit__(deinit self):
       if self.is_active:
           _ = external_call["molars_release_array", NoneType](self.array_ptr)
           _ = external_call["molars_release_schema", NoneType](self.schema_ptr)
           self.array_ptr.unsafe_free()
           self.schema_ptr.unsafe_free()
   ```
   The release callback calls into Rust, which drops the underlying `Box<dyn Array>` and returns memory to the OS allocator.

---

## Arrow Format Codes

The `ArrowSchema.format` string identifies the data type:

| Code | Format | C Type | Mojo Type |
|------|--------|--------|-----------|
| `g` | Float64 | `double` | `Float64` |
| `f` | Float32 | `float` | `Float32` |
| `l` | Int64 | `int64_t` | `Int64` |
| `i` | Int32 | `int32_t` | `Int32` |
| `u` | Utf8 | `uint8_t*` (32-bit offsets) | `String` |
| `U` | LargeUtf8 | `uint8_t*` (64-bit offsets) | `String` |
| `vu` | Utf8View (StringView) | `16-byte descriptors` + variadic buffers | `String` |
| `+s` | Struct | Nested child arrays | Root table |

---

## Struct Definitions

### `ArrowSchema`

```mojo
@fieldwise_init
struct ArrowSchema(Copyable, ImplicitlyCopyable, Movable):
    var format: Pointer[c_char, MutUntrackedOrigin]
    var name: Pointer[c_char, MutUntrackedOrigin]
    var metadata: Pointer[c_char, MutUntrackedOrigin]
    var flags: Int64
    var n_children: Int64
    var children: Pointer[Pointer[ArrowSchema, MutUntrackedOrigin], MutUntrackedOrigin]
    var dictionary: Pointer[ArrowSchema, MutUntrackedOrigin]
    var release: Pointer[NoneType, MutUntrackedOrigin]
    var private_data: Pointer[NoneType, MutUntrackedOrigin]
```

#### Helper Methods

- `def is_released(self) -> Bool`: Returns `True` if the release callback pointer is null.
- `def format_str(self) -> String`: Converts the C format string pointer into a native Mojo `String`.
- `def name_str(self) -> String`: Converts the C field name pointer into a native Mojo `String`.

---

### `ArrowArray`

```mojo
@fieldwise_init
struct ArrowArray(Copyable, ImplicitlyCopyable, Movable):
    var length: Int64
    var null_count: Int64
    var offset: Int64
    var n_buffers: Int64
    var n_children: Int64
    var buffers: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin]
    var children: Pointer[Pointer[ArrowArray, MutUntrackedOrigin], MutUntrackedOrigin]
    var dictionary: Pointer[ArrowArray, MutUntrackedOrigin]
    var release: Pointer[NoneType, MutUntrackedOrigin]
    var private_data: Pointer[NoneType, MutUntrackedOrigin]
```

#### Helper Methods

- `def is_released(self) -> Bool`: Returns `True` if the release callback pointer is null.

---

### `ManagedArrowTable`

```mojo
struct ManagedArrowTable(Movable):
    var array_ptr: Pointer[ArrowArray, MutUntrackedOrigin]
    var schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin]
    var is_active: Bool
```

RAII manager that guarantees release callbacks are executed and heap pointer allocations are safely freed when the table goes out of scope.

#### Methods

- `def __init__(out self, array_ptr: Pointer[ArrowArray, MutUntrackedOrigin], schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin])`: Takes ownership of heap-allocated root Arrow structs.
- `def num_rows(self) -> Int`: Retrieves row count from the root Arrow array.
- `def num_cols(self) -> Int`: Retrieves column count (`n_children`) from the root Arrow array.
- `def array(self) -> ArrowArray`: Returns a copy of the root `ArrowArray`.
- `def schema(self) -> ArrowSchema`: Returns a copy of the root `ArrowSchema`.
- `def get_column_array(self, col_idx: Int) raises -> ArrowArray`: Extracts child array at `col_idx`.
- `def get_column_schema(self, col_idx: Int) raises -> ArrowSchema`: Extracts child schema at `col_idx`.
- `def get_column_name(self, col_idx: Int) raises -> String`: Resolves column name string from child schema.
- `def get_column_format(self, col_idx: Int) raises -> String`: Resolves Arrow format code string from child schema.

