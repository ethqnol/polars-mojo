from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_false,
    assert_almost_equal,
)
from molars import DataFrame, Series, BooleanSeries


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


def test_boolean_series_and_comparisons() raises:
    var df = DataFrame.read_csv("tests/sample.csv")
    var score = df["score"]
    var count = df["count"]
    var name = df["name"]

    var high_score = score > 85.0
    assert_equal(len(high_score), 5)
    assert_equal(high_score.sum(), 3)
    assert_true(high_score[0])
    assert_false(high_score[1])
    assert_true(high_score.any())
    assert_false(high_score.all())

    var mid_count = (count >= 20) & (count <= 40)
    assert_equal(mid_count.sum(), 3)

    var combined = high_score | mid_count
    assert_equal(combined.sum(), 5)
    assert_true(combined.all())

    var inverted = ~high_score
    assert_equal(inverted.sum(), 2)
    assert_equal((high_score ^ mid_count).sum(), 4)

    var eq_alice = name == "Alice"
    assert_equal(eq_alice.sum(), 1)
    assert_true(eq_alice[0])

    var contains_li = name.str_contains("li")
    assert_equal(contains_li.sum(), 2)  # Alice, Charlie
    assert_true(name.str_starts_with("Al")[0])
    assert_true(name.str_ends_with("ve")[4])

    var self_eq = count == count
    assert_true(self_eq.all())
    _ = df


def test_filter() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    var filtered = df.filter(df["score"] > 85.0)
    assert_equal(filtered.height(), 3)
    assert_equal(filtered["name"].get_string(0), "Alice")
    assert_equal(filtered["name"].get_string(1), "David")
    assert_equal(filtered["name"].get_string(2), "Eve")

    var compound = df.filter((df["score"] > 80.0) & (df["count"] <= 30))
    assert_equal(compound.height(), 2)
    assert_equal(compound["name"].get_string(0), "Alice")
    assert_equal(compound["name"].get_string(1), "Bob")

    var list_mask: List[Bool] = [True, False, False, False, True]
    var list_filtered = df.filter(list_mask)
    assert_equal(list_filtered.height(), 2)
    assert_equal(list_filtered["name"].get_string(0), "Alice")
    assert_equal(list_filtered["name"].get_string(1), "Eve")
    _ = df
    _ = filtered
    _ = compound
    _ = list_filtered


def test_sort() raises:
    var df = DataFrame.read_csv("tests/sample.csv")

    var asc = df.sort("score")
    assert_almost_equal(asc["score"].get_float64(0), 78.5, atol=0.01)
    assert_equal(asc["name"].get_string(0), "Charlie")
    assert_almost_equal(asc["score"].get_float64(4), 95.5, atol=0.01)

    var desc = df.sort("score", descending=True)
    assert_almost_equal(desc["score"].get_float64(0), 95.5, atol=0.01)
    assert_equal(desc["name"].get_string(0), "Alice")

    with open("target/tmp_sort_multi.csv", "w") as f:
        f.write("grp,val\n1,10\n1,30\n2,5\n2,20\n")
    var mdf = DataFrame.read_csv("target/tmp_sort_multi.csv")
    var msorted = mdf.sort(["grp", "val"], [False, True])
    assert_equal(msorted["grp"].get_int64(0), 1)
    assert_equal(msorted["val"].get_int64(0), 30)
    assert_equal(msorted["val"].get_int64(1), 10)
    assert_equal(msorted["grp"].get_int64(2), 2)
    assert_equal(msorted["val"].get_int64(2), 20)
    assert_equal(msorted["val"].get_int64(3), 5)

    _ = df
    _ = asc
    _ = desc
    _ = mdf
    _ = msorted


def test_join() raises:
    with open("target/tmp_join_left.csv", "w") as f:
        f.write("id,name\n1,Alice\n2,Bob\n3,Charlie\n")
    with open("target/tmp_join_right.csv", "w") as f:
        f.write("id,dept\n2,Eng\n3,Sales\n4,HR\n")
    with open("target/tmp_join_right_renamed.csv", "w") as f:
        f.write("user_id,dept\n2,Eng\n3,Sales\n4,HR\n")

    var left = DataFrame.read_csv("target/tmp_join_left.csv")
    var right = DataFrame.read_csv("target/tmp_join_right.csv")
    var right2 = DataFrame.read_csv("target/tmp_join_right_renamed.csv")

    var inner = left.join(right, "id", "inner").sort("id")
    assert_equal(inner.height(), 2)
    assert_equal(inner["name"].get_string(0), "Bob")
    assert_equal(inner["dept"].get_string(0), "Eng")

    var left_j = left.join(right, on="id", how="left").sort("id")
    assert_equal(left_j.height(), 3)
    assert_true(left_j["dept"].is_null(0))
    assert_equal(left_j["dept"].get_as_string(0), "null")
    assert_equal(left_j["dept"].get_string(1), "Eng")

    var full_j = left.join(right, on="id", how="full")
    assert_equal(full_j.height(), 4)

    var semi_j = left.join(right, on="id", how="semi")
    assert_equal(semi_j.height(), 2)
    assert_equal(semi_j.width(), 2)

    var anti_j = left.join(right, on="id", how="anti")
    assert_equal(anti_j.height(), 1)
    assert_equal(anti_j["name"].get_string(0), "Alice")

    var cross_j = left.join(right, how="cross")
    assert_equal(cross_j.height(), 9)

    var diff_keys = left.join(right2, left_on="id", right_on="user_id", how="inner")
    assert_equal(diff_keys.height(), 2)

    _ = left
    _ = right
    _ = right2
    _ = inner
    _ = left_j
    _ = full_j
    _ = semi_j
    _ = anti_j
    _ = cross_j
    _ = diff_keys


