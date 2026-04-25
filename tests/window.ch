module Coral.Tests.Window
import Std.Test (assert_true, assert_eq, assert_close)
import Coral.Window (rolling_sum, rolling_mean, rolling_std, rolling_min, rolling_max, ewm)

def is_nan_local(x: f32) -> bool = neq(x, x)

def test_rolling_sum_basic() -> unit ! { Test } = {
  input = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  out = to_list(rolling_sum(input, cast(3, int64)))
  -- output[2] = 1+2+3 = 6
  -- output[3] = 2+3+4 = 9
  -- output[4] = 3+4+5 = 12
  _ = assert_close(index(out, cast(2, int64)), cast(6.0, f32), cast(0.00001, f32), "rs[2] == 6");
  _ = assert_close(index(out, cast(3, int64)), cast(9.0, f32), cast(0.00001, f32), "rs[3] == 9");
  assert_close(index(out, cast(4, int64)), cast(12.0, f32), cast(0.00001, f32), "rs[4] == 12")
}

def test_rolling_sum_first_two_are_nan() -> unit ! { Test } = {
  input = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  out = to_list(rolling_sum(input, cast(3, int64)))
  _ = assert_true(is_nan_local(index(out, cast(0, int64))), "rs[0] is NaN");
  assert_true(is_nan_local(index(out, cast(1, int64))), "rs[1] is NaN")
}

def test_rolling_mean_basic() -> unit ! { Test } = {
  input = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  out = to_list(rolling_mean(input, cast(3, int64)))
  -- mean of [1,2,3]=2, [2,3,4]=3, [3,4,5]=4
  _ = assert_close(index(out, cast(2, int64)), cast(2.0, f32), cast(0.00001, f32), "rm[2] == 2.0");
  _ = assert_close(index(out, cast(3, int64)), cast(3.0, f32), cast(0.00001, f32), "rm[3] == 3.0");
  assert_close(index(out, cast(4, int64)), cast(4.0, f32), cast(0.00001, f32), "rm[4] == 4.0")
}

def test_rolling_min_constant() -> unit ! { Test } = {
  input = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  out = to_list(rolling_min(input, cast(2, int64)))
  -- output[0] is NaN, output[1..3] all = 5.0
  _ = assert_close(index(out, cast(1, int64)), cast(5.0, f32), cast(0.00001, f32), "rmin[1] == 5");
  _ = assert_close(index(out, cast(2, int64)), cast(5.0, f32), cast(0.00001, f32), "rmin[2] == 5");
  assert_close(index(out, cast(3, int64)), cast(5.0, f32), cast(0.00001, f32), "rmin[3] == 5")
}

def test_rolling_max_increasing() -> unit ! { Test } = {
  input = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  out = to_list(rolling_max(input, cast(2, int64)))
  -- max of pairs (1,2)=2, (2,3)=3, (3,4)=4
  _ = assert_close(index(out, cast(1, int64)), cast(2.0, f32), cast(0.00001, f32), "rmax[1] == 2");
  _ = assert_close(index(out, cast(2, int64)), cast(3.0, f32), cast(0.00001, f32), "rmax[2] == 3");
  assert_close(index(out, cast(3, int64)), cast(4.0, f32), cast(0.00001, f32), "rmax[3] == 4")
}

def test_rolling_std_constant_is_zero() -> unit ! { Test } = {
  input = to_tensor([cast(7.0, f32), cast(7.0, f32), cast(7.0, f32), cast(7.0, f32)])
  out = to_list(rolling_std(input, cast(2, int64)))
  -- std of [7,7] is 0
  _ = assert_close(index(out, cast(1, int64)), cast(0.0, f32), cast(0.00001, f32), "rstd[1] == 0");
  _ = assert_close(index(out, cast(2, int64)), cast(0.0, f32), cast(0.00001, f32), "rstd[2] == 0");
  assert_close(index(out, cast(3, int64)), cast(0.0, f32), cast(0.00001, f32), "rstd[3] == 0")
}

