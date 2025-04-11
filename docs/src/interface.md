# The algorithm interface

## General design ideas

The interface this package provides is based on three ingredients of running an algorithm
consists of:

* a [`Problem`](@ref) that is to be solved and contains all information that is algorithm independent.
  This is _static information_ in the sense that it does not change during the runtime of the algorithm.
* an [`Algorithm`](@ref) that includes all of the _settings_ and _parameters_ that an algorithm.
  this is also information that is _static_.
* a [`State`](@ref) that contains all remaining data, especially data that might vary during the iteration,
  temporary caches, for example the current iteration the algorithm run is in and the current iterate, respectively.

The combination of the static information should be enough to initialize the varying data.

This general scheme is a guiding principle of the package, splitting information into _static_
or _configuration_ types or data that allows to [`initialize_state`](@ref) a corresponding _variable_ data type.

The order of arguments is given by two ideas

1. for non-mutating functions the order should be from the most fixed data to the most variable one.
  For example the three types just mentioned would be ordered like `f(problem, algorithm, state)`
2. For mutating functions the variable that is mutated comes first, for the remainder the guiding principle from 1 continues.
  The main case here is `f!(state, problem, algorithm)`.

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/interface.jl"]
Order = [:type, :function]
Private = true
```

## Algorithm

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/algorithm.jl"]
Order = [:type, :function]
Private = true
```

## Problem

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/problem.jl"]
Order = [:type, :function]
Private = true
```

## State

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["interface/state.jl"]
Order = [:type, :function]
Private = true
```