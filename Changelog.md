# Changelog

All notable Changes to the Julia package `AlgorithmsInterface.jl` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] unreleased

### Fixed

- `indicates_convergence(::StoppingCriterion, ::StoppingCriterionState)` had its condition inverted, claiming convergence exactly when the criterion had *not* indicated to stop.
- `indicates_convergence` for `StopWhenAll` and `StopWhenAny` now consults the children that actually indicated to stop.
  Previously a `StopWhenAny` pairing a convergence criterion with a fallback such as `StopAfterIteration` could never report convergence, since the criteria-only variant is `all(indicates_convergence, criteria)`.
- `is_finished!` for `StopWhenAll` and `StopWhenAny` short-circuited, skipping the children after the deciding one.
  Stateful criteria were starved of the current iterate and their `at_iteration` left unset even when they did indicate to stop; every child is now updated once per iteration.
- `get_reason` for `StopWhenAll` and `StopWhenAny` rendered children that had not indicated to stop as the literal text `"nothing"`.

## [0.1.0] 2026-05-01

Initial release.
