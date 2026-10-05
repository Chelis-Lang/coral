def zero_i32() -> i32 = cast(0, i32)
def invalid_gather_axis_helper(xs: tensor[3, f32], idx: tensor[2, i64]) -> tensor[2, f32] = gather(xs, idx, zero_i32())
