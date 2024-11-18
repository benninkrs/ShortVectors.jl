module ShortVectors

export VarNTuple, ShortVector
import Base: length, size, axes, iterate, getindex, iterate, show, display



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

@inline iterate(t::VarNTuple) = (length(t) > 0) ? (t[1],2) : nothing
@inline iterate(t::VarNTuple, i) = (i <= length(t)) ? (t[i],i+1) : nothing


@inline function getindex(t::VarNTuple, i)
	# @boundscheck (1 <= i <= length(t)) || Base.throw_boundserror(t, i)
	@boundscheck 1 <= i <= length(t) || throw(BoundsError(t, i))
	@inbounds t.tup[i]
end


display(t::VarNTuple) = show(t)

function show(io::IO, t::VarNTuple) 
	Base.show_delim_array(io, t.tup, '(', ',', ")", true, 1, t.len)
end
 



"""
	ShortVector{N,T}

Immutable vector that is stored locally if it has length ≤ N, otherwise is stored on the heap.
This provides significantly improved performance when a small capacity `N` is sufficient
for most instances, yet allows for larger instances when the need arises. 
"""
struct ShortVector{N, T} <: DenseVector{T}
	data::Union{VarNTuple{N, T}, Vector{T}}
	@inline function ShortVector{N,T}(a) where {N,T}
		if length(a) <= N
			# new{N,T}(VarNTuple{N,T}(a))
			# Doing the tuple-generation here (instead of in VarNTuple) avoids allocation for range/generator inputs
			pad_a = @inbounds i -> i<=length(a) ? a[i] : zero(eltype(a))
			t = ntuple(pad_a, Val(N))
			new{N,T}(VarNTuple{N,T}(t,length(a)))
		else
			new{N,T}(collect(a))
		end
	end
end

ShortVector{N}(a) where {N} = ShortVector{N, eltype(a)}(a)
 
length(v::ShortVector) = length(v.data)
size(v::ShortVector) = (v.len,)
axes(v::ShortVector) = Base.OneTo(length(v))

@inline iterate(v::ShortVector, args...) = iterate(v.data, args...)

@inline function getindex(v::ShortVector, i)
	@boundscheck (1 <= i <= length(v)) || Base.throw_boundserror(v, i)
	@inbounds v.data[i]
end

display(v::ShortVector) = show(v)

function show(io::IO, v::ShortVector)
	Base.show_delim_array(io, v.data, '[', ',', "]ˢᵛ", false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟦', ',', '⟧', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⟨', ',', '⟩', false, 1, length(v))
	# Base.show_delim_array(stdout, v.data, '⌈', ',', '⌋', false, 1, length(v))
end

end # module ShortVectors
