# Newton's method for finding roots of a function
# wrapped as a very simple iterative algorithm

using AlgorithmsInterface
import AlgorithmsInterface: initialize_state, initialize_state!, is_finished, solve!, step!
using Test

# Defining the structs
# ------------------
struct RootFindingProblem <: Problem
    f::Function
    df::Function
end

struct NewtonMethod{S} <: Algorithm
    stopping_criterion::S
end

# Implementing the algorithm
# --------------------------
# The initial guess is the algorithm's to make rather than the caller's, so both
# initializations are implemented, handing the generic `State` the iterate to start from.
function initialize_state(problem::RootFindingProblem, algorithm::NewtonMethod; kwargs...)
    scs = initialize_state(problem, algorithm, algorithm.stopping_criterion; kwargs...)
    return State(1.0, scs) # hardcode initial guess to 1.0
end
function initialize_state!(
        problem::RootFindingProblem,
        algorithm::NewtonMethod,
        state::State;
        kwargs...,
    )
    return initialize_state!(problem, algorithm, state, 1.0; kwargs...)
end

function step!(problem::RootFindingProblem, ::NewtonMethod, state::State)
    state.iterate -= problem.f(state.iterate) / problem.df(state.iterate)
    return state
end

# Testing the algorithm
# ---------------------
@testset "Babylonian square roots" begin
    f(x, a) = x^2 - a
    df(x, a) = 2x

    a = 612.0
    problem = RootFindingProblem(x -> f(x, a), x -> df(x, a))
    algorithm1 = NewtonMethod(StopAfterIteration(8))
    solution1 = solve(problem, algorithm1)
    @test solution1 ≈ sqrt(a)
    algorithm2 = NewtonMethod(StopAfterIteration(10))
    solution2 = solve(problem, algorithm2)
    @test solution2 ≈ sqrt(a)
    @test abs(solution2 - sqrt(a)) < abs(solution1 - sqrt(a))
    state3 = initialize_state(problem, algorithm2)
    solve!(problem, algorithm2, state3)
    @test state3.iterate == solution2
end
