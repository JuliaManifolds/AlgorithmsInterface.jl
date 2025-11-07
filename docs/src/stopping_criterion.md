# Stopping criteria

Continuing the square‑root story from the [Interface](@ref sec_interface) page, we now decide **when** the iteration should halt.
A stopping criterion encapsulates halting logic separately from the algorithm update rule.

## Why separate stopping logic?

Decoupling halting from stepping lets us:

* Reuse generic stopping (iteration caps, time limits) across algorithms.
* Compose multiple conditions (stop after 1 second OR 100 iterations, etc.).
* Query convergence indication vs. mere forced termination.
* Store structured reasons and state (e.g. at which iteration a threshold was met).


## Built-in criteria: Heron's method

The package ships several concrete [`StoppingCriterion`](@ref)s:

* [`StopAfterIteration`](@ref): stop after a maximum number of iterations.
* [`StopAfter`](@ref): stop after a wall‑clock time `Period` (e.g. `Second(2)`, `Minute(1)`).
* Combinations [`StopWhenAll`](@ref) (logical AND) and [`StopWhenAny`](@ref) (logical OR) built via `&` and `|` operators.

Each criterion has an associated [`StoppingCriterionState`](@ref) storing dynamic data (iteration when met, elapsed time, etc.).

Recall our [example implementation](@ref sec_heron) for Heron's method, where we we added a `stopping_criterion` to the `Algorithm`, as well as a `stopping_criterion_state` to the `State`.

```@example Heron
using AlgorithmsInterface

struct SqrtProblem <: Problem
    S::Float64                # number whose square root we seek
end

struct HeronAlgorithm <: Algorithm
    stopping_criterion        # any StoppingCriterion
end

mutable struct HeronState <: State
    iterate::Float64          # current iterate
    iteration::Int            # current iteration count
    stopping_criterion_state  # any StoppingCriterionState
end
```

Here, we delve a bit deeper into the core components of what made our algorithm stop, even though we had to add very little additional functionality.

### Initialization

The first core component to enable working with stopping criteria is to extend the initialization step to include initializing a [`StoppingCriterionState`](@ref) as well.
This can conveniently be done through the same initialization functions we used for initializing the state:

- [`initialize_state`](@ref) constructs an entirely new stopping state for the algorithm
- [`initialize_state!`](@ref) (in-place) reset of an existing stopping state.

```@example Heron
function AlgorithmsInterface.initialize_state(problem::SqrtProblem, algorithm::HeronAlgorithm; kwargs...)
    x0 = rand() # random initial guess
    stopping_criterion_state = initialize_state(problem, algorithm, algorithm.stopping_criterion)
    return HeronState(x0, 0, stopping_criterion_state)
end

function AlgorithmsInterface.initialize_state!(problem::SqrtProblem, algorithm::HeronAlgorithm, state::HeronState; kwargs...)
    # reset the state for the algorithm
    state.iterate = rand()
    state.iteration = 0
    
    # reset the state for the stopping criterion
    state = AlgorithmsInterface.initialize_state!(
        problem, algorithm, algorithm.stopping_criterion, state.stopping_criterion_state
    )
    return state
end
```

### Iteration

During the iteration procedure, as set out by our design principles, we do not have to modify any of the code, and the stopping criteria do not show up:

```@example Heron
function AlgorithmsInterface.step!(problem::SqrtProblem, algorithm::HeronAlgorithm, state::HeronState)
    S = problem.S
    x = state.iterate
    state.iterate = 0.5 * (x + S / x)
    return state
end
```

What is really going on is that behind the scenes, the loop of the iterative solver expands to code that is equivalent to:

```julia
while !is_finished!(problem, algorithm,  state)
    increment!(state)
    step!(problem, algorithm, state)
end
```

In other words, all of the logic is handled by the [`is_finished!`](@ref) function.
The generic stopping criteria provided by this package have default implementations for this function that work out-of-the-box.
This is partially because we used conventional names for the fields in the structs.
There, `Algorithm` assumes the existence of `stopping_criterion`, while `State` assumes `iterate` and `iteration` and `stopping_criterion_state` to exist.

### Running the algorithm

We can again combine everything into a single function, but now make the stopping criterion accessible:

