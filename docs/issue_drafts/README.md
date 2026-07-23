# Parked upstream issue drafts

Ready-to-file issue bodies awaiting a stated filing condition.

| Draft | Target repository | Filing condition |
|---|---|---|
| [`bare_build_unbound_pipe_targets.md`](bare_build_unbound_pipe_targets.md) | `Chelis-Lang/chelis` | Narrow to a minimal reproducer first — single-reference minimal cases are correctly rejected, so file only once the scale/context trigger is isolated |
| [`std_io_parquet_runtime_backing.md`](std_io_parquet_runtime_backing.md) | `Chelis-Lang/chelis` | Missing-feature request, not a regression — file once a concrete Parquet use case is worth prioritizing the runtime work, or when upstream signals movement on the `Std.Io` runtime surface |

Before filing, search the upstream tracker for duplicates. After filing, remove
the draft and replace every path citation with `chelis#NNN` in the same change.
