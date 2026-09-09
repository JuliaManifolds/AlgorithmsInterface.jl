@doc """
    State

The state an iterative algorithm is in.

The state consists of any information that describes the current step the algorithm is in
and keeps all information needed from one step to the next.
Since the `data` field is opaque to this package, this single type serves every
[`Algorithm`](@ref): a [`Problem`](@ref), an [`Algorithm`](@ref) and a [`step!`](@ref) method
suffice to run one, and since [`step!`](@ref) dispatches on the [`Algorithm`](@ref), sharing
one state type across algorithms costs no flexibility in doing so.

# Fields

* `iterate` stores the current iterate ``x^{(k)}``.
* `stopping_criterion_state` stores the [`StoppingCriterionState`](@ref) belonging to the
  [`StoppingCriterion`](@ref) of the [`Algorithm`](@ref), indicating whether the
  [`Algorithm`](@ref) will stop after this iteration or has stopped.
* `iteration::Int` stores the current iteration step ``k`` that is currently being performed
  or was last performed.
* `data` stores any further data that has to be carried from one step to the next.
  It is opaque to this package, and none of its contents are exposed as properties of the
  state, so an algorithm reaches them through `state.data`.
  A `NamedTuple` or a struct of its own keeps access to them type stable and is the
  recommended choice; `nothing` indicates that the algorithm needs no further data.

# Constructor

    State(iterate, stopping_criterion_state, data = nothing)
    State(iterate, stopping_criterion_state, iteration, data)

Initialize the state to start at `iterate`, carrying `data` alongside it.
The second form is the one that also sets the iteration it records.
"""
mutable struct State{V, S <: StoppingCriterionState, D}
    iterate::V
    stopping_criterion_state::S
    iteration::Int
    data::D
end

State(iterate, stopping_criterion_state::StoppingCriterionState, data = nothing) =
    State(iterate, stopping_criterion_state, 0, data)

"""
    increment!(problem::Problem, algorithm::Algorithm, state::State)

Increment the current iteration that a [`State`](@ref) is currently performing or was last performing.

The default increments `state.iteration`, which is all the bookkeeping this package needs.
An [`Algorithm`](@ref) that has more of it to do overloads this function.
"""
function increment!(::Problem, ::Algorithm, state::State)
    state.iteration += 1
    return state
end

# These two are documented by `_doc_init_state`, which covers exactly these signatures.
# The one taking an `iterate` is the most generic there is, so it doubles as the fallback for any
# `Problem` and `Algorithm` that do not initialize a state of their own. An algorithm that does
# know where to start implements the variant without an `iterate` and leaves the rest to these.
function initialize_state(
        problem::Problem, algorithm::Algorithm, iterate,
        state_data = nothing, stopping_state_data = nothing;
        kwargs...,
    )
    stopping_criterion_state = initialize_state(
        problem, algorithm, algorithm.stopping_criterion;
        stopping_state_data, kwargs...,
    )
    return State(iterate, stopping_criterion_state, state_data)
end

function initialize_state!(
        problem::Problem, algorithm::Algorithm, state::State,
        iterate = state.iterate, state_data = state.data, stopping_state_data = nothing;
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
