#
#
# A default state

@doc """
    DefaultState <: State

A [`State`](@ref) that stores the properties every [`State`](@ref) is expected to provide,
together with a single field to hold any further data an [`Algorithm`](@ref) needs.

Together with the default [`initialize_state`](@ref) and [`initialize_state!`](@ref) methods,
this spares a downstream algorithm the definition of its own state type:
a [`Problem`](@ref), an [`Algorithm`](@ref) and a [`step!`](@ref) method suffice.
Since [`step!`](@ref) dispatches on the [`Algorithm`](@ref), reusing this state costs no
flexibility in doing so.

# Fields

* `iterate` stores the current iterate ``x^{(k)}``.
* `stopping_criterion_state` stores the [`StoppingCriterionState`](@ref) belonging to the
  [`StoppingCriterion`](@ref) of the [`Algorithm`](@ref).
* `data` stores any further data that has to be carried from one step to the next.
  It is opaque to this package, and none of its contents are exposed as properties of the
  state, so an algorithm reaches them through `state.data`.
  A `NamedTuple` or a struct of its own keeps access to them type stable and is the
  recommended choice; `nothing` indicates that the algorithm needs no further data.
* `iteration::Int` stores the current iteration step ``k`` that is currently being performed
  or was last performed.

# Constructor

    DefaultState(iterate, stopping_criterion_state, data = nothing, iteration = 0)

Initialize the state to start at `iterate`, carrying `data` alongside it.
"""
mutable struct DefaultState{V, S <: StoppingCriterionState, D} <: State
    iterate::V
    stopping_criterion_state::S
    data::D
    iteration::Int
end

DefaultState(iterate, stopping_criterion_state::StoppingCriterionState, data = nothing) =
    DefaultState(iterate, stopping_criterion_state, data, 0)

# The default keeps whatever data a criterion state already carries, rather than clearing it.
# A criterion state that carries none takes `nothing`, which its `initialize_state!` ignores.
_stopping_state_data(::StoppingCriterionState) = nothing
_stopping_state_data(stopping_criterion_state::DefaultStoppingCriterionState) =
    stopping_criterion_state.data

# The signature taking an `iterate` is the most generic one there is, so this doubles as the
# fallback for any `Problem` and `Algorithm` that do not provide a state type of their own.
# Both these and their keyword counterparts below are documented by `_doc_init_state`, which
# covers exactly these signatures.
function initialize_state(
        problem::Problem, algorithm::Algorithm, iterate,
        state_data = nothing, stopping_state_data = nothing;
        kwargs...,
    )
    stopping_criterion_state = initialize_state(
        problem, algorithm, algorithm.stopping_criterion;
        stopping_state_data, kwargs...,
    )
    return DefaultState(iterate, stopping_criterion_state, state_data)
end

function initialize_state(
        problem::Problem, algorithm::Algorithm;
        iterate, state_data = nothing, stopping_state_data = nothing, kwargs...,
    )
    return initialize_state(
        problem, algorithm, iterate, state_data, stopping_state_data; kwargs...
    )
end

function initialize_state!(
        problem::Problem, algorithm::Algorithm, state::DefaultState, iterate,
        state_data = state.data,
        stopping_state_data = _stopping_state_data(state.stopping_criterion_state);
        kwargs...,
    )
    state.iterate = iterate
    state.data = state_data
    state.iteration = 0
    initialize_state!(
        problem, algorithm, algorithm.stopping_criterion, state.stopping_criterion_state;
        stopping_state_data, kwargs...,
    )
    return state
end

function initialize_state!(
        problem::Problem, algorithm::Algorithm, state::DefaultState;
        iterate = state.iterate, state_data = state.data,
        stopping_state_data = _stopping_state_data(state.stopping_criterion_state),
        kwargs...,
    )
    return initialize_state!(
        problem, algorithm, state, iterate, state_data, stopping_state_data; kwargs...
    )
end
