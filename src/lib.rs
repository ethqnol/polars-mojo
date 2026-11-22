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

#[repr(C)]
struct CArrowSchema {
    pub format: *const c_char,
    pub name: *const c_char,
    pub metadata: *const c_char,
    pub flags: i64,
    pub n_children: i64,
    pub children: *const *const CArrowSchema,
    pub dictionary: *const CArrowSchema,
    pub release: Option<unsafe extern "C" fn(arg1: *mut CArrowSchema)>,
    pub private_data: *mut std::ffi::c_void,
}

#[derive(Clone, Copy)]
#[repr(C)]
struct CArrowArray {
    pub length: i64,
    pub null_count: i64,
    pub offset: i64,
    pub n_buffers: i64,
    pub n_children: i64,
    pub buffers: *const *const std::ffi::c_void,
    pub children: *const *const CArrowArray,
    pub dictionary: *const CArrowArray,
    pub release: Option<unsafe extern "C" fn(arg1: *mut CArrowArray)>,
    pub private_data: *mut std::ffi::c_void,
}

unsafe fn parse_cstr<'a>(ptr: *const c_char, label: &str) -> Result<&'a str, String> {
    CStr::from_ptr(ptr)
        .to_str()
        .map_err(|e| format!("Invalid UTF-8 in {}: {}", label, e))
}

fn split_csv(csv: &str) -> Vec<&str> {
    csv.split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect()
}

#[inline]
unsafe fn is_valid_at(validity_ptr: *const u8, idx: usize) -> bool {
    if validity_ptr.is_null() {
        true
    } else {
        ((*validity_ptr.add(idx >> 3) >> (idx & 7)) & 1) != 0
    }
}

unsafe fn read_primitive_series<T>(
    name: &str,
    data_buf: *const std::ffi::c_void,
    col_offset: usize,
    col_len: usize,
    validity_ptr: *const u8,
    has_nulls: bool,
) -> Series
where
    T: Copy + 'static,
    Series: for<'a> NamedFrom<&'a [T], [T]> + NamedFrom<Vec<Option<T>>, [Option<T>]>,
{
    let ptr = (data_buf as *const T).add(col_offset);
    if !has_nulls {
        let slice = std::slice::from_raw_parts(ptr, col_len);
        Series::new(name.into(), slice)
    } else {
        let mut vals = Vec::with_capacity(col_len);
        for row in 0..col_len {
            if is_valid_at(validity_ptr, col_offset + row) {
                vals.push(Some(*ptr.add(row)));
            } else {
                vals.push(None);
            }
        }
        Series::new(name.into(), vals)
    }
}

unsafe fn read_i64_chunked(
    name: &str,
    data_buf: *const std::ffi::c_void,
    col_offset: usize,
    col_len: usize,
    validity_ptr: *const u8,
    has_nulls: bool,
    scale: i64,
) -> Int64Chunked {
    let ptr = (data_buf as *const i64).add(col_offset);
    if !has_nulls && scale == 1 {
        let slice = std::slice::from_raw_parts(ptr, col_len);
        Int64Chunked::from_slice(name.into(), slice)
    } else {
        let vals: Vec<Option<i64>> = (0..col_len)
            .map(|row| {
                if !has_nulls || is_valid_at(validity_ptr, col_offset + row) {
                    Some(*ptr.add(row) * scale)
                } else {
                    None
                }
            })
            .collect();
        Int64Chunked::from_iter_options(name.into(), vals.into_iter())
    }
}

