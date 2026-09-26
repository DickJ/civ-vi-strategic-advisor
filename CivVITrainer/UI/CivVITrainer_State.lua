include("CivVITrainer_Util")
local Util = CivVITrainer_Util
local State = {}

local function lookup(text)
  if text == nil then return "Unknown" end
  return Util.Try(function() return Locale.Lookup(text) end, tostring(text))
end

local function plotYields(plot)
  return {
    food = Util.Try(function() return plot:GetYield(YieldTypes.FOOD) end, 0),
    production = Util.Try(function() return plot:GetYield(YieldTypes.PRODUCTION) end, 0),
    gold = Util.Try(function() return plot:GetYield(YieldTypes.GOLD) end, 0),
    science = Util.Try(function() return plot:GetYield(YieldTypes.SCIENCE) end, 0),
    culture = Util.Try(function() return plot:GetYield(YieldTypes.CULTURE) end, 0),
    faith = Util.Try(function() return plot:GetYield(YieldTypes.FAITH) end, 0),
  }
end

local function isVisible(visibility, plot)
  return visibility ~= nil and plot ~= nil
    and Util.Try(function() return visibility:IsVisible(plot:GetX(), plot:GetY()) end, false)
end

local function isFrontier(visibility, plot)
  if not plot then return false end
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    local adjacent = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction)
    if adjacent and not Util.Try(function()
      return visibility:IsRevealed(adjacent:GetX(), adjacent:GetY())
    end, true) then
      return true
    end
  end
  return false
end

local function leaderTraits(leaderType, civilizationType)
  local descriptions = {}
  local traitTypes = {}
  if GameInfo.LeaderTraits then
    for row in GameInfo.LeaderTraits() do
      if row.LeaderType == leaderType then traitTypes[row.TraitType] = true end
    end
  end
  if GameInfo.CivilizationTraits then
    for row in GameInfo.CivilizationTraits() do
      if row.CivilizationType == civilizationType then traitTypes[row.TraitType] = true end
    end
  end
  for traitType, _ in pairs(traitTypes) do
    local row = GameInfo.Traits and GameInfo.Traits[traitType]
    if row then
      local name = lookup(row.Name or traitType)
      local description = lookup(row.Description or "")
      table.insert(descriptions, name .. (description ~= "" and (": " .. description) or ""))
    end
  end
  return descriptions
end

local function unitName(unit)
  local row = GameInfo.Units[unit:GetUnitType()]
  return row and lookup(row.Name) or "Unit"
end

local function unitPath(unit, plotIndex)
  local path = Util.Try(function()
    local pathInfo = UnitManager.GetMoveToPath(unit, plotIndex)
    return pathInfo
  end, nil)
  local result = {}
  if path then
    for _, node in ipairs(path) do
      if type(node) == "number" then
        table.insert(result, node)
      elseif type(node) == "table" and node.GetIndex then
        table.insert(result, node:GetIndex())
      end
    end
  end
  return result
end

local function bestVisibleUnitAt(plotIndex, localPlayerId)
  local best = nil
  local units = Util.Try(function() return Units.GetUnitsInPlot(plotIndex) end, {}) or {}
  for _, unit in ipairs(units) do
    if unit:GetOwner() ~= localPlayerId then
      local combat = math.max(
        Util.Try(function() return unit:GetCombat() end, 0),
        Util.Try(function() return unit:GetRangedCombat() end, 0))
      if not best or combat > best.combat then
        best = {
          id = unit:GetID(), owner = unit:GetOwner(), combat = combat,
          name = unitName(unit), plotIndex = plotIndex,
          x = unit:GetX(), y = unit:GetY(),
        }
      end
    end
  end
  return best
end

