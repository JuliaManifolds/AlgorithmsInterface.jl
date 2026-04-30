@doc """
    StoppingCriterion

An abstract type to represent a stopping criterion of an [`Algorithm`](@ref).

A concrete [`StoppingCriterion`](@ref) should also implement an
[`initialize_state(problem::Problem, algorithm::Algorithm, stopping_criterion::StoppingCriterion; kwargs...)`](@ref) function to create its accompanying
[`StoppingCriterionState`](@ref), as well as the corresponding mutating variant to reset such a [`StoppingCriterionState`](@ref).

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

Return whether or not a [`StoppingCriterion`](@ref) indicates convergence when it is in [`StoppingCriterionState`](@ref),
i.e. also check whether the state indicates that the criterion has been active.

If so it returns whether `stopping_criterion` itself indicates convergence, otherwise it returns `false`,
since the algorithm has then not yet stopped.
"""
function indicates_convergence(
        stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState,
    )
    return isnothing(get_reason(stopping_criterion, stopping_criterion_state)) && indicates_convergence(stopping_criterion)
end

_doc_is_finished = """
    is_finished(problem::Problem, algorithm::Algorithm, state::State)
    is_finished(problem::Problem, algorithm::Algorithm, state::State, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)
    is_finished!(problem::Problem, algorithm::Algorithm, state::State)
    is_finished!(problem::Problem, algorithm::Algorithm, state::State, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)

Indicate whether an [`Algorithm`](@ref) solving [`Problem`](@ref) is finished having reached
a certain [`State`](@ref). The variant with three arguments by default extracts the
[`StoppingCriterion`](@ref) and its [`StoppingCriterionState`](@ref) and their actual
checks are performed in the implementation with five arguments.

The mutating variant does alter the `stopping_criterion_state` and should only be called
once per iteration, the other one merely inspects the current status without mutation.
"""

@doc "$(_doc_is_finished)"
function is_finished(problem::Problem, algorithm::Algorithm, state::State)
    return is_finished(
        problem, algorithm, state,
        algorithm.stopping_criterion, state.stopping_criterion_state,
    )
end

@doc "$(_doc_is_finished)"
is_finished(::Problem, ::Algorithm, ::State, ::StoppingCriterion, ::StoppingCriterionState)

@doc "$(_doc_is_finished)"
function is_finished!(problem::Problem, algorithm::Algorithm, state::State)
    return is_finished!(
        problem, algorithm, state,
        algorithm.stopping_criterion, state.stopping_criterion_state,
    )
end

@doc "$(_doc_is_finished)"
is_finished!(::Problem, ::Algorithm, ::State, ::StoppingCriterion, ::StoppingCriterionState)

@doc """
    summary(io::IO, stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)
    summary(stopping_criterion::StoppingCriterion, stopping_criterion_state::StoppingCriterionState)

Provide a summary of the status of a stopping criterion – its parameters and whether
it currently indicates to stop. The first variant prints the summary to `io`,
the second returns it as a string.

# Example

For the [`StopAfterIteration`](@ref) criterion, the summary looks like

```
Max Iterations (15): not reached
```
"""
Base.summary(io::IO, ::StoppingCriterion, ::StoppingCriterionState)

function Base.summary(
        stopping_criterion::StoppingCriterion,
        stopping_criterion_state::StoppingCriterionState
    )
    io = IOBuffer()
    summary(io, stopping_criterion, stopping_criterion_state)
    return String(take!(io))
end

#
#
# Meta StoppingCriteria
@doc raw"""
    StopWhenAll <: StoppingCriterion

Store a tuple of [`StoppingCriterion`](@ref)s and indicate to stop
when _all_ of them indicate to stop.

# Constructor

    StopWhenAll(c::AbstractVector{<:StoppingCriterion})
    StopWhenAll(c::StoppingCriterion...)
"""
struct StopWhenAll{TCriteria <: Tuple} <: StoppingCriterion
    criteria::TCriteria
    StopWhenAll(c::StoppingCriterion...) = new{typeof(c)}(c)