unsafe fn import_df_non_owning(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
) -> Result<DataFrame, String> {
    if array.is_null() || schema.is_null() {
        return Err("Null pointer argument passed to import_df_non_owning".to_string());
    }

    let top_arr = &*(array as *const CArrowArray);
    let top_sch = &*(schema as *const CArrowSchema);

    let n_cols = top_arr.n_children as usize;

    let mut cols: Vec<Column> = Vec::with_capacity(n_cols);

    for i in 0..n_cols {
        let col_arr = &*(*top_arr.children.add(i));
        let col_sch = &*(*top_sch.children.add(i));

        let name = if col_sch.name.is_null() {
            ""
        } else {
            CStr::from_ptr(col_sch.name).to_str().unwrap_or("")
        };

        let format = if col_sch.format.is_null() {
            ""
        } else {
            CStr::from_ptr(col_sch.format).to_str().unwrap_or("")
        };

        let col_len = col_arr.length as usize;
        let col_offset = col_arr.offset as usize;
        let validity_ptr = if col_arr.n_buffers > 0 {
            *col_arr.buffers.add(0) as *const u8
        } else {
            std::ptr::null()
        };
        let has_nulls = !validity_ptr.is_null() && col_arr.null_count != 0;

        let series: Series = match format {
            "g" => read_primitive_series::<f64>(
                name,
                *col_arr.buffers.add(1),
                col_offset,
                col_len,
                validity_ptr,
                has_nulls,
            ),
            "f" => read_primitive_series::<f32>(
                name,
                *col_arr.buffers.add(1),
                col_offset,
                col_len,
                validity_ptr,
                has_nulls,
            ),
            "l" => read_primitive_series::<i64>(
                name,
                *col_arr.buffers.add(1),
                col_offset,
                col_len,
                validity_ptr,
                has_nulls,
            ),
            "i" => read_primitive_series::<i32>(
                name,
                *col_arr.buffers.add(1),
                col_offset,
                col_len,
                validity_ptr,
                has_nulls,
            ),
            "b" => {
                let data_ptr = *col_arr.buffers.add(1) as *const u8;
                if !has_nulls {
                    let mut vals = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        let idx = col_offset + row;
                        vals.push(((*data_ptr.add(idx >> 3) >> (idx & 7)) & 1) != 0);
                    }
                    Series::new(name.into(), vals)
                } else {
                    let mut vals = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        let idx = col_offset + row;
                        if is_valid_at(validity_ptr, idx) {
                            vals.push(Some(((*data_ptr.add(idx >> 3) >> (idx & 7)) & 1) != 0));
                        } else {
                            vals.push(None);
                        }
                    }
                    Series::new(name.into(), vals)
                }
            }
            "u" => {
                let off_ptr = *col_arr.buffers.add(1) as *const i32;
                let bytes_ptr = *col_arr.buffers.add(2) as *const u8;
                if !has_nulls {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        let start = *off_ptr.add(col_offset + row) as usize;
                        let end = *off_ptr.add(col_offset + row + 1) as usize;
                        let s = std::str::from_utf8(std::slice::from_raw_parts(bytes_ptr.add(start), end - start)).unwrap_or("");
                        strs.push(s);
                    }
                    Series::new(name.into(), strs)
                } else {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        if is_valid_at(validity_ptr, col_offset + row) {
                            let start = *off_ptr.add(col_offset + row) as usize;
                            let end = *off_ptr.add(col_offset + row + 1) as usize;
                            let s = std::str::from_utf8(std::slice::from_raw_parts(bytes_ptr.add(start), end - start)).unwrap_or("");
                            strs.push(Some(s));
                        } else {
                            strs.push(None);
                        }
                    }
                    Series::new(name.into(), strs)
                }
            }
            "U" => {
                let off_ptr = *col_arr.buffers.add(1) as *const i64;
                let bytes_ptr = *col_arr.buffers.add(2) as *const u8;
                if !has_nulls {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        let start = *off_ptr.add(col_offset + row) as usize;
                        let end = *off_ptr.add(col_offset + row + 1) as usize;
                        let s = std::str::from_utf8(std::slice::from_raw_parts(bytes_ptr.add(start), end - start)).unwrap_or("");
                        strs.push(s);
                    }
                    Series::new(name.into(), strs)
                } else {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        if is_valid_at(validity_ptr, col_offset + row) {
                            let start = *off_ptr.add(col_offset + row) as usize;
                            let end = *off_ptr.add(col_offset + row + 1) as usize;
                            let s = std::str::from_utf8(std::slice::from_raw_parts(bytes_ptr.add(start), end - start)).unwrap_or("");
                            strs.push(Some(s));
                        } else {
                            strs.push(None);
                        }
                    }
                    Series::new(name.into(), strs)
                }
            }
            "vu" => {
                let raw_views = *col_arr.buffers.add(1) as *const u8;
                let decode_view = |row: usize| -> &str {
                    let view_base = (col_offset + row) * 16;
                    let u32_ptr = raw_views.add(view_base) as *const u32;
                    let str_len = *u32_ptr as usize;
                    if str_len <= 12 {
                        let inline_bytes = raw_views.add(view_base + 4);
                        std::str::from_utf8(std::slice::from_raw_parts(inline_bytes, str_len)).unwrap_or("")
                    } else {
                        let buf_idx = *u32_ptr.add(2) as usize;
                        let offset = *u32_ptr.add(3) as usize;
                        let data_buf = *col_arr.buffers.add(2 + buf_idx) as *const u8;
                        std::str::from_utf8(std::slice::from_raw_parts(data_buf.add(offset), str_len)).unwrap_or("")
                    }
                };
                if !has_nulls {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        strs.push(decode_view(row));
                    }
                    Series::new(name.into(), strs)
                } else {
                    let mut strs = Vec::with_capacity(col_len);
                    for row in 0..col_len {
                        if is_valid_at(validity_ptr, col_offset + row) {
                            strs.push(Some(decode_view(row)));
                        } else {
                            strs.push(None);
                        }
                    }
                    Series::new(name.into(), strs)
                }
            }
            "tdD" => {
                let ptr = (*col_arr.buffers.add(1) as *const i32).add(col_offset);
                let ca = if !has_nulls {
                    Int32Chunked::from_slice(name.into(), std::slice::from_raw_parts(ptr, col_len))
                } else {
                    let vals: Vec<Option<i32>> = (0..col_len)
                        .map(|row| {
                            if is_valid_at(validity_ptr, col_offset + row) {
                                Some(*ptr.add(row))
                            } else {
                                None
                            }
                        })
                        .collect();
                    Int32Chunked::from_iter_options(name.into(), vals.into_iter())
                };
                ca.into_date().into_series()
            }
            ts if ts.starts_with("ts") => {
                let mut parts = ts.splitn(2, ':');
                let prefix = parts.next().unwrap_or("");
                let tz_str = parts.next().unwrap_or("");
                let tz: Option<TimeZone> = if tz_str.is_empty() {
                    None
                } else {
                    Some(tz_str.into())
                };
                let (unit, scale) = match prefix {
                    "tss" => (TimeUnit::Milliseconds, 1000),
                    "tsm" => (TimeUnit::Milliseconds, 1),
                    "tsu" => (TimeUnit::Microseconds, 1),
                    "tsn" => (TimeUnit::Nanoseconds, 1),
                    _ => {
                        return Err(format!("Unsupported timestamp format '{}' for column '{}'", ts, name));
                    }
                };
                let ca = read_i64_chunked(
                    name,
                    *col_arr.buffers.add(1),
                    col_offset,
                    col_len,
                    validity_ptr,
                    has_nulls,
                    scale,
                );
                ca.into_datetime(unit, tz).into_series()
            }
            dur if dur.starts_with("tD") => {
                let (unit, scale) = match dur {
                    "tDs" => (TimeUnit::Milliseconds, 1000),
                    "tDm" => (TimeUnit::Milliseconds, 1),
                    "tDu" => (TimeUnit::Microseconds, 1),
                    "tDn" => (TimeUnit::Nanoseconds, 1),
                    _ => {
                        return Err(format!("Unsupported duration format '{}' for column '{}'", dur, name));
                    }
                };
                let ca = read_i64_chunked(
                    name,
                    *col_arr.buffers.add(1),
                    col_offset,
                    col_len,
                    validity_ptr,
                    has_nulls,
                    scale,
                );
                ca.into_duration(unit).into_series()
            }
            other => {
                return Err(format!("Unsupported Arrow format code '{}' for column '{}'", other, name));
            }
        };

        cols.push(series.into());
    }

    DataFrame::new(cols).map_err(|e| format!("Failed to create DataFrame: {}", e))
}

