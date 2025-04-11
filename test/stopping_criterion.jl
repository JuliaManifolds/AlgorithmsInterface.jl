using Test
using AlgorithmsInterface
using Dates

struct DummyAlgorithm <: Algorithm
    stopping_criterion::StoppingCriterion
end
struct DummyProblem <: Problem end
mutable struct DummyState{S<:StoppingCriterionState} <: State
    stopping_criterion_state::S
    iteration::Int
end

problem = DummyProblem()

@testset "StopAfterIteration" begin
    s1 = StopAfterIteration(2)
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfterIteration(2)"

    algorithm = DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_finished = DummyState(s1_state, 2)
    state_not_finished = DummyState(s1_state, 1)
    @test is_finished(problem, algorithm, state_finished)
    @test !is_finished(problem, algorithm, state_not_finished)
end

@testset "StopAfter" begin
    s1 = StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.time = Second(2)
    @test is_finished(problem, algorithm, state_not_finished)
end

@testset "StopWhenAll" begin
    s1 = StopAfterIteration(2) & StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
          "StopWhenAll with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.criteria_states[2].time = Second(2)
    @test !is_finished(problem, algorithm, state_not_finished)
    state_not_finished.iteration = 2
    @test is_finished(problem, algorithm, state_not_finished)
end

@testset "StopWhenAny" begin
    s1 = StopAfterIteration(2) | StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
          "StopWhenAny with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.criteria_states[2].time = Second(2)
    @test is_finished(problem, algorithm, state_not_finished)
    state_not_finished.iteration = 2
    @test is_finished(problem, algorithm, state_not_finished)
end
