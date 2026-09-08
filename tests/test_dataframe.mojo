from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_almost_equal,
)
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


def test_writers() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    # Test CSV write and readback
    df.write_csv("tests/test_roundtrip.csv")
    var csv_df = DataFrame.read_csv("tests/test_roundtrip.csv")
    assert_equal(csv_df.height(), 5)
    assert_equal(csv_df.width(), 4)
    assert_almost_equal(csv_df["score"].sum_float64(), 435.5, atol=0.01)
    assert_equal(csv_df["name"].get_string(0), "Alice")

    # Test Parquet write and readback
    df.write_parquet("tests/test_roundtrip.parquet")
    var pq_df = DataFrame.read_parquet("tests/test_roundtrip.parquet")
    assert_equal(pq_df.height(), 5)
    assert_equal(pq_df.width(), 4)
    assert_almost_equal(pq_df["score"].sum_float64(), 435.5, atol=0.01)
    assert_equal(pq_df["name"].get_string(1), "Bob")
    _ = df
    _ = csv_df
    _ = pq_df


def test_slicing() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    # Test head(2)
    var head_df = df.head(2)
    assert_equal(head_df.height(), 2)
    assert_equal(head_df.width(), 4)
    assert_equal(head_df["name"].get_string(0), "Alice")
    assert_equal(head_df["name"].get_string(1), "Bob")

    # Test tail(2)
    var tail_df = df.tail(2)
    assert_equal(tail_df.height(), 2)
    assert_equal(tail_df.width(), 4)
    assert_equal(tail_df["name"].get_string(0), "David")
    assert_equal(tail_df["name"].get_string(1), "Eve")
    _ = df
    _ = head_df
    _ = tail_df


def test_projection() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    # Test select
    var sel_cols = List[String]()
    sel_cols.append("name")
    sel_cols.append("score")
    var sel_df = df.select(sel_cols)
    assert_equal(sel_df.width(), 2)
    assert_equal(sel_df.column_names()[0], "name")
    assert_equal(sel_df.column_names()[1], "score")
    assert_equal(sel_df["name"].get_string(0), "Alice")

    # Test drop
    var drop_cols = List[String]()
    drop_cols.append("count")
    var drop_df = df.drop(drop_cols)
    assert_equal(drop_df.width(), 3)
    assert_equal(drop_df.column_names()[0], "id")
    assert_equal(drop_df.column_names()[1], "name")
    assert_equal(drop_df.column_names()[2], "score")
    _ = df
    _ = sel_df
    _ = drop_df


def test_rename() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var renamed = df.rename("score", "rating")
    assert_equal(renamed.width(), 4)
    assert_equal(renamed.column_names()[2], "rating")
    assert_almost_equal(renamed["rating"].sum_float64(), 435.5, atol=0.01)
    _ = df
    _ = renamed


def test_simd_reductions() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var score_col = df["score"]

    # Explicit type methods
    assert_almost_equal(score_col.min_float64(), 78.5, atol=0.01)
    assert_almost_equal(score_col.max_float64(), 95.5, atol=0.01)
    assert_almost_equal(score_col.mean_float64(), 87.1, atol=0.01)
    assert_almost_equal(score_col.var_float64(ddof=1), 47.675, atol=0.01)
    assert_almost_equal(score_col.std_float64(ddof=1), 6.9047, atol=0.01)

    var count_col = df["count"]
    assert_equal(count_col.min_int64(), 10)
    assert_equal(count_col.max_int64(), 50)
    assert_almost_equal(count_col.mean_int64(), 30.0, atol=0.01)

    # High-level dispatch methods
    assert_almost_equal(score_col.min(), 78.5, atol=0.01)
    assert_almost_equal(score_col.max(), 95.5, atol=0.01)
    assert_almost_equal(score_col.sum(), 435.5, atol=0.01)
    assert_almost_equal(score_col.mean(), 87.1, atol=0.01)
    assert_almost_equal(score_col.var(ddof=1), 47.675, atol=0.01)
    assert_almost_equal(score_col.std(ddof=1), 6.9047, atol=0.01)

    assert_almost_equal(count_col.min(), 10.0, atol=0.01)
    assert_almost_equal(count_col.max(), 50.0, atol=0.01)
    assert_almost_equal(count_col.sum(), 150.0, atol=0.01)
    assert_almost_equal(count_col.mean(), 30.0, atol=0.01)
    _ = df


