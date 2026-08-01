def blocked_tensor_neq_borrowed[n](lhs: &tensor[n, f32], rhs: &tensor[n, f32]) -> tensor[n, bool] = neq(lhs, rhs)
