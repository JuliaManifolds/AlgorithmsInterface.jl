# [Logging](@id sec_logging)

In the final part of the square‑root story we instrument the Heron iteration with logging.
The logging system answers two questions separately:

* **What happens when we log?** → a [`LoggingAction`](@ref).
* **When do we log?** → an [`AlgorithmLogger`](@ref) mapping contexts to actions.

This separation lets users compose rich behaviors (printing, collecting stats, plotting) without modifying algorithm code, and lets algorithm authors emit domain‑specific events.

## Recap: Default logging contexts

The generic `solve!` loop in `interface/interface.jl` emits these contexts:

| Context    | Meaning                                  |
|-----------:|------------------------------------------|
| `:Start`   | Just before iteration begins             |
| `:Init`    | After state initialization               |
| `:PreStep` | Right before a `step!`                   |
| `:PostStep`| Right after a `step!`                    |
| `:Stop`    | After halting (stopping criterion met)   |

Algorithms may add their own (e.g. `:Refinement`, `:RejectedStep`) by calling [`handle_message`](@ref) with a custom symbol.

## Global enable/disable

```julia
using AlgorithmsInterface: set_global_logging_state!, get_global_logging_state
set_global_logging_state!(false)  # silence all logging
previous = set_global_logging_state!(true)  # restore
```

## Instrumenting the square‑root algorithm

We start with minimal feedback: iteration number and current estimate.

```julia
iter_printer = CallbackAction() do alg, prob, st
    @printf("Iter %3d  x = %.12f\n", st.iteration, st.x)
end

logger = AlgorithmLogger(:PostStep => iter_printer)

with(ALGORITHM_LOGGER => logger) do
    state = solve(SqrtProblem(42.0), HeronAlgorithm(1.0, StopAfterIteration(8)))
    println("Final ≈ sqrt(42): ", state.x)
end
```

### Timing the run

Add actions for start timestamp and per‑step elapsed time:

```julia
start_time = Ref{Float64}(0.0)

record_start = CallbackAction() do alg, prob, st
    start_time[] = time()
end

show_elapsed = CallbackAction() do alg, prob, st
    dt = time() - start_time[]
    @printf("Iter %3d  elapsed = %.3fs\n", st.iteration, dt)
end

logger = AlgorithmLogger(
    :Init => record_start,
    :PostStep => LogGroup([iter_printer, show_elapsed]),
    :Stop => CallbackAction() do alg, prob, st
        @printf("Done after %d iterations (total %.3fs)\n", st.iteration, time() - start_time[])
    end,
)
```

### Conditional logging (every N steps)

```julia
every_five = IfAction(
    (prob, alg, st; kwargs...) -> st.iteration % 5 == 0,
    CallbackAction() do alg, prob, st
        println("Checkpoint at iteration ", st.iteration)
    end,
)

logger = AlgorithmLogger(:PostStep => every_five)
```

### Capturing history for analysis

Instead of printing, store iterates in a custom action:

```julia
struct CaptureHistory <: LoggingAction
    xs::Vector{Float64}
end
CaptureHistory() = CaptureHistory(Float64[])

function AlgorithmsInterface.handle_message!(act::CaptureHistory, prob::SqrtProblem, alg::HeronAlgorithm, st::HeronState; kwargs...)
    push!(act.xs, st.x)
    return nothing
end

history = CaptureHistory()
logger = AlgorithmLogger(:PostStep => history)
with(ALGORITHM_LOGGER => logger) do
    solve(SqrtProblem(42.0), HeronAlgorithm(1.0, StopWhenStable(1e-10) & StopAfterIteration(200)))
end
println("Stored ", length(history.xs), " iterates")
```

You can later inspect convergence visually (plot `history.xs`).

### Multiple simultaneous behaviors

Group actions to avoid multiple context entries:

```julia
logger = AlgorithmLogger(
    :PostStep => LogGroup([iter_printer, history, every_five]),
)
```

### Adding custom contexts

Suppose we augment Heron's method with a fallback if `x` becomes non‑finite. We can log that:

```julia
fallback_action = CallbackAction() do alg, prob, st; println("Fallback triggered at iteration ", st.iteration); end
logger = AlgorithmLogger(:Fallback => fallback_action, :PostStep => iter_printer)

function safe_step!(prob::SqrtProblem, alg::HeronAlgorithm, st::HeronState)
    isnan(st.x) && begin
        handle_message(prob, alg, st, :Fallback)
        st.x = alg.initial_guess
    end
    step!(prob, alg, st)
end
```

Just call `handle_message(prob, alg, st, :YourContext)` whenever the event occurs.

### Robustness: error isolation

If a `LoggingAction` throws, the system catches and reports the error without aborting the algorithm. Keep actions side‑effect focused and fast; heavy processing can collect data during iteration and post‑process afterwards.

### Writing a new action type (summary statistics)

```julia
struct StatsCollector <: LoggingAction
    n::Int
    sum::Float64
end
StatsCollector() = StatsCollector(0, 0.0)

function AlgorithmsInterface.handle_message!(act::StatsCollector, prob::SqrtProblem, alg::HeronAlgorithm, st::HeronState; kwargs...)
    act.n += 1
    act.sum += st.x
end

avg_action = CallbackAction() do alg, prob, st
    # could query stats at :Stop using captured object
end
stats = StatsCollector()
logger = AlgorithmLogger(:PostStep => LogGroup([stats, iter_printer]))
```

At the end:

```julia
println("Average iterate value = ", stats.sum / stats.n)
```

## Choosing what to store vs. print

Guidelines:

* Use printing for immediate feedback (development / CLI runs).
* Store vectors / tables in custom actions for later analysis or plotting.
* Keep actions pure w.r.t. algorithm state (read but do not modify `state`).
* Prefer one `LogGroup` per context over many individual mappings.

## Reference API

Auto‑generated documentation for logging infrastructure follows.

```@autodocs
Modules = [AlgorithmsInterface]
Pages = ["logging.jl"]
Order = [:type, :function]
Private = true
```

## Wrap‑up

You have now seen: defining an algorithm (interface page), controlling halting (stopping criteria), and instrumenting execution (logging). Together these patterns encourage modular, testable iterative algorithm design.
