module Coral.Window
export (rolling_sum, rolling_mean, rolling_std, rolling_min, rolling_max, ewm)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def empty_f32_list() -> List[f32] = []
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def window_slice(values: List[f32], start: int64, finish: int64) -> List[f32] = {
  slice = drop(values, start)
  take(slice, sub(finish, start))
}
def sum_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> add(acc, value), cast(0.0, f32), values)
def mean_f32(values: List[f32]) -> f32 = div(sum_f32(values), cast(len(values), f32))
def std_sample_f32(values: List[f32]) -> f32 =
  if lte(len(values), one_i64()) then nan_f32() else {
    mu = mean_f32(values)
    variance = div(fold(fn (acc: f32, value: f32) -> add(acc, mul(sub(value, mu), sub(value, mu))), cast(0.0, f32), values), cast(sub(len(values), one_i64()), f32))
    sqrt(variance)
  }
def is_nan_scalar(x: f32) -> bool = neq(x, x)
def min_f32(values: List[f32]) -> f32 =
  fold(fn (acc: f32, value: f32) -> {
    acc_nan = is_nan_scalar(acc)
    val_nan = is_nan_scalar(value)
    if or(acc_nan, val_nan) then nan_f32() else if lt(value, acc) then value else acc
  }, index(values, zero_i64()), drop(values, one_i64()))
def max_f32(values: List[f32]) -> f32 =
  fold(fn (acc: f32, value: f32) -> {
    acc_nan = is_nan_scalar(acc)
    val_nan = is_nan_scalar(value)
    if or(acc_nan, val_nan) then nan_f32() else if gt(value, acc) then value else acc
  }, index(values, zero_i64()), drop(values, one_i64()))
def rolling_sum_list(values: List[f32], window: int64, idx: int64, acc: List[f32]) -> List[f32] =
  if gte(idx, len(values)) then acc else {
    next = if lt(add(idx, one_i64()), window) then nan_f32() else sum_f32(window_slice(values, sub(add(idx, one_i64()), window), add(idx, one_i64())))
    rolling_sum_list(values, window, add(idx, one_i64()), append(acc, next))
  }
def rolling_std_list(values: List[f32], window: int64, idx: int64, acc: List[f32]) -> List[f32] =
  if gte(idx, len(values)) then acc else {
    next = if lt(add(idx, one_i64()), window) then nan_f32() else std_sample_f32(window_slice(values, sub(add(idx, one_i64()), window), add(idx, one_i64())))
    rolling_std_list(values, window, add(idx, one_i64()), append(acc, next))
  }
def rolling_min_list(values: List[f32], window: int64, idx: int64, acc: List[f32]) -> List[f32] =
  if gte(idx, len(values)) then acc else {
    next = if lt(add(idx, one_i64()), window) then nan_f32() else min_f32(window_slice(values, sub(add(idx, one_i64()), window), add(idx, one_i64())))
    rolling_min_list(values, window, add(idx, one_i64()), append(acc, next))
  }
def rolling_max_list(values: List[f32], window: int64, idx: int64, acc: List[f32]) -> List[f32] =
  if gte(idx, len(values)) then acc else {
    next = if lt(add(idx, one_i64()), window) then nan_f32() else max_f32(window_slice(values, sub(add(idx, one_i64()), window), add(idx, one_i64())))
    rolling_max_list(values, window, add(idx, one_i64()), append(acc, next))
  }
def ewm_list(values: List[f32], alpha: f32, first: bool, prev: f32, acc: List[f32]) -> List[f32] =
  if eq(len(values), zero_i64()) then acc else {
    current = index(values, zero_i64())
    next = if first then current else add(mul(alpha, current), mul(sub(cast(1.0, f32), alpha), prev))
    rest = drop(values, one_i64())
    ewm_list(rest, alpha, false, next, append(acc, next))
  }
def rolling_sum[n](col: tensor[n, f32], window: int64) -> tensor[n, f32] = to_tensor(rolling_sum_list(to_list(col), window, zero_i64(), empty_f32_list()))
def rolling_mean[n](col: tensor[n, f32], window: int64) -> tensor[n, f32] = to_tensor(map(fn (value: f32) -> div(value, cast(window, f32)), rolling_sum_list(to_list(col), window, zero_i64(), empty_f32_list())))
def rolling_std[n](col: tensor[n, f32], window: int64) -> tensor[n, f32] = to_tensor(rolling_std_list(to_list(col), window, zero_i64(), empty_f32_list()))
def rolling_min[n](col: tensor[n, f32], window: int64) -> tensor[n, f32] = to_tensor(rolling_min_list(to_list(col), window, zero_i64(), empty_f32_list()))
def rolling_max[n](col: tensor[n, f32], window: int64) -> tensor[n, f32] = to_tensor(rolling_max_list(to_list(col), window, zero_i64(), empty_f32_list()))
def ewm[n](col: tensor[n, f32], alpha: f32) -> tensor[n, f32] = to_tensor(ewm_list(to_list(col), alpha, true, cast(0.0, f32), empty_f32_list()))
