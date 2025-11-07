using Test
using AlgorithmsInterface

# Dummy types for a minimal iterative algorithm
struct LogDummyProblem <: Problem end
struct LogDummyAlgorithm <: Algorithm
    stopping_criterion
end
mutable struct LogDummyState{S <: StoppingCriterionState} <: State
    iterate::Float64
    iteration::Int
    stopping_criterion_state::S
end

# State initialization for the dummy algorithm
function AlgorithmsInterface.initialize_state(problem::LogDummyProblem, algorithm::LogDummyAlgorithm; kwargs...)
    sc_state = initialize_state(problem, algorithm, algorithm.stopping_criterion; kwargs...)
    return LogDummyState(0.0, 0, sc_state)
end
function AlgorithmsInterface.initialize_state!(
        problem::LogDummyProblem,
        algorithm::LogDummyAlgorithm,
        state::LogDummyState;
        kwargs...
    )
    initialize_state!(problem, algorithm, algorithm.stopping_criterion, state.stopping_criterion_state; kwargs...)
    state.iterate = 0.0
    state.iteration = 0
    return state
end

# One trivial step per iteration (not relevant for the logging test)
function AlgorithmsInterface.step!(
        ::LogDummyProblem,
        ::LogDummyAlgorithm,
        state::LogDummyState,
    )
    state.iterate += 1.0
    return state
end

@testset "CallbackAction logs iteration on each step" begin
    problem = LogDummyProblem()
    algorithm = LogDummyAlgorithm(StopAfterIteration(3))

    # Action that logs the current iteration number at :PostStep
    iter_logger = CallbackAction() do problem, algorithm, state
        @info "Iter $(state.iteration)"
    end

    # Expect exactly three info logs for iterations 1, 2, 3
    @test_logs (:info, "Iter 1") (:info, "Iter 2") (:info, "Iter 3") begin
        with_algorithmlogger(:PostStep => iter_logger) do
            solve(problem, algorithm)
        end
    end
end
