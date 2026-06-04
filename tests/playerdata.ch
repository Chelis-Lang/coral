module Coral.Tests.PlayerData
import Std.Test (assert_true, assert_eq_int, assert_eq_string, assert_close)
import Coral.PlayerData (PlayerLineup, RecentForm, PositionDistribution, match_lineup, recent_form, team_starting_strength, team_starting_strength_fixture, position_distribution)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def test_team_starting_strength_fixture_home() -> unit ! { Test } = {
  value = team_starting_strength_fixture(cast(1, int64), zero_i64())
  assert_close(value, cast(0.66, f32), cast(0.00001, f32), "fixture returns deterministic home strength")
}
def test_team_starting_strength_fixture_away() -> unit ! { Test } = {
  value = team_starting_strength_fixture(cast(1, int64), one_i64())
  assert_close(value, cast(0.61, f32), cast(0.00001, f32), "fixture returns deterministic away strength")
}
def test_match_lineup_returns_eleven_with_side_metadata() -> unit ! { Test } = {
  lineup = match_lineup(cast(2, int64), zero_i64())
  match lineup with {
    | PlayerLineup { match_id: mid, home_or_away: side, team_id: team, player_ids: players, positions: positions, starting_strengths: strengths } => {
    _ = assert_eq_int(mid, cast(2, int64), "lineup records match id")
    _ = assert_eq_int(side, zero_i64(), "lineup records side")
    _ = assert_eq_int(team, cast(20, int64), "lineup derives stable fixture team id")
    _ = assert_eq_int(len(players), cast(11, int64), "lineup has eleven players")
    _ = assert_eq_int(index(players, zero_i64()), cast(2000, int64), "lineup has stable first player id")
    _ = assert_eq_string(index(positions, zero_i64()), "GK", "lineup starts with goalkeeper slot")
    assert_eq_int(len(strengths), cast(11, int64), "lineup has one strength per player")
  }
  }
}
def test_planned_accessors_compile_and_return_typed_values() -> unit ! { Test } = {
  strength = team_starting_strength(cast(3, int64), zero_i64())
  form = recent_form(cast(30, int64), cast(5, int64))
  dist = position_distribution(cast(3, int64), zero_i64())
  _ = assert_true(gt(strength, cast(0.0, f32)), "team strength is positive")
  _ = match form with {
    | RecentForm { team_id: team, lookback_matches: lookback, attack: attack, defense: defense, availability: availability } => {
    _ = assert_eq_int(team, cast(30, int64), "recent form records team id")
    _ = assert_eq_int(lookback, cast(5, int64), "recent form records lookback")
    _ = assert_true(gt(attack, defense), "fixture form keeps attack above defense")
    assert_close(availability, cast(1.0, f32), cast(0.00001, f32), "fixture availability is full")
  }
  }
  match dist with {
    | PositionDistribution { match_id: mid, home_or_away: side, goalkeeper: goalkeeper, defender: defender, midfielder: midfielder, forward: forward } => {
    _ = assert_eq_int(mid, cast(3, int64), "distribution records match id")
    _ = assert_eq_int(side, zero_i64(), "distribution records side")
    assert_eq_int(add(add(goalkeeper, defender), add(midfielder, forward)), cast(11, int64), "distribution totals eleven starters")
  }
  }
}
