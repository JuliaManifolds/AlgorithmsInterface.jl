@doc """
    StoppingCriterion

An abstract type to represent a stopping criterion of an [`Algorithm`](@ref).

A concrete [`StoppingCriterion`](@ref) is the static half of a stopping criterion, holding the
values it is configured with, while the [`StoppingCriterionState`](@ref) it is paired with
records what happens during a run.

It should usually implement

* [`is_finished!`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
* [`is_finished`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
* [`get_reason`](@ref)`(stopping_criterion, stopping_criterion_state)`
* [`indicates_convergence`](@ref)`(::Type{<:StoppingCriterion})`

Note that only [`indicates_convergence`](@ref) has to be implemented:
it answers whether meeting this criterion *would* mean convergence, which is a static property of the criterion type alone.
Both the variant taking a criterion and the one that additionally takes a [`StoppingCriterionState`](@ref), answering whether it *did* happen are derived from it.

A criterion that has to remember more than the iteration at which it indicated to stop
additionally implements
[`initialize_state(problem::Problem, algorithm::Algorithm, stopping_criterion::StoppingCriterion; kwargs...)`](@ref)
to fill the `data` field of its state, as well as the corresponding mutating variant to reset it.
"""
abstract type StoppingCriterion end

@doc """
    StoppingCriterionState

The state a [`StoppingCriterion`](@ref) is in within a [`State`](@ref).

It records the iteration at which its [`StoppingCriterion`](@ref) indicated to stop, next to a
single field for anything else that criterion has to remember from one iteration to the next.
Since that field is opaque to this package, this single type serves every
[`StoppingCriterion`](@ref), which therefore dispatches its methods on itself rather than on a
state of its own.

# Fields

* `at_iteration::Int` stores the iteration number at which this state indicated to stop.
  * `0` means it already indicated to stop at the start.
  * any negative number means that it has not yet indicated to stop.
* `data` stores any further data the criterion has to carry from one iteration to the next,
  for example a value it compares against in the next one.
  It is opaque to this package, and none of its contents are exposed as properties of the
  state, so a criterion reaches them through `stopping_criterion_state.data`.
  A mutable struct of its own is the recommended choice; `nothing`, the default, indicates
  that the criterion needs no further data.

# Constructor

    StoppingCriterionState(data = nothing)
    StoppingCriterionState(at_iteration, data)

Initialize the state to not having indicated to stop yet, carrying `data` alongside it.
The second form is the one that also sets the iteration it records.
"""
mutable struct StoppingCriterionState{D}
    at_iteration::Int
    data::D
end

StoppingCriterionState(data = nothing) = StoppingCriterionState(-1, data)

# Throughout, `stopping_state_data = nothing` means that the criterion decides which data to
# carry, so on a reset it keeps whatever the state already holds.
_reset_data(stopping_criterion_state::StoppingCriterionState, stopping_state_data) =
    isnothing(stopping_state_data) ? stopping_criterion_state.data : stopping_state_data

# Fallbacks for any criterion that needs no data of its own, so that such a criterion does not
# have to provide these two methods at all.
initialize_state(
    ::Problem, ::Algorithm, ::StoppingCriterion; stopping_state_data = nothing, kwargs...
) = StoppingCriterionState(stopping_state_data)
function initialize_state!(
        ::Problem, ::Algorithm, ::StoppingCriterion,
        stopping_criterion_state::StoppingCriterionState;
        stopping_state_data = nothing, kwargs...,
    )
    stopping_criterion_state.at_iteration = -1
    stopping_criterion_state.data = _reset_data(stopping_criterion_state, stopping_state_data)
    return stopping_criterion_state
end