def test_ewm_first_value_is_input() -> unit ! { Test } = {
  input = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])
  out = to_list(ewm(input, cast(0.5, f32)))
  -- first ewm value equals first input (init mode is the first-value mode)
  assert_close(index(out, cast(0, int64)), cast(10.0, f32), cast(0.00001, f32), "ewm[0] == 10")
}

def test_ewm_recurrence_alpha_half() -> unit ! { Test } = {
  -- ewm with adjust=False, alpha=0.5, init from first value:
  --   y[0] = x[0] = 10
  --   y[1] = 0.5*20 + 0.5*10 = 15
  --   y[2] = 0.5*30 + 0.5*15 = 22.5
  -- These hand-computed values isolate the alpha parameter from any "constant" bug.
  input = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])
  out = to_list(ewm(input, cast(0.5, f32)))
  _ = assert_close(index(out, cast(1, int64)), cast(15.0, f32), cast(0.00001, f32), "ewm[1] == 0.5*20 + 0.5*10 == 15");
  assert_close(index(out, cast(2, int64)), cast(22.5, f32), cast(0.00001, f32), "ewm[2] == 0.5*30 + 0.5*15 == 22.5")
}

def test_rolling_max_distinguishes_from_right_edge() -> unit ! { Test } = {
  -- Decreasing input rules out "rolling_max returns the right edge" (would give 1, 0)
  -- and "rolling_max returns rolling_min" (would give 0, NaN-friendly check).
  -- input [3,1,0,4] window=2: max windows are [_, 3, 1, 4]
  input = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(0.0, f32), cast(4.0, f32)])
  out = to_list(rolling_max(input, cast(2, int64)))
  _ = assert_close(index(out, cast(1, int64)), cast(3.0, f32), cast(1e-5, f32), "rmax[1] == max(3,1) == 3");
  _ = assert_close(index(out, cast(2, int64)), cast(1.0, f32), cast(1e-5, f32), "rmax[2] == max(1,0) == 1");
  assert_close(index(out, cast(3, int64)), cast(4.0, f32), cast(1e-5, f32), "rmax[3] == max(0,4) == 4")
}

def test_rolling_min_distinguishes_from_constant() -> unit ! { Test } = {
  -- Varying input rules out "rolling_min always returns 0" or "returns left edge".
  -- input [3,1,4,1,5] window=2: min windows are [_, 1, 1, 1, 1]... wait that's also flat.
  -- Use [3,5,2,8,1] window=2: mins are [_, 3, 2, 2, 1]
  input = to_tensor([cast(3.0, f32), cast(5.0, f32), cast(2.0, f32), cast(8.0, f32), cast(1.0, f32)])
  out = to_list(rolling_min(input, cast(2, int64)))
  _ = assert_close(index(out, cast(1, int64)), cast(3.0, f32), cast(1e-5, f32), "rmin[1] == min(3,5) == 3");
  _ = assert_close(index(out, cast(2, int64)), cast(2.0, f32), cast(1e-5, f32), "rmin[2] == min(5,2) == 2");
  assert_close(index(out, cast(4, int64)), cast(1.0, f32), cast(1e-5, f32), "rmin[4] == min(8,1) == 1")
}

def test_rolling_std_nonzero_varying_input() -> unit ! { Test } = {
  -- Sample std (ddof=1) of [1, 3]: sqrt((((1-2)^2 + (3-2)^2) / 1)) = sqrt(2) ~ 1.41421
  -- Sample std of [1, 3, 5] window=2 windows: [NaN, std(1,3)=√2, std(3,5)=√2]
  input = to_tensor([cast(1.0, f32), cast(3.0, f32), cast(5.0, f32)])
  out = to_list(rolling_std(input, cast(2, int64)))
  _ = assert_close(index(out, cast(1, int64)), cast(1.41421356, f32), cast(1e-4, f32), "rstd[1] == sqrt(2)");
  assert_close(index(out, cast(2, int64)), cast(1.41421356, f32), cast(1e-4, f32), "rstd[2] == sqrt(2)")
}
