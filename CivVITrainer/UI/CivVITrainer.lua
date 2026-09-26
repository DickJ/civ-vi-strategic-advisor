local State = include("CivVITrainer_State")
local Evaluator = include("CivVITrainer_Evaluator")

local m_recommendations = {}
local m_highlightedPlots = {}
local m_refreshPending = false
local m_refreshDelay = 0

local m_buttons = {
  Controls.Move1, Controls.Move2, Controls.Move3, Controls.Move4, Controls.Move5,
}
local m_labels = {
  Controls.Move1Text, Controls.Move2Text, Controls.Move3Text, Controls.Move4Text, Controls.Move5Text,
}

local function clearHighlights()
  if #m_highlightedPlots > 0 then
    pcall(function() UI.HighlightPlots(PlotHighlightTypes.MOVEMENT, false, m_highlightedPlots) end)
  end
  m_highlightedPlots = {}
end

local function showRecommendation(index)
  local recommendation = m_recommendations[index]
  if not recommendation then return end

  clearHighlights()
  Controls.Explanation:SetText(recommendation.explanation)
  Controls.ExplanationScroll:CalculateInternalSize()

  local player = Players[Game.GetLocalPlayer()]
  local unit = player and player:GetUnits():FindID(recommendation.unitId) or nil
  if unit then
    pcall(function()
      UI.DeselectAllCities()
      UI.DeselectAllUnits()
      UI.SelectUnit(unit)
    end)
  elseif player and recommendation.cityId then
    local city = player:GetCities():FindID(recommendation.cityId)
    if city then
      pcall(function()
        UI.DeselectAllUnits()
        UI.DeselectAllCities()
        UI.SelectCity(city)
      end)
    end
  end

  local destinationPlot = recommendation.destination and Map.GetPlotByIndex(recommendation.destination) or nil
  if destinationPlot then
    UI.LookAtPlot(destinationPlot:GetX(), destinationPlot:GetY())
  elseif unit then
    UI.LookAtPlot(unit:GetX(), unit:GetY())
  end

  for _, plotIndex in ipairs(recommendation.path or {}) do
    table.insert(m_highlightedPlots, plotIndex)
  end
  if recommendation.destination then table.insert(m_highlightedPlots, recommendation.destination) end
  if #m_highlightedPlots > 0 then
    pcall(function() UI.HighlightPlots(PlotHighlightTypes.MOVEMENT, true, m_highlightedPlots) end)
  end
end

local function render()
  for index = 1, 5 do
    local recommendation = m_recommendations[index]
    m_buttons[index]:SetHide(recommendation == nil)
    if recommendation then
      m_labels[index]:SetText(string.format("%d. %s  [COLOR_Gold](%.0f)[ENDCOLOR]", index, recommendation.title, recommendation.score))
      m_buttons[index]:SetToolTipString("Click to preview this plan on the map.")
    end
  end
  Controls.MainStack:CalculateSize()
  Controls.MainStack:ReprocessAnchoring()
  Controls.AdvisorPanel:SetSizeY(Controls.MainStack:GetSizeY() + 32)
end

local function refresh()
  m_refreshPending = false
  m_refreshDelay = 0
  local ok, snapshot = pcall(State.Capture)
  if not ok or not snapshot then
    Controls.Status:SetText("Waiting for a playable local turn. Check Lua.log if this persists.")
    m_recommendations = {}
    render()
    return
  end

  local rankedOk, recommendations = pcall(Evaluator.Rank, snapshot, 5)
  if not rankedOk then
    Controls.Status:SetText("Analysis encountered an adapter error; see Lua.log.")
    print("CivVITrainer evaluator error: " .. tostring(recommendations))
    m_recommendations = {}
  else
    m_recommendations = recommendations
    Controls.Status:SetText(string.format(
      "Turn %d • %d units • %d visible opponent units • offline analysis",
      snapshot.turn, #snapshot.units, #snapshot.visibleEnemyUnits))
  end
  Controls.Explanation:SetText("Select a recommendation to see its technical explanation.")
  clearHighlights()
  render()
end

local function scheduleRefresh(delay)
  m_refreshPending = true
  m_refreshDelay = math.max(m_refreshDelay, delay or 0.15)
end

local function onUpdate(deltaTime)
  if not m_refreshPending then return end
  m_refreshDelay = m_refreshDelay - deltaTime
  if m_refreshDelay <= 0 and not UI.IsGameCoreBusy() then refresh() end
end

local function initialize()
  for index, button in ipairs(m_buttons) do
    button:RegisterCallback(Mouse.eLClick, function() showRecommendation(index) end)
  end
  Controls.RefreshButton:RegisterCallback(Mouse.eLClick, refresh)
  Controls.RefreshButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over") end)
  ContextPtr:SetUpdate(onUpdate)
  Events.LoadGameViewStateDone.Add(function() scheduleRefresh(0.25) end)
  Events.LocalPlayerTurnBegin.Add(function() scheduleRefresh(0.25) end)
  Events.GameCoreEventPlaybackComplete.Add(function() scheduleRefresh(0.30) end)
  scheduleRefresh(0.25)
  print("CivVITrainer initialized")
end

initialize()