end
StopWhenAll(c::AbstractVector{<:StoppingCriterion}) = StopWhenAll(c...)
function indicates_convergence(stop_when_all::StopWhenAll)
    return any(indicates_convergence, stop_when_all.criteria)
end

function Base.show(io::IO, ::MIME"text/plain", stop_when_all::StopWhenAll)
    print(io, "StopWhenAll with the Stopping Criteria:")
    for stopping_criterion in stop_when_all.criteria
        print(io, "\n\t")
        replace(io, sprint(show, stopping_criterion; context = io), "\n" => "\n\t") # increase indent
    end
    return nothing
end

"""
    &(s1,s2)
    s1 & s2

Combine two [`StoppingCriterion`](@ref) within an [`StopWhenAll`](@ref).
If either `s1` (or `s2`) is already an [`StopWhenAll`](@ref), then `s2` (or `s1`) is
appended to the list of [`StoppingCriterion`](@ref) within `s1` (or `s2`).

# Example
    a = StopAfterIteration(200) & StopAfter(Minute(1))

Is the same as

    a = StopWhenAll(StopAfterIteration(200), StopAfter(Minute(1)))
"""
Base.:&(s1::StoppingCriterion, s2::StoppingCriterion) = StopWhenAll(s1, s2)
Base.:&(s1::StoppingCriterion, s2::StopWhenAll) = StopWhenAll(s1, s2.criteria...)
Base.:&(s1::StopWhenAll, s2::StoppingCriterion) = StopWhenAll(s1.criteria..., s2)
Base.:&(s1::StopWhenAll, s2::StopWhenAll) = StopWhenAll(s1.criteria..., s2.criteria...)

@doc raw"""
    StopWhenAny <: StoppingCriterion

Store a tuple of [`StoppingCriterion`](@ref) elements and indicate to stop
when _any_ single one indicates to stop. The `reason` is given by the
concatenation of all reasons (assuming that all non-indicating ones return `nothing`).

# Constructors

    StopWhenAny(c::AbstractVector{<:StoppingCriterion})
    StopWhenAny(c::StoppingCriterion...)
"""
struct StopWhenAny{TCriteria <: Tuple} <: StoppingCriterion
    criteria::TCriteria
    StopWhenAny(c::StoppingCriterion...) = new{typeof(c)}(c)
end
StopWhenAny(c::AbstractVector{<:StoppingCriterion}) = StopWhenAny(c...)

function indicates_convergence(stop_when_any::StopWhenAny)
    return all(indicates_convergence, stop_when_any.criteria)
end

function Base.show(io::IO, ::MIME"text/plain", stop_when_any::StopWhenAny)
    print(io, "StopWhenAny with the Stopping Criteria:")
    for stopping_criterion in stop_when_any.criteria
        print(io, "\n\t")
        replace(io, sprint(show, stopping_criterion; context = io), "\n" => "\n\t") # increase indent
    end
    return nothing
end

"""
    |(s1,s2)
    s1 | s2

Combine two [`StoppingCriterion`](@ref) within an [`StopWhenAny`](@ref).
If either `s1` (or `s2`) is already an [`StopWhenAny`](@ref), then `s2` (or `s1`) is
appended to the list of [`StoppingCriterion`](@ref) within `s1` (or `s2`)

# Example
    a = StopAfterIteration(200) | StopAfter(Minute(1))

Is the same as

    a = StopWhenAny(StopAfterIteration(200), StopAfter(Minute(1)))
"""
Base.:|(s1::StoppingCriterion, s2::StoppingCriterion) = StopWhenAny(s1, s2)
Base.:|(s1::StoppingCriterion, s2::StopWhenAny) = StopWhenAny(s1, s2.criteria...)
Base.:|(s1::StopWhenAny, s2::StoppingCriterion) = StopWhenAny(s1.criteria..., s2)
Base.:|(s1::StopWhenAny, s2::StopWhenAny) = StopWhenAny(s1.criteria..., s2.criteria...)

