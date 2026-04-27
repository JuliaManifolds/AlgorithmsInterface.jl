_doc_init_state = """
    state = initialize_state(problem::Problem, algorithm::Algorithm; kwargs...)
    state = initialize_state!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)

Initialize a [`State`](@ref) based on a [`Problem`](@ref) and an [`Algorithm`](@ref).
The `kwargs...` should allow to initialize for example the initial point.
This can be done in-place for `state`, then only values that did change have to be provided.
"""

function initialize_state end

@doc "$(_doc_init_state)"
initialize_state(::Problem, ::Algorithm; kwargs...)

function initialize_state! end

@doc "$(_doc_init_state)"
initialize_state!(::Problem, ::Algorithm, ::State; kwargs...)


"""
    output = finalize_state!(problem::Problem, algorithm::Algorithm, state::State)

Finalize the solver and decide what values get returned from the [`solve!`](@ref) call.
By default, this is a no-op and returns the `state`, but this allows for customization
in cases where the details of the `state` can remain hidden.
"""
finalize_state!(problem::Problem, algorithm::Algorithm, state::State) = state

# has to be defined before used in solve but is documented alphabetically after

@doc """
    solve(problem::Problem, algorithm::Algorithm; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref).
The keyword arguments `kwargs...` have to provide enough details such that
the corresponding state initialisation [`initialize_state`](@ref)`(problem, algorithm)`
returns a state.

By default this method continues to call [`solve!`](@ref).
"""
function solve(problem::Problem, algorithm::Algorithm; kwargs...)
    # obtain logger once to minimize overhead from accessing ScopedValue
    # additionally handle logging initialization to enable stateful LoggingAction
    logger = algorithm_logger()

    # initialize the state and emit message
    state = initialize_state(problem, algorithm; kwargs...)
    emit_message(logger, problem, algorithm, state, :Start)

    # main loop
    state = solve_loop!(problem, algorithm, state)

    # emit message about finished state
    emit_message(logger, problem, algorithm, state, :Stop)

    return finalize_state!(problem, algorithm, state)
end

@doc """
    solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref), starting from a given [`State`](@ref).
The state is modified in-place.

All keyword arguments are passed to the [`initialize_state!`](@ref)`(problem, algorithm, state)` function.
"""
function solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)
    # obtain logger once to minimize overhead from accessing ScopedValue
    # additionally handle logging initialization to enable stateful LoggingAction
    logger = algorithm_logger()

    # initialize the state and emit message
    initialize_state!(problem, algorithm, state; kwargs...)
    emit_message(logger, problem, algorithm, state, :Start)

    # main loop
    state = solve_loop!(problem, algorithm, state)

    # emit message about finished state
    emit_message(logger, problem, algorithm, state, :Stop)

    return finalize_state!(problem, algorithm, state)
end

"""
    solve_loop!(problem::Problem, algorithm::Algorithm, state::State)

Provide the main loop of the iterative `algorithm` for a given `problem` and starting `state`.

This loop consists of:
1. Checking for convergence with [`is_finished!`](@ref)
2. Incrementing the state [`increment!`](@ref)
3. Performing a step [`step!`](@ref)
4. Repeat
"""
function solve_loop!(problem::Problem, algorithm::Algorithm, state::State)
    logger = algorithm_logger()
    while !is_finished!(problem, algorithm, state)
        emit_message(logger, problem, algorithm, state, :PreStep)
        increment!(state)
        step!(problem, algorithm, state)
        emit_message(logger, problem, algorithm, state, :PostStep)
    end
    return state
end

function step! end
@doc """
    step!(problem::Problem, algorithm::Algorithm, state::State)

Perform the current step of an [`Algorithm`](@ref) solving a [`Problem`](@ref)
modifying the algorithm's [`State`](@ref).
"""
step!(problem::Problem, algorithm::Algorithm, state::State)
