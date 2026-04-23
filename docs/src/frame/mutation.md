# Mutation

Use `with_column`, `mutate`, `rename`, and `drop_column` to evolve frame schemas.

`mutate` is a semantic alias for `with_column` — both add or replace a column:

```chelis
-- mutate and with_column are equivalent
df2 = mutate(df, "total", FloatCol(to_tensor([cast(100.0, f32)])))
```
