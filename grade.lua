-------------------------------------------------------------------------
-- grade.lua: the provisional Phase 1 grade rule (CLAUDE.md, "Phase 1
-- plan", step 4).
--
-- Pure logic: reads no game globals, so it runs under plain Lua 5.1 for
-- tests (`lua test_grade.lua`). In-game, load it from the main file with
--   local grade = assert(SMODS.load_file('grade.lua'))()
--
-- The caller supplies the numbers:
--   player_score  what the player's play scores, in the order they
--                 played it (not the best order of those cards)
--   best_score    the top score in analyze_hand_inner's full list
--   chips_needed  G.GAME.blind.chips - G.GAME.chips, before this play
--   is_last_hand  true if no hands remain after this one. [verify] in
--                 balatro_src/ whether hands_left is already decremented
--                 when evaluate_play runs.
-------------------------------------------------------------------------

-- Share of the best score needed for each grade. Provisional: Phase 2
-- replaces these with GRADE_CUTOFFS (drop in win probability).
local SCORE_RATIO_CUTOFFS = {
  { grade = 'Best', min_ratio = 0.99 },
  { grade = 'Good', min_ratio = 0.90 },
  { grade = 'Inaccuracy', min_ratio = 0.75 },
  { grade = 'Mistake', min_ratio = 0.50 }
}

local function grade_by_ratio(ratio)
  for _, cutoff in ipairs(SCORE_RATIO_CUTOFFS) do
    if ratio >= cutoff.min_ratio then return cutoff.grade end
  end
  return 'Blunder'
end

local function is_number(value)
  return type(value) == 'number' and value == value
end

-- Returns { grade = string, provisional = boolean, reason = string },
-- or nil if the inputs are unusable (grading is skipped, never guessed).
local function grade_play(player_score, best_score, chips_needed,
                          is_last_hand)
  if not (is_number(player_score) and is_number(best_score)
      and is_number(chips_needed)) then
    return nil
  end

  -- Overkill chips don't carry over, so every clearing play is equal
  -- in Phase 1. (ENGINE_NUANCES 1.2 tie-breaks come later.)
  if player_score >= chips_needed then
    return { grade = 'Best', provisional = false,
             reason = 'Clears the blind' }
  end

  if best_score >= chips_needed then
    return { grade = 'Blunder', provisional = false,
             reason = 'Another play clears the blind' }
  end

  -- Nothing clears. Grade by score against the best play.
  local ratio = 1
  if best_score > 0 then ratio = player_score / best_score end
  local percent = math.floor(math.min(ratio, 1) * 100)

  -- With hands left, the true best may be a setup play that keeps
  -- strong cards for later. Phase 2's redraw simulation settles it.
  return { grade = grade_by_ratio(ratio),
           provisional = not is_last_hand,
           reason = 'Scores ' .. percent .. '% of the best play' }
end

return {
  SCORE_RATIO_CUTOFFS = SCORE_RATIO_CUTOFFS,
  grade_play = grade_play
}
