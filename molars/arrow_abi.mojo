from std.ffi import c_char, CStringSlice, external_call
from std.memory import Pointer

@always_inline
def null_ptr[T: AnyType]() -> Pointer[T, MutUntrackedOrigin]:
    return Pointer[T, MutUntrackedOrigin](unsafe_from_address=Int(0))

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

    def is_released(self) -> Bool:
        return Int(self.release) == 0

    def format_str(self) -> String:
        if Int(self.format) == 0:
            return ""
        return String(CStringSlice(unsafe_from_ptr=self.format))

    def name_str(self) -> String:
        if Int(self.name) == 0:
            return ""
        return String(CStringSlice(unsafe_from_ptr=self.name))

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

    def is_released(self) -> Bool:
        return Int(self.release) == 0

struct ManagedArrowTable(Movable):
    var array_ptr: Pointer[ArrowArray, MutUntrackedOrigin]
    var schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin]
    var is_active: Bool


    def __init__(
        out self,
        array_ptr: Pointer[ArrowArray, MutUntrackedOrigin],
        schema_ptr: Pointer[ArrowSchema, MutUntrackedOrigin],
    ):
        self.array_ptr = array_ptr
        self.schema_ptr = schema_ptr
        self.is_active = True

    def __init__(out self, *, deinit move: Self):
        self.array_ptr = move.array_ptr
        self.schema_ptr = move.schema_ptr
        self.is_active = move.is_active

    def __deinit__(deinit self):
        if self.is_active:
            _ = external_call["molars_release_array", NoneType](self.array_ptr)
            _ = external_call["molars_release_schema", NoneType](self.schema_ptr)
            self.array_ptr.unsafe_free()
            self.schema_ptr.unsafe_free()

    def array(self) -> ArrowArray:
        return self.array_ptr[]

    def schema(self) -> ArrowSchema:
        return self.schema_ptr[]

    def num_rows(self) -> Int:
        return Int(self.array_ptr[].length)

    def num_cols(self) -> Int:
        return Int(self.array_ptr[].n_children)

    def get_column_array(self, col_idx: Int) raises -> ArrowArray:
        if col_idx < 0 or col_idx >= self.num_cols():
            raise Error("Column index out of bounds")
        return self.array_ptr[].children[unsafe_offset=col_idx][]

    def get_column_schema(self, col_idx: Int) raises -> ArrowSchema:
        if col_idx < 0 or col_idx >= self.num_cols():
            raise Error("Column index out of bounds")
        return self.schema_ptr[].children[unsafe_offset=col_idx][]

    def get_column_name(self, col_idx: Int) raises -> String:
        var col_schema = self.get_column_schema(col_idx)
        return col_schema.name_str()

    def get_column_format(self, col_idx: Int) raises -> String:
        var col_schema = self.get_column_schema(col_idx)
        return col_schema.format_str()
