from std.testing import TestSuite, assert_equal, assert_true, assert_almost_equal
from molars import DataFrame, Series

def test_csv() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var shape = df.shape()
    assert_equal(shape[0], 5)
    assert_equal(shape[1], 4)

    var score_col = df["score"]
    assert_equal(score_col.len(), 5)
    assert_almost_equal(score_col.sum_float64(), 435.5, atol=0.01)

    var count_col = df["count"]
    assert_equal(count_col.sum_int64(), 150)

    var name_col = df["name"]
    assert_equal(name_col.get_string(0), "Alice")
    assert_equal(name_col.get_string(2), "Charlie")
    _ = df

def test_parquet() raises:
    var df = DataFrame.read_parquet("tests/sample.parquet")
    var shape = df.shape()
    assert_equal(shape[0], 5)
    assert_equal(shape[1], 4)

    assert_almost_equal(df["score"].sum_float64(), 435.5, atol=0.01)
    _ = df

def test_sql() raises:
    var df = DataFrame.sql(
        "SELECT name, score FROM sample WHERE score > 85.0",
        "sample",
        "tests/sample.parquet",
    )
    assert_equal(df.height(), 3)
    assert_equal(df.width(), 2)
    assert_equal(df["name"].get_string(0), "Alice")
    assert_equal(df["name"].get_string(1), "David")
    assert_equal(df["name"].get_string(2), "Eve")
    _ = df

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
