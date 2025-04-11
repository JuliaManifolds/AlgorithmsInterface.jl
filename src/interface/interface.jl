_doc_init_state = """
    state = initialize_state(problem::Problem, algorithm::Algorithm; kwargs...)
    state = initialize_state!(state::State, problem::Problem, algorithm::Algorithm; kwargs...)

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
    state = initialize_state(problem, algorithm; kwargs...)
    return solve!(problem, algorithm, state; kwargs...)
end

@doc """
    solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)

Solve the [`Problem`](@ref) using an [`Algorithm`](@ref), starting from a given [`State`](@ref).
The state is modified in-place.

All keyword arguments are passed to the [`initialize_state!`](@ref)`(problem, algorithm, state)` function.
"""
function solve!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)
    initialize_state!(problem, algorithm, state; kwargs...)
    while !is_finished!(problem, algorithm, state)
        increment!(state)
        step!(problem, algorithm, state)
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
