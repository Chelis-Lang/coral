module Coral.PlayerData
export (PlayerLineup, RecentForm, PositionDistribution, match_lineup, recent_form, team_starting_strength, team_starting_strength_fixture, position_distribution)
type PlayerLineup =
  | PlayerLineup { match_id: int64, home_or_away: int64, team_id: int64, player_ids: List[int64], positions: List[string], starting_strengths: List[f32] }
type RecentForm =
  | RecentForm { team_id: int64, lookback_matches: int64, attack: f32, defense: f32, availability: f32 }
type PositionDistribution =
  | PositionDistribution { match_id: int64, home_or_away: int64, goalkeeper: int64, defender: int64, midfielder: int64, forward: int64 }
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def eleven_i64() -> int64 = cast(11, int64)
def clamp_side(home_or_away: int64) -> int64 = { if eq(home_or_away, zero_i64()) then zero_i64() else one_i64() }
def side_team_id(match_id: int64, home_or_away: int64) -> int64 = {
  scaled_match = mul(match_id, cast(10, int64))
  add(scaled_match, clamp_side(home_or_away))
}
def match_lineup(match_id: int64, home_or_away: int64) -> PlayerLineup = {
  side = clamp_side(home_or_away)
  team = side_team_id(match_id, side)
  PlayerLineup { match_id: match_id, home_or_away: side, team_id: team, player_ids: player_ids_for_team(team), positions: starting_positions(), starting_strengths: starting_strengths(match_id, side) }
}
def recent_form(team_id: int64, lookback_matches: int64) -> RecentForm = {
  lookback = if lt(lookback_matches, one_i64()) then one_i64() else lookback_matches
  team_float = cast(team_id, f32)
  lookback_float = cast(lookback, f32)
  team_component = mul(team_float, cast(0.005, f32))
  lookback_attack = mul(lookback_float, cast(0.02, f32))
  lookback_defense = mul(lookback_float, cast(0.01, f32))
  attack_floor = cast(1.0, f32)
  defense_floor = cast(0.8, f32)
  attack_base = add(attack_floor, team_component)
  attack = add(attack_base, lookback_attack)
  defense = add(defense_floor, lookback_defense)
  RecentForm { team_id: team_id, lookback_matches: lookback, attack: attack, defense: defense, availability: cast(1.0, f32) }
}
def team_starting_strength(match_id: int64, home_or_away: int64) -> f32 = {
  strengths = starting_strengths(match_id, home_or_away)
  total = sum_f32(strengths)
  count = cast(len(strengths), f32)
  div(total, count)
}
team_starting_strength_fixture = team_starting_strength
def position_distribution(match_id: int64, home_or_away: int64) -> PositionDistribution = {
  side = clamp_side(home_or_away)
  PositionDistribution { match_id: match_id, home_or_away: side, goalkeeper: one_i64(), defender: cast(4, int64), midfielder: cast(3, int64), forward: cast(3, int64) }
}
def player_ids_for_team(team_id: int64) -> List[int64] = {
  base = mul(team_id, cast(100, int64))
  map(fn (idx: int64) -> add(base, idx), range(zero_i64(), eleven_i64()))
}
def starting_positions() -> List[string] = ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW"]
def starting_strengths(match_id: int64, home_or_away: int64) -> List[f32] = {
  base = base_strength_for_side(match_id, home_or_away)
  map(fn (idx: int64) -> {
    idx_float = cast(idx, f32)
    offset = mul(idx_float, cast(0.002, f32))
    add(base, offset)
  }, range(zero_i64(), eleven_i64()))
}
def base_strength_for_side(match_id: int64, home_or_away: int64) -> f32 = {
  side = clamp_side(home_or_away)
  base = if eq(side, zero_i64()) then cast(0.64, f32) else cast(0.59, f32)
  match_float = cast(match_id, f32)
  match_component = mul(match_float, cast(0.01, f32))
  add(base, match_component)
}
def sum_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> add(acc, value), cast(0.0, f32), values)
