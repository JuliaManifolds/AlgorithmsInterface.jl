@doc """
    Algorithm

An abstract type to represent an algorithm.

A concrete algorithm contains all static parameters that characterise the algorithms.
Together with a [`Problem`](@ref) an `Algorithm` subtype should be able to initialize
or reset a [`State`](@ref).

## Properties

Algorithms can contain any number of properties that are needed to define the algorithm,
but should additionally contain the following properties to interact with the stopping criteria.

* `stopping_criterion::StoppingCriterion`

## Example

For a [gradient descent](https://en.wikipedia.org/wiki/Gradient_descent) algorithm
the algorithm would specify which step size selection to use.
"""
abstract type Algorithm end
