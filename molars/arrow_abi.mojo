from std.ffi import c_char, CStringSlice, external_call
from std.memory import Pointer

@always_inline
def null_ptr[T: AnyType]() -> Pointer[T, MutUntrackedOrigin]:
    return Pointer[T, MutUntrackedOrigin](unsafe_from_address=Int(0))

@fieldwise_init
struct ArrowSchema(ImplicitlyCopyable, Copyable, Movable):
    """C ABI layout for schema metadata in the Apache Arrow C Data Interface.

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
    """
    var format: Pointer[c_char, MutUntrackedOrigin]
    var name: Pointer[c_char, MutUntrackedOrigin]
    var metadata: Pointer[c_char, MutUntrackedOrigin]
    var flags: Int64
    var n_children: Int64
    var children: Pointer[Pointer[ArrowSchema, MutUntrackedOrigin], MutUntrackedOrigin]
    var dictionary: Pointer[ArrowSchema, MutUntrackedOrigin]
    var release: Pointer[NoneType, MutUntrackedOrigin]
    var private_data: Pointer[NoneType, MutUntrackedOrigin]

    def is_released(self) -> Bool:
        """Returns True if the release callback has been cleared to null."""
        return Int(self.release) == 0

    def format_str(self) -> String:
        """Converts the format pointer into a Mojo String."""
        if Int(self.format) == 0:
            return ""
        return String(CStringSlice(unsafe_from_ptr=self.format))

    def name_str(self) -> String:
        """Converts the name pointer into a Mojo String."""
        if Int(self.name) == 0:
            return ""
        return String(CStringSlice(unsafe_from_ptr=self.name))

@fieldwise_init
struct ArrowArray(ImplicitlyCopyable, Copyable, Movable):
    """C ABI layout for a data array in the Apache Arrow C Data Interface.

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
    """
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

    def is_released(self) -> Bool:
        """Returns True if the release callback has been cleared to null."""
        return Int(self.release) == 0

struct ManagedArrowTable(Movable):
    """RAII memory manager for heap-allocated ArrowArray and ArrowSchema pointers.

    Invokes the Arrow C release callbacks and frees pointer allocations
    when the instance goes out of scope.

    Traits:
        Movable: Supports move semantics to transfer ownership.

    Fields:
        array_ptr: Pointer to heap-allocated root ArrowArray struct.
        schema_ptr: Pointer to heap-allocated root ArrowSchema struct.
        is_active: Flag indicating whether this instance owns active allocations.
    """
    var array_ptr: Pointer[ArrowArray, MutUntrackedOrigin]
    var schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin]
    var is_active: Bool

    def __init__(
        out self,
        array_ptr: Pointer[ArrowArray, MutUntrackedOrigin],
        schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin],
    ):
        """Initializes manager with active pointer ownership.

        Args:
            array_ptr: Pointer to allocated ArrowArray.
            schema_ptr: Pointer to allocated ArrowSchema.
        """
        self.array_ptr = array_ptr
        self.schema_ptr = schema_ptr
        self.is_active = True

    def __init__(out self, *, deinit move: Self):
        """Move constructor transferring ownership.

        Args:
            move: Source ManagedArrowTable being moved from.
        """
        self.array_ptr = move.array_ptr
        self.schema_ptr = move.schema_ptr
        self.is_active = move.is_active

    def __deinit__(deinit self):
        """Releases Arrow resources via FFI callbacks and deallocates pointers."""
        if self.is_active:
            _ = external_call["molars_release_array", NoneType](self.array_ptr)
            _ = external_call["molars_release_schema", NoneType](self.schema_ptr)
            self.array_ptr.unsafe_free()
            self.schema_ptr.unsafe_free()

    def array(self) -> ArrowArray:
        """Returns a copy of the root ArrowArray struct."""
        return self.array_ptr[]

    def schema(self) -> ArrowSchema:
        """Returns a copy of the root ArrowSchema struct."""
        return self.schema_ptr[]

    def num_rows(self) -> Int:
        """Returns the row count from the root ArrowArray."""
        return Int(self.array_ptr[].length)

    def num_cols(self) -> Int:
        """Returns the column count from the root ArrowArray."""
        return Int(self.array_ptr[].n_children)

    def get_column_array(self, col_idx: Int) raises -> ArrowArray:
        """Extracts the child ArrowArray for the specified column index.

        Args:
            col_idx: Zero-based column index.

        Returns:
            Child ArrowArray for the column.

        Raises:
            Error: If col_idx is out of range.
        """
        if col_idx < 0 or col_idx >= self.num_cols():
            raise Error("Column index out of bounds")
        return self.array_ptr[].children[unsafe_offset=col_idx][]

    def get_column_schema(self, col_idx: Int) raises -> ArrowSchema:
        """Extracts the child ArrowSchema for the specified column index.

        Args:
            col_idx: Zero-based column index.

        Returns:
            Child ArrowSchema for the column.

        Raises:
            Error: If col_idx is out of range.
        """
        if col_idx < 0 or col_idx >= self.num_cols():
            raise Error("Column index out of bounds")
        return self.schema_ptr[].children[unsafe_offset=col_idx][]

    def get_column_name(self, col_idx: Int) raises -> String:
        """Retrieves the name of the column at col_idx.

        Args:
            col_idx: Zero-based column index.

        Returns:
            Column name string.

        Raises:
            Error: If col_idx is out of range.
        """
        var col_schema = self.get_column_schema(col_idx)
        return col_schema.name_str()

    def get_column_format(self, col_idx: Int) raises -> String:
        """Retrieves the Arrow format code of the column at col_idx.

        Args:
            col_idx: Zero-based column index.

        Returns:
            Arrow format code (e.g. 'g', 'l', 'vu').

        Raises:
            Error: If col_idx is out of range.
        """
        var col_schema = self.get_column_schema(col_idx)
        return col_schema.format_str()
