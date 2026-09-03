from molars import DataFrame, Series

def test_csv() raises:
    var df = DataFrame.read_csv("scratch/sample.csv")
    var shape = df.shape()
    if shape[0] != 5 or shape[1] != 4:
        raise Error("Expected shape (5, 4), got (" + String(shape[0]) + ", " + String(shape[1]) + ")")

    var score_sum = df["score"].sum_float64()
    if score_sum < 435.49 or score_sum > 435.51:
        raise Error("score sum mismatch")

    var count_sum = df["count"].sum_int64()
    if count_sum != 150:
        raise Error("count sum mismatch: " + String(count_sum))

    if df["name"].get_as_string(0) != "Alice":
        raise Error("expected Alice, got " + df["name"].get_as_string(0))
    _ = df

def test_parquet() raises:
    var df = DataFrame.read_parquet("scratch/sample.parquet")
    var shape = df.shape()
    if shape[0] != 5 or shape[1] != 4:
        raise Error("Expected shape (5, 4), got (" + String(shape[0]) + ", " + String(shape[1]) + ")")

    var score_sum = df["score"].sum_float64()
    if score_sum < 435.49 or score_sum > 435.51:
        raise Error("parquet score sum mismatch")
    _ = df

def test_sql() raises:
    var df = DataFrame.sql(
        "SELECT name, score FROM sample WHERE score > 85.0",
        "sample",
        "scratch/sample.parquet",
    )
    if df.height() != 3 or df.width() != 2:
        raise Error("expected shape (3, 2), got (" + String(df.height()) + ", " + String(df.width()) + ")")
    _ = df

def main() raises:
    test_csv()
    print("test_csv ... ok")
    test_parquet()
    print("test_parquet ... ok")
    test_sql()
    print("test_sql ... ok")
