# ShortVectors.jl

This package provides the type `ShortVector`, which stores short vectors locally (i.e. on the stack)
and reverts to heap storage for longer vectors.  This can result in significant performance
gains when working with lots of short vectors, while retaining the flexbility to accommodate
vectors of any length if necessary. This package is inspired by Rust's [smallvec](https://docs.rs/smallvec/latest/smallvec/)
type and a related /[Julia Discourse discussion.](https://discourse.julialang.org/t/small-vectors/97121/3).

This is currently an *experimental* package: only the most basic functionality is provided, and little effort (so far) has been made to test and improve performance.
This package may eventually merge with similar efforts such as [SmallCollections.jl](https://github.com/matthias314/SmallCollections.jl) and/or [ImmutableVectors.jl](https://github.com/favba/ImmutableVectors.jl), which (as of 11/15/2024) do not allow for vectors longer than some chosen upper bound.

## Usage

```
struct ShortVector{N,T} <: DenseVector{T,1}
```
Immutable vector with local storage for up to `N` elements of type `T`.  If there are more
than `N` elements they are stored on the heap.  For best performance `N` should be large enough to accommodate the majority of likely vectors, but smaller than the size at which tuples yield poor performance (say, 10). 


```
> using ShortVectors
> ShortVector{4,Int64}(10:10:30)
[10, 20, 30]ˢᵛ				# stored locally

> ShortVector{4,Int64}(10:10:50)
[10, 20, 30, 40, 50]ˢᵛ		# stored on the heap
```

## Under the Hood

`ShortVector` is wrapper for what is essentially a `Union{NTuple{N,T}, Vector{T}}`.
