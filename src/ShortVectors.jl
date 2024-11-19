module ShortVectors

export VarNTuple, ShortVector
import Base: length, size, axes, iterate, getindex, iterate, show, display, convert



@inline function _padded_tuple(a, len, ::Type{T}, ::Val{N}; fillval = nothing) where {T,N}
	if len == 0
		# if the fillval (default or provided) is invalid, try zero(T)
		(fillval isa T) || (fillval = zero(T))
		ntuple(i->fillval, Val(N))
		# ntuple(i->zero(T), Val(N))
	else
		# TODO: make this robust to non 1-based indexing
		ntuple((@inbounds i -> convert(T, a[min(i,len)])), Val(N))
	end
end	


# Variable-length NTuple
"""
	VarNTuple{N,T}

Variable-length `NTuple` with fixed memory layout.  Stores up to `N` elements of type `T`.

	VarNTuple{N,T}(x; fillval = zero(T))
	VarNTuple{N}(x; fillval = zero(T))

Construct a VarNTuple from indexable collection `x`.  If `T` is omitted, it is taken to be `eltype(x)`.
`fillval` is a dummy instance of type `T`, and is only needed in the case `x` is empty and `zero(T)` is undefined.
"""
struct VarNTuple{N,T}
	tup::NTuple{N,T}
	len::Int

	@inline function VarNTuple{N,T}(data::NTuple{N,T},len) where {N,T}
		len <= N || throw(ArgumentError("Specified length ($len) exceeds specificed capacity ($N)"))
		new{N,T}(data,len)
	end

	@inline function VarNTuple{N,T}(a; fillval = nothing) where {N,T}
		len = length(a)
		(len <= N) || throw(ArgumentError("Input length ($len) exceeds specificed capacity ($N)"))
		new{N,T}(_padded_tuple(a, len, T, Val(N)))
	end
end


# Infer type from collection
# @inline VarNTuple{N}(a; kw...) where {N} = VarNTuple{N, eltype(a)}(a; kw...)
@inline function VarNTuple{N}(a; kw...) where {N} 
	T = eltype(a)
	if T === Union{}	# A Tuple of Union{} cannot be instantiated
		T = Any
	end
	return VarNTuple{N, T}(a; kw...)
end


@inline length(t::VarNTuple) = t.len
@inline size(t::VarNTuple) = (t.len,)
@inline axes(t::VarNTuple) = Base.OneTo(length(t))

@inline iterate(t::VarNTuple) = (length(t) > 0) ? (t[1],2) : nothing
@inline iterate(t::VarNTuple, i) = (i <= length(t)) ? (t[i],i+1) : nothing


@inline function getindex(t::VarNTuple, I)
	@boundscheck all(1<=i<=length(t) for i in I) || throw(BoundsError(t, I))
	@inbounds t.tup[I]
end

display(t::VarNTuple) = show(t)

function show(io::IO, t::VarNTuple)
	Base.show_delim_array(io, t.tup[1:t.len], '(', ',', ')', true)
end
 


"""
	ShortVector{N,T}

Immutable vector that is stored locally if it has length ≤ N, otherwise is stored on the heap.
This provides significantly improved performance when a small capacity `N` is sufficient
for most instances, yet allows for larger instances when the need arises. 
"""
struct ShortVector{N, T} <: DenseVector{T}
	data::Union{VarNTuple{N, T}, Vector{T}}
	@inline function ShortVector{N,T}(a; fillval = nothing) where {N,T}
		len = length(a)
		if len <= N
			# new{N,T}(VarNTuple{N,T}(a))
			# Creating the padded tuple here is inexplicable faster than doing it in VarNTuple
			t = _padded_tuple(a, len, T, Val(N); fillval)
			new{N,T}(VarNTuple{N,T}(t,len))
		else
			new{N,T}(collect(a))
		end
	end
end

# @inline ShortVector{N}(a) where {N} = ShortVector{N, eltype(a)}(a)
@inline function ShortVector{N}(a; kw...) where {N}
	T = eltype(a)
	if T === Union{}	# A Tuple of Union{} cannot be instantiated
		T = Any
	end
	return ShortVector{N, T}(a; kw...)
end

convert(::Type{ShortVector{N}}, a) where {N} = ShortVector{N}(a)
convert(::Type{ShortVector{N,T}}, a) where {N,T} = ShortVector{N,T}(a)

 
length(v::ShortVector) = length(v.data)
size(v::ShortVector) = (v.len,)
axes(v::ShortVector) = Base.OneTo(length(v))

@inline iterate(v::ShortVector, args...) = iterate(v.data, args...)

@inline getindex(v::ShortVector, i::Integer) = v.data[i]
@inline getindex(v::ShortVector{N,T}, I) where {N,T} = ShortVector{N,T}(v.data[I])


display(v::ShortVector) = show(v)

function show(io::IO, v::ShortVector)
	Base.show_delim_array(io, v.data, '[', ',', "]ˢᵛ", false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟦', ',', '⟧', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟨', ',', '⟩', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⌈', ',', '⌋', false, 1, length(v))
end

end # module ShortVectors