# A common state for stopping criteria working on tuples of stopping criteria
"""
    GroupStoppingCriterionState <: StoppingCriterionState

A [`StoppingCriterionState`](@ref) that groups multiple [`StoppingCriterionState`](@ref)s
internally as a tuple.
This is for example used in combination with [`StopWhenAny`](@ref) and [`StopWhenAll`](@ref).

# Constructor

    GroupStoppingCriterionState(c::StoppingCriterionState...)
"""
mutable struct GroupStoppingCriterionState{TCriteriaStates <: Tuple} <: StoppingCriterionState
    criteria_states::TCriteriaStates
    at_iteration::Int
    GroupStoppingCriterionState(c::StoppingCriterionState...) = new{typeof(c)}(c, -1)
end

function get_reason(
        stop_when::Union{StopWhenAll, StopWhenAny},
        stopping_criterion_states::GroupStoppingCriterionState,
    )
    stopping_criterion_states.at_iteration < 0 && return nothing
    criteria = stop_when.criteria
    stopping_criterion_states = stopping_criterion_states.criteria_states
    return join(Iterators.map(get_reason, criteria, stopping_criterion_states))
end

function initialize_state(
        problem::Problem, algorithm::Algorithm, stop_when::Union{StopWhenAll, StopWhenAny};
        kwargs...,
    )
    return GroupStoppingCriterionState(
        (
            initialize_state(problem, algorithm, stopping_criterion; kwargs...) for
                stopping_criterion in stop_when.criteria
        )...,
    )
end
function initialize_state!(
        problem::Problem, algorithm::Algorithm, stop_when::Union{StopWhenAll, StopWhenAny},
        stopping_criterion_states::GroupStoppingCriterionState;
        kwargs...,
    )
    for (stopping_criterion_state, stopping_criterion) in
        zip(stopping_criterion_states.criteria_states, stop_when.criteria)
        initialize_state!(
            problem, algorithm, stopping_criterion, stopping_criterion_state;
            kwargs...,
        )
    end
    stopping_criterion_states.at_iteration = -1
    return stopping_criterion_states
end

function is_finished(
        problem::Problem, algorithm::Algorithm, state::State,
        stop_when_all::StopWhenAll, stopping_criterion_states::GroupStoppingCriterionState,
    )
    k = state.iteration
    (k == 0) && (stopping_criterion_states.at_iteration = -1) # reset on init
    if all(
            st -> is_finished(problem, algorithm, state, st[1], st[2]),
            zip(stop_when_all.criteria, stopping_criterion_states.criteria_states),
        )
        return true
    end
    return false
end
function is_finished!(
        problem::Problem, algorithm::Algorithm, state::State,
        stop_when_all::StopWhenAll, stopping_criterion_states::GroupStoppingCriterionState,
    )
    k = state.iteration
    (k == 0) && (stopping_criterion_states.at_iteration = -1) # reset on init
    if all(
            st -> is_finished!(problem, algorithm, state, st[1], st[2]),
            zip(stop_when_all.criteria, stopping_criterion_states.criteria_states),
        )
        stopping_criterion_states.at_iteration = k
        return true
    end
    return false
end

function is_finished(
        problem::Problem, algorithm::Algorithm, state::State,
        stop_when_any::StopWhenAny, stopping_criterion_states::GroupStoppingCriterionState,
    )
    k = state.iteration
    (k == 0) && (stopping_criterion_states.at_iteration = -1) # reset on init
    if any(
            st -> is_finished(problem, algorithm, state, st[1], st[2]),
            zip(stop_when_any.criteria, stopping_criterion_states.criteria_states),
        )
        return true
    end
    return false