local function reachableMoves(unit, visibility, localPlayerId, cities)
  local result = {}
  local plotIndexes = Util.Try(function() return UnitManager.GetReachableMovement(unit) end, {}) or {}
  local limit = math.min(#plotIndexes, 24)
  for index = 1, limit do
    local plotIndex = plotIndexes[index]
    local plot = Map.GetPlotByIndex(plotIndex)
    if plot and isVisible(visibility, plot) then
      local owner = Util.Try(function() return plot:GetOwner() end, -1)
      local improvement = Util.Try(function() return plot:GetImprovementType() end, -1)
      local move = {
        plotIndex = plotIndex, x = plot:GetX(), y = plot:GetY(),
        yields = plotYields(plot), path = unitPath(unit, plotIndex),
        frontier = isFrontier(visibility, plot),
        canSettle = not plot:IsWater() and not plot:IsImpassable()
          and owner == -1 and Util.Try(function() return plot:GetResourceType() end, -1) == -1,
        improvable = not plot:IsWater() and improvement == -1
          and (owner == localPlayerId or owner == -1),
        defendsCity = false,
      }
      for _, city in ipairs(cities) do
        if Util.Distance(move, city) <= 1 and city.visibleThreat > 0 then move.defendsCity = true end
      end
      table.insert(result, move)
    end
  end
  table.sort(result, function(a, b)
    local ay = a.yields.production * 2 + a.yields.food + a.yields.science + a.yields.culture + a.yields.faith
    local by = b.yields.production * 2 + b.yields.food + b.yields.science + b.yields.culture + b.yields.faith
    if a.frontier then ay = ay + 5 end
    if b.frontier then by = by + 5 end
    return ay > by
  end)
  while #result > 6 do table.remove(result) end
  return result
end

local function reachableAttacks(unit, visibility, localPlayerId)
  local result = {}
  local targets = Util.Try(function() return UnitManager.GetReachableTargets(unit) end, {}) or {}
  for _, plotIndex in ipairs(targets) do
    local plot = Map.GetPlotByIndex(plotIndex)
    if plot and isVisible(visibility, plot) then
      local target = bestVisibleUnitAt(plotIndex, localPlayerId)
      if target then
        target.defenderCombat = target.combat
        target.path = unitPath(unit, plotIndex)
        target.isCity = false
        table.insert(result, target)
      else
        local city = Util.Try(function() return Cities.GetCityInPlot(plot:GetX(), plot:GetY()) end, nil)
        if city and city:GetOwner() ~= localPlayerId then
          table.insert(result, {
            name = lookup(city:GetName()), plotIndex = plotIndex, isCity = true,
            defenderCombat = Util.Try(function() return city:GetStrength() end, 20),
            path = unitPath(unit, plotIndex),
          })
        end
      end
    end
  end
  return result
end

local function collectVisibleEnemies(localPlayerId, localPlayer, visibility)
  local enemies, opponents = {}, {}
  local diplomacy = localPlayer:GetDiplomacy()
  for _, player in ipairs(PlayerManager.GetAliveMajors()) do
    local playerId = player:GetID()
    if playerId ~= localPlayerId and player and player:IsAlive()
      and Util.Try(function() return player:IsMajor() end, false)
      and Util.Try(function() return diplomacy:HasMet(playerId) end, false) then
      local config = PlayerConfigurations[playerId]
      local leaderType = config and config:GetLeaderTypeName() or ""
      local civType = config and Util.Try(function() return config:GetCivilizationTypeName() end, "") or ""
      local opponent = {
        id = playerId,
        name = config and lookup(config:GetCivilizationShortDescription()) or ("Player " .. playerId),
        leaderType = leaderType,
        atWar = Util.Try(function() return diplomacy:IsAtWarWith(playerId) end, false),
        bonuses = leaderTraits(leaderType, civType),
        visibleMilitary = 0,
      }
      for _, unit in player:GetUnits():Members() do
        local plot = Map.GetPlot(unit:GetX(), unit:GetY())
        if isVisible(visibility, plot) then
          local combat = math.max(
            Util.Try(function() return unit:GetCombat() end, 0),
            Util.Try(function() return unit:GetRangedCombat() end, 0))
          table.insert(enemies, {
            id = unit:GetID(), owner = playerId, name = unitName(unit), combat = combat,
            health = 100 - Util.Try(function() return unit:GetDamage() end, 0),
            x = unit:GetX(), y = unit:GetY(), plotIndex = plot:GetIndex(),
            opponentName = opponent.name, opponentBonuses = opponent.bonuses,
          })
          opponent.visibleMilitary = opponent.visibleMilitary + combat
        end
      end
      table.insert(opponents, opponent)
    end
  end
  return enemies, opponents
end

local function collectCities(player, visibleEnemies)
  local cities = {}
  for _, city in player:GetCities():Members() do
    local entry = {
      id = city:GetID(), name = lookup(city:GetName()), x = city:GetX(), y = city:GetY(),
      plotIndex = Map.GetPlot(city:GetX(), city:GetY()):GetIndex(),
      population = city:GetPopulation(), visibleThreat = 0,
      yields = {
        science = Util.Try(function() return city:GetYield(YieldTypes.SCIENCE) end, 0),
        culture = Util.Try(function() return city:GetYield(YieldTypes.CULTURE) end, 0),
        faith = Util.Try(function() return city:GetYield(YieldTypes.FAITH) end, 0),
        production = Util.Try(function() return city:GetYield(YieldTypes.PRODUCTION) end, 0),
      },
      needsProduction = Util.Try(function()
        return city:GetBuildQueue():GetCurrentProductionTypeHash() == 0
      end, false),
    }
    for _, enemy in ipairs(visibleEnemies) do
      if Util.Distance(entry, enemy) <= 4 then entry.visibleThreat = entry.visibleThreat + enemy.combat end
    end
    table.insert(cities, entry)
  end
  return cities
end

local function collectUnits(player, visibility, localPlayerId, cities)
  local units = {}
  for _, unit in player:GetUnits():Members() do
    local row = GameInfo.Units[unit:GetUnitType()]
    local combat = math.max(
      Util.Try(function() return unit:GetCombat() end, 0),
      Util.Try(function() return unit:GetRangedCombat() end, 0))
    local entry = {
      id = unit:GetID(), name = unitName(unit), x = unit:GetX(), y = unit:GetY(),
      plotIndex = Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex(),
      combat = combat,
      health = 100 - Util.Try(function() return unit:GetDamage() end, 0),
      movesRemaining = Util.Try(function() return unit:GetMovesRemaining() end, 0),
      isCivilian = combat <= 0,
      isSettler = row and row.FoundCity == true,
      isBuilder = row and (row.BuildCharges or 0) > 0,
    }
    if entry.movesRemaining > 0 then
      entry.moves = reachableMoves(unit, visibility, localPlayerId, cities)
      entry.attacks = reachableAttacks(unit, visibility, localPlayerId)
    else
      entry.moves, entry.attacks = {}, {}
    end
    table.insert(units, entry)
  end
  return units
end

local function collectSuzerains(localPlayerId)
  local count = 0
  for _, player in ipairs(PlayerManager.GetAliveMinors()) do
    if player and player:IsAlive() then
      local influence = Util.Try(function() return player:GetInfluence() end, nil)
      if influence and Util.Try(function() return influence:GetSuzerain() end, -1) == localPlayerId then
        count = count + 1
      end
    end
  end
  return count
end

function State.Capture()
  local localPlayerId = Game.GetLocalPlayer()
  if localPlayerId == nil or localPlayerId < 0 then return nil end
  local player = Players[localPlayerId]
  if not player then return nil end
  local visibility = PlayersVisibility[localPlayerId]
  local config = PlayerConfigurations[localPlayerId]
  local leaderType = config and config:GetLeaderTypeName() or ""
  local civType = config and Util.Try(function() return config:GetCivilizationTypeName() end, "") or ""
  local visibleEnemies, opponents = collectVisibleEnemies(localPlayerId, player, visibility)
  local cities = collectCities(player, visibleEnemies)

  local yields = { science = 0, culture = 0, faith = 0, gold = 0 }
  for _, city in player:GetCities():Members() do
    yields.science = yields.science + Util.Try(function() return city:GetYield(YieldTypes.SCIENCE) end, 0)
    yields.culture = yields.culture + Util.Try(function() return city:GetYield(YieldTypes.CULTURE) end, 0)
    yields.faith = yields.faith + Util.Try(function() return city:GetYield(YieldTypes.FAITH) end, 0)
    yields.gold = yields.gold + Util.Try(function() return city:GetYield(YieldTypes.GOLD) end, 0)
  end

  local units = collectUnits(player, visibility, localPlayerId, cities)
  local militaryStrength = 0
  for _, unit in ipairs(units) do militaryStrength = militaryStrength + (unit.combat or 0) end

  return {
    playerId = localPlayerId,
    turn = Game.GetCurrentGameTurn(),
    leaderType = leaderType,
    civilizationType = civType,
    ownBonuses = leaderTraits(leaderType, civType),
    yields = yields,
    cities = cities,
    visibleEnemyUnits = visibleEnemies,
    opponents = opponents,
    suzerainCount = collectSuzerains(localPlayerId),
    units = units,
    militaryStrength = militaryStrength,
  }
end

CivVITrainer_State = State
return State
