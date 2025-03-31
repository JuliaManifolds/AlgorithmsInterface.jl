@doc """
    Algorithm

An abstract type to represent an algorithm.

A concrete algorithm contains all static parameters that characterise the algorithms.
Together with a [`Problem`](@ref) an `Algorithm` subtype should be able to initialize
or reset a [`State`](@ref).

## Usual fields

Usually this should include the following. If you use this naming scheme, default functions
e.g. as accessors

* `stopping_criterion` a [`StoppingCriterion`](@ref)

## Methods

The following methods should be implemented for an [`Algorithm`](@ref)

* [`get_stopping_criterion`](@ref) to return the algorithms stopping criterion.

## Example

For a [gradient descent](https://en.wikipedia.org/wiki/Gradient_descent) algorithm
the algorithm would specify which step size selection to use.
"""
abstract type Algorithm end

"""
    get_stopping_criterion(algorithm::Algorithm)

Return the [`StoppingCriterion`](@ref) of the [`Algorithm`](@ref).

The default assumes that the criterion is stored in `algorithm.stopping_criterion`.
"""
get_stopping_criterion(algorithm::Algorithm) = algorithm.stopping_criterion
