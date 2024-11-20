module ShortVectors

export VarNTuple, ShortVector
import Base: length, size, axes, iterate, getindex, eachindex, iterate, show, display, convert



# Variable-length NTuple
"""
	VarNTuple{N,T}

Variable-length `NTuple` with fixed memory layout.  Stores up to `N` elements of type `T`.

	VarNTuple{N,T}(x)
	VarNTuple{N}(x)
	VarNTuple{N,T}(x)

Construct a VarNTuple from indexable collection `x`.  If `T` is omitted, it is taken to be `eltype(x)`.
However, this will cause an error if `zero(eltype(x))` is undefined. 
"""
struct VarNTuple{N,T}
	tup::NTuple{N,T}
	len::Int

	@inline function VarNTuple{N,T}(data::NTuple{N,T}, len::Int) where {N,T}
		len <= N || throw(ArgumentError("Specified length ($len) exceeds specificed capacity ($N)"))
		new{N,T}(data,len)
	end

	@inline function VarNTuple{N,T}(a; fillval = zero(T)) where {N,T}
		len = length(a)
		(len <= N) || throw(ArgumentError("Input length ($len) exceeds specificed capacity ($N)"))
		# The ternery is faster than using min(i,len).
		# Using @inbounds doesn't seem to make a difference
		t = ntuple(i -> (i<=len) ? a[i] : fillval, Val(N))
		new{N,T}(t, len)
	end
end


# Infer type from collection
@inline VarNTuple{N}(a) where {N} = VarNTuple{N, eltype(a)}(a)


@inline length(t::VarNTuple) = t.len
@inline size(t::VarNTuple) = (t.len,)
@inline axes(t::VarNTuple) = Base.OneTo(length(t))

eachindex(t::VarNTuple) = Base.OneTo(t.len)

@inline iterate(t::VarNTuple) = (length(t) > 0) ? (t[1],2) : nothing
@inline iterate(t::VarNTuple, i) = (i <= length(t)) ? (t[i],i+1) : nothing


@inline function getindex(t::VarNTuple, I)
	@boundscheck all(1<=i<=length(t) for i in I) || throw(BoundsError(t, I))
	t.tup[I]	# for some reason @inbounds makes this much slower
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
	# There is some indication this is not inlined, which may be responsible for less-than-hoped performance.
	#	Base.allocatedinline(Union{VarNTuple{4,Int}, Vector{Int}}) == false
	#	Base.uniontype_layout(Union{VarNTuple{4,Int}, Vector{Int}}) == (false, 40, 8)
	# But it is not clear whether the 'false' result of these methods simply reflects that the vector data is not inline.
	data::Union{VarNTuple{N, T}, Vector{T}}

	@inline function ShortVector{N,T}(a; fillval = zero(T)) where {N,T}
		@assert eltype(a) == T
		len = length(a)
		if len <= N
			# new{N,T}(VarNTuple{N,T}(a))
			# Creating the padded tuple here is inexplicable faster than doing it in VarNTuple
			# t = ntuple(i -> (i<=len) ? convert(T, a[i]) : fillval, Val(N))
			t = ntuple(i -> (i<=len) ? a[i] : fillval, Val(N))
			new{N,T}(VarNTuple{N,T}(t,len))
		else
			new{N,T}(collect(a))
		end
	end
end


# @inline ShortVector{N}(a) where {N} = ShortVector{N, eltype(a)}(a)
@inline ShortVector{N}(a) where {N} = ShortVector{N, eltype(a)}(a)

convert(::Type{ShortVector{N}}, a) where {N} = ShortVector{N}(a)
convert(::Type{ShortVector{N,T}}, a) where {N,T} = ShortVector{N,T}(a)

 
length(v::ShortVector) = length(v.data)
size(v::ShortVector) = (v.len,)
axes(v::ShortVector) = Base.OneTo(length(v))

@inline iterate(v::ShortVector, args...) = iterate(v.data, args...)

@inline getindex(v::ShortVector, i::Integer) = v.data[i]
@inline getindex(v::ShortVector{N,T}, I) where {N,T} = ShortVector{N,T}(v.data[I])


display(v::ShortVector) = show(v)

show(io::IO, ::MIME"text/plain", v::ShortVector) = show(io, v)

function show(io::IO, v::ShortVector)
	Base.show_delim_array(io, v.data, '[', ',', "]ˢᵛ", false, 1, length(v))
end

end # module ShortVectors
