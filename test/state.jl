# Tests for the state and the default state initialization

using Test
using AlgorithmsInterface
using AlgorithmsInterface: Test as AIT
using AlgorithmsInterface: increment!
using Dates

# Fixtures
# --------

# A problem and an algorithm that provide nothing beyond what the interface demands, so that
# every state they are solved with has to come from the default initialization. Newton's
# method initializes its own in `newton.jl`; the point here is that this one does not.
struct HalvingProblem <: Problem
    target::Float64
end

struct Halving{S <: StoppingCriterion} <: Algorithm
    stopping_criterion::S
end

function AlgorithmsInterface.step!(problem::HalvingProblem, ::Halving, state::State)
    state.iterate = (state.iterate + problem.target) / 2
    return state
end

# Carries a counter through `data` to show how an algorithm keeps data from one step to the
# next. A mutable struct is what the docs recommend for this: the state hands the same
# container back every step, and only its contents change.
struct CountingHalving{S <: StoppingCriterion} <: Algorithm
    stopping_criterion::S
end

mutable struct StepCounter
    steps::Int
end

function AlgorithmsInterface.step!(
        problem::HalvingProblem, ::CountingHalving, state::State,
    )
    state.iterate = (state.iterate + problem.target) / 2
    state.data.steps += 1
    return state
end

# Tests
# -----

@testset "State construction" begin
    scs = StoppingCriterionState()

    state = State(2.0, scs)
    @test state isa State{Float64, typeof(scs), Nothing}
    @test state.iterate == 2.0
    @test state.stopping_criterion_state === scs
    @test state.data === nothing
    @test state.iteration == 0

    # `iteration` is the third positional argument, with `data` staying last
    @test State(2.0, scs, 3, nothing).iteration == 3

    # the data field is opaque, so anything goes and nothing of it is exposed as a property
    named_tuple_state = State(2.0, scs, (; gradient = 1.0))
    @test named_tuple_state.data.gradient == 1.0
    @test !hasproperty(named_tuple_state, :gradient)

    dict_state = State(2.0, scs, Dict{Symbol, Any}(:gradient => 1.0))
    @test dict_state.data[:gradient] == 1.0
    dict_state.data[:hessian] = 2.0
    @test dict_state.data[:hessian] == 2.0
end

@testset "State interacts with the generic functionality" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))
    state = State(2.0, StoppingCriterionState())

    @test increment!(problem, algorithm, state) === state
    @test state.iteration == 1
    @test finalize_state!(problem, algorithm, state) == 2.0
    @test !is_finished!(problem, algorithm, state)
    @test !is_active(algorithm, state)
end

@testset "initialize_state defaults to a State" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))

    state = initialize_state(problem, algorithm, 2.0)
    @test state isa State
    @test state.iterate == 2.0
    @test state.iteration == 0
    @test state.data === nothing
    # the accompanying criterion state comes from the algorithm's own stopping criterion
    @test state.stopping_criterion_state isa StoppingCriterionState
    @test state.stopping_criterion_state.at_iteration == -1
    @test state.stopping_criterion_state.data === nothing

    # `state_data` and `stopping_state_data` are positional and land on their own state
    both = initialize_state(problem, algorithm, 2.0, (; a = 1), (; b = 2))
    @test both.data == (; a = 1)
    @test both.stopping_criterion_state.data == (; b = 2)

    # it is inferable
    @test @inferred(initialize_state(problem, algorithm, 2.0)) isa State

    # an algorithm that neither initializes a state itself nor is given an iterate to start
    # from is a mistake we should not paper over
    @test_throws MethodError initialize_state(problem, algorithm)

    # a criterion that carries data of its own still wins over the fallback
    time_algorithm = AIT.DummyAlgorithm(StopAfter(Second(1)))
    @test initialize_state(
        problem, time_algorithm, 2.0,
    ).stopping_criterion_state.data isa StopAfterTimePeriodData
end

@testset "initialize_state! resets a State" begin
    problem = AIT.DummyProblem()
    algorithm = AIT.DummyAlgorithm(StopAfterIteration(5))
    state = initialize_state(problem, algorithm, 2.0, (; a = 1), (; b = 2))

    state.iteration = 4
    state.stopping_criterion_state.at_iteration = 4

    # returns the state itself, not the stopping criterion state it also resets
    @test initialize_state!(problem, algorithm, state) === state
    @test state.iteration == 0
    @test state.stopping_criterion_state.at_iteration == -1
    # the iterate and both data fields are kept when they are not provided
    @test state.iterate == 2.0
    @test state.data == (; a = 1)
    @test state.stopping_criterion_state.data == (; b = 2)

    # positionally: iterate, then the two data fields
    initialize_state!(problem, algorithm, state, 3.0, (; a = 9), (; b = 8))
    @test state.iterate == 3.0
    @test state.data == (; a = 9)
    @test state.stopping_criterion_state.data == (; b = 8)

    # everything beyond the iterate is optional and keeps what the state already holds
    initialize_state!(problem, algorithm, state, 4.0, (; a = 7))
    @test state.iterate == 4.0
    @test state.data == (; a = 7)
    @test state.stopping_criterion_state.data == (; b = 8)

    initialize_state!(problem, algorithm, state)
    @test state.iterate == 4.0
    @test state.data == (; a = 7)
    @test state.stopping_criterion_state.data == (; b = 8)
end

@testset "an algorithm providing only a step! can be solved" begin
    problem = HalvingProblem(1.0)
    algorithm = Halving(StopAfterIteration(40))

    # no initialize_state, no initialize_state!: only `step!` above
    # `solve` passes the iterate it is given straight on to the default
    @test solve(problem, algorithm, 100.0) ≈ 1.0

    state = initialize_state(problem, algorithm, 100.0)
    @test solve!(problem, algorithm, state) ≈ 1.0
    @test state.iteration == 40

    # and it can carry its own data along
    counting = CountingHalving(StopAfterIteration(7))
    counting_state = initialize_state(problem, counting, 100.0, StepCounter(0))
    solve!(problem, counting, counting_state)
    @test counting_state.data.steps == 7
end
