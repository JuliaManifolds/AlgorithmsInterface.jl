using SafeTestsets

# these have to be included here to make show tests behave
using AlgorithmsInterface
using Dates

@safetestset "Newton" begin
    include("newton.jl")
end

@safetestset "Stopping Criteria" begin
    include("stopping_criterion.jl")
end

@safetestset "Logging Infrastructure" begin
    include("logging.jl")
end

@safetestset "Aqua" begin
    using AlgorithmsInterface, Aqua
    Aqua.test_all(AlgorithmsInterface)
end
