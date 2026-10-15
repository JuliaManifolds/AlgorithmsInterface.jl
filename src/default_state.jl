@doc """
    DefaultState <: State

A [`State`](@ref) that stores the required properties for the  [`State`](@ref) interface,
together with a `data` field for any further data an [`Algorithm`](@ref) needs.
It is the state used by the default [`initialize_state`](@ref) and [`initialize_state!`](@ref).

For more involved states, consider defining your own subtype of [`State`](@ref) instead.

# Fields

* `iterate` stores the current iterate ``x^{(k)}``.
* `stopping_criterion_state` stores the [`StoppingCriterionState`](@ref) belonging to the [`StoppingCriterion`](@ref) of the [`Algorithm`](@ref).
* `data` stores any further data, for example as a `NamedTuple`, or `nothing` if not needed.
* `iteration::Int` stores the current iteration step ``k`` that is currently being performed or was last performed.

# Constructor

    DefaultState(iterate, stopping_criterion_state, data = nothing)

Initialize the state to start at `iterate` with iteration `0`.
"""
mutable struct DefaultState{V, S <: StoppingCriterionState, D} <: State
    iterate::V
    stopping_criterion_state::S
    data::D
    iteration::Int
end

DefaultState(iterate, stopping_criterion_state::StoppingCriterionState, data = nothing) =
    DefaultState(iterate, stopping_criterion_state, data, 0)

# Default initialization, documented in `_doc_init_state`
function initialize_state(
        problem::Problem, algorithm::Algorithm, iterate, state_data = nothing; kwargs...
    )
    stopping_criterion_state = initialize_state(
        problem, algorithm, algorithm.stopping_criterion; kwargs...
    )
    return DefaultState(iterate, stopping_criterion_state, state_data)
end

function initialize_state(
        problem::Problem, algorithm::Algorithm; iterate, state_data = nothing, kwargs...
    )
    return initialize_state(problem, algorithm, iterate, state_data; kwargs...)
end

function initialize_state!(
        problem::Problem, algorithm::Algorithm, state::DefaultState, iterate,
        state_data = state.data; kwargs...,
    )
    state.iterate = iterate
    state.data = state_data
    state.iteration = 0
    initialize_state!(
        problem, algorithm, algorithm.stopping_criterion, state.stopping_criterion_state;
        kwargs...,
    )
    return state
end

function initialize_state!(
        problem::Problem, algorithm::Algorithm, state::DefaultState;
        iterate = state.iterate, state_data = state.data, kwargs...,
    )
    return initialize_state!(problem, algorithm, state, iterate, state_data; kwargs...)
end
