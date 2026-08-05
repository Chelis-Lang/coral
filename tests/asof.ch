module Coral.Tests.AsOf
import Std.Test (assert_close)
import Coral.AsOf (asof_lookup, asof_join, asof_lookup_list, asof_join_list)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def test_asof_lookup_exact_match() -> unit ! { Test } = {
  keys = to_tensor([cast(10, int64), cast(20, int64), cast(30, int64)])
  vals = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  found = asof_lookup(keys, vals, cast(20, int64), cast(-1.0, f32))
  assert_close(found, cast(2.0, f32), cast(1e-6, f32), "exact key returns exact value")
}
def test_asof_lookup_previous_match() -> unit ! { Test } = {
  keys = to_tensor([cast(10, int64), cast(20, int64), cast(30, int64)])
  vals = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  found = asof_lookup(keys, vals, cast(25, int64), cast(-1.0, f32))
  assert_close(found, cast(2.0, f32), cast(1e-6, f32), "between keys returns previous value")
}
def test_asof_lookup_no_prior_fallback() -> unit ! { Test } = {
  keys = to_tensor([cast(10, int64), cast(20, int64), cast(30, int64)])
  vals = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  found = asof_lookup(keys, vals, cast(5, int64), cast(-1.0, f32))
  assert_close(found, cast(-1.0, f32), cast(1e-6, f32), "no prior key returns fallback")
}
def test_asof_join_tensor_values() -> unit ! { Test } = {
  left = to_tensor([cast(5, int64), cast(10, int64), cast(25, int64), cast(35, int64)])
  right = to_tensor([cast(10, int64), cast(20, int64), cast(30, int64)])
  vals = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  out = to_list(asof_join(left, right, vals, cast(-1.0, f32)))
  sum = add(add(index(out, zero_i64()), index(out, one_i64())), add(index(out, cast(2, int64)), index(out, cast(3, int64))))
  assert_close(sum, cast(5.0, f32), cast(1e-6, f32), "join returns fallback, exact, previous, latest")
}
def test_asof_join_list_values() -> unit ! { Test } = {
  out = asof_join_list([cast(9, int64), cast(11, int64)], [cast(10, int64)], [cast(4.0, f32)], cast(-1.0, f32))
  sum = add(index(out, zero_i64()), index(out, one_i64()))
  assert_close(sum, cast(3.0, f32), cast(1e-6, f32), "list join supports fallback then prior")
}
