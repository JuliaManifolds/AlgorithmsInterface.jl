_doc_init_state = """
    state = initialize_state(problem::Problem, algorithm::Algorithm, iterate, state_data, stopping_state_data; kwargs...)
    state = initialize_state!(problem::Problem, algorithm::Algorithm, state::State, iterate, state_data, stopping_state_data; kwargs...)

Allocate a [`State`](@ref) to start at `iterate`, or reset an existing one to start there again.
All arguments beyond the `iterate` are optional, and `initialize_state!` defaults every one of
them to what the `state` already holds, so resetting in place only takes what actually changes.

`state_data` is what the [`State`](@ref) carries and `stopping_state_data` what the
[`StoppingCriterionState`](@ref) does.
For the latter, `nothing` leaves the [`StoppingCriterion`](@ref) to decide which data to carry,
so it is only passed to override that decision.
The remaining `kwargs...` are passed on to the corresponding function for the
[`StoppingCriterion`](@ref) of the [`Algorithm`](@ref).

An [`Algorithm`](@ref) that knows where it starts implements the variant without an `iterate`,
which is also what [`solve`](@ref) reaches when it is called without one:

    state = initialize_state(problem::Problem, algorithm::Algorithm; kwargs...)

Since [`State`](@ref) serves every algorithm, such an implementation only picks that starting
point and hands it to the method above.
"""

function initialize_state end

@doc "$(_doc_init_state)"
initialize_state(::Problem, ::Algorithm, iterate; kwargs...)

function initialize_state! end

@doc "$(_doc_init_state)"
initialize_state!(::Problem, ::Algorithm, ::State; kwargs...)

"""
    output = finalize_state!(problem::Problem, algorithm::Algorithm, state::State)

Finalize the solver and decide what values get returned from the [`solve!`](@ref) call.
By default, this is a no-op and returns the `state.iterate`, but this allows for further
customization in other cases, for example to clean up used resources or output other data.
"""
finalize_state!(problem::Problem, algorithm::Algorithm, state::State) = state.iterate

# has to be defined before used in solve but is documented alphabetically after

@doc """
    solve(problem::Problem, algorithm::Algorithm, args...; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref).
The `args...` are passed on to [`initialize_state`](@ref)`(problem, algorithm, args...)`, and
have to provide enough detail for it to return a state: the `iterate` to start at, unless the
`algorithm` implements an [`initialize_state`](@ref) that decides that itself.

By default this method continues to call [`solve!`](@ref).
"""
function solve(problem::Problem, algorithm::Algorithm, args...; kwargs...)
    # obtain logger once to minimize overhead from accessing ScopedValue
    # additionally handle logging initialization to enable stateful LoggingAction
    logger = algorithm_logger()

    # initialize the state and emit message
    state = initialize_state(problem, algorithm, args...; kwargs...)
    emit_message(logger, problem, algorithm, state, :Start)

    # main loop
    state = solve_loop!(problem, algorithm, state)

    # emit message about finished state
    emit_message(logger, problem, algorithm, state, :Stop)

    return finalize_state!(problem, algorithm, state)
end

@doc """
    solve!(problem::Problem, algorithm::Algorithm, state::State, args...; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref), starting from a given [`State`](@ref).
The state is modified in-place.

The `args...` and all keyword arguments are passed to the
[`initialize_state!`](@ref)`(problem, algorithm, state, args...)` function, which resets the
`state` and defaults everything that is not given to what it already holds.
"""
function solve!(problem::Problem, algorithm::Algorithm, state::State, args...; kwargs...)
    # obtain logger once to minimize overhead from accessing ScopedValue
    # additionally handle logging initialization to enable stateful LoggingAction
    logger = algorithm_logger()

    # initialize the state and emit message
    initialize_state!(problem, algorithm, state, args...; kwargs...)
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
2. Incrementing the state [`increment!`](@ref)`(problem, algorithm, state)`
3. Performing a step [`step!`](@ref)
4. Repeat
"""
function solve_loop!(problem::Problem, algorithm::Algorithm, state::State)
    logger = algorithm_logger()
    while !is_finished!(problem, algorithm, state)
        emit_message(logger, problem, algorithm, state, :PreStep)
        increment!(problem, algorithm, state)
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
