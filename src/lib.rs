use std::ffi::{CStr, c_char};
use std::sync::Mutex;
use polars::prelude::*;
use polars_arrow::ffi;
use polars_arrow::array::StructArray;
use polars_arrow::datatypes::{Field, ArrowDataType};

static LAST_ERROR: Mutex<String> = Mutex::new(String::new());

#[cfg(test)]
mod tests;

fn set_last_error(err: &str) {
    if let Ok(mut guard) = LAST_ERROR.lock() {
        guard.clear();
        guard.push_str(err);
    }
}

fn export_df_to_arrow_c(
    df: &mut DataFrame,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    let single_df = df.as_single_chunk_par();
    let compat = polars::datatypes::CompatLevel::newest();
    let mut fields = Vec::with_capacity(single_df.width());
    let mut arrays = Vec::with_capacity(single_df.width());

    for col in single_df.get_columns() {
        let field = col.as_materialized_series().field().to_arrow(compat);
        let arr = col.as_materialized_series().to_arrow(0, compat);
        fields.push(field);
        arrays.push(arr);
    }

    let struct_data_type = ArrowDataType::Struct(fields.clone());
    let struct_array = StructArray::new(struct_data_type.clone(), single_df.height(), arrays, None);
    let top_field = Field::new("".into(), struct_data_type, false);

    let c_array = ffi::export_array_to_c(Box::new(struct_array));
    let c_schema = ffi::export_field_to_c(&top_field);

    unsafe {
        std::ptr::write(out_array, c_array);
        std::ptr::write(out_schema, c_schema);
    }

    0
}

#[no_mangle]
pub unsafe extern "C" fn molars_read_csv(
    path: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if path.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_read_csv");
        return -1;
    }

    let c_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in file path: {}", e));
            return -2;
        }
    };

    let res = CsvReadOptions::default()
        .try_into_reader_with_file_path(Some(c_str.into()))
        .and_then(|r| r.finish());

    let mut df = match res {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&format!("Failed to read CSV '{}': {}", c_str, e));
            return -3;
        }
    };

    export_df_to_arrow_c(&mut df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_read_parquet(
    path: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if path.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_read_parquet");
        return -1;
    }

    let c_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in file path: {}", e));
            return -2;
        }
    };

    let file = match std::fs::File::open(c_str) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(&format!("Failed to open Parquet file '{}': {}", c_str, e));
            return -3;
        }
    };

    let res = ParquetReader::new(file).finish();
    let mut df = match res {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&format!("Failed to parse Parquet file '{}': {}", c_str, e));
            return -4;
        }
    };

    export_df_to_arrow_c(&mut df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_sql_query(
    query: *const c_char,
    table_name: *const c_char,
    file_path: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if query.is_null() || table_name.is_null() || file_path.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_sql_query");
        return -1;
    }

    let q_str = match CStr::from_ptr(query).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 query: {}", e));
            return -2;
        }
    };

    let t_str = match CStr::from_ptr(table_name).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 table name: {}", e));
            return -2;
        }
    };

    let f_str = match CStr::from_ptr(file_path).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 file path: {}", e));
            return -2;
        }
    };

    let lf = if f_str.ends_with(".parquet") {
        match LazyFrame::scan_parquet(f_str, ScanArgsParquet::default()) {
            Ok(lf) => lf,
            Err(e) => {
                set_last_error(&format!("Failed scanning parquet '{}': {}", f_str, e));
                return -3;
            }
        }
    } else {
        match LazyCsvReader::new(f_str).finish() {
            Ok(lf) => lf,
            Err(e) => {
                set_last_error(&format!("Failed scanning csv '{}': {}", f_str, e));
                return -3;
            }
        }
    };

    let mut ctx = polars::sql::SQLContext::new();
    ctx.register(t_str, lf);

    let res = match ctx.execute(q_str) {
        Ok(lf_res) => lf_res.collect(),
        Err(e) => {
            set_last_error(&format!("Failed to execute SQL query '{}': {}", q_str, e));
            return -4;
        }
    };

    let mut df = match res {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&format!("Failed to collect SQL query result: {}", e));
            return -5;
        }
    };

    export_df_to_arrow_c(&mut df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_release_array(array: *mut ffi::ArrowArray) {
    if !array.is_null() {
        let _ = std::ptr::read(array);
    }
}

#[no_mangle]
pub unsafe extern "C" fn molars_release_schema(schema: *mut ffi::ArrowSchema) {
    if !schema.is_null() {
        let _ = std::ptr::read(schema);
    }
}

#[no_mangle]
pub unsafe extern "C" fn molars_get_last_error(buf: *mut c_char, buf_len: usize) -> i32 {
    if buf.is_null() || buf_len == 0 {
        return -1;
    }

    if let Ok(guard) = LAST_ERROR.lock() {
        let bytes = guard.as_bytes();
        let copy_len = std::cmp::min(bytes.len(), buf_len - 1);
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), buf as *mut u8, copy_len);
        *buf.add(copy_len) = 0;
        copy_len as i32
    } else {
        -2
    }
}