def test_null_handling() raises:
    with open("target/tmp_nulls.csv", "w") as f:
        f.write("id,val,tag,flag\n1,10.0,a,true\n2,,b,false\n3,30.0,,\n4,,,true\n")

    var df = DataFrame.read_csv("target/tmp_nulls.csv")
    var val = df["val"]
    var flag = df["flag"]

    assert_true(val.has_nulls())
    assert_equal(val.count_nulls(), 2)
    assert_false(val.is_null(0))
    assert_true(val.is_valid(0))
    assert_true(val.is_null(1))
    assert_equal(val.get_as_string(1), "null")

    var null_mask = val.is_null()
    assert_equal(null_mask.sum(), 2)
    assert_true(null_mask[1])
    assert_true(null_mask[3])

    var not_null_mask = val.is_not_null()
    assert_equal(not_null_mask.sum(), 2)

    var filled_vals = val.fill_null(0.0)
    assert_almost_equal(filled_vals[1], 0.0, atol=0.01)
    assert_almost_equal(filled_vals[2], 30.0, atol=0.01)

    var filled_tags = df["tag"].fill_null_string("none")
    assert_equal(filled_tags[2], "none")

    assert_true(flag.get_bool(0))
    assert_false(flag.get_bool(1))
    var b_series = flag.to_bool_series()
    assert_equal(b_series.sum(), 2)

    var dn_all = df.drop_nulls()
    assert_equal(dn_all.height(), 1)
    var dn_sub = df.drop_nulls("val")
    assert_equal(dn_sub.height(), 2)

    var ff_df = df.fill_null("val", -1.0)
    assert_almost_equal(ff_df["val"].get_float64(1), -1.0, atol=0.01)

    var fs_df = df.fill_null("tag", "missing")
    assert_equal(fs_df["tag"].get_string(2), "missing")

    var ffill_df = df.fill_null_strategy("forward", "val")
    assert_almost_equal(ffill_df["val"].get_float64(1), 10.0, atol=0.01)
    assert_almost_equal(ffill_df["val"].get_float64(3), 30.0, atol=0.01)

    var sorted_nl = df.sort("val", descending=False, nulls_last=True)
    assert_almost_equal(sorted_nl["val"].get_float64(0), 10.0, atol=0.01)
    assert_true(sorted_nl["val"].is_null(2))
    assert_true(sorted_nl["val"].is_null(3))

    _ = df
    _ = dn_all
    _ = dn_sub
    _ = ff_df
    _ = fs_df
    _ = ffill_df
    _ = sorted_nl


def test_temporal_types() raises:
    with open("target/tmp_temporal.csv", "w") as f:
        f.write("dt,ts,val\n2024-01-01,2024-01-01 00:00:00,10\n2024-01-03,2024-01-03 12:30:45,30\n,,20\n")

    var df = DataFrame.read_csv("target/tmp_temporal.csv", try_parse_dates=True)
    var dt = df["dt"]
    var ts = df["ts"]

    assert_true(dt.is_date())
    assert_true(dt.is_temporal())
    assert_equal(dt.temporal_unit(), "d")
    assert_equal(dt.get_date_days(0), 19723)
    assert_equal(dt.get_date_iso(0), "2024-01-01")
    assert_equal(dt.get_date_iso(1), "2024-01-03")
    assert_equal(dt.get_date_iso(2), "null")
    assert_equal(dt.get_as_string(0), "2024-01-01")

    assert_true(ts.is_datetime())
    assert_equal(ts.get_datetime_iso(0), "2024-01-01T00:00:00")
    assert_equal(ts.get_datetime_iso(1), "2024-01-03T12:30:45")
    assert_equal(ts.get_datetime_iso(2), "null")

    var clean = df.filter(dt.is_not_null())
    assert_equal(clean.height(), 2)
    var sorted_dt = clean.sort("dt", descending=True)
    assert_equal(sorted_dt["dt"].get_date_iso(0), "2024-01-03")

    # Test Duration column via Parquet roundtrip + SQL timestamp subtraction
    df.write_parquet("target/tmp_temporal.parquet")
    var dur_df = DataFrame.sql(
        "SELECT (ts - CAST(dt AS TIMESTAMP)) AS elapsed FROM tbl WHERE dt IS NOT NULL",
        "tbl",
        "target/tmp_temporal.parquet",
    )
    var elapsed = dur_df["elapsed"]
    assert_true(elapsed.is_duration())
    assert_true(elapsed.is_temporal())
    assert_equal(elapsed.get_duration(0), 0)
    assert_true(elapsed.get_duration(1) > 0)
    assert_equal(elapsed.get_duration_string(0), "0us")
    assert_equal(elapsed.get_duration_string(1), "45045000000us")

    _ = df
    _ = clean
    _ = sorted_dt
    _ = dur_df


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
