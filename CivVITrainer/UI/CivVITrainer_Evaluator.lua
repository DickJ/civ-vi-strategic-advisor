local Util = include("CivVITrainer_Util")
local Strategy = include("CivVITrainer_Strategy")
local Evaluator = {}

local function addCandidate(list, candidate)
  candidate.factors = candidate.factors or {}
  candidate.steps = candidate.steps or {}
  candidate.path = candidate.path or {}
  candidate.score = candidate.score or 0
  table.insert(list, candidate)
end

local function visibleThreatNear(snapshot, position, radius)
  local total = 0
  local strongest = nil
  for _, unit in ipairs(snapshot.visibleEnemyUnits or {}) do
    local distance = Util.Distance(position, unit)
    if distance <= radius then
      local weighted = (unit.combat or 10) / math.max(distance, 1)
      total = total + weighted
      if not strongest or weighted > strongest.weighted then
        strongest = { unit = unit, weighted = weighted, distance = distance }
      end
    end
  end
  return total, strongest
end

local function yieldValue(plot, weights)
  local yields = plot.yields or {}
  return (yields.food or 0) * (0.8 + weights.expansion * 0.2)
    + (yields.production or 0) * 1.35
    + (yields.science or 0) * weights.science
    + (yields.culture or 0) * weights.culture
    + (yields.faith or 0) * weights.religion
    + (yields.gold or 0) * weights.economy * 0.55
end

local function actionExplanation(candidate, snapshot, weights)
  local lines = {}
  table.insert(lines, candidate.reason)
  if #candidate.steps > 0 then
    table.insert(lines, "[NEWLINE][NEWLINE][COLOR_Gold]Plan[ENDCOLOR]")
    for index, step in ipairs(candidate.steps) do
      table.insert(lines, string.format("[NEWLINE]%d. %s", index, step))
    end
  end
  table.insert(lines, "[NEWLINE][NEWLINE][COLOR_Gold]Technical factors[ENDCOLOR]")
  for _, factor in ipairs(candidate.factors) do
    table.insert(lines, "[NEWLINE]• " .. factor)
  end
  local stage = (snapshot.turn or 0) < 60 and "early" or ((snapshot.turn or 0) < 180 and "mid" or "late")
  table.insert(lines, string.format("[NEWLINE]• Game stage — turn %d (%s game); tempo and compounding value are adjusted accordingly.", snapshot.turn or 0, stage))
  table.insert(lines, string.format("[NEWLINE]• Empire output — %.1f science, %.1f culture, %.1f faith, and %.1f gold per turn.",
    (snapshot.yields or {}).science or 0, (snapshot.yields or {}).culture or 0,
    (snapshot.yields or {}).faith or 0, (snapshot.yields or {}).gold or 0))
  if snapshot.ownBonuses and snapshot.ownBonuses[1] then
    table.insert(lines, "[NEWLINE]• Your relevant leader/civilization profile includes " .. snapshot.ownBonuses[1] .. ".")
  end
  for _, opponent in ipairs(snapshot.opponents or {}) do
    local relation = opponent.atWar and "at war" or "at peace"
    local balance = (opponent.visibleMilitary or 0) > (snapshot.militaryStrength or 0)
      and "a visible local strength advantage" or "no visible local strength advantage"
    table.insert(lines, string.format("[NEWLINE]• %s is %s, has %d currently visible military strength, and shows %s.",
      opponent.name, relation, opponent.visibleMilitary or 0, balance))
    if opponent.bonuses and opponent.bonuses[1] then
      table.insert(lines, "[NEWLINE]• Known opponent bonus — " .. opponent.bonuses[1] .. ".")
    end
  end
  table.insert(lines, string.format(
    "[NEWLINE]• Victory weighting — science %.2f, culture %.2f, domination %.2f, religion %.2f.",
    weights.science, weights.culture, weights.domination, weights.religion))
  if snapshot.suzerainCount and snapshot.suzerainCount > 0 then
    table.insert(lines, string.format("[NEWLINE]• You currently suzerain %d known city-state(s); their strategic value is preserved in risk scoring.", snapshot.suzerainCount))
  end
  table.insert(lines, string.format("[NEWLINE]• Composite score: %.1f. Only currently player-visible information was evaluated.", candidate.score))
  return table.concat(lines, "")
end

