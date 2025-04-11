using SafeTestsets

@safetestset "Newton" begin
    include("newton.jl")
end

@safetestset "Aqua" begin
    using AlgorithmsInterface, Aqua
    Aqua.test_all(AlgorithmsInterface)
end
