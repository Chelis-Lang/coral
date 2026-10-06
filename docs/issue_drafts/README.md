# Parked upstream issue drafts

This directory holds ready-to-file bodies for upstream Chelis issues that are
waiting on a stated filing condition, such as isolating a minimal reproducer.
While a draft is parked, Coral cites it by path
(`docs/issue_drafts/<file>.md`) at the narrowing site and in
[`docs/UPSTREAM_BUGS.md`](../UPSTREAM_BUGS.md).

Before filing a draft, search the upstream tracker for duplicates. After
filing, delete the draft and replace every citation of its path with the new
`chelis#NNN` in the same change.
