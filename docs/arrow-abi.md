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
struct ArrowSchema(ImplicitlyCopyable, Copyable, Movable):
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

### `ArrowArray`

```mojo
@fieldwise_init
struct ArrowArray(ImplicitlyCopyable, Copyable, Movable):
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
