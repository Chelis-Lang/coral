module Coral.Tests.Internal
import Std.Test (assert_true, assert_eq, assert_eq_int, assert_eq_string, assert_close)
import Coral.Frame (
  Frame, Column, ColumnType,
  from_pairs, nrows, ncols, columns,
  sort_by, slice, head, tail,
  get_float_col, get_string_col,
  describe
)

-- These tests exercise internal frame algorithms via the public exports.
-- The chelis v0.2.4 test evaluator does not broadcast eq/neq/lt over tensors,
-- which prevents constructing IntCol/BoolCol values (their construction goes
-- through frame::bool_list_to_tensor). The internal-frame coverage below
-- focuses on the string-sort path (str_lt + enum_insertion_sort +
-- extract_perm_indices + reverse_ints + list_gather_string) and the
-- float/string slicing path, which all work end-to-end in the eval runtime.

def test_string_sort_lexicographic() -> unit ! { Test } = {
  -- Confirms str_lt + enum_insertion_sort + extract_perm_indices end-to-end:
  -- ascending lex order of ["paris","berlin","oslo"] is berlin < oslo < paris.
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", true)
  names = get_string_col(sorted, "city")
  _ = assert_eq_string(index(names, cast(0, int64)), "berlin", "first ascending is berlin");
  _ = assert_eq_string(index(names, cast(1, int64)), "oslo", "middle ascending is oslo");
  assert_eq_string(index(names, cast(2, int64)), "paris", "last ascending is paris")
}

def test_string_sort_descending() -> unit ! { Test } = {
  -- Confirms reverse_ints is applied after the ascending sort:
  -- descending of ["paris","berlin","oslo"] is paris > oslo > berlin.
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", false)
  names = get_string_col(sorted, "city")
  _ = assert_eq_string(index(names, cast(0, int64)), "paris", "first descending is paris");
  _ = assert_eq_string(index(names, cast(1, int64)), "oslo", "middle descending is oslo");
  assert_eq_string(index(names, cast(2, int64)), "berlin", "last descending is berlin")
}

def test_string_sort_stable_on_equal_prefix() -> unit ! { Test } = {
  -- Confirms str_lt walks past common prefixes and orders shorter < longer.
  -- "ab" < "abc" lexicographically; "abcd" > "abc". Sorted: ["ab","abc","abcd"].
  df = from_pairs([("s", StringCol(["abcd", "ab", "abc"]))])
  sorted = sort_by(df, "s", true)
  names = get_string_col(sorted, "s")
  _ = assert_eq_string(index(names, cast(0, int64)), "ab", "first is ab");
  _ = assert_eq_string(index(names, cast(1, int64)), "abc", "middle is abc");
  assert_eq_string(index(names, cast(2, int64)), "abcd", "last is abcd")
}

def test_slice_round_trip_preserves_floats() -> unit ! { Test } = {
  -- Exercises reindex_column on a FloatCol via slice: gather + to_list round-trip.
  df = from_pairs([("v", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32), cast(50.0, f32)])))])
  s = slice(df, cast(1, int64), cast(4, int64))
  vs = to_list(get_float_col(s, "v"))
  _ = assert_eq_int(len(vs), cast(3, int64), "slice length 3");
  _ = assert_close(index(vs, cast(0, int64)), cast(20.0, f32), cast(0.00001, f32), "slice[0] == 20");
  _ = assert_close(index(vs, cast(1, int64)), cast(30.0, f32), cast(0.00001, f32), "slice[1] == 30");
  assert_close(index(vs, cast(2, int64)), cast(40.0, f32), cast(0.00001, f32), "slice[2] == 40")
}

def test_slice_round_trip_preserves_strings() -> unit ! { Test } = {
  -- Exercises list_gather_string via slice on a StringCol.
  df = from_pairs([("s", StringCol(["a", "b", "c", "d", "e"]))])
  s = slice(df, cast(1, int64), cast(4, int64))
  ns = get_string_col(s, "s")
  _ = assert_eq_int(len(ns), cast(3, int64), "slice length 3");
  _ = assert_eq_string(index(ns, cast(0, int64)), "b", "slice[0] == b");
  _ = assert_eq_string(index(ns, cast(1, int64)), "c", "slice[1] == c");
  assert_eq_string(index(ns, cast(2, int64)), "d", "slice[2] == d")
}

def test_describe_skip_nan_count() -> unit ! { Test } = {
  -- describe on a FloatCol with one NaN should report count == 4 (NaNs are
  -- skipped via internal non_nan_values), not 5. Stat row 0 ("count") of
  -- the single value column "v" must equal 4.0.
  nan_v = div(cast(0.0, f32), cast(0.0, f32))
  df = from_pairs([("v", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), nan_v, cast(4.0, f32), cast(5.0, f32)])))])
  d = describe(df)
  _ = assert_eq_int(nrows(d), cast(8, int64), "describe has 8 rows");
  count_val = index(to_list(get_float_col(d, "v")), cast(0, int64))
  assert_close(count_val, cast(4.0, f32), cast(0.00001, f32), "skip-nan count == 4")
}
