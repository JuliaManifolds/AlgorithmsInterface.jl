@doc """
    StoppingCriterion

An abstract type to represent a stopping criterion.

A concrete [`StoppingCriterion`](@ref) `sc` should also implement a
[`initialize_state(problem::Problem, algorithm::Algorithm, sc::StoppingCriterion; kwargs...)`](@ref) function to create its accompanying
[`StoppingCriterionState`](@ref).
as well as the corresponting mutating variant to reset such a [`StoppingCriterionState`](@ref).

It should usually implement

* `indicates_convergence(sc)` a boolean whether or not this stopping criterion would indicate
  that the algorithm has converged, if it indicates to stop.
"""
abstract type StoppingCriterion end

@doc """
    StoppingCriterionState

An abstract type to represent a stopping criterion state within a [`State`](@ref).

Any concrete stopping criterion should be implemented as a functor,
that takes the “usual tuple” `(problem, algorithm, state, stopping_criterion)`
of a [`Problem`](@ref) `p`, an [`Algorithm`](@ref) and a [`State`](@ref) as input,
as well as the corresponding [`StoppingCriterion`](@ref). Though this is usually stored¨
in the [`Algorithm`](@ref) `algorithm`, the extra parameter allows both for more flexibility and
for multiple dispatch.
The concrete [`StoppingCriterionState`](@ref) should be part of the [`State`](@ref) `state`.

The functor might modify the stopping criterion state.
"""
abstract type StoppingCriterionState end

function get_reason end
@doc """
    get_reason(sc::StoppingCriterion, scs::StoppingCriterionState)

Provide a reason in human readable text as to why a [`StoppingCriterion`](@ref) `sc
with [`StoppingCriterionState`](@ref) `scs` indicated to stop.
If it does not indicate to stop, this should return an empty string.

Providing the iteration at which this indicated to stop in the reason would be preferable.
"""
get_reason(::StoppingCriterion, ::StoppingCriterionState)

function indicates_convergence end
@doc """
    indicates_convergence(sc::StoppingCriterion)

Return whether or not a [`StoppingCriterion`](@ref) `sc` indicates convergence.
"""
indicates_convergence(sc::StoppingCriterion)

@doc """
    indicates_convergence(sc::StoppingCriterion, ::StoppingCriterionState)

Return whether or not a [`StoppingCriterion`](@ref) `sc` indicates convergence
when it is in [`StoppingCriterionState`](@ref)

By default this checks whether the [`StoppingCriterion`](@ref) has actually stopped.
If so it returns whether `sc` itself indicates convergence, otherwise it returns `false`,
since the algorithm has then not yet stopped.
"""
function indicates_convergence(sc::StoppingCriterion, scs::StoppingCriterionState)
    return isnothing(get_reason(sc, scs)) ? indicates_convergence(sc) : false
end

@doc """
    summary(io::IO, sc::StoppingCriterion, scs::StoppingCriterionState)

Provide a summary of the status of a stopping criterion – its parameters and whether
it currently indicates to stop. It should not be longer than one line

# Example

For the [`StopAfterIteration`](@ref) criterion, the summary looks like

```
Max Iterations (15): not reached
```
"""
Base.summary(io::IO, ::StoppingCriterion, ::StoppingCriterionState)

#
#
# Meta StoppingCriteria
@doc raw"""
    StopWhenAll <: StoppingCriterion

store a tuple of [`StoppingCriterion`](@ref)s and indicate to stop,
when _all_ indicate to stop.

# Constructor

    StopWhenAll(c::NTuple{N,StoppingCriterion} where N)
    StopWhenAll(c::StoppingCriterion,...)
"""
struct StopWhenAll{TCriteria<:Tuple} <: StoppingCriterion
    criteria::TCriteria
end
StopWhenAll(c::AbstractVector{<:StoppingCriterion}) = StopWhenAll(Tuple(c))
StopWhenAll(c...) = StopWhenAll(c)
function indicates_convergence(sc::StopWhenAll)
    return any(indicates_convergence, sc.criteria)
