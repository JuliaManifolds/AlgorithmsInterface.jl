# By default, assume stopping criteria are stateless - they only need information
# in the regular state, and indicate the last iteration they converged on
"""
    DefaultStoppingCriterionState <: StoppingCriterionState

A [`StoppingCriterionState`](@ref) that does not require any information besides
storing the iteration number when it (last) indicated to stop).

# Field
* `at_iteration::Int` store the iteration number this state
  indicated to stop.
  * `0` means already at the start it indicated to stop
  * any negative number means that it did not yet indicate to stop.
"""
mutable struct DefaultStoppingCriterionState <: StoppingCriterionState
    at_iteration::Int
    DefaultStoppingCriterionState() = new(-1)
end

initialize_stopping_state(::Problem, ::Algorithm, ::StoppingCriterion; kwargs...) =
    DefaultStoppingCriterionState()

function initialize_stopping_state!(
        ::Problem, ::Algorithm, ::State,
        ::StoppingCriterion,
        stopping_criterion_state::DefaultStoppingCriterionState;
        kwargs...,
    )
    stopping_criterion_state.at_iteration = -1
    return stopping_criterion_state
end


# Meta StoppingCriteria
# ---------------------
@doc raw"""
    StopWhenAll <: StoppingCriterion

store a tuple of [`StoppingCriterion`](@ref)s and indicate to stop,
when _all_ indicate to stop.

# Constructor

    StopWhenAll(c::NTuple{N,StoppingCriterion} where N)
    StopWhenAll(c::StoppingCriterion,...)
"""
struct StopWhenAll{TCriteria <: Tuple} <: StoppingCriterion
    criteria::TCriteria
end
StopWhenAll(c::AbstractVector{<:StoppingCriterion}) = StopWhenAll(Tuple(c))
StopWhenAll(c...) = StopWhenAll(c)
function indicates_convergence(stop_when_all::StopWhenAll)
    return any(indicates_convergence, stop_when_all.criteria)
end

