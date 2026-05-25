module Coral.AsOf
export (asof_lookup, asof_join, asof_lookup_list, asof_join_list)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def asof_lookup_list(keys: List[int64], values: List[f32], key: int64, fallback: f32) -> f32 = { if keys |> len |> neq(len(values)) then fail("asof_lookup: key/value length mismatch") else asof_lookup_rec(keys, values, key, zero_i64(), fallback) }
def asof_join_list(left_keys: List[int64], right_keys: List[int64], right_values: List[f32], fallback: f32) -> List[f32] = { map(fn (key: int64) -> asof_lookup_list(right_keys, right_values, key, fallback), left_keys) }
def asof_lookup[n](keys: tensor[n, int64], values: tensor[n, f32], key: int64, fallback: f32) -> f32 = { asof_lookup_list(to_list(keys), to_list(values), key, fallback) }
def asof_join[n, m](left_keys: tensor[n, int64], right_keys: tensor[m, int64], right_values: tensor[m, f32], fallback: f32) -> tensor[n, f32] = { to_tensor(asof_join_list(to_list(left_keys), to_list(right_keys), to_list(right_values), fallback)) }
def asof_lookup_rec(keys: List[int64], values: List[f32], key: int64, idx: int64, best: f32) -> f32 = {
  if gte(idx, len(keys)) then best else {
    rkey = index(keys, idx)
    next_best = if lte(rkey, key) then index(values, idx) else best
    if gt(rkey, key) then best else asof_lookup_rec(keys, values, key, add(idx, one_i64()), next_best)
  }
}
