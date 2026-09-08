#[cfg(test)]
mod tests {
    use crate::*;
    use polars_arrow::ffi;
    use std::ffi::CString;

    #[test]
    fn test_new_ffi_functions() {
        let mut array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let path = CString::new("tests/sample.csv").unwrap();
        let ret = unsafe {
            molars_read_csv(path.as_ptr(), array.as_mut_ptr(), schema.as_mut_ptr())
        };
        assert_eq!(ret, 0);
        let mut array = unsafe { array.assume_init() };
        let mut schema = unsafe { schema.assume_init() };

        println!("Starting test_new_ffi_functions...");
        let out_csv = CString::new("target/test_ffi_out.csv").unwrap();
        println!("Calling molars_write_csv...");
        let ret_csv = unsafe {
            molars_write_csv(&array, &schema, out_csv.as_ptr())
        };
        println!("molars_write_csv returned {}", ret_csv);
        assert_eq!(ret_csv, 0);
        assert!(std::path::Path::new("target/test_ffi_out.csv").exists());

        println!("Calling molars_write_parquet...");
        let out_parquet = CString::new("target/test_ffi_out.parquet").unwrap();
        let ret_parquet = unsafe {
            molars_write_parquet(&array, &schema, out_parquet.as_ptr())
        };
        println!("molars_write_parquet returned {}", ret_parquet);
        assert_eq!(ret_parquet, 0);

        println!("Calling molars_slice...");
        let mut slice_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut slice_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let ret_slice = unsafe {
            molars_slice(&array, &schema, 1, 2, slice_arr.as_mut_ptr(), slice_sch.as_mut_ptr())
        };
        println!("molars_slice returned {}", ret_slice);
        assert_eq!(ret_slice, 0);
        let mut slice_arr = unsafe { slice_arr.assume_init() };
        let mut slice_sch = unsafe { slice_sch.assume_init() };
        let c_slice = &slice_arr as *const ffi::ArrowArray as *const CArrowArray;
        assert_eq!(unsafe { (*c_slice).length }, 2);
        println!("Releasing slice...");
        unsafe {
            molars_release_array(&mut slice_arr);
            molars_release_schema(&mut slice_sch);
        }
        println!("Slice released!");

        println!("Calling molars_select_columns...");
        // Test select columns
        let mut sel_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut sel_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let sel_cols = CString::new("name,score").unwrap();
        let ret_sel = unsafe {
            molars_select_columns(&array, &schema, sel_cols.as_ptr(), sel_arr.as_mut_ptr(), sel_sch.as_mut_ptr())
        };
        println!("molars_select_columns returned {}", ret_sel);
        assert_eq!(ret_sel, 0);
        let mut sel_arr = unsafe { sel_arr.assume_init() };
        let mut sel_sch = unsafe { sel_sch.assume_init() };
        let c_sel = &sel_arr as *const ffi::ArrowArray as *const CArrowArray;
        assert_eq!(unsafe { (*c_sel).n_children }, 2);
        unsafe {
            molars_release_array(&mut sel_arr);
            molars_release_schema(&mut sel_sch);
        }

        // Test drop columns
        let mut drop_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut drop_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let drop_cols = CString::new("count").unwrap();
        let ret_drop = unsafe {
            molars_drop_columns(&array, &schema, drop_cols.as_ptr(), drop_arr.as_mut_ptr(), drop_sch.as_mut_ptr())
        };
        assert_eq!(ret_drop, 0);
        let mut drop_arr = unsafe { drop_arr.assume_init() };
        let mut drop_sch = unsafe { drop_sch.assume_init() };
        let c_drop = &drop_arr as *const ffi::ArrowArray as *const CArrowArray;
        assert_eq!(unsafe { (*c_drop).n_children }, 3);
        unsafe {
            molars_release_array(&mut drop_arr);
            molars_release_schema(&mut drop_sch);
        }

        // Test rename column
        let mut ren_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut ren_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let old_name = CString::new("score").unwrap();
        let new_name = CString::new("rating").unwrap();
        let ret_ren = unsafe {
            molars_rename_column(&array, &schema, old_name.as_ptr(), new_name.as_ptr(), ren_arr.as_mut_ptr(), ren_sch.as_mut_ptr())
        };
        assert_eq!(ret_ren, 0);
        let mut ren_arr = unsafe { ren_arr.assume_init() };
        let mut ren_sch = unsafe { ren_sch.assume_init() };
        unsafe {
            molars_release_array(&mut ren_arr);
            molars_release_schema(&mut ren_sch);
        }

        // Original array must still be valid and cleanly releasable
        unsafe {
            molars_release_array(&mut array);
            molars_release_schema(&mut schema);
        }
    }

