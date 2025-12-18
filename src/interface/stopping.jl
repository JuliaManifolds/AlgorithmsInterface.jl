@doc """
    StoppingCriterion

An abstract type to represent a stopping criterion of an [`Algorithm`](@ref).

A concrete [`StoppingCriterion`](@ref) should also implement a
[`initialize_state(problem::Problem, algorithm::Algorithm, stopping_criterion::StoppingCriterion; kwargs...)`](@ref) function to create its accompanying
[`StoppingCriterionState`](@ref).
as well as the corresponding mutating variant to reset such a [`StoppingCriterionState`](@ref).

It should usually implement

* [`indicates_convergence`](@ref)`(stopping_criterion)`
* [`indicates_convergence`](@ref)`(stopping_criterion, stopping_criterion_state)`
* [`is_finished!`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
* [`is_finished`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
"""
abstract type StoppingCriterion end

@doc """
    StoppingCriterionState

An abstract type to represent a stopping criterion state within a [`State`](@ref).
It represents the concrete state a [`StoppingCriterion`](@ref) is in.

It should usually implement

* [`get_reason`](@ref)`(stopping_criterion, stopping_criterion_state)`
* [`indicates_convergence`](@ref)`(stopping_criterion, stopping_criterion_state)`
* [`is_finished!`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
* [`is_finished`](@ref)`(problem, algorithm, state, stopping_criterion, stopping_criterion_state)`
"""
abstract type StoppingCriterionState end

# Initialization
# --------------
_doc_init_stopping_state = """
    stopping_criterion_state = initialize_stopping_state(
        problem::Problem, algorithm::Algorithm
        stopping_criterion::StoppingCriterion = algorithm.stopping_criterion;
        kwargs...
    )
    stopping_criterion_state = initialize_stopping_state!(
        problem::Problem, algorithm::Algorithm, state::State,
        stopping_criterion::StoppingCriterion = algorithm.stopping_criterion,
        stopping_criterion_state::StoppingCriterionState = state.stopping_criterion_state;
        kwargs...
    )

Initialize a [`StoppingCriterionState`](@ref) based on a [`Problem`](@ref), [`Algorithm`](@ref),
[`State`](@ref) triplet for a given [`StoppingCriterion`](@ref).
By default, the `stopping_criterion` is retrieved from the `Algorithm` via `algorithm.stopping_criterion`.

The first signature is used for setting up a completely new stopping criterion state, while the second
simply resets a given state in-place.
"""

initialize_stopping_state(problem::Problem, algorithm::Algorithm; kwargs...) =
    initialize_stopping_state(problem, algorithm, algorithm.stopping_criterion; kwargs...)

@doc "$(_doc_init_stopping_state)"
initialize_stopping_state(::Problem, ::Algorithm, ::StoppingCriterion; kwargs...)

function initialize_stopping_state!(problem::Problem, algorithm::Algorithm, state::State; kwargs...)
    return initialize_stopping_state!(
        problem, algorithm, state, algorithm.stopping_criterion, state.stopping_criterion_state; kwargs...
    )
end

@doc "$(_doc_init_stopping_state)"
initialize_stopping_state!(::Problem, ::Algorithm, ::State, ::StoppingCriterion, ::StoppingCriterionState; kwargs...)


# Convergence characterization
# ----------------------------
function get_reason end

@doc """
    get_reason(stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)

Provide a reason in human readable text as to why a [`StoppingCriterion`](@ref) with [`StoppingCriterionState`](@ref) indicated to stop.
If it does not indicate to stop, this should return `nothing`.

Providing the iteration at which this indicated to stop in the reason would be preferable.
"""
get_reason(::StoppingCriterion, ::StoppingCriterionState)

function indicates_convergence end
@doc """
    indicates_convergence(stopping_criterion::StoppingCriterion)

Return whether or not a [`StoppingCriterion`](@ref) indicates convergence.
"""
indicates_convergence(stopping_criterion::StoppingCriterion)

@doc """
    indicates_convergence(stopping_criterion::StoppingCriterion, ::StoppingCriterionState)

Return whether or not a [`StoppingCriterion`](@ref) indicates convergence when it is in [`StoppingCriterionState`](@ref).

By default this checks whether the [`StoppingCriterion`](@ref) has actually stopped.
If so it returns whether `stopping_criterion` itself indicates convergence, otherwise it returns `false`,
since the algorithm has then not yet stopped.
"""
function indicates_convergence(
        stopping_criterion::StoppingCriterion,
        stopping_criterion_state::StoppingCriterionState,
    )
    return isnothing(get_reason(stopping_criterion, stopping_criterion_state)) &&
        indicates_convergence(stopping_criterion)
end

# Convergence indication
# ----------------------
_doc_is_finished = """
    is_finished(problem::Problem, algorithm::Algorithm, state::State)
    is_finished(problem::Problem, algorithm::Algorithm, state::State, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)
    is_finished!(problem::Problem, algorithm::Algorithm, state::State)
    is_finished!(problem::Problem, algorithm::Algorithm, state::State, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)

Indicate whether an [`Algorithm`](@ref) solving [`Problem`](@ref) is finished having reached
a certain [`State`](@ref). The variant with three arguments by default extracts the
[`StoppingCriterion`](@ref) and its [`StoppingCriterionState`](@ref) and their actual
checks are performed in the implementation with five arguments.

The mutating variant does alter the `stopping_criterion_state` and and should only be called
once per iteration, the other one merely inspects the current status without mutation.
"""

@doc "$(_doc_is_finished)"
function is_finished(problem::Problem, algorithm::Algorithm, state::State)
    return is_finished(
        problem, algorithm, state,
        algorithm.stopping_criterion,
        state.stopping_criterion_state,
    )
end

@doc "$(_doc_is_finished)"
is_finished(::Problem, ::Algorithm, ::State, ::StoppingCriterion, ::StoppingCriterionState)

@doc "$(_doc_is_finished)"
function is_finished!(problem::Problem, algorithm::Algorithm, state::State)
    return is_finished!(
        problem, algorithm, state,
        algorithm.stopping_criterion,
        state.stopping_criterion_state,
    )
end

@doc "$(_doc_is_finished)"
is_finished!(::Problem, ::Algorithm, ::State, ::StoppingCriterion, ::StoppingCriterionState)

@doc """
    summary(io::IO, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)

Provide a summary of the status of a stopping criterion – its parameters and whether
it currently indicates to stop. It should not be longer than one line

# Example

For the [`StopAfterIteration`](@ref) criterion, the summary looks like

```
Max Iterations (15): not reached
```
"""
Base.summary(io::IO, ::StoppingCriterion, ::StoppingCriterionState)
