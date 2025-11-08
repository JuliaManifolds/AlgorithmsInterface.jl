@doc raw"""
🧮 AlgorithmsInterface.jl: an interface for iterative algorithms in Julia

* 📚 Documentation: [juliamanifolds.github.io/AlgorithmsInterface.jl/](https://juliamanifolds.github.io/AlgorithmsInterface.jl/)
* 📦 Repository: [github.com/JuliaManifolds/AlgorithmsInterface.jl](https://github.com/JuliaManifolds/AlgorithmsInterface.jl)
* 💬 Discussions: [github.com/JuliaManifolds/AlgorithmsInterface.jl/discussions](https://github.com/JuliaManifolds/AlgorithmsInterface.jl/discussions)
* 🎯 Issues: [github.com/JuliaManifolds/AlgorithmsInterface.jl/issues](https://github.com/JuliaManifolds/AlgorithmsInterface.jl/issues)
"""
module AlgorithmsInterface

using Dates: Millisecond, Nanosecond, Period, canonicalize, value
using Printf
using ScopedValues

include("interface/algorithm.jl")
include("interface/problem.jl")
include("interface/state.jl")
include("interface/interface.jl")

include("stopping_criterion.jl")
include("logging.jl")

# general interface
export Algorithm, Problem, State
export initialize_state, initialize_state!

export step!, solve, solve!

# stopping criteria
export StoppingCriterion, StoppingCriterionState
export StopAfter, StopAfterIteration, StopWhenAll, StopWhenAny

export is_finished, is_finished!, get_reason, indicates_convergence

# Logging interface
export LoggingAction, CallbackAction, IfAction, ActionGroup
export with_algorithmlogger, emit_message

end # module AlgorithmsInterface
