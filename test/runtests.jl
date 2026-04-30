# Test entry point — uses ParallelTestRunner.jl to run test files in parallel
# worker processes (auto-discovered from `test/`).
#
# Run locally:
#   julia --project=test test/runtests.jl                  # run all tests
#   julia --project=test test/runtests.jl --list           # list discovered test files
#   julia --project=test test/runtests.jl --help           # show full usage
#   julia --project=test test/runtests.jl <name> [<name>…] # only files whose
#                                                          # name starts with <name>
#
# Or from the Julia REPL:
#   using Pkg; Pkg.test("AlgorithmsInterface";
#                       test_args=["--jobs=4", "--verbose"])
#
# Useful CLI options:
#   --jobs=N      number of worker processes (default: chosen from CPU/memory)
#   --verbose     print per-test timing, compile time, and memory stats
#   --quickfail   abort the whole run on the first failure

using ParallelTestRunner
using AlgorithmsInterface

runtests(AlgorithmsInterface, ARGS)
