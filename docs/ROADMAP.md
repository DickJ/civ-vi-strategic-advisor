# Roadmap

## 0.1 — playable vertical slice

- Empire-wide unit action ranking
- Visible-state privacy boundary
- Tactical, settlement, builder, defense, exploration, healing, and formation plans
- All vanilla victory-condition weights
- Map focus/path highlighting and automatic same-turn refresh

## 0.2 — exact empire decisions

- Legal improvement selection rather than builder-position heuristics
- Exact named city production, technology, civic, government, policy, trade-route,
  religion, great-person, and diplomacy candidates
- Multi-turn opportunity cost and production overflow
- Exact combat preview values and ranged/city-strike candidates

## 0.3 — deeper opponent model

- Complete vanilla leader/civilization ability interpretation
- Known unique-unit timing windows and counter-unit advice
- Relationship modifiers, promises, warmonger exposure, and deal valuation
- City-state type/bonus evaluation in addition to current suzerain count

## 0.4 — planning

- Beam search across multiple friendly actions
- Collision-aware formation plans
- Persistent strategic objectives with automatic invalidation
- Save/load of advisor preferences without affecting saved-game compatibility

## 1.0

- Steam Workshop packaging
- In-game settings and accessibility pass
- Performance budgets for large maps
- Optional local-model explanation sidecar, strictly separated from ranking
