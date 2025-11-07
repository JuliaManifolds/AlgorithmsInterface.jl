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
    # TODO: logging settings? stopping criterium initialization?
end

mutable struct NewtonState{S} <: State
    iteration::Int
    iterate::Float64
    stopping_criterion_state::S
end

# Implementing the algorithm
# --------------------------
function initialize_state(problem::RootFindingProblem, algorithm::NewtonMethod)
    scs = initialize_state(problem, algorithm, algorithm.stopping_criterion)
    return NewtonState(0, 1.0, scs) # hardcode initial guess to 1.0
end
function initialize_state!(
        problem::RootFindingProblem,
        algorithm::NewtonMethod,
        state::NewtonState,
    )
    state.iteration = 0
    state.iterate = 1.0
    initialize_state!(
        problem,
        algorithm,
        algorithm.stopping_criterion,
        state.stopping_criterion_state,
    )
    return state
end

function step!(problem::RootFindingProblem, ::NewtonMethod, state::NewtonState)
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
    @test solution1.iterate ≈ sqrt(a)
    algorithm2 = NewtonMethod(StopAfterIteration(10))
    solution2 = solve(problem, algorithm2)
    @test solution2.iterate ≈ sqrt(a)
    @test abs(solution2.iterate - sqrt(a)) < abs(solution1.iterate - sqrt(a))
end
