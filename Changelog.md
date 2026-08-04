# Changelog

All notable Changes to the Julia package `AlgorithmsInterface.jl` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] unreleased

### Added

- `is_active(stopping_criterion, stopping_criterion_state)`, the machine-readable counterpart of `get_reason`, reporting whether a criterion became active during the current run.
  It defaults to reading the state's `at_iteration` and is what the generic convergence reporting is now built on, rather than `!isnothing(get_reason(...))`.
- `get_active_stopping_criteria`, reporting which criteria became active.
  It recurses through nested combinations, so it separates stopping on a collapsed step size from stopping on an exhausted iteration budget — a distinction `indicates_convergence` is too coarse for.
- Convenience two-argument `get_reason(algorithm, state)`, and likewise for `is_active`, `indicates_convergence` and `get_active_stopping_criteria`, extracting the criterion and its state the way `is_finished` already did.
- `StopReasonAction`, a `LoggingAction` that reports `get_reason` at the `:Stop` context.
- Defaults for `get_reason` (`nothing`) and for the type-domain `indicates_convergence` (`false`), so a criterion that implements neither no longer hits a `MethodError` from the derived convergence reporting.
- `StopAfterTimePeriodData`, exported, holding the clock `StopAfter` carries as the `data` of its state, which a downstream criterion working on time measurements is expected to reuse.
- Defaults for `initialize_state` and `initialize_state!` returning and resetting a `State`, so that an algorithm only has to provide a `Problem`, an `Algorithm` and a `step!`.
- Defaults for `initialize_state(problem, algorithm, stopping_criterion)` and its mutating variant, returning and resetting a `StoppingCriterionState`, with a `stopping_state_data` keyword to seed its `data`.
  Every criterion honours that keyword rather than hardcoding its data: `nothing`, the default, leaves the criterion to decide, which on a reset means keeping the data the state already carries.
  `StopAfter` takes the `StopAfterTimePeriodData` it is handed and otherwise makes a fresh one, and `StopWhenAll` and `StopWhenAny` read it as the states of the criteria they combine, in the order of their `criteria`.

### Changed

- `State` is no longer an abstract type but the concrete state every algorithm runs with, storing the `iterate`, the `stopping_criterion_state` and the `iteration` next to a single `data` field for anything else an algorithm has to carry from one step to the next.
  The `data` field is opaque to this package and none of its contents are exposed as properties, so an algorithm reaches them through `state.data`, which is what makes one state type enough for all of them.
  An algorithm that used to define a state of its own now defines nothing at all, or, if it wants to decide where to start from rather than being handed an `iterate`, only an `initialize_state` returning a `State`.
- `increment!` takes the problem and the algorithm as well, as `increment!(problem, algorithm, state)`, so that per-iteration bookkeeping beyond the iteration counter remains overloadable now that it can no longer dispatch on a state of its own.
- `initialize_state` and `initialize_state!` take their arguments positionally, as `(problem, algorithm, iterate, state_data, stopping_state_data)` and `(problem, algorithm, state, iterate, state_data, stopping_state_data)`, rather than through `iterate`, `state_data` and `stopping_state_data` keywords.
  Everything beyond the `iterate` is optional, and `initialize_state!` defaults every argument to what the `state` already holds, so an in-place reset only takes what actually changes.
  `solve` and `solve!` forward their trailing positional arguments there, so `solve(problem, algorithm; iterate = x)` becomes `solve(problem, algorithm, x)`.
  An algorithm that decides where it starts still implements `initialize_state(problem, algorithm; kwargs...)`, which is what `solve(problem, algorithm)` reaches, and which no longer has to declare an `iterate` keyword to do so.
- `indicates_convergence` without a state moved to the type domain: a new criterion implements `indicates_convergence(::Type{YourCriterion})`, and `indicates_convergence(criterion)` forwards to it.
  `StopWhenAll` and `StopWhenAny` combine their children in the type domain as well, so a criterion that only implements the variant taking an instance is no longer accounted for in a group.
- `StoppingCriterionState` is no longer an abstract type but the concrete state every criterion runs with, storing the `at_iteration` at which the criterion indicated to stop next to a single `data` field for whatever else it has to remember from one iteration to the next.
  Both states put their `data` last, after the iteration they record: `StoppingCriterionState(at_iteration, data)` and `State(iterate, stopping_criterion_state, iteration, data)`, each with a shorter form omitting that iteration, as `StoppingCriterionState(data = nothing)` and `State(iterate, stopping_criterion_state, data = nothing)`.
  A criterion therefore dispatches `is_finished!`, `get_reason` and the rest on itself rather than on a state of its own, and defines `initialize_state` only to fill that `data` field.
  `StopAfter` keeps its clock there as a `StopAfterTimePeriodData`, and `StopWhenAll` and `StopWhenAny` the states of the criteria they combine, as a tuple in the order of their `criteria`.
- `StopAfterIteration` no longer carries its own `initialize_state` and `initialize_state!`, which the new criterion-level defaults now cover.

### Removed

- The abstract `State`: subtyping it is no longer how an algorithm provides a state, since the concrete `State` serves every algorithm.
- `AlgorithmsInterface.Test.DummyState`, which the concrete `State` replaces.
- The abstract `StoppingCriterionState`, along with `DefaultStoppingCriterionState`, `StopAfterTimePeriodState` and `GroupStoppingCriterionState`, all of which the concrete `StoppingCriterionState` replaces.

### Fixed

- `indicates_convergence(::StoppingCriterion, ::StoppingCriterionState)` had its condition inverted, claiming convergence exactly when the criterion had *not* indicated to stop.
- `indicates_convergence` for `StopWhenAll` and `StopWhenAny` now consults the children that actually indicated to stop.
  Previously a `StopWhenAny` pairing a convergence criterion with a fallback such as `StopAfterIteration` could never report convergence, since the criteria-only variant is `all(indicates_convergence, criteria)`.
- `is_finished!` for `StopWhenAll` and `StopWhenAny` short-circuited, skipping the children after the deciding one.
  Stateful criteria were starved of the current iterate and their `at_iteration` left unset even when they did indicate to stop; every child is now updated once per iteration.
- `get_reason` for `StopWhenAll` and `StopWhenAny` rendered children that had not indicated to stop as the literal text `"nothing"`, and returned `""` when no child had a message at all.
  It now reports only the children that triggered, and `nothing` when there is nothing to report.
- The non-mutating `is_finished` for `StopWhenAll` and `StopWhenAny` reset `at_iteration` at iteration `0`, contradicting its contract and silently clearing a group's recorded stop.
- The non-mutating `is_finished` for `StopAfter` reported the elapsed time recorded by the last `is_finished!` rather than reading the clock, so it could answer "not finished" for a run long past its threshold.
- `get_reason` for `StopAfterIteration` was gated on `at_iteration >= max_iterations` while its `Base.summary` was gated on `at_iteration >= 0`, so the two could disagree.

## [0.1.0] 2026-05-01

Initial release.