def test_elementwise_simd() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var score_col = df["score"]

    # Series + Series
    var doubled = score_col + score_col
    assert_equal(len(doubled), 5)
    assert_almost_equal(doubled[0], 191.0, atol=0.01)
    assert_almost_equal(doubled[1], 164.0, atol=0.01)

    # Series - Series
    var diff = score_col - score_col
    assert_equal(len(diff), 5)
    assert_almost_equal(diff[0], 0.0, atol=0.01)

    # Series * Scalar
    var scaled = score_col * 2.0
    assert_equal(len(scaled), 5)
    assert_almost_equal(scaled[0], 191.0, atol=0.01)

    # Series + Scalar
    var shifted = score_col + 10.0
    assert_equal(len(shifted), 5)
    assert_almost_equal(shifted[0], 105.5, atol=0.01)

    # Series / Scalar
    var halved = score_col / 2.0
    assert_equal(len(halved), 5)
    assert_almost_equal(halved[0], 47.75, atol=0.01)
    _ = df


def test_series_apply() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var score_col = df["score"]

    # 1. apply_float64 with named function
    def square_fn(x: Float64) -> Float64:
        return x * x

    var squared = score_col.apply_float64(square_fn)
    assert_equal(len(squared), 5)
    assert_almost_equal(squared[0], 95.5 * 95.5, atol=0.01)

    # 2. apply with state-capturing closure
    var boost = 5.0

    def boost_fn(x: Float64) raises {imm boost} -> Float64:
        return x + boost

    var boosted = score_col.apply(boost_fn)
    assert_equal(len(boosted), 5)
    assert_almost_equal(boosted[0], 100.5, atol=0.01)

    # 3. apply_int64 on integer column
    var count_col = df["count"]

    def double_int(x: Int64) -> Int64:
        return x * 2

    var doubled_counts = count_col.apply_int64(double_int)
    assert_equal(len(doubled_counts), 5)
    assert_equal(doubled_counts[0], 20)
    assert_equal(doubled_counts[1], 40)
    _ = df


def test_dataframe_groupby() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    # 1. Fluent group_by.agg with custom alias
    var grp = df.group_by(["name"]).agg(
        "score:sum:total_score,score:mean,count:sum"
    )
    assert_equal(grp.height(), 5)
    assert_equal(grp.width(), 4)
    assert_equal(grp.column_names()[0], "name")
    assert_equal(grp.column_names()[1], "total_score")
    assert_equal(grp.column_names()[2], "score_mean")
    assert_equal(grp.column_names()[3], "count_sum")

    # 2. group_by.sum
    var sum_df = df.group_by("name").sum("score")
    assert_equal(sum_df.height(), 5)
    assert_equal(sum_df.width(), 2)

    # 3. group_by.mean
    var mean_df = df.group_by("name").mean("score")
    assert_equal(mean_df.height(), 5)
    assert_equal(mean_df.width(), 2)

    # 4. group_by.count
    var count_df = df.group_by("name").count()
    assert_equal(count_df.height(), 5)
    assert_equal(count_df.width(), 2)
    assert_equal(count_df.column_names()[1], "count")

    # 5. Direct convenience group_by(keys, aggs)
    var direct_df = df.group_by("name", "score:max")
    assert_equal(direct_df.height(), 5)
    assert_equal(direct_df.width(), 2)
    assert_equal(direct_df.column_names()[1], "score_max")
    _ = df
    _ = grp
    _ = sum_df
    _ = mean_df
    _ = count_df
    _ = direct_df


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
