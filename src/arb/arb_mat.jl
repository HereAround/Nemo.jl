###############################################################################
#
#   arb_mat.jl : Arb matrices over ArbFieldElem
#
###############################################################################

###############################################################################
#
#   Similar & zero
#
###############################################################################

function similar(::ArbMatrix, R::ArbField, r::Int, c::Int)
   z = ArbMatrix(r, c)
   z.base_ring = R
   return z
end

zero(m::ArbMatrix, R::ArbField, r::Int, c::Int) = similar(m, R, r, c)

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent_type(::Type{ArbMatrix}) = ArbMatSpace

elem_type(::Type{ArbMatSpace}) = ArbMatrix

base_ring(a::ArbMatSpace) = a.base_ring

base_ring(a::ArbMatrix) = a.base_ring

parent(x::ArbMatrix) = matrix_space(base_ring(x), nrows(x), ncols(x))

dense_matrix_type(::Type{ArbFieldElem}) = ArbMatrix

precision(x::ArbMatSpace) = precision(x.base_ring)

function check_parent(x::ArbMatrix, y::ArbMatrix, throw::Bool = true)
   fl = (nrows(x) != nrows(y) || ncols(x) != ncols(y) || base_ring(x) != base_ring(y))
   fl && throw && error("Incompatible matrices")
   return !fl
end

function getindex!(z::ArbFieldElem, x::ArbMatrix, r::Int, c::Int)
  GC.@preserve x begin
     v = ccall((:arb_mat_entry_ptr, libarb), Ptr{ArbFieldElem},
                 (Ref{ArbMatrix}, Int, Int), x, r - 1, c - 1)
     ccall((:arb_set, libarb), Nothing, (Ref{ArbFieldElem}, Ptr{ArbFieldElem}), z, v)
  end
  return z
end

@inline function getindex(x::ArbMatrix, r::Int, c::Int)
  @boundscheck Generic._checkbounds(x, r, c)

  z = base_ring(x)()
  GC.@preserve x begin
     v = ccall((:arb_mat_entry_ptr, libarb), Ptr{ArbFieldElem},
                 (Ref{ArbMatrix}, Int, Int), x, r - 1, c - 1)
     ccall((:arb_set, libarb), Nothing, (Ref{ArbFieldElem}, Ptr{ArbFieldElem}), z, v)
  end
  return z
end

for T in [Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, ArbFieldElem, AbstractString]
   @eval begin
      @inline function setindex!(x::ArbMatrix, y::$T, r::Int, c::Int)
         @boundscheck Generic._checkbounds(x, r, c)

         GC.@preserve x begin
            z = ccall((:arb_mat_entry_ptr, libarb), Ptr{ArbFieldElem},
                      (Ref{ArbMatrix}, Int, Int), x, r - 1, c - 1)
            Nemo._arb_set(z, y, precision(base_ring(x)))
         end
      end
   end
end

Base.@propagate_inbounds setindex!(x::ArbMatrix, y::Integer,
                                 r::Int, c::Int) =
         setindex!(x, ZZRingElem(y), r, c)

Base.@propagate_inbounds setindex!(x::ArbMatrix, y::Rational{T},
                                 r::Int, c::Int) where {T <: Integer} =
         setindex!(x, ZZRingElem(y), r, c)

zero(a::ArbMatSpace) = a()

function one(x::ArbMatSpace)
  z = x()
  ccall((:arb_mat_one, libarb), Nothing, (Ref{ArbMatrix}, ), z)
  return z
end

number_of_rows(a::ArbMatrix) = a.r

number_of_columns(a::ArbMatrix) = a.c

number_of_rows(a::ArbMatSpace) = a.nrows

number_of_columns(a::ArbMatSpace) = a.ncols

function deepcopy_internal(x::ArbMatrix, dict::IdDict)
  z = ArbMatrix(nrows(x), ncols(x))
  ccall((:arb_mat_set, libarb), Nothing, (Ref{ArbMatrix}, Ref{ArbMatrix}), z, x)
  z.base_ring = x.base_ring
  return z
end

################################################################################
#
#  Unary operations
#
################################################################################

function -(x::ArbMatrix)
  z = similar(x)
  ccall((:arb_mat_neg, libarb), Nothing, (Ref{ArbMatrix}, Ref{ArbMatrix}), z, x)
  return z
end

################################################################################
#
#  Transpose
#
################################################################################

