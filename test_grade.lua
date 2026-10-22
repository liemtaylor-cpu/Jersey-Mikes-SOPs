-------------------------------------------------------------------------
-- test_grade.lua: unit tests for grade.lua. Run from the repo root:
--   lua test_grade.lua
-- Prints one line per test, then a summary. Exits 1 if any test fails.
-------------------------------------------------------------------------

local grade = dofile('grade.lua')

local passed, failed = 0, 0

local function check(name, result, want_grade, want_provisional)
  local ok = result ~= nil and result.grade == want_grade
    and result.provisional == want_provisional
  if ok then
    passed = passed + 1
    print('ok    ' .. name)
  else
    failed = failed + 1
    local got = 'nil'
    if result then
      got = result.grade .. ', provisional=' .. tostring(result.provisional)
    end
    print('FAIL  ' .. name .. ' (want ' .. want_grade .. ', provisional='
      .. tostring(want_provisional) .. '; got ' .. got .. ')')
  end
end

local function check_nil(name, result)
  if result == nil then
    passed = passed + 1
    print('ok    ' .. name)
  else
    failed = failed + 1
    print('FAIL  ' .. name .. ' (want nil, got ' .. result.grade .. ')')
  end
end

-- Some play clears the blind.
check('clearing play is Best',
  grade.grade_play(1200, 1200, 1000, false), 'Best', false)
check('weaker clearing play is still Best (overkill is wasted)',
  grade.grade_play(1001, 5000, 1000, false), 'Best', false)
check('scoring exactly the chips needed clears',
  grade.grade_play(1000, 1000, 1000, true), 'Best', false)
check('missing a clear is a Blunder',
  grade.grade_play(600, 1200, 1000, false), 'Blunder', false)
check('missing a clear is a Blunder even at 99% of best',
  grade.grade_play(990, 1000, 1000, true), 'Blunder', false)
check('zero-score play (e.g. The Eye) when a clear existed',
  grade.grade_play(0, 1200, 1000, false), 'Blunder', false)

-- Last hand, nothing clears: grade by share of the best score.
check('last hand, best play', grade.grade_play(800, 800, 1000, true),
  'Best', false)
check('last hand, 99% is Best', grade.grade_play(990, 1000, 5000, true),
  'Best', false)
check('last hand, 95% is Good', grade.grade_play(950, 1000, 5000, true),
  'Good', false)
check('last hand, 90% is Good', grade.grade_play(900, 1000, 5000, true),
  'Good', false)
check('last hand, 89% is Inaccuracy',
  grade.grade_play(890, 1000, 5000, true), 'Inaccuracy', false)
check('last hand, 75% is Inaccuracy',
  grade.grade_play(750, 1000, 5000, true), 'Inaccuracy', false)
check('last hand, 60% is Mistake', grade.grade_play(600, 1000, 5000, true),
  'Mistake', false)
check('last hand, 50% is Mistake', grade.grade_play(500, 1000, 5000, true),
  'Mistake', false)
check('last hand, 49% is Blunder', grade.grade_play(490, 1000, 5000, true),
  'Blunder', false)

-- Hands remain, nothing clears: same grades, marked provisional.
check('hands left, best play is provisional',
  grade.grade_play(800, 800, 1000, false), 'Best', true)
check('hands left, 60% is a provisional Mistake',
  grade.grade_play(600, 1000, 5000, false), 'Mistake', true)

-- Edge cases.
check('nothing scores at all (every play debuffed)',
  grade.grade_play(0, 0, 1000, true), 'Best', false)
check('player beats the "best" (scorer missed something)',
  grade.grade_play(1100, 1000, 5000, true), 'Best', false)
check('blind already met', grade.grade_play(0, 0, 0, false), 'Best', false)
check_nil('missing score is skipped, not guessed',
  grade.grade_play(nil, 1000, 1000, true))
check_nil('NaN score is skipped', grade.grade_play(0 / 0, 1000, 1000, true))

-- The reason line shown to the player.
local r = grade.grade_play(600, 1000, 5000, true)
if r and r.reason == 'Scores 60% of the best play' then
  passed = passed + 1
  print('ok    reason line shows the percentage')
else
  failed = failed + 1
  print('FAIL  reason line shows the percentage (got '
    .. tostring(r and r.reason) .. ')')
end

print('')
if failed == 0 then
  print('All ' .. passed .. ' tests passed.')
else
  print(failed .. ' of ' .. (passed + failed) .. ' tests FAILED.')
  os.exit(1)
end
