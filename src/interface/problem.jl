"""
    Problem

An abstract type to represent a problem to be solved with all its static properties, that do
not change during an algorithm run.

## Example

For a [gradient descent](https://en.wikipedia.org/wiki/Gradient_descent) algorithm the problem consists of

* a `cost` function ``f: C → ℝ``
* a gradient function ``$(raw"\operatorname{grad}")f``

The problem then could that these are given in four different forms

* a function `c = cost(x)` and a gradient `d = gradient(x)`
* a function `c = cost(x)` and an in-place gradient `gradient!(d,x)`
* a combined cost-grad function `(c,d) = costgrad(x)`
* a combined cost-grad function `(c, d) = costgrad!(d, x)` that computes the gradient in-place.
"""
abstract type Problem end