local function generateUnitCandidates(snapshot, weights, candidates)
  for _, unit in ipairs(snapshot.units or {}) do
    local threat, strongest = visibleThreatNear(snapshot, unit, 4)
    local healthLost = 100 - (unit.health or 100)

    if healthLost >= 20 then
      local healScore = healthLost * 0.9 + threat * -0.35 + weights.survival * 14
      addCandidate(candidates, {
        kind = "HEAL", unitId = unit.id, destination = unit.plotIndex,
        title = "Heal " .. unit.name,
        score = healScore,
        reason = "Preserve an experienced unit instead of trading future combat value for a low-quality action now.",
        steps = { "Keep the unit on its current tile and choose Heal." },
        factors = {
          string.format("The unit is missing %d health.", healthLost),
          string.format("Visible local threat pressure is %.1f.", threat),
        },
      })
    end

    for _, attack in ipairs(unit.attacks or {}) do
      local margin = (unit.combat or 0) - (attack.defenderCombat or 0)
      local score = 45 + margin * 2.1 + weights.domination * 13 - (unit.health and (100 - unit.health) * 0.25 or 0)
      if attack.isCity then score = score + weights.domination * 12 end
      addCandidate(candidates, {
        kind = "ATTACK", unitId = unit.id, destination = attack.plotIndex,
        title = "Attack " .. (attack.name or "visible target") .. " with " .. unit.name,
        score = score,
        path = attack.path,
        reason = margin >= 0 and "This is a favorable visible combat exchange." or "This attack is strategically useful despite a difficult direct matchup.",
        steps = { "Select " .. unit.name .. ".", "Attack the highlighted target." },
        factors = {
          string.format("Estimated visible strength margin: %+d.", margin),
          attack.isCity and "The target is a city, so the action directly advances domination leverage." or "Removing this unit reduces local enemy action economy.",
        },
      })
    end

    for _, move in ipairs(unit.moves or {}) do
      local tileThreat = visibleThreatNear(snapshot, move, 3)
      local value = yieldValue(move, weights)
      local score = value * 2.4 - tileThreat * (unit.isCivilian and 1.4 or 0.25)
      local kind = "POSITION"
      local purpose = "Improve position while retaining future options."
      if move.frontier then
        kind = "EXPLORE"
        score = score + 18 + weights.science * 3 + weights.expansion * 4
        purpose = "Reveal new terrain and improve expansion, contact, and route information."
      elseif move.defendsCity then
        kind = "DEFEND"
        score = score + 22 + weights.survival * 8
        purpose = "Reinforce a threatened city and deny an easy attack vector."
      elseif unit.isSettler and move.canSettle then
        kind = "SETTLE"
        score = score + 38 + weights.expansion * 18 + value * 2
        purpose = "Found a city on a high-value legal tile and convert map control into long-term yields."
      elseif unit.isBuilder and move.improvable then
        kind = "IMPROVE"
        score = score + 26 + value * 2 + weights.economy * 5
        purpose = "Convert a workable tile into immediate and compounding empire output."
      end
      addCandidate(candidates, {
        kind = kind, unitId = unit.id, destination = move.plotIndex,
        title = purpose:gsub("%.$", "") .. " (" .. unit.name .. ")",
        score = score,
        path = move.path,
        reason = purpose,
        steps = { "Select " .. unit.name .. ".", "Follow the highlighted path to the destination." },
        factors = {
          string.format("Destination tile economic value: %.1f.", value),
          string.format("Visible threat pressure near destination: %.1f.", tileThreat),
          strongest and ("The strongest nearby visible threat is " .. strongest.unit.name .. ".") or "No nearby enemy unit is currently visible.",
        },
      })
    end
  end
end

