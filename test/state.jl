# Tests for the default state and the default state initialization

using Test
using AlgorithmsInterface
using AlgorithmsInterface: Test as AIT
using AlgorithmsInterface: increment!
using Dates

# Fixtures
# --------

# A problem and an algorithm without their own state type
struct HalvingProblem <: Problem
    target::Float64
end

struct Halving{S <: StoppingCriterion} <: Algorithm
    stopping_criterion::S
end

function AlgorithmsInterface.step!(problem::HalvingProblem, ::Halving, state::DefaultState)
    state.iterate = (state.iterate + problem.target) / 2
    return state
end

# Same, but storing a step counter in `data`
struct CountingHalving{S <: StoppingCriterion} <: Algorithm
    stopping_criterion::S
end

mutable struct StepCounter
    steps::Int
end

function AlgorithmsInterface.step!(
        problem::HalvingProblem, ::CountingHalving, state::DefaultState,
    )
    state.iterate = (state.iterate + problem.target) / 2
    state.data.steps += 1
    return state
end

# Tests
# -----

@testset "DefaultState construction" begin
    scs = DefaultStoppingCriterionState()

    state = DefaultState(2.0, scs)
    @test state isa DefaultState{Float64, typeof(scs), Nothing}
    @test state.iterate == 2.0
    @test state.stopping_criterion_state === scs
    @test state.data === nothing
    @test state.iteration == 0

    # `iteration` is the fourth positional argument
    @test DefaultState(2.0, scs, nothing, 3).iteration == 3

    # `data` can be anything, and its contents are not exposed as properties
    named_tuple_state = DefaultState(2.0, scs, (; gradient = 1.0))
    @test named_tuple_state.data.gradient == 1.0
    @test !hasproperty(named_tuple_state, :gradient)

    dict_state = DefaultState(2.0, scs, Dict{Symbol, Any}(:gradient => 1.0))
    @test dict_state.data[:gradient] == 1.0
    dict_state.data[:hessian] = 2.0
    @test dict_state.data[:hessian] == 2.0
end

@testset "DefaultState satisfies the State interface" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))
    state = DefaultState(2.0, DefaultStoppingCriterionState())

    @test increment!(state) === state
    @test state.iteration == 1
    @test finalize_state!(problem, algorithm, state) == 2.0
    @test !is_finished!(problem, algorithm, state)
    @test !is_active(algorithm, state)
end

@testset "initialize_state defaults to a DefaultState" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))

    state = initialize_state(problem, algorithm, 2.0)
    @test state isa DefaultState
    @test state.iterate == 2.0
    @test state.iteration == 0
    @test state.data === nothing
    # the accompanying criterion state comes from the algorithm's own stopping criterion
    @test state.stopping_criterion_state isa DefaultStoppingCriterionState
    @test state.stopping_criterion_state.at_iteration == -1

    # `state_data` is positional
    @test initialize_state(problem, algorithm, 2.0, (; a = 1)).data == (; a = 1)

    # the keyword form forwards to the same implementation
    @test initialize_state(problem, algorithm; iterate = 2.0, state_data = (; a = 1)).data ==
        (; a = 1)

    # type stable
    @test @inferred(initialize_state(problem, algorithm, 2.0)) isa DefaultState

    # the `iterate` keyword is required
    @test_throws UndefKeywordError initialize_state(problem, algorithm)

    # criteria with their own state still use it
    time_algorithm = AIT.DummyAlgorithm(StopAfter(Second(1)))
    @test initialize_state(
        problem, time_algorithm, 2.0,
    ).stopping_criterion_state isa StopAfterTimePeriodState
end

@testset "initialize_state! resets a DefaultState" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))
    state = initialize_state(problem, algorithm, 2.0, (; a = 1))

    state.iteration = 4
    state.stopping_criterion_state.at_iteration = 4

    # returns the state, not the stopping criterion state
    @test initialize_state!(problem, algorithm, state) === state
    @test state.iteration == 0
    @test state.stopping_criterion_state.at_iteration == -1
    # the iterate and data are kept if not provided
    @test state.iterate == 2.0
    @test state.data == (; a = 1)

    # positionally: iterate, then the data
    initialize_state!(problem, algorithm, state, 3.0, (; a = 9))
    @test state.iterate == 3.0
    @test state.data == (; a = 9)
    initialize_state!(problem, algorithm, state, 3.5)
    @test state.iterate == 3.5
    @test state.data == (; a = 9)

    # the keyword form forwards to the same implementation
    initialize_state!(problem, algorithm, state; iterate = 4.0, state_data = (; a = 7))
    @test state.iterate == 4.0
    @test state.data == (; a = 7)
end

@testset "an algorithm without a state type of its own can be solved" begin
    problem = HalvingProblem(1.0)
    algorithm = Halving(StopAfterIteration(40))

    # only `step!` is defined
    @test solve(problem, algorithm; iterate = 100.0) ≈ 1.0

    state = initialize_state(problem, algorithm, 100.0)
    @test solve!(problem, algorithm, state) ≈ 1.0
    @test state.iteration == 40

    # with data
    counting = CountingHalving(StopAfterIteration(7))
    counting_state = initialize_state(problem, counting, 100.0, StepCounter(0))
    solve!(problem, counting, counting_state)
    @test counting_state.data.steps == 7
end
