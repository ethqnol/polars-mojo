from std.algorithm import vectorize
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from molars.arrow_abi import (
    ArrowArray,
    ArrowSchema,
    ManagedArrowTable,
    null_ptr,
)
from molars.bridge import MolarsBridge


@fieldwise_init
struct Series(Copyable, Movable):
    """A zero-copy typed view over a single Apache Arrow array.

    Provides direct buffer pointer access and hardware-accelerated SIMD
    reductions over numeric and string Arrow columns.

    Traits:
        Copyable: Supports deep copying of Series metadata.
        Movable: Supports move semantics.

    Fields:
        name: Name of the column.
        format: Arrow format string descriptor (e.g. 'g' for f64, 'l' for i64, 'vu' for StringView).
        length: Number of rows in the series.
        null_count: Number of null values in the column.
        n_buffers: Number of backing memory buffers.
        buffers: Pointer array to underlying Arrow buffers.
    """

    var name: String
    var format: String
    var length: Int
    var offset: Int
    var null_count: Int
    var n_buffers: Int
    var buffers: Pointer[
        Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin
    ]

    def len(self) -> Int:
        """Returns the number of elements in the series.

        Returns:
            Row count as an Int.
        """
        return self.length

    def as_float64_ptr(self) raises -> Pointer[Float64, MutUntrackedOrigin]:
        """Returns a typed pointer to the underlying Float64 buffer.

        Returns:
            Pointer to contiguous 64-bit float array.

        Raises:
            Error: If the series format is not 'g' (Float64).
        """
        if self.format != "g":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Float64 ('g')"
            )
        return (
            self.buffers[unsafe_offset=1]
            .unsafe_bitcast[Float64]()
            .unsafe_offset(self.offset)
        )

    def as_float32_ptr(self) raises -> Pointer[Float32, MutUntrackedOrigin]:
        """Returns a typed pointer to the underlying Float32 buffer.

        Returns:
            Pointer to contiguous 32-bit float array.

        Raises:
            Error: If the series format is not 'f' (Float32).
        """
        if self.format != "f":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Float32 ('f')"
            )
        return (
            self.buffers[unsafe_offset=1]
            .unsafe_bitcast[Float32]()
            .unsafe_offset(self.offset)
        )

    def as_int64_ptr(self) raises -> Pointer[Int64, MutUntrackedOrigin]:
        """Returns a typed pointer to the underlying Int64 buffer.

        Returns:
            Pointer to contiguous 64-bit signed integer array.

        Raises:
            Error: If the series format is not 'l' (Int64).
        """
        if self.format != "l":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Int64 ('l')"
            )
        return (
            self.buffers[unsafe_offset=1]
            .unsafe_bitcast[Int64]()
            .unsafe_offset(self.offset)
        )

    def as_int32_ptr(self) raises -> Pointer[Int32, MutUntrackedOrigin]:
        """Returns a typed pointer to the underlying Int32 buffer.

        Returns:
            Pointer to contiguous 32-bit signed integer array.

        Raises:
            Error: If the series format is not 'i' (Int32).
        """
        if self.format != "i":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Int32 ('i')"
            )
        return (
            self.buffers[unsafe_offset=1]
            .unsafe_bitcast[Int32]()
            .unsafe_offset(self.offset)
        )

    def get_float64(self, idx: Int) raises -> Float64:
        """Returns the Float64 scalar at the specified row index.

        Args:
            idx: Zero-based row index.

        Returns:
            Float64 value at index.

        Raises:
            Error: If the series is not Float64 or index is invalid.
        """
        var ptr = self.as_float64_ptr()
        return ptr[unsafe_offset=idx]

    def get_float32(self, idx: Int) raises -> Float32:
        """Returns the Float32 scalar at the specified row index.

        Args:
            idx: Zero-based row index.

        Returns:
            Float32 value at index.

        Raises:
            Error: If the series is not Float32 or index is invalid.
        """
        var ptr = self.as_float32_ptr()
        return ptr[unsafe_offset=idx]

    def get_int64(self, idx: Int) raises -> Int64:
        """Returns the Int64 scalar at the specified row index.

        Args:
            idx: Zero-based row index.

        Returns:
            Int64 value at index.

        Raises:
            Error: If the series is not Int64 or index is invalid.
        """
        var ptr = self.as_int64_ptr()
        return ptr[unsafe_offset=idx]

    def get_int32(self, idx: Int) raises -> Int32:
        """Returns the Int32 scalar at the specified row index.

        Args:
            idx: Zero-based row index.

        Returns:
            Int32 value at index.

        Raises:
            Error: If the series is not Int32 or index is invalid.
        """
        var ptr = self.as_int32_ptr()
        return ptr[unsafe_offset=idx]

    def get_string(self, idx: Int) raises -> String:
        """Returns the string at the specified row index.

        Supports Utf8 ('u'), LargeUtf8 ('U'), and Arrow StringView ('vu').

        Args:
            idx: Zero-based row index.

        Returns:
            Decoded UTF-8 string.

        Raises:
            Error: If the series is not a string column format.
        """
        if self.format != "u" and self.format != "U" and self.format != "vu":
            raise Error(
                "Series '"
                + self.name
                + "' is not a string column (format '"
                + self.format
                + "')"
            )
        return self.get_as_string(idx)

    def get_as_string(self, idx: Int) -> String:
        """Formats the value at index as a string across all supported data types.

        Args:
            idx: Zero-based row index.

        Returns:
            String representation of the element.
        """
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
            var start = Int(off_ptr[unsafe_offset=self.offset + idx])
            var end = Int(off_ptr[unsafe_offset=self.offset + idx + 1])
            var str_bytes = self.buffers[unsafe_offset=2].unsafe_bitcast[
                UInt8
            ]()
            var s = String("")
            for i in range(start, end):
                s += chr(Int(str_bytes[unsafe_offset=i]))
            return s
        elif self.format == "U":
            # LargeUtf8: buffers[1] is 64-bit offsets, buffers[2] is bytes
            var off_ptr = self.buffers[unsafe_offset=1].unsafe_bitcast[Int64]()
            var start = Int(off_ptr[unsafe_offset=self.offset + idx])
            var end = Int(off_ptr[unsafe_offset=self.offset + idx + 1])
            var str_bytes = self.buffers[unsafe_offset=2].unsafe_bitcast[
                UInt8
            ]()
            var s = String("")
            for i in range(start, end):
                s += chr(Int(str_bytes[unsafe_offset=i]))
            return s
        elif self.format == "vu":
            # Utf8View (Arrow StringView): buffers[1] is 16-byte view descriptors
            # buffers[2..] are variadic data buffers
            var raw_views = self.buffers[unsafe_offset=1].unsafe_bitcast[
                UInt8
            ]()
            var view_base = (self.offset + idx) * 16
            var u32_ptr = raw_views.unsafe_offset(view_base).unsafe_bitcast[
                UInt32
            ]()
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
                var data_buf = self.buffers[
                    unsafe_offset=2 + buf_idx
                ].unsafe_bitcast[UInt8]()
                for i in range(str_len):
                    s += chr(Int(data_buf[unsafe_offset=offset + i]))
                return s
        else:
            return "<format " + self.format + ">"

    def sum_float64(self) raises -> Float64:
        """Computes the sum of all elements using SIMD vector loads.

        Returns:
            Total sum as Float64.

        Raises:
            Error: If the series format is not Float64 ('g').
        """
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
        """Computes the sum of all elements using SIMD vector loads.

        Returns:
            Total sum as Int64.

        Raises:
            Error: If the series format is not Int64 ('l').
        """
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
        """Computes the arithmetic mean of the series.

        Returns:
            Arithmetic mean as Float64, or 0.0 if empty.

        Raises:
            Error: If the series format is not Float64 ('g').
        """
        if self.length == 0:
            return 0.0
        return self.sum_float64() / Float64(self.length)

    def mean_int64(self) raises -> Float64:
        """Computes the arithmetic mean of the series.

        Returns:
            Arithmetic mean as Float64, or 0.0 if empty.

        Raises:
            Error: If the series format is not Int64 ('l').
        """
        if self.length == 0:
            return 0.0
        return Float64(self.sum_int64()) / Float64(self.length)

    def get_float(self, idx: Int) raises -> Float64:
        """Returns the element at idx as a Float64 scalar.

        Args:
            idx: Zero-based row index.

        Returns:
            Float64 scalar.

        Raises:
            Error: If the format is not convertible to Float64.
        """
        if self.format == "g":
            return self.get_float64(idx)
        elif self.format == "f":
            return Float64(self.get_float32(idx))
        elif self.format == "l":
            return Float64(self.get_int64(idx))
        elif self.format == "i":
            return Float64(self.get_int32(idx))
        else:
            raise Error(
                "Series '"
                + self.name
                + "' format '"
                + self.format
                + "' cannot be converted to Float64"
            )

    def sum_float32(self) raises -> Float32:
        """Computes the sum of all elements using SIMD vector loads for Float32.
        """
        var ptr = self.as_float32_ptr()
        var n = self.length
        var total = Float32(0.0)
        comptime simd_w = 8

        def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            total += v.reduce_add()

        vectorize[simd_w](n, add_chunk)
        return total

    def sum_int32(self) raises -> Int32:
        """Computes the sum of all elements using SIMD vector loads for Int32.
        """
        var ptr = self.as_int32_ptr()
        var n = self.length
        var total = Int32(0)
        comptime simd_w = 8

        def add_chunk[simd_width: Int](idx: Int) {mut total, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            total += v.reduce_add()

        vectorize[simd_w](n, add_chunk)
        return total

    def mean_float32(self) raises -> Float32:
        """Computes the arithmetic mean for Float32 series."""
        if self.length == 0:
            return 0.0
        return self.sum_float32() / Float32(self.length)

    def mean_int32(self) raises -> Float64:
        """Computes the arithmetic mean for Int32 series."""
        if self.length == 0:
            return 0.0
        return Float64(self.sum_int32()) / Float64(self.length)

    def min_float64(self) raises -> Float64:
        """Computes the minimum value in the Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute min of empty Series")
        var ptr = self.as_float64_ptr()
        var n = self.length
        var min_val = ptr[unsafe_offset=0]
        comptime simd_w = 4

        def min_chunk[simd_width: Int](idx: Int) {mut min_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_min()
            if m < min_val:
                min_val = m

        vectorize[simd_w](n, min_chunk)
        return min_val

    def max_float64(self) raises -> Float64:
        """Computes the maximum value in the Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute max of empty Series")
        var ptr = self.as_float64_ptr()
        var n = self.length
        var max_val = ptr[unsafe_offset=0]
        comptime simd_w = 4

        def max_chunk[simd_width: Int](idx: Int) {mut max_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_max()
            if m > max_val:
                max_val = m

        vectorize[simd_w](n, max_chunk)
        return max_val

    def min_int64(self) raises -> Int64:
        """Computes the minimum value in the Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute min of empty Series")
        var ptr = self.as_int64_ptr()
        var n = self.length
        var min_val = ptr[unsafe_offset=0]
        comptime simd_w = 4

        def min_chunk[simd_width: Int](idx: Int) {mut min_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_min()
            if m < min_val:
                min_val = m

        vectorize[simd_w](n, min_chunk)
        return min_val

    def max_int64(self) raises -> Int64:
        """Computes the maximum value in the Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute max of empty Series")
        var ptr = self.as_int64_ptr()
        var n = self.length
        var max_val = ptr[unsafe_offset=0]
        comptime simd_w = 4

        def max_chunk[simd_width: Int](idx: Int) {mut max_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_max()
            if m > max_val:
                max_val = m

        vectorize[simd_w](n, max_chunk)
        return max_val

    def min_float32(self) raises -> Float32:
        """Computes the minimum value in the Float32 Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute min of empty Series")
        var ptr = self.as_float32_ptr()
        var n = self.length
        var min_val = ptr[unsafe_offset=0]
        comptime simd_w = 8

        def min_chunk[simd_width: Int](idx: Int) {mut min_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_min()
            if m < min_val:
                min_val = m

        vectorize[simd_w](n, min_chunk)
        return min_val

    def max_float32(self) raises -> Float32:
        """Computes the maximum value in the Float32 Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute max of empty Series")
        var ptr = self.as_float32_ptr()
        var n = self.length
        var max_val = ptr[unsafe_offset=0]
        comptime simd_w = 8

        def max_chunk[simd_width: Int](idx: Int) {mut max_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_max()
            if m > max_val:
                max_val = m

        vectorize[simd_w](n, max_chunk)
        return max_val

    def min_int32(self) raises -> Int32:
        """Computes the minimum value in the Int32 Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute min of empty Series")
        var ptr = self.as_int32_ptr()
        var n = self.length
        var min_val = ptr[unsafe_offset=0]
        comptime simd_w = 8

        def min_chunk[simd_width: Int](idx: Int) {mut min_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_min()
            if m < min_val:
                min_val = m

        vectorize[simd_w](n, min_chunk)
        return min_val

    def max_int32(self) raises -> Int32:
        """Computes the maximum value in the Int32 Series using SIMD."""
        if self.length == 0:
            raise Error("Cannot compute max of empty Series")
        var ptr = self.as_int32_ptr()
        var n = self.length
        var max_val = ptr[unsafe_offset=0]
        comptime simd_w = 8

        def max_chunk[simd_width: Int](idx: Int) {mut max_val, imm ptr}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var m = v.reduce_max()
            if m > max_val:
                max_val = m

        vectorize[simd_w](n, max_chunk)
        return max_val

    def var_float64(self, ddof: Int = 1) raises -> Float64:
        """Computes sample variance of the Float64 Series using SIMD."""
        if self.length <= ddof:
            raise Error(
                "Not enough elements to compute variance with ddof="
                + String(ddof)
            )
        var mean = self.mean_float64()
        var ptr = self.as_float64_ptr()
        var n = self.length
        var total_sq_diff = Float64(0.0)
        comptime simd_w = 4

        def var_chunk[
            simd_width: Int
        ](idx: Int) {mut total_sq_diff, imm ptr, imm mean}:
            var v = ptr.unsafe_load[width=simd_width](idx)
            var diff = v - mean
            total_sq_diff += (diff * diff).reduce_add()

        vectorize[simd_w](n, var_chunk)
        return total_sq_diff / Float64(n - ddof)

    def std_float64(self, ddof: Int = 1) raises -> Float64:
        """Computes standard deviation of the Float64 Series using SIMD."""
        from std.math import sqrt

        return sqrt(self.var_float64(ddof))

    def sum(self) raises -> Float64:
        """Dynamically computes the sum across any numeric Series type."""
        if self.format == "g":
            return self.sum_float64()
        elif self.format == "f":
            return Float64(self.sum_float32())
        elif self.format == "l":
            return Float64(self.sum_int64())
        elif self.format == "i":
            return Float64(self.sum_int32())
        else:
            raise Error(
                "Series '"
                + self.name
                + "' format '"
                + self.format
                + "' does not support sum"
            )

    def mean(self) raises -> Float64:
        """Dynamically computes the mean across any numeric Series type."""
        if self.format == "g":
            return self.mean_float64()
        elif self.format == "f":
            return Float64(self.mean_float32())
        elif self.format == "l":
            return self.mean_int64()
        elif self.format == "i":
            return Float64(self.mean_int32())
        else:
            raise Error(
                "Series '"
                + self.name
                + "' format '"
                + self.format
                + "' does not support mean"
            )

    def min(self) raises -> Float64:
        """Dynamically computes the min across any numeric Series type."""
        if self.format == "g":
            return self.min_float64()
        elif self.format == "f":
            return Float64(self.min_float32())
        elif self.format == "l":
            return Float64(self.min_int64())
        elif self.format == "i":
            return Float64(self.min_int32())
        else:
            raise Error(
                "Series '"
                + self.name
                + "' format '"
                + self.format
                + "' does not support min"
            )

    def max(self) raises -> Float64:
        """Dynamically computes the max across any numeric Series type."""
        if self.format == "g":
            return self.max_float64()
        elif self.format == "f":
            return Float64(self.max_float32())
        elif self.format == "l":
            return Float64(self.max_int64())
        elif self.format == "i":
            return Float64(self.max_int32())
        else:
            raise Error(
                "Series '"
                + self.name
                + "' format '"
                + self.format
                + "' does not support max"
            )

    def var(self, ddof: Int = 1) raises -> Float64:
        """Dynamically computes variance across Float64 series."""
        return self.var_float64(ddof)

    def std(self, ddof: Int = 1) raises -> Float64:
        """Dynamically computes standard deviation across Float64 series."""
        return self.std_float64(ddof)

    def __add__(self, other: Series) raises -> List[Float64]:
        """Element-wise addition with another Series."""
        if self.length != other.length:
            raise Error(
                "Series lengths do not match: "
                + String(self.length)
                + " vs "
                + String(other.length)
            )
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g" and other.format == "g":
            var p1 = self.as_float64_ptr()
            var p2 = other.as_float64_ptr()

            def chunk[simd_width: Int](idx: Int) {imm p1, imm p2, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                var v2 = p2.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 + v2)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) + other.get_float(i)
        return res^

    def __add__(self, scalar: Float64) raises -> List[Float64]:
        """Scalar addition broadcasting across the Series."""
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g":
            var p1 = self.as_float64_ptr()

            def chunk[
                simd_width: Int
            ](idx: Int) {imm p1, imm scalar, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 + scalar)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) + scalar
        return res^

    def __radd__(self, scalar: Float64) raises -> List[Float64]:
        return self.__add__(scalar)

    def __sub__(self, other: Series) raises -> List[Float64]:
        """Element-wise subtraction with another Series."""
        if self.length != other.length:
            raise Error(
                "Series lengths do not match: "
                + String(self.length)
                + " vs "
                + String(other.length)
            )
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g" and other.format == "g":
            var p1 = self.as_float64_ptr()
            var p2 = other.as_float64_ptr()

            def chunk[simd_width: Int](idx: Int) {imm p1, imm p2, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                var v2 = p2.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 - v2)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) - other.get_float(i)
        return res^

    def __sub__(self, scalar: Float64) raises -> List[Float64]:
        """Scalar subtraction broadcasting across the Series."""
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g":
            var p1 = self.as_float64_ptr()

            def chunk[
                simd_width: Int
            ](idx: Int) {imm p1, imm scalar, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 - scalar)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) - scalar
        return res^

    def __mul__(self, other: Series) raises -> List[Float64]:
        """Element-wise multiplication with another Series."""
        if self.length != other.length:
            raise Error(
                "Series lengths do not match: "
                + String(self.length)
                + " vs "
                + String(other.length)
            )
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g" and other.format == "g":
            var p1 = self.as_float64_ptr()
            var p2 = other.as_float64_ptr()

            def chunk[simd_width: Int](idx: Int) {imm p1, imm p2, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                var v2 = p2.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 * v2)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) * other.get_float(i)
        return res^

    def __mul__(self, scalar: Float64) raises -> List[Float64]:
        """Scalar multiplication broadcasting across the Series."""
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g":
            var p1 = self.as_float64_ptr()

            def chunk[
                simd_width: Int
            ](idx: Int) {imm p1, imm scalar, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 * scalar)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) * scalar
        return res^

    def __rmul__(self, scalar: Float64) raises -> List[Float64]:
        return self.__mul__(scalar)

    def __truediv__(self, other: Series) raises -> List[Float64]:
        """Element-wise division with another Series."""
        if self.length != other.length:
            raise Error(
                "Series lengths do not match: "
                + String(self.length)
                + " vs "
                + String(other.length)
            )
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g" and other.format == "g":
            var p1 = self.as_float64_ptr()
            var p2 = other.as_float64_ptr()

            def chunk[simd_width: Int](idx: Int) {imm p1, imm p2, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                var v2 = p2.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 / v2)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) / other.get_float(i)
        return res^

    def __truediv__(self, scalar: Float64) raises -> List[Float64]:
        """Scalar division broadcasting across the Series."""
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        comptime simd_w = 4

        if self.format == "g":
            var p1 = self.as_float64_ptr()

            def chunk[
                simd_width: Int
            ](idx: Int) {imm p1, imm scalar, mut res_ptr}:
                var v1 = p1.unsafe_load[width=simd_width](idx)
                res_ptr.unsafe_store[width=simd_width](idx, v1 / scalar)

            vectorize[simd_w](n, chunk)
        else:
            for i in range(n):
                res[i] = self.get_float(i) / scalar
        return res^

    def apply_float64[
        Func: def(Float64) raises -> Float64
    ](self, func: Func) raises -> List[Float64]:
        """Applies a function or closure element-wise over the Float64 Series.

        Args:
            func: A function or closure mapping Float64 -> Float64 (can raise).

        Returns:
            A List[Float64] containing the transformed values.
        """
        if self.format != "g":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Float64 ('g')"
            )
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        var p = self.as_float64_ptr()
        for i in range(n):
            res_ptr[unsafe_offset=i] = func(p[unsafe_offset=i])
        return res^

    def apply_int64[
        Func: def(Int64) raises -> Int64
    ](self, func: Func) raises -> List[Int64]:
        """Applies a function or closure element-wise over the Int64 Series.

        Args:
            func: A function or closure mapping Int64 -> Int64 (can raise).

        Returns:
            A List[Int64] containing the transformed values.
        """
        if self.format != "l":
            raise Error(
                "Series '"
                + self.name
                + "' is format '"
                + self.format
                + "', not Int64 ('l')"
            )
        var n = self.length
        var res = List[Int64](capacity=n)
        res.resize(n, 0)
        var res_ptr = res.unsafe_ptr()
        var p = self.as_int64_ptr()
        for i in range(n):
            res_ptr[unsafe_offset=i] = func(p[unsafe_offset=i])
        return res^

    def apply[
        Func: def(Float64) raises -> Float64
    ](self, func: Func) raises -> List[Float64]:
        """Dynamically applies a function or closure element-wise over numeric column values.

        Converts non-Float64 numeric types to Float64 dynamically.

        Args:
            func: A function or closure mapping Float64 -> Float64 (can raise).

        Returns:
            A List[Float64] containing the transformed values.
        """
        var n = self.length
        var res = List[Float64](capacity=n)
        res.resize(n, 0.0)
        var res_ptr = res.unsafe_ptr()
        if self.format == "g":
            var p = self.as_float64_ptr()
            for i in range(n):
                res_ptr[unsafe_offset=i] = func(p[unsafe_offset=i])
        else:
            for i in range(n):
                res_ptr[unsafe_offset=i] = func(self.get_float(i))
        return res^


struct DataFrame(Movable, Writable):
    """An in-memory columnar table backed by an Apache Arrow StructArray.

    Traits:
        Movable: Supports move lifecycle semantics.
        Writable: Implements terminal pretty-printing via write_to.

    Fields:
        _table: RAII manager for underlying ArrowArray and ArrowSchema pointers.
        _col_names: Ordered list of column names.
        _col_formats: Ordered list of Arrow format type codes for each column.
    """

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
        """Reads a CSV file into a DataFrame using the Polars multithreaded reader.

        Args:
            path: Filesystem path to the CSV file.

        Returns:
            DataFrame populated with columns exported via the Arrow C Data Interface.

        Raises:
            Error: If the file path is invalid, parsing fails, or allocation fails.
        """
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.read_csv(path, array_ptr, schema_ptr)
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    @staticmethod
    def read_parquet(path: String) raises -> DataFrame:
        """Reads an Apache Parquet file into a DataFrame using the Polars reader.

        Args:
            path: Filesystem path to the Parquet file.

        Returns:
            DataFrame populated with columns exported via the Arrow C Data Interface.

        Raises:
            Error: If the file cannot be opened, metadata is corrupted, or parsing fails.
        """
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.read_parquet(path, array_ptr, schema_ptr)
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    @staticmethod
    def sql(
        query: String, table_name: String, file_path: String
    ) raises -> DataFrame:
        """Executes a SQL query against a dataset using the Polars SQLContext engine.

        Registers the dataset as a LazyFrame, applies query optimizations, and
        collects the result into an Arrow table.

        Args:
            query: SQL query string (e.g. "SELECT col_a, AVG(col_b) FROM tbl GROUP BY col_a").
            table_name: Table identifier to reference in the FROM clause.
            file_path: Filesystem path to the source CSV or Parquet file.

        Returns:
            DataFrame containing query results.

        Raises:
            Error: On invalid SQL syntax, plan execution error, or read failure.
        """
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.sql_query(
            query, table_name, file_path, array_ptr, schema_ptr
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def num_rows(self) -> Int:
        """Returns the number of rows in the table.

        Returns:
            Total row count as an Int.
        """
        return self._table.num_rows()

    def height(self) -> Int:
        """Returns the number of rows in the table.

        Returns:
            Total row count as an Int.
        """
        return self._table.num_rows()

    def num_cols(self) -> Int:
        """Returns the number of columns in the table.

        Returns:
            Total column count as an Int.
        """
        return len(self._col_names)

    def width(self) -> Int:
        """Returns the number of columns in the table.

        Returns:
            Total column count as an Int.
        """
        return len(self._col_names)

    def shape(self) -> Tuple[Int, Int]:
        """Returns table dimensions as a (height, width) tuple.

        Returns:
            Tuple containing (num_rows, num_cols).
        """
        return (self.height(), self.width())

    def column_names(self) -> List[String]:
        """Returns the ordered list of column names in the table.

        Returns:
            List of column name strings.
        """
        var res = List[String]()
        for i in range(len(self._col_names)):
            res.append(self._col_names[i])
        return res^

    def column_index(self, name: String) raises -> Int:
        """Finds the zero-based column index for a given column name.

        Args:
            name: Column name to search for.

        Returns:
            Zero-based integer column index.

        Raises:
            Error: If no column matches the provided name.
        """
        for i in range(len(self._col_names)):
            if self._col_names[i] == name:
                return i
        raise Error("Column not found: " + name)

    def column(self, name: String) raises -> Series:
        """Extracts a column Series by name with zero memory copies.

        Args:
            name: Column name to look up.

        Returns:
            Series view over the column's Arrow buffers.

        Raises:
            Error: If the column name is not found.
        """
        var idx = self.column_index(name)
        return self.column(idx)

    def column(self, idx: Int) raises -> Series:
        """Extracts a column Series by index with zero memory copies.

        Args:
            idx: Zero-based column index.

        Returns:
            Series view over the column's Arrow buffers.

        Raises:
            Error: If the index is out of range [0, num_cols - 1].
        """
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
            offset=Int(col_array.offset),
            null_count=null_cnt,
            n_buffers=n_bufs,
            buffers=bufs,
        )

    def __getitem__(self, name: String) raises -> Series:
        """Subscript indexing operator to retrieve a column by name.

        Args:
            name: Column name.

        Returns:
            Series view over the column's Arrow buffers.

        Raises:
            Error: If the column name does not exist.
        """
        return self.column(name)

    def __getitem__(self, idx: Int) raises -> Series:
        """Subscript indexing operator to retrieve a column by index.

        Args:
            idx: Zero-based column index.

        Returns:
            Series view over the column's Arrow buffers.

        Raises:
            Error: If index is out of bounds.
        """
        return self.column(idx)

    def write_csv(self, path: String) raises:
        """Writes the DataFrame to a CSV file.

        Args:
            path: Target filesystem path for the CSV output.

        Raises:
            Error: If writing to the file fails.
        """
        _ = MolarsBridge.write_csv(
            self._table.array_ptr, self._table.schema_ptr, path
        )

    def write_parquet(self, path: String) raises:
        """Writes the DataFrame to an Apache Parquet file.

        Args:
            path: Target filesystem path for the Parquet output.

        Raises:
            Error: If writing to the file fails.
        """
        _ = MolarsBridge.write_parquet(
            self._table.array_ptr, self._table.schema_ptr, path
        )

    def head(self, n: Int = 5) raises -> DataFrame:
        """Returns the first n rows of the DataFrame.

        Args:
            n: Number of rows to return (default 5).

        Returns:
            A new DataFrame containing the sliced rows.
        """
        var count = n
        if count < 0:
            count = 0
        if count > self.height():
            count = self.height()
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.slice_df(
            self._table.array_ptr,
            self._table.schema_ptr,
            0,
            count,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def tail(self, n: Int = 5) raises -> DataFrame:
        """Returns the last n rows of the DataFrame.

        Args:
            n: Number of rows to return (default 5).

        Returns:
            A new DataFrame containing the sliced rows.
        """
        var count = n
        if count < 0:
            count = 0
        if count > self.height():
            count = self.height()
        var offset = Int64(self.height() - count)
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.slice_df(
            self._table.array_ptr,
            self._table.schema_ptr,
            offset,
            count,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def select(self, columns: List[String]) raises -> DataFrame:
        """Projects a subset of columns from the DataFrame.

        Args:
            columns: List of column names to select.

        Returns:
            A new DataFrame containing only the selected columns.
        """
        var csv_cols = String("")
        for i in range(len(columns)):
            csv_cols += columns[i]
            if i + 1 < len(columns):
                csv_cols += ","
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.select_columns(
            self._table.array_ptr,
            self._table.schema_ptr,
            csv_cols,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def drop(self, columns: List[String]) raises -> DataFrame:
        """Returns a DataFrame without the specified columns.

        Args:
            columns: List of column names to exclude.

        Returns:
            A new DataFrame without the specified columns.
        """
        var csv_cols = String("")
        for i in range(len(columns)):
            csv_cols += columns[i]
            if i + 1 < len(columns):
                csv_cols += ","
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.drop_columns(
            self._table.array_ptr,
            self._table.schema_ptr,
            csv_cols,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def rename(self, old_name: String, new_name: String) raises -> DataFrame:
        """Renames a column in the DataFrame.

        Args:
            old_name: Existing column name.
            new_name: New column name.

        Returns:
            A new DataFrame with the column renamed.
        """
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.rename_column(
            self._table.array_ptr,
            self._table.schema_ptr,
            old_name,
            new_name,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def group_by(self, keys: List[String]) -> GroupBy:
        """Groups the DataFrame by the specified column names.

        Args:
            keys: List of column names to group by.

        Returns:
            A GroupBy object to perform aggregations.
        """
        var keys_csv = String("")
        for i in range(len(keys)):
            keys_csv += keys[i]
            if i + 1 < len(keys):
                keys_csv += ","
        return GroupBy(self._table.array_ptr, self._table.schema_ptr, keys_csv)

    def group_by(self, key: String) -> GroupBy:
        """Groups the DataFrame by a single column name or comma-separated column names.

        Args:
            key: Column name or comma-separated column names to group by.

        Returns:
            A GroupBy object to perform aggregations.
        """
        return GroupBy(self._table.array_ptr, self._table.schema_ptr, key)

    def group_by(self, keys: String, aggs: String) raises -> DataFrame:
        """Directly groups and aggregates the DataFrame.

        Args:
            keys: Grouping column names (comma-separated).
            aggs: Aggregation specifications (comma-separated, e.g. 'sales:sum,rating:mean').

        Returns:
            An aggregated DataFrame.
        """
        return self.group_by(keys).agg(aggs)

    def groupby(self, keys: List[String]) -> GroupBy:
        """Alias for group_by."""
        return self.group_by(keys)

    def groupby(self, key: String) -> GroupBy:
        """Alias for group_by."""
        return self.group_by(key)

    def groupby(self, keys: String, aggs: String) raises -> DataFrame:
        """Alias for group_by."""
        return self.group_by(keys, aggs)

    def write_to(self, mut writer: Some[Writer]):
        """Formats the DataFrame as an aligned ASCII preview table for terminal output.

        Args:
            writer: Output stream receiving formatted characters.
        """
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


@fieldwise_init
struct GroupBy(Copyable, Movable):
    """An intermediate groupby grouping object.

    Allows executing aggregations over grouped columns using Polars' multithreaded engine.
    """

    var _array: Pointer[ArrowArray, MutUntrackedOrigin]
    var _schema: Pointer[ArrowSchema, MutUntrackedOrigin]
    var _keys_csv: String

    def agg(self, aggs_csv: String) raises -> DataFrame:
        """Applies aggregations to the grouped DataFrame.

        Args:
            aggs_csv: Comma-separated list of aggregations in 'col:op' or 'col:op:alias' format.
                     Supported operations: 'sum', 'mean', 'avg', 'min', 'max', 'count', 'std', 'var', 'first', 'last'.

        Returns:
            An aggregated DataFrame.
        """
        var array_ptr = unsafe_alloc[ArrowArray](1)
        var schema_ptr = unsafe_alloc[ArrowSchema](1)
        _ = MolarsBridge.groupby_agg(
            self._array,
            self._schema,
            self._keys_csv,
            aggs_csv,
            array_ptr,
            schema_ptr,
        )
        var managed = ManagedArrowTable(array_ptr, schema_ptr)
        return DataFrame(managed^)

    def sum(self, cols_csv: String) raises -> DataFrame:
        """Computes sum for specified columns in the group."""
        var parts = cols_csv.split(",")
        var aggs = String("")
        for i in range(len(parts)):
            var c = String(parts[i].strip())
            aggs += c + ":sum"
            if i + 1 < len(parts):
                aggs += ","
        return self.agg(aggs)

    def mean(self, cols_csv: String) raises -> DataFrame:
        """Computes mean for specified columns in the group."""
        var parts = cols_csv.split(",")
        var aggs = String("")
        for i in range(len(parts)):
            var c = String(parts[i].strip())
            aggs += c + ":mean"
            if i + 1 < len(parts):
                aggs += ","
        return self.agg(aggs)

    def count(self) raises -> DataFrame:
        """Counts rows per group using the first key column."""
        var key_parts = self._keys_csv.split(",")
        var first_key = String(key_parts[0].strip())
        return self.agg(first_key + ":count:count")
