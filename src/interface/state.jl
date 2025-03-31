@doc """
    State

An abstract type to represent the state an iterative algorithm is in.

The state consists of any information that describes the current step the algorithm is in
and keeps all information needed from one step to the next.

## Usual fields

Usually this should include the following. If you use this naming scheme, default functions
e.g. as accessors

* `iteration` – the current iteration step ``k`` that is is currently performed or was last performed
* `stopping_criterion_state` – a [`StoppingCriterionState`](@ref) that indicates whether an [`Algorithm`](@ref)
  will stop after this iteration or has stopped.
* `iterate` the current iterate ``x^{(k)}```.

These variable names given in this list are the defaults for which the accessors are implemented,
such that if your concrete `MyState <: State` follows this convention, you do not have to reimplement
their accessors.

## Methods

The following methods should be implemented for a state

* [`get_iteration`](@ref)`(state)` to return the current iteration number
* [`increment!](@ref)`(state)`
* [`get_stopping_criterion_state`](@ref) return the [`StoppingCriterionState`](@ref)
* [`get_iterate`](@ref) return the current iterate ``x^{(k)}``.
"""
abstract type State end

"""
    get_iterate(state::State)

Return the current iterate ``x^{(k)}`` of a [`State`](@ref).

The default assumes that the current iterate is stored in `state.iterate`.
"""
get_iterate(state::State) = state.iterate

"""
    get_iteration(state::State)

Return the current iteration a [`State`](@ref) either is currently performing or was last performed

The default assumes that the current iteration is stored in `state.iteration`.
"""
get_iteration(state::State) = state.iteration

"""
    increment!(state::State)

Increment the current iteration a [`State`](@ref) either is currently performing or was last performed

The default assumes that the current iteration is stored in `state.iteration`.
"""
function increment!(state::State)
    state.iteration += 1
    return state
end

"""
    get_stopping_criterion_state(state::State)

Return the [`StoppingCriterionState`](@ref) of the given [`State`](@ref).

The default assumes that the criterion is stored in `state.stopping_criterion_state`.
"""
get_stopping_criterion_state(state::State) = state.stopping_criterion_state
