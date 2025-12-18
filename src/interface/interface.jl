_doc_init_state = """
    state = initialize_state(
        problem::Problem, algorithm::Algorithm,
        [stopping_criterion_state::StoppingCriterionState];
        kwargs...
    )
    state = initialize_state!(
        problem::Problem, algorithm::Algorithm, state::State;
        kwargs...
    )

Initialize a [`State`](@ref) based on a [`Problem`](@ref) and an [`Algorithm`](@ref).
The `kwargs...` should allow to initialize for example the initial point.
This can be done in-place for `state`, then only values that did change have to be provided.

Note that since the returned state should also hold `state.stopping_criterion_state`,
which will be used to keep the internal state of the stopping criterion, the out-of-place
version receives this as one of its arguments. By default, that will be initialized separately
through a call to [`initialize_stopping_state`](@ref) and provided as an argument.

On the other hand, the in-place version is not responsible for initializing the `stopping_criterion_state`,
as that will be handled separately by [`initialize_stopping_state!`](@ref).

Users that which to handle the stopping criterion initialization in `initialize_state` manually
should overload the 2-argument version, while by default the 3-argument version should be implemented.
"""

function initialize_state(problem::Problem, algorithm::Algorithm; kwargs...)
    stopping_criterion_state = initialize_stopping_state(problem, algorithm; kwargs...)
    return initialize_state(problem, algorithm, stopping_criterion_state; kwargs...)
end

@doc "$(_doc_init_state)"
initialize_state(::Problem, ::Algorithm; kwargs...)

function initialize_state! end

@doc "$(_doc_init_state)"
initialize_state!(::Problem, ::Algorithm, ::State; kwargs...)

# has to be defined before used in solve but is documented alphabetically after

@doc """
    solve(problem::Problem, algorithm::Algorithm; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref).

The keyword arguments `kwargs...` have to provide enough details such that the corresponding
state and stopping state initialisation [`initialize_state`](@ref)` and [`initialize_stopping_state`](@ref)
can be used to return valid states and stopping states.

By default this method continues to call [`solve!`](@ref).
"""
function solve(problem::Problem, algorithm::Algorithm; kwargs...)
    state = initialize_state(problem, algorithm; kwargs...)
    return solve!(problem, algorithm, state; kwargs...)
end

@doc """
    solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref), starting from a given [`State`](@ref).
The state is modified in-place.

All keyword arguments are passed to the [`initialize_state!`](@ref) and
[`initialize_stopping_state!`](@ref) functions.
"""
function solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)
    # obtain logger once to minimize overhead from accessing ScopedValue
    # additionally handle logging initialization to enable stateful LoggingAction
    logger = algorithm_logger()

    # initialize the state and emit message
    initialize_stopping_state!(problem, algorithm, state; kwargs...)
    initialize_state!(problem, algorithm, state; kwargs...)

    emit_message(logger, problem, algorithm, state, :Start)

    # main body of the algorithm
    while !is_finished!(problem, algorithm, state)
        # logging event between convergence check and algorithm step
        emit_message(logger, problem, algorithm, state, :PreStep)

        # algorithm step
        increment!(state)
        step!(problem, algorithm, state)

        # logging event between algorithm step and convergence check
        emit_message(logger, problem, algorithm, state, :PostStep)
    end

    # emit message about finished state
    emit_message(logger, problem, algorithm, state, :Stop)

    return state
end

function step! end

@doc """
    step!(problem::Problem, algorithm::Algorithm, state::State)

Perform the current step of an [`Algorithm`](@ref) solving a [`Problem`](@ref)
modifying the algorithm's [`State`](@ref).
"""
step!(problem::Problem, algorithm::Algorithm, state::State)
