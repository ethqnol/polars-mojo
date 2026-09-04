from std.sys.info import size_of
from std.testing import TestSuite, assert_equal
from std.memory.alloc import unsafe_alloc
from molars.arrow_abi import ArrowArray, ArrowSchema, null_ptr
from molars.bridge import MolarsBridge

def test_arrow_schema_size() raises:
    assert_equal(size_of[ArrowSchema](), 72)

def test_arrow_array_size() raises:
    assert_equal(size_of[ArrowArray](), 80)

def test_release_null_safety() raises:
    var dummy_array = unsafe_alloc[ArrowArray](1)
    dummy_array[].release = null_ptr[NoneType]()
    MolarsBridge.release_array(dummy_array)
    dummy_array.unsafe_free()

    var dummy_schema = unsafe_alloc[ArrowSchema](1)
    dummy_schema[].release = null_ptr[NoneType]()
    MolarsBridge.release_schema(dummy_schema)
    dummy_schema.unsafe_free()

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
