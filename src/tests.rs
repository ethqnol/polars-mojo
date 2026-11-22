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

    #[test]
    fn test_ffi_filter() {
        let mut array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let path = CString::new("tests/sample.csv").unwrap();
        let ret = unsafe {
            molars_read_csv(path.as_ptr(), array.as_mut_ptr(), schema.as_mut_ptr())
        };
        assert_eq!(ret, 0);
        let mut array = unsafe { array.assume_init() };
        let mut schema = unsafe { schema.assume_init() };

        let mask: Vec<u8> = vec![1, 0, 0, 1, 1];
        let mut out_array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut out_schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let ret_flt = unsafe {
            molars_filter(
                &array,
                &schema,
                mask.as_ptr(),
                mask.len(),
                out_array.as_mut_ptr(),
                out_schema.as_mut_ptr(),
            )
        };
        assert_eq!(ret_flt, 0);
        let mut out_array = unsafe { out_array.assume_init() };
        let mut out_schema = unsafe { out_schema.assume_init() };
        let df_filtered = unsafe { import_df_non_owning(&out_array, &out_schema) }.unwrap();
        assert_eq!(df_filtered.height(), 3);
        assert_eq!(df_filtered.column("id").unwrap().i64().unwrap().get(0), Some(1));
        assert_eq!(df_filtered.column("id").unwrap().i64().unwrap().get(1), Some(4));
        assert_eq!(df_filtered.column("id").unwrap().i64().unwrap().get(2), Some(5));

        unsafe {
            molars_release_array(&mut out_array);
            molars_release_schema(&mut out_schema);
            molars_release_array(&mut array);
            molars_release_schema(&mut schema);
        }
    }

    #[test]
    fn test_ffi_sort() {
        let mut array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let path = CString::new("tests/sample.csv").unwrap();
        assert_eq!(unsafe { molars_read_csv(path.as_ptr(), array.as_mut_ptr(), schema.as_mut_ptr()) }, 0);
        let mut array = unsafe { array.assume_init() };
        let mut schema = unsafe { schema.assume_init() };

        let mut out_array = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut out_schema = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let by = CString::new("score").unwrap();
        let desc = CString::new("false").unwrap();
        assert_eq!(
            unsafe {
                molars_sort(
                    &array,
                    &schema,
                    by.as_ptr(),
                    desc.as_ptr(),
                    1,
                    out_array.as_mut_ptr(),
                    out_schema.as_mut_ptr(),
                )
            },
            0
        );
        let mut out_array = unsafe { out_array.assume_init() };
        let mut out_schema = unsafe { out_schema.assume_init() };
        let sorted = unsafe { import_df_non_owning(&out_array, &out_schema) }.unwrap();
        assert_eq!(sorted.column("score").unwrap().f64().unwrap().get(0), Some(78.5));
        assert_eq!(sorted.column("score").unwrap().f64().unwrap().get(4), Some(95.5));

        // Multi-column sort with per-column descending flags
        let mut df_multi = DataFrame::new(vec![
            Series::new("grp".into(), &[1i64, 1, 2, 2]).into(),
            Series::new("val".into(), &[10i64, 30, 5, 20]).into(),
        ])
        .unwrap();
        let mut m_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut m_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        assert_eq!(export_df_to_arrow_c(&mut df_multi, m_arr.as_mut_ptr(), m_sch.as_mut_ptr()), 0);
        let mut m_arr = unsafe { m_arr.assume_init() };
        let mut m_sch = unsafe { m_sch.assume_init() };

        let mut ms_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut ms_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let by2 = CString::new("grp,val").unwrap();
        let desc2 = CString::new("false,true").unwrap();
        assert_eq!(
            unsafe { molars_sort(&m_arr, &m_sch, by2.as_ptr(), desc2.as_ptr(), 1, ms_arr.as_mut_ptr(), ms_sch.as_mut_ptr()) },
            0
        );
        let mut ms_arr = unsafe { ms_arr.assume_init() };
        let mut ms_sch = unsafe { ms_sch.assume_init() };
        let ms_df = unsafe { import_df_non_owning(&ms_arr, &ms_sch) }.unwrap();
        assert_eq!(ms_df.column("val").unwrap().i64().unwrap().get(0), Some(30));
        assert_eq!(ms_df.column("val").unwrap().i64().unwrap().get(1), Some(10));
        assert_eq!(ms_df.column("val").unwrap().i64().unwrap().get(2), Some(20));
        assert_eq!(ms_df.column("val").unwrap().i64().unwrap().get(3), Some(5));

        unsafe {
            molars_release_array(&mut ms_arr);
            molars_release_schema(&mut ms_sch);
            molars_release_array(&mut m_arr);
            molars_release_schema(&mut m_sch);
            molars_release_array(&mut out_array);
            molars_release_schema(&mut out_schema);
            molars_release_array(&mut array);
            molars_release_schema(&mut schema);
        }
    }

    #[test]
    fn test_ffi_join() {
        let mut left = DataFrame::new(vec![
            Series::new("id".into(), &[1i64, 2, 3]).into(),
            Series::new("name".into(), &["Alice", "Bob", "Charlie"]).into(),
        ])
        .unwrap();
        let mut right = DataFrame::new(vec![
            Series::new("id".into(), &[2i64, 3, 4]).into(),
            Series::new("dept".into(), &["Eng", "Sales", "HR"]).into(),
        ])
        .unwrap();

        let mut l_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut l_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let mut r_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut r_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        assert_eq!(export_df_to_arrow_c(&mut left, l_arr.as_mut_ptr(), l_sch.as_mut_ptr()), 0);
        assert_eq!(export_df_to_arrow_c(&mut right, r_arr.as_mut_ptr(), r_sch.as_mut_ptr()), 0);
        let mut l_arr = unsafe { l_arr.assume_init() };
        let mut l_sch = unsafe { l_sch.assume_init() };
        let mut r_arr = unsafe { r_arr.assume_init() };
        let mut r_sch = unsafe { r_sch.assume_init() };

        let key = CString::new("id").unwrap();
        for (how_s, expected_rows) in [
            ("inner", 2usize),
            ("left", 3),
            ("full", 4),
            ("semi", 2),
            ("anti", 1),
            ("cross", 9),
        ] {
            let mut j_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
            let mut j_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
            let how = CString::new(how_s).unwrap();
            let empty = CString::new("").unwrap();
            let (lon, ron) = if how_s == "cross" {
                (empty.as_ptr(), empty.as_ptr())
            } else {
                (key.as_ptr(), key.as_ptr())
            };
            assert_eq!(
                unsafe {
                    molars_join(
                        &l_arr,
                        &l_sch,
                        &r_arr,
                        &r_sch,
                        lon,
                        ron,
                        how.as_ptr(),
                        j_arr.as_mut_ptr(),
                        j_sch.as_mut_ptr(),
                    )
                },
                0,
                "join '{}' failed",
                how_s
            );
            let mut j_arr = unsafe { j_arr.assume_init() };
            let mut j_sch = unsafe { j_sch.assume_init() };
            let joined = unsafe { import_df_non_owning(&j_arr, &j_sch) }.unwrap();
            assert_eq!(joined.height(), expected_rows, "join '{}' row mismatch", how_s);
            unsafe {
                molars_release_array(&mut j_arr);
                molars_release_schema(&mut j_sch);
            }
        }

        unsafe {
            molars_release_array(&mut l_arr);
            molars_release_schema(&mut l_sch);
            molars_release_array(&mut r_arr);
            molars_release_schema(&mut r_sch);
        }
    }

    #[test]
    fn test_ffi_nulls_and_booleans() {
        let mut df = DataFrame::new(vec![
            Series::new("f".into(), &[Some(1.5f64), None, Some(3.5)]).into(),
            Series::new("i".into(), &[Some(10i64), Some(20), None]).into(),
            Series::new("s".into(), &[Some("a"), None, Some("c")]).into(),
            Series::new("b".into(), &[Some(true), Some(false), None]).into(),
        ])
        .unwrap();

        let mut arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        assert_eq!(export_df_to_arrow_c(&mut df, arr.as_mut_ptr(), sch.as_mut_ptr()), 0);
        let mut arr = unsafe { arr.assume_init() };
        let mut sch = unsafe { sch.assume_init() };

        let roundtrip = unsafe { import_df_non_owning(&arr, &sch) }.unwrap();
        assert_eq!(roundtrip.column("f").unwrap().f64().unwrap().get(1), None);
        assert_eq!(roundtrip.column("i").unwrap().i64().unwrap().get(2), None);
        assert_eq!(roundtrip.column("s").unwrap().str().unwrap().get(1), None);
        assert_eq!(roundtrip.column("b").unwrap().bool().unwrap().get(0), Some(true));
        assert_eq!(roundtrip.column("b").unwrap().bool().unwrap().get(1), Some(false));
        assert_eq!(roundtrip.column("b").unwrap().bool().unwrap().get(2), None);

        // drop_nulls all
        let mut dn_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut dn_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let empty = CString::new("").unwrap();
        assert_eq!(unsafe { molars_drop_nulls(&arr, &sch, empty.as_ptr(), dn_arr.as_mut_ptr(), dn_sch.as_mut_ptr()) }, 0);
        let mut dn_arr = unsafe { dn_arr.assume_init() };
        let mut dn_sch = unsafe { dn_sch.assume_init() };
        let dn_df = unsafe { import_df_non_owning(&dn_arr, &dn_sch) }.unwrap();
        assert_eq!(dn_df.height(), 1);

        // drop_nulls subset
        let mut dns_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut dns_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let sub = CString::new("f").unwrap();
        assert_eq!(unsafe { molars_drop_nulls(&arr, &sch, sub.as_ptr(), dns_arr.as_mut_ptr(), dns_sch.as_mut_ptr()) }, 0);
        let mut dns_arr = unsafe { dns_arr.assume_init() };
        let mut dns_sch = unsafe { dns_sch.assume_init() };
        let dns_df = unsafe { import_df_non_owning(&dns_arr, &dns_sch) }.unwrap();
        assert_eq!(dns_df.height(), 2);

        // fill_null_float64
        let mut ff_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut ff_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let col_f = CString::new("f").unwrap();
        assert_eq!(unsafe { molars_fill_null_float64(&arr, &sch, col_f.as_ptr(), 99.0, ff_arr.as_mut_ptr(), ff_sch.as_mut_ptr()) }, 0);
        let mut ff_arr = unsafe { ff_arr.assume_init() };
        let mut ff_sch = unsafe { ff_sch.assume_init() };
        let ff_df = unsafe { import_df_non_owning(&ff_arr, &ff_sch) }.unwrap();
        assert_eq!(ff_df.column("f").unwrap().f64().unwrap().get(1), Some(99.0));

        // fill_null_int64
        let mut fi_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut fi_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let col_i = CString::new("i").unwrap();
        assert_eq!(unsafe { molars_fill_null_int64(&arr, &sch, col_i.as_ptr(), 42, fi_arr.as_mut_ptr(), fi_sch.as_mut_ptr()) }, 0);
        let mut fi_arr = unsafe { fi_arr.assume_init() };
        let mut fi_sch = unsafe { fi_sch.assume_init() };
        let fi_df = unsafe { import_df_non_owning(&fi_arr, &fi_sch) }.unwrap();
        assert_eq!(fi_df.column("i").unwrap().i64().unwrap().get(2), Some(42));

        // fill_null_str
        let mut fs_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut fs_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let col_s = CString::new("s").unwrap();
        let fill_s = CString::new("missing").unwrap();
        assert_eq!(unsafe { molars_fill_null_str(&arr, &sch, col_s.as_ptr(), fill_s.as_ptr(), fs_arr.as_mut_ptr(), fs_sch.as_mut_ptr()) }, 0);
        let mut fs_arr = unsafe { fs_arr.assume_init() };
        let mut fs_sch = unsafe { fs_sch.assume_init() };
        let fs_df = unsafe { import_df_non_owning(&fs_arr, &fs_sch) }.unwrap();
        assert_eq!(fs_df.column("s").unwrap().str().unwrap().get(1), Some("missing"));

        // fill_null_strategy
        let mut fst_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut fst_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let strat = CString::new("forward").unwrap();
        assert_eq!(unsafe { molars_fill_null_strategy(&arr, &sch, col_f.as_ptr(), strat.as_ptr(), fst_arr.as_mut_ptr(), fst_sch.as_mut_ptr()) }, 0);
        let mut fst_arr = unsafe { fst_arr.assume_init() };
        let mut fst_sch = unsafe { fst_sch.assume_init() };
        let fst_df = unsafe { import_df_non_owning(&fst_arr, &fst_sch) }.unwrap();
        assert_eq!(fst_df.column("f").unwrap().f64().unwrap().get(1), Some(1.5));

        unsafe {
            molars_release_array(&mut fst_arr);
            molars_release_schema(&mut fst_sch);
            molars_release_array(&mut fs_arr);
            molars_release_schema(&mut fs_sch);
            molars_release_array(&mut fi_arr);
            molars_release_schema(&mut fi_sch);
            molars_release_array(&mut ff_arr);
            molars_release_schema(&mut ff_sch);
            molars_release_array(&mut dns_arr);
            molars_release_schema(&mut dns_sch);
            molars_release_array(&mut dn_arr);
            molars_release_schema(&mut dn_sch);
            molars_release_array(&mut arr);
            molars_release_schema(&mut sch);
        }
    }

    #[test]
    fn test_ffi_temporal_types() {
        let dates = Int32Chunked::from_iter_options("d".into(), [Some(19723), None, Some(19725)].into_iter())
            .into_date()
            .into_series();
        let datetimes = Int64Chunked::from_iter_options(
            "dt".into(),
            [Some(1_704_067_200_000_000i64), Some(1_704_153_600_000_000), None].into_iter(),
        )
        .into_datetime(TimeUnit::Microseconds, None)
        .into_series();
        let durations = Int64Chunked::from_iter_options("dur".into(), [Some(5000i64), Some(10000), Some(15000)].into_iter())
            .into_duration(TimeUnit::Milliseconds)
            .into_series();

        let mut df = DataFrame::new(vec![dates.into(), datetimes.into(), durations.into()]).unwrap();
        let mut arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        assert_eq!(export_df_to_arrow_c(&mut df, arr.as_mut_ptr(), sch.as_mut_ptr()), 0);
        let mut arr = unsafe { arr.assume_init() };
        let mut sch = unsafe { sch.assume_init() };

        let roundtrip = unsafe { import_df_non_owning(&arr, &sch) }.unwrap();
        assert_eq!(*roundtrip.column("d").unwrap().dtype(), DataType::Date);
        assert_eq!(
            *roundtrip.column("dt").unwrap().dtype(),
            DataType::Datetime(TimeUnit::Microseconds, None)
        );
        assert_eq!(
            *roundtrip.column("dur").unwrap().dtype(),
            DataType::Duration(TimeUnit::Milliseconds)
        );
        assert_eq!(roundtrip.column("d").unwrap().null_count(), 1);
        assert_eq!(roundtrip.column("dt").unwrap().null_count(), 1);
        assert_eq!(roundtrip.column("dur").unwrap().null_count(), 0);

        // Also test molars_read_csv_ex on a temporary CSV with dates
        let tmp_csv = "target/test_dates_tmp.csv";
        std::fs::write(tmp_csv, "dt,val\n2024-01-01,10\n2024-01-02,20\n").unwrap();
        let mut csv_arr = std::mem::MaybeUninit::<ffi::ArrowArray>::uninit();
        let mut csv_sch = std::mem::MaybeUninit::<ffi::ArrowSchema>::uninit();
        let c_tmp = CString::new(tmp_csv).unwrap();
        assert_eq!(
            unsafe { molars_read_csv_ex(c_tmp.as_ptr(), 1, csv_arr.as_mut_ptr(), csv_sch.as_mut_ptr()) },
            0
        );
        let mut csv_arr = unsafe { csv_arr.assume_init() };
        let mut csv_sch = unsafe { csv_sch.assume_init() };
        let csv_df = unsafe { import_df_non_owning(&csv_arr, &csv_sch) }.unwrap();
        assert_eq!(*csv_df.column("dt").unwrap().dtype(), DataType::Date);
        let _ = std::fs::remove_file(tmp_csv);

        unsafe {
            molars_release_array(&mut csv_arr);
            molars_release_schema(&mut csv_sch);
            molars_release_array(&mut arr);
            molars_release_schema(&mut sch);
        }
    }
}