    #[test]
    fn test_export_1m() {
        if !std::path::Path::new("scratch/bench_1m.csv").exists() {
            println!("Skipping test_export_1m: scratch/bench_1m.csv not found");
            return;
        }

        let mut array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();

        let path = CString::new("scratch/bench_1m.csv").unwrap();
        let ret = unsafe {
            molars_read_csv(path.as_ptr(), array.as_mut_ptr(), schema.as_mut_ptr())
        };
        assert_eq!(ret, 0);

        let mut array = unsafe { array.assume_init() };
        let mut schema = unsafe { schema.assume_init() };

        let c_arr = &array as *const ffi::ArrowArray as *const CArrowArray;
        let c_arr_ref = unsafe { &*c_arr };

        println!("Top array length: {}, n_children: {}", c_arr_ref.length, c_arr_ref.n_children);
        assert_eq!(c_arr_ref.length, 1_000_000);
        assert_eq!(c_arr_ref.n_children, 2);

        // Inspect child 0
        let child0_ptr = unsafe { *c_arr_ref.children };
        let child0 = unsafe { &*child0_ptr };
        println!("Child 0: len={}, n_buffers={}", child0.length, child0.n_buffers);
        for b in 0..child0.n_buffers {
            let buf_ptr = unsafe { *child0.buffers.add(b as usize) };
            println!("  Buffer {} ptr: {:p}", b, buf_ptr);
        }

        // Check first few float values
        let f64_ptr = unsafe { *child0.buffers.add(1) as *const f64 };
        println!("f64_ptr: {:p}", f64_ptr);
        unsafe {
            println!("f[0] = {}, f[1] = {}, f[2] = {}", *f64_ptr, *f64_ptr.add(1), *f64_ptr.add(2));
        }

        unsafe {
            molars_release_array(&mut array);
            molars_release_schema(&mut schema);
        }
        std::mem::forget(array);
        std::mem::forget(schema);
    }

    #[test]
    fn test_polars_groupby_api() {
        let s0 = Series::new("dept".into(), &["Sales", "HR", "Sales", "HR"]);
        let s1 = Series::new("salary".into(), &[100.0, 80.0, 120.0, 90.0]);
        let df = DataFrame::new(vec![s0.into(), s1.into()]).unwrap();

        let keys = vec![col("dept")];
        let aggs = vec![
            col("salary").sum().alias("salary_sum"),
            col("salary").mean().alias("salary_mean"),
            col("salary").count().alias("count"),
        ];

        let res = df.lazy().group_by(keys).agg(aggs).collect().unwrap();
        assert_eq!(res.height(), 2);
        assert_eq!(res.width(), 4);
    }

    #[test]
    fn test_ffi_groupby_agg() {
        let mut array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let path = CString::new("tests/sample.csv").unwrap();
        let ret = unsafe {
            molars_read_csv(path.as_ptr(), array.as_mut_ptr(), schema.as_mut_ptr())
        };
        assert_eq!(ret, 0);
        let mut array = unsafe { array.assume_init() };
        let mut schema = unsafe { schema.assume_init() };

        let mut out_array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut out_schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let keys = CString::new("name").unwrap();
        let aggs = CString::new("score:sum:total_score,score:mean,count:sum").unwrap();

        let ret_grp = unsafe {
            molars_groupby_agg(
                &array,
                &schema,
                keys.as_ptr(),
                aggs.as_ptr(),
                out_array.as_mut_ptr(),
                out_schema.as_mut_ptr(),
            )
        };
        assert_eq!(ret_grp, 0);

        let mut out_array = unsafe { out_array.assume_init() };
        let mut out_schema = unsafe { out_schema.assume_init() };
        let c_arr = &out_array as *const ffi::ArrowArray as *const CArrowArray;
        assert_eq!(unsafe { (*c_arr).length }, 5);
        assert_eq!(unsafe { (*c_arr).n_children }, 4); // name, total_score, score_mean, count_sum

        unsafe {
            molars_release_array(&mut out_array);
            molars_release_schema(&mut out_schema);
            molars_release_array(&mut array);
            molars_release_schema(&mut schema);
        }
    }
}