end
function is_finished!(
        problem::Problem, algorithm::Algorithm, state::State,
        stop_when_any::StopWhenAny, stopping_criterion_states::GroupStoppingCriterionState,
    )
    k = state.iteration
    (k == 0) && (stopping_criterion_states.at_iteration = -1) # reset on init
    if any(
            st -> is_finished!(problem, algorithm, state, st[1], st[2]),
            zip(stop_when_any.criteria, stopping_criterion_states.criteria_states),
        )
        stopping_criterion_states.at_iteration = k
        return true
    end
    return false
end

function Base.summary(
        io::IO,
        stop_when_any::StopWhenAny, stopping_criterion_states::GroupStoppingCriterionState,
    )
    has_stopped = (stopping_criterion_states.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop when _one_ of the following are fulfilled:\n"
    for (stopping_criterion, stopping_criterion_state) in
        zip(stop_when_any.criteria, stopping_criterion_states.criteria_states)
        t = replace(summary(stopping_criterion, stopping_criterion_state), "\n" => "\n\t")
        r = "$(r)\t$(t)\n"
    end
    return print(io, "$(r)Overall: $(s)")
end
function Base.summary(
        io::IO,
        stop_when_all::StopWhenAll, stopping_criterion_states::GroupStoppingCriterionState,
    )
    has_stopped = (stopping_criterion_states.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop when _all_ of the following are fulfilled:\n"
    for (stopping_criterion, stopping_criterion_state) in
        zip(stop_when_all.criteria, stopping_criterion_states.criteria_states)
        t = replace(summary(stopping_criterion, stopping_criterion_state), "\n" => "\n\t")
        r = "$(r)\t$(t)\n"
    end
    return print(io, "$(r)Overall: $(s)")
end

#
#
# Concrete Stopping Criteria

@doc raw"""
    StopAfterIteration <: StoppingCriterion

A simple stopping criterion to stop after a maximal number of iterations.

# Fields

* `max_iterations` stores the iteration number at which to stop.

# Constructor

    StopAfterIteration(max_iterations)

Initialize the criterion to indicate stopping after `max_iterations` iterations.
"""
struct StopAfterIteration <: StoppingCriterion
    max_iterations::Int
end

"""
    DefaultStoppingCriterionState <: StoppingCriterionState

A [`StoppingCriterionState`](@ref) that does not require any information besides
storing the iteration number at which it (last) indicated to stop.

# Fields

* `at_iteration::Int` stores the iteration number at which this state indicated to stop.
  * `0` means it already indicated to stop at the start.
  * any negative number means that it has not yet indicated to stop.
"""
mutable struct DefaultStoppingCriterionState <: StoppingCriterionState
    at_iteration::Int
    DefaultStoppingCriterionState() = new(-1)
end

initialize_state(::Problem, ::Algorithm, ::StopAfterIteration; kwargs...) = DefaultStoppingCriterionState()
function initialize_state!(
        ::Problem, ::Algorithm, ::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState;
        kwargs...,
    )
    stopping_criterion_state.at_iteration = -1
    return stopping_criterion_state
end


function is_finished(
        ::Problem, ::Algorithm, state::State,
        stop_after_iteration::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState,
    )
    return state.iteration >= stop_after_iteration.max_iterations
end
function is_finished!(
        ::Problem, ::Algorithm, state::State,
        stop_after_iteration::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState,
    )
    k = state.iteration
    (k == 0) && (stopping_criterion_state.at_iteration = -1)
    if k >= stop_after_iteration.max_iterations
        stopping_criterion_state.at_iteration = k
        return true
    end
    return false
end
function get_reason(
        stop_after_iteration::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState,
    )
    if stopping_criterion_state.at_iteration >= stop_after_iteration.max_iterations
        return "At iteration $(stopping_criterion_state.at_iteration) the algorithm reached its maximal number of iterations ($(stop_after_iteration.max_iterations)).\n"
    end
    return nothing
end
indicates_convergence(stop_after_iteration::StopAfterIteration) = false
function Base.summary(
        io::IO,
        stop_after_iteration::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState,
    )
    has_stopped = (stopping_criterion_state.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    return print(io, "Max Iterations ($(stop_after_iteration.max_iterations)): $s")
end

"""
    StopAfter <: StoppingCriterion

Stores a threshold for stopping based on the total runtime. It uses
`time_ns()` to measure the time, and you provide a `Period` as the time limit,
for example `Minute(15)`.

# Fields

* `threshold` stores the `Period` after which to stop.

# Constructor

    StopAfter(t::Period)

Initialize the stopping criterion to stop after the `Period` `t` has elapsed.
"""
struct StopAfter <: StoppingCriterion
    threshold::Period
    function StopAfter(t::Period)
        if value(t) < 0
            throw(ArgumentError("You must provide a positive time period"))
        else
            s = new(t)
        end
        return s
    end
end

@doc """
    StopAfterTimePeriodState <: StoppingCriterionState

A state for stopping criteria that are based on time measurements,
for example [`StopAfter`](@ref).

# Fields

* `start` stores the starting time, recorded when the algorithm is started (the call with `k=0`).
* `time` stores the elapsed time.
* `at_iteration` indicates at which iteration (including `k=0`) the stopping criterion
  was fulfilled, and is `-1` while it is not fulfilled.
"""
mutable struct StopAfterTimePeriodState <: StoppingCriterionState
    start::Nanosecond
    time::Nanosecond
    at_iteration::Int
    function StopAfterTimePeriodState()
        return new(Nanosecond(0), Nanosecond(0), -1)
    end
end

initialize_state(::Problem, ::Algorithm, ::StopAfter; kwargs...) =
    StopAfterTimePeriodState()

function initialize_state!(
        ::Problem, ::Algorithm, ::StopAfter,
        stopping_criterion_state::StopAfterTimePeriodState;
        kwargs...,
    )
    stopping_criterion_state.start = Nanosecond(0)
    stopping_criterion_state.time = Nanosecond(0)
    stopping_criterion_state.at_iteration = -1
    return stopping_criterion_state
end

function is_finished(
        ::Problem, ::Algorithm, state::State,
        stop_after::StopAfter, stop_after_state::StopAfterTimePeriodState,
    )
    k = state.iteration
    # Just check whether the (last recorded) time is beyond the threshold
    return (k > 0 && (stop_after_state.time > Nanosecond(stop_after.threshold)))
end
function is_finished!(
        ::Problem, ::Algorithm, state::State,
        stop_after::StopAfter, stop_after_state::StopAfterTimePeriodState,
    )
    k = state.iteration
    if value(stop_after_state.start) == 0 || k <= 0 # (re)start timer
        stop_after_state.at_iteration = -1
        stop_after_state.start = Nanosecond(time_ns())
        stop_after_state.time = Nanosecond(0)
    else
        stop_after_state.time = Nanosecond(time_ns()) - stop_after_state.start
        if k > 0 && (stop_after_state.time > Nanosecond(stop_after.threshold))
            stop_after_state.at_iteration = k
            return true
        end
    end
    return false
end
function get_reason(
        stop_after::StopAfter,
        stopping_criterion_state::StopAfterTimePeriodState,
    )
    if (stopping_criterion_state.at_iteration >= 0)
        return "After iteration $(stopping_criterion_state.at_iteration) the algorithm ran for $(floor(stopping_criterion_state.time, typeof(stop_after.threshold))) (threshold: $(stop_after.threshold)).\n"
    end
    return nothing
end
function Base.summary(
        io::IO,
        stop_after::StopAfter, stopping_criterion_state::StopAfterTimePeriodState,
    )
    has_stopped = (stopping_criterion_state.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    return print(io, "stopped after $(stop_after.threshold): $s")
end
indicates_convergence(stop_after::StopAfter) = false