end

function Base.show(io::IO, ::MIME"text/plain", sc::StopWhenAll)
    s = ""
    for sc_i in sc.criteria
        s = s * "\n * " * replace("$(sc_i)", "\n" => "\n    ") #increase indent
    end
    return print(io, "StopWhenAll with the Stopping Criteria\n$(s)")
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
struct StopWhenAny{TCriteria<:Tuple} <: StoppingCriterion
    criteria::TCriteria
    StopWhenAny(c::Vector{<:StoppingCriterion}) = new{typeof(tuple(c...))}(tuple(c...))
    StopWhenAny(c::StoppingCriterion...) = new{typeof(c)}(c)
end

function indicates_convergence(sc::StopWhenAny)
    return all(indicates_convergence, sc.criteria)
end
function Base.show(io::IO, ::MIME"text/plain", sc::StopWhenAny)
    s = ""
    for sc_i in sc.criteria
        s = s * "\n * " * replace("$(sc_i)", "\n" => "\n    ") #increase indent
    end
    return print(io, "StopWhenAny with the Stopping Criteria\n$(s)")
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
This is for example used in combination with [`StopWhenAny`](@ref) and [`StopWhenAny`](@ref)

# Constructor
    GroupStoppingCriterionState(c::Vector{N,StoppingCriterionState} where N)
    GroupStoppingCriterionState(c::StoppingCriterionState...)