```@example Heron
function heron_sqrt(x; stopping_criterion)
    prob = SqrtProblem(x)
    alg  = HeronAlgorithm(stopping_criterion)
    state = solve(prob, alg)  # allocates & runs
    return state.iterate, state.iteration
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

Conversely, to demand both a minimum iteration quality condition **and** a cap, use `&` (logical AND).

```@example Heron
criterion = StopAfterIteration(25) & StopAfter(Millisecond(50))  # logical AND
heron_sqrt(2; stopping_criterion = criterion)
```

## Implementing a new criterion

It is of course possible that we are not satisfied by the stopping criteria that are provided by default.
Suppose we want to stop when successive iterates change by less than `ϵ`, we could achieve this by implementing our own stopping criterion.
In order to do so, we need to define our own structs and implement the required interface.
Again, we split up the data into a _static_ part, the [`StoppingCriterion`](@ref), and a _dynamic_ part, the [`StoppingCriterionState`](@ref).

```@example Heron
struct StopWhenStable <: StoppingCriterion
    tol::Float64    # when do we consider things converged
end

mutable struct StopWhenStableState <: StoppingCriterionState
    previous_iterate::Float64       # previous value to compare to
    at_iteration::Int               # iteration at which stability was reached
    delta::Float64                  # difference between the values
end
```

Note that our mutable state holds both the `previous_iterate`, which we need to compare to,
as well as the iteration at which the condition was satisfied.
This is not strictly necessary, but can be convenient to have a persistent indication that convergence was reached.

### Initialization

In order to support these _stateful_ criteria, again an initialization phase is needed.
This could be implemented as follows:

```@example Heron
function AlgorithmsInterface.initialize_state(::Problem, ::Algorithm, c::StopWhenStable; kwargs...)
    return StopWhenStableState(NaN, -1, NaN)
end

function AlgorithmsInterface.initialize_state!(
        ::Problem, ::Algorithm, stop_when::StopWhenStable, st::StopWhenStableState;
        kwargs...
)
    st.previous_iterate = NaN
    st.at_iteration = -1
    st.delta = NaN
    return st
end
```

### Checking for convergence

Then, we need to implement the logic that checks whether an algorithm has finished, which is achieved through [`is_finished`](@ref) and [`is_finished!`](@ref).
Here, the mutating version alters the `stopping_criterion_state`, and should therefore be called exactly once per iteration, while the non-mutating version is simply used to inspect the current status.

```@example Heron
function AlgorithmsInterface.is_finished!(
        ::Problem, ::Algorithm, state::State, c::StopWhenStable, st::StopWhenStableState
)
	k = state.iteration
	if k == 0
		st.previous_iterate = state.iterate
		st.at_iteration = -1
		return false
	end

	st.delta = abs(state.iterate - st.previous_iterate)
	st.previous_iterate = state.iterate
	if st.delta < c.tol
		st.at_iteration = k
		return true
	end
	return false
end

function AlgorithmsInterface.is_finished(
        ::Problem, ::Algorithm, state::State, c::StopWhenStable, st::StopWhenStableState
)
	k = state.iteration
	k == 0 && return false

	Δ = abs(state.iterate - st.previous_iterate)
	return Δ < c.tol
end
```

### Reason and convergence reporting

Finally, we need to implement [`get_reason`](@ref) and [`indicates_convergence`](@ref).
These helper functions are required to interact with the [logging system](@ref sec_logging), to distinguish between states that are considered ongoing, stopped and converged, or stopped without convergence.

```@example Heron
function AlgorithmsInterface.get_reason(c::StopWhenStable, st::StopWhenStableState)
    (st.at_iteration >= 0 && st.delta < c.tol) || return nothing
    return "The algorithm reached an approximate stable point after $(st.at_iteration) iterations; the change $(st.delta) is less than $(c.tol)."
end

AlgorithmsInterface.indicates_convergence(c::StopWhenStable, st::StopWhenStableState) = true
```

### Convergence in action

Then we are finally ready to test out our new stopping criterion.

```@example Heron
criterion = StopWhenStable(1e-8)
heron_sqrt(16.0; stopping_criterion = criterion)
```

Note that our work payed off, as we can still compose this stopping criterion with other criteria as well:

```@example Heron
criterion = StopWhenStable(1e-8) | StopAfterIteration(5)
heron_sqrt(16.0; stopping_criterion = criterion)
```

### Summary

Implementing a criterion usually means defining:

1. A subtype of [`StoppingCriterion`](@ref).
2. A state subtype of [`StoppingCriterionState`](@ref) capturing dynamic fields.
3. `initialize_state` and `initialize_state!` for setup/reset.
4. `is_finished!` (mutating) and optionally `is_finished` (non‑mutating) variants.
5. `get_reason` (return `nothing` or a string) for user feedback.
6. `indicates_convergence(::YourCriterion)` to mark if meeting it implies convergence.

You may also implement `Base.summary(io, criterion, criterion_state)` for compact status reports.

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
