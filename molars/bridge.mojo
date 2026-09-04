from std.ffi import external_call, c_char, CStringSlice
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from molars.arrow_abi import ArrowArray, ArrowSchema

struct MolarsBridge:
    @staticmethod
    @always_inline
    def read_csv(
        path: String,
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var path_copy = path
        var ret = external_call["molars_read_csv", Int32](
            path_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error("molars_read_csv failed (code " + String(ret) + "): " + err)
        return ret

    @staticmethod
    @always_inline
    def read_parquet(
        path: String,
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var path_copy = path
        var ret = external_call["molars_read_parquet", Int32](
            path_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error("molars_read_parquet failed (code " + String(ret) + "): " + err)
        return ret

    @staticmethod
    @always_inline
    def sql_query(
        query: String,
        table_name: String,
        file_path: String,
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var q_copy = query
        var t_copy = table_name
        var f_copy = file_path
        var ret = external_call["molars_sql_query", Int32](
            q_copy.unsafe_ptr(),
            t_copy.unsafe_ptr(),
            f_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error("molars_sql_query failed (code " + String(ret) + "): " + err)
        return ret

    @staticmethod
    @always_inline
    def release_array(array: Pointer[ArrowArray, MutUntrackedOrigin]):
        _ = external_call["molars_release_array", NoneType](array)

    @staticmethod
    @always_inline
    def release_schema(schema: Pointer[ArrowSchema, MutUntrackedOrigin]):
        _ = external_call["molars_release_schema", NoneType](schema)

    @staticmethod
    def get_last_error() -> String:
        var buf = unsafe_alloc[c_char](1024)
        var n = external_call["molars_get_last_error", Int32](buf, 1024)
        if n > 0:
            var res = String(CStringSlice(unsafe_from_ptr=buf))
            buf.unsafe_free()
            return res
        buf.unsafe_free()
        return "Unknown error"