local function generateFormationCandidate(snapshot, weights, candidates)
  local military = {}
  for _, unit in ipairs(snapshot.units or {}) do
    if not unit.isCivilian and (unit.combat or 0) > 0 and (unit.movesRemaining or 0) > 0 then
      table.insert(military, unit)
    end
  end
  if #military < 2 or #(snapshot.visibleEnemyUnits or {}) == 0 then return end

  local target = snapshot.visibleEnemyUnits[1]
  table.sort(military, function(a, b) return Util.Distance(a, target) < Util.Distance(b, target) end)
  local selected = { military[1], military[2] }
  if military[3] and Util.Distance(military[3], target) <= 7 then table.insert(selected, military[3]) end

  local steps, unitIds, paths = {}, {}, {}
  local totalStrength = 0
  for _, unit in ipairs(selected) do
    table.insert(unitIds, unit.id)
    totalStrength = totalStrength + (unit.combat or 0)
    local bestMove = unit.moves and unit.moves[1]
    if bestMove then
      table.insert(steps, "Move " .. unit.name .. " to the highlighted rally area.")
      for _, plotIndex in ipairs(bestMove.path or {}) do table.insert(paths, plotIndex) end
    end
  end
  addCandidate(candidates, {
    kind = "FORMATION", unitId = selected[1].id, unitIds = unitIds,
    destination = target.plotIndex, path = paths,
    title = "Form a coordinated group against " .. target.name,
    score = 32 + totalStrength * 0.35 + weights.domination * 14 + weights.survival * 7,
    reason = "Concentrating multiple units creates support, flanking, zone-control, and focus-fire options that isolated moves do not.",
    steps = steps,
    factors = {
      string.format("The proposed group combines %d units and %d visible combat strength.", #selected, totalStrength),
      "The target and every path endpoint used by this plan are currently visible.",
    },
  })
end

local function generateCityCandidates(snapshot, weights, candidates)
  local profiles = {
    {
      key = "science", yieldKey = "science", kind = "SCIENCE_CITY", label = "Advance science infrastructure in ",
      reason = "Science converts production into earlier technologies, stronger units, and the space-race path.",
      step = "Open city production and prioritize the best legal Campus, science building, or prerequisite.",
    },
    {
      key = "culture", yieldKey = "culture", kind = "CULTURE_CITY", label = "Advance culture infrastructure in ",
      reason = "Culture accelerates governments and policies while building the tourism engine for a cultural victory.",
      step = "Open city production and prioritize the best legal Theater Square, culture building, or prerequisite.",
    },
    {
      key = "religion", yieldKey = "faith", kind = "RELIGION_CITY", label = "Advance religious infrastructure in ",
      reason = "Faith, religious unit throughput, and belief leverage are the core conversion resources for a religious victory.",
      step = "Open city production and prioritize the best legal Holy Site, religious building, or prerequisite.",
    },
    {
      key = "domination", yieldKey = "production", kind = "MILITARY_CITY", label = "Advance military production in ",
      reason = "Military production converts strategic tempo into deterrence, defense, and capital-capture potential.",
      step = "Open city production and prioritize the best legal counter-unit, siege unit, Encampment, or prerequisite.",
    },
  }

  for _, city in ipairs(snapshot.cities or {}) do
    local best, bestScore = nil, -999
    for _, profile in ipairs(profiles) do
      local existing = (city.yields or {})[profile.yieldKey] or 0
      local score = weights[profile.key] * 24 + city.population * 2.5 + (city.yields.production or 0) * 1.2 - existing * 0.25
      if profile.key == "domination" and city.visibleThreat > 0 then score = score + 25 + weights.survival * 8 end
      if city.needsProduction then score = score + 35 end
      if score > bestScore then best, bestScore = profile, score end
    end
    if best then
      addCandidate(candidates, {
        kind = best.kind, cityId = city.id, destination = city.plotIndex,
        title = best.label .. city.name,
        score = bestScore,
        reason = best.reason,
        steps = { "Select " .. city.name .. ".", best.step },
        factors = {
          string.format("%s has %d population and %.1f production per turn.", city.name, city.population, city.yields.production or 0),
          string.format("Visible military pressure near the city: %d.", city.visibleThreat or 0),
          city.needsProduction and "The production queue currently requires an immediate choice." or "This competes against the city's current production and should be chosen only if the highlighted strategic payoff is larger.",
        },
      })
    end
  end
end

local function deduplicateAndLimit(candidates, count)
  table.sort(candidates, function(a, b)
    if a.score == b.score then return a.title < b.title end
    return a.score > b.score
  end)
  local result, seen = {}, {}
  for _, candidate in ipairs(candidates) do
    local key = candidate.kind .. ":" .. tostring(candidate.unitId) .. ":" .. tostring(candidate.destination)
    if not seen[key] then
      seen[key] = true
      table.insert(result, candidate)
      if #result >= count then break end
    end
  end
  return result
end

function Evaluator.Rank(snapshot, count)
  local weights = Strategy.Derive(snapshot)
  local candidates = {}
  generateUnitCandidates(snapshot, weights, candidates)
  generateFormationCandidate(snapshot, weights, candidates)
  generateCityCandidates(snapshot, weights, candidates)
  local result = deduplicateAndLimit(candidates, count or 5)
  for _, candidate in ipairs(result) do
    candidate.explanation = actionExplanation(candidate, snapshot, weights)
  end
  return result
end

return Evaluator
