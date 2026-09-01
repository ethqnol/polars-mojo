#[cfg(test)]
mod tests {
    use crate::*;
    use polars_arrow::ffi;
    use std::ffi::CString;

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

    #[test]
    fn test_export_1m() {
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
}