function transpose(x::ArbMatrix)
  z = similar(x, ncols(x), nrows(x))
  ccall((:arb_mat_transpose, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}), z, x)
  return z
end

################################################################################
#
#  Binary operations
#
################################################################################

function +(x::ArbMatrix, y::ArbMatrix)
  check_parent(x, y)
  z = similar(x)
  ccall((:arb_mat_add, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, x, y, precision(parent(x)))
  return z
end

function -(x::ArbMatrix, y::ArbMatrix)
  check_parent(x, y)
  z = similar(x)
  ccall((:arb_mat_sub, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, x, y, precision(parent(x)))
  return z
end

function *(x::ArbMatrix, y::ArbMatrix)
  ncols(x) != nrows(y) && error("Matrices have wrong dimensions")
  z = similar(x, nrows(x), ncols(y))
  ccall((:arb_mat_mul, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

################################################################################
#
#   Ad hoc binary operators
#
################################################################################

function ^(x::ArbMatrix, y::UInt)
  nrows(x) != ncols(x) && error("Matrix must be square")
  z = similar(x)
  ccall((:arb_mat_pow_ui, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, UInt, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function *(x::ArbMatrix, y::Int)
  z = similar(x)
  ccall((:arb_mat_scalar_mul_si, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Int, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::Int, y::ArbMatrix) = y*x

*(x::ArbMatrix, y::QQFieldElem) = x*base_ring(x)(y)

*(x::QQFieldElem, y::ArbMatrix) = y*x

function *(x::ArbMatrix, y::ZZRingElem)
  z = similar(x)
  ccall((:arb_mat_scalar_mul_fmpz, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ZZRingElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::ZZRingElem, y::ArbMatrix) = y*x

function *(x::ArbMatrix, y::ArbFieldElem)
  z = similar(x)
  ccall((:arb_mat_scalar_mul_arb, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbFieldElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::ArbFieldElem, y::ArbMatrix) = y*x

for T in [Integer, ZZRingElem, QQFieldElem, ArbFieldElem]
   @eval begin
      function +(x::ArbMatrix, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] += y
         end
         return z
      end

      +(x::$T, y::ArbMatrix) = y + x

      function -(x::ArbMatrix, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] -= y
         end
         return z
      end

      function -(x::$T, y::ArbMatrix)
         z = -y
         for i = 1:min(nrows(y), ncols(y))
            z[i, i] += x
         end
         return z
      end
   end
end

function +(x::ArbMatrix, y::Rational{T}) where T <: Union{Int, BigInt}
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] += y
   end
   return z
end

+(x::Rational{T}, y::ArbMatrix) where T <: Union{Int, BigInt} = y + x

function -(x::ArbMatrix, y::Rational{T}) where T <: Union{Int, BigInt}
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] -= y
   end
   return z
end

function -(x::Rational{T}, y::ArbMatrix) where T <: Union{Int, BigInt}
   z = -y
   for i = 1:min(nrows(y), ncols(y))
      z[i, i] += x
   end
   return z
end

###############################################################################
#
#   Shifting
#
###############################################################################

function ldexp(x::ArbMatrix, y::Int)
  z = similar(x)
  ccall((:arb_mat_scalar_mul_2exp_si, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Int), z, x, y)
  return z
end

###############################################################################
#
#   Comparisons
#
###############################################################################

@doc raw"""
    isequal(x::ArbMatrix, y::ArbMatrix)

Return `true` if the matrices of balls $x$ and $y$ are precisely equal,
i.e. if all matrix entries have the same midpoints and radii.
"""
function isequal(x::ArbMatrix, y::ArbMatrix)
  r = ccall((:arb_mat_equal, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}), x, y)
  return Bool(r)
end

function ==(x::ArbMatrix, y::ArbMatrix)
  fl = check_parent(x, y, false)
  !fl && return false
  r = ccall((:arb_mat_eq, libarb), Cint, (Ref{ArbMatrix}, Ref{ArbMatrix}), x, y)
  return Bool(r)
end

function !=(x::ArbMatrix, y::ArbMatrix)
  r = ccall((:arb_mat_ne, libarb), Cint, (Ref{ArbMatrix}, Ref{ArbMatrix}), x, y)
  return Bool(r)
end

@doc raw"""
    overlaps(x::ArbMatrix, y::ArbMatrix)

Returns `true` if all entries of $x$ overlap with the corresponding entry of
$y$, otherwise return `false`.
"""
function overlaps(x::ArbMatrix, y::ArbMatrix)
  r = ccall((:arb_mat_overlaps, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}), x, y)
  return Bool(r)
end

@doc raw"""
    contains(x::ArbMatrix, y::ArbMatrix)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::ArbMatrix, y::ArbMatrix)
  r = ccall((:arb_mat_contains, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}), x, y)
  return Bool(r)
end

###############################################################################
#
#   Ad hoc comparisons
#
###############################################################################

@doc raw"""
    contains(x::ArbMatrix, y::ZZMatrix)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::ArbMatrix, y::ZZMatrix)
  r = ccall((:arb_mat_contains_fmpz_mat, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ZZMatrix}), x, y)
  return Bool(r)
end


@doc raw"""
    contains(x::ArbMatrix, y::QQMatrix)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::ArbMatrix, y::QQMatrix)
  r = ccall((:arb_mat_contains_fmpq_mat, libarb), Cint,
              (Ref{ArbMatrix}, Ref{QQMatrix}), x, y)
  return Bool(r)
end

==(x::ArbMatrix, y::Integer) = x == parent(x)(y)

==(x::Integer, y::ArbMatrix) = y == x

==(x::ArbMatrix, y::ZZRingElem) = x == parent(x)(y)

==(x::ZZRingElem, y::ArbMatrix) = y == x

==(x::ArbMatrix, y::ZZMatrix) = x == parent(x)(y)

==(x::ZZMatrix, y::ArbMatrix) = y == x

###############################################################################
#
#   Inversion
#
###############################################################################

@doc raw"""
    inv(x::ArbMatrix)

Given a  $n\times n$ matrix of type `ArbMatrix`, return an
$n\times n$ matrix $X$ such that $AX$ contains the
identity matrix. If $A$ cannot be inverted numerically an exception is raised.
"""
function inv(x::ArbMatrix)
  fl, z = is_invertible_with_inverse(x)
  fl && return z
  error("Matrix singular or cannot be inverted numerically")
end

function is_invertible_with_inverse(x::ArbMatrix)
  ncols(x) != nrows(x) && return false, x
  z = similar(x)
  r = ccall((:arb_mat_inv, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Int), z, x, precision(base_ring(x)))
  return Bool(r), z
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::ArbMatrix, y::ArbMatrix; check::Bool=true)
   ncols(x) != ncols(y) && error("Incompatible matrix dimensions")
   x*inv(y)
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

function divexact(x::ArbMatrix, y::Int; check::Bool=true)
  y == 0 && throw(DivideError())
  z = similar(x)
  ccall((:arb_mat_scalar_div_si, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Int, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function divexact(x::ArbMatrix, y::ZZRingElem; check::Bool=true)
  z = similar(x)
  ccall((:arb_mat_scalar_div_fmpz, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ZZRingElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function divexact(x::ArbMatrix, y::ArbFieldElem; check::Bool=true)
  z = similar(x)
  ccall((:arb_mat_scalar_div_arb, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbFieldElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

################################################################################
#
#  Characteristic polynomial
#
################################################################################

function charpoly(x::ArbPolyRing, y::ArbMatrix)
  base_ring(y) != base_ring(x) && error("Base rings must coincide")
  z = x()
  ccall((:arb_mat_charpoly, libarb), Nothing,
              (Ref{ArbPolyRingElem}, Ref{ArbMatrix}, Int), z, y, precision(base_ring(y)))
  return z
end

###############################################################################
#
#   Determinant
#
###############################################################################

function det(x::ArbMatrix)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = base_ring(x)()
  ccall((:arb_mat_det, libarb), Nothing,
              (Ref{ArbFieldElem}, Ref{ArbMatrix}, Int), z, x, precision(base_ring(x)))
  return z
end

################################################################################
#
#   Exponential function
#
################################################################################

function Base.exp(x::ArbMatrix)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = similar(x)
  ccall((:arb_mat_exp, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Int), z, x, precision(base_ring(x)))
  return z
end

###############################################################################
#
#   Linear solving
#
###############################################################################

function cholesky(x::ArbMatrix)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = similar(x, nrows(x), ncols(x))
  p = precision(base_ring(x))
  fl = ccall((:arb_mat_cho, libarb), Cint, (Ref{ArbMatrix}, Ref{ArbMatrix}, Int), z, x, p)
  fl == 0 && error("Matrix is not positive definite")
  return z
end

function lu!(P::Generic.Perm, x::ArbMatrix)
  parent(P).n != nrows(x) && error("Permutation does not match matrix")
  P.d .-= 1
  r = ccall((:arb_mat_lu, libarb), Cint,
              (Ptr{Int}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              P.d, x, x, precision(base_ring(x)))
  r == 0 && error("Could not find $(nrows(x)) invertible pivot elements")
  P.d .+= 1
  inv!(P)
  return nrows(x)
end

function _solve!(z::ArbMatrix, x::ArbMatrix, y::ArbMatrix)
  r = ccall((:arb_mat_solve, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, x, y, precision(base_ring(x)))
  r == 0 && error("Matrix cannot be inverted numerically")
  nothing
end

function _solve(x::ArbMatrix, y::ArbMatrix)
  ncols(x) != nrows(x) && error("First argument must be square")
  ncols(x) != nrows(y) && error("Matrix dimensions are wrong")
  z = similar(y)
  _solve!(z, x, y)
  return z
end

function _solve_lu_precomp!(z::ArbMatrix, P::Generic.Perm, LU::ArbMatrix, y::ArbMatrix)
  Q = inv(P)
  ccall((:arb_mat_solve_lu_precomp, libarb), Nothing,
              (Ref{ArbMatrix}, Ptr{Int}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, Q.d .- 1, LU, y, precision(base_ring(LU)))
  nothing
end

function _solve_lu_precomp(P::Generic.Perm, LU::ArbMatrix, y::ArbMatrix)
  ncols(LU) != nrows(y) && error("Matrix dimensions are wrong")
  z = similar(y)
  _solve_lu_precomp!(z, P, LU, y)
  return z
end

function _solve_cholesky_precomp!(z::ArbMatrix, cho::ArbMatrix, y::ArbMatrix)
  ccall((:arb_mat_solve_cho_precomp, libarb), Nothing,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              z, cho, y, precision(base_ring(cho)))
  nothing
end

function _solve_cholesky_precomp(cho::ArbMatrix, y::ArbMatrix)
  ncols(cho) != nrows(y) && error("Matrix dimensions are wrong")
  z = similar(y)
  _solve_cholesky_precomp!(z, cho, y)
  return z
end

function AbstractAlgebra.Solve._can_solve_internal_no_check(A::ArbMatrix, b::ArbMatrix, task::Symbol; side::Symbol = :left)
   nrows(A) != ncols(A) && error("Only implemented for square matrices")
   if side === :left
      fl, sol, K = AbstractAlgebra.Solve._can_solve_internal_no_check(transpose(A), transpose(b), task, side = :right)
      return fl, transpose(sol), transpose(K)
   end

   x = similar(A, ncols(A), ncols(b))
   fl = ccall((:arb_mat_solve, libarb), Cint,
              (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
              x, A, b, precision(base_ring(A)))
   fl == 0 && error("Matrix cannot be inverted numerically")
   if task === :only_check || task === :with_solution
      return true, x, zero(A, 0, 0)
   end
   # If we ended up here, then A is invertible, so the kernel is trivial
   return true, x, zero(A, ncols(A), 0)
end

################################################################################
#
#   Linear solving via context object
#
################################################################################

function solve_init(A::ArbMatrix)
   return AbstractAlgebra.Solve.SolveCtx{ArbFieldElem, ArbMatrix, ArbMatrix}(A)
end

function AbstractAlgebra.Solve._init_reduce(C::AbstractAlgebra.Solve.SolveCtx{ArbFieldElem})
   if isdefined(C, :red) && isdefined(C, :lu_perm)
      return nothing
   end

   nrows(C) != ncols(C) && error("Only implemented for square matrices")

   A = matrix(C)
   P = Generic.Perm(nrows(C))
   x = similar(A, nrows(A), ncols(A))
   P.d .-= 1
   fl = ccall((:arb_mat_lu, libarb), Cint,
               (Ptr{Int}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
               P.d, x, A, precision(base_ring(A)))
   fl == 0 && error("Could not find $(nrows(x)) invertible pivot elements")
   P.d .+= 1
   inv!(P)

   C.red = x
   C.lu_perm = P
   return nothing
end

function AbstractAlgebra.Solve._init_reduce_transpose(C::AbstractAlgebra.Solve.SolveCtx{ArbFieldElem})
   if isdefined(C, :red_transp) && isdefined(C, :lu_perm_transp)
      return nothing
   end

   nrows(C) != ncols(C) && error("Only implemented for square matrices")

   A = transpose(matrix(C))
   P = Generic.Perm(nrows(C))
   x = similar(A, nrows(A), ncols(A))
   P.d .-= 1
   fl = ccall((:arb_mat_lu, libarb), Cint,
               (Ptr{Int}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
               P.d, x, A, precision(base_ring(A)))
   fl == 0 && error("Could not find $(nrows(x)) invertible pivot elements")
   P.d .+= 1
   inv!(P)

   C.red_transp = x
   C.lu_perm_transp = P
   return nothing
end

function AbstractAlgebra.Solve._can_solve_internal_no_check(C::AbstractAlgebra.Solve.SolveCtx{ArbFieldElem}, b::ArbMatrix, task::Symbol; side::Symbol = :left)
   if side === :right
      LU = AbstractAlgebra.Solve.reduced_matrix(C)
      p = AbstractAlgebra.Solve.lu_permutation(C)
   else
      LU = AbstractAlgebra.Solve.reduced_matrix_of_transpose(C)
      p = AbstractAlgebra.Solve.lu_permutation_of_transpose(C)
      b = transpose(b)
   end

   x = similar(b, ncols(C), ncols(b))
   ccall((:arb_mat_solve_lu_precomp, libarb), Nothing,
         (Ref{ArbMatrix}, Ptr{Int}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
         x, inv(p).d .- 1, LU, b, precision(base_ring(LU)))

   if side === :left
     x = transpose(x)
   end

   if task === :only_check || task === :with_solution
      return true, x, zero(b, 0, 0)
   end
   # If we ended up here, then the matrix is invertible, so the kernel is trivial
   if side === :right
      return true, x, zero(b, ncols(C), 0)
   else
      return true, x, zero(b, 0, nrows(C))
   end
end

################################################################################
#
#   Row swapping
#
################################################################################

function swap_rows(x::ArbMatrix, i::Int, j::Int)
  Generic._checkbounds(nrows(x), i) || throw(BoundsError())
  Generic._checkbounds(nrows(x), j) || throw(BoundsError())
  z = deepcopy(x)
  swap_rows!(z, i, j)
  return z
end

function swap_rows!(x::ArbMatrix, i::Int, j::Int)
  ccall((:arb_mat_swap_rows, libarb), Nothing,
              (Ref{ArbMatrix}, Ptr{Nothing}, Int, Int),
              x, C_NULL, i - 1, j - 1)
end

################################################################################
#
#   Norm
#
################################################################################

@doc raw"""
    bound_inf_norm(x::ArbMatrix)

Returns a non-negative element $z$ of type `ArbFieldElem`, such that $z$ is an upper
bound for the infinity norm for every matrix in $x$
"""
function bound_inf_norm(x::ArbMatrix)
  z = ArbFieldElem()
  GC.@preserve x z begin
     t = ccall((:arb_rad_ptr, libarb), Ptr{mag_struct}, (Ref{ArbFieldElem}, ), z)
     ccall((:arb_mat_bound_inf_norm, libarb), Nothing,
                 (Ptr{mag_struct}, Ref{ArbMatrix}), t, x)
     s = ccall((:arb_mid_ptr, libarb), Ptr{arf_struct}, (Ref{ArbFieldElem}, ), z)
     ccall((:arf_set_mag, libarb), Nothing,
                 (Ptr{arf_struct}, Ptr{mag_struct}), s, t)
     ccall((:mag_zero, libarb), Nothing,
                 (Ptr{mag_struct},), t)
  end
  return base_ring(x)(z)
end

################################################################################
#
#   Unsafe functions
#
################################################################################

for (s,f) in (("add!","arb_mat_add"), ("mul!","arb_mat_mul"),
              ("sub!","arb_mat_sub"))
  @eval begin
    function ($(Symbol(s)))(z::ArbMatrix, x::ArbMatrix, y::ArbMatrix)
      ccall(($f, libarb), Nothing,
                  (Ref{ArbMatrix}, Ref{ArbMatrix}, Ref{ArbMatrix}, Int),
                  z, x, y, precision(base_ring(x)))
      return z
    end
  end
end

###############################################################################
#
#   Parent object call overloads
#
###############################################################################

function (x::ArbMatSpace)()
  z = ArbMatrix(nrows(x), ncols(x))
  z.base_ring = x.base_ring
  return z
end

function (x::ArbMatSpace)(y::ZZMatrix)
  (ncols(x) != ncols(y) || nrows(x) != nrows(y)) &&
      error("Dimensions are wrong")
  z = ArbMatrix(y, precision(x))
  z.base_ring = x.base_ring
  return z
end

function (x::ArbMatSpace)(y::AbstractMatrix{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, ArbFieldElem, AbstractString}}
  _check_dim(nrows(x), ncols(x), y)
  z = ArbMatrix(nrows(x), ncols(x), y, precision(x))
  z.base_ring = x.base_ring
  return z
end

function (x::ArbMatSpace)(y::AbstractVector{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, ArbFieldElem, AbstractString}}
  _check_dim(nrows(x), ncols(x), y)
  z = ArbMatrix(nrows(x), ncols(x), y, precision(x))
  z.base_ring = x.base_ring
  return z
end

function (x::ArbMatSpace)(y::Union{Int, UInt, ZZRingElem, QQFieldElem, Float64,
                          BigFloat, ArbFieldElem, AbstractString})
  z = x()
  for i in 1:nrows(z)
      for j = 1:ncols(z)
         if i != j
            z[i, j] = zero(base_ring(x))
         else
            z[i, j] = y
         end
      end
   end
   return z
end

###############################################################################
#
#   Matrix constructor
#
###############################################################################

function matrix(R::ArbField, arr::AbstractMatrix{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, ArbFieldElem, AbstractString}}
   z = ArbMatrix(size(arr, 1), size(arr, 2), arr, precision(R))
   z.base_ring = R
   return z
end

function matrix(R::ArbField, r::Int, c::Int, arr::AbstractVector{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, ArbFieldElem, AbstractString}}
   _check_dim(r, c, arr)
   z = ArbMatrix(r, c, arr, precision(R))
   z.base_ring = R
   return z
end

function matrix(R::ArbField, arr::AbstractMatrix{<: Integer})
   arr_fmpz = map(ZZRingElem, arr)
   return matrix(R, arr_fmpz)
end

function matrix(R::ArbField, r::Int, c::Int, arr::AbstractVector{<: Integer})
   arr_fmpz = map(ZZRingElem, arr)
   return matrix(R, r, c, arr_fmpz)
end

function matrix(R::ArbField, arr::AbstractMatrix{Rational{T}}) where {T <: Integer}
   arr_fmpz = map(QQFieldElem, arr)
   return matrix(R, arr_fmpz)
end

function matrix(R::ArbField, r::Int, c::Int, arr::AbstractVector{Rational{T}}) where {T <: Integer}
   arr_fmpz = map(QQFieldElem, arr)
   return matrix(R, r, c, arr_fmpz)
end

###############################################################################
#
#  Zero matrix
#
###############################################################################

function zero_matrix(R::ArbField, r::Int, c::Int)
   if r < 0 || c < 0
     error("dimensions must not be negative")
   end
   z = ArbMatrix(r, c)
   z.base_ring = R
   return z
end

###############################################################################
#
#  Identity matrix
#
###############################################################################

function identity_matrix(R::ArbField, n::Int)
   if n < 0
     error("dimension must not be negative")
   end
   z = ArbMatrix(n, n)
   ccall((:arb_mat_one, libarb), Nothing, (Ref{ArbMatrix}, ), z)
   z.base_ring = R
   return z
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{ArbMatrix}, ::Type{T}) where {T <: Integer} = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{Rational{T}}) where T <: Union{Int, BigInt} = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{ZZRingElem}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{QQFieldElem}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{ArbFieldElem}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{Float64}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{BigFloat}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{ZZMatrix}) = ArbMatrix

promote_rule(::Type{ArbMatrix}, ::Type{QQMatrix}) = ArbMatrix

###############################################################################
#
#   matrix_space constructor
#
###############################################################################

function matrix_space(R::ArbField, r::Int, c::Int; cached = true)
  # TODO/FIXME: `cached` is ignored and only exists for backwards compatibility
  (r <= 0 || c <= 0) && error("Dimensions must be positive")
  return ArbMatSpace(R, r, c)
end