function Base.show(io::IO, ::MIME"text/plain", stop_when_all::StopWhenAll)
    print(io, "StopWhenAll with the Stopping Criteria:")
    for stopping_criterion in stop_when_all.criteria
        print(io, "\n     ")
        replace(io, string(stopping_criterion), "\n" => "\n    ") #increase indent
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

    a = StopWhenAll(StopAfterIteration(200), StopAfter(Minute(1))
"""
Base.:&(s1::StoppingCriterion, s2::StoppingCriterion) = StopWhenAll(s1, s2)
Base.:&(s1::StoppingCriterion, s2::StopWhenAll) = StopWhenAll(s1, s2.criteria...)
Base.:&(s1::StopWhenAll, s2::StoppingCriterion) = StopWhenAll(s1.criteria..., s2)
Base.:&(s1::StopWhenAll, s2::StopWhenAll) = StopWhenAll(s1.criteria..., s2.criteria...)

@doc raw"""
    StopWhenAny <: StoppingCriterion

store an array of [`StoppingCriterion`](@ref) elements and indicates to stop,
when _any_ single one indicates to stop. The `reason` is given by the
concatenation of all reasons (assuming that all non-indicating return `""`).

# Constructors

    StopWhenAny(c::Vector{N,StoppingCriterion} where N)
    StopWhenAny(c::StoppingCriterion...)
"""
struct StopWhenAny{TCriteria <: Tuple} <: StoppingCriterion
    criteria::TCriteria
    StopWhenAny(c::Vector{<:StoppingCriterion}) = new{typeof(tuple(c...))}(tuple(c...))
    StopWhenAny(c::StoppingCriterion...) = new{typeof(c)}(c)
end

function indicates_convergence(stop_when_any::StopWhenAny)
    return all(indicates_convergence, stop_when_any.criteria)
end

function Base.show(io::IO, ::MIME"text/plain", stop_when_any::StopWhenAny)
    print(io, "StopWhenAny with the Stopping Criteria:")
    for stopping_criterion in stop_when_any.criteria
        print(io, "\n     ")
        replace(io, string(stopping_criterion), "\n" => "\n    ") #increase indent
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
This is for example used in combination with [`StopWhenAny`](@ref) and [`StopWhenAll`](@ref)

# Constructor
    GroupStoppingCriterionState(c::Vector{<:StoppingCriterionState})
    GroupStoppingCriterionState(c::StoppingCriterionState...)
"""
mutable struct GroupStoppingCriterionState{TCriteriaStates <: Tuple} <: StoppingCriterionState
    criteria_states::TCriteriaStates
    at_iteration::Int
    GroupStoppingCriterionState(c::Vector{<:StoppingCriterionState}) =
        new{typeof(tuple(c...))}(tuple(c...), -1)
    GroupStoppingCriterionState(c::StoppingCriterionState...) = new{typeof(c)}(c, -1)
end

function get_reason(
        stop_when::Union{StopWhenAll, StopWhenAny},
        stopping_criterion_states::GroupStoppingCriterionState,
    )
    stopping_criterion_states.at_iteration < 0 && return nothing
    criteria = stop_when.criteriaq
    stopping_criterion_states = stopping_criterion_states.criteria_states
    return join(Iterators.map(get_reason, criteria, stopping_criterion_states))
end

function initialize_stopping_state(
        problem::Problem, algorithm::Algorithm,
        stop_when::Union{StopWhenAll, StopWhenAny};
        kwargs...,
    )
    return GroupStoppingCriterionState(
        (
            initialize_stopping_state(problem, algorithm, stopping_criterion; kwargs...) for
                stopping_criterion in stop_when.criteria
        )...,
    )
end
function initialize_stopping_state!(
        problem::Problem, algorithm::Algorithm, state::State,
        stop_when::Union{StopWhenAll, StopWhenAny},
        stopping_criterion_states::GroupStoppingCriterionState;
        kwargs...,
    )
    for (stopping_criterion_state, stopping_criterion) in
        zip(stopping_criterion_states.criteria_states, stop_when.criteria)
        initialize_stopping_state!(
            problem, algorithm, state,
            stopping_criterion,
            stopping_criterion_state;
            kwargs...,
        )
    end
    stopping_criterion_states.at_iteration = -1
    return stopping_criterion_states
end

function is_finished(
        problem::Problem,
        algorithm::Algorithm,
        state::State,
        stop_when_all::StopWhenAll,
        stopping_criterion_states::GroupStoppingCriterionState,
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
        problem::Problem,
        algorithm::Algorithm,
        state::State,
        stop_when_all::StopWhenAll,
        stopping_criterion_states::GroupStoppingCriterionState,
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
        problem::Problem,
        algorithm::Algorithm,
        state::State,
        stop_when_any::StopWhenAny,
        stopping_criterion_states::GroupStoppingCriterionState,
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
        problem::Problem,
        algorithm::Algorithm,
        state::State,
        stop_when_any::StopWhenAny,
        stopping_criterion_states::GroupStoppingCriterionState,
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
        stop_when_any::StopWhenAny,
        stopping_criterion_states::GroupStoppingCriterionState,
    )
    has_stopped = (stopping_criterion_states.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop When _one_ of the following are fulfilled:\n"
    for (stopping_criterion, stopping_criterion_state) in
        zip(stop_when_any.criteria, stopping_criterion_states.criteria_states)
        s = replace(summary(stopping_criterion, stopping_criterion_state), "\n" => "\n    ")
        r = "$r    $(s)\n"
    end
    return print(io, "$(r)Overall: $s")
end
function Base.summary(
        io::IO,
        stop_when_all::StopWhenAll,
        stopping_criterion_states::GroupStoppingCriterionState,
    )
    has_stopped = (stopping_criterion_states.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop When _all_ of the following are fulfilled:\n"
    for (stopping_criterion, stopping_criterion_state) in
        zip(stop_when_all.criteria, stopping_criterion_states.criteria_states)
        s = replace(summary(stopping_criterion, stopping_criterion_state), "\n" => "\n    ")
        r = "$r    $(s)\n"
    end
    return print(io, "$(r)Overall: $s")
end

#
#
# Concrete Stopping Criteria

@doc raw"""
    StopAfterIteration <: StoppingCriterion

A simple stopping criterion to stop after a maximal number of iterations.

# Fields

* `max_iterations`  stores the maximal iteration number where to stop at

# Constructor

    StopAfterIteration(maxIter)

initialize the functor to indicate to stop after `maxIter` iterations.
"""
struct StopAfterIteration <: StoppingCriterion
    max_iterations::Int
end


function is_finished(
        ::Problem,
        ::Algorithm,
        state::State,
        stop_after_iteration::StopAfterIteration,
        stopping_criterion_state::DefaultStoppingCriterionState,
    )
    return state.iteration >= stop_after_iteration.max_iterations
end
function is_finished!(
        ::Problem,
        ::Algorithm,
        state::State,
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
    return print(io, "Max Iteration $(stop_after_iteration.max_iterations):\t$s")
end

"""
    StopAfter <: StoppingCriterion

store a threshold when to stop looking at the complete runtime. It uses
`time_ns()` to measure the time and you provide a `Period` as a time limit,
for example `Minute(15)`.

# Fields

* `threshold` stores the `Period` after which to stop

# Constructor

    StopAfter(t)

initialize the stopping criterion to a `Period t` to stop after.
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

* `start` stores the starting time when the algorithm is started, that is a call with `i=0`.
* `time` stores the elapsed time
* `at_iteration` indicates at which iteration (including `i=0`) the stopping criterion
  was fulfilled and is `-1` while it is not fulfilled.

"""
mutable struct StopAfterTimePeriodState <: StoppingCriterionState
    start::Nanosecond
    time::Nanosecond
    at_iteration::Int
    function StopAfterTimePeriodState()
        return new(Nanosecond(0), Nanosecond(0), -1)
    end
end

initialize_stopping_state(::Problem, ::Algorithm, ::StopAfter; kwargs...) =
    StopAfterTimePeriodState()

function initialize_stopping_state!(
        ::Problem, ::Algorithm, ::State,
        ::StopAfter, stopping_criterion_state::StopAfterTimePeriodState;
        kwargs...,
    )
    stopping_criterion_state.start = Nanosecond(0)
    stopping_criterion_state.time = Nanosecond(0)
    stopping_criterion_state.at_iteration = -1
    return stopping_criterion_state
end

function is_finished(
        ::Problem,
        ::Algorithm,
        state::State,
        stop_after::StopAfter,
        stop_after_state::StopAfterTimePeriodState,
    )
    k = state.iteration
    # Just check whether the (last recorded) time is beyond the threshold
    return (k > 0 && (stop_after_state.time > Nanosecond(stop_after.threshold)))
end
function is_finished!(
        ::Problem,
        ::Algorithm,
        state::State,
        stop_after::StopAfter,
        stop_after_state::StopAfterTimePeriodState,
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
        stop_after::StopAfter,
        stopping_criterion_state::StopAfterTimePeriodState,
    )
    has_stopped = (stopping_criterion_state.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    return print(io, "stopped after $(stop_after.threshold):\t$s")
end
indicates_convergence(stop_after::StopAfter) = false
