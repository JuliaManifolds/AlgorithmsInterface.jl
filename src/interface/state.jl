@doc """
    State

An abstract type to represent the state an iterative algorithm is in.

The state consists of any information that describes the current step the algorithm is in
and keeps all information needed from one step to the next.

## Properties

In order to interact with the stopping criteria, the state should contain the following properties,
and provide corresponding `getproperty` and `setproperty!` methods.

* `iteration` – the current iteration step ``k`` that is is currently performed or was last performed
* `stopping_criterion_state` – a [`StoppingCriterionState`](@ref) that indicates whether an [`Algorithm`](@ref)
  will stop after this iteration or has stopped.
* `iterate` the current iterate ``x^{(k)}``.

## Methods

The following methods should be implemented for a state

* [`increment!`](@ref)(state)
"""
abstract type State end

"""
    increment!(state::State)

Increment the current iteration a [`State`](@ref) either is currently performing or was last performed

The default assumes that the current iteration is stored in `state.iteration`.
"""
function increment!(state::State)
    state.iteration += 1
    return state
end
