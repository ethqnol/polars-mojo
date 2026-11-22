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
    def read_csv_ex(
        path: String,
        try_parse_dates: Bool,
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var path_copy = path + "\0"
        var parse_dates = Int32(1) if try_parse_dates else Int32(0)
        var ret = external_call["molars_read_csv_ex", Int32](
            path_copy.unsafe_ptr(),
            parse_dates,
            array,
            schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_read_csv_ex failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def filter_df(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        mask_ptr: Pointer[UInt8, MutUntrackedOrigin],
        mask_len: Int,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var ret = external_call["molars_filter", Int32](
            array,
            schema,
            mask_ptr,
            mask_len,
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_filter failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def sort_df(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        by_csv: String,
        descending_csv: String,
        nulls_last: Bool,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var by_copy = by_csv + "\0"
        var desc_copy = descending_csv + "\0"
        var nl = Int32(1) if nulls_last else Int32(0)
        var ret = external_call["molars_sort", Int32](
            array,
            schema,
            by_copy.unsafe_ptr(),
            desc_copy.unsafe_ptr(),
            nl,
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_sort failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def join_df(
        left_array: Pointer[ArrowArray, MutUntrackedOrigin],
        left_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        right_array: Pointer[ArrowArray, MutUntrackedOrigin],
        right_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        left_on_csv: String,
        right_on_csv: String,
        how: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var lon_copy = left_on_csv + "\0"
        var ron_copy = right_on_csv + "\0"
        var how_copy = how + "\0"
        var ret = external_call["molars_join", Int32](
            left_array,
            left_schema,
            right_array,
            right_schema,
            lon_copy.unsafe_ptr(),
            ron_copy.unsafe_ptr(),
            how_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_join failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def drop_nulls(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        subset_csv: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var sub_copy = subset_csv + "\0"
        var ret = external_call["molars_drop_nulls", Int32](
            array,
            schema,
            sub_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_drop_nulls failed (code " + String(ret) + "): " + err
            )
        return ret

    @staticmethod
    @always_inline
    def fill_null_float64(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_name: String,
        value: Float64,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var col_copy = col_name + "\0"
        var ret = external_call["molars_fill_null_float64", Int32](
            array,
            schema,
            col_copy.unsafe_ptr(),
            value,
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_fill_null_float64 failed (code "
                + String(ret)
                + "): "
                + err
            )
        return ret

    @staticmethod
    @always_inline
    def fill_null_int64(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_name: String,
        value: Int64,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var col_copy = col_name + "\0"
        var ret = external_call["molars_fill_null_int64", Int32](
            array,
            schema,
            col_copy.unsafe_ptr(),
            value,
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_fill_null_int64 failed (code "
                + String(ret)
                + "): "
                + err
            )
        return ret

    @staticmethod
    @always_inline
    def fill_null_str(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_name: String,
        value: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var col_copy = col_name + "\0"
        var val_copy = value + "\0"
        var ret = external_call["molars_fill_null_str", Int32](
            array,
            schema,
            col_copy.unsafe_ptr(),
            val_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_fill_null_str failed (code "
                + String(ret)
                + "): "
                + err
            )
        return ret

    @staticmethod
    @always_inline
    def fill_null_strategy(
        array: Pointer[ArrowArray, MutUntrackedOrigin],
        schema: Pointer[ArrowSchema, MutUntrackedOrigin],
        col_name: String,
        strategy: String,
        out_array: Pointer[ArrowArray, MutUntrackedOrigin],
        out_schema: Pointer[ArrowSchema, MutUntrackedOrigin],
    ) raises -> Int32:
        var col_copy = col_name + "\0"
        var strat_copy = strategy + "\0"
        var ret = external_call["molars_fill_null_strategy", Int32](
            array,
            schema,
            col_copy.unsafe_ptr(),
            strat_copy.unsafe_ptr(),
            out_array,
            out_schema,
        )
        if ret != 0:
            var err = MolarsBridge.get_last_error()
            raise Error(
                "molars_fill_null_strategy failed (code "
                + String(ret)
                + "): "
                + err
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
