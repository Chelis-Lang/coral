module Coral.Tests.Linearity
import Std.Test (assert_eq)
-- Regression for chelis#1200, fixed by chelis PR #1208 and released in 0.18.5.
-- On 0.18.4 a `_ =` wildcard discard desugared with the `destructure: true`
-- marker, opening the Linearity-F2 destructure-consume scope over the rest of
-- the enclosing body: any later reuse of a variable a record-destructuring
-- callee had touched was a hard UseAfterConsume. Promoted from
-- tests_blocked/linearity/wildcard_discard_consume.ch at the 0.18.5 pin bump.
type TaggedBox =
  | TaggedBox { data: tensor[2, f32], tag: string }
def tag_of(b: TaggedBox) -> string =
  match b with {
    | TaggedBox { data, tag } => tag
  }
def test_wildcard_discard_does_not_consume_destructured_arg() -> unit ! { Test } = {
  b = TaggedBox { data: to_tensor([cast(1.0, f32), cast(2.0, f32)]), tag: "t" }
  _ = tag_of(b)
  assert_eq(tag_of(b), "t", "reusable after a `_ =` discard")
}
