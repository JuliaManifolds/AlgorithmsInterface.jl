using Test
using AlgorithmsInterface
using Dates

struct DummyAlgorithm <: Algorithm
    stopping_criterion::StoppingCriterion
end

struct DummyProblem <: Problem end

mutable struct DummyState{S <: StoppingCriterionState} <: State
    stopping_criterion_state::S
    iteration::Int
end

function AlgorithmsInterface.initialize_state(
        problem::DummyProblem, algorithm::DummyAlgorithm, stopping_criterion_state::StoppingCriterionState;
        kwargs...
    )
    return DummyState(stopping_criterion_state, 1)
end

problem = DummyProblem()

@testset "StopAfterIteration" begin
    s1 = StopAfterIteration(2)
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfterIteration(2)"

    algorithm = DummyAlgorithm(s1)
    state = initialize_state(problem, algorithm)
    @test !is_finished(problem, algorithm, state)
    AlgorithmsInterface.increment!(state)
    @test is_finished(problem, algorithm, state)
end

@testset "StopAfter" begin
    s1 = StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    state = initialize_state(problem, algorithm)
    @test !is_finished(problem, algorithm, state)
    state.stopping_criterion_state.time = Second(2)
    @test is_finished(problem, algorithm, state)
end

@testset "StopWhenAll" begin
    s1 = StopAfterIteration(2) & StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAll with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    state = initialize_state(problem, algorithm)
    @test !is_finished(problem, algorithm, state)
    state.stopping_criterion_state.criteria_states[2].time = Second(2)
    @test !is_finished(problem, algorithm, state)
    AlgorithmsInterface.increment!(state)
    @test is_finished(problem, algorithm, state)
end

@testset "StopWhenAny" begin
    s1 = StopAfterIteration(2) | StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAny with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    state = initialize_state(problem, algorithm)
    @test !is_finished(problem, algorithm, state)
    state.stopping_criterion_state.criteria_states[2].time = Second(2)
    @test is_finished(problem, algorithm, state)
    AlgorithmsInterface.increment!(state)
    @test is_finished(problem, algorithm, state)
end
