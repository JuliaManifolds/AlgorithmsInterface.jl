```@meta
CollapsedDocStrings = true
```

# [Stopping criteria](@id sec_stopping)

Continuing the square‑root story from the [Interface](@ref sec_interface) page, we now decide **when** the iteration should halt.
A stopping criterion encapsulates halting logic separately from the algorithm update rule.

## Why separate stopping logic?

Decoupling halting from stepping lets us:

* Reuse generic stopping (iteration caps, time limits) across algorithms.
* Compose multiple conditions (stop after 1 second OR 100 iterations, etc.).
* Query convergence indication vs. mere forced termination, see [querying the verdict](@ref sec_stopping_verdict).
* Store structured reasons and state (e.g. at which iteration a threshold was met).


## Built-in criteria: Heron's method

The package ships several concrete [`StoppingCriterion`](@ref)s:

* [`StopAfterIteration`](@ref): stop after a maximum number of iterations.
* [`StopAfter`](@ref): stop after a wall‑clock time `Period` (e.g. `Second(2)`, `Minute(1)`).
* Combinations [`StopWhenAll`](@ref) (logical AND) and [`StopWhenAny`](@ref) (logical OR) built via `&` and `|` operators.

Each criterion has an associated [`StoppingCriterionState`](@ref) storing dynamic data (iteration when met, elapsed time, etc.).

Recall our [example implementation](@ref sec_heron) for Heron's method, where the `Algorithm` carries a `stopping_criterion` and the `State` a `stopping_criterion_state`.

```@example Heron
using AlgorithmsInterface

struct SqrtProblem <: Problem
    S::Float64                # number whose square root we seek
end

struct HeronAlgorithm <: Algorithm
    stopping_criterion        # any StoppingCriterion
end
```

Here, we delve a bit deeper into the core components of what made our algorithm stop, even though we had to add very little additional functionality.

### Initialization

The first core component to enable working with stopping criteria is that the initialization step initializes a [`StoppingCriterionState`](@ref) as well.
This happens through the same initialization functions we used for initializing the state:

- [`initialize_state`](@ref) constructs an entirely new stopping state for the algorithm
- [`initialize_state!`](@ref) (in-place) reset of an existing stopping state.

Since we leave the initialization to its defaults, this is already taken care of: they pair the [`State`](@ref) with the state of the algorithm's own criterion, along the lines of

```julia
function AlgorithmsInterface.initialize_state(problem::Problem, algorithm::Algorithm, iterate; kwargs...)
    stopping_criterion_state = initialize_state(problem, algorithm, algorithm.stopping_criterion; kwargs...)
    return State(iterate, stopping_criterion_state)
end
```

An [`initialize_state`](@ref) of your own only decides which `iterate` to pass along, and can leave that pairing to the method above.

### Iteration

During the iteration procedure, as set out by our design principles, we do not have to modify any of the code, and the stopping criteria do not show up:

```@example Heron
function AlgorithmsInterface.step!(problem::SqrtProblem, algorithm::HeronAlgorithm, state::State)
    S = problem.S
    x = state.iterate
    state.iterate = 0.5 * (x + S / x)
    return state
end
```

What is really going on is that behind the scenes, the loop of the iterative solver expands to code that is equivalent to:

```julia
while !is_finished!(problem, algorithm,  state)
    increment!(problem, algorithm, state)
    step!(problem, algorithm, state)
end
```

In other words, all of the logic is handled by the [`is_finished!`](@ref) function.
The generic stopping criteria provided by this package have default implementations for this function that work out-of-the-box.
This is partially because everything is reached under conventional names: the generic code assumes an `Algorithm` to carry a `stopping_criterion`, and reads the `iterate`, the `iteration` and the `stopping_criterion_state` of the [`State`](@ref).

### Running the algorithm

We can again combine everything into a single function, but now make the stopping criterion accessible:

```@example Heron
function heron_sqrt(x; stopping_criterion)
    prob = SqrtProblem(x)
    alg  = HeronAlgorithm(stopping_criterion)
    return solve(prob, alg, 1.0)  # allocates & runs
end

heron_sqrt(2; stopping_criterion = StopAfterIteration(10))
```

With this function, we are now ready to explore different ways of telling the algorithm to stop.
For example, using the basic criteria provided by this package, we can alternatively do:

```@example Heron
using Dates
criterion = StopAfter(Millisecond(50))
heron_sqrt(2; stopping_criterion = criterion)
```

We can tighten the condition by combining criteria. Suppose we want to stop after either 25 iterations or 50 milliseconds, whichever comes first:

```@example Heron
criterion = StopAfterIteration(25) | StopAfter(Millisecond(50))  # logical OR
heron_sqrt(2; stopping_criterion = criterion)
```

Conversely, to demand both a minimum iteration count **and** a time cap, use `&` (logical AND).

