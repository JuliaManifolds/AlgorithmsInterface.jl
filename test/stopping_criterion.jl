using Test
using AlgorithmsInterface
using AlgorithmsInterface: Test as AIT
using Dates

problem = AIT.DummyProblem()

@testset "StopAfterIteration" begin
    s1 = StopAfterIteration(2)
    @test s1 isa StoppingCriterion
    @test repr(s1) == "StopAfterIteration(2)"
    @test !indicates_convergence(s1)
    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    @test !indicates_convergence(s1, s1_state)
    state_finished = AIT.DummyState(s1_state, 2)
    state_not_finished = AIT.DummyState(s1_state, 1)
    @test is_finished(problem, algorithm, state_finished)
    @test !is_finished(problem, algorithm, state_not_finished)
end

@testset "StopAfter" begin
    s1 = StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfter(Second(1))"

    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.time = Second(2)
    @test is_finished(problem, algorithm, state_not_finished)
end

@testset "StopWhenAll" begin
    s1 = StopAfterIteration(2) & StopAfter(Second(1))
    s1b = StopWhenAll([StopAfterIteration(2), StopAfter(Second(1))])
    @test s1 == s1b
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAll with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.criteria_states[2].time = Second(2)
    @test !is_finished(problem, algorithm, state_not_finished)
    state_not_finished.iteration = 2
    @test is_finished(problem, algorithm, state_not_finished)
    @test !indicates_convergence(s1)
end

@testset "StopWhenAny" begin
    s1 = StopAfterIteration(2) | StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAny with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"

    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    state_not_finished = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, state_not_finished)
    s1_state.criteria_states[2].time = Second(2)
    @test is_finished(problem, algorithm, state_not_finished)
    state_not_finished.iteration = 2
    @test is_finished(problem, algorithm, state_not_finished)
end