"""
mutable struct GroupStoppingCriterionState{TCriteriaStates<:Tuple} <: StoppingCriterionState
    criteria_states::TCriteriaStates
    at_iteration::Int
    GroupStoppingCriterionState(c::Vector{<:StoppingCriterionState}) =
        new{typeof(tuple(c...))}(tuple(c...), -1)
    GroupStoppingCriterionState(c::StoppingCriterionState...) = new{typeof(c)}(c, -1)
end

function initialize_state(
    problem::Problem,
    algorithm::Algorithm,
    sc::Union{StopWhenAll,StopWhenAny};
    kwargs...,
)
    return GroupStoppingCriterionState([
        initialize_state(problem, algorithm, sc_i; kwargs) for sc_i in sc.criteria
    ])
end
function initialize_state!(
    scs::GroupStoppingCriterionState,
    problem::Problem,
    algorithm::Algorithm,
    sc::Union{StopWhenAll,StopWhenAny};
    kwargs...,
)
    for (scs_i, sc_i) in zip(scs.criteria_states, sc.criteria)
        initialize_state!(scs_i, problem, algorithm, sc_i; kwargs...)
    end
    scs.at_iteration = -1
    return scs
end

function get_reason(sc::Union{StopWhenAll,StopWhenAny}, scs::GroupStoppingCriterionState)
    if scs.at_iteration >= 0
        return string(
            (
                get_reason(sc_i, scs_i) for
                (sc_i, scs_i) in zip(sc.criteria, scs.criteria_states)
            )...,
        )
    end
    return nothing
end

function Base.summary(io::IO, sc::StopWhenAny, scs::GroupStoppingCriterionState)
    has_stopped = (scs.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop When _one_ of the following are fulfilled:\n"
    for (sc_i, scs_i) in zip(sc.criteria, scs.criteria_states)
        s = replace(summary(sc_i, scs_i), "\n" => "\n    ")
        r = "$r    $(s)\n"
    end
    return "$(r)Overall: $s"
end
function Base.summary(io::IO, sc::StopWhenAll, scs::GroupStoppingCriterionState)
    has_stopped = (scs.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    r = "Stop When _all_ of the following are fulfilled:\n"
    for (sc_i, scs_i) in zip(sc.criteria, scs.criteria_states)
        s = replace(summary(sc_i, scs_i), "\n" => "\n    ")
        r = "$r    $(s)\n"
    end
    return print(io, "$(r)Overall: $s")
end
# Meta functors
function (scs::GroupStoppingCriterionState)(
    problem::Problem,
    algorithm::Algorithm,
    state::State,
    sc::StopWhenAll,
)
    k = get_iteration(state)
    (k == 0) && (scs.at_iteration = -1) # reset on init
    if all(st -> st[2](problem, algorithm, state, st[1]), zip(sc.criteria, scs.criteria_states))
        scs.at_iteration = k
        return true
    end
    return false
end

function (scs::GroupStoppingCriterionState)(
    problem::Problem,
    algorithm::Algorithm,
    state::State,
    sc::StopWhenAny,
)
    k = get_iteration(state)
    (k == 0) && (c.at_iteration = -1) # reset on init
    if any(st -> st[2](problem, algorithm, state, st[1]), zip(sc.criteria, scs.criteria_states))
        c.at_iteration = k
        return true
    end
    return false
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
mutable struct DefaultStoppingCriterionState
    at_iteration::Int
    DefaultStoppingCriterionState() = new(-1)
end

initialize_state(::Problem, ::Algorithm, ::StopAfterIteration; kwargs...) =
    DefaultStoppingCriterionState()
function initialize_state!(
    scs::DefaultStoppingCriterionState,
    ::Problem,
    ::Algorithm,
    ::StopAfterIteration;
    kwargs...,
)
    scs.at_iteration = -1
    return scs
end

function (scs::DefaultStoppingCriterionState)(
    ::Problem,
    ::Algorithm,
    state::State,
    sc::StopAfterIteration,
)
    k = get_iteration(state)
    (k == 0) && (scs.at_iteration = -1)
    if k >= sc.max_iterations
        scs.at_iteration = k
        return true
    end
    return false
end
function get_reason(sc::StopAfterIteration, scs::DefaultStoppingCriterionState)
    if scs.at_iteration >= sc.max_iterations
        return "At iteration $(scs.at_iteration) the algorithm reached its maximal number of iterations ($(sc.max_iterations)).\n"
    end
    return nothing
end
indicates_convergence(sc::StopAfterIteration) = false
function Base.summary(io::IO, sc::StopAfterIteration, scs::DefaultStoppingCriterionState)
    has_stopped = (scs.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    return print(io, "Max Iteration $(sc.max_iterations):\t$s")
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

initialize_state(::Problem, ::Algorithm, ::StopAfter; kwargs...) =
    StopAfterTimePeriodState()

function initialize_state!(
    scs::DefaultStoppingCriterionState,
    ::Problem,
    ::Algorithm,
    ::StopAfter;
    kwargs...,
)
    scs.start = Nanosecond(0)
    scs.time = Nanosecond(0)
    scs.at_iteration = -1
    return scs
end

function (scs::StopAfterTimePeriodState)(::Problem, ::Algorithm, state::State, sc::StopAfter)
    k = get_iteration(state)
    if value(scs.start) == 0 || k <= 0 # (re)start timer
        scs.at_iteration = -1
        scs.start = Nanosecond(time_ns())
        scs.time = Nanosecond(0)
    else
        scs.time = Nanosecond(time_ns()) - scs.start
        if k > 0 && (scs.time > Nanosecond(sc.threshold))
            scs.at_iteration = k
            return true
        end
    end
    return false
end
function get_reason(sc::StopAfter, scs::StopAfterTimePeriodState)
    if (scs.at_iteration >= 0)
        return "After iteration $(scs.at_iteration) the algorithm ran for $(floor(scs.time, typeof(sc.threshold))) (threshold: $(sc.threshold)).\n"
    end
    return nothing
end
function Base.summary(io::IO, sc::StopAfter, scs::StopAfterTimePeriodState)
    has_stopped = (scs.at_iteration >= 0)
    s = has_stopped ? "reached" : "not reached"
    return print(io, "stopped after $(sc.threshold):\t$s")
end
indicates_convergence(sc::StopAfter) = false
