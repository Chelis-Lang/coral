module Coral.ApiSmoke
import Coral.Core (version)
import Coral.Frame (Column, ColumnType, Frame, from_pairs, columns, nrows, ncols)
import Coral.GroupBy (AggFn)
import Coral.Window (rolling_mean)
export (smoke)

def smoke[n](col: tensor[n, f32]) -> tensor[n, f32] = {
  _ = version()
  rolling_mean(col, cast(2, int64))
}
