# [The algorithm interface](@id sec_interface)

This section starts a single, cohesive story that will weave through all documentation pages.
We will incrementally build an iterative algorithm, enrich it with stopping criteria, and
finally refine how it records (logs) its progress. Instead of presenting the API in the
abstract, we anchor every concept in one concrete, tiny example you can copy & adapt.

Why an “interface” for algorithms? Iterative numerical methods nearly always share the
same moving pieces:

* immutable input (the mathematical problem you are solving),
* immutable configuration (parameters and knobs of the chosen algorithm), and
* mutable working data (current iterate, caches, diagnostics) that evolves as you step.

Bundling these together loosely—without forcing one giant monolithic type—makes it easier to:

* reason about what is allowed to change and what must remain fixed,
* write generic tooling (e.g. stopping logic, logging, benchmarking) that applies across many algorithms,
* test algorithms in isolation by constructing minimal `Problem`/`Algorithm` pairs, and
* extend behavior (add new stopping criteria, new logging events) without rewriting core loops.

The interface in this package formalizes those roles with three abstract types:
* [`Problem`](@ref): immutable, algorithm‑agnostic input data.
* [`Algorithm`](@ref): immutable configuration and parameters deciding how to iterate.
* [`State`](@ref): mutable data that evolves (current iterate, caches, counters, diagnostics).
It provides a framework for decomposing iterative methods into small, composable parts:
concrete `Problem`/`Algorithm`/`State` types have to implement a minimal set of core functionality,
and this package helps to stitch everything together and provide additional helper functionality such as stopping criteria and logging functionality.

## [Concrete example: Heron's method](@id sec_heron)

To make everything tangible, we will work through a concrete example to illustrate the library's goals and concepts.
Our running example is Heron's / Babylonian method for estimating $\sqrt{S}$.
(see also the concise background on Wikipedia: [Babylonian method (Heron's method)](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)):
Starting from an initial guess $x_0$, we may converge to the solution by iterating:

$$x_{k+1} = \frac{1}{2}\left(x_k + \frac{S}{x_k}\right)$$

We therefore suggest the following concrete implementations of the abstract types provided by this package:
They are illustrative; various performance and generality questions will be left unaddressed to keep this example simple.

### Algorithm types

```@example Heron
using AlgorithmsInterface

struct SqrtProblem <: Problem
    S::Float64                # number whose square root we seek
end

struct HeronAlgorithm <: Algorithm
    stopping_criterion        # will be plugged in later (any StoppingCriterion)
end

mutable struct HeronState <: State
    iterate::Float64          # current iterate
    iteration::Int            # current iteration count
    stopping_criterion_state  # will be plugged in later (any StoppingCriterionState)
end
```

### Initialization

In order to start implementing the core parts of our algorithm, we start at the very beginning.
There are two main entry points provided by the interface:

- [`initialize_state`](@ref) constructs an entirely new state for the algorithm
- [`initialize_state!`](@ref) (in-place) reset of an existing state.

An example implementation might look like:

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

### Iteration steps

Algorithms define a mutable step via [`step!`](@ref). For Heron's method:

```@example Heron
function AlgorithmsInterface.step!(problem::SqrtProblem, algorithm::HeronAlgorithm, state::HeronState)
    S = problem.S
    x = state.iterate
    state.iterate = 0.5 * (x + S / x)
    return state
end
```

Note that we are only focussing on the actual algorithm, and *not* incrementing the iteration counter.
These kinds of bookkeeping should be handled by the [`increment!(state)`](@ref) function, which will by default already increment the iteration counter.
The following generic functionality is therefore enough for our purposes, and does *not* need to be defined.
Nevertheless, if additional bookkeeping would be desired, this can be achieved by overloading that function:

```julia
function AlgorithmsInterface.increment!(state::State)
    state.iteration += 1
    return state
end
```

### Running the algorithm

With these definitions in place you can already run (assuming you also choose a stopping criterion – added in the next section):

```@example Heron
function heron_sqrt(x; maxiter = 10)
    prob = SqrtProblem(x)
    alg  = HeronAlgorithm(StopAfterIteration(maxiter))
    state = solve(prob, alg)  # allocates & runs
    return state.iterate
end

println("Approximate sqrt: ", heron_sqrt(16.0))
```

We will refine this example with better halting logic and logging shortly.

## Reference: Core interface types & functions

Below are the automatic API docs for the core interface pieces. Read them after grasping the example above – the intent should now be clearer.

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/interface.jl"]
Order = [:type, :function]
Private = true
```

### Algorithm

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/algorithm.jl"]
Order = [:type, :function]
Private = true
```

### Problem

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/problem.jl"]
Order = [:type, :function]
Private = true
```

### State

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/state.jl"]
Order = [:type, :function]
Private = true
```

### Next: Stopping criteria

Proceed to the stopping criteria section to add robust halting logic (iteration caps, time limits, tolerance on successive iterates, and combinations) to this square‑root example.
