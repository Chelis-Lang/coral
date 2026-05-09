module Coral.ApiSmoke
import Coral.Core (version)
import Coral.Frame (Column, ColumnType, Frame, from_pairs, columns, nrows, ncols, mutate, int_col_of_list, is_nan_col, fill_nan_col, drop_nan_col, any_nan_col, count_nan_col, is_nan, fill_nan, drop_nan, any_nan, count_nan)
import Coral.GroupBy (AggFn, value_counts)
import Coral.Window (rolling_mean)
import Coral.Join (inner_join, left_join, outer_join)
import Coral.Reshape (pivot, melt, stack, unstack)
export (smoke)
def smoke[n](col: tensor[n, f32]) -> tensor[n, f32] = {
  _ = version()
  rolling_mean(col, cast(2, int64))
}
