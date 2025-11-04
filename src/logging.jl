# LoggingAction interface
# -----------------------
"""
    LoggingAction

Abstract supertype for defining an action that generates a log record.

## Methods
Any concrete subtype should at least implement the following method to handle the logging event:

- [`handle_message!(action, problem, algorithm, state, args...; kwargs...)`](@ref handle_message!)
"""
abstract type LoggingAction end

@doc """
    handle_message!(action::LoggingAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...)

Entry-point for defining an implementation of how to handle a logging event for a given [`LoggingAction`](@ref).
""" handle_message!(::LoggingAction, ::Algorithm, ::Problem, ::State; kwargs...)

# Concrete LoggingActions
# -----------------------
"""
    LogGroup(actions::Vector{<:LoggingAction})

Concrete [`LoggingAction`](@ref) that can be used to sequentially perform each of the `actions`.
"""
struct LogGroup{A <: LoggingAction} <: LoggingAction
    actions::Vector{A}
end

function handle_message!(
        action::LogGroup, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    for child in action.actions
        handle_message!(child, algorithm, problem, state; kwargs...)
    end
    return nothing
end

"""
    CallbackAction(callback)

Concrete [`LoggingAction`](@ref) that handles a logging event through an arbitrary callback function.
The callback function must have the following signature:
```julia
callback(algorithm, problem, state; kwargs...) = ...
```
Here `args...` and `kwargs...` are optional and can be filled out with context-specific information.
"""
struct CallbackAction{F} <: LoggingAction
    callback::F
end

function handle_message!(
        action::CallbackAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    action.callback(algorithm, problem, state; kwargs...)
    return nothing
end

struct IfAction{F, A <: LoggingAction} <: LoggingAction
    predicate::F
    action::A
end

function handle_message!(
        action::IfAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    return action.predicate(problem, algorithm, state; kwargs...) ?
        handle_message(action.action, problem, algorithm, state; kwargs...) :
        nothing
end

# Algorithm Logger
# ----------------
"""
    AlgorithmLogger(context => action, ...)

Logging transformer that handles the logic of dispatching logging events to logging actions.
By default, the following events trigger a logging action with the given `context`:

|  context  |              event                  |
| --------- | ----------------------------------- |
| :Start    | The solver will start.              |
| :Init     | The solver has been initialized.    |
| :PreStep  | The solver is about to take a step. |
| :PostStep | The solver has taken a step.        |
| :Stop     | The solver has finished.            |

Specific algorithms can associate other events with other contexts.

See also the scoped value [`AlgorithmsInterface.algorithm_logger`](@ref).
"""
struct AlgorithmLogger
    actions::Dict{Symbol, LogAction}
end
AlgorithmLogger(args...) = AlgorithmLogger(Dict{Symbol, LogAction}(args...))

"""
    const LOGGING_ENABLED = Ref(true)

Global toggle for enabling and disabling all logging features.
"""
const LOGGING_ENABLED = Ref(true)

"""
    const algorithm_logger = ScopedValue(AlgorithmLogger())

Scoped value for handling the logging events of arbitrary algorithms.
"""
const ALGORITHM_LOGGER = ScopedValue(AlgorithmLogger())

# @inline here to enable the cheap global check
@inline function log!(problem::Problem, algorithm::Algorithm, state::State, context::Symbol; kwargs...)
    if LOGGING_ENABLED[]
        logger::AlgorithmLogger = ALGORITHM_LOGGER[]
        handle_message(logger, problem, algorithm, state, context; kwargs...)
    end
    return nothing
end

# @noinline to keep the algorithm function bodies small
@noinline function handle_message(
        alglogger::AlgorithmLogger, problem::Problem, algorithm::Algorithm, state::State, context::Symbol;
        kwargs...
    )
    action::LoggingAction = @something(get(alglogger.actions, context, nothing), return nothing)
    try
        handle_message!(action, problem, algorithm, state, args...; kwargs...)
    catch err
        bt = catch_backtrace()
        @error "Error during the handling of a logging action" action exception = (err, bt)
    end
    return nothing
end
