module Coral.Internal.Hamt
export (Hamt, hamt_empty, hamt_singleton, hamt_from_pairs, hamt_get, hamt_contains, hamt_put, hamt_remove, hamt_size, hamt_keys, hamt_entries)
type Hamt[a] =
  | Empty
  | Leaf { hash: int64, key: string, value: a }
  | BitmapNode { bitmap: int64, children: List[Hamt[a]], count: int64 }
  | Collision { hash: int64, entries: List[(string, a)] }
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def five_i64() -> int64 = cast(5, int64)
def mask_i64() -> int64 = cast(31, int64)
def hamt_empty[a]() -> Hamt[a] = Empty
def hamt_singleton[a](key: string, value: a) -> Hamt[a] = hamt_put(hamt_empty(), key, value)
def hamt_from_pairs[a](pairs: List[(string, a)]) -> Hamt[a] = from_pairs_rec(pairs, hamt_empty())
def hamt_get[a](map0: Hamt[a], key: string) -> Option[a] = {
  hash = hash_string_local(key)
  get_h(map0, key, hash, zero_i64())
}
def hamt_contains[a](map0: Hamt[a], key: string) -> bool = has_value(hamt_get(map0, key))
def hamt_put[a](map0: Hamt[a], key: string, value: a) -> Hamt[a] = {
  hash = hash_string_local(key)
  put_h(map0, key, value, hash, zero_i64())
}
def hamt_remove[a](map0: Hamt[a], key: string) -> Hamt[a] = {
  hash = hash_string_local(key)
  remove_h(map0, key, hash, zero_i64())
}
def hamt_size[a](map0: Hamt[a]) -> int64 = { match map0 with {
  | Empty => zero_i64()
  | Leaf { hash: hash, key: key, value: value } => one_i64()
  | BitmapNode { bitmap: bitmap, children: children, count: count } => count
  | Collision { hash: hash, entries: entries } => len(entries)
} }
def hamt_keys[a](map0: Hamt[a]) -> List[string] = map(fn (entry: (string, a)) -> entry.0, hamt_entries(map0))
def hamt_entries[a](map0: Hamt[a]) -> List[(string, a)] = entries_h(map0, [])
def get_h[a](node: Hamt[a], key: string, hash: int64, depth: int64) -> Option[a] = { match node with {
  | Empty => None
  | Leaf { hash: leaf_hash, key: leaf_key, value: leaf_value } => if and(eq(leaf_hash, hash), eq(leaf_key, key)) then Some(leaf_value) else None
  | Collision { hash: collision_hash, entries: entries } => if neq(collision_hash, hash) then None else collision_get(entries, key)
  | BitmapNode { bitmap: bitmap, children: children, count: count } => {
  bit = bitpos(fragment(hash, depth))
  if not(has_bit(bitmap, bit)) then None else get_h(index(children, index_of(bitmap, bit)), key, hash, add(depth, one_i64()))
}
} }
def put_h[a](node: Hamt[a], key: string, value: a, hash: int64, depth: int64) -> Hamt[a] = { match node with {
  | Empty => Leaf { hash: hash, key: key, value: value }
  | Leaf { hash: leaf_hash, key: leaf_key, value: leaf_value } => { if and(eq(leaf_hash, hash), eq(leaf_key, key)) then Leaf { hash: hash, key: key, value: value } else if eq(leaf_hash, hash) then Collision { hash: hash, entries: collision_put([(leaf_key, leaf_value)], key, value) } else merge_leaves(Leaf { hash: leaf_hash, key: leaf_key, value: leaf_value }, Leaf { hash: hash, key: key, value: value }, depth) }
  | Collision { hash: collision_hash, entries: entries } => { if eq(collision_hash, hash) then Collision { hash: hash, entries: collision_put(entries, key, value) } else merge_leaves(node, Leaf { hash: hash, key: key, value: value }, depth) }
  | BitmapNode { bitmap: bitmap, children: children, count: count } => {
  bit = bitpos(fragment(hash, depth))
  idx = index_of(bitmap, bit)
  if not(has_bit(bitmap, bit)) then BitmapNode { bitmap: bitor(bitmap, bit), children: list_insert_node(children, idx, Leaf { hash: hash, key: key, value: value }), count: add(count, one_i64()) } else {
    child = index(children, idx)
    next_child = put_h(child, key, value, hash, add(depth, one_i64()))
    BitmapNode { bitmap: bitmap, children: list_replace_node(children, idx, next_child), count: add(count, sub(hamt_size(next_child), hamt_size(child))) }
  }
}
} }
def remove_h[a](node: Hamt[a], key: string, hash: int64, depth: int64) -> Hamt[a] = { match node with {
  | Empty => Empty
  | Leaf { hash: leaf_hash, key: leaf_key, value: leaf_value } => if and(eq(leaf_hash, hash), eq(leaf_key, key)) then Empty else node
  | Collision { hash: collision_hash, entries: entries } => { if neq(collision_hash, hash) then node else {
  next_entries = collision_remove(entries, key)
  if eq(len(next_entries), zero_i64()) then Empty else if eq(len(next_entries), one_i64()) then {
    head = index(next_entries, zero_i64())
    Leaf { hash: collision_hash, key: head.0, value: head.1 }
  } else Collision { hash: collision_hash, entries: next_entries }
} }
  | BitmapNode { bitmap: bitmap, children: children, count: count } => {
  bit = bitpos(fragment(hash, depth))
  if not(has_bit(bitmap, bit)) then node else {
    idx = index_of(bitmap, bit)
    child = index(children, idx)
    next_child = remove_h(child, key, hash, add(depth, one_i64()))
    delta = sub(hamt_size(next_child), hamt_size(child))
    match next_child with {
      | Empty => {
      next_bitmap = bitand(bitmap, bitxor(bit, mask_i64_all()))
      next_children = list_remove_node(children, idx)
      if eq(len(next_children), zero_i64()) then Empty else BitmapNode { bitmap: next_bitmap, children: next_children, count: add(count, delta) }
    }
      | _ => BitmapNode { bitmap: bitmap, children: list_replace_node(children, idx, next_child), count: add(count, delta) }
    }
  }
}
} }
def merge_leaves[a](lhs: Hamt[a], rhs: Hamt[a], depth: int64) -> Hamt[a] = {
  lhs_hash = node_hash(lhs)
  rhs_hash = node_hash(rhs)
  lhs_frag = fragment(lhs_hash, depth)
  rhs_frag = fragment(rhs_hash, depth)
  if eq(lhs_frag, rhs_frag) then BitmapNode { bitmap: bitpos(lhs_frag), children: [merge_leaves(lhs, rhs, add(depth, one_i64()))], count: add(hamt_size(lhs), hamt_size(rhs)) } else {
    lhs_bit = bitpos(lhs_frag)
    rhs_bit = bitpos(rhs_frag)
    if lt(lhs_frag, rhs_frag) then BitmapNode { bitmap: bitor(lhs_bit, rhs_bit), children: [lhs, rhs], count: add(hamt_size(lhs), hamt_size(rhs)) } else BitmapNode { bitmap: bitor(lhs_bit, rhs_bit), children: [rhs, lhs], count: add(hamt_size(lhs), hamt_size(rhs)) }
  }
}
def node_hash[a](node: Hamt[a]) -> int64 = { match node with {
  | Leaf { hash: hash, key: key, value: value } => hash
  | Collision { hash: hash, entries: entries } => hash
  | _ => fail("node_hash: expected leaf or collision")
} }
def fragment(hash: int64, depth: int64) -> int64 = bitand(shr(hash, mul(depth, five_i64())), mask_i64())
def bitpos(frag: int64) -> int64 = shl(one_i64(), frag)
def has_bit(bitmap: int64, bit: int64) -> bool = neq(bitand(bitmap, bit), zero_i64())
def index_of(bitmap: int64, bit: int64) -> int64 = popcount_i64(bitand(bitmap, sub(bit, one_i64())))
def mask_i64_all() -> int64 = cast(-1, int64)
def popcount_i64(value: int64) -> int64 = { if eq(value, zero_i64()) then zero_i64() else add(one_i64(), popcount_i64(bitand(value, sub(value, one_i64())))) }
def hash_string_local(text: string) -> int64 = hash_chars(text, zero_i64(), one_i64())
def hash_chars(text: string, idx: int64, acc: int64) -> int64 = { if gte(idx, string_len(text)) then acc else {
  ch = string_slice(text, idx, one_i64())
  next = mod(add(mul(acc, cast(131, int64)), char_code(ch)), cast(2147483647, int64))
  hash_chars(text, add(idx, one_i64()), next)
} }
def char_code(ch: string) -> int64 = char_index(char_table(), ch, zero_i64())
def char_index(chars: List[string], target: string, idx: int64) -> int64 = { if eq(len(chars), zero_i64()) then cast(127, int64) else {
  head = index(chars, zero_i64())
  if eq(head, target) then add(idx, one_i64()) else char_index(drop(chars, one_i64()), target, add(idx, one_i64()))
} }
def char_table() -> List[string] = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "_", "-", ".", " ", "%", "/", ":", "+", "*", "#", "@"]
def collision_get[a](entries: List[(string, a)], key: string) -> Option[a] = { if eq(len(entries), zero_i64()) then None else {
  head = index(entries, zero_i64())
  if eq(head.0, key) then Some(head.1) else collision_get(drop(entries, one_i64()), key)
} }
def collision_put[a](entries: List[(string, a)], key: string, value: a) -> List[(string, a)] = { if eq(len(entries), zero_i64()) then [(key, value)] else {
  head = index(entries, zero_i64())
  rest = drop(entries, one_i64())
  if eq(head.0, key) then prepend_entry((key, value), rest) else prepend_entry(head, collision_put(rest, key, value))
} }
def collision_remove[a](entries: List[(string, a)], key: string) -> List[(string, a)] = { if eq(len(entries), zero_i64()) then [] else {
  head = index(entries, zero_i64())
  rest = drop(entries, one_i64())
  if eq(head.0, key) then rest else prepend_entry(head, collision_remove(rest, key))
} }
def entries_h[a](node: Hamt[a], acc: List[(string, a)]) -> List[(string, a)] = { match node with {
  | Empty => acc
  | Leaf { hash: hash, key: key, value: value } => append(acc, (key, value))
  | Collision { hash: hash, entries: entries } => append_all_entries(acc, entries)
  | BitmapNode { bitmap: bitmap, children: children, count: count } => entries_children(children, acc)
} }
def entries_children[a](children: List[Hamt[a]], acc: List[(string, a)]) -> List[(string, a)] = { if eq(len(children), zero_i64()) then acc else entries_children(drop(children, one_i64()), entries_h(index(children, zero_i64()), acc)) }
def from_pairs_rec[a](pairs: List[(string, a)], acc: Hamt[a]) -> Hamt[a] = { if eq(len(pairs), zero_i64()) then acc else {
  head = index(pairs, zero_i64())
  from_pairs_rec(drop(pairs, one_i64()), hamt_put(acc, head.0, head.1))
} }
def has_value[a](value: Option[a]) -> bool = { match value with {
  | Some(item) => true
  | None => false
} }
def prepend_node[a](value: Hamt[a], items: List[Hamt[a]]) -> List[Hamt[a]] = prepend_node_acc(items, [value])
def prepend_node_acc[a](items: List[Hamt[a]], acc: List[Hamt[a]]) -> List[Hamt[a]] = { if eq(len(items), zero_i64()) then acc else prepend_node_acc(drop(items, one_i64()), append(acc, index(items, zero_i64()))) }
def prepend_entry[a](value: (string, a), items: List[(string, a)]) -> List[(string, a)] = prepend_entry_acc(items, [value])
def prepend_entry_acc[a](items: List[(string, a)], acc: List[(string, a)]) -> List[(string, a)] = { if eq(len(items), zero_i64()) then acc else prepend_entry_acc(drop(items, one_i64()), append(acc, index(items, zero_i64()))) }
def append_all_entries[a](lhs: List[(string, a)], rhs: List[(string, a)]) -> List[(string, a)] = { if eq(len(rhs), zero_i64()) then lhs else append_all_entries(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64())) }
def list_insert_node[a](items: List[Hamt[a]], idx: int64, value: Hamt[a]) -> List[Hamt[a]] = { if lte(idx, zero_i64()) then prepend_node(value, items) else if eq(len(items), zero_i64()) then [value] else prepend_node(index(items, zero_i64()), list_insert_node(drop(items, one_i64()), sub(idx, one_i64()), value)) }
def list_replace_node[a](items: List[Hamt[a]], idx: int64, value: Hamt[a]) -> List[Hamt[a]] = { if eq(len(items), zero_i64()) then [] else if eq(idx, zero_i64()) then prepend_node(value, drop(items, one_i64())) else prepend_node(index(items, zero_i64()), list_replace_node(drop(items, one_i64()), sub(idx, one_i64()), value)) }
def list_remove_node[a](items: List[Hamt[a]], idx: int64) -> List[Hamt[a]] = { if eq(len(items), zero_i64()) then [] else if eq(idx, zero_i64()) then drop(items, one_i64()) else prepend_node(index(items, zero_i64()), list_remove_node(drop(items, one_i64()), sub(idx, one_i64()))) }
