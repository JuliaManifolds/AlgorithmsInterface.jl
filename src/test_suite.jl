"""
    AlgorithmsInterface.Test

The module `AlgorithmsInterface.Test` contains concrete (dummy) instances
to test parts of the interface.
"""
module Test
using ..AlgorithmsInterface

struct DummyAlgorithm{S <: AlgorithmsInterface.StoppingCriterion} <: AlgorithmsInterface.Algorithm
    stopping_criterion::S
end
struct DummyProblem <: AlgorithmsInterface.Problem end
mutable struct DummyState{S <: AlgorithmsInterface.StoppingCriterionState} <: AlgorithmsInterface.State
    stopping_criterion_state::S
    iteration::Int
end
end
