#= src/prange.jl

References:

  B. Engquist, L. Ying. A fast directional algorithm for high frequency
    acoustic scattering in two dimensions. Commun. Math. Sci. 7 (2): 327-345,
    2009.

  N. Halko, P.G. Martinsson, J.A. Tropp. Finding structure with randomness:
    Probabilistic algorithms for constructing approximate matrix
    decompositions. SIAM Rev. 53 (2): 217-288, 2011.
=#

for sfx in ("", "!")
  f = symbol("prange", sfx)
  g = symbol("pqrfact", sfx)
  @eval begin
    function $f{T}(
        trans::Symbol, A::AbstractMatOrLinOp{T}, opts::LRAOptions=LRAOptions(T);
        args...)
      prange_chktrans(trans)
      opts = isempty(args) ? opts : copy(opts; args...)
      opts = chkopts(A, opts)
      if trans == :b
        chksquare(A)
        ishermitian(A) && return $f(:n, A, opts)
        opts = copy(opts, pqrfact_retval="qr")
        if opts.sketch == :none
          Fr = pqrfact!(A', opts)
          Fc =       $g(A , opts)
        else
          Fr = sketchfact(:right, :c, A, opts)
          Fc = sketchfact(:right, :n, A, opts)
        end
        kr = Fr[:k]
        kc = Fc[:k]
        B = Array(T, size(A,1), kr+kc)
        B[:,   1:kr   ] = Fr[:Q]
        B[:,kr+1:kr+kc] = Fc[:Q]
        Rr = sub(Fr.R, 1:kr, 1:kr)
        Rc = sub(Fc.R, 1:kc, 1:kc)
        BLAS.trmm!('R', 'U', 'N', 'N', one(T), Rr, sub(B,:,   1:kr   ))
        BLAS.trmm!('R', 'U', 'N', 'N', one(T), Rc, sub(B,:,kr+1:kr+kc))
        opts.pqrfact_retval="q"
        return pqrfact_lapack!(B, opts)[:Q]
      else
        opts = copy(opts, pqrfact_retval="q")
        if opts.sketch == :none
          if trans == :n  Q =       $g(A , opts)[:Q]
          else            Q = pqrfact!(A', opts)[:Q]
          end
        elseif opts.sketch == :sub  Q = prange_sub(trans, A, opts)
        else                        Q = sketchfact(:right, trans, A, opts)[:Q]
        end
        Q
      end
    end
    $f(trans::Symbol, A, args...; kwargs...) =
      $f(trans, LinOp(A), args...; kwargs...)
    $f(A, args...; kwargs...) = $f(:n, A, args...; kwargs...)
  end
end

function prange_sub{T}(trans::Symbol, A::AbstractMatrix{T}, opts::LRAOptions)
  F = sketchfact(:left, trans, A, opts)
  k = F[:k]
  if trans == :n
    B = A[:,F[:p][1:k]]
  else
    n = size(A, 2)
    B = Array(T, n, k)
    for j = 1:k, i = 1:n
      B[i,j] = conj(A[F[:p][j],i])
    end
  end
  orthcols!(B)
end

prange_chktrans(trans::Symbol) =
  trans in (:n, :c, :b) || throw(ArgumentError("trans"))