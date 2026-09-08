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
        var path_copy = path + "\0"
        var ret = external_call["molars_read_csv", Int32](
            path_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_read_csv failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def read_parquet(
        path: String,
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var path_copy = path + "\0"
        var ret = external_call["molars_read_parquet", Int32](
            path_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_read_parquet failed (code " + String(ret) + "): " + err
            )
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
        var q_copy = query + "\0"
        var t_copy = table_name + "\0"
        var f_copy = file_path + "\0"
        var ret = external_call["molars_sql_query", Int32](
            q_copy.unsafe_ptr(),
            t_copy.unsafe_ptr(),
            f_copy.unsafe_ptr(),
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_sql_query failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def write_csv(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        path: String,
    ) raises -> Int32:
        var path_copy = path + "\0"
        var ret = external_call["molars_write_csv", Int32](
            array,
            schema,
            path_copy.unsafe_ptr(),
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_write_csv failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def write_parquet(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        path: String,
    ) raises -> Int32:
        var path_copy = path + "\0"
        var ret = external_call["molars_write_parquet", Int32](
            array,
            schema,
            path_copy.unsafe_ptr(),
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_write_parquet failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def slice_df(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        offset: Int64,
        length: Int,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var ret = external_call["molars_slice", Int32](
            array,
            schema,
            offset,
            length,
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_slice failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def select_columns(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_names_csv: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var cols_copy = col_names_csv + "\0"
        var ret = external_call["molars_select_columns", Int32](
            array,
            schema,
            cols_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_select_columns failed (code "
                + String(ret)
                + "): "
                + err
            )
        return ret

    @staticmethod
    @always_inline
    def drop_columns(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_names_csv: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var cols_copy = col_names_csv + "\0"
        var ret = external_call["molars_drop_columns", Int32](
            array,
            schema,
            cols_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_drop_columns failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def rename_column(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        old_name: String,
        new_name: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var old_copy = old_name + "\0"
        var new_copy = new_name + "\0"
        var ret = external_call["molars_rename_column", Int32](
            array,
            schema,
            old_copy.unsafe_ptr(),
            new_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_rename_column failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def groupby_agg(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        keys_csv: String,
        aggs_csv: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var keys_copy = keys_csv + "\0"
        var aggs_copy = aggs_csv + "\0"
        var ret = external_call["molars_groupby_agg", Int32](
            array,
            schema,
            keys_copy.unsafe_ptr(),
            aggs_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_groupby_agg failed (code " + String(ret) + "): " + err
            )
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
