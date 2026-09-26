# Architecture

The advisor is deliberately split into two trust zones.

`CivVITrainer_State.lua` is the Civ VI adapter. It reads the local player,
friendly empire, contacted opponents, public diplomacy, suzerainty, and only
enemy units whose plots are currently visible. It emits plain Lua tables.

`CivVITrainer_Evaluator.lua` and `CivVITrainer_Strategy.lua` are offline pure
logic. They cannot call the game API. They generate candidates, score them, form
multi-unit plans, deduplicate near-identical actions, and produce explanations.

`CivVITrainer.lua` renders the top five candidates and previews a selected plan.
It does not call `RequestOperation` or any other order-issuing API.

## Scoring

Candidate score is an additive model with these families:

- tactical exchange: combat margin, health, target type, and threat pressure;
- positional value: tile yields, visibility frontier, city defense, and safety;
- strategic fit: science, culture, domination, religion, economy, survival, and
  expansion weights;
- timing: early expansion, wartime survival, and late-game victory conversion;
- coordination: concentration of force and multi-unit action economy.

Victory weights start balanced, then adjust using the selected vanilla leader,
current empire yields, war state, and stage of game. This makes all four vanilla
victory paths first-class without forcing the player to choose one prematurely.

## Why no bundled LLM yet

A local model under 5 GB is feasible, but distributing and launching a model
process from a Civ VI UI mod adds platform packaging, memory, latency, and trust
complexity without improving move legality. The first release therefore uses a
fully deterministic explanation engine. A future optional sidecar can rewrite
the structured explanation, but it will never rank moves or receive hidden data.