```@example Heron
criterion = StopAfterIteration(25) & StopAfter(Millisecond(50))  # logical AND
heron_sqrt(2; stopping_criterion = criterion)
```

## Implementing a new criterion

It is of course possible that we are not satisfied by the stopping criteria that are provided by default.
Suppose we want to stop when successive iterates change by less than `ϵ`, we could achieve this by implementing our own stopping criterion.
In order to do so, we need to define our own structs and implement the required interface.
Again, we split up the data into a _static_ part, the [`StoppingCriterion`](@ref), and a _dynamic_ part, the [`StoppingCriterionState`](@ref).

The dynamic part is not yours to write: [`StoppingCriterionState`](@ref) records the iteration at which the criterion triggered, and carries a `data` field for anything else it has to remember.
What a criterion does define is that `data` — here the previous iterate to compare against, and the change we measured, which we keep around for the message:

```@example Heron
struct StopWhenStable <: StoppingCriterion
    tol::Float64    # when do we consider things converged
end

mutable struct StableData
    previous_iterate::Float64       # previous value to compare to
    delta::Float64                  # difference between the values
end
```

A mutable struct is the recommended container: the state keeps handing the same one back, and the criterion updates its fields in place.
Note that the iteration at which the condition was satisfied is *not* part of it — that is the `at_iteration` the state records for every criterion.

### Initialization

In order to support these _stateful_ criteria, again an initialization phase is needed.
This could be implemented as follows:

```@example Heron
function AlgorithmsInterface.initialize_state(::Problem, ::Algorithm, c::StopWhenStable; kwargs...)
    return StoppingCriterionState(StableData(NaN, NaN))
end

function AlgorithmsInterface.initialize_state!(
        ::Problem, ::Algorithm, stop_when::StopWhenStable, st::StoppingCriterionState;
        kwargs...
)
    st.data.previous_iterate = NaN
    st.data.delta = NaN
    st.at_iteration = -1
    return st
end
```

Both are handed a `stopping_state_data` keyword, which is `nothing` unless a caller wants to supply the container itself.
Ignoring it, as above, means the criterion always uses one of its own; a criterion that lets it through takes what it is given instead, the way [`StopAfter`](@ref) does with its clock:

```julia
function AlgorithmsInterface.initialize_state(
        ::Problem, ::Algorithm, c::StopWhenStable; stopping_state_data = nothing, kwargs...
)
    return StoppingCriterionState(
        isnothing(stopping_state_data) ? StableData(NaN, NaN) : stopping_state_data
    )
end
```

### Checking for convergence

Then, we need to implement the logic that checks whether an algorithm has finished, which is achieved through [`is_finished`](@ref) and [`is_finished!`](@ref).
Here, the mutating version alters the `stopping_criterion_state`, and should therefore be called exactly once per iteration, while the non-mutating version is simply used to inspect the current status.

```@example Heron
function AlgorithmsInterface.is_finished!(
        ::Problem, ::Algorithm, state::State, c::StopWhenStable, st::StoppingCriterionState
)
    k = state.iteration
    if k == 0
        st.data.previous_iterate = state.iterate
        st.at_iteration = -1
        return false
    end

    st.data.delta = abs(state.iterate - st.data.previous_iterate)
    st.data.previous_iterate = state.iterate
    if st.data.delta < c.tol
        st.at_iteration = k
        return true
    end
    return false
end

function AlgorithmsInterface.is_finished(
        ::Problem, ::Algorithm, state::State, c::StopWhenStable, st::StoppingCriterionState
)
    k = state.iteration
    k == 0 && return false

    Δ = abs(state.iterate - st.data.previous_iterate)
    return Δ < c.tol
end
```

### Reason and convergence reporting

Finally, we need to say what our criterion reports once it has triggered.
There are two separate questions here, and keeping them apart is what makes the generic reporting work:

* *Did* this criterion indicate to stop? This is answered by [`is_active`](@ref), and it is what all the generic machinery is built on.
* Why, in words? This is answered by [`get_reason`](@ref), and it is for human consumption only.

We get the first one for free.
The default implementation of [`is_active`](@ref) reads the `at_iteration` property of the state, which every criterion has, following the convention that a negative value means "has not (yet) indicated to stop".
Only a criterion that records its status in its `data` instead has to implement [`is_active`](@ref) itself.

That leaves the message, plus the static statement that meeting this criterion *does* mean convergence:

```@example Heron
function AlgorithmsInterface.get_reason(c::StopWhenStable, st::StoppingCriterionState)
    is_active(c, st) || return nothing
    return "The algorithm reached an approximate stable point after $(st.at_iteration) iterations; the change $(st.data.delta) is less than $(c.tol).\n"
end

AlgorithmsInterface.indicates_convergence(::Type{StopWhenStable}) = true
```

Note that `get_reason` gates on the *recorded* status rather than re-checking `st.data.delta < c.tol`.
Re-checking the predicate would make the message disappear again as soon as the state moves on, whereas `at_iteration` is a permanent record of what happened.

