"""
    log!(problem::Problem, algorithm::Algorithm, state::State; context::Symbol) -> nothing

Generate a log record for the given `(problem, algorithm, state)`, using the logging action associated to `context`.
By default, the following events trigger a logging action with the given `context`:

| context   | event                                 |
| --------- | ------------------------------------- |
| :Start    | The solver has been initialized.      |
| :PreStep  | The solver is about to take a step.   |
| :PostStep | The solver has taken a step.          |
| :Stop     | The solver has finished.              |

Specific algorithms can associate other events with other contexts.

See also [`register_action!`](@ref) to associate custom actions with these contexts.
"""
function log!(problem::Problem, algorithm::Algorithm, state::State; context)::Nothing
    action = @something(logging_action(problem, algorithm, state, context), return nothing)
    # TODO: filter out `nothing` logdata
    @logmsg(
        loglevel(action), logdata!(action, problem, algorithm, state),
        _id = logid(action), _group = loggroup(algorithm)
    )
    return nothing
end

"""
    logging_action(problem::Problem, algorithm::Algorithm, state::State, context::Symbol)
        -> Union{Nothing,LoggingAction}

Obtain the registered logging action associated to an event identified by `context`.
The default implementation assumes a dictionary-like object `state.logging_action`, which holds
the different registered actions.
"""
function logging_action(::Problem, ::Algorithm, state::State, context::Symbol)
    return get(state.logging_actions, context, nothing)
end

@doc """
    loggroup(algorithm::Algorithm) -> Symbol
    loggroup(::Type{<:Algorithm}) -> Symbol

Generate a group id to attach to all log records for a given algorithm.
""" loggroup

loggroup(algorithm::Algorithm) = loggroup(typeof(algorithm))
loggroup(Alg::Type{<:Algorithm}) = Base.nameof(Alg)

# Sources
# -------
"""
    LoggingAction

Abstract supertype for defining an action that generates a log record.

## Methods
Any concrete subtype should at least implement the following method:
- [`logdata!(action, problem, algorithm, state)`](@ref logdata!) : generate the data for the log record.

Addionally, the following methods can be specialized to alter the default behavior:
- [`loglevel(action) = Logging.Info`](@ref loglevel) : specify the logging level of the generated record.
- [`logid(action) = objectid(action)`](@ref logid) : specify a unique identifier to associate with the record.
"""
abstract type LoggingAction end

logdata!(::LoggingAction, ::Problem, ::Algorithm, ::State) = missing
loglevel(::LoggingAction) = Logging.Info
logid(action::LoggingAction) = objectid(action)

struct LogCallback{F} <: LoggingAction
    f::F
end

logdata!(action::LogCallback, problem, algorithm, state) =
    action.f(problem, algorithm, state)

struct LogGroup{A <: LoggingAction} <: LoggingAction
    actions::Vector{A}
end

loglevel(alg::LogGroup) = maximum(loglevel, alg.actions)

logdata!(action::LogGroup, problem, algorithm, state) = map(action.actions) do action
    return logdata!(action, problem, algorithm, state)
end

struct LogLvl{F, A <: LoggingAction} <: LoggingAction
    action::A
    lvl::LogLevel
end

loglevel(alg::LogLvl) = alg.lvl

struct LogIf{F, A <: LoggingAction} <: LoggingAction
    predicate::F
    action::A
end

# first cheap check through the level
loglevel(alg::LogIf) = loglevel(alg.action)

# second check through the predicate
logdata!(action::LogIf, problem::Problem, algorithm::Algorithm, state::State) =
    action.predicate(problem, algorithm, state) ? logdata!(action.action, problem, algorithm, state) : nothing

# Sinks
# -----
struct StringFormat{F <: PrintF.Format}
    format::F
end
function (formatter::StringFormat)(io::IO, lvl, msg, _module, group, id, file = nothing, line = nothing; indent::Integer = 0, kwargs...)
    iob = IOBuffer()
    return ioc = IOContext(iob, io)

end

struct FormatterGroup{K, V}
    rules::Dict{K, V}
end

function (formatter::AlgorithmFormatter)(io::IO, log)
    rule = get(formatter.rules, log.id, nothing)
    isnothing(rule) ? println(io, log) :
        rule(io, log.level, log.message, log._module, log.group, log.id, log.file, log.line; log.kwargs...)
    return nothing
end