#[no_mangle]
pub unsafe extern "C" fn molars_write_csv(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    path: *const c_char,
) -> i32 {
    if array.is_null() || schema.is_null() || path.is_null() {
        set_last_error("Null pointer argument passed to molars_write_csv");
        return -1;
    }

    let c_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in file path: {}", e));
            return -2;
        }
    };

    let mut df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    if let Some(parent) = std::path::Path::new(c_str).parent() {
        if !parent.as_os_str().is_empty() {
            let _ = std::fs::create_dir_all(parent);
        }
    }

    let mut file = match std::fs::File::create(c_str) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(&format!("Failed to create CSV file '{}': {}", c_str, e));
            return -4;
        }
    };

    if let Err(e) = CsvWriter::new(&mut file).finish(&mut df) {
        set_last_error(&format!("Failed to write CSV '{}': {}", c_str, e));
        return -5;
    }

    0
}

#[no_mangle]
pub unsafe extern "C" fn molars_write_parquet(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    path: *const c_char,
) -> i32 {
    if array.is_null() || schema.is_null() || path.is_null() {
        set_last_error("Null pointer argument passed to molars_write_parquet");
        return -1;
    }

    let c_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in file path: {}", e));
            return -2;
        }
    };

    let mut df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    if let Some(parent) = std::path::Path::new(c_str).parent() {
        if !parent.as_os_str().is_empty() {
            let _ = std::fs::create_dir_all(parent);
        }
    }

    let mut file = match std::fs::File::create(c_str) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(&format!("Failed to create Parquet file '{}': {}", c_str, e));
            return -4;
        }
    };

    if let Err(e) = ParquetWriter::new(&mut file).finish(&mut df) {
        set_last_error(&format!("Failed to write Parquet '{}': {}", c_str, e));
        return -5;
    }

    0
}

