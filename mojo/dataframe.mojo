from std.algorithm import vectorize
from std.memory import Pointer
from molars.arrow_abi import ArrowArray, ArrowSchema, ManagedArrowTable, null_ptr
from molars.bridge import MolarsBridge

@fieldwise_init
struct Series(Copyable, Movable):
    var name: String
    var format: String
    var length: Int
    var null_count: Int
    var n_buffers: Int
    var buffers: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin]

    def len(self) -> Int:
        return self.length

    def as_float64_ptr(self) raises -> Pointer[Float64, MutUntrackedOrigin]:
        if self.format != "g":
            raise Error("Series '" + self.name + "' is format '" + self.format + "', not Float64 ('g')")
        return self.buffers[unsafe_offset=1].unsafe_bitcast[Float64]()

    def as_float32_ptr(self) raises -> Pointer[Float32, MutUntrackedOrigin]:
        if self.format != "f":
            raise Error("Series '" + self.name + "' is format '" + self.format + "', not Float32 ('f')")
        return self.buffers[unsafe_offset=1].unsafe_bitcast[Float32]()

    def as_int64_ptr(self) raises -> Pointer[Int64, MutUntrackedOrigin]:
        if self.format != "l":
            raise Error("Series '" + self.name + "' is format '" + self.format + "', not Int64 ('l')")
        return self.buffers[unsafe_offset=1].unsafe_bitcast[Int64]()

    def as_int32_ptr(self) raises -> Pointer[Int32, MutUntrackedOrigin]:
        if self.format != "i":
            raise Error("Series '" + self.name + "' is format '" + self.format + "', not Int32 ('i')")
        return self.buffers[unsafe_offset=1].unsafe_bitcast[Int32]()

    def get_float64(self, idx: Int) raises -> Float64:
        var ptr = self.as_float64_ptr()
        return ptr[unsafe_offset=idx]

    def get_float32(self, idx: Int) raises -> Float32:
        var ptr = self.as_float32_ptr()
        return ptr[unsafe_offset=idx]

    def get_int64(self, idx: Int) raises -> Int64:
        var ptr = self.as_int64_ptr()
        return ptr[unsafe_offset=idx]

    def get_int32(self, idx: Int) raises -> Int32:
        var ptr = self.as_int32_ptr()
        return ptr[unsafe_offset=idx]

    def get_as_string(self, idx: Int) -> String:
        if self.format == "g":
            var ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Float64]()
            return String(ptr[unsafe_offset=idx])
        elif self.format == "f":
            var ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Float32]()
            return String(ptr[unsafe_offset=idx])
        elif self.format == "l":
            var ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Int64]()
            return String(ptr[unsafe_offset=idx])
        elif self.format == "i":
            var ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Int32]()
            return String(ptr[unsafe_offset=idx])
        elif self.format == "u":
            # Utf8: buffers[1] is 32-bit offsets, buffers[2] is bytes
            var off_ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Int32]()
            var start = Int(off_ptr[unsafe_offset=idx])
            var end = Int(off_ptr[unsafe_offset=idx + 1])
            var str_bytes = self.buffers[unsafe_offset=2].unsafe_bitcast[UInt8]()
            var s = String("")
            for i in range(start, end):
                s += chr(Int(str_bytes[unsafe_offset=i]))
            return s
        elif self.format == "U":
            # LargeUtf8: buffers[1] is 64-bit offsets, buffers[2] is bytes
            var off_ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Int64]()
            var start = Int(off_ptr[unsafe_offset=idx])
            var end = Int(off_ptr[unsafe_offset=idx + 1])
            var str_bytes = self.buffers[unsafe_offset=2].unsafe_bitcast[UInt8]()
            var s = String("")
            for i in range(start, end):
                s += chr(Int(str_bytes[unsafe_offset=i]))
            return s
        elif self.format == "vu":
            # Utf8View (Arrow StringView): buffers[1] is 16-byte view descriptors
            # buffers[2..] are variadic data buffers
            var raw_views = self.buffers[unsafe_offset=1].unsafe_bitcast[UInt8]()
            var view_base = idx * 16
            var u32_ptr = raw_views.unsafe_offset(view_base).unsafe_bitcast[UInt32]()
            var str_len = Int(u32_ptr[unsafe_offset=0])
            var s = String("")
            if str_len <= 12:
                # Inlined string directly in the view descriptor (bytes 4..15)
                var inline_bytes = raw_views.unsafe_offset(view_base + 4)
                for i in range(str_len):
                    s += chr(Int(inline_bytes[unsafe_offset=i]))
                return s
            else:
                # Out-of-line string in variadic buffer
                var buf_idx = Int(u32_ptr[unsafe_offset=2])
                var offset = Int(u32_ptr[unsafe_offset=3])
                var data_buf = self.buffers[unsafe_offset=2 + buf_idx].unsafe_bitcast[UInt8]()
                for i in range(str_len):
                    s += chr(Int(data_buf[unsafe_offset=offset + i]))
                return s
        else:
            return "<format " + self.format + ">"

    def sum_float64(self) raises -> Float64:
        var ptr = self.as_float64_ptr()
        var n = self.length
        var total = Float64(0.0)
        comptime simd_w = 4

        def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            total += v.reduce_add()

        vectorize[simd_w](n, add_chunk)
        return total

    def sum_int64(self) raises -> Int64:
        var ptr = self.as_int64_ptr()
        var n = self.length
        var total = Int64(0)
        comptime simd_w = 4

        def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            total += v.reduce_add()

        vectorize[simd_w](n, add_chunk)
        return total

    def mean_float64(self) raises -> Float64:
        if self.length == 0:
            return 0.0
        return self.sum_float64() / Float64(self.length)

    def mean_int64(self) raises -> Float64:
        if self.length == 0:
            return 0.0
        return Float64(self.sum_int64()) / Float64(self.length)

