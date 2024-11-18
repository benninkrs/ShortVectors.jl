module ShortVectors

export VarNTuple, ShortVector
import Base: length, size, axes, iterate, getindex, show



"""
   static_iter_state(f, s0, Val(n))
Computes a stateful iteration statically (by manually unrolling).  Similar to `static_iter`,
but for cases in which the iteration state is distinct from the value to be returned.
Equivalent to:
   (_, s1) = f(1, s0)
   (_, s2) = f(2, s1)
   ...
   (v, sn) = f(n, s(n-1))
   return v
"""

@inline function static_iter_state(g, ::Val{N}) where N
	@assert N::Integer > 0
	if @generated
	   quote
		  (value_1, state_0) = iterate(g)
		  Base.Cartesian.@nexprs $N i -> (value_{i}, state_{i}) = iterate(g, state_{i-1})
		  return $(Symbol(:value_, N))
	   end
	else
	   (value, state) = iterate(g)
	   for _ in 2:N
		  (value, state) = iterate(g, state)
	   end
	   return value
	end
 end
 

# """
# 	tuple_iter(iter, Val(n))
# Construct a tuple from an iterable object.
# """
# function tuple_iter(iter, ::Val{n}) where {n}
# 	# wrapper function that can be called n times but stops iterating after i iterations


# 	f = static_iter_state((j,s) -> j,s
# 		(j < i) ? iterfun(j,s) : (iterfun(i,s)[1], s), s0, Val(n)) do    # slower if s is type unstable
# 	 end

# 	f = i -> static_iter_state(s0, Val(n)) do j,s
# 		  (j < i) ? iterfun(j,s) : (iterfun(i,s)[1], s)   # slower if s is type unstable
# 	   end
# 	ntuple(f, Val(n))
#  end
 



# Variable-length NTuple
"""
	VarNTuple{N,T}

Variable-length `NTuple` with fixed memory layout.
Stores up to `N` elements of type `T`.
"""
struct VarNTuple{N,T}
	tup::NTuple{N,T}
	len::Int

	@inline function VarNTuple{N,T}(data::NTuple{N,T},len) where {N,T}
		len <= N || throw(ArgumentError("Specified length ($len) exceeds specificed capacity ($N)"))
		new{N,T}(data,len)
	end

	@inline function VarNTuple{N,T}(a) where {N,T}
		len = length(a)
		(len <= N) || throw(ArgumentError("Input length ($len) exceeds specificed capacity ($N)"))
		pad_a = @inbounds i -> i<=len ? a[i] : zero(eltype(a))
		data = ntuple(pad_a, Val(N))
		new{N,T}(data,len)
	end
end

@inline VarNTuple{N}(a) where {N} = VarNTuple{N, eltype(a)}(a)

@inline length(t::VarNTuple) = t.len
@inline size(t::VarNTuple) = (t.len,)
@inline axes(t::VarNTuple) = Base.OneTo(length(t))

@inline iterate(t::VarNTuple) = (1,2)
@inline iterate(t::VarNTuple, i) = (i,i+1)


@inline function getindex(t::VarNTuple, i)
	# @boundscheck (1 <= i <= length(t)) || Base.throw_boundserror(t, i)
	@boundscheck checkbounds(t.tup, i)
	@inbounds t.tup[i]
end

show(io::IO, t::VarNTuple) = show(io, t.tup)
 



"""
	ShortVector{N,T}

Immutable vector that is stored locally if it has length ≤ N, otherwise is stored on the heap.
This provides significantly improved performance when a small capacity `N` is sufficient
for most instances, yet allows for larger instances when the need arises. 
"""
struct ShortVector{N, T}
	data::Union{VarNTuple{N, T}, Vector{T}}
	@inline function ShortVector{N,T}(a) where {N,T}
		if length(a) <= N
			# new{N,T}(VarNTuple{N,T}(a))

			# Doing the tuple-generation here (instead of in VarNTuple) avoids allocation for range/generator inputs
			pad_a = @inbounds i -> i<=length(a) ? a[i] : zero(eltype(a))
			t = ntuple(pad_a, Val(N))
			new{N,T}(VarNTuple{N,T}(t,N))
		else
			new{N,T}(collect(a))
		end
	end
end

ShortVector{N}(a) where {N} = ShortVector{N, eltype(a)}(a)
 
length(v::ShortVector) = length(v.data)
size(v::ShortVector) = (v.len,)
axes(v::ShortVector) = Base.OneTo(length(v))


@inline function getindex(v::ShortVector, i)
	@boundscheck (1 <= i <= length(v)) || Base.throw_boundserror(v, i)
	@inbounds v.data[i]
end


function show(io::IO, v::ShortVector)
	Base.show_delim_array(io, v.data, '[', ',', "]ˢᵛ", false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟦', ',', '⟧', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟨', ',', '⟩', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⌈', ',', '⌋', false, 1, length(v))
end

end # module ShortVectors