#[no_mangle]
pub unsafe extern "C" fn molars_slice(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    offset: i64,
    length: usize,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_slice");
        return -1;
    }

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    let mut sliced = df.slice(offset, length);
    export_df_to_arrow_c(&mut sliced, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_select_columns(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_names_csv: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || col_names_csv.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_select_columns");
        return -1;
    }

    let cols_str = match CStr::from_ptr(col_names_csv).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in column names: {}", e));
            return -2;
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let col_names: Vec<&str> = cols_str
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();

    let mut selected = match df.select(col_names) {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Failed to select columns: {}", e));
            return -4;
        }
    };

    export_df_to_arrow_c(&mut selected, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_drop_columns(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_names_csv: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || col_names_csv.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_drop_columns");
        return -1;
    }

    let cols_str = match CStr::from_ptr(col_names_csv).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in column names: {}", e));
            return -2;
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let col_names: Vec<&str> = cols_str
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();

    let mut dropped = df.drop_many(col_names);
    export_df_to_arrow_c(&mut dropped, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_rename_column(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    old_name: *const c_char,
    new_name: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || old_name.is_null() || new_name.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_rename_column");
        return -1;
    }

    let old_str = match CStr::from_ptr(old_name).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in old column name: {}", e));
            return -2;
        }
    };

    let new_str = match CStr::from_ptr(new_name).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in new column name: {}", e));
            return -2;
        }
    };

    let mut df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    if let Err(e) = df.rename(old_str, new_str.into()) {
        set_last_error(&format!("Failed to rename column '{}' to '{}': {}", old_str, new_str, e));
        return -4;
    }

    export_df_to_arrow_c(&mut df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_groupby_agg(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    keys_csv: *const c_char,
    aggs_csv: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || keys_csv.is_null() || aggs_csv.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_groupby_agg");
        return -1;
    }

    let keys_str = match CStr::from_ptr(keys_csv).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in keys: {}", e));
            return -2;
        }
    };

    let aggs_str = match CStr::from_ptr(aggs_csv).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Invalid UTF-8 in aggs: {}", e));
            return -2;
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let key_exprs: Vec<Expr> = keys_str
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| col(s))
        .collect();

    if key_exprs.is_empty() {
        set_last_error("No grouping keys provided");
        return -4;
    }

    let mut agg_exprs: Vec<Expr> = Vec::new();
    for item in aggs_str.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()) {
        let parts: Vec<&str> = item.split(':').map(|s| s.trim()).collect();
        if parts.len() < 2 {
            set_last_error(&format!("Invalid aggregation format '{}', expected 'col:op' or 'col:op:alias'", item));
            return -5;
        }
        let col_name = parts[0];
        let op = parts[1].to_lowercase();
        let alias_name = if parts.len() >= 3 {
            parts[2].to_string()
        } else {
            format!("{}_{}", col_name, op)
        };

        let base_expr = col(col_name);
        let agg_expr = match op.as_str() {
            "sum" => base_expr.sum(),
            "mean" | "avg" => base_expr.mean(),
            "min" => base_expr.min(),
            "max" => base_expr.max(),
            "count" => base_expr.count(),
            "std" => base_expr.std(1),
            "var" => base_expr.var(1),
            "first" => base_expr.first(),
            "last" => base_expr.last(),
            other => {
                set_last_error(&format!("Unsupported aggregation operation '{}' for column '{}'", other, col_name));
                return -6;
            }
        };
        agg_exprs.push(agg_expr.alias(alias_name.as_str()));
    }

    if agg_exprs.is_empty() {
        set_last_error("No aggregations specified");
        return -7;
    }

    let res = match df.lazy().group_by(key_exprs).agg(agg_exprs).collect() {
        Ok(res_df) => res_df,
        Err(e) => {
            set_last_error(&format!("Failed to execute groupby aggregation: {}", e));
            return -8;
        }
    };

    let mut res_df = res;
    export_df_to_arrow_c(&mut res_df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_read_csv_ex(
    path: *const c_char,
    try_parse_dates: i32,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if path.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_read_csv_ex");
        return -1;
    }

    let c_str = match parse_cstr(path, "file path") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    let parse_opts = CsvParseOptions::default().with_try_parse_dates(try_parse_dates != 0);
    let res = CsvReadOptions::default()
        .with_parse_options(parse_opts)
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
pub unsafe extern "C" fn molars_filter(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    mask: *const u8,
    mask_len: usize,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_filter");
        return -1;
    }
    if mask_len > 0 && mask.is_null() {
        set_last_error("Null mask pointer passed to molars_filter with non-zero length");
        return -1;
    }

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    if mask_len != df.height() {
        set_last_error(&format!(
            "Filter mask length {} does not match DataFrame height {}",
            mask_len,
            df.height()
        ));
        return -3;
    }

    let bools: Vec<bool> = if mask_len == 0 {
        Vec::new()
    } else {
        std::slice::from_raw_parts(mask, mask_len)
            .iter()
            .map(|&b| b != 0)
            .collect()
    };
    let mask_ca = BooleanChunked::from_slice("mask".into(), &bools);

    let mut filtered = match df.filter(&mask_ca) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(&format!("Failed to filter DataFrame: {}", e));
            return -4;
        }
    };

    export_df_to_arrow_c(&mut filtered, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_sort(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    by_csv: *const c_char,
    descending_csv: *const c_char,
    nulls_last: i32,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || by_csv.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_sort");
        return -1;
    }

    let by_str = match parse_cstr(by_csv, "sort columns") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };
    let desc_str = if descending_csv.is_null() {
        ""
    } else {
        match parse_cstr(descending_csv, "descending flags") {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&e);
                return -2;
            }
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let by_cols = split_csv(by_str);
    if by_cols.is_empty() {
        set_last_error("No sort columns provided");
        return -4;
    }

    let desc_flags: Vec<bool> = split_csv(desc_str)
        .into_iter()
        .map(|s| s == "1" || s.eq_ignore_ascii_case("true"))
        .collect();
    let desc_vec = if desc_flags.is_empty() {
        vec![false; by_cols.len()]
    } else if desc_flags.len() == 1 {
        vec![desc_flags[0]; by_cols.len()]
    } else if desc_flags.len() == by_cols.len() {
        desc_flags
    } else {
        set_last_error("Length of descending flags must be 1 or match number of sort columns");
        return -5;
    };

    let options = SortMultipleOptions::default()
        .with_order_descending_multi(desc_vec)
        .with_nulls_last(nulls_last != 0);

    let mut sorted = match df.sort(by_cols, options) {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&format!("Failed to sort DataFrame: {}", e));
            return -6;
        }
    };

    export_df_to_arrow_c(&mut sorted, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_join(
    left_array: *const ffi::ArrowArray,
    left_schema: *const ffi::ArrowSchema,
    right_array: *const ffi::ArrowArray,
    right_schema: *const ffi::ArrowSchema,
    left_on_csv: *const c_char,
    right_on_csv: *const c_char,
    how: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if left_array.is_null()
        || left_schema.is_null()
        || right_array.is_null()
        || right_schema.is_null()
        || how.is_null()
        || out_array.is_null()
        || out_schema.is_null()
    {
        set_last_error("Null pointer argument passed to molars_join");
        return -1;
    }

    let how_str = match parse_cstr(how, "join type") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    let left_on_str = if left_on_csv.is_null() {
        ""
    } else {
        match parse_cstr(left_on_csv, "left_on") {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&e);
                return -2;
            }
        }
    };

    let right_on_str = if right_on_csv.is_null() {
        ""
    } else {
        match parse_cstr(right_on_csv, "right_on") {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&e);
                return -2;
            }
        }
    };

    let left_df = match import_df_non_owning(left_array, left_schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };
    let right_df = match import_df_non_owning(right_array, right_schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let how_lower = how_str.trim().to_ascii_lowercase();
    let res = if how_lower == "cross" {
        left_df.cross_join(&right_df, None, None)
    } else {
        let join_type = match how_lower.as_str() {
            "inner" => JoinType::Inner,
            "left" => JoinType::Left,
            "right" => JoinType::Right,
            "full" | "outer" => JoinType::Full,
            "semi" => JoinType::Semi,
            "anti" => JoinType::Anti,
            other => {
                set_last_error(&format!("Unsupported join type '{}'", other));
                return -4;
            }
        };

        let left_on = split_csv(left_on_str);
        let right_on = split_csv(right_on_str);
        if left_on.is_empty() || left_on.len() != right_on.len() {
            set_last_error("Join key lists must be non-empty and have matching lengths");
            return -5;
        }

        left_df.join(&right_df, left_on, right_on, JoinArgs::new(join_type), None)
    };

    let mut joined = match res {
        Ok(j) => j,
        Err(e) => {
            set_last_error(&format!("Failed to join DataFrames: {}", e));
            return -6;
        }
    };

    export_df_to_arrow_c(&mut joined, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_drop_nulls(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    subset_csv: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_drop_nulls");
        return -1;
    }

    let subset_str = if subset_csv.is_null() {
        ""
    } else {
        match parse_cstr(subset_csv, "subset") {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&e);
                return -2;
            }
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let subset: Vec<String> = split_csv(subset_str).into_iter().map(String::from).collect();
    let res = if subset.is_empty() {
        df.drop_nulls::<String>(None)
    } else {
        df.drop_nulls(Some(&subset))
    };

    let mut out_df = match res {
        Ok(d) => d,
        Err(e) => {
            set_last_error(&format!("Failed to drop nulls: {}", e));
            return -4;
        }
    };

    export_df_to_arrow_c(&mut out_df, out_array, out_schema)
}

unsafe fn fill_null_col_expr(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_name: *const c_char,
    fill_val: Expr,
    fn_name: &str,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || col_name.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error(&format!("Null pointer argument passed to {}", fn_name));
        return -1;
    }

    let col_str = match parse_cstr(col_name, "column name") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -3;
        }
    };

    let mut out_df = match df.lazy().with_column(col(col_str).fill_null(fill_val)).collect() {
        Ok(d) => d,
        Err(e) => {
            set_last_error(&format!("Failed to fill_null on '{}': {}", col_str, e));
            return -4;
        }
    };

    export_df_to_arrow_c(&mut out_df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_fill_null_float64(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_name: *const c_char,
    value: f64,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    fill_null_col_expr(array, schema, col_name, lit(value), "molars_fill_null_float64", out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_fill_null_int64(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_name: *const c_char,
    value: i64,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    fill_null_col_expr(array, schema, col_name, lit(value), "molars_fill_null_int64", out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_fill_null_str(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_name: *const c_char,
    value: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if value.is_null() {
        set_last_error("Null value pointer passed to molars_fill_null_str");
        return -1;
    }
    let val_str = match parse_cstr(value, "fill value") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };
    fill_null_col_expr(array, schema, col_name, lit(val_str), "molars_fill_null_str", out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_fill_null_strategy(
    array: *const ffi::ArrowArray,
    schema: *const ffi::ArrowSchema,
    col_name: *const c_char,
    strategy: *const c_char,
    out_array: *mut ffi::ArrowArray,
    out_schema: *mut ffi::ArrowSchema,
) -> i32 {
    if array.is_null() || schema.is_null() || strategy.is_null() || out_array.is_null() || out_schema.is_null() {
        set_last_error("Null pointer argument passed to molars_fill_null_strategy");
        return -1;
    }

    let strat_str = match parse_cstr(strategy, "strategy") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(&e);
            return -2;
        }
    };

    let col_str = if col_name.is_null() {
        ""
    } else {
        match parse_cstr(col_name, "column name") {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&e);
                return -2;
            }
        }
    };

    let strat = match strat_str.trim().to_ascii_lowercase().as_str() {
        "forward" | "ffill" => FillNullStrategy::Forward(None),
        "backward" | "bfill" => FillNullStrategy::Backward(None),
        "min" => FillNullStrategy::Min,
        "max" => FillNullStrategy::Max,
        "mean" => FillNullStrategy::Mean,
        "zero" => FillNullStrategy::Zero,
        "one" => FillNullStrategy::One,
        other => {
            set_last_error(&format!("Unsupported fill_null strategy '{}'", other));
            return -3;
        }
    };

    let df = match import_df_non_owning(array, schema) {
        Ok(df) => df,
        Err(e) => {
            set_last_error(&e);
            return -4;
        }
    };

    let res = if col_str.trim().is_empty() {
        df.fill_null(strat)
    } else {
        df.lazy()
            .with_column(col(col_str.trim()).fill_null_with_strategy(strat))
            .collect()
    };

    let mut out_df = match res {
        Ok(d) => d,
        Err(e) => {
            set_last_error(&format!("Failed to fill_null with strategy '{}': {}", strat_str, e));
            return -5;
        }
    };

    export_df_to_arrow_c(&mut out_df, out_array, out_schema)
}

#[no_mangle]
pub unsafe extern "C" fn molars_release_array(array: *mut ffi::ArrowArray) {
    if !array.is_null() {
        let arr = array as *mut CArrowArray;
        if let Some(release) = (*arr).release.take() {
            release(arr);
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn molars_release_schema(schema: *mut ffi::ArrowSchema) {
    if !schema.is_null() {
        let sch = schema as *mut CArrowSchema;
        if let Some(release) = (*sch).release.take() {
            release(sch);
        }
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
