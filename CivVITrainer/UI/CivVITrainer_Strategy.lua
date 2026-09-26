local Util = include("CivVITrainer_Util")
local Strategy = {}

local BASE = {
  science = 1.00,
  culture = 1.00,
  domination = 1.00,
  religion = 1.00,
  economy = 1.00,
  survival = 1.25,
  expansion = 1.00,
}

local LEADER_HINTS = {
  LEADER_GILGAMESH = { domination = 0.25, science = 0.15 },
  LEADER_TRAJAN = { culture = 0.20, expansion = 0.25 },
  LEADER_PERICLES = { culture = 0.40 },
  LEADER_GORGO = { culture = 0.25, domination = 0.20 },
  LEADER_SALADIN = { religion = 0.30, science = 0.20 },
  LEADER_PETER_GREAT = { religion = 0.25, culture = 0.25 },
  LEADER_GANDHI = { religion = 0.40 },
  LEADER_HOJO = { religion = 0.15, culture = 0.15, domination = 0.15 },
  LEADER_QIN = { culture = 0.30 },
  LEADER_T_ROOSEVELT = { culture = 0.20, domination = 0.15 },
  LEADER_VICTORIA = { domination = 0.30, expansion = 0.15 },
  LEADER_CATHERINE_DE_MEDICI = { culture = 0.30 },
  LEADER_CLEOPATRA = { culture = 0.20, economy = 0.25 },
  LEADER_MVEMBA = { culture = 0.30, science = 0.10 },
  LEADER_HARDRADA = { domination = 0.35 },
  LEADER_FREDERICK = { domination = 0.20, science = 0.25 },
  LEADER_PHILIP_II = { religion = 0.30, domination = 0.20 },
  LEADER_TOMYRIS = { domination = 0.40 },
  LEADER_MONTEZUMA = { domination = 0.35, expansion = 0.15 },
}

local function add(weights, additions)
  for key, value in pairs(additions or {}) do
    weights[key] = (weights[key] or 0) + value
  end
end

function Strategy.Derive(snapshot)
  local weights = Util.Copy(BASE)
  add(weights, LEADER_HINTS[snapshot.leaderType])

  local turn = snapshot.turn or 0
  if turn < 60 then
    add(weights, { expansion = 0.35, survival = 0.15, science = 0.10 })
  elseif turn > 180 then
    add(weights, { science = 0.15, culture = 0.15, domination = 0.10, religion = 0.10 })
  end

  local yields = snapshot.yields or {}
  if (yields.faith or 0) > (yields.science or 0) * 1.2 then add(weights, { religion = 0.25 }) end
  if (yields.culture or 0) > (yields.science or 0) * 1.15 then add(weights, { culture = 0.20 }) end
  if (yields.science or 0) > (yields.culture or 0) * 1.25 then add(weights, { science = 0.20 }) end

  local hostile = 0
  for _, opponent in ipairs(snapshot.opponents or {}) do
    if opponent.atWar then hostile = hostile + 1 end
  end
  if hostile > 0 then add(weights, { survival = 0.55, domination = 0.30, expansion = -0.20 }) end

  return weights
end

return Strategy