Only the type-domain [`indicates_convergence`](@ref) needs to be defined.
It answers "would meeting this criterion mean the algorithm converged?", which is a static property of the criterion type alone.
The variant taking a criterion simply forwards to the type, and the two-argument variant, which additionally answers "*did* it happen?", is derived from it and [`is_active`](@ref):

```@example Heron
criterion = StopWhenStable(1e-8)
criterion_state = AlgorithmsInterface.initialize_state(SqrtProblem(16.0), HeronAlgorithm(criterion), criterion)
indicates_convergence(criterion), indicates_convergence(criterion, criterion_state)
```

The criterion always *could* indicate convergence, but its fresh state has not yet seen it happen.

This distinction matters most for composed criteria.
A `StopWhenStable(1e-8) | StopAfterIteration(5)` can stop for either reason, so `indicates_convergence` of the group *without* a state is `false` since the group offers no guarantee.
Given a state, it reports whether one of the children that actually triggered indicates convergence, which is what lets a caller tell "converged" apart from "ran out of iterations".

Both `get_reason` and the type-domain `indicates_convergence` have conservative defaults, `nothing` and `false`, so a criterion that has nothing to add does not have to implement them.

### [Querying the verdict](@id sec_stopping_verdict)

After a run, these same functions are how a caller finds out what happened.
Since [`solve`](@ref) returns only the iterate, we use [`solve!`](@ref) with a state we hold on to:

```@example Heron
function heron_verdict(x, criterion)
    problem = SqrtProblem(x)
    algorithm = HeronAlgorithm(criterion)
    state = AlgorithmsInterface.initialize_state(problem, algorithm, 1.0)

    solve!(problem, algorithm, state)

    converged = indicates_convergence(algorithm, state)
    reason = get_reason(algorithm, state)
    active = [typeof(c) for (c, cs) in get_active_stopping_criteria(algorithm, state)]

    return converged, reason, active
end

heron_verdict(16.0, StopWhenStable(1e-8) | StopAfterIteration(50))
```

These two-argument forms extract the criterion and its state for us, so there is no need to reach into `algorithm.stopping_criterion` and `state.stopping_criterion_state` by hand.

The very same criterion reports a different verdict when the budget is what runs out first:

```@example Heron
heron_verdict(16.0, StopWhenStable(1e-8) | StopAfterIteration(5))
```

This is the distinction the whole two-argument machinery exists for.
Note also that convergence is a coarse verdict: an iteration cap and a collapsed step size both fail to indicate convergence while calling for quite different responses.
That is what [`get_active_stopping_criteria`](@ref) is for — it reports exactly which criteria became active, recursing through any [`StopWhenAll`](@ref) and [`StopWhenAny`](@ref) so that the groups themselves never show up.

The [logging system](@ref sec_logging) offers [`StopReasonAction`](@ref) to report the reason at the `:Stop` context, without having to hold on to the state at all.

### Convergence in action

Then we are finally ready to test out our new stopping criterion.

```@example Heron
criterion = StopWhenStable(1e-8)
heron_sqrt(16.0; stopping_criterion = criterion)
```

Note that our work paid off, as we can still compose this stopping criterion with other criteria as well:

```@example Heron
criterion = StopWhenStable(1e-8) | StopAfterIteration(5)
heron_sqrt(16.0; stopping_criterion = criterion)
```

### Summary

Implementing a criterion means defining:

1. A subtype of [`StoppingCriterion`](@ref).
2. `is_finished!` (mutating) and optionally `is_finished` (non‑mutating) variants.
3. `get_reason` (return `nothing` or a string) for user feedback, gated on `is_active`.
4. `indicates_convergence(::Type{YourCriterion})` to mark if meeting it implies convergence.
   The `(criterion,)` and the `(criterion, criterion_state)` variant are derived from this one and do not need to be defined.

The state is taken care of for you.
[`initialize_state`](@ref) and [`initialize_state!`](@ref) return and reset a [`StoppingCriterionState`](@ref), which records the `at_iteration` that all the reporting is built on and carries a `data` field for whatever else the criterion has to remember.

Only a criterion that needs such data, as the one above needed a `previous_iterate` to compare against, additionally defines:

* A container for it, reached as `stopping_criterion_state.data`.
* `initialize_state` and `initialize_state!` to fill and reset that container.

You may also implement `Base.summary(io, criterion, criterion_state)` for compact status reports,
and `is_active(criterion, criterion_state)` if your criterion does not record its status in the
state's `at_iteration` property.

## Reference API

Below are the auto‑generated docs for all stopping criterion infrastructure.

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["stopping_criterion.jl"]
Order = [:type, :function]
Private = true
```

### Next: Logging

With halting logic done, proceed to the [logging section](@ref sec_logging) to instrument the same example and capture intermediate diagnostics.
