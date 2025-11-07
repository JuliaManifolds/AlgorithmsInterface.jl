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
""" handle_message!(::LoggingAction, ::Problem, ::Algorithm, ::State; kwargs...)

# Concrete LoggingActions
# -----------------------
"""
    GroupAction(actions::LoggingAction...)
    GroupAction(actions::Vector{<:LoggingAction})

Concrete [`LoggingAction`](@ref) that can be used to sequentially perform each of the `actions`.
"""
struct GroupAction{A <: LoggingAction} <: LoggingAction
    actions::Vector{A}
end
GroupAction(actions::LoggingAction...) = GroupAction(collect(LoggingAction, actions))

function handle_message!(
        action::GroupAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    for child in action.actions
        handle_message!(child, problem, algorithm, state; kwargs...)
    end
    return nothing
end

"""
    CallbackAction(callback)

Concrete [`LoggingAction`](@ref) that handles a logging event through an arbitrary callback function.
The callback function must have the following signature:
```julia
callback(problem, algorithm, state; kwargs...) = ...
```
Here `kwargs...` are optional and can be filled out with context-specific information.
"""
struct CallbackAction{F} <: LoggingAction
    callback::F
end

function handle_message!(
        action::CallbackAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    action.callback(problem, algorithm, state; kwargs...)
    return nothing
end

"""
    IfAction(predicate, action)

Concrete [`LoggingAction`](@ref) that wraps another action and hides it behind a clause, only
emitting logging events whenever the `predicate` evaluates to true. The `predicate` must have
the signature:
```julia
predicate(problem, algorithm, state; kwargs...)::Bool
```
"""
struct IfAction{F, A <: LoggingAction} <: LoggingAction
    predicate::F
    action::A
end

function handle_message!(
        action::IfAction, problem::Problem, algorithm::Algorithm, state::State; kwargs...
    )
    return action.predicate(problem, algorithm, state; kwargs...) ?
        handle_message!(action.action, problem, algorithm, state; kwargs...) :
        nothing
end

# Algorithm Logger
# ----------------
"""
    AlgorithmLogger(context => action, ...) -> logger

Logging transformer that handles the logic of dispatching logging events to logging actions.
This is implemented through `logger[context]`.

See also the scoped value [`AlgorithmsInterface.algorithm_logger`](@ref).
"""
struct AlgorithmLogger
    actions::Dict{Symbol, LoggingAction}
end
AlgorithmLogger(args::Pair...) = AlgorithmLogger(Dict{Symbol, LoggingAction}(args...))

Base.getindex(logger::AlgorithmLogger, context::Symbol) = get(logger.actions, context, nothing)

"""
    with_algorithmlogger(f, (context => action)::Pair{Symbol, LoggingAction}...)
    with_algorithmlogger((context => action)::Pair{Symbol, LoggingAction}...) do
        # insert arbitrary code here
    end

Run the given zero-argument function `f()` while mapping events of given `context`s to their respective `action`s.
By default, the following events trigger a logging action with the given `context`:

|  context  |              event                  |
| --------- | ----------------------------------- |
| :Start    | The solver will start.              |
| :PreStep  | The solver is about to take a step. |
| :PostStep | The solver has taken a step.        |
| :Stop     | The solver has finished.            |

However, further events and actions can be emitted through the [`emit_message`](@ref) interface.

See also the scoped value [`AlgorithmsInterface.algorithm_logger`](@ref).
"""
@inline function with_algorithmlogger(f, args...)
    logger = AlgorithmLogger(args...)
    return with(f, ALGORITHM_LOGGER => logger)
end

@doc """
    get_global_logging_state()
    set_global_logging_state!(state::Bool) -> previous_state

Retrieve or set the value to globally enable or disable the handling of logging events.
""" get_global_logging_state, set_global_logging_state!

const LOGGING_ENABLED = Ref(true)

get_global_logging_state() = LOGGING_ENABLED[]
function set_global_logging_state!(state::Bool)
    previous = LOGGING_ENABLED[]
    LOGGING_ENABLED[] = state
    return previous
end

@doc """
    algorithm_logger()::Union{AlgorithmLogger, Nothing}

Retrieve the current logger that is responsible for handling logging events.
The current logger is determined by a `ScopedValue`.
Whenever `nothing` is returned, no logging should happen.

See also [`set_global_logging_state!`](@ref) for globally toggling whether logging should happen.
""" algorithm_logger

const ALGORITHM_LOGGER = ScopedValue(AlgorithmLogger())

function algorithm_logger()
    LOGGING_ENABLED[] || return nothing
    logger = ALGORITHM_LOGGER[]
    isempty(logger.actions) && return nothing
    return logger
end

"""
    emit_message(problem::Problem, algorithm::Algorithm, state::State, context::Symbol; kwargs...) -> nothing
    emit_message(algorithm_logger, problem::Problem, algorithm::Algorithm, state::State, context::Symbol; kwargs...) -> nothing

Use the current or the provided algorithm logger to handle the logging event of the given `context`.
The first signature should be favored as it correctly handles accessing the `logger` and respecting global toggles for enabling and disabling the logging system.

The second signature should be used exclusively in (very) hot loops, where the overhead of [`AlgorithmsInterface.algorithm_logger()`](@ref) is too large.
In this case, you can manually extract the `algorithm_logger()` once outside of the hot loop.
"""
emit_message(problem::Problem, algorithm::Algorithm, state::State, context::Symbol; kwargs...) =
    emit_message(algorithm_logger(), problem, algorithm, state, context; kwargs...)
emit_message(::Nothing, problem::Problem, algorithm::Algorithm, state::State, context::Symbol; kwargs...) =
    nothing
function emit_message(
        logger::AlgorithmLogger, problem::Problem, algorithm::Algorithm, state::State, context::Symbol;
        kwargs...
    )
    @noinline; @nospecialize
    action::LoggingAction = @something(logger[context], return nothing)

    # Try-catch around logging to avoid stopping the algorithm when a logging action fails
    # but still emit an error message
    try
        handle_message!(action, problem, algorithm, state; kwargs...)
    catch err
        bt = catch_backtrace()
        @error "Error during the handling of a logging action" action exception = (err, bt)
    end
    return nothing
end
