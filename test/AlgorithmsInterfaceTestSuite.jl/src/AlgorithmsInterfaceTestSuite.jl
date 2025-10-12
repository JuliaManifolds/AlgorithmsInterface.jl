"""
    AlgorithmsInterfaceTestSuite

A package to provide dummy algorithms and other test tools for `AlgorithmsInterface.jl`.
"""
module AlgorithmsInterfaceTestSuite

using AlgorithmsInterface

struct DummyAlgorithm <: Algorithm
    stopping_criterion::StoppingCriterion
end
struct DummyProblem <: Problem end
mutable struct DummyState{S <: StoppingCriterionState} <: State
    stopping_criterion_state::S
    iteration::Int
end

export DummyAlgorithm, DummyProblem, DummyState

end # module AlgorithmsInterfaceTestSuite
