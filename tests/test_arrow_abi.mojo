from std.sys.info import size_of
from molars.arrow_abi import ArrowArray, ArrowSchema, ManagedArrowTable, null_ptr
from molars.bridge import MolarsBridge

def main() raises:
    if size_of[ArrowSchema]() != 72:
        raise Error("ArrowSchema size mismatch, expected 72 bytes")

    if size_of[ArrowArray]() != 80:
        raise Error("ArrowArray size mismatch, expected 80 bytes")

    var dummy_array = alloc[ArrowArray](1)
    dummy_array[].release = null_ptr[NoneType]()
    MolarsBridge.release_array(dummy_array)
    dummy_array.unsafe_free()

    var dummy_schema = alloc[ArrowSchema](1)
    dummy_schema[].release = null_ptr[NoneType]()
    MolarsBridge.release_schema(dummy_schema)
    dummy_schema.unsafe_free()

    print("test_arrow_abi ... ok")

