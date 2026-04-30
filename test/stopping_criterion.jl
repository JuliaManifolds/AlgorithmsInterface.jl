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
    alg_state = AIT.DummyState(s1_state, 1)
    @test is_finished(problem, algorithm, state_finished)
    @test !is_finished(problem, algorithm, alg_state)
end

@testset "StopAfter" begin
    s1 = StopAfter(Second(1))
    @test s1 isa StoppingCriterion
    @test string(s1) == "StopAfter(Second(1))"

    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)
    alg_state = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, alg_state)
    s1_state.time = Second(2)
    @test is_finished(problem, algorithm, alg_state)
end

@testset "StopWhenAll" begin
    c1 = StopAfterIteration(2)
    c2 = StopAfter(Nanosecond(2))
    c3 = StopAfterIteration(3)
    s1 = c1 & c2
    s1b = StopWhenAll([c1, c2])
    @test s1 == s1b
    @test s1 isa StoppingCriterion
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAll with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Nanosecond(2))"
    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)

    s1_str = summary(s1, s1_state)
    @test contains(s1_str, "Stop when _all_ ")
    @test contains(s1_str, "Overall: not reached")

    @test isnothing(AlgorithmsInterface.get_reason(s1, s1_state))
    alg_state = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, alg_state)
    # Fake start timer
    s1_state.criteria_states[2].start = Nanosecond(time_ns())
    s1_state.criteria_states[2].time = Nanosecond(7)
    # just time is not enough
    @test !is_finished(problem, algorithm, alg_state)
    alg_state.iteration = 2
    # but now both are
    @test is_finished!(problem, algorithm, alg_state)
    @test !indicates_convergence(s1)
    # check that reset works (a) check with modification
    @test is_finished!(problem, algorithm, alg_state)
    @test alg_state.stopping_criterion_state.at_iteration > 0
    AlgorithmsInterface.initialize_state!(problem, algorithm, s1, s1_state)
    @test s1_state.criteria_states[1].at_iteration == -1
    # Different constructors
    s2 = c1 & c2 & c3
    @test s1 & c3 == s2
    @test c1 & (c2 & c3) == s2
    @test s1 & s2 isa StopWhenAll
end

@testset "StopWhenAny" begin
    c1 = StopAfterIteration(2)
    c2 = StopAfter(Second(1))
    c3 = StopAfterIteration(3)

    s1 = c1 | c2
    @test s1 isa StoppingCriterion
    @test s1 == StopWhenAny([c1, c2])
    @test sprint((io, x) -> show(io, MIME"text/plain"(), x), s1) ==
        "StopWhenAny with the Stopping Criteria:\n     StopAfterIteration(2)\n     StopAfter(Second(1))"
    @test !indicates_convergence(s1)

    algorithm = AIT.DummyAlgorithm(s1)
    s1_state = initialize_state(problem, algorithm, s1)

    s1_str = summary(s1, s1_state)
    @test contains(s1_str, "Stop when _one_ ")
    @test contains(s1_str, "Overall: not reached")

    @test isnothing(AlgorithmsInterface.get_reason(s1, s1_state))
    alg_state = AIT.DummyState(s1_state, 1)
    @test !is_finished(problem, algorithm, alg_state)
    s1_state.criteria_states[2].time = Second(2)
    @test is_finished(problem, algorithm, alg_state)
    alg_state.iteration = 2
    @test is_finished(problem, algorithm, alg_state)
    # check that reset works (a) check with modification
    @test is_finished!(problem, algorithm, alg_state)
    @test alg_state.stopping_criterion_state.at_iteration > 0
    AlgorithmsInterface.initialize_state!(problem, algorithm, s1, s1_state)
    @test s1_state.criteria_states[1].at_iteration == -1
    # Different constructors
    s2 = c1 | c2 | c3
    @test s1 | c3 == s2
    @test c1 | (c2 | c3) == s2
    @test s1 | s2 isa StopWhenAny
end
