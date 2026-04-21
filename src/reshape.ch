module Coral.Reshape
export (pivot, melt)

def pivot[a](df: a, index_col: string, columns_col: string, values_col: string) -> a = fail("pivot is deferred pending a lighter v0.1.0 reshape pass")
def melt[a](df: a, id_cols: List[string], value_cols: List[string]) -> a = fail("melt is deferred pending a lighter v0.1.0 reshape pass")
