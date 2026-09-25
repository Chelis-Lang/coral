# API

The repository's `SKILL.md` §5 lists every public function by module, and
each module's exports are declared at the top of its source file under
`src/`.

| Module | Chapter |
|---|---|
| `Coral.Frame` | [Construction](../frame/construction.md), [Filtering](../frame/filtering.md), [Mutation](../frame/mutation.md), [NaN Handling](../frame/nan_handling.md), [Concatenation](../frame/concatenation.md), [Describe](../frame/describe.md) |
| `Coral.GroupBy` | [GroupBy](../groupby.md) |
| `Coral.Join` | [Joins](../joins.md) |
| `Coral.Io` | [CSV And JSON](../io.md) |
| `Coral.Window` | [Rolling And EWM](../window.md) |
| `Coral.Reshape` | [Reshape](../reshape.md) |
| `Coral.AsOf` | `asof_lookup` and `asof_join` over sorted `i64` key tensors with `f32` values, plus the host-list forms `asof_lookup_list` and `asof_join_list` |