struct DataFrame(Movable, Writable):
    var _table: ManagedArrowTable
    var _col_names: List[String]
    var _col_formats: List[String]

    def __init__(out self, *, deinit move: Self):
        self._table = move._table^
        self._col_names = move._col_names^
        self._col_formats = move._col_formats^

    def __init__(out self, var table: ManagedArrowTable) raises:
        self._table = table^
        var n_cols = self._table.num_cols()
        self._col_names = List[String]()
        self._col_formats = List[String]()
        for i in range(n_cols):
            self._col_names.append(self._table.get_column_name(i))
            self._col_formats.append(self._table.get_column_format(i))

    @staticmethod
    def read_csv(path: String) raises -> DataFrame:
        var array_ptr = alloc[ArrowArray](1)
        var schema_ptr = alloc[ArrowSchema](1)
        _ = MolarsBridge.read_csv(path, array_ptr, schema_ptr)
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    @staticmethod
    def read_parquet(path: String) raises -> DataFrame:
        var array_ptr = alloc[ArrowArray](1)
        var schema_ptr = alloc[ArrowSchema](1)
        _ = MolarsBridge.read_parquet(path, array_ptr, schema_ptr)
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    @staticmethod
    def sql(query: String, table_name: String, file_path: String) raises -> DataFrame:
        var array_ptr = alloc[ArrowArray](1)
        var schema_ptr = alloc[ArrowSchema](1)
        _ = MolarsBridge.sql_query(query, table_name, file_path, array_ptr, schema_ptr)
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def num_rows(self) -> Int:
        return self._table.num_rows()

    def height(self) -> Int:
        return self._table.num_rows()

    def num_cols(self) -> Int:
        return len(self._col_names)

    def width(self) -> Int:
        return len(self._col_names)

    def shape(self) -> Tuple[Int, Int]:
        return (self.height(), self.width())

    def column_names(self) -> List[String]:
        var res = List[String]()
        for i in range(len(self._col_names)):
            res.append(self._col_names[i])
        return res^

    def column_index(self, name: String) raises -> Int:
        for i in range(len(self._col_names)):
            if self._col_names[i] == name:
                return i
        raise Error("Column not found: " + name)

    def column(self, name: String) raises -> Series:
        var idx = self.column_index(name)
        return self.column(idx)

    def column(self, idx: Int) raises -> Series:
        if idx < 0 or idx >= len(self._col_names):
            raise Error("Column index out of range: " + String(idx))

        var col_array = self._table.get_column_array(idx)
        var name = self._col_names[idx]
        var fmt = self._col_formats[idx]
        var length = Int(col_array.length)
        var null_cnt = Int(col_array.null_count)
        var n_bufs = Int(col_array.n_buffers)
        var bufs = col_array.buffers

        return Series(
            name=name,
            format=fmt,
            length=length,
            null_count=null_cnt,
            n_buffers=n_bufs,
            buffers=bufs,
        )

    def __getitem__(self, name: String) raises -> Series:
        return self.column(name)

    def __getitem__(self, idx: Int) raises -> Series:
        return self.column(idx)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("shape: (", self.height(), ", ", self.width(), ")\n")
        var col_count = self.width()
        for c in range(col_count):
            writer.write(self._col_names[c])
            if c + 1 < col_count:
                writer.write(" | ")
        writer.write("\n")
        for c in range(col_count):
            var type_name = "unknown"
            var fmt = self._col_formats[c]
            if fmt == "g":
                type_name = "f64"
            elif fmt == "f":
                type_name = "f32"
            elif fmt == "l":
                type_name = "i64"
            elif fmt == "i":
                type_name = "i32"
            elif fmt == "u" or fmt == "U" or fmt == "vu":
                type_name = "str"
            writer.write(type_name)
            if c + 1 < col_count:
                writer.write(" | ")
        writer.write("\n")
        for c in range(col_count):
            writer.write("---")
            if c + 1 < col_count:
                writer.write("-+-")
        writer.write("\n")

        var max_preview = 5
        var n_rows = self.height()
        if max_preview > n_rows:
            max_preview = n_rows

        for r in range(max_preview):
            for c in range(col_count):
                try:
                    var s = self.column(c)
                    writer.write(s.get_as_string(r))
                except:
                    writer.write("?")
                if c + 1 < col_count:
                    writer.write(" | ")
            writer.write("\n")

        if n_rows > max_preview:
            writer.write("... (", n_rows - max_preview, " more rows)\n")
