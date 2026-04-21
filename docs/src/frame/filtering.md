# Filtering

Coral’s preferred filter surface is mask-first: build a tensor bool
mask with vectorized comparisons, then call `filter(df, mask)`.
